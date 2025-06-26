import SwiftUI
import FirebaseFirestore

// MARK: - Modern In-App Notification View
struct InAppNotificationView: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Notification icon with enhanced styling
            notificationIcon
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                )
            
            // Notification content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Dismiss button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text(notification.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Enhanced action hint
                if notification.type == "new_message" {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue.opacity(0.8))
                        
                        Text("Tap to open chat")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: dragOffset)
        .onTapGesture {
            // Enhanced tap feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.15)) {
                scale = 0.95
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    scale = 1.0
                }
                onTap()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation.height
                    dragOffset = translation < 0 ? translation : 0
                    opacity = max(0.3, 1.0 - abs(translation) / 100.0)
                }
                .onEnded { value in
                    if value.translation.height < -80 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = -100
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            dragOffset = 0
                            opacity = 1.0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Auto-dismiss based on notification type
            let dismissTime: TimeInterval = notification.type == "new_message" ? 8.0 : 5.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                    dragOffset = -50
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private var notificationIcon: some View {
        switch notification.type {
        case "new_message":
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "message.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
        case "friend_request":
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
        case "friend_request_accepted":
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
        case "ping":
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
        default:
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// Enhanced Preview
struct InAppNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            InAppNotificationView(
                notification: AppNotification(
                    userId: "test",
                    type: "new_message",
                    title: "New Message",
                    message: "Hey, what's up? Are you free tonight for dinner?",
                    timestamp: Timestamp(),
                    senderId: "sender123",
                    senderName: "John Doe",
                    data: ["fromUser": "John"]
                ),
                onTap: { print("Message notification tapped") },
                onDismiss: { print("Message notification dismissed") }
            )
            
            InAppNotificationView(
                notification: AppNotification(
                    userId: "test",
                    type: "friend_request",
                    title: "Friend Request",
                    message: "Sarah wants to be your friend",
                    timestamp: Timestamp(),
                    senderId: "sender456",
                    senderName: "Sarah",
                    data: ["fromUser": "Sarah"]
                ),
                onTap: { print("Friend request tapped") },
                onDismiss: { print("Friend request dismissed") }
            )
            
            InAppNotificationView(
                notification: AppNotification(
                    userId: "test",
                    type: "ping",
                    title: "Ping!",
                    message: "Alex pinged you!",
                    timestamp: Timestamp(),
                    senderId: "sender789",
                    senderName: "Alex",
                    data: ["fromUser": "Alex"]
                ),
                onTap: { print("Ping notification tapped") },
                onDismiss: { print("Ping notification dismissed") }
            )
        }
        .padding()
        .background(Color.black)
    }
} 