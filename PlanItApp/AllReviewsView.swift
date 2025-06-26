import SwiftUI

struct AllReviewsView: View {
    let place: Place
    @ObservedObject var reviewAggregator: ReviewAggregatorService
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSource: ReviewSource?
    
    var filteredReviews: [EnhancedReview] {
        if let selectedSource = selectedSource {
            return reviewAggregator.reviews.filter { $0.source == selectedSource }
        }
        return reviewAggregator.reviews
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Overall Sentiment Summary
                if let sentiment = reviewAggregator.overallSentiment {
                    overallSentimentView(sentiment)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                }
                
                // Source Filter
                sourceFilterView
                
                // Reviews List
                reviewsList
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func overallSentimentView(_ sentiment: SentimentScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Customer Sentiment")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(sentiment.emoji)
                    .font(.title)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.1f", sentiment.overall))/10")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Based on \(reviewAggregator.reviews.count) reviews")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(sentiment.explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            // Detailed Sentiment Categories
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                SentimentCategoryView(title: "Service", score: sentiment.categories.service, color: .blue)
                
                if let foodScore = sentiment.categories.food {
                    SentimentCategoryView(title: "Food", score: foodScore, color: .orange)
                }
                
                SentimentCategoryView(title: "Atmosphere", score: sentiment.categories.atmosphere, color: .green)
                SentimentCategoryView(title: "Value", score: sentiment.categories.value, color: .purple)
                SentimentCategoryView(title: "Cleanliness", score: sentiment.categories.cleanliness, color: .teal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var sourceFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Sources
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedSource = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        
                        Text("All Sources")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("(\(reviewAggregator.reviews.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedSource == nil ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(selectedSource == nil ? .white : .primary)
                }
                
                // Individual Sources
                ForEach(ReviewSource.allCases, id: \.self) { source in
                    let count = reviewAggregator.reviews.filter { $0.source == source }.count
                    
                    if count > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedSource = selectedSource == source ? nil : source
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: source.icon)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: source.color))
                                
                                Text(source.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("(\(count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedSource == source ? Color(hex: source.color) : Color(.systemGray5))
                            )
                            .foregroundColor(selectedSource == source ? .white : .primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
    }
    
    private var reviewsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredReviews) { review in
                    EnhancedReviewCard(review: review, place: place)
                        .onAppear {
                            // Load more reviews when reaching near the end
                            if review.id == filteredReviews.last?.id {
                                Task {
                                    await reviewAggregator.loadReviews(for: place, initialLoad: false)
                                }
                            }
                        }
                }
                
                // Loading indicator
                if reviewAggregator.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading more reviews...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // No more reviews indicator
                if !reviewAggregator.hasMoreReviews && !reviewAggregator.isLoading && !filteredReviews.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("You've reached the end!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("All available reviews from multiple sources have been loaded.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                
                if filteredReviews.isEmpty && !reviewAggregator.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("No reviews found")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if selectedSource != nil {
                            Text("Try selecting a different source or view all reviews.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    AllReviewsView(
        place: Place(
            id: UUID(),
            name: "Sample Restaurant",
            description: "A great place to eat",
            category: .restaurants,
            rating: 4.5,
            reviewCount: 123,
            priceRange: "$$",
            images: [],
            location: "123 Main St",
            hours: "Mon-Fri: 9AM-10PM",
            detailedHours: DetailedHours(
                monday: "9:00 AM - 10:00 PM",
                tuesday: "9:00 AM - 10:00 PM",
                wednesday: "9:00 AM - 10:00 PM",
                thursday: "9:00 AM - 10:00 PM",
                friday: "9:00 AM - 11:00 PM",
                saturday: "8:00 AM - 11:00 PM",
                sunday: "8:00 AM - 9:00 PM"
            ),
            phone: "(555) 123-4567",
            website: nil as String?,
            menuItems: [],
            reviews: [],
            googlePlaceId: "sample_id",
            sentiment: nil as CustomerSentiment?,
            isCurrentlyOpen: true,
            hasActualMenu: false,
            coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060)
        ),
        reviewAggregator: ReviewAggregatorService()
    )
}

// MARK: - SentimentCategoryView Component
struct SentimentCategoryView: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(String(format: "%.1f", score))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(scoreColor)
            
            // Score indicator bar
            RoundedRectangle(cornerRadius: 4)
                .fill(scoreColor.opacity(0.2))
                .frame(height: 4)
                .overlay(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor)
                            .frame(width: geometry.size.width * (score / 5.0))
                    }
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(scoreColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var scoreColor: Color {
        if score >= 4.0 {
            return .green
        } else if score >= 3.0 {
            return color
        } else {
            return .red
        }
    }
}

// MARK: - EnhancedReviewCard Component
struct EnhancedReviewCard: View {
    let review: EnhancedReview
    let place: Place
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Review header
            HStack(spacing: 12) {
                // Reviewer avatar or initial
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(review.author.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.author)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        // Star rating
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(review.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Review source badge
                        HStack(spacing: 4) {
                            Image(systemName: review.source.icon)
                                .font(.caption2)
                            
                            Text(review.source.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: review.source.color).opacity(0.1))
                        )
                        .foregroundColor(Color(hex: review.source.color))
                    }
                }
            }
            
            // Review text
            VStack(alignment: .leading, spacing: 8) {
                Text(review.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 4)
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
                
                if review.text.count > 200 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Review metrics if available
            if let helpfulCount = review.helpfulCount, helpfulCount > 0 {
                HStack {
                    Image(systemName: "hand.thumbsup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(helpfulCount) people found this helpful")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
} 