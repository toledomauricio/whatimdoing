import Cocoa

struct TextTruncator {
    /// Truncates text to fit within maxWidth using the given font.
    /// Strategy: full text → semantic word truncation → character truncation.
    static func truncate(_ text: String, maxWidth: CGFloat = 200, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let fullSize = (text as NSString).size(withAttributes: attributes)
        if fullSize.width <= maxWidth { return text }

        let ellipsis = "…"
        let words = text.split(separator: " ").map(String.init)

        // Try keeping first words + last word with ellipsis in between
        if words.count > 2, let lastWord = words.last {
            for keepCount in stride(from: words.count - 2, through: 1, by: -1) {
                let prefix = words.prefix(keepCount).joined(separator: " ")
                let candidate = "\(prefix) \(ellipsis) \(lastWord)"
                let size = (candidate as NSString).size(withAttributes: attributes)
                if size.width <= maxWidth { return candidate }
            }
        }

        // Fallback: truncate by characters
        return truncateByCharacters(text, maxWidth: maxWidth, font: font)
    }

    static func truncateByCharacters(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength - 1)) + "…"
    }

    private static func truncateByCharacters(_ text: String, maxWidth: CGFloat, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let ellipsis = "…"
        var truncated = text

        while !truncated.isEmpty {
            truncated = String(truncated.dropLast())
            let candidate = truncated + ellipsis
            let size = (candidate as NSString).size(withAttributes: attributes)
            if size.width <= maxWidth { return candidate }
        }

        return ellipsis
    }
}
