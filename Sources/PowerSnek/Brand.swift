import AppKit
import SwiftUI

/// Brand tokens shared with the website (`site/src/styles.css`).
enum Brand {
    /// Controls and highlights: chartreuse (#C3FB1C) on dark backgrounds,
    /// olive (#5C7414) on light ones, where chartreuse lacks contrast.
    static let accent = Color(nsColor: NSColor(name: "PowerSnekAccent") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 0xC3 / 255.0, green: 0xFB / 255.0, blue: 0x1C / 255.0, alpha: 1)
        }
        return NSColor(srgbRed: 0x5C / 255.0, green: 0x74 / 255.0, blue: 0x14 / 255.0, alpha: 1)
    })
}
