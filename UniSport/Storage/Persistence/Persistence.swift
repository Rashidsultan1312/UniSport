import Foundation

final class KeyValueStore {
    static let shared = KeyValueStore()

    private let defaults = UserDefaults.standard

    func save<Value: Encodable>(_ value: Value, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }

    func load<Value: Decodable>(_ type: Value.Type, forKey key: String) throws -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func saveBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func loadBool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    func saveDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func loadDouble(forKey key: String) -> Double {
        defaults.double(forKey: key)
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

struct CacheEntry: Codable {
    let key: String
    let data: Data
    let expiryDate: Date
}

final class DiskCache {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folderName: String = "UniSportCache") {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directoryURL = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func save<T: Encodable>(_ value: T, for key: String, expiryDate: Date) throws {
        let payload = try JSONEncoder().encode(value)
        let entry = CacheEntry(key: key, data: payload, expiryDate: expiryDate)
        let url = fileURL(for: key)
        try encoder.encode(entry).write(to: url)
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> (value: T, isStale: Bool)? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let entry = try decoder.decode(CacheEntry.self, from: data)
        let value = try JSONDecoder().decode(T.self, from: entry.data)
        return (value, Date() > entry.expiryDate)
    }

    func clear() throws {
        let contents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        for item in contents {
            try FileManager.default.removeItem(at: item)
        }
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }
}

final class MemoryCache {
    static let shared = MemoryCache()
    private let cache = NSCache<NSString, NSData>()

    func save(_ data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }

    func load(for key: String) -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }

    func clear() {
        cache.removeAllObjects()
    }
}

enum CacheTTL {
    static let countriesAndLeagues: TimeInterval = 60 * 60 * 24
    static let teams: TimeInterval = 60 * 60 * 12
    static let standings: TimeInterval = 60 * 15
    static let fixtures: TimeInterval = 60 * 5
    static let live: TimeInterval = 20
    static let details: TimeInterval = 60 * 2
    static let topScorers: TimeInterval = 60 * 60 * 6
}
