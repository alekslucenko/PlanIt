import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import CoreLocation

// MARK: - Advanced User Fingerprint Model
struct UserFingerprint: Codable, Equatable {
    var userId: String
    var lastUpdated: Date
    
    // MARK: - Basic Profile
    var basicProfile: BasicProfile
    
    // MARK: - Behavioral Patterns (🧠 Psychology Core)
    var behavioralPatterns: BehavioralPatterns
    
    // MARK: - Preference Evolution (🎯 Adaptive Learning)  
    var preferenceEvolution: PreferenceEvolution
    
    // MARK: - Social & Contextual (👥 Social Psychology)
    var socialContext: SocialContext
    
    // MARK: - Temporal Patterns (⏰ Time-based Learning)
    var temporalPatterns: TemporalPatterns
    
    // MARK: - Emotional Intelligence (😊 Mood & Sentiment)
    var emotionalIntelligence: EmotionalIntelligence
    
    // MARK: - Location Intelligence (📍 Spatial Learning)
    var locationIntelligence: LocationIntelligence
    
    // MARK: - Interaction Patterns (🔄 Engagement Analytics)
    var interactionPatterns: InteractionPatterns
    
    // MARK: - AI Insights (🤖 Gemini Generated)
    var aiInsights: AIInsights
    
    // MARK: - Legacy Compatibility Fields
    var preferredPlaceTypes: [String]
    var likes: [String]
    var dislikes: [String]
    var onboardingResponses: [[String: String]]
    
    init(userId: String) {
        self.userId = userId
        self.lastUpdated = Date()
        self.basicProfile = BasicProfile()
        self.behavioralPatterns = BehavioralPatterns()
        self.preferenceEvolution = PreferenceEvolution()
        self.socialContext = SocialContext()
        self.temporalPatterns = TemporalPatterns()
        self.emotionalIntelligence = EmotionalIntelligence()
        self.locationIntelligence = LocationIntelligence()
        self.interactionPatterns = InteractionPatterns()
        self.aiInsights = AIInsights()
        self.preferredPlaceTypes = ["restaurant", "cafe", "park", "shopping"]
        self.likes = []
        self.dislikes = []
        self.onboardingResponses = []
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decode(String.self, forKey: .userId)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        
        basicProfile = try container.decodeIfPresent(BasicProfile.self, forKey: .basicProfile) ?? BasicProfile()
        behavioralPatterns = try container.decodeIfPresent(BehavioralPatterns.self, forKey: .behavioralPatterns) ?? BehavioralPatterns()
        preferenceEvolution = try container.decodeIfPresent(PreferenceEvolution.self, forKey: .preferenceEvolution) ?? PreferenceEvolution()
        socialContext = try container.decodeIfPresent(SocialContext.self, forKey: .socialContext) ?? SocialContext()
        temporalPatterns = try container.decodeIfPresent(TemporalPatterns.self, forKey: .temporalPatterns) ?? TemporalPatterns()
        emotionalIntelligence = try container.decodeIfPresent(EmotionalIntelligence.self, forKey: .emotionalIntelligence) ?? EmotionalIntelligence()
        locationIntelligence = try container.decodeIfPresent(LocationIntelligence.self, forKey: .locationIntelligence) ?? LocationIntelligence()
        interactionPatterns = try container.decodeIfPresent(InteractionPatterns.self, forKey: .interactionPatterns) ?? InteractionPatterns()
        aiInsights = try container.decodeIfPresent(AIInsights.self, forKey: .aiInsights) ?? AIInsights()
        
        // Handle legacy fields with defaults
        preferredPlaceTypes = try container.decodeIfPresent([String].self, forKey: .preferredPlaceTypes) ?? ["restaurant", "cafe", "park", "shopping"]
        likes = try container.decodeIfPresent([String].self, forKey: .likes) ?? []
        dislikes = try container.decodeIfPresent([String].self, forKey: .dislikes) ?? []
        onboardingResponses = try container.decodeIfPresent([[String: String]].self, forKey: .onboardingResponses) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case userId, lastUpdated, basicProfile, behavioralPatterns, preferenceEvolution
        case socialContext, temporalPatterns, emotionalIntelligence, locationIntelligence
        case interactionPatterns, aiInsights, preferredPlaceTypes, likes, dislikes, onboardingResponses
    }
    
