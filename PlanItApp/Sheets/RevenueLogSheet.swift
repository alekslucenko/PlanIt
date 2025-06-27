import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Revenue Log Sheet View
struct RevenueLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ticketSales: [TicketSale] = []
    @State private var isLoading = true
    @State private var totalRevenue: Double = 0
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.gray.opacity(0.9)
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
                    } else if ticketSales.isEmpty {
                        emptyStateSection
                    } else {
                        contentSection
                    }
                }
            }
        }
        .onAppear {
            loadRevenueData()
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
                    Text("Revenue History")
                        .font(.geist(20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("All payments and transactions")
                        .font(.geist(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Share button placeholder
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Total Revenue Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Revenue")
                        .font(.geist(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("$\(formatCurrency(totalRevenue))")
                        .font(.geist(28, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
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
            
            Text("Loading revenue data...")
                .font(.geist(16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Revenue Yet")
                .font(.geist(24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Revenue data will appear here when customers purchase tickets to your events.")
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
                ForEach(ticketSales.sorted { $0.timestamp > $1.timestamp }) { sale in
                    RevenueItemView(sale: sale)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .padding(.top, 20)
    }
    
    private func loadRevenueData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        db.collection("ticketSales")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading revenue data: \(error)")
                        self.isLoading = false
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.isLoading = false
                        return
                    }
                    
                    self.ticketSales = documents.compactMap { doc in
                        try? doc.data(as: TicketSale.self)
                    }
                    
                    self.totalRevenue = self.ticketSales.reduce(0) { $0 + $1.amount }
                    self.isLoading = false
                }
            }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

// MARK: - Revenue Item Component
struct RevenueItemView: View {
    let sale: TicketSale
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Payment Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.green)
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(sale.customerName)
                    .font(.geist(16, weight: .semibold))
                    .foregroundColor(.white)
                
                                    Text("\(sale.ticketCount) × \(sale.partyName)")
                    .font(.geist(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(formatDate(sale.timestamp))
                    .font(.geist(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("+$\(formatAmount(sale.amount))")
                    .font(.geist(18, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Ticket Sale")
                    .font(.geist(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
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
    
    private func formatAmount(_ amount: Double) -> String {
        return String(format: "%.2f", amount)
    }
} 