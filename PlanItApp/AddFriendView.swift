import SwiftUI
import FirebaseFirestore

struct AddFriendView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthenticationService
    @ObservedObject var friendsManager: FriendsManager
    
    @State private var usernameInput = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var foundUser: AppUser?
    @State private var hasSearched = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text("add_friend".localized)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Username input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter username (e.g., john#1234)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("username#1234", text: $usernameInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    
                    // Send request button
                    Button(action: sendFriendRequest) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                            }
                            
                            Text(isLoading ? "sending".localized : "send_friend_request".localized)
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        )
                    }
                    .disabled(usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
                
                // Instructions section
                VStack(spacing: 20) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        Text("how_to_find_friends".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(icon: "person.crop.circle", text: "ask_for_username".localized)
                            InstructionRow(icon: "doc.on.doc", text: "copy_from_profile".localized)
                            InstructionRow(icon: "paperplane", text: "enter_to_send_request".localized)
                            InstructionRow(icon: "textformat.abc", text: "usernames_format".localized)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("cancel".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("add_friend".localized, isPresented: $showAlert) {
                Button("ok".localized) {
                    if alertMessage.contains("sent successfully") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Force view refresh when language changes
        }
    }
    
    private func sendFriendRequest() {
        let trimmedInput = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else { return }
        
        isLoading = true
        
        friendsManager.searchUser(by: trimmedInput) { user, message in
            DispatchQueue.main.async {
                isLoading = false
                
                if let user = user {
                    // User found, send friend request
                    friendsManager.sendFriendRequest(to: user) { success, requestMessage in
                        DispatchQueue.main.async {
                            alertMessage = requestMessage
                            showAlert = true
                        }
                    }
                } else {
                    // User not found
                    alertMessage = message
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct UserSearchResultCard: View {
    let user: AppUser
    let onSendRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image Placeholder
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(getInitials(user.displayName))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(user.fullUsername)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Found user")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: onSendRequest) {
                Text("Send Request")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getInitials(_ name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(name.prefix(2))
        }
    }
}

struct EmptySearchResultView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("User Not Found")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Double-check the username#1234 format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    AddFriendView(friendsManager: FriendsManager())
        .environmentObject(AuthenticationService())
} 