    static func == (lhs: UserFingerprint, rhs: UserFingerprint) -> Bool {
        return lhs.userId == rhs.userId && 
               lhs.lastUpdated.timeIntervalSince1970.rounded() == rhs.lastUpdated.timeIntervalSince1970.rounded() &&
               lhs.preferredPlaceTypes == rhs.preferredPlaceTypes &&
               lhs.likes == rhs.likes &&
               lhs.dislikes == rhs.dislikes
    }
}

// MARK: - Basic Profile
struct BasicProfile: Codable {
    var displayName: String?
    var email: String?
    var currentLocation: LocationPoint?
    var onboardingCompleted: Bool
    var memberSince: Date
    var totalSessions: Int
    var averageSessionDuration: TimeInterval
    
    init() {
        self.displayName = nil
        self.email = nil
        self.currentLocation = nil
        self.onboardingCompleted = false
        self.memberSince = Date()
        self.totalSessions = 0
        self.averageSessionDuration = 0
    }
}

// MARK: - Behavioral Patterns (Core Psychology Engine)
struct BehavioralPatterns: Codable {
    // Decision Making Patterns
    var decisionSpeed: DecisionSpeed                    // Fast vs deliberate decision maker
    var riskTolerance: RiskTolerance                   // Conservative vs adventurous
    var explorationStyle: ExplorationStyle            // Planned vs spontaneous
    var socialTendency: SocialTendency                 // Solo vs group oriented
    
    // Attention & Engagement
    var attentionPatterns: AttentionPatterns           // Focus levels, scroll behavior
    var engagementDepth: EngagementDepth               // Surface vs deep engagement
    var noveltySeekingLevel: Double                    // 0.0-1.0 novelty preference
    var routinePreference: Double                      // 0.0-1.0 routine vs variety
    
    // Cognitive Biases Leveraged
    var progressBiasResponse: Double                   // How much progress motivates them
    var socialProofSensitivity: Double                // Response to "others liked this"
    var scarcityMotivation: Double                     // "Limited time" effectiveness
    var authorityInfluence: Double                     // Expert recommendations impact
    
    // Search & Discovery Behavior
    var searchPatterns: SearchPatterns
    var discoveryPreferences: DiscoveryPreferences
    
    init() {
        self.decisionSpeed = .balanced
        self.riskTolerance = .moderate
        self.explorationStyle = .balanced
        self.socialTendency = .balanced
        self.attentionPatterns = AttentionPatterns()
        self.engagementDepth = .moderate
        self.noveltySeekingLevel = 0.5
        self.routinePreference = 0.5
        self.progressBiasResponse = 0.7
        self.socialProofSensitivity = 0.6
        self.scarcityMotivation = 0.4
        self.authorityInfluence = 0.5
        self.searchPatterns = SearchPatterns()
        self.discoveryPreferences = DiscoveryPreferences()
    }
}

// MARK: - Preference Evolution (Adaptive Learning)
struct PreferenceEvolution: Codable {
    var preferredTags: [String: Double]                // Tag preferences with confidence scores
    var evolvedCategories: [String: CategoryEvolution] // How preferences changed over time
    var seasonalPatterns: [String: SeasonalPattern]    // Weather/season based preferences
    var moodBasedPreferences: [String: [String]]       // Mood -> preferred place types
    var discoveredAffinities: [String]                 // New interests AI discovered
    var confidenceScores: [String: Double]            // Confidence in each preference
    
    // Preference Drift Detection
    var preferenceStability: Double                    // How stable are their preferences
    var lastMajorShift: Date?                         // When preferences last changed significantly
    var emergingInterests: [String]                   // Newly developing interests
    
    init() {
        self.preferredTags = [:]
        self.evolvedCategories = [:]
        self.seasonalPatterns = [:]
        self.moodBasedPreferences = [:]
        self.discoveredAffinities = []
        self.confidenceScores = [:]
        self.preferenceStability = 0.5
        self.lastMajorShift = nil
        self.emergingInterests = []
    }
}

// MARK: - Social Context (Social Psychology)
struct SocialContext: Codable {
    var groupComposition: GroupComposition             // Who they typically explore with
    var socialInfluenceLevel: Double                   // How much friends influence choices
    var sharingBehavior: SharingBehavior              // How they share discoveries
    var leadershipTendency: Double                     // Planner vs follower in groups
    
    // Social Proof Patterns
    var peekAtFriendsActivity: Bool                   // Interested in what friends are doing
    var recommendsToFriends: Bool                     // Actively shares recommendations
    var followsTrends: Bool                           // Follows popular places
    var createsNewTrends: Bool                        // Discovers places before they're popular
    
