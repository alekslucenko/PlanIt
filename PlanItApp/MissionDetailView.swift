import SwiftUI

struct MissionDetailView: View {
    let mission: Mission
    let missionManager: MissionManager
    let xpManager: XPManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Mission Header
                    missionHeader
                    
                    // Mission Description
                    missionDescription
                    
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
                if let vibeTag = mission.vibeTag {
                    Text(vibeTag)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.blue.opacity(0.3))
                        )
                }
                
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
        }
    }
    
    // MARK: - Mission Description
    private var missionDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mission Brief")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
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
                    DetailedPlaceOptionRow(
                        place: place,
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
            } else {
                // Show target places for new missions
                ForEach(mission.targetPlaces) { targetPlace in
                    DetailedTargetPlaceRow(
                        targetPlace: targetPlace,
                        isVisited: mission.visitedPlaces.contains(targetPlace.placeId),
                        onVisit: {
                            Task {
                                await missionManager.markPlaceAsVisited(
                                    missionId: mission.id,
                                    placeId: targetPlace.placeId
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
        let totalPlaces = mission.placeOptions?.count ?? mission.targetPlaces.count
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text("\(mission.completedPlacesCount) of \(totalPlaces) places visited")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(Int((Double(mission.completedPlacesCount) / Double(totalPlaces)) * 100))%")
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
                                width: geometry.size.width * (Double(mission.completedPlacesCount) / Double(totalPlaces)),
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
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Detailed Place Option Row
struct DetailedPlaceOptionRow: View {
    let place: MissionPlace
    let onVisit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(place.completed ? .green.opacity(0.2) : .blue.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: place.completed ? "checkmark.circle.fill" : "location.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(place.completed ? .green : .blue)
                }
                
                // Place Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .strikethrough(place.completed)
                    
                    Text(place.address)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if !place.completed {
                    Button(action: onVisit) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Mark as Visited")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                } else {
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
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Open in Maps or show directions
                }) {
                    Image(systemName: "map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(place.completed ? .green.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
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

// MARK: - Detailed Target Place Row
struct DetailedTargetPlaceRow: View {
    let targetPlace: MissionTargetPlace
    let isVisited: Bool
    let onVisit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(isVisited ? .green.opacity(0.2) : .blue.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "location.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isVisited ? .green : .blue)
                }
                
                // Place Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetPlace.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .strikethrough(isVisited)
                    
                    Text(targetPlace.address)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if !isVisited {
                    Button(action: onVisit) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Mark as Visited")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text("Visited")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Open in Maps or show directions
                }) {
                    Image(systemName: "map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isVisited ? .green.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isVisited ? 0.8 : 1.0)
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

// MARK: - Preview
struct MissionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MissionDetailView(
            mission: Mission(
                title: "Sample Mission",
                prompt: "This is a sample mission description.",
                xpReward: 200,
                vibeTag: "Adventurous",
                locationType: "restaurant",
                placeOptions: [],
                userId: "sample"
            ),
            missionManager: MissionManager(),
            xpManager: XPManager()
        )
    }
} 