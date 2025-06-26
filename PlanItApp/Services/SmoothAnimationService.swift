import SwiftUI
import Foundation

// MARK: - Smooth Animation Service
@MainActor
class SmoothAnimationService: ObservableObject {
    static let shared = SmoothAnimationService()
    
    // MARK: - Animation States
    @Published var activeAnimations: Set<String> = []
    @Published var animationQueue: [AnimationTask] = []
    @Published var isAnimating = false
    
    // MARK: - Animation Configuration
    private let animationCoordinator = AnimationCoordinator()
    
    private init() {}
    
    // MARK: - Animation Task
    struct AnimationTask: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let priority: AnimationPriority
        let animation: Animation
        let action: () -> Void
        
        static func == (lhs: AnimationTask, rhs: AnimationTask) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    enum AnimationPriority: Int, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
    }
    
    // MARK: - Safe Animation Execution
    func performAnimation(
        name: String,
        priority: AnimationPriority = .medium,
        animation: Animation = .easeInOut(duration: 0.3),
        action: @escaping () -> Void
    ) {
        // Prevent overlapping animations with same name
        guard !activeAnimations.contains(name) else {
            print("⚠️ Animation '\(name)' already active, skipping")
            return
        }
        
        let task = AnimationTask(
            name: name,
            priority: priority,
            animation: animation,
            action: action
        )
        
        executeAnimationTask(task)
    }
    
    private func executeAnimationTask(_ task: AnimationTask) {
        activeAnimations.insert(task.name)
        isAnimating = true
        
        withAnimation(task.animation) {
            task.action()
        }
        
        // Remove from active animations after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration(task.animation)) {
            self.activeAnimations.remove(task.name)
            if self.activeAnimations.isEmpty {
                self.isAnimating = false
            }
        }
    }
    
    private func animationDuration(_ animation: Animation) -> TimeInterval {
        // Estimate animation duration based on type
        switch animation {
        case .easeIn, .easeOut, .easeInOut:
            return 0.3
        case .linear:
            return 0.25
        case .spring:
            return 0.6
        default:
            return 0.3
        }
    }
    
    // MARK: - Coordinated Animations
    func performCoordinatedAnimation(
        animations: [(String, Animation, () -> Void)],
        completion: (() -> Void)? = nil
    ) {
        let group = DispatchGroup()
        
        for (name, animation, action) in animations {
            group.enter()
            performAnimation(name: name, animation: animation) {
                action()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion?()
        }
    }
}

// MARK: - Animation Coordinator
@MainActor
class AnimationCoordinator: ObservableObject {
    @Published var cardAnimations: [String: Bool] = [:]
    @Published var scrollAnimations: [String: CGFloat] = [:]
    @Published var fadeAnimations: [String: Double] = [:]
    
    func animateCard(_ id: String, delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.cardAnimations[id] = true
            }
        }
    }
    
    func animateScroll(_ id: String, to offset: CGFloat) {
        withAnimation(.easeInOut(duration: 0.4)) {
            scrollAnimations[id] = offset
        }
    }
    
    func animateFade(_ id: String, to opacity: Double, delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                fadeAnimations[id] = opacity
            }
        }
    }
}

// MARK: - Smooth Animation ViewModifiers
struct SmoothScaleAnimation: ViewModifier {
    let isActive: Bool
    let scale: CGFloat
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? scale : 1.0)
            .animation(animation, value: isActive)
    }
}

struct SmoothFadeAnimation: ViewModifier {
    let isVisible: Bool
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(animation, value: isVisible)
    }
}

struct SmoothSlideAnimation: ViewModifier {
    let isActive: Bool
    let offset: CGSize
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .offset(isActive ? offset : .zero)
            .animation(animation, value: isActive)
    }
}

// MARK: - Smooth Animation Extensions
extension View {
    func smoothScale(
        isActive: Bool,
        scale: CGFloat = 1.05,
        animation: Animation = .spring(response: 0.4, dampingFraction: 0.7)
    ) -> some View {
        modifier(SmoothScaleAnimation(isActive: isActive, scale: scale, animation: animation))
    }
    
    func smoothFade(
        isVisible: Bool,
        animation: Animation = .easeInOut(duration: 0.3)
    ) -> some View {
        modifier(SmoothFadeAnimation(isVisible: isVisible, animation: animation))
    }
    
    func smoothSlide(
        isActive: Bool,
        offset: CGSize = CGSize(width: 0, height: -10),
        animation: Animation = .easeInOut(duration: 0.3)
    ) -> some View {
        modifier(SmoothSlideAnimation(isActive: isActive, offset: offset, animation: animation))
    }
    
    func animatedOnAppear(
        animation: Animation = .spring(response: 0.6, dampingFraction: 0.8),
        delay: TimeInterval = 0
    ) -> some View {
        self.modifier(AnimatedOnAppearModifier(animation: animation, delay: delay))
    }
}

// MARK: - Animated On Appear Modifier
struct AnimatedOnAppearModifier: ViewModifier {
    let animation: Animation
    let delay: TimeInterval
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1.0 : 0.0)
            .scaleEffect(hasAppeared ? 1.0 : 0.8)
            .animation(animation, value: hasAppeared)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    hasAppeared = true
                }
            }
    }
}

// MARK: - Performance-Optimized List Animation
struct OptimizedListAnimation: ViewModifier {
    let items: Int
    @State private var visibleItems: Set<Int> = []
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Stagger animations for better performance
                for i in 0..<min(items, 10) { // Limit initial animations
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                        visibleItems.insert(i)
                    }
                }
            }
    }
}

// MARK: - Smooth Tab Animation
struct SmoothTabAnimation: ViewModifier {
    let isSelected: Bool
    @StateObject private var animationService = SmoothAnimationService.shared
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .opacity(isSelected ? 1.0 : 0.7)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Card Hover Animation
struct CardHoverAnimation: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? 16 : 8,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onTapGesture {
                // Trigger hover effect on tap for mobile
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isHovered = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isHovered = false
                    }
                }
            }
    }
}

extension View {
    func cardHoverAnimation() -> some View {
        modifier(CardHoverAnimation())
    }
    
    func smoothTabAnimation(isSelected: Bool) -> some View {
        modifier(SmoothTabAnimation(isSelected: isSelected))
    }
    
    func optimizedListAnimation(itemCount: Int) -> some View {
        modifier(OptimizedListAnimation(items: itemCount))
    }
} 