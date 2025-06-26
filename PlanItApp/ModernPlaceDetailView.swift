import SwiftUI
import MapKit
import Firebase

struct ModernPlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var dynamicCategoryManager = DynamicCategoryManager.shared
    @State private var showingImages = false
    @State private var selectedImageIndex = 0
    @State private var showingShare = false
    @State private var showingReviews = false
    @State private var showingDirections = false
    @EnvironmentObject var authService: AuthenticationService
    @State private var userReaction: UserReaction?
    @State private var whyText: String = ""
    @State private var placeVibes: String = ""
    @State private var isUpdatingFingerprint = false
    @State private var isGeneratingVibes = false
    private let gemini = GeminiAIService.shared
    @EnvironmentObject var fingerprintManager: UserFingerprintManager
    @State private var appearDate: Date?
    
    // Subtle gradient background for cards
    private var cardBackground: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.adaptiveBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Image Section
                        heroImageSection
                        
                        // Content Section
                        contentSection
                        
                        // AI Explanation Section (moved to bottom)
                        if !whyText.isEmpty {
                            aiExplanationSection
                                .padding(.horizontal)
                                .padding(.bottom, 100) // Space for reaction buttons
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Enhanced Reaction System (moved to overlay to stay at bottom)
                VStack {
                    Spacer()
                    reactionButtonsSection
                }
            }
            .overlay(alignment: .topTrailing) {
                // Close button
                closeButton
            }
            .sheet(isPresented: $showingImages) {
                imageGalleryView
            }
            .sheet(isPresented: $showingShare) {
                shareView
            }
            .sheet(isPresented: $showingReviews) {
                reviewsView
            }
        }
        .navigationBarHidden(true)
        .task {
            await fetchWhy()
            await generatePlaceVibes()
        }
        .onAppear {
            appearDate = Date()
        }
        .onDisappear {
            if let start = appearDate {
                let duration = Date().timeIntervalSince(start)
                if duration > 6 {
                    Task {
                        await DynamicCategoryManager.shared.recordPlaceInteraction(place: place, interaction: .viewed)
                    }
                }
            }
        }
    }
    
    private var heroImageSection: some View {
        ZStack(alignment: .topTrailing) {
            // Main image
            GeometryReader { geometry in
                if let imageUrl = place.images.first, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 300)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: 300)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                } else {
                    // Fallback image
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(place.name)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        )
                }
            }
            .frame(height: 300)
            
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: ModernSocialTheme.Spacing.lg) {
            // Quick Actions
            quickActionsSection
            
            // About Section
            aboutSection
            
            // Place Vibes Section
            placeVibesSection
            
            // Photos Section
            if place.images.count > 1 {
                photosSection
            }
            
            // Contact & Hours
            contactSection
            
            // Reviews Preview
            reviewsPreviewSection
            
            // Map Section
            mapSection
        }
        .padding(ModernSocialTheme.Spacing.lg)
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: ModernSocialTheme.Spacing.md) {
            // Call button
            if !place.phone.isEmpty && place.phone != "Phone available when you tap for details" {
                Button(action: {
                    if let phoneURL = URL(string: "tel:\(place.phone.filter("0123456789".contains))") {
                        UIApplication.shared.open(phoneURL)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Call")
                            .font(ModernSocialTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ModernSocialTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                            .fill(ModernSocialTheme.Colors.successGreen)
                    )
                }
            }
            
            // Directions button
            Button(action: {
                showingDirections = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Directions")
                        .font(ModernSocialTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ModernSocialTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                        .fill(ModernSocialTheme.Colors.primaryBlue)
                )
            }
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            HStack {
                Text("About")
                    .font(ModernSocialTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.sm) {
                // Location
                HStack(spacing: ModernSocialTheme.Spacing.sm) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                        .frame(width: 24)
                    
                    Text(place.location)
                        .font(ModernSocialTheme.Typography.body)
                        .foregroundColor(.adaptivePrimary)
                }
                
                // Description
                if !place.description.isEmpty && place.description != "Tap to learn more about this place" {
                    Text(place.description)
                        .font(ModernSocialTheme.Typography.body)
                        .foregroundColor(.adaptiveSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ModernSocialTheme.Spacing.sm) {
                        ForEach(sampleTags(for: place.category), id: \.self) { tag in
                            ModernTag(text: tag, isSelected: false)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            HStack {
                Text("Photos")
                    .font(ModernSocialTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                
                Spacer()
                
                Button("See All") {
                    showingImages = true
                }
                .font(ModernSocialTheme.Typography.subheadline)
                .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                .fontWeight(.semibold)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernSocialTheme.Spacing.sm) {
                    ForEach(Array(place.images.prefix(5).enumerated()), id: \.offset) { index, imageURL in
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                                .fill(Color.adaptiveSecondary)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    ModernLoadingView(size: 30)
                                )
                        }
                        .onTapGesture {
                            selectedImageIndex = index
                            showingImages = true
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            Text("Contact & Hours")
                .font(ModernSocialTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.adaptivePrimary)
            
            VStack(spacing: ModernSocialTheme.Spacing.sm) {
                // Phone
                if !place.phone.isEmpty && place.phone != "Phone available when you tap for details" {
                    HStack(spacing: ModernSocialTheme.Spacing.sm) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ModernSocialTheme.Colors.primaryBlue)
                            .frame(width: 24)
                        
                        Text(place.phone)
                            .font(ModernSocialTheme.Typography.body)
                            .foregroundColor(.adaptivePrimary)
                        
                        Spacer()
                    }
                }
                
                // Hours
                HStack(alignment: .top, spacing: ModernSocialTheme.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ModernSocialTheme.Colors.warningOrange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hours")
                            .font(ModernSocialTheme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptivePrimary)
                        
                        Text(place.hours)
                            .font(ModernSocialTheme.Typography.subheadline)
                            .foregroundColor(.adaptiveSecondary)
                    }
                    
                    Spacer()
                }
                
                // Website
                if let website = place.website, !website.isEmpty {
                    HStack(spacing: ModernSocialTheme.Spacing.sm) {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundColor(ModernSocialTheme.Colors.primaryPurple)
                            .frame(width: 24)
                        
                        Text("Visit Website")
                            .font(ModernSocialTheme.Typography.body)
                            .foregroundColor(ModernSocialTheme.Colors.primaryPurple)
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var reviewsPreviewSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            HStack {
                Text("Reviews")
                    .font(ModernSocialTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                
                Spacer()
                
                Button("See All") {
                    showingReviews = true
                }
                .font(ModernSocialTheme.Typography.subheadline)
                .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                .fontWeight(.semibold)
            }
            
            if place.reviews.isEmpty {
                VStack(spacing: ModernSocialTheme.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(ModernSocialTheme.Colors.warningOrange)
                    
                    Text("No reviews yet")
                        .font(ModernSocialTheme.Typography.body)
                        .foregroundColor(.adaptiveSecondary)
                    
                    Text("Be the first to share your experience!")
                        .font(ModernSocialTheme.Typography.caption)
                        .foregroundColor(.adaptiveSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(ModernSocialTheme.Spacing.lg)
            } else {
                // Show first few reviews
                VStack(spacing: ModernSocialTheme.Spacing.md) {
                    ForEach(Array(place.reviews.prefix(2)), id: \.id) { review in
                        ModernReviewCard(review: review)
                    }
                }
            }
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            Text("Location")
                .font(ModernSocialTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.adaptivePrimary)
            
            if let coordinates = place.coordinates {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [place]) { place in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude), tint: ModernSocialTheme.Colors.primaryPink)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium))
                .onTapGesture {
                    // Open in Maps app
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude))
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = place.name
                    mapItem.openInMaps()
                }
            }
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.large)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private var closeButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(ModernSocialTheme.Spacing.lg)
        .padding(.top, 50)
    }
    
    private var imageGalleryView: some View {
        TabView(selection: $selectedImageIndex) {
            ForEach(Array(place.images.enumerated()), id: \.offset) { index, imageURL in
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ModernLoadingView()
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle())
        .background(Color.black)
        .overlay(alignment: .topTrailing) {
            Button("Done") {
                showingImages = false
            }
            .font(ModernSocialTheme.Typography.headline)
            .foregroundColor(.white)
            .padding()
        }
    }
    
    private var shareView: some View {
        VStack {
            Text("Share \(place.name)")
                .font(ModernSocialTheme.Typography.title2)
                .fontWeight(.bold)
                .padding()
            
            // Share options would go here
            Text("Share functionality would be implemented here")
                .foregroundColor(.adaptiveSecondary)
                .padding()
            
            Spacer()
        }
    }
    
    private var reviewsView: some View {
        VStack {
            Text("All Reviews")
                .font(ModernSocialTheme.Typography.title2)
                .fontWeight(.bold)
                .padding()
            
            // Reviews list would go here
            Text("Full reviews view would be implemented here")
                .foregroundColor(.adaptiveSecondary)
                .padding()
            
            Spacer()
        }
    }
    
    private func sampleTags(for category: PlaceCategory) -> [String] {
        switch category {
        case .restaurants:
            return ["Fine Dining", "Outdoor Seating", "Wine Bar"]
        case .cafes:
            return ["Coffee", "WiFi", "Study Spot"]
        case .bars:
            return ["Cocktails", "Live Music", "Happy Hour"]
        case .venues:
            return ["Events", "Private Parties", "Weddings"]
        case .shopping:
            return ["Retail", "Fashion", "Local Goods"]
        }
    }

    /// Place Vibes Section - Shows emotional/physical feelings about the place
    private var placeVibesSection: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.md) {
            HStack {
                Text("🌟 Place Vibes")
                    .font(ModernSocialTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                
                Spacer()
                
                if isGeneratingVibes {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if !placeVibes.isEmpty {
                Text(placeVibes)
                    .font(ModernSocialTheme.Typography.body)
                    .foregroundColor(.adaptiveSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(ModernSocialTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                            .fill(ModernSocialTheme.Colors.primaryPink.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                                    .stroke(ModernSocialTheme.Colors.primaryPink.opacity(0.2), lineWidth: 1)
                            )
                    )
            } else if !isGeneratingVibes {
                Text("Tap to regenerate vibes")
                    .font(ModernSocialTheme.Typography.caption)
                    .foregroundColor(.adaptiveSecondary)
                    .onTapGesture {
                        Task {
                            await generatePlaceVibes()
                        }
                    }
            }
        }
    }
    
    /// Enhanced reaction function that updates user fingerprint
    private func reactToPlace(_ reaction: UserReaction) async {
        guard userReaction != reaction else { return } // no duplicate
        
        isUpdatingFingerprint = true
        
        // Update local state immediately for responsive UI
        userReaction = reaction
        
        // Record interaction using dynamic category manager
        let interaction: PlaceInteraction = reaction == .liked ? .liked : .disliked
        await dynamicCategoryManager.recordPlaceInteraction(place: place, interaction: interaction)
        
        isUpdatingFingerprint = false
        
        print("✅ User reacted \(reaction.rawValue) to \(place.name)")
    }
    
    /// Generates AI-powered vibes for the place
    private func generatePlaceVibes() async {
        guard placeVibes.isEmpty else { return }
        
        isGeneratingVibes = true
        
        let vibesPrompt = """
        You are a place vibes expert. Describe the emotional and physical feeling someone would get when visiting this place.
        
        Place: \(place.name)
        Category: \(place.category.displayName)
        Description: \(place.description)
        Rating: \(place.rating)/5.0
        Price: \(place.priceRange)
        
        Generate a 2-3 sentence description of the VIBES and FEELINGS someone would experience here.
        Focus on:
        - Atmosphere and mood
        - Energy level 
        - Emotional feelings
        - Physical sensations
        - Social dynamics
        
        Keep it conversational and relatable. No JSON, just natural text.
        """
        
        gemini.generateStructuredResponse(prompt: vibesPrompt) { response in
            Task { @MainActor in
                placeVibes = response.trimmingCharacters(in: .whitespacesAndNewlines)
                isGeneratingVibes = false
            }
        }
    }
    
    /// Gets the personalized recommendation for this place if it exists  
    private func getPersonalizedRecommendation() -> PersonalizedRecommendation? {
        // Since we're no longer using the old recommendation manager, return nil for now
        return nil
    }

    /// Fetches AI explanation for why this place was recommended
    private func fetchWhy() async {
        guard whyText.isEmpty else { return }
        
        // Get user's fingerprint for personalized explanation
        let prompt = fingerprintManager.buildGeminiPrompt()
        
        let enhancedPrompt = """
        Based on this user's profile and preferences:
        \(prompt)
        
        Explain in 2-3 engaging sentences WHY the place "\(place.name)" (Category: \(place.category.displayName), Rating: \(place.rating)/5, Price: \(place.priceRange)) is specifically recommended for this user.
        
        Focus on:
        - How it matches their onboarding preferences
        - What they've liked/disliked before
        - The specific experience they'll have
        - Why this choice is personally curated for them
        
        Write as their personal AI concierge who knows them well. Use "you" and make it feel intimate and personalized.
        Be specific about what makes this place perfect for their taste and current context.
        """
        
        gemini.generateStructuredResponse(prompt: enhancedPrompt) { explanation in
            Task { @MainActor in
                // Clean the response to get just the text explanation
                let cleanedExplanation = explanation
                    .replacingOccurrences(of: "```", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                self.whyText = cleanedExplanation.isEmpty ? 
                    "This place matches your preferences perfectly! The atmosphere and offerings align with what you typically enjoy." : 
                    cleanedExplanation
            }
        }
    }

    // MARK: - Separated AI Explanation Section
    private var aiExplanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Why AI Picked This Place")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text(cleanWhyText(whyText))
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    /// Clean the AI explanation text from JSON symbols and IDs
    private func cleanWhyText(_ text: String) -> String {
        var cleanedText = text
        
        // Remove JSON-like structures
        cleanedText = cleanedText.replacingOccurrences(of: "\"", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "{", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "}", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "[", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "]", with: "")
        
        // Remove place IDs and category references
        let patterns = [
            "place_id: [^,\\s]*",
            "placeId: [^,\\s]*",
            "categories: [^,\\s]*",
            "category: [^,\\s]*",
            "id: [^,\\s]*",
            "ChIJ[^,\\s]*",
            "confidence: [0-9.]*"
        ]
        
        for pattern in patterns {
            cleanedText = cleanedText.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        // Clean up extra commas and spaces
        cleanedText = cleanedText.replacingOccurrences(of: ",", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "  ", with: " ")
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If text is empty or too short, provide a default explanation
        if cleanedText.isEmpty || cleanedText.count < 10 {
            return "This place was personally selected based on your preferences, location, and past activity. It matches your taste for quality experiences in your area."
        }
        
        return cleanedText
    }
    
    // MARK: - Separated Reaction Buttons
    private var reactionButtonsSection: some View {
        HStack(spacing: 40) {
            // Thumbs Up Button
            Button {
                Task { await reactToPlace(.liked) }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: userReaction == .liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(userReaction == .liked ? .green : .white)
                    
                    Text("Love it")
                        .font(.caption)
                        .foregroundColor(userReaction == .liked ? .green : .white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingFingerprint)

            // Thumbs Down Button
            Button {
                Task { await reactToPlace(.disliked) }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: userReaction == .disliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(userReaction == .disliked ? .red : .white)
                    
                    Text("Not for me")
                        .font(.caption)
                        .foregroundColor(userReaction == .disliked ? .red : .white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingFingerprint)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 30)
        .opacity(isUpdatingFingerprint ? 0.6 : 1.0)
        .overlay(
            // Loading indicator when updating fingerprint
            ProgressView()
                .scaleEffect(0.8)
                .opacity(isUpdatingFingerprint ? 1 : 0)
        )
    }
}

// MARK: - Modern Review Card
struct ModernReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernSocialTheme.Spacing.sm) {
            HStack {
                // User avatar placeholder
                Circle()
                    .fill(ModernSocialTheme.Colors.primaryPink.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(review.authorName.prefix(1))
                            .font(ModernSocialTheme.Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(ModernSocialTheme.Colors.primaryPink)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.authorName)
                        .font(ModernSocialTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptivePrimary)
                    
                    HStack(spacing: 4) {
                        ModernRatingView(rating: Double(review.rating), size: 12, color: ModernSocialTheme.Colors.warningOrange)
                        
                        Text(DateFormatter.reviewDate.string(from: review.time))
                            .font(ModernSocialTheme.Typography.caption)
                            .foregroundColor(.adaptiveSecondary)
                    }
                }
                
                Spacer()
            }
            
            Text(review.text)
                .font(ModernSocialTheme.Typography.body)
                .foregroundColor(.adaptivePrimary)
                .lineLimit(3)
        }
        .padding(ModernSocialTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernSocialTheme.CornerRadius.medium)
                .fill(Color.adaptiveSecondary)
        )
    }
}

#Preview {
    let samplePlace = Place(
        id: UUID(),
        name: "The Modern Cafe",
        description: "A cozy artisanal coffee shop with locally sourced beans and handcrafted pastries",
        category: .cafes,
        rating: 4.5,
        reviewCount: 127,
                        priceRange: "$$",
        images: [
            "https://example.com/image1.jpg",
            "https://example.com/image2.jpg",
            "https://example.com/image3.jpg"
        ],
        location: "123 Main St, Downtown",
        hours: "Mon-Fri: 7AM-7PM, Sat-Sun: 8AM-6PM",
        detailedHours: nil,
        phone: "(555) 123-4567",
        website: "https://moderncafe.com",
        menuItems: [],
        reviews: [],
        googlePlaceId: "sample_id",
        sentiment: nil,
        isCurrentlyOpen: true,
        hasActualMenu: false,
        coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060)
    )
    
    ModernPlaceDetailView(place: samplePlace)
} 