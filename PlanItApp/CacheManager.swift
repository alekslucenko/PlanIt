import Foundation
import FirebaseFirestore

// MARK: - CachedPlace Model
struct CachedPlace: Codable, Identifiable {
    let id: String // placeId
    let json: String // base64 encoded
    let updatedAt: Date
}

// MARK: - CacheManager
@MainActor
final class CacheManager: ObservableObject {
    static let shared = CacheManager()
    private init() {}

    private let memoryCache = NSCache<NSString, NSString>()
    private let db = Firestore.firestore()
    private let ttl: TimeInterval = 60 * 60 * 24 // 24h

    func getPlace(for id: String) async -> Data? {
        if let str = memoryCache.object(forKey: id as NSString) {
            return Data(base64Encoded: str as String)
        }
        // Check Firestore cache collection
        do {
            let doc = try await db.collection("cachedPlaces").document(id).getDocument()
            if let ts = doc["updatedAt"] as? Timestamp,
               Date().timeIntervalSince(ts.dateValue()) < ttl,
               let blobStr = doc["json"] as? String,
               let blobData = Data(base64Encoded: blobStr) {
                memoryCache.setObject(blobStr as NSString, forKey: id as NSString)
                return blobData
            }
        } catch {
            print("Cache fetch error: \(error)")
        }
        return nil
    }

    func savePlace(id: String, json: Data) async {
        let encoded = json.base64EncodedString()
        memoryCache.setObject(encoded as NSString, forKey: id as NSString)
        do {
            try await db.collection("cachedPlaces").document(id).setData([
                "json": encoded,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("Cache save error: \(error)")
        }
    }
} 