import SwiftUI

// MARK: - Premium Question View
struct PremiumQuestionView: View {
    let category: OnboardingCategory
    let question: OnboardingQuestion
    let onAnswer: (OnboardingResponse) -> Void
    
    @State private var selectedOptions: Set<String> = []
    @State private var sliderValue: Double = 0
    @State private var ratingValue: Int = 0
    @State private var textValue: String = ""
    @State private var isAnimating = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Question header
            VStack(spacing: 16) {
                Text(category.emoji)
                    .font(.system(size: 44))
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
                
                VStack(spacing: 8) {
                    Text(question.text)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
            }
            
            // Answer input based on question type
            answerInputView
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimating)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        // Single shared keyboard toolbar for the entire view
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
                .foregroundColor(.primary)
                .fontWeight(.medium)
            }
        }
        .onAppear {
            setupInitialValues()
            withAnimation {
                isAnimating = true
            }
        }
    }
    
    private var categoryBadge: some View {
        HStack {
            Image(systemName: category.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text(category.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .scaleEffect(isAnimating ? 1 : 0.5)
        .opacity(isAnimating ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: isAnimating)
    }
    
    @ViewBuilder
    private var answerInputView: some View {
        switch question.type {
        case .singleChoice:
            singleChoiceView
        case .multipleChoice:
            multipleChoiceView
        case .slider:
            sliderView
        case .rating:
            ratingView
        case .textInput:
            textInputView
        }
    }
    
    private var singleChoiceView: some View {
        VStack(spacing: 12) {
            ForEach(Array((question.options ?? []).enumerated()), id: \.element) { index, option in
                ChoiceButton(
                    option: option,
                    isSelected: selectedOptions.contains(option),
                    index: index,
                    isAnimating: isAnimating,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.removeAll()
                                selectedOptions.insert(option)
                            }
                        }
                        submitAnswer()
                    }
                )
            }
        }
    }
    
    private var multipleChoiceView: some View {
        VStack(spacing: 12) {
            ForEach(Array((question.options ?? []).enumerated()), id: \.element) { index, option in
                MultipleChoiceButton(
                    option: option,
                    isSelected: selectedOptions.contains(option),
                    index: index,
                    isAnimating: isAnimating,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        }
                        submitAnswer()
                    }
                )
            }
            
            if !selectedOptions.isEmpty {
                Text("Selected: \(selectedOptions.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    // MARK: - FIXED SLIDER VIEW - Eliminates number scroller bug
    private var sliderView: some View {
        VStack(spacing: 30) {
            // Current value display with proper formatting
            VStack(spacing: 16) {
                Text("Current Selection")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                if let range = question.sliderRange {
                    Text(formattedSliderValue(sliderValue, range: range))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: sliderValue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: isAnimating)
            
            // Slider with proper range validation
            if let range = question.sliderRange {
                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { 
                                // Ensure value is within valid range
                                max(range.min, min(range.max, sliderValue))
                            },
                            set: { newValue in
                                // Clamp value to range and apply step
                                let step = getSliderStep(for: range)
                                let steppedValue = round(newValue / step) * step
                                sliderValue = max(range.min, min(range.max, steppedValue))
                            }
                        ),
                        in: range.min...range.max,
                        step: getSliderStep(for: range)
                    ) { editing in
                        if !editing {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            submitAnswer()
                        }
                    }
                    .accentColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: sliderValue)
                    
                    // Labels with proper formatting
                    if let labels = question.sliderLabels {
                        HStack {
                            Text(labels.min)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(labels.max)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: isAnimating)
            }
        }
    }
    
    private var ratingView: some View {
        VStack(spacing: 30) {
            Text("Tap to rate")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: isAnimating)
            
            HStack(spacing: 12) {
                ForEach(1...(question.ratingMax ?? 5), id: \.self) { star in
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            ratingValue = star
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        submitAnswer()
                    }) {
                        Image(systemName: star <= ratingValue ? "star.fill" : "star")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(
                                star <= ratingValue ? 
                                .white : 
                                .white.opacity(0.3)
                            )
                            .scaleEffect(star <= ratingValue ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: ratingValue)
                    }
                    .scaleEffect(isAnimating ? 1 : 0.3)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.8)
                        .delay(0.4 + Double(star) * 0.1),
                        value: isAnimating
                    )
                }
            }
            
            if ratingValue > 0 {
                Text("Rating: \(ratingValue) out of \(question.ratingMax ?? 5)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    private var textInputView: some View {
        VStack(spacing: 20) {
            TextField("Your answer...", text: $textValue, axis: .vertical)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .focused($isTextFieldFocused)
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .frame(minHeight: 120)
                .onChange(of: textValue) { _, newValue in
                    submitAnswer()
                }
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: isAnimating)
            
            Text("\(textValue.count) characters")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .opacity(textValue.isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: textValue.isEmpty)
        }
    }
    
    // MARK: - Helper Functions
    private func setupInitialValues() {
        // FIXED: Always reset ALL values first to prevent glitches
        sliderValue = 0
        ratingValue = 0
        selectedOptions.removeAll()
        textValue = ""
        
        // Then set appropriate initial values
        if let range = question.sliderRange {
            // Set initial value to minimum of range for consistent behavior
            sliderValue = range.min
        }
    }
    
    private func getSliderStep(for range: (min: Double, max: Double)) -> Double {
        // Dynamic step size based on range
        if range.min >= 10 { // Dollar values
            return 5
        } else if range.max > 10 { // Time values
            return 1
        } else { // Rating scale
            return 0.5
        }
    }
    
    private func formattedSliderValue(_ value: Double, range: (min: Double, max: Double)) -> String {
        if range.min >= 10 { // Dollar values
            return "$\(Int(value))"
        } else if range.max > 10 { // Time values
            if value >= 60 {
                let hours = Int(value / 60)
                let minutes = Int(value.truncatingRemainder(dividingBy: 60))
                return "\(hours)h \(minutes)m"
            } else {
                return "\(Int(value)) min"
            }
        } else { // Rating scale
            return String(format: "%.1f/%.0f", value, range.max)
        }
    }
    
    private func submitAnswer() {
        var response: OnboardingResponse
        
        switch question.type {
        case .singleChoice, .multipleChoice:
            response = OnboardingResponse(
                questionId: question.id,
                categoryId: category.rawValue,
                selectedOptions: Array(selectedOptions)
            )
        case .slider:
            response = OnboardingResponse(
                questionId: question.id,
                categoryId: category.rawValue,
                sliderValue: sliderValue
            )
        case .rating:
            response = OnboardingResponse(
                questionId: question.id,
                categoryId: category.rawValue,
                ratingValue: ratingValue
            )
        case .textInput:
            response = OnboardingResponse(
                questionId: question.id,
                categoryId: category.rawValue,
                textValue: textValue
            )
        }
        
        onAnswer(response)
    }
}

