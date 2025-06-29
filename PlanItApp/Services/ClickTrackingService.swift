import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

/// 🎯 COMPREHENSIVE CLICK TRACKING & ANALYTICS SERVICE
/// Tracks every user interaction with party cards and provides demographic insights
@MainActor
class ClickTrackingService: ObservableObject {
    static let shared = ClickTrackingService()
    
    // MARK: - Data Models
    
    struct EventClick: Identifiable, Codable {
        let id: String
        let partyId: String
        let partyTitle: String
        let partyImageUrl: String?
        let userId: String
        let userName: String
        let userAge: Int?
        let userGender: String?
        let userLocation: String?
        let timestamp: Date
        let deviceType: String
        let sessionId: String
        
        init(partyId: String, partyTitle: String, partyImageUrl: String?, userId: String, userName: String, userAge: Int? = nil, userGender: String? = nil, userLocation: String? = nil) {
            self.id = UUID().uuidString
            self.partyId = partyId
            self.partyTitle = partyTitle
            self.partyImageUrl = partyImageUrl
            self.userId = userId
            self.userName = userName
            self.userAge = userAge
            self.userGender = userGender
            self.userLocation = userLocation
            self.timestamp = Date()
            self.deviceType = UIDevice.current.model
            self.sessionId = UUID().uuidString
        }
    }
    
    struct EventClickAnalytics: Identifiable {
        let id = UUID()
        let partyId: String
        let partyTitle: String
        let partyImageUrl: String?
        let totalClicks: Int
        let uniqueUsers: Int
        let conversionRate: Double
        let averageUserAge: Double
        let topUserLocation: String
        let genderBreakdown: [String: Int]
        let clicksThisWeek: Int
        let clicksThisMonth: Int
        let recentClicks: [EventClick]
    }
    
    struct DemographicInsight {
        let ageRanges: [String: Int] // "18-24": count
        let genderDistribution: [String: Int]
        let topLocations: [String: Int]
        let averageSpent: Double
        let conversionRate: Double
        let totalUniqueUsers: Int
    }
    
    // MARK: - Published Properties
    @Published var eventClickAnalytics: [EventClickAnalytics] = []
    @Published var demographicInsights = DemographicInsight(
        ageRanges: [:],
        genderDistribution: [:], 
        topLocations: [:],
        averageSpent: 0,
        conversionRate: 0,
        totalUniqueUsers: 0
    )
    @Published var totalClicksAllEvents: Int = 0
    @Published var clicksThisWeek: Int = 0
    @Published var clicksThisMonth: Int = 0
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    // MARK: - Click Tracking Methods
    
    /// Records a click on a party card with full user context
    func trackPartyCardClick(party: Party, user: User) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get user demographics
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            
            let click = EventClick(
                partyId: party.id,
                partyTitle: party.title,
                partyImageUrl: party.images.first,
                userId: userId,
                userName: user.displayName ?? "Anonymous",
                userAge: userData["age"] as? Int,
                userGender: userData["gender"] as? String,
                userLocation: userData["location"] as? String
            )
            
            // Store click in Firestore
            try await db.collection("eventClicks").document(click.id).setData([
                "partyId": click.partyId,
                "partyTitle": click.partyTitle,
                "partyImageUrl": click.partyImageUrl ?? "",
                "hostId": party.hostId,
                "userId": click.userId,
                "userName": click.userName,
                "userAge": click.userAge ?? 0,
                "userGender": click.userGender ?? "",
                "userLocation": click.userLocation ?? "",
                "timestamp": Timestamp(date: click.timestamp),
                "deviceType": click.deviceType,
                "sessionId": click.sessionId
            ])
            
            // Update party's click count
            try await db.collection("parties").document(party.id).updateData([
                "clickCount": FieldValue.increment(Int64(1)),
                "lastClickedAt": Timestamp(date: Date())
            ])
            
