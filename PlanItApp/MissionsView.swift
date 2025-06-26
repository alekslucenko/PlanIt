import SwiftUI

// MARK: - Modern Missions View
struct MissionsView: View {
    @ObservedObject var missionManager: MissionManager
    @ObservedObject var xpManager: XPManager
    @ObservedObject var locationManager = LocationManager.shared
    @State private var selectedMission: Mission?
    @State private var selectedTab: MissionTab = .missions
    @State private var refreshing = false
    @State private var timeUntilRefresh: String = ""
    @State private var dailyTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Modern social media gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2"),
                    Color(hex: "#667eea")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Clean header
                modernHeader
                
                // Tab switcher
                tabSwitcher
                
                // Content
                TabView(selection: $selectedTab) {
                    missionsContent
                        .tag(MissionTab.missions)
                    
                    leaderboardContent
                        .tag(MissionTab.leaderboard)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .onReceive(dailyTimer) { _ in
            updateCountdownTimer()
        }
        .onAppear {
            startDailyMissionGeneration()
        }
        .sheet(item: $selectedMission) { mission in
            MissionDetailView(
                mission: mission,
                missionManager: missionManager,
                xpManager: xpManager
            )
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenges")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Explore • Connect • Earn XP")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                HStack {
                    Text("New challenges in")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(timeUntilRefresh)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.2))
                        )
                }
            }
            
            // XP Circle and User Level - Centered
            VStack(spacing: 16) {
                // Professional XP Ring
                ZStack {
                    // Outer ring with glow
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 120, height: 120)
                        .shadow(
                            color: Color(hex: "#00d4ff").opacity(0.4),
                            radius: 15,
                            x: 0,
                            y: 0
                        )
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(xpManager.userXP.progressToNextLevel()))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.7), value: xpManager.userXP.progressToNextLevel())
                    
                    // Inner content
                    VStack(spacing: 4) {
                        Text("LVL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)
                        
                        Text("\(xpManager.userXP.level)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(xpManager.userXP.currentXP) XP")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Explorer Level Badge
                VStack(spacing: 8) {
                    Text(explorerLevel)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    Text("Today's Progress")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(completedToday)/\(totalDailyMissions)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Tab Switcher
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(MissionTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(selectedTab == tab ? .white.opacity(0.2) : .clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(.white.opacity(0.1))
    }
    
    // MARK: - Missions Content
    private var missionsContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Stats cards row
                statsRow
                
                // Daily challenges
                dailyChallengesSection
                
                // Active missions
                if !missionManager.activeMissions.isEmpty {
                    activeMissionsSection
                }
                
                // Generate new mission button
                generateMissionButton
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .refreshable {
            await refreshMissions()
        }
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "target",
                title: "Active",
                value: "\(missionManager.activeMissions.count)",
                color: .blue
            )
            
            StatCard(
                icon: "checkmark.circle.fill",
                title: "Complete",
                value: "\(completedToday)",
                color: .green
            )
            
            StatCard(
                icon: "star.fill",
                title: "XP Today",
                value: "\(xpEarnedToday)",
                color: .yellow
            )
        }
    }
    
    // MARK: - Daily Challenges Section
    private var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Challenges")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if missionManager.dailyMissions.isEmpty {
                // Generate daily missions
                VStack(spacing: 16) {
                    Text("Generating personalized challenges...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(missionManager.dailyMissions.prefix(4)) { mission in
                    ModernMissionCard(
                        mission: mission,
                        onTap: { selectedMission = mission },
                        onPlaceVisit: { placeId in
                            Task {
                                await missionManager.markPlaceAsVisited(
                                    missionId: mission.id,
                                    placeId: placeId
                                )
                                await missionManager.checkMissionCompletion(mission)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Active Missions Section
    private var activeMissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Missions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ForEach(missionManager.activeMissions) { mission in
                ModernMissionCard(
                    mission: mission,
                    onTap: { selectedMission = mission },
                    onPlaceVisit: { placeId in
                        Task {
                            await missionManager.markPlaceAsVisited(
                                missionId: mission.id,
                                placeId: placeId
                            )
                            await missionManager.checkMissionCompletion(mission)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Generate Mission Button
    private var generateMissionButton: some View {
        Button(action: {
            Task {
                await missionManager.generatePersonalizedMission()
            }
        }) {
            HStack(spacing: 12) {
                if missionManager.isGeneratingMission {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(missionManager.isGeneratingMission ? "Creating Mission..." : "Create New Mission")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(missionManager.isGeneratingMission)
    }
    
    // MARK: - Leaderboard Content
    private var leaderboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // User's rank card
                userRankCard
                
                // Top players
                topPlayersSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - User Rank Card
    private var userRankCard: some View {
        HStack(spacing: 16) {
            // Rank circle
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text("#\(xpManager.currentUserRank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Rank")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(xpManager.totalXP) XP")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Level \(xpManager.currentLevel)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(xpManager.xpToNextLevel) to next")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Top Players Section
    private var topPlayersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Leaderboard")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ForEach(Array(xpManager.leaderboard.enumerated()), id: \.element.id) { index, player in
                LeaderboardRow(
                    rank: index + 1,
                    player: player,
                    isCurrentUser: player.id == xpManager.currentUserId
                )
            }
        }
    }
    
    // MARK: - Helper Properties
    private var completedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return missionManager.completedMissions.filter { mission in
            guard let completedAt = mission.completedAt else { return false }
            return Calendar.current.isDate(completedAt, inSameDayAs: today)
        }.count
    }
    
    private var totalDailyMissions: Int {
        return max(missionManager.dailyMissions.count, 4)
    }
    
    private var dailyProgress: Double {
        guard totalDailyMissions > 0 else { return 0.0 }
        return Double(completedToday) / Double(totalDailyMissions)
    }
    
    private var xpEarnedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return missionManager.completedMissions
            .filter { mission in
                guard let completedAt = mission.completedAt else { return false }
                return Calendar.current.isDate(completedAt, inSameDayAs: today)
            }
            .reduce(0) { $0 + $1.xpReward }
    }
    
    private var explorerLevel: String {
        let level = xpManager.userXP.level
        switch level {
        case 1...5:
            return "🌱 Rookie Explorer"
        case 6...15:
            return "🏃‍♂️ Active Adventurer"
        case 16...30:
            return "🌟 Seasoned Explorer"
        case 31...50:
            return "🏆 Master Navigator"
        case 51...75:
            return "👑 Elite Discoverer"
        case 76...100:
            return "🔥 Legend Explorer"
        default:
            return "🚀 Infinity Explorer"
        }
    }
    
    // MARK: - Helper Methods
    private func updateCountdownTimer() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let startOfTomorrow = Calendar.current.startOfDay(for: tomorrow)
        let timeInterval = startOfTomorrow.timeIntervalSince(Date())
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        timeUntilRefresh = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func startDailyMissionGeneration() {
        Task {
            await missionManager.generateDailyMissions()
        }
    }
    
    private func refreshMissions() async {
        refreshing = true
        await missionManager.generateDailyMissions()
        refreshing = false
    }
}

// MARK: - Modern Mission Card
struct ModernMissionCard: View {
    let mission: Mission
    let onTap: () -> Void
    let onPlaceVisit: (String) -> Void
    
    @State private var showingPlaces = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mission header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(mission.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                }
                
                Spacer()
                
                // XP reward
                VStack(spacing: 2) {
                    Text("\(mission.xpReward)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("XP")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.yellow.opacity(0.2))
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(mission.visitedPlaces.count)/\(mission.targetPlaces.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                ProgressView(value: Double(mission.visitedPlaces.count), total: Double(mission.targetPlaces.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 1.5)
            }
            
            // Places to visit
            if !mission.targetPlaces.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Places to Visit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Button(showingPlaces ? "Show Less" : "Show All") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingPlaces.toggle()
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    
                    LazyVStack(spacing: 8) {
                        let placesToShow = showingPlaces ? mission.targetPlaces : Array(mission.targetPlaces.prefix(2))
                        
                        ForEach(placesToShow, id: \.placeId) { targetPlace in
                            MissionPlaceRow(
                                targetPlace: targetPlace,
                                isVisited: mission.visitedPlaces.contains(targetPlace.placeId),
                                onVisit: {
                                    onPlaceVisit(targetPlace.placeId)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Mission Place Row
struct MissionPlaceRow: View {
    let targetPlace: MissionTargetPlace
    let isVisited: Bool
    let onVisit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Visit status
            Button(action: onVisit) {
                Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isVisited ? .green : .white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isVisited)
            
            // Place info
            VStack(alignment: .leading, spacing: 2) {
                Text(targetPlace.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .strikethrough(isVisited)
                
                if !targetPlace.address.isEmpty {
                    Text(targetPlace.address)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Rating
            if targetPlace.rating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    
                    Text(String(format: "%.1f", targetPlace.rating))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(isVisited ? 0.1 : 0.05))
        )
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.15))
        )
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let rank: Int
    let player: LeaderboardPlayer
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("#\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Level \(player.level)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // XP
            Text("\(player.xp) XP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? .white.opacity(0.2) : .white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentUser ? .white.opacity(0.4) : .clear, lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(hex: "#CD7F32") // Bronze
        default: return .blue
        }
    }
}

// MARK: - Mission Tab Enum
enum MissionTab: String, CaseIterable {
    case missions = "missions"
    case leaderboard = "leaderboard"
    
    var title: String {
        switch self {
        case .missions: return "Missions"
        case .leaderboard: return "Leaderboard"
        }
    }
    
    var icon: String {
        switch self {
        case .missions: return "target"
        case .leaderboard: return "trophy.fill"
        }
    }
}

#Preview {
    MissionsView(missionManager: MissionManager(), xpManager: XPManager())
} 