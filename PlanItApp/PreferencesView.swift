import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var animateNeon = false
    @State private var showingThemeAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic themed background
                theme.backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: theme.isDarkMode)
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Header Section
                        headerSection
                        
                        // Main Theme Toggle Section
                        themeToggleSection
                        
                        // Additional Settings
                        additionalSettingsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(theme.accentBlue)
                .font(.system(size: 16, weight: .semibold))
            )
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            startNeonAnimation()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Theme Icon
            ZStack {
                Circle()
                    .fill(theme.cardBackground)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(theme.isDarkMode ? theme.neonPurple.opacity(0.3) : theme.accentBlue.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(
                        color: theme.isDarkMode ? theme.neonPurple.opacity(0.3) : theme.accentBlue.opacity(0.2),
                        radius: theme.isDarkMode ? 20 : 8,
                        x: 0,
                        y: theme.isDarkMode ? 8 : 4
                    )
                
                Image(systemName: theme.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(theme.isDarkMode ? theme.neonPurple : theme.accentBlue)
                    .rotationEffect(.degrees(theme.isDarkMode ? 0 : 180))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: theme.isDarkMode)
            }
            
            VStack(spacing: 8) {
                Text("Theme Settings")
                    .font(.system(size: 24, weight: .bold))
                    .themedText(.primary)
                
                Text("Customize your app experience")
                    .font(.system(size: 16, weight: .medium))
                    .themedText(.secondary)
            }
        }
    }
    
    private var themeToggleSection: some View {
        VStack(spacing: 24) {
            // Current Theme Display
            HStack {
                Text("Current Theme")
                    .font(.system(size: 18, weight: .semibold))
                    .themedText(.primary)
                
                Spacer()
                
                Text(theme.isDarkMode ? "Dark Mode" : "Light Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.isDarkMode ? theme.neonPink : theme.accentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.isDarkMode ? theme.neonPink.opacity(0.1) : theme.accentBlue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.isDarkMode ? theme.neonPink.opacity(0.3) : theme.accentBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .themedCard()
            
            // NEON TOGGLE BUTTON
            Button(action: {
                hapticFeedback()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showingThemeAnimation = true
                    theme.toggleTheme()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingThemeAnimation = false
                }
            }) {
                ZStack {
                    // Background glow
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.isDarkMode ? theme.neonPink.opacity(0.3) : theme.accentBlue.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 280, height: 120)
                        .blur(radius: 20)
                        .opacity(animateNeon ? 1.0 : 0.6)
                    
                    // Main button container
                    RoundedRectangle(cornerRadius: 25)
                        .fill(theme.cardBackground)
                        .frame(width: 260, height: 80)
                        .overlay(
                            // Neon border
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    LinearGradient(
                                        colors: theme.isDarkMode ? [
                                            theme.neonPink,
                                            theme.neonPurple,
                                            theme.neonBlue,
                                            theme.neonPink
                                        ] : [
                                            theme.accentBlue,
                                            Color.cyan,
                                            theme.accentBlue
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .opacity(animateNeon ? 1.0 : 0.7)
                        )
                        .shadow(
                            color: theme.isDarkMode ? theme.neonPink.opacity(0.6) : theme.accentBlue.opacity(0.4),
                            radius: theme.isDarkMode ? 25 : 15,
                            x: 0,
                            y: theme.isDarkMode ? 10 : 5
                        )
                    
                    // Toggle content
                    HStack(spacing: 20) {
                        // Light mode side
                        VStack(spacing: 8) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(theme.isDarkMode ? theme.secondaryText : theme.neonYellow)
                                .scaleEffect(theme.isDarkMode ? 0.8 : 1.2)
                            
                            Text("Light")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.isDarkMode ? theme.secondaryText : theme.accentBlue)
                        }
                        .opacity(theme.isDarkMode ? 0.5 : 1.0)
                        
                        // Toggle switch
                        ZStack {
                            // Track
                            RoundedRectangle(cornerRadius: 20)
                                .fill(theme.isDarkMode ? theme.neonPurple.opacity(0.3) : theme.accentBlue.opacity(0.3))
                                .frame(width: 60, height: 32)
                            
                            // Thumb
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: theme.isDarkMode ? [
                                            theme.neonPink,
                                            theme.neonPurple
                                        ] : [
                                            Color.white,
                                            theme.accentBlue.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                                .shadow(
                                    color: theme.isDarkMode ? theme.neonPink.opacity(0.6) : Color.black.opacity(0.2),
                                    radius: theme.isDarkMode ? 8 : 4,
                                    x: 0,
                                    y: 2
                                )
                                .offset(x: theme.isDarkMode ? 16 : -16)
                        }
                        
                        // Dark mode side
                        VStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(theme.isDarkMode ? theme.neonPurple : theme.secondaryText)
                                .scaleEffect(theme.isDarkMode ? 1.2 : 0.8)
                            
                            Text("Dark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.isDarkMode ? theme.neonPink : theme.secondaryText)
                        }
                        .opacity(theme.isDarkMode ? 1.0 : 0.5)
                    }
                    
                    // Theme transition overlay
                    if showingThemeAnimation {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        theme.isDarkMode ? theme.neonPurple : theme.accentBlue,
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 260, height: 80)
                            .opacity(0.3)
                            .scaleEffect(2.0)
                            .animation(.easeOut(duration: 0.6), value: showingThemeAnimation)
                    }
                }
            }
            .scaleEffect(showingThemeAnimation ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: theme.isDarkMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingThemeAnimation)
        }
    }
    
    private var additionalSettingsSection: some View {
        VStack(spacing: 16) {
            Text("Other Settings")
                .font(.system(size: 20, weight: .semibold))
                .themedText(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                PreferenceRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage your notification preferences",
                    iconColor: theme.accentOrange
                ) {}
                
                PreferenceRow(
                    icon: "location.fill",
                    title: "Location Services",
                    subtitle: "Control location access",
                    iconColor: theme.accentGreen
                ) {}
                
                PreferenceRow(
                    icon: "heart.fill",
                    title: "Favorites Sync",
                    subtitle: "Sync favorites across devices",
                    iconColor: theme.accentPink
                ) {}
                
                PreferenceRow(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    subtitle: "Manage your privacy settings",
                    iconColor: theme.accentPurple
                ) {}
                
                // HOST MODE TOGGLE
                HostModeToggleRow()
            }
        }
    }
    
    private func startNeonAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            animateNeon = true
        }
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preference Row Component
struct PreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: () -> Void
    
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .themedText(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .themedText(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .themedText(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Host Mode Toggle Row
struct HostModeToggleRow: View {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var theme = ThemeManager.shared
    @State private var showingHostModeSetup = false
    @State private var showingDisableConfirmation = false
    
    var body: some View {
        Button(action: {
            if partyManager.isHostMode {
                showingDisableConfirmation = true
            } else {
                showingHostModeSetup = true
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(theme.accentGold.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: partyManager.isHostMode ? "building.2.fill" : "building.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.accentGold)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Party Host Mode")
                        .font(.system(size: 16, weight: .semibold))
                        .themedText(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(partyManager.isHostMode ? "Currently hosting parties" : "Switch to host parties and events")
                        .font(.system(size: 14, weight: .medium))
                        .themedText(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Toggle indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(partyManager.isHostMode ? theme.accentGold.opacity(0.3) : theme.secondaryText.opacity(0.3))
                        .frame(width: 50, height: 28)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .offset(x: partyManager.isHostMode ? 11 : -11)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: partyManager.isHostMode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingHostModeSetup) {
            HostModeSetupView()
        }
        .alert("Disable Host Mode", isPresented: $showingDisableConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                Task {
                    do {
                        try await partyManager.disableHostMode()
                    } catch {
                        print("Error disabling host mode: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to disable host mode? Your host profile will be archived.")
        }
    }
}

// MARK: - Host Mode Setup View
struct HostModeSetupView: View {
    @StateObject private var partyManager = PartyManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var businessName = ""
    @State private var contactEmail = ""
    @State private var phoneNumber = ""
    @State private var businessType = "Event Planning"
    @State private var isSettingUp = false
    
    private let businessTypes = [
        "Event Planning", "Restaurant/Bar", "Venue", "Entertainment", "Catering", "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Business Information") {
                    TextField("Business Name", text: $businessName)
                    TextField("Contact Email", text: $contactEmail)
                        .keyboardType(.emailAddress)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    
                    Picker("Business Type", selection: $businessType) {
                        ForEach(businessTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("What you get") {
                    Label("Host Dashboard", systemImage: "chart.bar.fill")
                    Label("Business Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Party Creation Tools", systemImage: "plus.circle.fill")
                    Label("Celebrity Booking", systemImage: "star.fill")
                    Label("Security Services", systemImage: "shield.fill")
                    Label("Concierge Services", systemImage: "bell.fill")
                }
            }
            .navigationTitle("Setup Host Mode")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enable") {
                        enableHostMode()
                    }
                    .disabled(!canEnable || isSettingUp)
                }
            }
        }
    }
    
    private var canEnable: Bool {
        !businessName.isEmpty && !contactEmail.isEmpty && !phoneNumber.isEmpty
    }
    
    private func enableHostMode() {
        isSettingUp = true
        
        Task {
            do {
                try await partyManager.enableHostMode(
                    businessName: businessName,
                    contactEmail: contactEmail,
                    phoneNumber: phoneNumber,
                    businessType: businessType
                )
                
                await MainActor.run {
                    isSettingUp = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    // Handle error
                }
            }
        }
    }
}

#Preview {
    PreferencesView()
} 