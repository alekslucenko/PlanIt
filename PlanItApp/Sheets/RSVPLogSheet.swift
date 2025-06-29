import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - RSVP Log Sheet
struct RSVPLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let firestoreService: FirestoreService
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.orange.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 40) // Push header down for visibility
                    
                    if firestoreService.attendeeDetails.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Done") {
                    dismiss()
                }
                .font(.inter(16, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Total Attendees")
                        .font(.inter(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("confirmed RSVPs")
                        .font(.inter(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Current Value Display
            VStack(spacing: 8) {
                Text("\(firestoreService.totalAttendees)")
                    .font(.inter(36, weight: .bold))
                    .foregroundColor(.orange)
                
                let attendanceRate = firestoreService.activeEvents > 0 ? 
                    Double(firestoreService.totalAttendees) / Double(firestoreService.activeEvents) : 0
                Text("\(String(format: "%.1f", attendanceRate)) avg per event")
                    .font(.inter(14, weight: .medium))
                    .foregroundColor(.orange.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No RSVPs Yet")
                .font(.inter(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("RSVP data will appear here when users confirm their attendance to your events.")
                .font(.inter(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Confirmed RSVPs")
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(firestoreService.attendeeDetails.count) items")
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(firestoreService.attendeeDetails) { attendee in
                        AttendeeRow(attendee: attendee)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Attendee Row
struct AttendeeRow: View {
    let attendee: AttendeeDetail
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Attendee Avatar
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(attendee.guestName.prefix(1).uppercased())
                    .font(.inter(16, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            // Attendee Info
            VStack(alignment: .leading, spacing: 2) {
                Text(attendee.guestName)
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(attendee.guestEmail)
                    .font(.inter(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(attendee.eventName)
                    .font(.inter(11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // RSVP Status and Time
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("CONFIRMED")
                        .font(.inter(10, weight: .bold))
                        .foregroundColor(.green)
                        .textCase(.uppercase)
                }
                
                Text(formatRelativeDate(attendee.rsvpTime))
                    .font(.inter(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    RSVPLogSheet(firestoreService: FirestoreService())
} 