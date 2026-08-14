enum ContentID {
    static let mistRadishCrop = "brookseed.crop.mist_radish"
    static let mistRadishSeed = "brookseed.item.mist_radish_seed"
    static let mistRadishItem = "brookseed.item.mist_radish"

    static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 120 else {
            return false
        }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else {
            return false
        }
        return segments.allSatisfy(isIdentifier(_:))
    }

    private static func isIdentifier(_ segment: Substring) -> Bool {
        guard let first = segment.first, first.isLetter || first == "_" else {
            return false
        }
        return segment.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_"
        }
    }
}
