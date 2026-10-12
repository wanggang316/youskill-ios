import Foundation

enum AppConfiguration {
    static let apiBaseURL = URL(string: "https://api.youskill.cc")!
    static let skillsAPIKey = "4586a151c7950fa482a099dfa916ff9d616d02d9f10e710c31819607aabb9fff"
    static let websiteURL = URL(string: "https://youskill.cc")!
    static let githubURL = URL(string: "https://github.com/wanggang316/youskill-ios")!
    static let desktopGithubURL = URL(string: "https://github.com/wanggang316/you-skill")!
    static let bundleIdentifier = "com.gumpw.youskill"

    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

enum AppJSONCoders {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601Formatters.makeWithFractionalSeconds().date(from: value) {
                return date
            }
            if let date = ISO8601Formatters.makeBasic().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = ISO8601Formatters.makeWithFractionalSeconds().string(from: date)
            try container.encode(string)
        }
        return encoder
    }()
}

enum ISO8601Formatters {
    static func makeWithFractionalSeconds() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static func makeBasic() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
