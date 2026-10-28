import ArenaKit
import SwiftUI
import UIKit

// The look of the Are.na website: Arial, black on white (white on black in
// dark mode), grey hairlines, small bold controls with 3 pt corners, and
// green for open channels.

// MARK: - Colour

extension ShapeStyle where Self == Color {
    static var arenaBackground: Color { Color(light: 0xFFFFFF, dark: 0x000000) }
    /// Headings and selected items.
    static var arenaInk: Color { Color(light: 0x000000, dark: 0xFFFFFF) }
    /// Running text.
    static var arenaBodyInk: Color { Color(light: 0x333333, dark: 0xE5E5E5) }
    static var arenaSecondary: Color { Color(light: 0x696969, dark: 0xB2B2B2) }
    static var arenaTertiary: Color { Color(light: 0x999999, dark: 0x777777) }
    /// Button and placeholder fill.
    static var arenaFill: Color { Color(light: 0xF7F7F7, dark: 0x1A1A1A) }
    static var arenaHairline: Color { Color(light: 0xDEDEDE, dark: 0x333333) }
    /// The one filled button on a screen ("Sign up" on are.na).
    static var arenaAccent: Color { Color(light: 0x00075F, dark: 0xE2DFE9) }
    static var arenaOnAccent: Color { Color(light: 0xFFFFFF, dark: 0x000000) }
    /// Open (public) channels.
    static var arenaOpen: Color { Color(light: 0x238020, dark: 0x5DBB59) }
    static var arenaPrivate: Color { Color(light: 0xB3261E, dark: 0xE5605A) }
}

extension Color {
    fileprivate init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}

extension Optional where Wrapped == Channel.Visibility {
    /// Are.na colours channel names by visibility: green when anyone can
    /// add, red when private, plain otherwise.
    var color: Color {
        switch self {
        case .public: .arenaOpen
        case .private: .arenaPrivate
        case .closed, nil: .arenaInk
        }
    }
}

// MARK: - Type

extension Font {
    /// Arial, scaled with Dynamic Type like `style`.
    static func arena(_ size: CGFloat, bold: Bool = false, relativeTo style: TextStyle = .body) -> Font {
        .custom(bold ? "Arial-BoldMT" : "ArialMT", size: size, relativeTo: style)
    }

    static let arenaLargeTitle = arena(28, bold: true, relativeTo: .largeTitle)
    static let arenaTitle = arena(20, bold: true, relativeTo: .title3)
    static let arenaBody = arena(16)
    static let arenaBodyBold = arena(16, bold: true)
    static let arenaSmall = arena(13, relativeTo: .footnote)
    static let arenaSmallBold = arena(13, bold: true, relativeTo: .footnote)
}

enum ArenaAppearance {
    /// Navigation bar titles and bar buttons are UIKit, so they're set here.
    @MainActor
    static func apply() {
        let metrics = UIFontMetrics(forTextStyle: .headline)
        if let bold = UIFont(name: "Arial-BoldMT", size: 16), let regular = UIFont(name: "ArialMT", size: 17) {
            UINavigationBar.appearance().titleTextAttributes = [.font: metrics.scaledFont(for: bold)]
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: bold.withSize(30))
            ]
            UIBarButtonItem.appearance().setTitleTextAttributes([.font: metrics.scaledFont(for: regular)], for: .normal)
        }
    }
}

// MARK: - Controls

/// Are.na's small, bold, nearly square buttons. `.arenaPrimary` is the filled
/// one; use it once per screen.
struct ArenaButtonStyle: ButtonStyle {
    var isPrimary = false
    var isFullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.arenaSmallBold)
            .foregroundStyle(foreground(for: configuration.role))
            .padding(.horizontal, 12)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: isFullWidth ? 44 : 34)
            .background(isPrimary ? Color.arenaAccent : Color.arenaFill, in: RoundedRectangle(cornerRadius: 3))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Rectangle())
    }

    private func foreground(for role: ButtonRole?) -> Color {
        if isPrimary { return .arenaOnAccent }
        return role == .destructive ? .arenaPrivate : .arenaBodyInk
    }
}

extension ButtonStyle where Self == ArenaButtonStyle {
    static var arena: ArenaButtonStyle { ArenaButtonStyle() }
    static var arenaPrimary: ArenaButtonStyle { ArenaButtonStyle(isPrimary: true) }
    static func arenaPrimary(fullWidth: Bool) -> ArenaButtonStyle { ArenaButtonStyle(isPrimary: true, isFullWidth: fullWidth) }
}

/// A small grey label over a hairline, like "View" and "Sort" on are.na.
struct ArenaSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.arenaSmall)
                .foregroundStyle(.arenaSecondary)
            Rectangle()
                .fill(.arenaHairline)
                .frame(height: 1)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A titled group of content under an `ArenaSectionHeader`.
struct ArenaSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArenaSectionHeader(title: title)
            content
        }
    }
}

/// A vertical list of choices with a bar down the left and a marker on the
/// chosen one, like the View and Sort controls on are.na.
struct ArenaOptionList<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        ArenaSection(title) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection
                    Button {
                        selection = option
                    } label: {
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(isSelected ? Color.arenaSecondary : Color.clear)
                                .frame(width: 4, height: 10)
                            Text(label(option))
                                .font(.arenaSmallBold)
                                .foregroundStyle(isSelected ? Color.arenaInk : Color.arenaSecondary)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .background(alignment: .leading) {
                Capsule()
                    .fill(.arenaFill)
                    .frame(width: 4)
            }
        }
    }
}

/// A 1 pt grey frame, as around text blocks and channels on are.na.
struct ArenaFrame: ViewModifier {
    var color: Color = .arenaHairline

    func body(content: Content) -> some View {
        content
            .background(.arenaBackground)
            .overlay { Rectangle().strokeBorder(color, lineWidth: 1) }
    }
}

extension View {
    func arenaFrame(_ color: Color = .arenaHairline) -> some View {
        modifier(ArenaFrame(color: color))
    }
}
