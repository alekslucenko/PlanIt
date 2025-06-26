import SwiftUI
import Charts

// MARK: - Matching Animation View (Finding your matches...)
struct MatchingAnimationView: View {
    let categoryName: String
    let onComplete: () -> Void
    @State private var progress: CGFloat = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var foundCount = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private let searchTexts = [
        "Scanning local areas...",
        "Analyzing preferences...",
        "Finding perfect matches...",
        "Curating recommendations...",
        "Almost ready..."
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Category icon with pulse animation
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#43e97b").opacity(0.3))
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)
                    
                    Text(getCategoryEmoji(categoryName))
                        .font(.system(size: 80))
                        .scaleEffect(isSearching ? 1.2 : 1.0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isSearching)
                }
                
                Text("Finding \(categoryName)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Animated progress bar
            VStack(spacing: 16) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 20, height: 8)
                                    .offset(x: (geometry.size.width * progress) - 10)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            )
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
                
                Text(searchText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .animation(.easeInOut(duration: 0.3), value: searchText)
                
                // Found count animation
                HStack(spacing: 8) {
                    Text("\(foundCount)")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: foundCount)
                    
                    Text("places found!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .onAppear {
            startSearchAnimation()
        }
    }
    
    private func startSearchAnimation() {
        isSearching = true
        pulseScale = 1.2
        
        // Animate progress and search text
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if progress < 1.0 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    progress += 0.2
                    foundCount = Int(progress * 15000) // Show increasing count
                }
                
                // Update search text
                let textIndex = min(Int(progress * CGFloat(searchTexts.count)), searchTexts.count - 1)
                searchText = searchTexts[textIndex]
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
    
    private func getCategoryEmoji(_ categoryName: String) -> String {
        switch categoryName.lowercased() {
        case "restaurants": return "🍽️"
        case "venues": return "🎭"
        case "shopping": return "🛍️"
        case "hangout spots": return "☕"
        case "nature": return "🌲"
        case "entertainment": return "🎬"
        case "fitness": return "💪"
        case "culture": return "🎨"
        default: return "📍"
        }
    }
}

// MARK: - Match Results View (MATCHED 50K+ PLACES FOR YOU!)
struct MatchResultsView: View {
    let matchCount: Int
    let totalMatches: Int
    let onContinue: () -> Void
    @State private var isAnimating = false
    @State private var countAnimation = 0
    @State private var showContinueButton = false
    @State private var confettiOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Confetti background
            ConfettiView()
                .opacity(confettiOpacity)
                .animation(.easeInOut(duration: 1.0), value: confettiOpacity)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success celebration
                VStack(spacing: 24) {
                    // Animated checkmark
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#fa709a").opacity(0.3))
                            .frame(width: 150, height: 150)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(isAnimating ? 1.0 : 0.3)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: isAnimating)
                    }
                    
                    // Exciting headline
                    VStack(spacing: 16) {
                        Text("MATCHED")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                        
                        HStack(spacing: 8) {
                            Text("\(countAnimation)")
                                .font(.system(size: 48, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: countAnimation)
                            
                            Text("PLACES")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        
                        Text("FOR YOU!")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .opacity(isAnimating ? 1 : 0)
                    }
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: isAnimating)
                    
                    // Subtitle
                    Text("Based on your unique preferences")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: isAnimating)
                }
                
                Spacer()
                
                // Continue button
                if showContinueButton {
                    Button(action: onContinue) {
                        HStack(spacing: 12) {
                            Text("See What's Next")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color(hex: "#fa709a").opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .padding(.horizontal, 40)
                    .scaleEffect(showContinueButton ? 1.0 : 0.3)
                    .opacity(showContinueButton ? 1 : 0)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            startResultAnimation()
        }
    }
    
    private func startResultAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isAnimating = true
            confettiOpacity = 1.0
        }
        
        // Animate count
        let _ = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if countAnimation < matchCount {
                countAnimation += max(1, matchCount / 20)
                if countAnimation >= matchCount {
                    countAnimation = matchCount
                    timer.invalidate()
                }
            }
        }
        
        // Show continue button after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showContinueButton = true
            }
        }
    }
}

// MARK: - Fun Statistics View (Users having more fun)
struct FunStatisticsView: View {
    let statIndex: Int
    let onContinue: () -> Void
    @State private var isAnimating = false
    @State private var chartProgress: CGFloat = 0
    @State private var showNextButton = false
    