    // Network Analysis
    var socialCircleSize: SocialCircleSize
    var influenceNetwork: [String: Double]            // Friend IDs and influence weights
    var mutualInterests: [String: [String]]           // Shared interests with specific friends
    
    init() {
        self.groupComposition = .mixed
        self.socialInfluenceLevel = 0.5
        self.sharingBehavior = .selective
        self.leadershipTendency = 0.5
        self.peekAtFriendsActivity = true
        self.recommendsToFriends = false
        self.followsTrends = false
        self.createsNewTrends = false
        self.socialCircleSize = .medium
        self.influenceNetwork = [:]
        self.mutualInterests = [:]
    }
}

// MARK: - Temporal Patterns (Time-based Intelligence)
struct TemporalPatterns: Codable {
    var timePreferences: [String: Double]             // Morning person vs night owl
    var dayOfWeekPatterns: [String: ActivityPattern]  // Monday vs weekend behavior
    var seasonalBehavior: [String: Double]            // Spring vs winter preferences
    var holidayPatterns: [String: Double]             // Behavior around holidays
    
    // Routine Analysis
    var hasStrongRoutines: Bool                       // Predictable vs spontaneous
    var routineFlexibility: Double                    // Willingness to break routine
    var optimalDiscoveryTimes: [String]               // Best times to suggest new places
    
    // Prediction Patterns
    var planningHorizon: PlanningHorizon              // How far ahead they plan
    var spontaneityLevel: Double                      // 0.0-1.0 spontaneous decisions
    var moodTimingPatterns: [String: [String]]        // When they're in specific moods
    
    init() {
        self.timePreferences = [:]
        self.dayOfWeekPatterns = [:]
        self.seasonalBehavior = [:]
        self.holidayPatterns = [:]
        self.hasStrongRoutines = false
        self.routineFlexibility = 0.5
        self.optimalDiscoveryTimes = []
        self.planningHorizon = .moderate
        self.spontaneityLevel = 0.5
        self.moodTimingPatterns = [:]
    }
}

// MARK: - Emotional Intelligence (Mood & Sentiment)
struct EmotionalIntelligence: Codable {
    var moodHistory: [MoodEntry]                      // Historical mood data
    var emotionalTriggers: [String: EmotionalResponse] // What affects their mood
    var moodInfluencedChoices: [String: [String]]     // Places chosen in different moods
    var stressResponsePatterns: StressResponse        // How they handle stress
    
    // Emotional State Inference
    var currentMoodIndicators: [String: Double]       // Real-time mood signals
    var moodPredictiveFactors: [String: Double]       // What predicts their mood
    var emotionalVolatility: Double                   // Mood stability
    var emotionalIntelligenceScore: Double            // Self-awareness level
    
    // Therapeutic Preferences
    var calmingPreferences: [String]                  // What helps when stressed
    var energizingPreferences: [String]               // What boosts mood
    var socialMoodPreferences: [String: SocialMoodPref] // Alone vs social when in different moods
    
    init() {
        self.moodHistory = []
        self.emotionalTriggers = [:]
        self.moodInfluencedChoices = [:]
        self.stressResponsePatterns = .balanced
        self.currentMoodIndicators = [:]
        self.moodPredictiveFactors = [:]
        self.emotionalVolatility = 0.5
        self.emotionalIntelligenceScore = 0.5
        self.calmingPreferences = []
        self.energizingPreferences = []
        self.socialMoodPreferences = [:]
    }
}

// MARK: - Location Intelligence (Spatial Learning)
struct LocationIntelligence: Codable {
    var exploredAreas: [ExploredArea]                 // Areas they've discovered
    var mobilityPatterns: MobilityPatterns            // How they move around
    var distanceComfortZone: DistancePreference       // Willing to travel distance
    var transportationPreferences: [String: Double]   // Walking, driving, public transit
    
    // Spatial Cognition
    var spatialMemory: [String: SpatialMemory]        // Remember places and routes
    var landmarkPreferences: [String]                 // Visual cues they respond to
    var navigationStyle: NavigationStyle              // GPS dependent vs intuitive
    
    // Geographic Preferences
    var urbanVsNaturalPreference: Double              // City vs nature (0.0-1.0)
    var crowdDensityTolerance: CrowdTolerance         // Busy vs quiet places
    var architecturalPreferences: [String]            // Building styles they like
    var ambientPreferences: AmbientPreferences        // Noise, lighting, atmosphere
    
