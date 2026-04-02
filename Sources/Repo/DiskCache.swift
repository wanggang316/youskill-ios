import CryptoKit
import Foundation

actor DiskCache {
    private let baseDirectory: URL
    private let fileManager: FileManager

    init(namespace: String, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        baseDirectory = cachesURL.appendingPathComponent(AppConfiguration.bundleIdentifier, isDirectory: true)
            .appendingPathComponent(namespace, isDirectory: true)

        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func loadText(for key: String) -> String? {
        let url = fileURL(for: key)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func store(text: String, for key: String) throws {
        let url = fileURL(for: key)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func loadJSON<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? AppJSONCoders.decoder.decode(T.self, from: data)
    }

    func storeJSON<T: Encodable>(_ value: T, for key: String) throws {
        let data = try AppJSONCoders.encoder.encode(value)
        let url = fileURL(for: key)
        try data.write(to: url)
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hashed = digest.map { String(format: "%02x", $0) }.joined()
        return baseDirectory.appendingPathComponent(hashed)
    }
}
