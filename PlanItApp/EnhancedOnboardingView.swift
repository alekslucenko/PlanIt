import SwiftUI
import FirebaseFirestore

// MARK: - Timeout Helper
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {
    let message = "Operation timed out"
}

// MARK: - Premium Onboarding View with Modern Design
struct EnhancedOnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: LocationManager
    @State private var currentStep = 0
    @State private var selectedCategories: Set<OnboardingCategory> = []
    @State private var onboardingResponses: [OnboardingResponse] = []
    @State private var showingAuthRequired = false
    @State private var pendingOnboardingData: OnboardingData?
    @State private var userName: String = ""
    @State private var showingReaffirmation = false
    @State private var currentReaffirmation: ReaffirmationContent?
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingLogin = false
    
    private let totalSteps = 7
    
    // MARK: - Computed Properties (Simplifies Type Inference)
    private var currentOnboardingData: OnboardingData {
        OnboardingData(
            selectedCategories: Array(selectedCategories.isEmpty ? [.restaurants, .hangoutSpots] : selectedCategories),
            responses: onboardingResponses,
            userName: userName
        )
    }
    
    // MARK: - Extracted Step View (Fixes Compiler Hang)
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:
            LocationPermissionStepView(
                onNext: { nextStep() },
                onSkip: { nextStep() }
            )
        case 1:
            NameEntryView(
                userName: $userName,
                onNext: { 
                    onboardingManager.setUserName(userName)
                    nextStep()
                },
                onShowLogin: { 
                    print("🔑 EnhancedOnboardingView: Showing login for existing user")
                    showingLogin = true 
                }
            )
        case 2:
            WelcomeView(
                userName: userName,
                onNext: { nextStep() }
            )
        case 3:
            InterestSelectionView(
                selectedCategories: $selectedCategories,
                onNext: { 
                    guard !selectedCategories.isEmpty else { return }
                    showReaffirmation()
                    nextStep()
                },
                onBack: { previousStep() }
            )
        case 4:
            GlobalQuestionFlowView(
                responses: $onboardingResponses,
                onNext: { nextStep() },
                onBack: { previousStep() }
            )
        case 5:
            QuestionFlowView(
                selectedCategories: selectedCategories,
                responses: $onboardingResponses,
                onNext: { 
                    showReaffirmation()
                    nextStep()
                },
                onBack: { previousStep() }
            )
        case 6:
            CompletionView(
                userName: userName,
                onComplete: completeOnboarding,
                onBack: { previousStep() }
            )
        default:
            EmptyView()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium gradient background
                PremiumBackgroundView()
                    .ignoresSafeArea()
                
                // Main content - NO MORE TABVIEW SWIPING
                VStack {
                    // Progress indicator at top
                    ProgressIndicatorView(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.top, geometry.safeAreaInsets.top + 20)
                    
                    // Current step content
                    currentStepView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingAuthRequired) {
            if let data = pendingOnboardingData {
                LoginView(
                    onboardingData: data,
                    userName: userName,
                    onAuthComplete: {
                        showingAuthRequired = false
                        Task {
                            await finalizeOnboarding(with: data)
                        }
                    },
                    isForExistingUser: false
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(
                onboardingData: nil,
                userName: userName,
                onAuthComplete: handleLoginComplete,
                isForExistingUser: true
            )
            .environmentObject(authService)
        }
        .overlay(
            Group {
                if showingReaffirmation, let content = currentReaffirmation {
                    ReaffirmationToast(
                        content: content,
                        isShowing: $showingReaffirmation
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
        )
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Oops!"),
                message: Text(errorMessage ?? "Something went wrong. Please try again."),
                dismissButton: .default(Text("Got it"))
            )
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && showingAuthRequired {
                if let data = pendingOnboardingData {
                    Task {
                        await finalizeOnboarding(with: data)
                    }
                }
                showingAuthRequired = false
            }
        }
        .onChange(of: authService.errorMessage) { _, error in
            if let error = error {
                errorMessage = error
                showingError = true
            }
        }
    }
    
    // MARK: - Navigation Helpers (Prevents Compiler Hang)
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep += 1
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep -= 1
        }
    }
    
    private func handleLoginComplete() {
        showingLogin = false
        print("🔑 EnhancedOnboardingView: Authentication completed, processing onboarding...")
        
        if authService.isAuthenticated {
            print("🎯 EnhancedOnboardingView: User successfully authenticated")
            // FIXED: Don't try to finalize onboarding data for existing users
            // Just mark onboarding as complete and let ContentView handle navigation
            onboardingManager.setHasCompletedOnboarding(true)
            print("🎯 EnhancedOnboardingView: Marked onboarding as completed for existing user")
        }
    }
    
    private func showReaffirmation() {
        guard !ReaffirmationContent.contents.isEmpty else { return }
        
        let randomContent = ReaffirmationContent.contents.randomElement()!
        currentReaffirmation = randomContent
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingReaffirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingReaffirmation = false
            }
        }
    }
    
    private func completeOnboarding() {
        let onboardingData = OnboardingData(
            selectedCategories: Array(selectedCategories.isEmpty ? [.restaurants, .hangoutSpots] : selectedCategories),
            responses: onboardingResponses,
            userName: userName
        )
        
        print("🎯 Completing onboarding with data: \(onboardingData)")
        
        pendingOnboardingData = onboardingData
        showingAuthRequired = true
    }
    
    private func finalizeOnboarding(with data: OnboardingData) async {
        print("🔄 EnhancedOnboardingView: Starting onboarding finalization...")
        
        // Check if user is available with timeout instead of retry loop
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds timeout
            return false
        }
        
        let userCheckTask = Task {
            return authService.user != nil
        }
        
        let userAvailable = await userCheckTask.value
        timeoutTask.cancel()
        
        guard userAvailable else {
            print("❌ Authentication user not available")
            await MainActor.run {
                errorMessage = "Authentication failed. Please try again."
                showingError = true
            }
            return
        }

        // Save onboarding data with timeout protection
        do {
            try await withTimeout(seconds: 10) {
                await authService.saveOnboardingData(data, location: locationManager.selectedLocation)
                await initializeUserFingerprint(with: data)
            }
            print("✅ EnhancedOnboardingView: Onboarding data saved successfully")
        } catch {
            print("⚠️ EnhancedOnboardingView: Save operation failed or timed out: \(error)")
        }

        await MainActor.run {
            print("✅ EnhancedOnboardingView: Completing onboarding in OnboardingManager")
            onboardingManager.completeOnboarding(with: data)
            pendingOnboardingData = nil
            print("🎯 EnhancedOnboardingView: Onboarding completion finished!")
        }
    }
    
    private func initializeUserFingerprint(with data: OnboardingData) async {
        guard let user = authService.user else { 
            print("❌ No user available for fingerprint initialization")
            return 
        }
        
        // Create a simplified fingerprint to avoid hanging
        let basicFingerprint: [String: Any] = [
            "displayName": data.userName,
            "email": user.email ?? "",
            "onboardingCompleted": true,
            "selectedCategories": data.selectedCategories.map { $0.rawValue },
            "responseCount": data.responses.count,
            "fingerprintCreatedAt": FieldValue.serverTimestamp(),
            "lastFingerprintUpdate": FieldValue.serverTimestamp()
        ]
        
        do {
            let db = Firestore.firestore()
            
            // Save basic fingerprint with timeout protection
            try await db.collection("users").document(user.uid).setData(basicFingerprint, merge: true)
            
            print("🧬 Basic user fingerprint initialized successfully")
            
            // Initialize detailed fingerprint in background without blocking
            Task {
                await initializeDetailedFingerprintInBackground(with: data, userId: user.uid)
            }
            
        } catch {
            print("❌ Failed to initialize basic user fingerprint: \(error)")
        }
    }
    
    private func initializeDetailedFingerprintInBackground(with data: OnboardingData, userId: String) async {
        do {
            // Build comprehensive user fingerprint from onboarding data
            let preferredPlaceTypes = extractPreferredPlaceTypes(from: data)
            let moodHistory = extractMoodHistory(from: data)
            let cuisineHistory = extractCuisineHistory(from: data)
            
            var detailedFingerprint: [String: Any] = [
                "onboardingResponses": data.responses.map { response in
                    var responseData: [String: Any] = [
                        "questionId": response.questionId,
                        "categoryId": response.categoryId
                    ]
                    
                    if let selectedOptions = response.selectedOptions {
                        responseData["selectedOptions"] = selectedOptions
                    }
                    if let sliderValue = response.sliderValue {
                        responseData["sliderValue"] = sliderValue
                    }
                    if let ratingValue = response.ratingValue {
                        responseData["ratingValue"] = ratingValue
                    }
                    if let textValue = response.textValue {
                        responseData["textValue"] = textValue
                    }
                    responseData["timestamp"] = ISO8601DateFormatter().string(from: response.timestamp)
                    
                    return responseData
                },
                "likes": [],
                "dislikes": [],
                "interactionLogs": [],
                "likeCount": 0,
                "dislikeCount": 0,
                "tagAffinities": [:],
                "preferredPlaceTypes": preferredPlaceTypes,
                "moodHistory": moodHistory,
                "cuisineHistory": cuisineHistory,
                "behavioralPatterns": [
                    "timePreferences": [:],
                    "dayPreferences": [:],
                    "weatherPreferences": [:]
                ],
                "psychographics": [
                    "explorationStyle": "balanced",
                    "socialTendency": "moderate",
                    "riskTolerance": "medium"
                ],
                "lastDetailedUpdate": FieldValue.serverTimestamp()
            ]
            
            // Add location if available
            if let location = locationManager.selectedLocation {
                detailedFingerprint["location"] = [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude
                ]
                detailedFingerprint["currentLocation"] = [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude
                ]
            }
            
            let db = Firestore.firestore()
            
            // Update with detailed data
            try await db.collection("users").document(userId).setData(detailedFingerprint, merge: true)
            
            // Create dedicated fingerprint document for faster recommendation queries
            try await db.collection("userFingerprints").document(userId).setData(detailedFingerprint, merge: true)
            
            print("🧬 Detailed user fingerprint initialized successfully in background")
            
        } catch {
            print("❌ Failed to initialize detailed user fingerprint: \(error)")
        }
    }
    
    private func extractPreferredPlaceTypes(from data: OnboardingData) -> [String] {
        var placeTypes: [String] = []
        
        // Extract from selected categories
        for category in data.selectedCategories {
            switch category {
            case .restaurants:
                placeTypes.append(contentsOf: ["restaurant", "cafe", "bar"])
            case .hangoutSpots:
                placeTypes.append(contentsOf: ["cafe", "lounge", "park"])
            case .nature:
                placeTypes.append(contentsOf: ["park", "beach", "hiking_trail"])
            case .entertainment:
                placeTypes.append(contentsOf: ["movie_theater", "concert_hall", "nightclub"])
            case .shopping:
                placeTypes.append(contentsOf: ["shopping_mall", "store", "boutique"])
            case .culture:
                placeTypes.append(contentsOf: ["museum", "gallery", "historic_site"])
            case .fitness:
                placeTypes.append(contentsOf: ["gym", "sports_complex", "yoga_studio"])
            default:
                break
            }
        }
        
        return Array(Set(placeTypes)) // Remove duplicates
    }
    
    private func extractMoodHistory(from data: OnboardingData) -> [String] {
        var moods: [String] = []
        
        // Analyze responses to infer moods
        for response in data.responses {
            if let textValue = response.textValue?.lowercased() {
                if textValue.contains("relax") || textValue.contains("calm") {
                    moods.append("Relaxing")
                } else if textValue.contains("social") || textValue.contains("friend") {
                    moods.append("Social")
                } else if textValue.contains("adventure") || textValue.contains("exciting") {
                    moods.append("Adventurous")
                } else if textValue.contains("quiet") || textValue.contains("peaceful") {
                    moods.append("Contemplative")
                }
            }
            
            if let selectedOptions = response.selectedOptions {
                for option in selectedOptions {
                    if option.lowercased().contains("lively") || option.lowercased().contains("energetic") {
                        moods.append("Energetic")
                    } else if option.lowercased().contains("intimate") || option.lowercased().contains("romantic") {
                        moods.append("Romantic")
                    }
                }
            }
        }
        
        // Default moods if none detected
        if moods.isEmpty {
            moods = ["Relaxing", "Social"]
        }
        
        return Array(Set(moods))
    }
    
    private func extractCuisineHistory(from data: OnboardingData) -> [String] {
        var cuisines: [String] = []
        
        // Extract from restaurant responses
        for response in data.responses where response.categoryId == "restaurants" {
            if let selectedOptions = response.selectedOptions {
                for option in selectedOptions {
                    if option.contains("Italian") {
                        cuisines.append("Italian")
                    } else if option.contains("Asian") {
                        cuisines.append("Asian")
                    } else if option.contains("Mexican") {
                        cuisines.append("Mexican")
                    } else if option.contains("American") {
                        cuisines.append("American")
                    } else if option.contains("Mediterranean") {
                        cuisines.append("Mediterranean")
                    }
                }
            }
        }
        
        // Default cuisines if none detected
        if cuisines.isEmpty {
            cuisines = ["Italian", "Mexican", "Asian"]
        }
        
        return Array(Set(cuisines))
    }
}

