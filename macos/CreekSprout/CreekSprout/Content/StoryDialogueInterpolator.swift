import Foundation

enum StoryDialogueInterpolationError: Error, Equatable, CustomStringConvertible {
    case standingOutOfRange(Int)
    case missingQ05Resolution
    case invalidQ05Resolution(String)
    case unknownToken(String)
    case unresolvedToken(String)

    var description: String {
        switch self {
        case let .standingOutOfRange(value):
            "社会声誉超出 0...100：\(value)"
        case .missingQ05Resolution:
            "对白需要已保存的 q05_resolution"
        case let .invalidQ05Resolution(value):
            "非法 q05_resolution：\(value)"
        case let .unknownToken(token):
            "对白含未知插值 token：\(token)"
        case let .unresolvedToken(text):
            "对白插值后仍含未解析 token：\(text)"
        }
    }
}

struct StoryDialogueInterpolationContext: Equatable, Sendable {
    var standing: Int
    var q05Resolution: StoryChoiceID?
}

enum StoryDialogueInterpolator {
    static let allowedTokens: Set<String> = ["reputation", "q05_resolution"]

    private static let tokenExpression = try! NSRegularExpression(
        pattern: #"\{\{([a-z0-9_]+)\}\}"#
    )

    static func tokens(in text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return tokenExpression.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[tokenRange])
        }
    }

    static func interpolate(
        _ text: String,
        context: StoryDialogueInterpolationContext
    ) throws -> String {
        guard (0...100).contains(context.standing) else {
            throw StoryDialogueInterpolationError.standingOutOfRange(context.standing)
        }

        let foundTokens = tokens(in: text)
        if let unknown = foundTokens.first(where: { !allowedTokens.contains($0) }) {
            throw StoryDialogueInterpolationError.unknownToken(unknown)
        }

        var result = text.replacingOccurrences(
            of: "{{reputation}}",
            with: String(context.standing)
        )

        if foundTokens.contains("q05_resolution") {
            guard let resolution = context.q05Resolution else {
                throw StoryDialogueInterpolationError.missingQ05Resolution
            }
            let displayValue: String
            switch resolution {
            case .publicOrder: displayValue = "公开限量单"
            case .coop: displayValue = "联合供货"
            case .delay: displayValue = "暂缓签约"
            default:
                throw StoryDialogueInterpolationError.invalidQ05Resolution(resolution.rawValue)
            }
            result = result.replacingOccurrences(of: "{{q05_resolution}}", with: displayValue)
        }

        guard tokens(in: result).isEmpty, !result.contains("{{") else {
            throw StoryDialogueInterpolationError.unresolvedToken(result)
        }
        return result
    }

    static func interpolate(
        _ text: String,
        standing: Int,
        q05Resolution: StoryChoiceID? = nil
    ) throws -> String {
        try interpolate(
            text,
            context: StoryDialogueInterpolationContext(
                standing: standing,
                q05Resolution: q05Resolution
            )
        )
    }
}

