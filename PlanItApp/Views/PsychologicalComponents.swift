import SwiftUI
import CoreLocation

// MARK: - Psychological Category Grid
struct PsychologicalCategoryGrid: View {
    let categories: [DynamicCategory]
    @Binding var selectedCategory: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Curated for You")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("✨ AI-personalized")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(categories) { category in
                        PsychologicalCategoryCard(
                            category: category,
                            isSelected: selectedCategory == category.title
                        ) {
                            selectedCategory = category.title
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Psychological Category Card
struct PsychologicalCategoryCard: View {
    let category: DynamicCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    @StateObject private var hapticManager = HapticManager.shared
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with psychological design
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isSelected ? 
                            [Color.blue.opacity(0.8), Color.purple.opacity(0.6)] :
                            [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Text(category.personalizedEmoji.isEmpty ? getCategoryEmoji(for: category.category) : category.personalizedEmoji)
                    .font(.system(size: 24))
            }
            
            VStack(spacing: 4) {
                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(category.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let socialProof = category.socialProofText {
                    Text(socialProof)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                if let psychologyHook = category.psychologyHook {
                    Text(psychologyHook)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.purple)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 110)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            hapticManager.lightImpact()
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func getCategoryEmoji(for type: PlaceCategory) -> String {
        switch type {
        case .restaurants: return "🍽️"
        case .cafes: return "☕"
        case .bars: return "🍸"
        case .venues: return "🎭"
        case .shopping: return "🛍️"
        }
    }
}

// MARK: - Psychological Recommendations View
struct PsychologicalRecommendationsView: View {
    let recommendations: [IntelligentRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Perfect for You")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("🧠 Psychology-matched")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recommendations) { recommendation in
                        PsychologicalRecommendationCard(recommendation: recommendation)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Psychological Recommendation Card
struct PsychologicalRecommendationCard: View {
    let recommendation: IntelligentRecommendation
    @StateObject private var hapticManager = HapticManager.shared
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            reasoningSection
            nudgesSection
            realTimeSection
            confidenceSection
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        .onTapGesture {
            hapticManager.mediumImpact()
            print("🎯 Tapped recommendation: \(recommendation.aiRecommendation.name)")
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.aiRecommendation.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(recommendation.aiRecommendation.category.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            psychologyScoreIndicator
        }
    }
    
    // MARK: - Psychology Score Indicator
    private var psychologyScoreIndicator: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: recommendation.psychologyScore / 10.0)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.1f", recommendation.psychologyScore))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text("match")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Reasoning Section
    private var reasoningSection: some View {
        Text(recommendation.personalizedReasoning)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(3)
    }
    
    // MARK: - Nudges Section
    @ViewBuilder
    private var nudgesSection: some View {
        if !recommendation.behavioralNudges.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(recommendation.behavioralNudges.prefix(2)), id: \.self) { nudge in
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(nudge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    // MARK: - Real-time Section
    private var realTimeSection: some View {
        HStack(spacing: 8) {
            if let waitTime = recommendation.realTimeFactors.waitTime, !waitTime.isEmpty && waitTime != "Unknown" {
                Label(waitTime, systemImage: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            if !recommendation.realTimeFactors.crowdLevel.isEmpty && recommendation.realTimeFactors.crowdLevel != "Unknown" {
                Label(recommendation.realTimeFactors.crowdLevel, systemImage: "person.2")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
            }
        }
    }
    
    // MARK: - Confidence Section
    private var confidenceSection: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.indigo)
                
                Text("IQ: \(String(format: "%.1f", recommendation.finalIntelligenceScore))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.indigo)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.green)
                
                Text("\(Int(recommendation.confidenceScore * 100))%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Card Background
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Supporting Types and Extensions

// ThemeManager and Color extensions moved to ThemeManager.swift to avoid duplicates 