    private let statistics: [FunStatistic] = [
        FunStatistic(
            title: "Users Have 3x More Fun",
            subtitle: "vs. Planning Alone",
            description: "PlanIt users report having significantly more enjoyable experiences compared to traditional planning methods",
            mainValue: "3x",
            color: Color(hex: "#a8edea"),
            chartData: [
                ("Traditional Planning", 32),
                ("With PlanIt", 95)
            ]
        ),
        FunStatistic(
            title: "Save 5+ Hours Weekly",
            subtitle: "on Trip Planning",
            description: "Our AI instantly finds what you're looking for, eliminating endless scrolling and research",
            mainValue: "5hrs",
            color: Color(hex: "#ffecd2"),
            chartData: [
                ("Manual Search", 7.2),
                ("PlanIt AI", 1.8)
            ]
        ),
        FunStatistic(
            title: "97% Success Rate",
            subtitle: "in Finding Perfect Matches",
            description: "Nearly all users find places they absolutely love using our personalized recommendations",
            mainValue: "97%",
            color: Color(hex: "#a8edea"),
            chartData: [
                ("Other Apps", 64),
                ("PlanIt", 97)
            ]
        )
    ]
    
    var currentStat: FunStatistic {
        statistics[min(statIndex, statistics.count - 1)]
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text(currentStat.title)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1 : 0)
                
                Text(currentStat.subtitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(currentStat.color)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1 : 0)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: isAnimating)
            
            // Chart visualization
            VStack(spacing: 20) {
                // Main statistic
                Text(currentStat.mainValue)
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [currentStat.color, currentStat.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                
                // Comparison chart
                VStack(spacing: 16) {
                    ForEach(Array(currentStat.chartData.enumerated()), id: \.offset) { index, data in
                        ComparisonBar(
                            label: data.0,
                            value: data.1,
                            maxValue: currentStat.chartData.map { $0.1 }.max() ?? 100,
                            color: index == 0 ? Color.gray.opacity(0.5) : currentStat.color,
                            progress: chartProgress,
                            animationDelay: Double(index) * 0.2
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
            
            // Description
            Text(currentStat.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            
            Spacer()
            
            // Continue button
            if showNextButton {
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        Text("This is Amazing!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [currentStat.color, currentStat.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: currentStat.color.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 40)
                .scaleEffect(showNextButton ? 1.0 : 0.3)
                .opacity(showNextButton ? 1 : 0)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer().frame(height: 50)
        }
        .onAppear {
            startStatAnimation()
        }
    }
    
    private func startStatAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isAnimating = true
        }
        
        // Animate chart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 1.5)) {
                chartProgress = 1.0
            }
        }
        
        // Show continue button
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showNextButton = true
            }
        }
    }
}

struct FunStatistic {
    let title: String
    let subtitle: String
    let description: String
    let mainValue: String
    let color: Color
    let chartData: [(String, Double)]
}

struct ComparisonBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color
    let progress: CGFloat
    let animationDelay: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.0f%", value))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * (value / maxValue) * progress,
                            height: 12
                        )
                        .animation(.easeInOut(duration: 1.0).delay(animationDelay), value: progress)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Trust Builder View (Features and benefits)
struct TrustBuilderView: View {
    let featureIndex: Int
    let onContinue: () -> Void
    @State private var isAnimating = false
    @State private var showNextButton = false
    
    private let features: [TrustFeature] = [
        TrustFeature(
            icon: "🔒",
            title: "Your Privacy Matters",
            subtitle: "100% Secure & Private",
            description: "Your personal data is encrypted and never shared. We believe in transparency and putting you in control.",
            benefits: ["End-to-end encryption", "No data selling", "GDPR compliant", "You own your data"],
            color: Color(hex: "#667eea")
        ),
        TrustFeature(
            icon: "⚡",
            title: "Lightning Fast Results",
            subtitle: "Instant Recommendations",
            description: "Get personalized suggestions in under 2 seconds using our advanced AI algorithms.",
            benefits: ["Sub-2 second response", "Real-time updates", "Offline capability", "Smart caching"],
            color: Color(hex: "#f093fb")
        ),
        TrustFeature(
            icon: "🎯",
            title: "Precision Matching",
            subtitle: "Tailored Just for You",
            description: "Our AI learns your preferences to provide increasingly accurate recommendations over time.",
            benefits: ["Machine learning", "Preference evolution", "Context awareness", "Continuous improvement"],
            color: Color(hex: "#4facfe")
        )
    ]
    
