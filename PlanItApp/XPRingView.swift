import SwiftUI

struct XPRingView: View {
    @ObservedObject var xpManager: XPManager
    @State private var animatedProgress: Double = 0
    @State private var showXPLog = false
    @State private var ringRotation: Double = 0
    @State private var glowIntensity: Double = 0.5
    @State private var levelPulse: CGFloat = 1.0
    @State private var sparkleOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 28) {
            // Professional XP Ring with advanced animations
            professionalXPRing
            
            // Enhanced XP Statistics
            xpStatisticsGrid
            
            // Weekly Progress Card
            weeklyProgressCard
            
            // XP History Preview
            xpHistoryPreview
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: xpManager.userXP.currentXP) { _ in
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animatedProgress = xpManager.userXP.progressToNextLevel()
            }
        }
        .sheet(isPresented: $showXPLog) {
            EnhancedXPLogView(xpManager: xpManager)
        }
    }
    
    // MARK: - Professional XP Ring
    private var professionalXPRing: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#00d4ff").opacity(glowIntensity * 0.3),
                            Color(hex: "#a8e6cf").opacity(glowIntensity * 0.2),
                            Color(hex: "#00d4ff").opacity(glowIntensity * 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .frame(width: 200, height: 200)
                .blur(radius: 12)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowIntensity)
            
            // Background ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 16
                )
                .frame(width: 180, height: 180)
            
            // Animated progress ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: "#00d4ff"),
                            Color(hex: "#0099cc"),
                            Color(hex: "#a8e6cf"),
                            Color(hex: "#4ecdc4"),
                            Color(hex: "#00d4ff")
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90 + ringRotation))
                .shadow(
                    color: Color(hex: "#00d4ff").opacity(0.6),
                    radius: 8,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 2.0, dampingFraction: 0.8), value: animatedProgress)
            
            // Sparkle effects around the ring
            ForEach(0..<8, id: \.self) { index in
                sparkleEffect(at: index)
            }
            
            // Inner content with professional styling
            VStack(spacing: 12) {
                // Level indicator
                VStack(spacing: 4) {
                    Text("LEVEL")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    
                    Text("\(xpManager.userXP.level)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(levelPulse)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: levelPulse)
                }
                
                // XP Progress
                VStack(spacing: 6) {
                    Text("\(xpManager.userXP.currentXP) XP")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(xpManager.userXP.xpToNextLevel()) to next level")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            
            // Progress percentage indicator
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#00d4ff"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#00d4ff").opacity(0.3), lineWidth: 1)
                                )
                        )
                        .offset(x: -30, y: -30)
                }
            }
        }
        .frame(width: 200, height: 200)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showXPLog = true
            }
        }
    }
    
    // MARK: - Sparkle Effect
    private func sparkleEffect(at index: Int) -> some View {
        let angle = Double(index) * 45.0
        let radius: CGFloat = 100
        
        return Circle()
            .fill(Color(hex: "#00d4ff").opacity(0.8))
            .frame(width: 6, height: 6)
            .offset(
                x: cos(angle * .pi / 180 + sparkleOffset) * radius,
                y: sin(angle * .pi / 180 + sparkleOffset) * radius
            )
            .opacity(animatedProgress > Double(index) / 8.0 ? 1.0 : 0.3)
            .scaleEffect(animatedProgress > Double(index) / 8.0 ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 2).delay(Double(index) * 0.1), value: animatedProgress)
    }
    
    // MARK: - XP Statistics Grid
    private var xpStatisticsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statCard(
                title: "Total XP",
                value: "\(xpManager.userXP.currentXP)",
                subtitle: "Experience Points",
                icon: "star.fill",
                color: Color(hex: "#ffd700"),
                trend: "+\(weeklyXPGain)"
            )
            
            statCard(
                title: "Places Visited",
                value: "\(placesVisitedCount)",
                subtitle: "Locations Explored",
                icon: "location.fill",
                color: Color(hex: "#4ecdc4"),
                trend: "+\(recentPlaceVisits)"
            )
            
            statCard(
                title: "Missions",
                value: "\(missionsCompletedCount)",
                subtitle: "Completed",
                icon: "target",
                color: Color(hex: "#9b59b6"),
                trend: "+\(recentMissions)"
            )
        }
    }
    
    // MARK: - Stat Card
    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color, trend: String) -> some View {
        VStack(spacing: 8) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Stats
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Trend indicator
                if !trend.isEmpty && trend != "+0" {
                    Text(trend)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.1))
                        )
                }
            }
        }
        .frame(minHeight: 100)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - Weekly Progress Card
    private var weeklyProgressCard: some View {
        Button(action: { showXPLog = true }) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Week's Progress")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Keep exploring to maintain your streak")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Weekly XP badge
                    VStack(spacing: 4) {
                        Text("\(xpManager.weeklyXP)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#00d4ff"))
                        
                        Text("XP")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#00d4ff"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#00d4ff").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#00d4ff").opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Weekly progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00d4ff"), Color(hex: "#a8e6cf")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * weeklyProgressPercentage,
                                height: 8
                            )
                            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: weeklyProgressPercentage)
                    }
                }
                .frame(height: 8)
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
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - XP History Preview
    private var xpHistoryPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    showXPLog = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#00d4ff"))
            }
            
            // Recent XP events preview
            ForEach(Array(xpManager.userXP.xpHistory.prefix(3))) { event in
                compactXPEventRow(event: event)
            }
            
            if xpManager.userXP.xpHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("Start exploring to earn XP!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Compact XP Event Row
    private func compactXPEventRow(event: XPEvent) -> some View {
        HStack(spacing: 12) {
            // Event icon
            ZStack {
                Circle()
                    .fill(eventColor(for: event).opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: eventIcon(for: event))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(eventColor(for: event))
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.event)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(timeAgoString(from: event.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // XP badge
            Text("+\(event.xp)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(eventColor(for: event).opacity(0.3))
                )
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Animation Control
    private func startAnimations() {
        // Start progress animation
        withAnimation(.spring(response: 2.0, dampingFraction: 0.8).delay(0.5)) {
            animatedProgress = xpManager.userXP.progressToNextLevel()
        }
        
        // Start glow animation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
        
        // Start level pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            levelPulse = 1.05
        }
        
        // Start ring rotation
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        
        // Start sparkle animation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            sparkleOffset = .pi * 2
        }
    }
    
    // MARK: - Computed Properties
    private var weeklyXPGain: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return xpManager.userXP.xpHistory
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.xp }
    }
    
    private var placesVisitedCount: Int {
        return xpManager.userXP.xpHistory.filter { $0.event.contains("Visit") }.count
    }
    
    private var missionsCompletedCount: Int {
        return xpManager.userXP.xpHistory.filter { $0.event.contains("Mission") }.count
    }
    
    private var recentPlaceVisits: Int {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        
        return xpManager.userXP.xpHistory
            .filter { $0.timestamp >= threeDaysAgo && $0.event.contains("Visit") }
            .count
    }
    
    private var recentMissions: Int {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        
        return xpManager.userXP.xpHistory
            .filter { $0.timestamp >= threeDaysAgo && $0.event.contains("Mission") }
            .count
    }
    
    private var weeklyProgressPercentage: Double {
        let targetWeeklyXP = 500.0 // Target weekly XP
        return min(Double(xpManager.weeklyXP) / targetWeeklyXP, 1.0)
    }
    
    private func eventColor(for event: XPEvent) -> Color {
        switch event.event {
        case _ where event.event.contains("Mission"):
            return Color(hex: "#9b59b6")
        case _ where event.event.contains("Visit"):
            return Color(hex: "#4ecdc4")
        case _ where event.event.contains("Review"):
            return Color(hex: "#2ecc71")
        default:
            return Color(hex: "#ffd700")
        }
    }
    
    private func eventIcon(for event: XPEvent) -> String {
        switch event.event {
        case _ where event.event.contains("Mission"):
            return "target"
        case _ where event.event.contains("Visit"):
            return "location.fill"
        case _ where event.event.contains("Review"):
            return "star.fill"
        default:
            return "plus.circle.fill"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
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

// MARK: - Enhanced XP Log View
struct EnhancedXPLogView: View {
    @ObservedObject var xpManager: XPManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: XPEventFilter = .all
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(hex: "#0a0a0a"),
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Filter buttons
                        filterButtons
                        
                        // Filtered events
                        ForEach(filteredEvents) { event in
                            EnhancedXPEventRow(event: event)
                        }
                        
                        if filteredEvents.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("XP History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#00d4ff"))
                }
            }
        }
    }
    
    // MARK: - Filter Buttons
    private var filterButtons: some View {
        HStack(spacing: 0) {
            ForEach(XPEventFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(filter.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    selectedFilter == filter ?
                                    LinearGradient(
                                        colors: [Color(hex: "#00d4ff"), Color(hex: "#0099cc")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No XP events yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Start exploring to earn XP!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.top, 60)
    }
    
    // MARK: - Computed Properties
    private var filteredEvents: [XPEvent] {
        switch selectedFilter {
        case .all:
            return xpManager.userXP.xpHistory
        case .missions:
            return xpManager.userXP.xpHistory.filter { $0.event.contains("Mission") }
        case .visits:
            return xpManager.userXP.xpHistory.filter { $0.event.contains("Visit") }
        case .reviews:
            return xpManager.userXP.xpHistory.filter { $0.event.contains("Review") }
        }
    }
}

// MARK: - Enhanced XP Event Row
struct EnhancedXPEventRow: View {
    let event: XPEvent
    
    var body: some View {
        HStack(spacing: 16) {
            // Event icon with enhanced styling
            ZStack {
                Circle()
                    .fill(eventColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: eventIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(eventColor)
            }
            .shadow(color: eventColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Event details
            VStack(alignment: .leading, spacing: 6) {
                Text(event.event)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let details = event.details {
                    Text(details)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Text(timeAgoString(from: event.timestamp))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // XP badge with enhanced design
            VStack(spacing: 4) {
                Text("+\(event.xp)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("XP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(eventColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(eventColor.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Computed Properties
    private var eventColor: Color {
        switch event.event {
        case _ where event.event.contains("Mission"):
            return Color(hex: "#9b59b6")
        case _ where event.event.contains("Visit"):
            return Color(hex: "#4ecdc4")
        case _ where event.event.contains("Review"):
            return Color(hex: "#2ecc71")
        default:
            return Color(hex: "#ffd700")
        }
    }
    
    private var eventIcon: String {
        switch event.event {
        case _ where event.event.contains("Mission"):
            return "target"
        case _ where event.event.contains("Visit"):
            return "location.fill"
        case _ where event.event.contains("Review"):
            return "star.fill"
        default:
            return "plus.circle.fill"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
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

// MARK: - XP Event Filter
enum XPEventFilter: String, CaseIterable {
    case all = "all"
    case missions = "missions"
    case visits = "visits"
    case reviews = "reviews"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .missions: return "Missions"
        case .visits: return "Visits"
        case .reviews: return "Reviews"
        }
    }
}

// MARK: - Preview
struct XPRingView_Previews: PreviewProvider {
    static var previews: some View {
        XPRingView(xpManager: XPManager())
            .background(Color.black)
    }
} 