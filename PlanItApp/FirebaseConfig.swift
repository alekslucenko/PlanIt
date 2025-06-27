import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

class FirebaseConfig {
    static func configure() {
        guard FirebaseApp.app() == nil else {
            print("🔥 Firebase already configured")
            return
        }
        
        FirebaseApp.configure()
        
        // Configure Firestore settings for better offline support
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
        
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ Error: Could not find CLIENT_ID in GoogleService-Info.plist")
            return
        }
        
        let gidConfig = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = gidConfig
        
        print("🔥 Firebase configured successfully with Google Sign-In and enhanced offline support")
    }
} 