// MARK: - Premium Background
struct PremiumBackgroundView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.8),
                    Color.pink.opacity(0.9),
                    Color.orange.opacity(0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated orbs
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 60...120))
                    .blur(radius: 2)
                    .offset(
                        x: cos(animationOffset + Double(index) * 0.5) * 100,
                        y: sin(animationOffset + Double(index) * 0.7) * 100
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                animationOffset = .pi * 2
            }
        }
    }
}

// MARK: - Name Entry View
struct NameEntryView: View {
    @Binding var userName: String
    let onNext: () -> Void
    let onShowLogin: () -> Void
    @State private var isAnimating = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.spring(response: 1.2, dampingFraction: 0.6), value: isAnimating)
                
                VStack(spacing: 16) {
                    Text("What's your name?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("We'll use this to personalize your experience")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
                
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        TextField("Enter username (letters & numbers only)", text: $userName)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isTextFieldFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        isTextFieldFocused = false
                                    }
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                                }
                            }
                            .onChange(of: userName) { oldValue, newValue in
                                // Filter out invalid characters in real-time
                                let filtered = newValue.filter { $0.isLetter || $0.isNumber }
                                if filtered != newValue {
                                    userName = filtered
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                        
                        // Username validation feedback
                        if !userName.isEmpty && !AppUser.isValidUsername(userName) {
                            Text(getUsernameValidationMessage())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else if AppUser.isValidUsername(userName) {
                            Text("✓ Valid username")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimating)
            }
            
            Spacer()
            
            // Navigation buttons - standardized
            VStack(spacing: 16) {
                NavigationButtonsView(
                    showBackButton: false,
                    backAction: {},
                    continueTitle: "Continue",
                    continueAction: {
                        if AppUser.isValidUsername(userName) {
                            onNext()
                        }
                    },
                    isContinueDisabled: !AppUser.isValidUsername(userName)
                )
                
                // Already have an account button
                Button(action: onShowLogin) {
                    Text("Already have an account?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .underline()
                }
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(1.1), value: isAnimating)
            }
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.9), value: isAnimating)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func getUsernameValidationMessage() -> String {
        if userName.count < 3 {
            return "Username must be at least 3 characters"
        } else if userName.count > 20 {
            return "Username must be 20 characters or less"
        } else {
            return "Only letters and numbers allowed"
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let userName: String
    let onNext: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.spring(response: 1.2, dampingFraction: 0.6), value: isAnimating)
                
                VStack(spacing: 16) {
                    Text("Hey \(userName.isEmpty ? "there" : userName)! 👋")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("Ready to discover amazing places\ntailored just for you?")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
            }
            
            Spacer()
            
            // Navigation buttons - standardized
            NavigationButtonsView(
                showBackButton: false,
                backAction: {},
                continueTitle: "Let's Go!",
                continueAction: onNext
            )
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6), value: isAnimating)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

