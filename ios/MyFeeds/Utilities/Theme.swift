import SwiftUI

extension Color {
    /// Create a color from HSL values (hue 0-360, saturation 0-100, lightness 0-100),
    /// matching the CSS hsl() palette used by the companion apps.
    init(hsl hue: Double, _ saturation: Double, _ lightness: Double, alpha: Double = 1) {
        let s = saturation / 100
        let l = lightness / 100
        let brightness = l + s * min(l, 1 - l)
        let sat = brightness == 0 ? 0 : 2 * (1 - l / brightness)
        self.init(hue: hue / 360, saturation: sat, brightness: brightness, opacity: alpha)
    }
}

/// My Feeds design system — deep navy command-center palette with sky-blue accents.
enum Theme {
    static let background = Color(hsl: 220, 30, 8)
    static let card = Color(hsl: 220, 30, 11)
    static let input = Color(hsl: 220, 30, 14)
    static let border = Color(hsl: 220, 15, 22)
    static let cardBorder = Color(hsl: 220, 25, 18)
    static let borderFocus = Color(hsl: 199, 89, 48)

    static let textPrimary = Color(hsl: 220, 20, 92)
    static let textSecondary = Color(hsl: 215, 15, 55)
    static let textMuted = Color(hsl: 220, 10, 42)

    static let accent = Color(hsl: 199, 89, 48)
    static let accentGradient = LinearGradient(
        colors: [Color(hsl: 199, 89, 48), Color(hsl: 199, 89, 40)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let accentPressed = Color(hsl: 199, 89, 36)

    static let success = Color(hsl: 142, 71, 45)
    static let warning = Color(hsl: 38, 92, 50)
    static let destructive = Color(hsl: 0, 84, 60)
    static let destructiveBg = Color(hsl: 0, 84, 14)

    /// Per-agent accent colors — cycled by index in the alphabetically sorted agent list.
    static let agentAccents: [Color] = [
        Color(hsl: 199, 89, 48),
        Color(hsl: 152, 69, 50),
        Color(hsl: 32, 95, 55),
        Color(hsl: 0, 72, 55),
        Color(hsl: 199, 89, 70),
        Color(hsl: 280, 70, 60),
        Color(hsl: 168, 70, 50),
        Color(hsl: 30, 90, 55),
    ]

    static func agentAccent(_ index: Int) -> Color {
        agentAccents[((index % agentAccents.count) + agentAccents.count) % agentAccents.count]
    }
}

/// Card container used throughout the app.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = 12) -> some View {
        modifier(CardBackground(radius: radius))
    }
}

/// Uppercase section header used on Dashboard / Agent Detail.
struct SectionHeader: View {
    let title: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 12)
    }
}
