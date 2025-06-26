import SwiftUI

// MARK: - Profile Visibility Settings View
// Controls who can see user profile and activity
struct VisibilitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profileDiscoverable = true
    @State private var showLastSeen = false
    @State private var showCurrentLocation = false
    @State private var allowFriendRequests = true
    @State private var showFriendsToPublic = false
    @State private var showActivityStatus = true
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.purple)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Profile Visibility")
                                    .font(.headline)
                                
                                Text("Control who can see your profile and activity")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("About Visibility")
                        .textCase(nil)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "person.crop.circle.fill",
                        title: "Discoverable Profile",
                        subtitle: "Allow others to find your profile by username",
                        isOn: $profileDiscoverable,
                        color: .blue
                    )
                    
                    SettingsToggleRow(
                        icon: "person.badge.plus.fill",
                        title: "Accept Friend Requests",
                        subtitle: "Allow other users to send you friend requests",
                        isOn: $allowFriendRequests,
                        color: .green
                    )
                    
                    SettingsToggleRow(
                        icon: "circle.fill",
                        title: "Show Activity Status",
                        subtitle: "Let friends see when you're active",
                        isOn: $showActivityStatus,
                        color: .orange
                    )
                } header: {
                    Text("Basic Privacy")
                        .textCase(nil)
                } footer: {
                    Text("These settings control the basic visibility of your profile to other users.")
                        .font(.caption)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "clock.fill",
                        title: "Show Last Seen",
                        subtitle: "Display when you were last active to friends",
                        isOn: $showLastSeen,
                        color: .gray
                    )
                    
                    SettingsToggleRow(
                        icon: "location.fill",
                        title: "Share Current Location",
                        subtitle: "Let friends see your current city/area",
                        isOn: $showCurrentLocation,
                        color: .red
                    )
                    
                    SettingsToggleRow(
                        icon: "person.2.fill",
                        title: "Public Friends List",
                        subtitle: "Show your friends list to other users",
                        isOn: $showFriendsToPublic,
                        color: .purple
                    )
                } header: {
                    Text("Advanced Privacy")
                        .textCase(nil)
                } footer: {
                    Text("Advanced privacy controls for location and social information sharing.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacy by Design")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("PlanIt is built with privacy in mind. All visibility settings default to the most private option, and you have complete control over your data sharing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Rights")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("• Change any setting at any time\n• Delete your data completely\n• Export your information\n• Control third-party access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Privacy Information")
                        .textCase(nil)
                }
            }
            .navigationTitle("Visibility")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            loadVisibilitySettings()
        }
        .onChange(of: profileDiscoverable) { _, _ in saveVisibilitySettings() }
        .onChange(of: showLastSeen) { _, _ in saveVisibilitySettings() }
        .onChange(of: showCurrentLocation) { _, _ in saveVisibilitySettings() }
        .onChange(of: allowFriendRequests) { _, _ in saveVisibilitySettings() }
        .onChange(of: showFriendsToPublic) { _, _ in saveVisibilitySettings() }
        .onChange(of: showActivityStatus) { _, _ in saveVisibilitySettings() }
    }
    
    private func loadVisibilitySettings() {
        let defaults = UserDefaults.standard
        profileDiscoverable = defaults.bool(forKey: "profile_discoverable")
        showLastSeen = defaults.bool(forKey: "show_last_seen")
        showCurrentLocation = defaults.bool(forKey: "show_current_location")
        allowFriendRequests = defaults.bool(forKey: "allow_friend_requests")
        showFriendsToPublic = defaults.bool(forKey: "show_friends_to_public")
        showActivityStatus = defaults.bool(forKey: "show_activity_status")
    }
    
    private func saveVisibilitySettings() {
        let defaults = UserDefaults.standard
        defaults.set(profileDiscoverable, forKey: "profile_discoverable")
        defaults.set(showLastSeen, forKey: "show_last_seen")
        defaults.set(showCurrentLocation, forKey: "show_current_location")
        defaults.set(allowFriendRequests, forKey: "allow_friend_requests")
        defaults.set(showFriendsToPublic, forKey: "show_friends_to_public")
        defaults.set(showActivityStatus, forKey: "show_activity_status")
    }
} 