// MARK: - Interest Selection View
struct InterestSelectionView: View {
    @Binding var selectedCategories: Set<OnboardingCategory>
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        // FIXED: Use proper VStack layout to keep buttons locked at bottom
        VStack(spacing: 0) {
            // Header Section - TOP
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.spring(response: 1.2, dampingFraction: 0.6), value: isAnimating)
                
                VStack(spacing: 16) {
                    Text("What interests you?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("Choose categories that match your vibe")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
            }
            .padding(.top, 40)
            
            Spacer(minLength: 30)
            
            // Category Grid - MIDDLE SECTION (scrollable if needed)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(OnboardingCategory.allCases.filter { $0 != .global }, id: \.self) { category in
                        InterestCard(
                            category: category,
                            isSelected: selectedCategories.contains(category),
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    if selectedCategories.contains(category) {
                                        selectedCategories.remove(category)
                                    } else {
                                        selectedCategories.insert(category)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 30)
            .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimating)
            
            Spacer(minLength: 30)
            
            // Navigation buttons - BOTTOM SECTION (always locked at bottom)
            NavigationButtonsView(
                showBackButton: true,
                backAction: onBack,
                continueTitle: "Continue",
                continueAction: onNext,
                isContinueDisabled: selectedCategories.isEmpty
            )
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.9), value: isAnimating)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

