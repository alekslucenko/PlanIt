import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
import CoreLocation

@MainActor
class MissionManager: ObservableObject {
    @Published var activeMissions: [Mission] = []
    @Published var completedMissions: [Mission] = []
    @Published var dailyMissions: [Mission] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isGeneratingMission: Bool = false
    
    private let db = Firestore.firestore()
    private var missionsListener: ListenerRegistration?
    private let geminiService = GeminiAIService.shared
    private var xpManager: XPManager?
    private let fingerprintManager = UserFingerprintManager.shared
    private let placesService = GooglePlacesService()
    
    // Enhanced mission generation settings
    private let maxActiveMissions = 5 // Increased from 3
    let dailyMissionGoal = 5 // New daily goal
    private let missionRefreshHours = 6
    
    // New properties for enhanced functionality
    @Published var dailyMissionsGenerated: Int = 0
    @Published var lastDailyMissionGeneration: Date?
    
    init() {
        startListeningForMissions()
        loadDailyMissionStats()
    }
    
    deinit {
        missionsListener?.remove()
    }
    
    func setXPManager(_ xpManager: XPManager) {
        self.xpManager = xpManager
    }
    
    // MARK: - Real-time Missions Listener
    func startListeningForMissions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        missionsListener = db.collection("users").document(userId).collection("missions")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ Missions listener error: \(error)")
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ No missions found")
                    self?.isLoading = false
                    return
                }
                
                Task { @MainActor in
                    await self?.loadMissionsFromSnapshot(documents: documents)
                }
            }
    }
    
    // MARK: - Load Missions from Firestore
    private func loadMissionsFromSnapshot(documents: [QueryDocumentSnapshot]) async {
        var active: [Mission] = []
        var completed: [Mission] = []
        
        for document in documents {
            if let mission = parseMissionFromDocument(document) {
                if mission.status == .completed {
                    completed.append(mission)
                } else if mission.status == .active {
                    active.append(mission)
                }
            }
        }
        
        activeMissions = active
        completedMissions = completed
        isLoading = false
        
        print("✅ Loaded \(active.count) active missions, \(completed.count) completed")
        
        // Generate new missions if needed
        if activeMissions.count < maxActiveMissions {
            await generateMissionsIfNeeded()
        }
    }
    
    // MARK: - Parse Mission from Firestore Document
    private func parseMissionFromDocument(_ document: QueryDocumentSnapshot) -> Mission? {
        let data = document.data()
        
        guard let title = data["title"] as? String,
              let prompt = data["prompt"] as? String,
              let xpReward = data["xpReward"] as? Int,
              let vibeTag = data["vibeTag"] as? String,
              let locationType = data["locationType"] as? String,
              let statusString = data["status"] as? String,
              let status = MissionStatus(rawValue: statusString),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let userId = data["userId"] as? String,
              let placeOptionsData = data["placeOptions"] as? [[String: Any]] else {
            print("❌ Invalid mission data in document: \(document.documentID)")
            return nil
        }
        
        // Parse place options
        var placeOptions: [MissionPlace] = []
        for placeData in placeOptionsData {
            if let placeId = placeData["placeId"] as? String,
               let name = placeData["name"] as? String,
               let address = placeData["address"] as? String {
                
                var place = MissionPlace(placeId: placeId, name: name, address: address)
                place.completed = placeData["completed"] as? Bool ?? false
                if let completedAt = (placeData["completedAt"] as? Timestamp)?.dateValue() {
                    place.completedAt = completedAt
                }
                placeOptions.append(place)
            }
        }
        
        // Create mission
        var mission = Mission(
            title: title,
            prompt: prompt,
            xpReward: xpReward,
            vibeTag: vibeTag,
            locationType: locationType,
            placeOptions: placeOptions,
            userId: userId
        )
        
        // Update with Firestore data
        mission = Mission(
            title: title,
            prompt: prompt,
            xpReward: xpReward,
            vibeTag: vibeTag,
            locationType: locationType,
            placeOptions: placeOptions,
            userId: userId
        )
        
        if let completedAt = (data["completedAt"] as? Timestamp)?.dateValue() {
            // Set completed at
        }
        
        return mission
    }
    
    // MARK: - Generate New Missions with Gemini AI
    func generateMissionsIfNeeded() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard activeMissions.count < maxActiveMissions else { return }
        guard !isGeneratingMission else { return }
        
        isGeneratingMission = true
        
        do {
            // Get user's onboarding data for personalization
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            
            let missionsToGenerate = maxActiveMissions - activeMissions.count
            
            for _ in 0..<missionsToGenerate {
                await generateSingleMission(userData: userData, userId: userId)
                
                // Small delay between generations to avoid rate limiting
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
        } catch {
            print("❌ Error generating missions: \(error)")
            errorMessage = "Failed to generate missions: \(error.localizedDescription)"
        }
        
        isGeneratingMission = false
    }
    
    // MARK: - Generate Single Mission
    private func generateSingleMission(userData: [String: Any], userId: String) async {
        do {
            // Create personalized prompt based on user data
            let prompt = createPersonalizedPrompt(from: userData)
            
            // Call Gemini AI to generate mission
            let missionResponse = try await geminiService.generateMissionIdeas(prompt: prompt)
            
            // Parse the response and create mission
            if let mission = parseMissionFromGeminiResponse(missionResponse, userId: userId) {
                // Save to Firestore
                try await saveMissionToFirestore(mission)
                print("✅ Generated and saved new mission: \(mission.title)")
            }
            
        } catch {
            print("❌ Error generating single mission: \(error)")
        }
    }
    
    // MARK: - Create Personalized Prompt
    private func createPersonalizedPrompt(from userData: [String: Any]) -> String {
        var prompt = """
        Generate a unique, fun exploration mission for a user based on their preferences.
        
        User Profile:
        """
        
        // Add user preferences from onboarding data
        if let onboardingData = userData["onboarding"] as? [String: Any] {
            if let responses = onboardingData["responses"] as? [[String: Any]] {
                prompt += "\nPreferences:"
                for response in responses.prefix(5) { // Limit to avoid too long prompts
                    if let questionId = response["questionId"] as? String,
                       let selectedOptions = response["selectedOptions"] as? [String] {
                        prompt += "\n- \(questionId): \(selectedOptions.joined(separator: ", "))"
                    }
                }
            }
        }
        
        prompt += """
        
        Please generate 1 mission that is:
        1. Unique and creative (not generic)
        2. Tied to specific types of places
        3. Achievable in a single visit
        4. Meaningful and engaging
        
        Respond in this JSON format:
        {
            "title": "Creative mission title",
            "prompt": "Detailed mission description",
            "xpReward": 150-300,
            "vibeTag": "descriptive tag",
            "locationType": "restaurant/cafe/park/museum/etc",
            "placeOptions": [
                {
                    "name": "Specific place name",
                    "address": "Full address",
                    "placeId": "mock_place_id_1"
                }
            ]
        }
        
        Make the mission personal and exciting!
        """
        
        return prompt
    }
    
    // MARK: - Parse Mission from Gemini Response
    private func parseMissionFromGeminiResponse(_ response: String, userId: String) -> Mission? {
        // Extract JSON from the response
        guard let jsonString = extractJSON(from: response),
              let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Could not extract JSON from Gemini response")
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let title = json?["title"] as? String,
                  let prompt = json?["prompt"] as? String,
                  let xpReward = json?["xpReward"] as? Int,
                  let vibeTag = json?["vibeTag"] as? String,
                  let locationType = json?["locationType"] as? String,
                  let placeOptionsData = json?["placeOptions"] as? [[String: Any]] else {
                print("❌ Invalid JSON structure from Gemini")
                return nil
            }
            
            // Parse place options
            var placeOptions: [MissionPlace] = []
            for placeData in placeOptionsData {
                if let name = placeData["name"] as? String,
                   let address = placeData["address"] as? String,
                   let placeId = placeData["placeId"] as? String {
                    
                    let place = MissionPlace(placeId: placeId, name: name, address: address)
                    placeOptions.append(place)
                }
            }
            
            let mission = Mission(
                title: title,
                prompt: prompt,
                xpReward: xpReward,
                vibeTag: vibeTag,
                locationType: locationType,
                placeOptions: placeOptions,
                userId: userId
            )
            
            return mission
            
        } catch {
            print("❌ Error parsing JSON from Gemini: \(error)")
            return nil
        }
    }
    
    // MARK: - Extract JSON from Response
    private func extractJSON(from response: String) -> String? {
        // Safe JSON extraction to prevent index out of bounds
        let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for JSON content between { and }
        guard let startIndex = cleanedResponse.firstIndex(of: "{"),
              let endIndex = cleanedResponse.lastIndex(of: "}") else {
            print("❌ No JSON braces found in response")
            return nil
        }
        
        // Ensure valid range
        guard startIndex <= endIndex else {
            print("❌ Invalid JSON range detected")
            return nil
        }
        
        let jsonString = String(cleanedResponse[startIndex...endIndex])
        
        // Validate that we have a reasonable JSON structure
        guard jsonString.count > 2 else {
            print("❌ JSON string too short: \(jsonString)")
            return nil
        }
        
        return jsonString
    }
    
    // MARK: - Enhanced Daily Mission Generation
    func generateDailyMissions() async {
        guard !isGeneratingMission else { return }
        
        isGeneratingMission = true
        
        // Check if daily missions were already generated today
        let today = Calendar.current.startOfDay(for: Date())
        if let lastGeneration = lastDailyMissionGeneration,
           Calendar.current.isDate(lastGeneration, inSameDayAs: today),
           !dailyMissions.isEmpty {
            print("✅ Daily missions already generated today")
            isGeneratingMission = false
            return
        }
        
        print("🎯 Generating daily missions for today...")
        
        // Generate 4 daily missions
        var newDailyMissions: [Mission] = []
        
        for i in 0..<4 {
            if let mission = await generateSingleDailyMission(index: i) {
                newDailyMissions.append(mission)
            }
            
            // Small delay between generations
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        dailyMissions = newDailyMissions
        lastDailyMissionGeneration = Date()
        
        // Save daily mission stats
        await updateDailyMissionStats()
        
        print("✅ Generated \(newDailyMissions.count) daily missions")
        isGeneratingMission = false
    }
    
    private func generateSingleDailyMission(index: Int) async -> Mission? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        
        let missionTypes = ["restaurant", "cafe", "bars", "venues"]
        let selectedType = missionTypes[index % missionTypes.count]
        
        // Get user location
        let userLocation = getCurrentUserLocation()
        
        // Search for real places
        let searchQuery = getDailyMissionSearchQuery(type: selectedType, index: index)
        
        let googlePlaces = await withCheckedContinuation { continuation in
            placesService.searchPlacesByText(
                query: searchQuery,
                location: userLocation,
                radius: 3000 // 3km radius for daily missions
            ) { places in
                continuation.resume(returning: places)
            }
        }
        
        guard !googlePlaces.isEmpty else {
            print("❌ No places found for daily mission type: \(selectedType)")
            return nil
        }
        
        // Select 2-3 places for the mission
        let selectedPlaces = Array(googlePlaces.prefix(3))
        
        // Convert to mission target places
        let targetPlaces = selectedPlaces.map { googlePlace in
            MissionTargetPlace(
                placeId: googlePlace.placeId,
                name: googlePlace.name,
                address: googlePlace.address,
                rating: googlePlace.rating ?? 0.0,
                category: selectedType
            )
        }
        
        // Create mission
        let mission = Mission(
            id: UUID().uuidString,
            title: getDailyMissionTitle(type: selectedType, index: index),
            description: getDailyMissionDescription(type: selectedType),
            targetPlaces: targetPlaces,
            visitedPlaces: [],
            xpReward: getDailyMissionXPReward(type: selectedType),
            createdAt: Date(),
            status: .active,
            isDaily: true
        )
        
        return mission
    }
    
    private func getDailyMissionSearchQuery(type: String, index: Int) -> String {
        let queries: [String: [String]] = [
            "restaurant": [
                "restaurants near me",
                "local dining restaurants",
                "popular restaurants",
                "trending restaurants"
            ],
            "cafe": [
                "coffee shops near me",
                "cafes near me",
                "local coffee shops",
                "popular cafes"
            ],
            "bars": [
                "bars near me",
                "cocktail bars",
                "local bars",
                "popular bars"
            ],
            "venues": [
                "entertainment venues",
                "activities near me",
                "venues near me",
                "entertainment"
            ]
        ]
        
        let typeQueries = queries[type] ?? ["places near me"]
        return typeQueries[index % typeQueries.count]
    }
    
    private func getDailyMissionTitle(type: String, index: Int) -> String {
        let titles: [String: [String]] = [
            "restaurant": [
                "Culinary Explorer",
                "Food Adventure",
                "Taste Quest",
                "Dining Discovery"
            ],
            "cafe": [
                "Coffee Connoisseur",
                "Cafe Hopper",
                "Bean Counter",
                "Caffeine Quest"
            ],
            "bars": [
                "Happy Hour Hero",
                "Cocktail Seeker",
                "Bar Explorer",
                "Nightlife Navigator"
            ],
            "venues": [
                "Activity Hunter",
                "Fun Finder",
                "Entertainment Explorer",
                "Adventure Seeker"
            ]
        ]
        
        let typeTitles = titles[type] ?? ["Explorer"]
        return typeTitles[index % typeTitles.count]
    }
    
    private func getDailyMissionDescription(type: String) -> String {
        let descriptions: [String: String] = [
            "restaurant": "Discover amazing local restaurants and expand your culinary horizons",
            "cafe": "Find cozy coffee shops and enjoy the perfect brew",
            "bars": "Explore the local nightlife and discover great places for drinks",
            "venues": "Find fun activities and entertainment venues in your area"
        ]
        
        return descriptions[type] ?? "Explore local places and earn XP"
    }
    
    private func getDailyMissionXPReward(type: String) -> Int {
        let rewards: [String: Int] = [
            "restaurant": 200,
            "cafe": 150,
            "bars": 175,
            "venues": 225
        ]
        
        return rewards[type] ?? 200
    }
    
    private func getCurrentUserLocation() -> CLLocation {
        // Try to get user location from fingerprint or location manager
        if let fingerprintLocation = fingerprintManager.fingerprint?.currentLocation {
            return CLLocation(latitude: fingerprintLocation.latitude, longitude: fingerprintLocation.longitude)
        }
        
        // Default to San Francisco
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    
    // MARK: - Mission Progress Tracking
    func markPlaceAsVisited(missionId: String, placeId: String) async {
        // Update daily missions
        if let index = dailyMissions.firstIndex(where: { $0.id == missionId }) {
            if !dailyMissions[index].visitedPlaces.contains(placeId) {
                dailyMissions[index].visitedPlaces.append(placeId)
                print("✅ Marked place as visited for daily mission: \(missionId)")
            }
        }
        
        // Update active missions
        if let index = activeMissions.firstIndex(where: { $0.id == missionId }) {
            if !activeMissions[index].visitedPlaces.contains(placeId) {
                activeMissions[index].visitedPlaces.append(placeId)
                print("✅ Marked place as visited for active mission: \(missionId)")
            }
        }
        
        // Save to Firestore if needed
        await saveMissionProgress(missionId: missionId, visitedPlaces: getVisitedPlaces(for: missionId))
    }
    
    func checkMissionCompletion(_ mission: Mission) async {
        let isComplete = mission.visitedPlaces.count >= mission.targetPlaces.count
        
        if isComplete && mission.status != .completed {
            await completeMission(mission)
        }
    }
    
    private func completeMission(_ mission: Mission) async {
        // Create new completed mission
        var completedMission = Mission(
            id: mission.id,
            title: mission.title,
            description: mission.description,
            targetPlaces: mission.targetPlaces,
            visitedPlaces: mission.visitedPlaces,
            xpReward: mission.xpReward,
            createdAt: mission.createdAt,
            status: .completed,
            isDaily: mission.isDaily
        )
        completedMission.completedAt = Date()
        
        // Move from active to completed
        if let index = activeMissions.firstIndex(where: { $0.id == mission.id }) {
            activeMissions.remove(at: index)
            completedMissions.insert(completedMission, at: 0)
        }
        
        // Update daily missions
        if let index = dailyMissions.firstIndex(where: { $0.id == mission.id }) {
            dailyMissions[index] = completedMission
        }
        
        // Award XP
        await awardXP(amount: mission.xpReward)
        
        // Save to Firestore
        await saveMissionCompletion(completedMission)
        
        print("🎉 Mission completed: \(mission.title) (+\(mission.xpReward) XP)")
    }
    
    private func getVisitedPlaces(for missionId: String) -> [String] {
        if let mission = dailyMissions.first(where: { $0.id == missionId }) {
            return mission.visitedPlaces
        }
        if let mission = activeMissions.first(where: { $0.id == missionId }) {
            return mission.visitedPlaces
        }
        return []
    }
    
    private func awardXP(amount: Int) async {
        // Award XP through XP manager
        await xpManager?.awardXP(amount: amount, reason: "Mission completed")
    }
    
    // MARK: - Firestore Operations
    private func saveMissionProgress(missionId: String, visitedPlaces: [String]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).collection("missions").document(missionId).updateData([
                "visitedPlaces": visitedPlaces,
                "lastUpdated": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Error saving mission progress: \(error)")
        }
    }
    
    private func saveMissionCompletion(_ mission: Mission) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).collection("missions").document(mission.id).updateData([
                "status": "completed",
                "completedAt": FieldValue.serverTimestamp(),
                "visitedPlaces": mission.visitedPlaces
            ])
        } catch {
            print("❌ Error saving mission completion: \(error)")
        }
    }
    
    // MARK: - Update Daily Mission Stats
    private func updateDailyMissionStats() async {
        let today = Calendar.current.startOfDay(for: Date())
        if let lastGeneration = lastDailyMissionGeneration,
           Calendar.current.isDate(lastGeneration, inSameDayAs: today) {
            dailyMissionsGenerated += 1
        } else {
            dailyMissionsGenerated = 1
            lastDailyMissionGeneration = Date()
        }
        saveDailyMissionStats()
    }
    
    // MARK: - Save Mission to Firestore
    private func saveMissionToFirestore(_ mission: Mission) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let missionData: [String: Any] = [
            "id": mission.id,
            "title": mission.title,
            "prompt": mission.prompt,
            "xpReward": mission.xpReward,
            "vibeTag": mission.vibeTag,
            "locationType": mission.locationType,
            "status": mission.status.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "completedAt": mission.completedAt as Any,
            "placeOptions": mission.placeOptions?.map { place in
                [
                    "id": place.id,
                    "placeId": place.placeId,
                    "name": place.name,
                    "address": place.address,
                    "completed": place.completed,
                    "completedAt": place.completedAt as Any
                ]
            } ?? [],
            "userId": mission.userId
        ]
        
        try await db.collection("users").document(userId)
            .collection("missions").document(mission.id).setData(missionData)
        
        print("✅ Mission saved to Firestore: \(mission.title)")
    }
    
    // MARK: - Helper Functions
    private func loadDailyMissionStats() {
        dailyMissionsGenerated = UserDefaults.standard.integer(forKey: "dailyMissionsGenerated")
        if let lastGeneration = UserDefaults.standard.object(forKey: "lastDailyMissionGeneration") as? Date {
            lastDailyMissionGeneration = lastGeneration
        }
    }
    
    private func saveDailyMissionStats() {
        UserDefaults.standard.set(dailyMissionsGenerated, forKey: "dailyMissionsGenerated")
        UserDefaults.standard.set(lastDailyMissionGeneration, forKey: "lastDailyMissionGeneration")
    }
    
    // MARK: - Refresh Missions
    func refreshMissions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Check if enough time has passed since last generation
        let lastGenerationTime = UserDefaults.standard.object(forKey: "lastMissionGeneration") as? Date ?? Date.distantPast
        let hoursSinceLastGeneration = Date().timeIntervalSince(lastGenerationTime) / 3600
        
        if hoursSinceLastGeneration >= Double(missionRefreshHours) {
            await generateDailyMissions()
            UserDefaults.standard.set(Date(), forKey: "lastMissionGeneration")
        }
        
        isLoading = false
    }
    
    // MARK: - Get Mission by ID
    func getMission(by id: String) -> Mission? {
        return activeMissions.first { $0.id == id } ?? completedMissions.first { $0.id == id }
    }
    
    // MARK: - Force Generate New Mission (for testing)
    func forceGenerateNewMission() async {
        await generateDailyMissions()
    }
    
    // MARK: - Enhanced Personalized Mission Generation
    func generatePersonalizedMission() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard !isGeneratingMission else { return }
        
        isGeneratingMission = true
        
        do {
            // Get user fingerprint for personalization
            let fingerprint = fingerprintManager.fingerprint ?? AppUserFingerprint()
            
            // Create mission concept based on user preferences
            let missionConcept = createMissionConcept(from: fingerprint, userId: userId)
            
            // Generate mission with real Google Places
            if let mission = await generateMissionWithRealPlaces(concept: missionConcept) {
                // Save mission to Firestore
                try await saveMissionToFirestore(mission)
                
                print("✅ Generated personalized mission with real places: \(mission.title)")
                
                // Update daily mission stats
                await updateDailyMissionStats()
                
            } else {
                print("❌ Failed to generate mission with real places")
            }
            
        } catch {
            print("❌ Error in personalized mission generation: \(error)")
            errorMessage = "Failed to generate mission: \(error.localizedDescription)"
        }
        
        isGeneratingMission = false
    }
    
    // MARK: - Create Mission Concept from User Fingerprint
    private func createMissionConcept(from fingerprint: AppUserFingerprint, userId: String) -> MissionConcept {
        let locationTypes = ["restaurant", "cafe", "park", "shopping", "entertainment"]
        let vibes = ["Trendy", "Cozy", "Adventurous", "Relaxing", "Social", "Quiet", "Energetic"]
        
        // Use fingerprint data to influence mission type
        let preferredType = fingerprint.preferredPlaceTypes.randomElement() ?? locationTypes.randomElement()!
        let selectedVibe = fingerprint.moodHistory.last ?? vibes.randomElement()!
        
        // Create search query for Google Places
        let searchQuery = createGooglePlacesQuery(
            locationType: preferredType,
            fingerprint: fingerprint
        )
        
        return MissionConcept(
            title: generateMissionTitle(locationType: preferredType, vibe: selectedVibe),
            prompt: generateMissionPrompt(locationType: preferredType, vibe: selectedVibe),
            xpReward: calculateMissionXPReward(locationType: preferredType),
            vibeTag: selectedVibe,
            locationType: preferredType,
            placeSearchQuery: searchQuery,
            targetPlaceCount: 3,
            userId: userId
        )
    }
    
    // MARK: - Helper Functions for Mission Generation
    private func createGooglePlacesQuery(locationType: String, fingerprint: AppUserFingerprint) -> String {
        let baseQueries: [String: String] = [
            "restaurant": "restaurants near me",
            "cafe": "coffee shops cafes near me",
            "park": "parks recreation areas near me",
            "shopping": "shopping centers stores near me",
            "entertainment": "entertainment venues activities near me"
        ]
        
        // Add user preferences to make search more specific
        var query = baseQueries[locationType] ?? "places near me"
        
        // Enhance query based on fingerprint data
        if !fingerprint.cuisineHistory.isEmpty && locationType == "restaurant" {
            let cuisine = fingerprint.cuisineHistory.randomElement()!
            query = "\(cuisine) restaurants near me"
        }
        
        return query
    }
    
    private func generateMissionTitle(locationType: String, vibe: String) -> String {
        let titleTemplates: [String: [String]] = [
            "restaurant": ["Culinary Adventure", "Taste Explorer", "Foodie Mission"],
            "cafe": ["Coffee Quest", "Cafe Discovery", "Bean Hunter Mission"],
            "park": ["Nature Explorer", "Green Space Quest", "Outdoor Adventure"],
            "shopping": ["Retail Safari", "Shopping Explorer", "Treasure Hunt"],
            "entertainment": ["Fun Finder", "Entertainment Quest", "Activity Hunter"]
        ]
        
        let templates = titleTemplates[locationType] ?? ["Discovery Mission"]
        let baseTitle = templates.randomElement()!
        
        return "\(vibe) \(baseTitle)"
    }
    
    private func generateMissionPrompt(locationType: String, vibe: String) -> String {
        return "Explore and discover new places that match your interests"
    }
    
    private func calculateMissionXPReward(locationType: String) -> Int {
        let baseRewards: [String: Int] = [
            "restaurant": 200,
            "cafe": 150,
            "park": 175,
            "shopping": 150,
            "entertainment": 225
        ]
        
        return baseRewards[locationType] ?? 200
    }
    
    // MARK: - Enhanced Mission Generation with Real Google Places
    private func generateMissionWithRealPlaces(concept: MissionConcept) async -> Mission? {
        do {
            // Get user location - use current location or fingerprint location
            let userLocation: CLLocation
            if let fingerprintLocation = fingerprintManager.fingerprint?.currentLocation {
                userLocation = CLLocation(latitude: fingerprintLocation.latitude, longitude: fingerprintLocation.longitude)
            } else if let fingerprintMainLocation = fingerprintManager.fingerprint?.location {
                userLocation = CLLocation(latitude: fingerprintMainLocation.latitude, longitude: fingerprintMainLocation.longitude)
            } else {
                // Default to San Francisco if no location available
                userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
            }
            
            // Search for real places using Google Places API with async wrapper
            let searchResults = await withCheckedContinuation { continuation in
                placesService.searchPlacesByText(
                    query: concept.placeSearchQuery,
                    location: userLocation,
                    radius: 5000 // 5km radius
                ) { googlePlaces in
                    continuation.resume(returning: googlePlaces)
                }
            }
            
            guard !searchResults.isEmpty else {
                print("❌ No real places found for query: \(concept.placeSearchQuery)")
                return nil
            }
            
            // Select up to 3 real places for the mission
            let selectedPlaces = Array(searchResults.prefix(min(3, concept.targetPlaceCount)))
            
            // Convert Google Places to MissionPlaces
            let missionPlaces = selectedPlaces.map { googlePlace in
                MissionPlace(
                    placeId: googlePlace.placeId,
                    name: googlePlace.name,
                    address: googlePlace.address
                )
            }
            
            let mission = Mission(
                title: concept.title,
                prompt: concept.prompt,
                xpReward: concept.xpReward,
                vibeTag: concept.vibeTag,
                locationType: concept.locationType,
                placeOptions: missionPlaces,
                userId: concept.userId
            )
            
            print("✅ Created mission with \(missionPlaces.count) real Google Places")
            return mission
            
        } catch {
            print("❌ Error generating mission with real places: \(error)")
            return nil
        }
    }
} 