            print("✅ Party click tracked: \(party.title) by \(click.userName)")
            
        } catch {
            print("❌ Error tracking party click: \(error)")
        }
    }
    
    // MARK: - Analytics Setup
    
    func startTrackingForHost(_ hostId: String) {
        removeAllListeners()
        setupClickListeners(for: hostId)
    }
    
    func stopTracking() {
        removeAllListeners()
    }
    
    private func setupClickListeners(for hostId: String) {
        // Listen to all clicks for host's events
        let clicksListener = db.collection("eventClicks")
            .whereField("hostId", isEqualTo: hostId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error in clicks listener: \(error)")
                    return
                }
                
                Task {
                    await self.processClickData(snapshot?.documents ?? [])
                }
            }
        
        listeners.append(clicksListener)
    }
    
    private func processClickData(_ documents: [QueryDocumentSnapshot]) async {
        var clickAnalytics: [String: EventClickAnalytics] = [:]
        var allClicks: [EventClick] = []
        var ageRanges: [String: Int] = [:]
        var genderDist: [String: Int] = [:]
        var locations: [String: Int] = [:]
        var totalSpent: Double = 0
        var payingCustomers: Set<String> = []
        
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Process each click
        for document in documents {
            let data = document.data()
            
            guard let partyId = data["partyId"] as? String,
                  let partyTitle = data["partyTitle"] as? String,
                  let userId = data["userId"] as? String,
                  let userName = data["userName"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp else {
                continue
            }
            
            let clickDate = timestamp.dateValue()
            let click = EventClick(
                partyId: partyId,
                partyTitle: partyTitle,
                partyImageUrl: data["partyImageUrl"] as? String,
                userId: userId,
                userName: userName,
                userAge: data["userAge"] as? Int,
                userGender: data["userGender"] as? String,
                userLocation: data["userLocation"] as? String
            )
            
            allClicks.append(click)
            
            // Build analytics for each event
            if clickAnalytics[partyId] == nil {
                clickAnalytics[partyId] = EventClickAnalytics(
                    partyId: partyId,
                    partyTitle: partyTitle,
                    partyImageUrl: click.partyImageUrl,
                    totalClicks: 0,
                    uniqueUsers: 0,
                    conversionRate: 0,
                    averageUserAge: 0,
                    topUserLocation: "",
                    genderBreakdown: [:],
                    clicksThisWeek: 0,
                    clicksThisMonth: 0,
                    recentClicks: []
                )
            }
            
            // Count clicks by timeframe
            var weekClicks = 0
            var monthClicks = 0
            
            if clickDate >= weekStart {
                weekClicks += 1
            }
            if clickDate >= monthStart {
                monthClicks += 1
            }
            
            // Process demographics
            if let age = click.userAge {
                let ageRange = getAgeRange(age)
                ageRanges[ageRange, default: 0] += 1
            }
            
            if let gender = click.userGender, !gender.isEmpty {
                genderDist[gender, default: 0] += 1
            }
            
            if let location = click.userLocation, !location.isEmpty {
                locations[location, default: 0] += 1
            }
        }
        
        // Get conversion data (users who actually purchased)
        await getConversionData(for: Array(clickAnalytics.keys))
        
        // Calculate demographics
        let totalUniqueUsers = Set(allClicks.map { $0.userId }).count
        let avgSpent = await calculateAverageSpentByClickers(Array(Set(allClicks.map { $0.userId })))
        
        await MainActor.run {
            self.eventClickAnalytics = Array(clickAnalytics.values).sorted { $0.totalClicks > $1.totalClicks }
            self.totalClicksAllEvents = allClicks.count
            self.clicksThisWeek = allClicks.filter { 
                calendar.dateInterval(of: .weekOfYear, for: now)?.contains($0.timestamp) ?? false 
            }.count
            self.clicksThisMonth = allClicks.filter { 
                calendar.dateInterval(of: .month, for: now)?.contains($0.timestamp) ?? false 
            }.count
            
            self.demographicInsights = DemographicInsight(
                ageRanges: ageRanges,
                genderDistribution: genderDist,
                topLocations: locations,
                averageSpent: avgSpent,
                conversionRate: calculateConversionRate(allClicks.count, payingCustomers.count),
                totalUniqueUsers: totalUniqueUsers
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAgeRange(_ age: Int) -> String {
        switch age {
        case 0..<18: return "Under 18"
        case 18..<25: return "18-24"
        case 25..<35: return "25-34"
        case 35..<45: return "35-44"
        case 45..<55: return "45-54"
        case 55..<65: return "55-64"
        default: return "65+"
        }
    }
    
    private func getConversionData(for partyIds: [String]) async {
        // Get actual purchases for these events
        do {
            for partyId in partyIds {
                let salesSnapshot = try await db.collectionGroup("ticketSales")
                    .whereField("partyId", isEqualTo: partyId)
                    .getDocuments()
                
                let rsvpSnapshot = try await db.collectionGroup("rsvps")
                    .whereField("partyId", isEqualTo: partyId)
                    .getDocuments()
                
                // Update conversion rates for this event
                // Implementation continues...
            }
        } catch {
            print("❌ Error getting conversion data: \(error)")
        }
    }
    
    private func calculateAverageSpentByClickers(_ userIds: [String]) async -> Double {
        var totalSpent: Double = 0
        var userCount = 0
        
        for userId in userIds {
            do {
                let salesSnapshot = try await db.collectionGroup("ticketSales")
                    .whereField("buyerId", isEqualTo: userId)
                    .getDocuments()
                
                let userTotal = salesSnapshot.documents.reduce(0.0) { sum, doc in
                    let data = doc.data()
                    let price = data["ticketPrice"] as? Double ?? 0
                    let quantity = data["quantity"] as? Int ?? 0
                    return sum + (price * Double(quantity))
                }
                
                if userTotal > 0 {
                    totalSpent += userTotal
                    userCount += 1
                }
            } catch {
                print("❌ Error calculating user spending: \(error)")
            }
        }
        
        return userCount > 0 ? totalSpent / Double(userCount) : 0
    }
    
    private func calculateConversionRate(_ totalClicks: Int, _ conversions: Int) -> Double {
        return totalClicks > 0 ? (Double(conversions) / Double(totalClicks)) * 100 : 0
    }
    
    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Public Analytics Methods
    
    func getClickAnalyticsForTimeframe(_ timeframe: HostAnalyticsService.Timeframe) -> [EventClickAnalytics] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeframe {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .thisWeek:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .thisMonth:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        }
        
        return eventClickAnalytics.map { analytics in
            let filteredClicks = analytics.recentClicks.filter { $0.timestamp >= startDate }
            return EventClickAnalytics(
                partyId: analytics.partyId,
                partyTitle: analytics.partyTitle,
                partyImageUrl: analytics.partyImageUrl,
                totalClicks: filteredClicks.count,
                uniqueUsers: Set(filteredClicks.map { $0.userId }).count,
                conversionRate: analytics.conversionRate,
                averageUserAge: analytics.averageUserAge,
                topUserLocation: analytics.topUserLocation,
                genderBreakdown: analytics.genderBreakdown,
                clicksThisWeek: analytics.clicksThisWeek,
                clicksThisMonth: analytics.clicksThisMonth,
                recentClicks: filteredClicks
            )
        }.sorted { $0.totalClicks > $1.totalClicks }
    }
}

// Expose nested analytics struct for easy use across other files
typealias EventClickAnalytics = ClickTrackingService.EventClickAnalytics 