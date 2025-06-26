//
//  EventPlannerView.swift
//  PlanIt
//
//  Created by Aleks Lucenko on 6/12/25.
//

import SwiftUI
import CoreLocation

// MARK: - Event Plan Data Models
struct EventPlan: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var date: Date
    var places: [Place]
    var estimatedDuration: TimeInterval // in seconds
    var totalDistance: Double // in miles
    var createdAt: Date
    var category: EventPlanCategory
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = (Int(estimatedDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedDistance: String {
        return String(format: "%.1f mi", totalDistance)
    }
}

enum EventPlanCategory: String, CaseIterable, Codable {
    case dateNight = "Date Night"
    case familyFun = "Family Fun"
    case businessTrip = "Business Trip"
    case exploration = "Exploration"
    case foodTour = "Food Tour"
    case nightOut = "Night Out"
    case shopping = "Shopping Spree"
    case cultural = "Cultural"
    
    var iconName: String {
        switch self {
        case .dateNight: return "heart.fill"
        case .familyFun: return "figure.2.and.child.holdinghands"
        case .businessTrip: return "briefcase.fill"
        case .exploration: return "map.fill"
        case .foodTour: return "fork.knife"
        case .nightOut: return "moon.stars.fill"
        case .shopping: return "bag.fill"
        case .cultural: return "building.columns.fill"
        }
    }
    
    var color: String {
        switch self {
        case .dateNight: return "#FF6B6B"
        case .familyFun: return "#4ECDC4"
        case .businessTrip: return "#45B7D1"
        case .exploration: return "#96CEB4"
        case .foodTour: return "#FECA57"
        case .nightOut: return "#A29BFE"
        case .shopping: return "#FD79A8"
        case .cultural: return "#E17055"
        }
    }
}

// MARK: - Event Plan Manager
class EventPlanManager: ObservableObject {
    @Published var eventPlans: [EventPlan] = []
    @Published var currentPlan: EventPlan?
    @Published var isCreatingPlan = false
    
    static let shared = EventPlanManager()
    
    private init() {
        loadPlans()
    }
    
    func createNewPlan(name: String, description: String, date: Date, category: EventPlanCategory) {
        let newPlan = EventPlan(
            name: name,
            description: description,
            date: date,
            places: [],
            estimatedDuration: 0,
            totalDistance: 0,
            createdAt: Date(),
            category: category
        )
        currentPlan = newPlan
        isCreatingPlan = true
    }
    
    func addPlaceToPlan(_ place: Place) {
        guard currentPlan != nil else { return }
        currentPlan!.places.append(place)
        updatePlanMetrics()
    }
    
    func removePlaceFromPlan(_ place: Place) {
        guard currentPlan != nil else { return }
        currentPlan!.places.removeAll { $0.id == place.id }
        updatePlanMetrics()
    }
    
    func savePlan() {
        guard let plan = currentPlan else { return }
        eventPlans.append(plan)
        currentPlan = nil
        isCreatingPlan = false
        savePlans()
    }
    
    func cancelPlan() {
        currentPlan = nil
        isCreatingPlan = false
    }
    
    func deletePlan(_ plan: EventPlan) {
        eventPlans.removeAll { $0.id == plan.id }
        savePlans()
    }
    
    private func updatePlanMetrics() {
        guard var plan = currentPlan else { return }
        
        // Calculate estimated duration (2 hours per place + travel time)
        plan.estimatedDuration = Double(plan.places.count) * 2 * 3600 // 2 hours per place
        
        // Calculate total distance between places
        plan.totalDistance = calculateTotalDistance(for: plan.places)
        
        currentPlan = plan
    }
    
    private func calculateTotalDistance(for places: [Place]) -> Double {
        guard places.count > 1 else { return 0 }
        
        var totalDistance = 0.0
        for i in 0..<(places.count - 1) {
            if let coord1 = places[i].coordinates,
               let coord2 = places[i + 1].coordinates {
                let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
                let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
                let distance = location1.distance(from: location2) / 1609.34 // Convert to miles
                totalDistance += distance
            }
        }
        return totalDistance
    }
    
    private func savePlans() {
        if let encoded = try? JSONEncoder().encode(eventPlans) {
            UserDefaults.standard.set(encoded, forKey: "EventPlans")
        }
    }
    
    private func loadPlans() {
        if let data = UserDefaults.standard.data(forKey: "EventPlans"),
           let decoded = try? JSONDecoder().decode([EventPlan].self, from: data) {
            eventPlans = decoded
        }
    }
}

// MARK: - Main Event Planner View
struct EventPlannerView: View {
    @StateObject private var planManager = EventPlanManager.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var placeDataService = PlaceDataService.shared
    @State private var showingCreatePlan = false
    @State private var showingPlaceSearch = false
    @State private var searchText = ""
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic themed background
                theme.backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: theme.isDarkMode)
                
                if planManager.isCreatingPlan {
                    // Creating plan mode
                    PlanCreationView()
                } else {
                    // Main plans list view
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header section
                            headerSection
                            
                            // Create new plan button
                            createPlanButton
                            
                            // Existing plans
                            plansSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePlan) {
            CreateEventPlanSheet()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Planner")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create amazing experiences")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#FF6B6B"))
            }
            .padding(.top, 10)
        }
    }
    
    private var createPlanButton: some View {
        Button(action: {
            showingCreatePlan = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Create New Event Plan")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E88")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if planManager.eventPlans.isEmpty {
                emptyPlansView
            } else {
                HStack {
                    Text("Your Event Plans")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(planManager.eventPlans.count) plans")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                LazyVStack(spacing: 16) {
                    ForEach(planManager.eventPlans.sorted(by: { $0.date < $1.date }), id: \.id) { plan in
                        EventPlanCard(plan: plan)
                    }
                }
            }
        }
    }
    
    private var emptyPlansView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#FF6B6B").opacity(0.6))
            
            Text("No Event Plans Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Create your first event plan to start organizing amazing experiences with multiple places!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Plan Creation View
struct PlanCreationView: View {
    @StateObject private var planManager = EventPlanManager.shared
    @StateObject private var placeDataService = PlaceDataService.shared
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var showingPlaceSearch = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with plan info
                planHeaderSection
                
                // Add places section
                addPlacesSection
                
                // Current places in plan
                if let plan = planManager.currentPlan, !plan.places.isEmpty {
                    currentPlacesSection
                }
                
                // Save/Cancel buttons
                actionButtonsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .navigationBarHidden(true)
    }
    
    private var planHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: {
                    planManager.cancelPlan()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                
                Spacer()
                
                Text("Creating Plan")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Save button preview
                Button(action: {
                    planManager.savePlan()
                }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                }
                .disabled(planManager.currentPlan?.places.isEmpty ?? true)
            }
            
            if let plan = planManager.currentPlan {
                VStack(alignment: .leading, spacing: 12) {
                    Text(plan.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(plan.description)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Label(plan.formattedDate, systemImage: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: plan.category.color))
                        
                        Label(plan.category.rawValue, systemImage: plan.category.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: plan.category.color))
                    }
                    
                    if !plan.places.isEmpty {
                        HStack(spacing: 16) {
                            Label("\(plan.places.count) places", systemImage: "mappin.and.ellipse")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Label(plan.formattedDuration, systemImage: "clock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            if plan.totalDistance > 0 {
                                Label(plan.formattedDistance, systemImage: "location")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: plan.category.color).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var addPlacesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Places to Your Plan")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Search for places to add...", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { oldValue, newValue in
                        if !newValue.isEmpty, let location = locationManager.selectedLocation {
                            placeDataService.searchPlaces(query: newValue, location: location, radius: 5.0)
                        } else {
                            placeDataService.clearSearchResults()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        placeDataService.clearSearchResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
            )
            
            // Search results
            if placeDataService.isSearching {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Searching places...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else if !placeDataService.searchResults.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(placeDataService.searchResults, id: \.id) { place in
                        AddPlaceCard(place: place)
                    }
                }
            }
        }
    }
    
    private var currentPlacesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Places in Your Plan (\(planManager.currentPlan?.places.count ?? 0))")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            if let places = planManager.currentPlan?.places {
                LazyVStack(spacing: 12) {
                    ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                        PlanPlaceCard(place: place, index: index + 1)
                    }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                planManager.cancelPlan()
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            Button(action: {
                planManager.savePlan()
            }) {
                Text("Save Plan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E88")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(planManager.currentPlan?.places.isEmpty ?? true)
        }
        .padding(.top, 20)
    }
}

