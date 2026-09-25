import SwiftUI
import PowerSnekKit

/// A grid of style cards. Picking one applies its presets (color, laps,
/// speed) and calls `onPick`, e.g. to preview it.
struct StylePicker: View {
    @ObservedObject var settings: SettingsStore
    var compact = false
    var onPick: @MainActor (CelebrationProfile) -> Void = { _ in }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: compact ? 5 : 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(CelebrationProfile.all) { profile in
                StyleCard(profile: profile,
                          isSelected: settings.styleID == profile.id,
                          compact: compact) {
                    settings.apply(profile)
                    onPick(profile)
                }
            }
        }
    }
}

struct StyleCard: View {
    let profile: CelebrationProfile
    let isSelected: Bool
    var compact = false
    let action: @MainActor () -> Void

    @State private var isHovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                StyleSwatch(profile: profile, animating: isSelected || isHovering)
                    .frame(height: compact ? 42 : 56)
                Text(profile.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if !compact {
                    Text(profile.tagline)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(shape.fill(isSelected ? Brand.accent.opacity(0.14) : Color.primary.opacity(0.04)))
            .overlay(shape.strokeBorder(isSelected ? Brand.accent : Color.primary.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(profile.tagline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile.name) style")
        .accessibilityHint(profile.tagline)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

/// A tiny dark "screen" with the style's comet running around its edge
/// (static glow when not animating or under Reduce Motion).
struct StyleSwatch: View {
    let profile: CelebrationProfile
    let animating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        Color(nsColor: HexColor.nsColor(fromHex: profile.colorHex) ?? .systemGreen)
    }

    private var edge: some Shape {
        RoundedRectangle(cornerRadius: 5, style: .continuous).inset(by: 5)
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.07))
            if animating && !reduceMotion {
                TimelineView(.animation) { context in
                    comet(head: phase(at: context.date))
                }
            } else {
                edge.stroke(color.opacity(0.85), lineWidth: 1.4 * profile.strokeScale + 0.4)
                    .shadow(color: color.opacity(0.8), radius: 3 * profile.glowScale)
            }
            UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
                .fill(Color.black)
                .frame(width: 16, height: 5)
        }
        .accessibilityHidden(true)
    }

    /// Head position (0…1 around the edge), lapping at the style's speed.
    private func phase(at date: Date) -> Double {
        let lap = max(0.6, profile.lapDuration
            / (CometMath.calibrationLaps + CelebrationProfile.nominalLandingFraction))
        return (date.timeIntervalSinceReferenceDate / lap).truncatingRemainder(dividingBy: 1)
    }

    private func comet(head: Double) -> some View {
        let tail = head - min(0.45, profile.trailFraction * 2.2)
        let width = 2 * profile.strokeScale + 0.6
        return ZStack {
            edge.stroke(color.opacity(0.15), lineWidth: 1)
            segment(from: max(0, tail), to: head, width: width)
            if tail < 0 {
                segment(from: tail + 1, to: 1, width: width)
            }
        }
        .shadow(color: color, radius: 4 * profile.glowScale)
    }

    private func segment(from start: Double, to end: Double, width: CGFloat) -> some View {
        edge.trim(from: CGFloat(start), to: CGFloat(end))
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
