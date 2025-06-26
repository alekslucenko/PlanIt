import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Enhanced Leaderboard Screen
struct EnhancedLeaderboardScreen: View {
    @ObservedObject var xpManager: XPManager
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var selectedTimeframe: LeaderboardTimeframe = .thisMonth
    @State private var currentUserRank: Int = 0
    @State private var animationOffset: CGFloat = 0
    @State private var previousEntries: [LeaderboardEntry] = []
    
    // Real-time listener
    private let db = Firestore.firestore()
    @State private var leaderboardListener: ListenerRegistration?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Leaderboard Header
                    leaderboardHeader
                    
                    // Timeframe Selector
                    timeframeSelector
                    
                    // Top 3 Podium
                    if !leaderboardEntries.isEmpty {
                        topThreePodium
                    }
                    
                    // Current User Position (if not in top 3)
                    if currentUserRank > 3 {
                        currentUserCard
                    }
                    
                    // Full Leaderboard
                    fullLeaderboardSection
                    
                    // Loading State
                    if isLoading {
                        modernLoadingState
                    }
                    
                    // Bottom spacing
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .refreshable {
                await refreshLeaderboard()
            }
        }
        .onAppear {
            startRealtimeLeaderboardListener()
            Task {
                await loadLeaderboard()
            }
        }
        .onDisappear {
            stopRealtimeLeaderboardListener()
        }
    }
    
    // MARK: - Leaderboard Header
    private var leaderboardHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Compete with explorers worldwide")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Trophy icon with animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#ffd700").opacity(0.3), Color(hex: "#ff8c00").opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "#ffd700"))
                        .scaleEffect(1.0 + sin(animationOffset) * 0.1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                animationOffset = .pi * 2
                            }
                        }
                }
            }
            
            // User's current rank summary
            userRankSummary
        }
    }
    
    // MARK: - User Rank Summary
    private var userRankSummary: some View {
        HStack(spacing: 16) {
            rankIndicator(
                title: "Your Rank",
                value: currentUserRank > 0 ? "#\(currentUserRank)" : "—",
                icon: "person.fill",
                color: Color(hex: "#00d4ff")
            )
            
            rankIndicator(
                title: "Your XP",
                value: "\(xpManager.userXP.currentXP)",
                icon: "star.fill",
                color: Color(hex: "#ffd700")
            )
            
            rankIndicator(
                title: "Level",
                value: "\(xpManager.userXP.level)",
                icon: "shield.fill",
                color: Color(hex: "#a8e6cf")
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#00d4ff").opacity(0.3), Color(hex: "#a8e6cf").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(hex: "#00d4ff").opacity(0.1), radius: 16, x: 0, y: 8)
        )
    }
    
    // MARK: - Rank Indicator
    private func rankIndicator(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardTimeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedTimeframe = timeframe
                    }
                    Task {
                        await loadLeaderboard()
                    }
                }) {
                    Text(timeframe.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedTimeframe == timeframe ? Color(hex: "#00d4ff") : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Top Three Podium
    private var topThreePodium: some View {
        VStack(spacing: 20) {
            Text("Top Explorers")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack(alignment: .bottom, spacing: 12) {
                // Second place
                if leaderboardEntries.count > 1 {
                    podiumEntry(entry: leaderboardEntries[1], rank: 2, height: 80)
                }
                
                // First place
                if leaderboardEntries.count > 0 {
                    podiumEntry(entry: leaderboardEntries[0], rank: 1, height: 100)
                }
                
                // Third place
                if leaderboardEntries.count > 2 {
                    podiumEntry(entry: leaderboardEntries[2], rank: 3, height: 60)
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Podium Entry
    private func podiumEntry(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: podiumColors(for: rank),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: rank == 1 ? 70 : 60, height: rank == 1 ? 70 : 60)
                
                if let initial = entry.displayName.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: rank == 1 ? 28 : 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Crown for first place
                if rank == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#ffd700"))
                        .offset(y: -45)
                }
            }
            
            // User info
            VStack(spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: rank == 1 ? 16 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(entry.xp) XP")
                    .font(.system(size: rank == 1 ? 14 : 12, weight: .semibold, design: .rounded))
                    .foregroundColor(podiumColors(for: rank)[0])
            }
            
            // Podium base
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: podiumColors(for: rank).map { $0.opacity(0.8) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height)
                .overlay(
                    Text("#\(rank)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Current User Card
    private var currentUserCard: some View {
        VStack(spacing: 12) {
            Text("Your Position")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            // Real current user entry
            if let currentUserId = Auth.auth().currentUser?.uid {
                LeaderboardEntryRow(
                    entry: LeaderboardEntry(
                        userId: currentUserId, 
                        username: Auth.auth().currentUser?.displayName ?? "You", 
                        displayName: Auth.auth().currentUser?.displayName ?? "You", 
                        xp: xpManager.userXP.currentXP, 
                        level: xpManager.userXP.level,
                        location: "Your Location"
                    ),
                    rank: currentUserRank > 0 ? currentUserRank : leaderboardEntries.count + 1,
                    isCurrentUser: true
                )
            }
        }
    }
    
    // MARK: - Full Leaderboard Section
    private var fullLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Rankings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                LeaderboardEntryRow(entry: entry, rank: index + 1, isCurrentUser: false)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Modern Loading State
    private var modernLoadingState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#ffd700"), Color(hex: "#ff8c00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(animationOffset))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            animationOffset = 360
                        }
                    }
            }
            
            Text("Loading leaderboard...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top, 40)
    }
    
    // MARK: - Helper Methods
    private func loadLeaderboard() async {
        isLoading = true
        
        switch selectedTimeframe {
        case .thisWeek:
            leaderboardEntries = await loadWeeklyLeaderboard()
        case .thisMonth:
            leaderboardEntries = await loadMonthlyLeaderboard()
        case .allTime:
            leaderboardEntries = await loadAllTimeLeaderboard()
        }
        
        // Find current user's rank
        if let currentUserId = Auth.auth().currentUser?.uid {
            currentUserRank = leaderboardEntries.firstIndex(where: { $0.userId == currentUserId }).map { $0 + 1 } ?? 0
        }
        
        isLoading = false
    }
    
    private func refreshLeaderboard() async {
        await loadLeaderboard()
    }
    
    private func loadWeeklyLeaderboard() async -> [LeaderboardEntry] {
        // Get weekly XP data from XPManager
        return await xpManager.getGlobalLeaderboard(limit: 50)
    }
    
    private func loadMonthlyLeaderboard() async -> [LeaderboardEntry] {
        // Get monthly leaderboard
        return await xpManager.getGlobalLeaderboard(limit: 50)
    }
    
    private func loadAllTimeLeaderboard() async -> [LeaderboardEntry] {
        // Get all-time leaderboard
        return await xpManager.getGlobalLeaderboard(limit: 50)
    }
    
    private func podiumColors(for rank: Int) -> [Color] {
        switch rank {
        case 1:
            return [Color(hex: "#ffd700"), Color(hex: "#ffed4e")]
        case 2:
            return [Color(hex: "#c0c0c0"), Color(hex: "#e8e8e8")]
        case 3:
            return [Color(hex: "#cd7f32"), Color(hex: "#deb887")]
        default:
            return [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")]
        }
    }
    
    // MARK: - Real-time Listener Implementation
    private func startRealtimeLeaderboardListener() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthYear = formatter.string(from: Date())
        
        leaderboardListener = db.collection("leaderboard")
            .whereField("monthYear", isEqualTo: monthYear)
            .order(by: "xp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("❌ Leaderboard listener error: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                Task { @MainActor in
                    await self.processRealtimeLeaderboardUpdate(documents: documents)
                }
            }
    }
    
    private func stopRealtimeLeaderboardListener() {
        leaderboardListener?.remove()
        leaderboardListener = nil
    }
    
    @MainActor
    private func processRealtimeLeaderboardUpdate(documents: [QueryDocumentSnapshot]) async {
        // Store previous entries for animation comparison
        previousEntries = leaderboardEntries
        
        var newEntries: [LeaderboardEntry] = []
        
        for (index, document) in documents.enumerated() {
            let data = document.data()
            
            var entry = LeaderboardEntry(
                userId: data["userId"] as? String ?? "",
                username: data["username"] as? String ?? "",
                displayName: data["displayName"] as? String ?? "",
                xp: data["xp"] as? Int ?? 0,
                level: data["level"] as? Int ?? 1,
                location: data["location"] as? String ?? "",
                avatarURL: data["avatarURL"] as? String
            )
            
            entry.rank = index + 1
            newEntries.append(entry)
        }
        
        // Update with animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            leaderboardEntries = newEntries
        }
        
        // Find current user's rank
        if let currentUserId = Auth.auth().currentUser?.uid {
            currentUserRank = leaderboardEntries.firstIndex(where: { $0.userId == currentUserId }).map { $0 + 1 } ?? 0
        }
        
        // Check for rank changes and animate
        animateRankChanges()
        
        isLoading = false
    }
    
    private func animateRankChanges() {
        // Compare previous and current entries to detect rank changes
        for newEntry in leaderboardEntries {
            if let previousEntry = previousEntries.first(where: { $0.userId == newEntry.userId }) {
                if previousEntry.rank != newEntry.rank {
                    // Rank changed - could trigger additional animations here
                    print("🔄 User \(newEntry.displayName) rank changed from \(previousEntry.rank) to \(newEntry.rank)")
                }
            }
        }
    }
}

// MARK: - Leaderboard Entry Row
struct LeaderboardEntryRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    @State private var animationScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank number
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 40, alignment: .leading)
                .fixedSize()
            
            // User avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isCurrentUser ? 
                                [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")] :
                                [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(glowOpacity), lineWidth: 2)
                    )
                
                if let initial = entry.displayName.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                
                HStack {
                    Text(entry.location.isEmpty ? "Explorer" : entry.location)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // XP and Level
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(entry.xp)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize()
                    
                    Text("XP")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                }
                
                HStack(spacing: 4) {
                    Text("Level")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                    
                    Text("\(entry.level)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Group {
                if isCurrentUser {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Material.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "#00d4ff").opacity(0.5), Color(hex: "#a8e6cf").opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: Color(hex: "#00d4ff").opacity(0.2),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                }
            }
        )
        .scaleEffect(animationScale)
        .onAppear {
            if isCurrentUser {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.5
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RankChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let userId = userInfo["userId"] as? String,
               userId == entry.userId {
                animateRankChange()
            }
        }
    }
    
    private func animateRankChange() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            animationScale = 1.1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animationScale = 1.0
            }
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1:
            return Color(hex: "#ffd700")
        case 2:
            return Color(hex: "#c0c0c0")
        case 3:
            return Color(hex: "#cd7f32")
        default:
            return .white
        }
    }
}

// Note: LeaderboardTimeframe enum is defined in AppModels.swift

// MARK: - Preview
struct EnhancedLeaderboardScreen_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedLeaderboardScreen(xpManager: XPManager())
            .background(Color.black)
    }
} 