    init() {
        self.exploredAreas = []
        self.mobilityPatterns = MobilityPatterns()
        self.distanceComfortZone = .moderate
        self.transportationPreferences = [:]
        self.spatialMemory = [:]
        self.landmarkPreferences = []
        self.navigationStyle = .balanced
        self.urbanVsNaturalPreference = 0.5
        self.crowdDensityTolerance = .moderate
        self.architecturalPreferences = []
        self.ambientPreferences = AmbientPreferences()
    }
}

// MARK: - Interaction Patterns (Engagement Analytics)
struct InteractionPatterns: Codable {
    var sessionBehavior: SessionBehavior               // How they use the app
    var engagementMetrics: EngagementMetrics          // Depth of interaction
    var contentConsumption: ContentConsumption        // What they focus on
    var decisionFunnels: [String: DecisionFunnel]     // How they make choices
    
    // Micro-interaction Analysis
    var scrollVelocity: ScrollBehavior                // Fast scroller vs deliberate
    var tapPatterns: TapPatterns                      // Tapping behavior analysis
    var dwellTimes: [String: TimeInterval]            // Time spent on different content
    var backtrackingBehavior: BacktrackingBehavior    // How often they revisit content
    
    // Conversion Patterns
    var browseToActionConversion: Double              // Likelihood to act on discoveries
    var discoveryToFavoriteRate: Double               // How selective they are
    var shareRate: Double                             // How often they share
    var returnToFavoriteRate: Double                  // Revisit favorite places
    
    init() {
        self.sessionBehavior = SessionBehavior()
        self.engagementMetrics = EngagementMetrics()
        self.contentConsumption = ContentConsumption()
        self.decisionFunnels = [:]
        self.scrollVelocity = .moderate
        self.tapPatterns = TapPatterns()
        self.dwellTimes = [:]
        self.backtrackingBehavior = .moderate
        self.browseToActionConversion = 0.1
        self.discoveryToFavoriteRate = 0.15
        self.shareRate = 0.05
        self.returnToFavoriteRate = 0.3
    }
}

// MARK: - AI Insights (Gemini Generated Intelligence)
struct AIInsights: Codable {
    var personalityProfile: String                    // AI-generated personality summary
    var recommendationReasons: [String]               // Why AI makes certain suggestions
    var behavioralPredictions: [String: Double]       // Predicted future behaviors
    var interestEvolutionForecast: [String]          // Predicted emerging interests
    
    // Gemini Persona Analysis
    var explorerArchetype: ExplorerArchetype          // What type of explorer they are
    var motivationalDrivers: [String: Double]        // What motivates them most
    var communicationStyle: CommunicationStyle       // How they prefer to receive info
    var decisionMakingStyle: DecisionMakingStyle      // How they process choices
    
    // Predictive Insights
    var nextLikelyInterests: [String]                 // AI-predicted new interests
    var moodPrediction: [String: Double]              // Predicted mood patterns
    var socialBehaviorForecast: SocialForecast       // Predicted social changes
    var lifestageIndicators: [String: Double]         // Life changes that affect preferences
    
    // Meta-learning
    var aiConfidenceScores: [String: Double]          // How confident AI is in predictions
    var lastAIUpdate: Date                           // When AI last analyzed profile
    var aiPersonalizationLevel: Double               // How personalized AI recommendations are
    
    init() {
        self.personalityProfile = ""
        self.recommendationReasons = []
        self.behavioralPredictions = [:]
        self.interestEvolutionForecast = []
        self.explorerArchetype = .balanced
        self.motivationalDrivers = [:]
        self.communicationStyle = .balanced
        self.decisionMakingStyle = .balanced
        self.nextLikelyInterests = []
        self.moodPrediction = [:]
        self.socialBehaviorForecast = SocialForecast()
        self.lifestageIndicators = [:]
        self.aiConfidenceScores = [:]
        self.lastAIUpdate = Date()
        self.aiPersonalizationLevel = 0.0
    }
}

// MARK: - Supporting Enums and Structs

enum DecisionSpeed: String, Codable, CaseIterable {
    case impulsive = "impulsive"       // Decides quickly, trusts gut
    case balanced = "balanced"         // Considers options but doesn't overthink
    case deliberate = "deliberate"     // Takes time, weighs all options
}

enum RiskTolerance: String, Codable, CaseIterable {
    case conservative = "conservative"  // Prefers known, safe choices
    case moderate = "moderate"         // Balanced approach to risk
    case adventurous = "adventurous"   // Seeks new, unknown experiences
}

enum ExplorationStyle: String, Codable, CaseIterable {
    case planned = "planned"           // Plans exploration, researches first
    case balanced = "balanced"         // Mix of planning and spontaneity
    case spontaneous = "spontaneous"   // Discovers serendipitously
}