// MARK: - Interest Card - FIXED ROUNDED CORNERS
struct InterestCard: View {
    let category: OnboardingCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: category.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? .black : .white)
                
                Text(category.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .clear : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .cornerRadius(16)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Global Question Flow View
struct GlobalQuestionFlowView: View {
    @Binding var responses: [OnboardingResponse]
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var currentQuestionIndex = 0
    @State private var isAnimating = false
    
    private var allQuestions: [OnboardingQuestion] {
        Self.globalQuestions
    }
    
    private var currentQuestion: OnboardingQuestion? {
        guard currentQuestionIndex < allQuestions.count else { return nil }
        return allQuestions[currentQuestionIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    ForEach(0..<allQuestions.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentQuestionIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(index == currentQuestionIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentQuestionIndex)
                    }
                }
                
                Text("Question \(currentQuestionIndex + 1) of \(allQuestions.count)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 20)
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: isAnimating)
            
            Spacer(minLength: 40)
            
            if let question = currentQuestion {
                PremiumQuestionView(
                    category: .global,
                    question: question,
                    onAnswer: { response in
                        if let index = responses.firstIndex(where: { $0.questionId == response.questionId }) {
                            responses[index] = response
                        } else {
                            responses.append(response)
                        }
                    }
                )
                .transition(.opacity.combined(with: .slide))
            }
            
            Spacer(minLength: 60)
            
            NavigationButtonsView(
                showBackButton: true,
                backAction: {
                    if currentQuestionIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex -= 1
                        }
                    } else {
                        onBack()
                    }
                },
                continueTitle: currentQuestionIndex < allQuestions.count - 1 ? "Next" : "Continue",
                continueAction: {
                    if currentQuestionIndex < allQuestions.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex += 1
                        }
                    } else {
                        onNext()
                    }
                },
                isContinueDisabled: !hasValidResponse()
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private func hasValidResponse() -> Bool {
        guard let question = currentQuestion else { return false }

        guard let response = responses.first(where: { $0.questionId == question.id }) else {
            return false
        }

        switch question.type {
        case .singleChoice, .multipleChoice:
            return !(response.selectedOptions?.isEmpty ?? true)
        case .slider:
            return response.sliderValue != nil
        case .rating:
            return (response.ratingValue ?? 0) > 0
        case .textInput:
            let text = response.textValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !text.isEmpty
        }
    }

    // MARK: Questions definition
    static let globalQuestions: [OnboardingQuestion] = [
        OnboardingQuestion(id: "global_age", text: "Select your age range", type: .singleChoice, options: ["18-24", "25-34", "35-44", "45-54", "55+"]),
        OnboardingQuestion(id: "global_outing_times", text: "Preferred outing times", type: .multipleChoice, options: ["Morning", "Afternoon", "Evening", "Night"]),
        OnboardingQuestion(id: "global_vibes", text: "Pick the vibes that describe your perfect spot", type: .multipleChoice, options: ["Romantic", "Chaotic", "Trendy", "Historic", "Intimate", "Family-Friendly", "Luxury"]),
        OnboardingQuestion(id: "global_transport", text: "How do you usually get around?", type: .singleChoice, options: ["Drives", "Walks", "Public Transit", "Ride Share"]),
        OnboardingQuestion(id: "global_social", text: "Who do you normally go out with?", type: .singleChoice, options: ["Solo", "Couple", "Group", "Family"]),
        OnboardingQuestion(id: "global_cuisine", text: "Favourite cuisines (pick all that apply)", type: .multipleChoice, options: ["Italian", "Sushi", "BBQ", "Mexican", "Indian", "Mediterranean", "Vegan"]),
        OnboardingQuestion(id: "global_music", text: "Favourite music genres", type: .multipleChoice, options: ["Pop", "Rock", "Hip-Hop", "Electronic", "Classical", "Jazz", "Country"]),
        OnboardingQuestion(id: "global_events", text: "Favourite event types", type: .multipleChoice, options: ["Concerts", "Comedy", "Sports", "Festivals", "Theatre", "Workshops"]),
        OnboardingQuestion(id: "global_dislikes", text: "Anything you dislike or want to avoid?", type: .textInput),
        OnboardingQuestion(id: "global_fav_locations", text: "List 1–3 of your favourite places", type: .textInput),
        OnboardingQuestion(id: "global_ideal_day", text: "Describe your ideal day out", type: .textInput)
    ]
}