    var currentFeature: TrustFeature {
        features[min(featureIndex, features.count - 1)]
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Feature icon and title
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(currentFeature.color.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text(currentFeature.icon)
                        .font(.system(size: 60))
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: isAnimating)
                }
                
                VStack(spacing: 12) {
                    Text(currentFeature.title)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                    
                    Text(currentFeature.subtitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(currentFeature.color)
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: isAnimating)
            }
            
            // Description
            Text(currentFeature.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: isAnimating)
            
            // Benefits list
            VStack(spacing: 12) {
                ForEach(Array(currentFeature.benefits.enumerated()), id: \.offset) { index, benefit in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(currentFeature.color)
                        
                        Text(benefit)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .scaleEffect(isAnimating ? 1.0 : 0.3)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8 + Double(index) * 0.1), value: isAnimating)
                }
            }
            
            Spacer()
            
            // Continue button
            if showNextButton {
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        Text("I Trust This!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [currentFeature.color, currentFeature.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: currentFeature.color.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 40)
                .scaleEffect(showNextButton ? 1.0 : 0.3)
                .opacity(showNextButton ? 1 : 0)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer().frame(height: 50)
        }
        .onAppear {
            startTrustAnimation()
        }
    }
    
    private func startTrustAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isAnimating = true
        }
        
        // Show continue button
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showNextButton = true
            }
        }
    }
}

struct TrustFeature {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let benefits: [String]
    let color: Color
}

// MARK: - Paywall Lead View (Psychology-driven preparation)
struct PaywallLeadView: View {
    let totalMatches: Int
    let selectedCategories: [OnboardingCategory]
    let onComplete: () -> Void
    @State private var isAnimating = false
    @State private var showValue = false
    @State private var valueScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Success summary
            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 80))
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: isAnimating)
                
                VStack(spacing: 16) {
                    Text("Your Profile is Ready!")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                    
                    Text("We've found \(totalMatches)+ perfect places")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: isAnimating)
            }
            
            // Value proposition
            if showValue {
                VStack(spacing: 20) {
                    Text("Worth Over $200")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                        .scaleEffect(valueScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(3), value: valueScale)
                    
                    Text("Professional travel consultation would cost $200+. You're getting personalized AI recommendations worth even more!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Categories summary
            VStack(spacing: 16) {
                Text("Your Interest Categories:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: isAnimating)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Array(selectedCategories.enumerated()), id: \.element) { index, category in
                        HStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: category.color))
                            
                            Text(category.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: category.color).opacity(0.2))
                        )
                        .scaleEffect(isAnimating ? 1.0 : 0.3)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8 + Double(index) * 0.1), value: isAnimating)
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Final CTA
            Button(action: onComplete) {
                HStack(spacing: 12) {
                    Text("Unlock My Matches")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .padding(.horizontal, 30)
            .scaleEffect(isAnimating ? 1.0 : 0.3)
            .opacity(isAnimating ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.2), value: isAnimating)
            
            Spacer().frame(height: 50)
        }
        .onAppear {
            startFinalAnimation()
        }
    }
    
    private func startFinalAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            isAnimating = true
        }
        
        // Show value proposition
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showValue = true
            }
            
            // Value scale animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                valueScale = 1.2
            }
        }
    }
}

// MARK: - Confetti Animation
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces.indices, id: \.self) { index in
                if index < confettiPieces.count {
                    ConfettiPieceView(piece: confettiPieces[index])
                }
            }
        }
        .onAppear {
            generateConfetti()
        }
    }
    
    private func generateConfetti() {
        confettiPieces = (0..<50).map { _ in
            ConfettiPiece(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -50
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -3...3),
                    y: CGFloat.random(in: 2...6)
                ),
                color: [Color.pink, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple].randomElement() ?? .pink,
                rotation: Double.random(in: 0...360)
            )
        }
    }
}

struct ConfettiPiece {
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var rotation: Double
}

struct ConfettiPieceView: View {
    @State var piece: ConfettiPiece
    
    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(piece.rotation))
            .position(piece.position)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    piece.position.y += UIScreen.main.bounds.height + 100
                    piece.position.x += piece.velocity.x * 100
                    piece.rotation += 720
                }
            }
    }
}

#Preview {
    MatchingAnimationView(categoryName: "Restaurants", onComplete: {})
} 