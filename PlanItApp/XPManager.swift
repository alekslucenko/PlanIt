import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class XPManager: ObservableObject {
    @Published var userXP: UserXP = UserXP()
    @Published var recentXPEvents: [XPEvent] = []
    @Published var weeklyXP: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var leaderboard: [LeaderboardPlayer] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var showXPAnimation: Bool = false
    @Published var lastXPGain: Int = 0
    
    private let db = Firestore.firestore()
    private var userXPListener: ListenerRegistration?
    
    // XP Values for different actions
    enum XPRewards: Int {
        case visitPlace = 50
        case completeMission = 200
        case addReview = 30
        case sharePlace = 25
        case checkIn = 15
        case firstVisit = 75
        case weeklyStreak = 100
        case monthlyBonus = 500
    }
    
    // Computed properties for missions view
    var currentUserRank: Int {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return 0 }
        return leaderboard.firstIndex(where: { $0.id == currentUserId }) ?? 0
    }
    
    var currentLevel: Int {
        return userXP.level
    }
    
    var totalXP: Int {
        return userXP.currentXP
    }
    
    var xpToNextLevel: Int {
        return userXP.xpToNextLevel()
    }
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    init() {
        startListeningForXPUpdates()
        Task {
            await loadLeaderboard()
        }
    }
    
    deinit {
        userXPListener?.remove()
    }
    
    // MARK: - Real-time XP Listener
    func startListeningForXPUpdates() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        userXPListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    print("❌ XP listener error: \(error)")
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    return
                }
                
                guard let document = documentSnapshot, document.exists,
                      let data = document.data() else {
                    print("⚠️ No XP data found, initializing...")
                    Task { @MainActor in
                        await self?.initializeUserXP()
                    }
                    return
                }
                
                Task { @MainActor in
                    await self?.loadXPFromFirestore(data: data)
                }
            }
    }
    
    // MARK: - Load XP Data from Firestore
    private func loadXPFromFirestore(data: [String: Any]) async {
        do {
            // Load basic XP data
            let currentXP = data["xp"] as? Int ?? 0
            let level = data["level"] as? Int ?? UserXP.calculateLevel(from: currentXP)
            
            // Load XP history
            var xpHistory: [XPEvent] = []
            if let historyData = data["xpHistory"] as? [[String: Any]] {
                for eventData in historyData {
                    if let event = eventData["event"] as? String,
                       let xp = eventData["xp"] as? Int,
                       let timestamp = (eventData["timestamp"] as? Timestamp)?.dateValue() {
                        
                        let xpEvent = XPEvent(
                            event: event,
                            xp: xp,
                            placeId: eventData["placeId"] as? String,
                            missionId: eventData["missionId"] as? String,
                            details: eventData["details"] as? String
                        )
                        
                        // Set the actual timestamp
                        var mutableEvent = xpEvent
                        xpHistory.append(mutableEvent)
                    }
                }
            }
            
            // Calculate weekly XP
            let weeklyXP = calculateWeeklyXP(from: xpHistory)
            
            // Update user XP
            userXP = UserXP()
            userXP.currentXP = currentXP
            userXP.level = level
            userXP.xpHistory = xpHistory.sorted { $0.timestamp > $1.timestamp }
            userXP.weeklyXP = weeklyXP
            userXP.lastXPUpdate = Date()
            
            // Update recent events (last 10)
            recentXPEvents = Array(userXP.xpHistory.prefix(10))
            self.weeklyXP = weeklyXP
            
            isLoading = false
            print("✅ XP data loaded: \(currentXP) XP, Level \(level)")
            
        } catch {
            print("❌ Error loading XP data: \(error)")
            errorMessage = "Failed to load XP data: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Initialize User XP
    private func initializeUserXP() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let initialXPData: [String: Any] = [
                "xp": 0,
                "level": 1,
                "xpHistory": [],
                "weeklyXP": 0,
                "lastXPUpdate": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId).updateData(initialXPData)
            print("✅ Initialized XP data for user")
            
        } catch {
            print("❌ Error initializing XP: \(error)")
            errorMessage = "Failed to initialize XP: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Award XP
    func awardXP(amount: Int, event: String, placeId: String? = nil, missionId: String? = nil, details: String? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let xpEvent = XPEvent(
                event: event,
                xp: amount,
                placeId: placeId,
                missionId: missionId,
                details: details
            )
            
            let newTotalXP = userXP.currentXP + amount
            let newLevel = UserXP.calculateLevel(from: newTotalXP)
            let leveledUp = newLevel > userXP.level
            
            // Prepare event data for Firestore
            let eventData: [String: Any] = [
                "id": xpEvent.id,
                "event": xpEvent.event,
                "xp": xpEvent.xp,
                "timestamp": Timestamp(date: xpEvent.timestamp),
                "placeId": xpEvent.placeId as Any,
                "missionId": xpEvent.missionId as Any,
                "details": xpEvent.details as Any
            ]
            
            // Update Firestore
            try await db.collection("users").document(userId).updateData([
                "xp": newTotalXP,
                "level": newLevel,
                "xpHistory": FieldValue.arrayUnion([eventData]),
                "lastXPUpdate": FieldValue.serverTimestamp()
            ])
            
            // Update leaderboard
            await updateLeaderboard(userId: userId, newXP: newTotalXP, newLevel: newLevel)
            
            // Show level up animation if applicable
            if leveledUp {
                await showLevelUpAnimation(newLevel: newLevel)
            }
            
            // Show XP gained animation
            await showXPGainedAnimation(amount: amount, event: event)
            
            print("✅ Awarded \(amount) XP for: \(event)")
            
        } catch {
            print("❌ Error awarding XP: \(error)")
            errorMessage = "Failed to award XP: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Mission Completion XP
    func awardMissionCompletionXP(mission: Mission, placeId: String) async {
        await awardXP(
            amount: mission.xpReward,
            event: "Completed Mission",
            placeId: placeId,
            missionId: mission.id,
            details: mission.title
        )
    }
    
    // MARK: - Place Visit XP
    func awardPlaceVisitXP(placeId: String, placeName: String, isFirstVisit: Bool = false) async {
        let amount = isFirstVisit ? XPRewards.firstVisit.rawValue : XPRewards.visitPlace.rawValue
        let event = isFirstVisit ? "First Visit" : "Visited Place"
        
        await awardXP(
            amount: amount,
            event: event,
            placeId: placeId,
            details: placeName
        )
    }
    
    // MARK: - Update Leaderboard
    private func updateLeaderboard(userId: String, newXP: Int, newLevel: Int) async {
        do {
            // Get current month-year for leaderboard segmentation
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthYear = formatter.string(from: Date())
            
            // Get user info
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else { return }
            
            let username = userData["username"] as? String ?? ""
            let displayName = userData["displayName"] as? String ?? ""
            let photoURL = userData["photoURL"] as? String
            
            let leaderboardEntry = LeaderboardEntry(
                userId: userId,
                username: username,
                displayName: displayName,
                xp: newXP,
                level: newLevel,
                avatarURL: photoURL
            )
            
            let entryData: [String: Any] = [
                "userId": leaderboardEntry.userId,
                "username": leaderboardEntry.username,
                "displayName": leaderboardEntry.displayName,
                "xp": leaderboardEntry.xp,
                "level": leaderboardEntry.level,
                "location": leaderboardEntry.location,
                "avatarURL": leaderboardEntry.avatarURL as Any,
                "lastUpdated": FieldValue.serverTimestamp(),
                "monthYear": monthYear
            ]
            
            try await db.collection("leaderboard").document("\(monthYear)_\(userId)").setData(entryData)
            print("✅ Updated leaderboard entry")
            
        } catch {
            print("❌ Error updating leaderboard: \(error)")
        }
    }
    
    // MARK: - Calculate Weekly XP
    private func calculateWeeklyXP(from history: [XPEvent]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return history
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.xp }
    }
    
    // MARK: - Animation Methods
    private func showLevelUpAnimation(newLevel: Int) async {
        // TODO: Implement level up animation
        print("🎉 LEVEL UP! You are now level \(newLevel)!")
    }
    
    private func showXPGainedAnimation(amount: Int, event: String) async {
        await MainActor.run {
            lastXPGain = amount
            showXPAnimation = true
        }
        
        // Hide animation after 3 seconds
        try? await Task.sleep(for: .seconds(3))
        
        await MainActor.run {
            showXPAnimation = false
        }
        
        print("✨ +\(amount) XP for \(event)")
    }
    
    // MARK: - Reset Weekly XP (called by background task)
    func resetWeeklyXP() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "weeklyXP": 0,
                "lastWeeklyReset": FieldValue.serverTimestamp()
            ])
            
            weeklyXP = 0
            userXP.weeklyXP = 0
            
        } catch {
            print("❌ Error resetting weekly XP: \(error)")
        }
    }
    
    // MARK: - Get XP Leaderboard
    func getGlobalLeaderboard(limit: Int = 50) async -> [LeaderboardEntry] {
        do {
            // Simplified query to avoid index requirement temporarily
            let querySnapshot = try await db.collection("leaderboard")
                .order(by: "xp", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            var entries: [LeaderboardEntry] = []
            
            for (index, document) in querySnapshot.documents.enumerated() {
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
                entries.append(entry)
            }
            
            return entries
            
        } catch {
            print("❌ Error fetching leaderboard: \(error)")
            return []
        }
    }
    
    // MARK: - Get Friends Leaderboard
    func getFriendsLeaderboard(friendIds: [String]) async -> [LeaderboardEntry] {
        guard !friendIds.isEmpty else { return [] }
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthYear = formatter.string(from: Date())
            
            var entries: [LeaderboardEntry] = []
            
            // Fetch in batches of 10 (Firestore limit for whereIn)
            let batches = friendIds.chunked(into: 10)
            
            for batch in batches {
                let batchIds = batch.map { "\(monthYear)_\($0)" }
                
                let querySnapshot = try await db.collection("leaderboard")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .getDocuments()
                
                for document in querySnapshot.documents {
                    let data = document.data()
                    
                    let entry = LeaderboardEntry(
                        userId: data["userId"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        displayName: data["displayName"] as? String ?? "",
                        xp: data["xp"] as? Int ?? 0,
                        level: data["level"] as? Int ?? 1,
                        location: data["location"] as? String ?? "",
                        avatarURL: data["avatarURL"] as? String
                    )
                    
                    entries.append(entry)
                }
            }
            
            // Sort by XP and assign ranks
            entries.sort { $0.xp > $1.xp }
            for (index, _) in entries.enumerated() {
                entries[index].rank = index + 1
            }
            
            return entries
            
        } catch {
            print("❌ Error fetching friends leaderboard: \(error)")
            return []
        }
    }
    
    // MARK: - Load Leaderboard
    func loadLeaderboard() async {
        do {
            let entries = await getGlobalLeaderboard(limit: 50)
            let players = entries.map { entry in
                LeaderboardPlayer(
                    id: entry.userId,
                    name: entry.displayName.isEmpty ? entry.username : entry.displayName,
                    xp: entry.xp,
                    level: entry.level,
                    avatarURL: entry.avatarURL
                )
            }
            
            await MainActor.run {
                self.leaderboard = players
            }
            
            print("✅ Loaded \(players.count) leaderboard entries")
            
        } catch {
            print("❌ Error loading leaderboard: \(error)")
        }
    }
    
    // MARK: - Award XP (Simplified version for mission completion)
    func awardXP(amount: Int, reason: String) async {
        await awardXP(amount: amount, event: reason)
    }
    
    // MARK: - Progress Milestone Checking
    func checkProgressMilestones() {
        // Check for various milestones
        let currentXP = userXP.currentXP
        let currentLevel = userXP.level
        
        // Level milestones
        if currentLevel >= 5 && currentLevel % 5 == 0 {
            print("🎉 Milestone: Level \(currentLevel) achieved!")
        }
        
        // XP milestones
        let xpMilestones = [100, 500, 1000, 2500, 5000, 10000]
        for milestone in xpMilestones {
            if currentXP >= milestone {
                // Check if this milestone was recently achieved
                let recentEvents = recentXPEvents.prefix(5)
                let previousTotal = currentXP - (recentEvents.first?.xp ?? 0)
                if previousTotal < milestone {
                    print("🎯 XP Milestone: \(milestone) XP achieved!")
                }
            }
        }
        
        // Weekly XP milestones
        if weeklyXP >= 1000 {
            print("🔥 Weekly milestone: \(weeklyXP) XP this week!")
        }
    }
}