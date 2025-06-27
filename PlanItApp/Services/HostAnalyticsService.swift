import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
final class HostAnalyticsService: ObservableObject {
    static let shared = HostAnalyticsService()
    
    // Public, live-updating metrics that the dashboard binds to
    @Published var metrics: HostMetrics = .placeholder
    @Published var chartPoints: [DailyMetricPoint] = []
    @Published var timeframe: Timeframe = .thisWeek {
        didSet { recalculateMetrics() }
    }
    
    // MARK: - Types
    struct HostMetrics {
        var totalRevenue: Double
        var newCustomers: Int
        var activeEvents: Int
        var totalAttendees: Int
        var averageEventSize: Double
        // Growth percentages vs previous equivalent period
        var revenueGrowth: Double
        var customerGrowth: Double
        var eventGrowth: Double
        var attendeeGrowth: Double
        var eventSizeGrowth: Double
        
        static let placeholder = HostMetrics(totalRevenue: 0,
                                             newCustomers: 0,
                                             activeEvents: 0,
                                             totalAttendees: 0,
                                             averageEventSize: 0,
                                             revenueGrowth: 0,
                                             customerGrowth: 0,
                                             eventGrowth: 0,
                                             attendeeGrowth: 0,
                                             eventSizeGrowth: 0)
    }
    
    struct DailyMetricPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    enum Timeframe: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisQuarter = "This Quarter"
        
        var dateRange: ClosedRange<Date> {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .thisWeek:
                let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                return start...now
            case .thisMonth:
                let comps = cal.dateComponents([.year, .month], from: now)
                let start = cal.date(from: comps) ?? now
                return start...now
            case .thisQuarter:
                let comps = cal.dateComponents([.year], from: now)
                let yearStart = cal.date(from: comps) ?? now
                if let quarter = cal.dateInterval(of: .quarter, for: now) {
                    return quarter.start...now
                }
                return yearStart...now
            }
        }
    }
    
    // MARK: - Private
    private let db = Firestore.firestore()
    private var partiesListener: ListenerRegistration?
    private var rsvpListeners: [ListenerRegistration] = []
    private var hostParties: [Party] = []
    private var rsvpMap: [String: [RSVP]] = [:] // partyId -> RSVPs
    private var userId: String? { Auth.auth().currentUser?.uid }
    
    private init() {
        attachPartyListener()
    }
    
    deinit {
        partiesListener?.remove()
        rsvpListeners.forEach { $0.remove() }
    }
    
    // MARK: - Firestore Listening
    private func attachPartyListener() {
        guard let uid = userId else { return }
        partiesListener?.remove()
        partiesListener = db.collection("parties")
            .whereField("hostId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { print("❌ HostAnalyticsService party listener error: \(err)"); return }
                guard let docs = snap?.documents else { return }
                self.hostParties = docs.compactMap { try? $0.data(as: Party.self) }
                self.attachRSVPListeners()
            }
    }
    
    private func attachRSVPListeners() {
        // Clear previous listeners
        rsvpListeners.forEach { $0.remove() }
        rsvpListeners.removeAll()
        rsvpMap.removeAll()
        
        for party in hostParties {
            let listener = db.collection("rsvps")
                .whereField("partyId", isEqualTo: party.id)
                .addSnapshotListener { [weak self] snap, err in
                    guard let self = self else { return }
                    if let err = err { print("❌ RSVP listener error: \(err)"); return }
                    let rsvps = snap?.documents.compactMap { try? $0.data(as: RSVP.self) } ?? []
                    self.rsvpMap[party.id] = rsvps
                    self.recalculateMetrics()
                }
            rsvpListeners.append(listener)
        }
        recalculateMetrics()
    }
    
    // MARK: - Calculation
    private func recalculateMetrics() {
        let range = timeframe.dateRange
        let now = Date()
        var revenue: Double = 0
        var customersSet: Set<String> = []
        var activeEvents = 0
        var totalAttendees = 0
        var sizeAccumulator = 0
        var dailyBuckets: [String: Double] = [:] // yyyy-MM-dd -> revenue
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for party in hostParties {
            if range.contains(party.startDate) {
                activeEvents += 1
            }
            // attendees from RSVP map
            let rsvps = rsvpMap[party.id] ?? []
            for rsvp in rsvps {
                if range.contains(rsvp.rsvpDate) {
                    totalAttendees += rsvp.quantity
                    customersSet.insert(rsvp.userId)
                    // approximate revenue
                    if let tier = party.ticketTiers.first(where: { $0.id == rsvp.ticketTierId }) {
                        revenue += Double(rsvp.quantity) * tier.price
                    }
                    let dayKey = formatter.string(from: rsvp.rsvpDate)
                    dailyBuckets[dayKey, default: 0] += Double(rsvp.quantity) * (party.ticketTiers.first(where: { $0.id == rsvp.ticketTierId })?.price ?? 0)
                }
            }
            sizeAccumulator += rsvpMap[party.id]?.reduce(0, { $0 + $1.quantity }) ?? 0
        }
        let avgSize = activeEvents == 0 ? 0 : Double(sizeAccumulator) / Double(activeEvents)
        metrics = HostMetrics(totalRevenue: revenue,
                              newCustomers: customersSet.count,
                              activeEvents: activeEvents,
                              totalAttendees: totalAttendees,
                              averageEventSize: avgSize,
                              revenueGrowth: 0,
                              customerGrowth: 0,
                              eventGrowth: 0,
                              attendeeGrowth: 0,
                              eventSizeGrowth: 0)
        // convert buckets to daily points sorted
        chartPoints = dailyBuckets.compactMap { key, value in
            formatter.date(from: key).map { DailyMetricPoint(date: $0, value: value) }
        }.sorted { $0.date < $1.date }
    }
} 