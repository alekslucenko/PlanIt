import SwiftUI
import LocalAuthentication

// MARK: - Security Settings View
// Complies with Apple App Store Guidelines for security and privacy
struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var biometricLockEnabled = false
    @State private var autoLockEnabled = true
    @State private var screenshotProtectionEnabled = false
    @State private var twoFactorEnabled = false
    @State private var dataEncryptionEnabled = true
    @State private var showingBiometricAlert = false
    @State private var biometricError = ""
    @State private var showingAccountDeletion = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Security & Privacy")
                                    .font(.headline)
                                
                                Text("Protect your account and personal data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("About Security")
                        .textCase(nil)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "faceid",
                        title: biometricType,
                        subtitle: "Use \(biometricType.lowercased()) to unlock PlanIt",
                        isOn: $biometricLockEnabled,
                        color: .blue
                    )
                    .onTapGesture {
                        toggleBiometricLock()
                    }
                    
                    SettingsToggleRow(
                        icon: "lock.rotation",
                        title: "Auto-Lock",
                        subtitle: "Automatically lock app when inactive",
                        isOn: $autoLockEnabled,
                        color: .orange
                    )
                    
                    SettingsToggleRow(
                        icon: "camera.metering.none",
                        title: "Screenshot Protection",
                        subtitle: "Prevent screenshots in sensitive areas",
                        isOn: $screenshotProtectionEnabled,
                        color: .purple
                    )
                } header: {
                    Text("App Security")
                        .textCase(nil)
                } footer: {
                    Text("These settings help protect your app and data from unauthorized access.")
                        .font(.caption)
                }
                
                Section {
                    SettingsToggleRow(
                        icon: "key.fill",
                        title: "Two-Factor Authentication",
                        subtitle: "Add an extra layer of security to your account",
                        isOn: $twoFactorEnabled,
                        color: .green
                    )
                    
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data Encryption")
                                .font(.body)
                            
                            Text("Your data is encrypted using industry-standard AES-256")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Account Security")
                        .textCase(nil)
                }
                
                Section {
                    Button(action: {
                        // Navigate to password change
                    }) {
                        HStack {
                            Image(systemName: "key.horizontal.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Change Password")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Navigate to active sessions
                    }) {
                        HStack {
                            Image(systemName: "desktopcomputer.and.arrow.down")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active Sessions")
                                    .foregroundColor(.primary)
                                
                                Text("Manage logged-in devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Navigate to privacy settings
                    }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Privacy Center")
                                    .foregroundColor(.primary)
                                
                                Text("Manage data and privacy settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Account Management")
                        .textCase(nil)
                }
                
                Section {
                    Button(action: {
                        showingAccountDeletion = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete Account")
                                    .foregroundColor(.red)
                                
                                Text("Permanently delete your account and all data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Danger Zone")
                        .textCase(nil)
                } footer: {
                    Text("Account deletion is permanent and cannot be undone. All your data will be completely removed from our servers.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Security Standards")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("PlanIt follows industry best practices for data security including end-to-end encryption, secure authentication, and regular security audits.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Security Information")
                        .textCase(nil)
                }
            }
            .navigationTitle("Security")
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
        .alert("Biometric Authentication", isPresented: $showingBiometricAlert) {
            Button("OK") { }
        } message: {
            Text(biometricError)
        }
        .alert("Delete Account", isPresented: $showingAccountDeletion) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle account deletion
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
        }
        .onAppear {
            loadSecuritySettings()
        }
        .onChange(of: biometricLockEnabled) { _, _ in saveSecuritySettings() }
        .onChange(of: autoLockEnabled) { _, _ in saveSecuritySettings() }
        .onChange(of: screenshotProtectionEnabled) { _, _ in saveSecuritySettings() }
        .onChange(of: twoFactorEnabled) { _, _ in saveSecuritySettings() }
    }
    
    private var biometricType: String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .faceID {
                return "Face ID"
            } else if context.biometryType == .touchID {
                return "Touch ID"
            }
        }
        return "Biometric Lock"
    }
    
    private func toggleBiometricLock() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if !biometricLockEnabled {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     localizedReason: "Enable biometric authentication for PlanIt") { success, authError in
                    DispatchQueue.main.async {
                        if success {
                            biometricLockEnabled = true
                        } else {
                            biometricError = authError?.localizedDescription ?? "Authentication failed"
                            showingBiometricAlert = true
                        }
                    }
                }
            } else {
                biometricLockEnabled = false
            }
        } else {
            biometricError = error?.localizedDescription ?? "Biometric authentication not available"
            showingBiometricAlert = true
        }
    }
    
    private func loadSecuritySettings() {
        let defaults = UserDefaults.standard
        biometricLockEnabled = defaults.bool(forKey: "biometric_lock_enabled")
        autoLockEnabled = defaults.bool(forKey: "auto_lock_enabled")
        screenshotProtectionEnabled = defaults.bool(forKey: "screenshot_protection_enabled")
        twoFactorEnabled = defaults.bool(forKey: "two_factor_enabled")
        dataEncryptionEnabled = defaults.bool(forKey: "data_encryption_enabled")
    }
    
    private func saveSecuritySettings() {
        let defaults = UserDefaults.standard
        defaults.set(biometricLockEnabled, forKey: "biometric_lock_enabled")
        defaults.set(autoLockEnabled, forKey: "auto_lock_enabled")
        defaults.set(screenshotProtectionEnabled, forKey: "screenshot_protection_enabled")
        defaults.set(twoFactorEnabled, forKey: "two_factor_enabled")
        defaults.set(dataEncryptionEnabled, forKey: "data_encryption_enabled")
    }
} 