// MARK: - Helper Views with Fixed Corners
struct ChoiceButton: View {
    let option: String
    let isSelected: Bool
    let index: Int
    let isAnimating: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
        }
        .cornerRadius(16)
        .scaleEffect(isAnimating ? 1 : 0.8)
        .opacity(isAnimating ? 1 : 0)
        .animation(
            .spring(response: 0.8, dampingFraction: 0.8)
            .delay(0.3 + Double(index) * 0.1),
            value: isAnimating
        )
    }
}

struct MultipleChoiceButton: View {
    let option: String
    let isSelected: Bool
    let index: Int
    let isAnimating: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
        }
        .cornerRadius(16)
        .scaleEffect(isAnimating ? 1 : 0.8)
        .opacity(isAnimating ? 1 : 0)
        .animation(
            .spring(response: 0.8, dampingFraction: 0.8)
            .delay(0.3 + Double(index) * 0.1),
            value: isAnimating
        )
    }
}

// MARK: - Legacy QuestionView for compatibility
struct QuestionView: View {
    let category: OnboardingCategory
    let question: OnboardingQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let progress: CGFloat
    let onAnswer: (OnboardingResponse) -> Void
    
    var body: some View {
        PremiumQuestionView(
            category: category,
            question: question,
            onAnswer: onAnswer
        )
    }
}

#Preview {
    PremiumQuestionView(
        category: .restaurants,
        question: OnboardingCategory.restaurants.questions[0],
        onAnswer: { _ in }
    )
} 