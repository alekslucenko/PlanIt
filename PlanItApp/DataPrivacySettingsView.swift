import SwiftUI

// MARK: - Data Privacy Settings View
// Complies with Apple App Store Guidelines Section 5.1 - Privacy
struct DataPrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var personalizedAdsEnabled = false
    @State private var dataSharingEnabled = false
    @State private var showingDataExportOptions = false
    @State private var showingDataDeletionAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data Privacy")
                                    .font(.headline)
                                
                                Text("Control what data PlanIt collects and how it's used")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Privacy Overview")
                        .textCase(nil)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "chart.bar.fill",
                        title: "Usage Analytics",
                        subtitle: "Help improve the app by sharing anonymous usage data",
                        isOn: $analyticsEnabled,
                        color: .blue
                    )
                    
                    SettingsToggleRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Crash Reporting",
                        subtitle: "Automatically send crash reports to help fix bugs",
                        isOn: $crashReportingEnabled,
                        color: .orange
                    )
                    
                    SettingsToggleRow(
                        icon: "megaphone.fill",
                        title: "Personalized Recommendations",
                        subtitle: "Use your activity to improve place suggestions",
                        isOn: $personalizedAdsEnabled,
                        color: .purple
                    )
                } header: {
                    Text("Data Collection")
                        .textCase(nil)
                } footer: {
                    Text("All data collection is optional and can be disabled at any time. Your privacy choices are respected and stored locally.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Your Data")
                                .font(.body)
                            
                            Text("Download a copy of your personal data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Export") {
                            showingDataExportOptions = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account & Data")
                                .font(.body)
                            
                            Text("Permanently delete your account and all associated data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Delete") {
                            showingDataDeletionAlert = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your Rights")
                        .textCase(nil)
                } footer: {
                    Text("You have the right to access, export, and delete your personal data at any time, in compliance with GDPR and CCPA regulations.")
                        .font(.caption)
                }
                
                Section {
                    PrivacyInfoRow(
                        icon: "doc.text.fill",
                        title: "What We Collect",
                        description: "• Account information (email, username)\n• Location data (when permitted)\n• App usage patterns (if analytics enabled)\n• Device information for app functionality"
                    )
                    
                    PrivacyInfoRow(
                        icon: "lock.fill",
                        title: "How We Protect Data",
                        description: "• All data encrypted in transit and at rest\n• No data sold to third parties\n• Minimal data collection principle\n• Regular security audits"
                    )
                    
                    PrivacyInfoRow(
                        icon: "hand.raised.fill",
                        title: "What We Don't Do",
                        description: "• Track you across other apps or websites\n• Sell your personal information\n• Access your device without permission\n• Share data without explicit consent"
                    )
                } header: {
                    Text("Privacy Practices")
                        .textCase(nil)
                }
                
                Section {
                    Link(destination: URL(string: "https://planit.app/privacy")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Privacy Policy")
                                .font(.body)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://planit.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Terms of Service")
                                .font(.body)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Legal Documents")
                        .textCase(nil)
                }
            }
            .navigationTitle("Data Privacy")
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
        .alert("Delete Account", isPresented: $showingDataDeletionAlert) {
            Button("Delete", role: .destructive) {
                // Handle account deletion
                handleAccountDeletion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted from our servers.")
        }
        .sheet(isPresented: $showingDataExportOptions) {
            DataExportView()
        }
        .onAppear {
            loadPrivacySettings()
        }
        .onChange(of: analyticsEnabled) { _, _ in savePrivacySettings() }
        .onChange(of: crashReportingEnabled) { _, _ in savePrivacySettings() }
        .onChange(of: personalizedAdsEnabled) { _, _ in savePrivacySettings() }
    }
    
    private func loadPrivacySettings() {
        let defaults = UserDefaults.standard
        analyticsEnabled = defaults.bool(forKey: "privacy_analytics_enabled")
        crashReportingEnabled = defaults.bool(forKey: "privacy_crash_reporting_enabled")
        personalizedAdsEnabled = defaults.bool(forKey: "privacy_personalized_ads_enabled")
    }
    
    private func savePrivacySettings() {
        let defaults = UserDefaults.standard
        defaults.set(analyticsEnabled, forKey: "privacy_analytics_enabled")
        defaults.set(crashReportingEnabled, forKey: "privacy_crash_reporting_enabled")
        defaults.set(personalizedAdsEnabled, forKey: "privacy_personalized_ads_enabled")
    }
    
    private func handleAccountDeletion() {
        // Implementation for account deletion
        print("Account deletion requested - implement API call")
    }
}

// MARK: - Privacy Info Row Component
struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Data Export View
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormats: Set<String> = ["JSON"]
    @State private var isExporting = false
    
    let exportFormats = ["JSON", "CSV", "PDF"]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Choose the format for your data export. This will include all your personal information stored in PlanIt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Export Format")
                        .textCase(nil)
                }
                
                Section {
                    ForEach(exportFormats, id: \.self) { format in
                        HStack {
                            Text(format)
                            Spacer()
                            if selectedFormats.contains(format) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFormats.contains(format) {
                                selectedFormats.remove(format)
                            } else {
                                selectedFormats.insert(format)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Export Data") {
                        startExport()
                    }
                    .disabled(selectedFormats.isEmpty || isExporting)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        // Implementation for data export
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            dismiss()
        }
    }
} 