// MARK: - Event Plan Card
struct EventPlanCard: View {
    let plan: EventPlan
    @StateObject private var planManager = EventPlanManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(plan.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Category icon
                Image(systemName: plan.category.iconName)
                    .font(.title2)
                    .foregroundColor(Color(hex: plan.category.color))
            }
            
            // Plan details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Label(plan.formattedDate, systemImage: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: plan.category.color))
                    
                    Label(plan.category.rawValue, systemImage: plan.category.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: plan.category.color))
                }
                
                HStack(spacing: 16) {
                    Label("\(plan.places.count) places", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Label(plan.formattedDuration, systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if plan.totalDistance > 0 {
                        Label(plan.formattedDistance, systemImage: "location")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Places preview
            if !plan.places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(plan.places.prefix(3), id: \.id) { place in
                            Text(place.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: plan.category.color))
                                )
                        }
                        
                        if plan.places.count > 3 {
                            Text("+\(plan.places.count - 3) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: plan.category.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: plan.category.color).opacity(0.2))
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: plan.category.color).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            EventPlanDetailView(plan: plan)
        }
    }
}

// MARK: - Add Place Card
struct AddPlaceCard: View {
    let place: Place
    @StateObject private var planManager = EventPlanManager.shared
    
    private var isAlreadyAdded: Bool {
        planManager.currentPlan?.places.contains(where: { $0.id == place.id }) ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Place image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: place.category.color).opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: place.category.iconName)
                        .font(.title2)
                        .foregroundColor(Color(hex: place.category.color))
                )
            
            // Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(place.location)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", place.rating))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(place.priceRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: place.category.color))
                }
            }
            
            Spacer()
            
            // Add button
            Button(action: {
                if isAlreadyAdded {
                    planManager.removePlaceFromPlan(place)
                } else {
                    planManager.addPlaceToPlan(place)
                }
            }) {
                Image(systemName: isAlreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundColor(isAlreadyAdded ? .green : Color(hex: "#FF6B6B"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Plan Place Card
struct PlanPlaceCard: View {
    let place: Place
    let index: Int
    @StateObject private var planManager = EventPlanManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number
            Text("\(index)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: "#FF6B6B"))
                )
            
            // Place image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: place.category.color).opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: place.category.iconName)
                        .font(.title2)
                        .foregroundColor(Color(hex: place.category.color))
                )
            
            // Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(place.location)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", place.rating))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(place.priceRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: place.category.color))
                }
            }
            
            Spacer()
            
            // Remove button
            Button(action: {
                planManager.removePlaceFromPlan(place)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Create Event Plan Sheet
struct CreateEventPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var planManager = EventPlanManager.shared
    
    @State private var planName = ""
    @State private var planDescription = ""
    @State private var selectedDate = Date()
    @State private var selectedCategory: EventPlanCategory = .exploration
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Create Event Plan")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Plan your perfect experience")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Plan details form
                    VStack(spacing: 20) {
                        // Plan name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plan Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("Enter plan name", text: $planName)
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        
                        // Plan description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("Describe your event plan", text: $planDescription, axis: .vertical)
                                .font(.system(size: 16))
                                .lineLimit(3, reservesSpace: true)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        
                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            DatePicker("Select date and time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        
                        // Category selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(EventPlanCategory.allCases, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: category.iconName)
                                                .font(.system(size: 16))
                                                .foregroundColor(selectedCategory == category ? .white : Color(hex: category.color))
                                            
                                            Text(category.rawValue)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(selectedCategory == category ? .white : Color(hex: category.color))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedCategory == category ? Color(hex: category.color) : Color(hex: category.color).opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color(hex: category.color).opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Create button
                    Button(action: {
                        planManager.createNewPlan(
                            name: planName,
                            description: planDescription,
                            date: selectedDate,
                            category: selectedCategory
                        )
                        dismiss()
                    }) {
                        Text("Create Plan")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E88")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(planName.isEmpty)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Event Plan Detail View
struct EventPlanDetailView: View {
    let plan: EventPlan
    @Environment(\.dismiss) private var dismiss
    @StateObject private var planManager = EventPlanManager.shared
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Plan header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: plan.category.iconName)
                                .font(.title)
                                .foregroundColor(Color(hex: plan.category.color))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(plan.category.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: plan.category.color))
                            }
                            
                            Spacer()
                        }
                        
                        Text(plan.description)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        // Plan metrics
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(plan.formattedDate)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(plan.formattedDuration)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            if plan.totalDistance > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Distance")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text(plan.formattedDistance)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: plan.category.color).opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Places in plan
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Places in This Plan (\(plan.places.count))")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(plan.places.enumerated()), id: \.element.id) { index, place in
                                PlanDetailPlaceCard(place: place, index: index + 1, categoryColor: plan.category.color)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Delete Plan", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                planManager.deletePlan(plan)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this event plan? This action cannot be undone.")
        }
    }
}

// MARK: - Plan Detail Place Card
struct PlanDetailPlaceCard: View {
    let place: Place
    let index: Int
    let categoryColor: String
    @State private var showingPlaceDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number
            Text("\(index)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: categoryColor))
                )
            
            // Place image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: place.category.color).opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: place.category.iconName)
                        .font(.title2)
                        .foregroundColor(Color(hex: place.category.color))
                )
            
            // Place info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(place.location)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", place.rating))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(place.priceRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: place.category.color))
                }
            }
            
            Spacer()
            
            // View details button
            Button(action: {
                showingPlaceDetail = true
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: categoryColor).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture {
            showingPlaceDetail = true
        }
        .sheet(isPresented: $showingPlaceDetail) {
            NavigationView {
                PlaceDetailView(place: place)
            }
        }
    }
}

#Preview {
    EventPlannerView()
} 