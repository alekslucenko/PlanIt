import SwiftUI
import FirebaseFirestore

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var isAnimating = false
    
    // Required properties for onboarding integration
    let onboardingData: OnboardingData?
    let userName: String
    let onAuthComplete: () -> Void
    
    // NEW: Flag to indicate if this is for existing users only
    let isForExistingUser: Bool
    
    // Computed property that combines the flags for easier detection
    var isExistingUserLogin: Bool {
        // FIXED: Use explicit flag when available, fallback to onboarding data check
        return isForExistingUser || (onboardingData != nil)
    }
    
    // Shared focus state for keyboard management
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email, password, confirmPassword, displayName
    }
    
    // Initialize with explicit existing user flag
    init(onboardingData: OnboardingData?, userName: String, onAuthComplete: @escaping () -> Void, isForExistingUser: Bool = false) {
        self.onboardingData = onboardingData
        self.userName = userName
        self.onAuthComplete = onAuthComplete
        self.isForExistingUser = isForExistingUser
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient - FIXED: No animation to prevent keyboard shifts
                LinearGradient(
                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.9), Color.orange.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard)
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 60)
                        
                        // Logo and title
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 50, weight: .regular))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
                            
                            VStack(spacing: 8) {
                                Text("Almost there! ✨")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Create your account to save your preferences")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
                        }
                        
                        // Auth Mode Toggle
                        VStack(spacing: 20) {
                            // FIXED: Only show toggle if this is NOT an existing user login
                            if !isExistingUserLogin {
                                HStack(spacing: 0) {
                                    Button(action: { 
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isSignUp = false 
                                            focusedField = nil // Dismiss keyboard when switching
                                        }
                                    }) {
                                        Text("Sign In")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isSignUp ? .white.opacity(0.7) : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(isSignUp ? Color.clear : Color.white.opacity(0.2))
                                            )
                                    }
                                    
                                    Button(action: { 
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isSignUp = true 
                                            focusedField = nil // Dismiss keyboard when switching
                                        }
                                    }) {
                                        Text("Sign Up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isSignUp ? .white : .white.opacity(0.7))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(isSignUp ? Color.white.opacity(0.2) : Color.clear)
                                            )
                                    }
                                }
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .padding(.horizontal, 40)
                                .scaleEffect(isAnimating ? 1 : 0.8)
                                .opacity(isAnimating ? 1 : 0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                            } else {
                                // Show only "Sign In" title for existing users
                                Text("Welcome Back!")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .scaleEffect(isAnimating ? 1 : 0.8)
                                    .opacity(isAnimating ? 1 : 0)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                            }
                            
                            // Form fields with standardized styling
                            VStack(spacing: 16) {
                                // FIXED: Only show display name field for signup AND not existing user
                                if isSignUp && !isExistingUserLogin {
                                    SharedTextField(
                                        title: "Display Name",
                                        text: $displayName,
                                        placeholder: "How should we call you?",
                                        icon: "person",
                                        focusedField: $focusedField,
                                        fieldType: .displayName
                                    )
                                }
                                
                                SharedTextField(
                                    title: "Email",
                                    text: $email,
                                    placeholder: "your.email@example.com",
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    focusedField: $focusedField,
                                    fieldType: .email
                                )
                                
                                SharedSecureField(
                                    title: "Password",
                                    text: $password,
                                    placeholder: "Enter password",
                                    showPassword: $showingPassword,
                                    focusedField: $focusedField,
                                    fieldType: .password
                                )
                                
                                // FIXED: Only show confirm password for signup AND not existing user
                                if isSignUp && !isExistingUserLogin {
                                    SharedSecureField(
                                        title: "Confirm Password",
                                        text: $confirmPassword,
                                        placeholder: "Confirm password",
                                        showPassword: $showingConfirmPassword,
                                        focusedField: $focusedField,
                                        fieldType: .confirmPassword
                                    )
                                }
                            }
                            .padding(.horizontal, 40)
                            .scaleEffect(isAnimating ? 1 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.7), value: isAnimating)
                            
                            // Submit Button
                            Button(action: {
                                focusedField = nil // Dismiss keyboard before submitting
                                Task {
                                    // FIXED: Force sign in for existing users, otherwise use toggle
                                    if isExistingUserLogin || !isSignUp {
                                        await handleSignIn()
                                    } else {
                                        await handleSignUp()
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if authService.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // FIXED: Show appropriate text based on context
                                    Text(isExistingUserLogin ? "Sign In" : (isSignUp ? "Create Account" : "Sign In"))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.white)
                                .cornerRadius(16)
                            }
                            .disabled(authService.isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            .padding(.horizontal, 40)
                            .scaleEffect(isAnimating ? 1 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.9), value: isAnimating)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("OR")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 40)
                            .scaleEffect(isAnimating ? 1 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.1), value: isAnimating)
                            
                            // Google Sign-In
                            Button(action: {
                                Task {
                                    await authService.signInWithGoogle()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Text("Continue with Google")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(authService.isLoading)
                            .padding(.horizontal, 40)
                            .scaleEffect(isAnimating ? 1 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.3), value: isAnimating)
                        }
                        
                        // Cancel button
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.5), value: isAnimating)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        // Single shared keyboard toolbar
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .foregroundColor(.primary)
                .fontWeight(.medium)
            }
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Oops!"),
                message: Text(authService.errorMessage ?? "Something went wrong. Please try again."),
                dismissButton: .default(Text("Got it")) {
                    authService.errorMessage = nil
                }
            )
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            // FIXED: Set initial state for existing users
            if isExistingUserLogin {
                isSignUp = false // Force sign in mode
                if displayName.isEmpty {
                    displayName = userName
                }
            } else {
                // Pre-fill display name if provided for new signups
                if isSignUp && displayName.isEmpty {
                    displayName = userName
                }
            }
        }
        .onChange(of: authService.errorMessage) { _, error in
            if error != nil {
                showingError = true
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                print("🔑 LoginView: Authentication successful, completing onboarding...")
                
                // CRITICAL: Call completion callback first to trigger UI transition
                onAuthComplete()
                
                // Initialize user fingerprint with onboarding data if available
                if let data = onboardingData {
                    Task {
                        await initializeUserFingerprint(with: data)
                        // Small delay before dismissing to ensure transition
                        try? await Task.sleep(for: .milliseconds(500))
                        await MainActor.run {
                            dismiss()
                        }
                    }
                } else {
                    // For existing users without onboarding data, dismiss with small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        // FIXED: For existing users, only validate email and password
        if isExistingUserLogin {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   email.contains("@")
        }
        
        // For new users with signup toggle
        if isSignUp {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   !displayName.isEmpty && 
                   password == confirmPassword &&
                   email.contains("@") &&
                   password.count >= 6
        } else {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   email.contains("@")
        }
    }
    
    private func handleSignIn() async {
        await authService.signInWithEmail(email, password: password)
        
        // FIXED: Always call completion callback after attempting signin
        // The onChange listener will handle the actual success case
        print("🔑 LoginView: Sign in attempt completed, isAuthenticated = \(authService.isAuthenticated)")
    }
    
    private func handleSignUp() async {
        guard password == confirmPassword else {
            await MainActor.run {
                authService.errorMessage = "Passwords do not match"
            }
            return
        }
        
        // Convert onboarding data to JSON format if available
        var onboardingJSON: [String: Any]? = nil
        if let data = onboardingData {
            onboardingJSON = [
                "selectedCategories": data.selectedCategories.map { $0.rawValue },
                "responses": data.responses.map { response in
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
                    
                    return responseData
                },
                "userName": data.userName,
                "completedAt": FieldValue.serverTimestamp()
            ]
        }
        
        await authService.signUpWithEmail(email, password: password, displayName: displayName, onboardingData: onboardingJSON)
        
        // Call completion callback after successful signup
        if authService.isAuthenticated {
            onAuthComplete()
        }
    }
    
    private func initializeUserFingerprint(with data: OnboardingData) async {
        guard let user = authService.user else { return }
        
        do {
            // Build comprehensive user fingerprint from onboarding data
            let preferredPlaceTypes = extractPreferredPlaceTypes(from: data)
            let moodHistory = extractMoodHistory(from: data)
            let cuisineHistory = extractCuisineHistory(from: data)
            
            var initialFingerprint: [String: Any] = [
                "displayName": data.userName,
                "email": user.email ?? "",
                "onboardingCompleted": true,
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
                "fingerprintCreatedAt": FieldValue.serverTimestamp(),
                "lastFingerprintUpdate": FieldValue.serverTimestamp()
            ]
            
            // Save to both users collection and userFingerprints collection
            let db = Firestore.firestore()
            
            // Update main user document
            try await db.collection("users").document(user.uid).setData(initialFingerprint, merge: true)
            
            // Create dedicated fingerprint document for faster recommendation queries
            try await db.collection("userFingerprints").document(user.uid).setData(initialFingerprint)
            
            print("🧬 User fingerprint initialized successfully from LoginView")
            
        } catch {
            print("❌ Failed to initialize user fingerprint: \(error)")
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



// MARK: - Shared Text Field
struct SharedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var focusedField: FocusState<LoginView.Field?>.Binding
    let fieldType: LoginView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .disableAutocorrection(keyboardType == .emailAddress)
                    .focused(focusedField, equals: fieldType)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

// MARK: - Shared Secure Field
struct SharedSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var showPassword: Bool
    var focusedField: FocusState<LoginView.Field?>.Binding
    let fieldType: LoginView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)
                
                if showPassword {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused(focusedField, equals: fieldType)
                } else {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused(focusedField, equals: fieldType)
                }
                
                Button(action: {
                    showPassword.toggle()
                }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

#Preview {
    LoginView(
        onboardingData: nil,
        userName: "",
        onAuthComplete: {},
        isForExistingUser: false
    )
    .environmentObject(AuthenticationService())
}