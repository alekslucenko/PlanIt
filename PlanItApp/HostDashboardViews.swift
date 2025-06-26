import SwiftUI
import Charts
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

// MARK: - ESSENTIAL HOST DASHBOARD COMPONENTS (FIXING BUILD ERRORS)

// ProfileModeSwitcher - Critical Component
struct ProfileModeSwitcher: View {
    @StateObject private var partyManager = PartyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isBusinessMode = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isBusinessMode.toggle()
                partyManager.toggleHostMode()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isBusinessMode ? "building.2" : "person.circle")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(isBusinessMode ? "Business" : "Personal")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isBusinessMode ? themeManager.businessAccent : themeManager.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isBusinessMode ? themeManager.businessPrimary : themeManager.cardBackground)
                    .overlay(
                        Capsule()
                            .stroke(isBusinessMode ? themeManager.businessPrimary : themeManager.secondaryText.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.3), value: isBusinessMode)
        .onAppear {
            isBusinessMode = partyManager.isHostMode
        }
        .onChange(of: partyManager.isHostMode) { _, newValue in
            isBusinessMode = newValue
        }
    }
}

// HostAnalyticsView - Missing Component Referenced in ModernMainTabView
struct HostAnalyticsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var partyManager = PartyManager.shared
    @State private var selectedTimeframe: String = "This Month"
    
    var body: some View {
        ZStack {
            themeManager.businessBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Analytics Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Business Analytics")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(themeManager.businessText)
                            
                            Spacer()
                            
                            Picker("Timeframe", selection: $selectedTimeframe) {
                                Text("This Week").tag("This Week")
                                Text("This Month").tag("This Month")
                                Text("Last Month").tag("Last Month")
                                Text("This Year").tag("This Year")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accentColor(themeManager.businessPrimary)
                        }
                        
                        Text("Comprehensive insights into your business performance")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.businessSecondaryText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Analytics Content
                    Text("📊 Advanced Analytics Coming Soon")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.businessPrimary)
                        .padding(.top, 100)
                    
                    Text("Detailed revenue, attendance, and performance metrics")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// CelebrityBookingView - Missing Component Referenced in ModernMainTabView
struct CelebrityBookingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            themeManager.businessBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("🌟")
                    .font(.system(size: 80))
                
                Text("Celebrity Booking")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(themeManager.businessText)
                
                Text("Premium celebrity network for exclusive events coming soon")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarHidden(true)
    }
}

// SecurityBookingView - Missing Component Referenced in ModernMainTabView
struct SecurityBookingView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            themeManager.businessBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("🛡️")
                    .font(.system(size: 80))
                
                Text("Security Services")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(themeManager.businessText)
                
                Text("Professional security teams for your exclusive events coming soon")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarHidden(true)
    }
}

// ConciergeServicesView - Missing Component Referenced in ModernMainTabView
struct ConciergeServicesView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            themeManager.businessBackground
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("🔔")
                    .font(.system(size: 80))
                
                Text("Concierge Services")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(themeManager.businessText)
                
                Text("Exclusive concierge services for luxury events coming soon")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.businessSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarHidden(true)
    }
}

// EnhancedAnalyticsView - Missing Component
struct EnhancedAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.businessBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Text("📊")
                        .font(.system(size: 80))
                    
                    Text("Advanced Analytics")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(themeManager.businessText)
                    
                    Text("Comprehensive business insights and performance metrics coming soon")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.businessSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .padding(.top, 60)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.businessPrimary)
                }
            }
        }
    }
}

// NOTE: HostDashboardView, HostPartiesView, HostTabBar, and other components 
// are defined in ModernMainTabView.swift to avoid duplication 