// MARK: - Question Flow View
struct QuestionFlowView: View {
    let selectedCategories: Set<OnboardingCategory>
    @Binding var responses: [OnboardingResponse]
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var currentQuestionIndex = 0
    @State private var isAnimating = false
    
    private var allQuestions: [OnboardingQuestion] {
        selectedCategories.flatMap { $0.questions }
    }
    
    private var currentQuestion: OnboardingQuestion? {
        guard currentQuestionIndex < allQuestions.count else { return nil }
        return allQuestions[currentQuestionIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    ForEach(0..<allQuestions.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentQuestionIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(index == currentQuestionIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentQuestionIndex)
                    }
                }
                
                Text("Question \(currentQuestionIndex + 1) of \(allQuestions.count)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 20)
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: isAnimating)
            
            Spacer(minLength: 40)
            
            if let question = currentQuestion {
                PremiumQuestionView(
                    category: selectedCategories.first { $0.questions.contains { $0.id == question.id } } ?? .restaurants,
                    question: question,
                    onAnswer: { response in
                        if let index = responses.firstIndex(where: { $0.questionId == response.questionId }) {
                            responses[index] = response
                        } else {
                            responses.append(response)
                        }
                    }
                )
                .transition(.opacity.combined(with: .slide))
            }
            
            Spacer(minLength: 60)
            
            NavigationButtonsView(
                showBackButton: true,
                backAction: {
                    if currentQuestionIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex -= 1
                        }
                    } else {
                        onBack()
                    }
                },
                continueTitle: currentQuestionIndex < allQuestions.count - 1 ? "Next" : "Continue",
                continueAction: {
                    if currentQuestionIndex < allQuestions.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentQuestionIndex += 1
                        }
                    } else {
                        onNext()
                    }
                },
                isContinueDisabled: !hasValidResponse()
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private func hasValidResponse() -> Bool {
        guard let question = currentQuestion else { return false }

        guard let response = responses.first(where: { $0.questionId == question.id }) else {
            return false
        }

        switch question.type {
        case .singleChoice, .multipleChoice:
            return !(response.selectedOptions?.isEmpty ?? true)
        case .slider:
            return response.sliderValue != nil
        case .rating:
            return (response.ratingValue ?? 0) > 0
        case .textInput:
            let text = response.textValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !text.isEmpty
        }
    }
}

