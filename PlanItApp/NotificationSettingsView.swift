import SwiftUI
import UserNotifications

// MARK: - Notification Settings View
// Complies with Apple App Store Guidelines Section 4.5.4 - Push Notifications
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var pushNotificationsEnabled = false
    @State private var friendRequestsEnabled = true
    @State private var messagesEnabled = true
    @State private var systemNotificationsEnabled = false
    @State private var marketingNotificationsEnabled = false
    @State private var showingSystemSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Preferences")
                                    .font(.headline)
                                
                                Text("Control how you receive notifications from PlanIt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("About Notifications")
                        .textCase(nil)
                }
                
                Section {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System Notification Settings")
                                .font(.body)
                            
                            Text("Manage notifications in iOS Settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("System Settings")
                        .textCase(nil)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "person.2.fill",
                        title: "Friend Requests",
                        subtitle: "Get notified when someone sends you a friend request",
                        isOn: $friendRequestsEnabled,
                        color: .blue
                    )
                    
                    SettingsToggleRow(
                        icon: "message.fill",
                        title: "Messages",
                        subtitle: "Receive notifications for new messages",
                        isOn: $messagesEnabled,
                        color: .green
                    )
                    
                    SettingsToggleRow(
                        icon: "info.circle.fill",
                        title: "App Updates",
                        subtitle: "Notifications about app features and updates",
                        isOn: $systemNotificationsEnabled,
                        color: .orange
                    )
                } header: {
                    Text("App Notifications")
                        .textCase(nil)
                } footer: {
                    Text("These settings control notifications within the app. To completely disable notifications, use iOS Settings above.")
                        .font(.caption)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "megaphone.fill",
                        title: "Marketing Communications",
                        subtitle: "Optional promotional notifications about new features",
                        isOn: $marketingNotificationsEnabled,
                        color: .purple
                    )
                } header: {
                    Text("Optional")
                        .textCase(nil)
                } footer: {
                    Text("Marketing notifications are completely optional and can be disabled at any time. We respect your privacy and won't spam you.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacy Compliance")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("PlanIt follows Apple's privacy guidelines and only sends notifications you've explicitly allowed. Your notification preferences are stored locally on your device.")
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
            .navigationTitle("Notifications")
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
            loadNotificationSettings()
        }
        .onChange(of: friendRequestsEnabled) { _, newValue in
            saveNotificationSettings()
        }
        .onChange(of: messagesEnabled) { _, newValue in
            saveNotificationSettings()
        }
        .onChange(of: systemNotificationsEnabled) { _, newValue in
            saveNotificationSettings()
        }
        .onChange(of: marketingNotificationsEnabled) { _, newValue in
            saveNotificationSettings()
        }
    }
    
    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func loadNotificationSettings() {
        let defaults = UserDefaults.standard
        friendRequestsEnabled = defaults.bool(forKey: "notifications_friend_requests")
        messagesEnabled = defaults.bool(forKey: "notifications_messages")
        systemNotificationsEnabled = defaults.bool(forKey: "notifications_system")
        marketingNotificationsEnabled = defaults.bool(forKey: "notifications_marketing")
        
        // Check system notification authorization
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                pushNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func saveNotificationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(friendRequestsEnabled, forKey: "notifications_friend_requests")
        defaults.set(messagesEnabled, forKey: "notifications_messages")
        defaults.set(systemNotificationsEnabled, forKey: "notifications_system")
        defaults.set(marketingNotificationsEnabled, forKey: "notifications_marketing")
    }
}

// MARK: - Settings Toggle Row Component
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.vertical, 4)
    }
} 