enum SocialTendency: String, Codable, CaseIterable {
    case solo = "solo"                 // Prefers exploring alone
    case balanced = "balanced"         // Enjoys both solo and group
    case social = "social"             // Prefers group experiences
}

enum EngagementDepth: String, Codable, CaseIterable {
    case surface = "surface"           // Quick browsing, light engagement
    case moderate = "moderate"         // Balanced depth of interaction
    case deep = "deep"                 // Thoroughly engages with content
}

enum ExplorerArchetype: String, Codable, CaseIterable {
    case curator = "curator"           // Finds and shares gems
    case adventurer = "adventurer"     // Seeks thrills and new experiences
    case socialite = "socialite"       // Values social experiences
    case contemplative = "contemplative" // Seeks peaceful, meaningful places
    case balanced = "balanced"         // Mix of different exploration styles
}

// Additional supporting structs for comprehensive behavioral modeling...

struct AttentionPatterns: Codable {
    var averageFocusTime: TimeInterval
    var scrollingSpeed: String  // "fast", "moderate", "slow"
    var returnsToContent: Bool
    var multitaskingTendency: Double
    
    init() {
        self.averageFocusTime = 30.0
        self.scrollingSpeed = "moderate"
        self.returnsToContent = false
        self.multitaskingTendency = 0.5
    }
}

struct SearchPatterns: Codable {
    var averageSearchLength: Int
    var usesFilters: Bool
    var searchRefinementRate: Double
    var browseVsSearchRatio: Double
    
    init() {
        self.averageSearchLength = 15
        self.usesFilters = false
        self.searchRefinementRate = 0.3
        self.browseVsSearchRatio = 0.7
    }
}

struct MoodEntry: Codable {
    var timestamp: Date
    var mood: String
    var intensity: Double // 0.0-1.0
    var context: [String: String]
    var location: LocationPoint?
    
    init(mood: String, intensity: Double) {
        self.timestamp = Date()
        self.mood = mood
        self.intensity = intensity
        self.context = [:]
        self.location = nil
    }
}

// Location-related structures
struct LocationPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Placeholder structs for compilation - these would be fully implemented
struct DiscoveryPreferences: Codable { init() {} }
struct CategoryEvolution: Codable { init() {} }
struct SeasonalPattern: Codable { init() {} }
struct GroupComposition: Codable { init() {} }
struct SharingBehavior: Codable { init() {} }
struct SocialCircleSize: Codable { init() {} }
struct ActivityPattern: Codable { init() {} }
struct PlanningHorizon: Codable { init() {} }
struct EmotionalResponse: Codable { init() {} }
struct StressResponse: Codable { init() {} }
struct SocialMoodPref: Codable { init() {} }
struct ExploredArea: Codable { init() {} }
struct MobilityPatterns: Codable { init() {} }
struct DistancePreference: Codable { init() {} }
struct SpatialMemory: Codable { init() {} }
struct NavigationStyle: Codable { init() {} }
struct CrowdTolerance: Codable { init() {} }
struct AmbientPreferences: Codable { init() {} }
struct SessionBehavior: Codable { init() {} }
struct ContentConsumption: Codable { init() {} }
struct DecisionFunnel: Codable { init() {} }
struct ScrollBehavior: Codable { init() {} }
struct TapPatterns: Codable { init() {} }
struct BacktrackingBehavior: Codable { init() {} }
struct CommunicationStyle: Codable { init() {} }
struct DecisionMakingStyle: Codable { init() {} }
struct SocialForecast: Codable { init() {} }

// Enum implementations would be extended based on the pattern above...
extension GroupComposition {
    static let mixed = GroupComposition()
}

extension SharingBehavior {
    static let selective = SharingBehavior()
}

extension SocialCircleSize {
    static let medium = SocialCircleSize()
}

extension PlanningHorizon {
    static let moderate = PlanningHorizon()
}

extension StressResponse {
    static let balanced = StressResponse()
}

extension DistancePreference {
    static let moderate = DistancePreference()
}

extension NavigationStyle {
    static let balanced = NavigationStyle()
}

extension CrowdTolerance {
    static let moderate = CrowdTolerance()
}

extension ScrollBehavior {
    static let moderate = ScrollBehavior()
}

extension BacktrackingBehavior {
    static let moderate = BacktrackingBehavior()
}

extension CommunicationStyle {
    static let balanced = CommunicationStyle()
}

extension DecisionMakingStyle {
    static let balanced = DecisionMakingStyle()
} 