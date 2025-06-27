import SwiftUI
import MapKit

/// 🎉 MODERN PARTY CARD
/// Beautiful, interactive card for displaying party information with RSVP functionality
/// Designed for the user parties view with modern UI and smooth animations
struct ModernPartyCard: View {
    let party: Party
    let isRSVPed: Bool
    let onTap: () -> Void
    let onQuickRSVP: () -> Void
    let onFullRSVP: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false
    
    var timeUntilParty: String {
        let now = Date()
        let timeInterval = party.startDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Started"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
    
    var priceRange: String {
        if party.ticketTiers.isEmpty {
            return "Free"
        }
        
        let prices = party.ticketTiers.map { $0.price }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 0
        
        if minPrice == 0 && maxPrice == 0 {
            return "Free"
        } else if minPrice == maxPrice {
            return "$\(Int(minPrice))"
        } else {
            return "$\(Int(minPrice))-\(Int(maxPrice))"
        }
    }
    
    var attendanceInfo: String {
        let current = party.currentAttendees
        let capacity = party.guestCap
        
        if current >= capacity {
            return "Full (\(capacity))"
        } else {
            let percentage = Int((Double(current) / Double(capacity)) * 100)
            return "\(current)/\(capacity) • \(percentage)%"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header with status indicators
                VStack(spacing: 8) {
                    HStack {
                        // Time until party
                        Text(timeUntilParty)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(timeUntilParty == "Started" ? Color.green : themeManager.travelPink)
                            )
                        
                        Spacer()
                        
                        // RSVP status
                        if isRSVPed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        // Price indicator
                        Text(priceRange)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(priceRange == "Free" ? .green : themeManager.travelBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.9))
                            )
                    }
                    
                    // Party title
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .themedText(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Host and location
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(themeManager.travelPurple)
                                .font(.caption)
                            
                            Text(party.hostName)
                                .font(.caption)
                                .themedText(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(themeManager.travelPink)
                                .font(.caption)
                            
                            Text(party.location.name)
                                .font(.caption)
                                .themedText(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                
                // Attendance and RSVP section
                VStack(spacing: 12) {
                    // Attendance bar
                    VStack(spacing: 4) {
                        HStack {
                            Text("Attendance")
                                .font(.caption2)
                                .themedText(.secondary)
                            
                            Spacer()
                            
                            Text(attendanceInfo)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .themedText(.primary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(themeManager.cardBackground)
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [themeManager.travelPink, themeManager.travelPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width * (Double(party.currentAttendees) / Double(party.guestCap)),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if isRSVPed {
                            Button("View Details") {
                                onTap()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.travelBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.travelBlue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        } else {
                            Button("Quick RSVP") {
                                onQuickRSVP()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [themeManager.travelPink, themeManager.travelPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            
                            Button("Details") {
                                onFullRSVP()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.travelBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.travelBlue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.travelBlue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(themeManager.cardBackground.opacity(0.5))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.travelPink.opacity(0.3),
                                    themeManager.travelPurple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isPressed ? 2 : 1
                        )
                )
                .shadow(
                    color: themeManager.travelPink.opacity(0.2),
                    radius: isPressed ? 8 : 4,
                    x: 0,
                    y: isPressed ? 4 : 2
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
} 