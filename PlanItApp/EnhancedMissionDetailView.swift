import SwiftUI
import MapKit

// MARK: - Enhanced Mission Detail View
struct EnhancedMissionDetailView: View {
    let mission: Mission
    let missionManager: MissionManager
    let xpManager: XPManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Mission Header
                    missionHeader
                    
                    // XP Reward
                    xpRewardSection
                    
                    // Place Options
                    placeOptionsSection
                    
                    // Mission Progress
                    if !mission.isCompleted {
                        progressSection
                    }
                    
                    // Completion Status
                    if mission.isCompleted {
                        completionSection
                    }
                }
                .padding(20)
            }
            .background(Color.black)
            .navigationTitle("Mission Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Mission Header
    private var missionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mission.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Text(mission.vibeTag ?? "Mission")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                
                if let locationType = mission.locationType {
                                         Text(locationType.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.purple.opacity(0.3))
                        )
                }
            }
            
            Text(mission.prompt ?? mission.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
    }
    
    // MARK: - XP Reward Section
    private var xpRewardSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Text("+\(mission.xpReward)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("XP Reward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Complete this mission to earn \(mission.xpReward) XP")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Place Options Section
    private var placeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Place Options")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            if let placeOptions = mission.placeOptions {
                ForEach(placeOptions) { place in
                EnhancedPlaceOptionRow(
                    place: place,
                    missionCompleted: mission.isCompleted,
                    accentColor: .blue,
                    onVisit: {
                        Task {
                            await missionManager.markPlaceAsVisited(
                                missionId: mission.id,
                                placeId: place.placeId
                            )
                        }
                                            }
                    )
                }
            }
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text("\(mission.completedPlacesCount) of \(mission.placeOptions?.count ?? mission.targetPlaces.count) places visited")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(Int((Double(mission.completedPlacesCount) / Double(mission.placeOptions?.count ?? mission.targetPlaces.count)) * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(
                                width: geometry.size.width * (Double(mission.completedPlacesCount) / Double(mission.placeOptions?.count ?? mission.targetPlaces.count)),
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.5), value: mission.completedPlacesCount)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Completion Section
    private var completionSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Mission Completed! 🎉")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("You earned \(mission.xpReward) XP")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
                
                if let completedAt = mission.completedAt {
                    Text("Completed \(timeAgoString(from: completedAt))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Enhanced Place Detail Card
struct EnhancedPlaceDetailCard: View {
    let place: MissionPlace
    let missionCompleted: Bool
    let accentColor: Color
    let onVisit: () -> Void
    let onShowDetails: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(place.completed ? .green.opacity(0.2) : accentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: place.completed ? "checkmark.circle.fill" : "location.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(place.completed ? .green : accentColor)
                }
                
                // Place info
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .strikethrough(place.completed)
                        .lineLimit(2)
                    
                    Text(place.address)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if place.completed {
                    // Completed indicator
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text("Visited")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                        
                        if let completedAt = place.completedAt {
                            Text("• \(timeAgoString(from: completedAt))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.green.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                } else if !missionCompleted {
                    // Visit button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            onVisit()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text("Mark as Visited")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
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
                
                Spacer()
                
                // Details button
                Button(action: onShowDetails) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.1))
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            place.completed ? .green.opacity(0.3) : accentColor.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: place.completed ? .green.opacity(0.1) : accentColor.opacity(0.1),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .opacity(place.completed ? 0.8 : 1.0)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Mission Map View
struct MissionMapView: View {
    let mission: Mission
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion()
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: mission.placeOptions ?? []) { place in
                MapPin(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), tint: place.completed ? .green : .red)
            }
            .navigationTitle("Mission Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 