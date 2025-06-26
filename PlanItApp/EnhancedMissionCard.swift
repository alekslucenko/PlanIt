import SwiftUI

// MARK: - Enhanced Mission Card
struct EnhancedMissionCard: View {
    let mission: Mission
    let isCompleted: Bool
    let onTap: () -> Void
    let onPlaceVisit: (String) -> Void
    
    @State private var isExpanded = false
    @State private var cardOffset: CGFloat = 0
    @State private var showPlaceDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with enhanced styling
            missionHeader
            
            // Mission description with better typography
            missionDescription
            
            // Progress indicator
            if !isCompleted {
                progressIndicator
            }
            
            // Place options with enhanced design
            placeOptionsSection
            
            // AI attribution with modern styling
            aiAttribution
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [missionAccentColor.opacity(0.4), missionAccentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: missionAccentColor.opacity(isCompleted ? 0.2 : 0.3),
                    radius: isCompleted ? 8 : 16,
                    x: 0,
                    y: isCompleted ? 4 : 8
                )
        )
        .offset(x: cardOffset)
        .scaleEffect(isCompleted ? 0.98 : 1.0)
        .opacity(isCompleted ? 0.85 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                onTap()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                cardOffset = 0
            }
        }
    }
    
    // MARK: - Mission Header
    private var missionHeader: some View {
        HStack(spacing: 16) {
            // Enhanced mission icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [missionAccentColor.opacity(0.3), missionAccentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: missionIconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(missionAccentColor)
            }
            .shadow(color: missionAccentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Mission info
            VStack(alignment: .leading, spacing: 6) {
                Text(mission.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Vibe tag
                    if let vibeTag = mission.vibeTag {
                        Text(vibeTag)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(missionAccentColor.opacity(0.25))
                                    .overlay(
                                        Capsule()
                                            .stroke(missionAccentColor.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    
                    // XP reward with enhanced styling
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        
                        Text("+\(mission.xpReward)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.yellow.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            Spacer()
            
            // Status indicator
            statusIndicator
        }
    }
    
    // MARK: - Status Indicator
    private var statusIndicator: some View {
        Group {
            if isCompleted {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 2) {
                    Text("\(mission.completedPlacesCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("of \(mission.placeOptions?.count ?? mission.targetPlaces.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Mission Description
    private var missionDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            let description = mission.prompt ?? mission.description
            let shortDescription = description.count > 120 ? 
                String(description.prefix(120)) + "..." : 
                description
            
            Text(shortDescription)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
            
            if description.count > 120 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Read full mission")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(missionAccentColor)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(missionAccentColor)
                    }
                }
            }
            
            if isExpanded && description.count > 120 {
                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(Int(progressPercentage * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(missionAccentColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [missionAccentColor, missionAccentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 6
                        )
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progressPercentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Place Options Section
    private var placeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Options")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ForEach((mission.placeOptions ?? []).prefix(isExpanded ? (mission.placeOptions?.count ?? 0) : 2)) { place in
                EnhancedPlaceOptionRow(
                    place: place,
                    missionCompleted: isCompleted,
                    accentColor: missionAccentColor,
                    onVisit: { onPlaceVisit(place.placeId) }
                )
            }
            
            if (mission.placeOptions?.count ?? 0) > 2 && !isExpanded {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded = true
                    }
                }) {
                    HStack {
                        Text("Show \((mission.placeOptions?.count ?? 0) - 2) more locations")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(missionAccentColor)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(missionAccentColor)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - AI Attribution
    private var aiAttribution: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#00d4ff").opacity(0.8))
                
                Text("Powered by Advanced AI")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#00d4ff").opacity(0.8))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var missionAccentColor: Color {
        switch (mission.locationType ?? "default").lowercased() {
        case "restaurant", "cafe", "food":
            return Color(hex: "#ff6b35")
        case "park", "nature", "outdoor":
            return Color(hex: "#4ecdc4")
        case "museum", "gallery", "culture":
            return Color(hex: "#9b59b6")
        case "bar", "nightlife", "entertainment":
            return Color(hex: "#e74c3c")
        case "shopping", "retail":
            return Color(hex: "#f39c12")
        case "fitness", "sports":
            return Color(hex: "#2ecc71")
        default:
            return Color(hex: "#3498db")
        }
    }
    
    private var missionIconName: String {
        switch (mission.locationType ?? "default").lowercased() {
        case "restaurant", "cafe", "food":
            return "fork.knife"
        case "park", "nature", "outdoor":
            return "leaf.fill"
        case "museum", "gallery", "culture":
            return "building.columns.fill"
        case "bar", "nightlife", "entertainment":
            return "music.note"
        case "shopping", "retail":
            return "bag.fill"
        case "fitness", "sports":
            return "figure.run"
        default:
            return "location.fill"
        }
    }
    
    private var progressPercentage: Double {
        let totalPlaces = mission.placeOptions?.count ?? mission.targetPlaces.count
        guard totalPlaces > 0 else { return 0.0 }
        return Double(mission.completedPlacesCount) / Double(totalPlaces)
    }
}

// MARK: - Enhanced Place Option Row
struct EnhancedPlaceOptionRow: View {
    let place: MissionPlace
    let missionCompleted: Bool
    let accentColor: Color
    let onVisit: () -> Void
    
    @State private var isPressed = false
    @State private var showingPlaceDetail = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Place status icon
            ZStack {
                Circle()
                    .fill(place.completed ? .green.opacity(0.2) : accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: place.completed ? "checkmark" : "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(place.completed ? .green : accentColor)
            }
            
            // Place information
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .strikethrough(place.completed)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(place.address)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                // Visit button or completed indicator
                if place.completed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text("Visited")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                } else if !missionCompleted {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            onVisit()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12, weight: .semibold))
                            
                            Text("Visit")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(accentColor)
                                .shadow(color: accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = pressing
                        }
                    }, perform: {})
                }
                
                // Details button
                Button(action: {
                    showingPlaceDetail = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text("Details")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(place.completed ? .green.opacity(0.3) : accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(place.completed ? 0.7 : 1.0)
        .sheet(isPresented: $showingPlaceDetail) {
            // Create a Place object from MissionPlace for PlaceDetailView
            PlaceDetailView(place: createPlaceFromMissionPlace())
        }
    }
    
    // Helper to create Place from MissionPlace for PlaceDetailView
    private func createPlaceFromMissionPlace() -> Place {
        return Place(
            id: UUID(),
            name: place.name,
            description: "Mission location - tap to explore details",
            category: .restaurants, // Default category
            rating: 4.0, // Default rating
            reviewCount: 50, // Default review count
            priceRange: "$$", // Default price range
            images: ["default_restaurant"], // Default image
            location: place.address,
            hours: "Hours not available",
            detailedHours: nil,
            phone: "Phone not available",
            website: nil,
            menuItems: [],
            reviews: [],
            googlePlaceId: place.placeId,
            sentiment: nil,
            isCurrentlyOpen: true,
            hasActualMenu: false,
            coordinates: Coordinates(latitude: 0.0, longitude: 0.0) // Will be fetched by detail view
        )
    }
}

// MARK: - Preview
struct EnhancedMissionCard_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedMissionCard(
            mission: Mission(
                title: "The Secret Sunrise Symphony",
                prompt: "Embark on a 'Sunrise Symphony' scavenger hunt! Your mission, should you choose to accept it, is to discover the most Instagram-worthy breakfast spots that capture the golden hour magic.",
                xpReward: 250,
                vibeTag: "Trendy Morning Exploration",
                locationType: "cafe",
                placeOptions: [
                    MissionPlace(placeId: "1", name: "The Daily Grind", address: "123 Example Street, City, State"),
                    MissionPlace(placeId: "2", name: "Coffee Beanery", address: "456 Another Street, City, State")
                ],
                userId: "sample"
            ),
            isCompleted: false,
            onTap: {},
            onPlaceVisit: { _ in }
        )
        .padding()
        .background(Color.black)
    }
} 