// MARK: - Completion View
struct CompletionView: View {
    let userName: String
    let onComplete: () -> Void
    let onBack: () -> Void
    @State private var isAnimating = false
    @State private var particleAnimations: [Bool] = Array(repeating: false, count: 8)
    
    var body: some View {
        VStack {
            Spacer()
            
            // Celebration animation
            ZStack {
                // Background particles
                ForEach(0..<particleAnimations.count, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(Double(index) * .pi / 4) * (particleAnimations[index] ? 80 : 0),
                            y: sin(Double(index) * .pi / 4) * (particleAnimations[index] ? 80 : 0)
                        )
                        .scaleEffect(particleAnimations[index] ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).delay(Double(index) * 0.1), value: particleAnimations[index])
                }
                
                VStack(spacing: 20) {
                    Text("Perfect! 🎉")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: isAnimating)
                    
                    Text("You're all set to discover amazing places that match your preferences!")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.7), value: isAnimating)
                }
            }
            
            Spacer()
            
            // Navigation buttons - standardized
            NavigationButtonsView(
                showBackButton: true,
                backAction: onBack,
                continueTitle: "Start Exploring!",
                continueAction: onComplete
            )
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0), value: isAnimating)
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for index in 0..<particleAnimations.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                        particleAnimations[index] = true
                    }
                }
            }
        }
    }
}

// MARK: - STANDARDIZED NAVIGATION BUTTONS COMPONENT
struct NavigationButtonsView: View {
    let showBackButton: Bool
    let backAction: () -> Void
    let continueTitle: String
    let continueAction: () -> Void
    var isContinueDisabled: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            if showBackButton {
                Button(action: backAction) {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: continueAction) {
                Label(continueTitle, systemImage: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(isContinueDisabled)
            .opacity(isContinueDisabled ? 0.6 : 1.0)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }
}

// MARK: - Premium Button Components (Updated)
struct PremiumButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 100, height: 50)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reaffirmation Toast
struct ReaffirmationToast: View {
    let content: ReaffirmationContent
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: content.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                Text(content.message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

// MARK: - Progress Indicator
struct ProgressIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}

#Preview {
    EnhancedOnboardingView()
        .environmentObject(OnboardingManager())
        .environmentObject(AuthenticationService())
        .environmentObject(LocationManager())
} 