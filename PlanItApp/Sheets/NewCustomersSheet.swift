import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - New Customers Sheet View
struct NewCustomersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newCustomers: [AppUser] = []
    @State private var isLoading = true
    @State private var timeframe: TimeFrame = .thisWeek
    
    private let db = Firestore.firestore()
    
    enum TimeFrame: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case allTime = "All Time"
        
        var days: Int {
            switch self {
            case .thisWeek: return 7
            case .thisMonth: return 30
            case .lastMonth: return 60
            case .allTime: return 365
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.purple.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    if isLoading {
                        loadingSection
                    } else if newCustomers.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
        .onAppear {
            loadNewCustomerData()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Close") {
                    dismiss()
                }
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("New Customers")
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("First-time buyers")
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Time Filter
            HStack(spacing: 0) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            timeframe = frame
                            loadNewCustomerData()
                        }
                    }) {
                        Text(frame.rawValue)
                            .font(.geist(12, weight: .medium))
                            .foregroundColor(timeframe == frame ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(timeframe == frame ? .white : Color.clear)
                            )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Summary Stats
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Customers")
                        .font(.geist(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(newCustomers.count)")
                        .font(.geist(28, weight: .bold))
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Loading customer data...")
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No New Customers")
                .font(.geist(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("New customers will appear here when they make their first purchase.")
                .font(.geist(14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(newCustomers.sorted { 
                    $0.createdAt > $1.createdAt
                }) { customer in
                    CustomerItemView(customer: customer)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .padding(.top, 20)
    }
    
    private func loadNewCustomerData() {
        guard Auth.auth().currentUser?.uid != nil else {
            isLoading = false
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -timeframe.days, to: endDate) ?? endDate
        
        db.collection("users")
            .whereField("createdAt", isGreaterThan: startDate)
            .whereField("createdAt", isLessThan: endDate)
            .addSnapshotListener { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading new customer data: \(error)")
                        self.isLoading = false
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.isLoading = false
                        return
                    }
                    
                    self.newCustomers = documents.compactMap { doc in
                        try? doc.data(as: AppUser.self)
                    }
                    
                    self.isLoading = false
                }
            }
    }
}

// MARK: - Customer Item View
struct CustomerItemView: View {
    let customer: AppUser
    
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
        HStack(spacing: 16) {
            // Customer Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                if let photoURL = customer.photoURL, !photoURL.isEmpty {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.purple)
                }
            }
            
            // Customer Details
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.displayName)
                    .font(.geist(16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(customer.email)
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text("Joined \(formatRelativeDate(customer.createdAt))")
                    .font(.geist(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // New Customer Badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow)
                    
                    Text("NEW")
                        .font(.geist(10, weight: .bold))
                        .foregroundColor(.yellow)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.2))
                )
                
                Text("Level \(customer.userXP.level)")
                    .font(.geist(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
} 