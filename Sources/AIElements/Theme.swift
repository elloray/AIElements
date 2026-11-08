import SwiftUI
import CoreText

/// Semantic reference tokens. Set with `.aiTheme(...)` on any subtree.
public struct AITheme: Sendable {
    public var background: Color
    public var foreground: Color
    public var muted: Color
    public var mutedForeground: Color
    public var border: Color
    public var destructive: Color
    public var radius: CGFloat
    public var accent: Color
    /// Optional overrides follow the theme's foreground and background when omitted.
    public var primaryButtonFill: Color?
    public var primaryButtonLabel: Color?
    public var outlineButtonFill: Color?
    public var inputBackground: Color
    public var cardBackground: Color
    public init(background: Color, foreground: Color, muted: Color, mutedForeground: Color,
                border: Color, destructive: Color, radius: CGFloat = 14, accent: Color? = nil, inputBackground: Color? = nil,
                primaryButtonFill: Color? = nil, primaryButtonLabel: Color? = nil, outlineButtonFill: Color? = nil, cardBackground: Color? = nil) {
        self.cardBackground = cardBackground ?? background
        self.primaryButtonFill = primaryButtonFill
        self.primaryButtonLabel = primaryButtonLabel
        self.outlineButtonFill = outlineButtonFill
        self.background = background; self.foreground = foreground; self.muted = muted
        self.mutedForeground = mutedForeground; self.border = border
        self.destructive = destructive; self.radius = radius; self.accent = accent ?? muted; self.inputBackground = inputBackground ?? muted.opacity(0.65)
    }
    // CSS Lab D50 tokens captured from the reference, converted to sRGB (2026-11-06).
    public static let light = AITheme(background: .white, foreground: .black, muted: Color(white: 0.960587), mutedForeground: Color(white: 0.451519), border: Color(white: 0.898161), destructive: Color(red: 0.906411, green: 0, blue: 0.042121), inputBackground: Color(white: 0.898161).opacity(0.5))
    public static let dark = AITheme(background: Color(white: 0.039388), foreground: Color(white: 0.980256), muted: Color(white: 0.149382), mutedForeground: Color(white: 0.630163), border: .white.opacity(0.10), destructive: Color(red: 1, green: 0.391179, blue: 0.403845), accent: Color(white: 0.250471), inputBackground: .white.opacity(0.075),
                                     primaryButtonFill: Color(white: 229 / 255), primaryButtonLabel: Color(white: 23 / 255), outlineButtonFill: .clear, cardBackground: Color(white: 23 / 255))

}
private struct AIThemeKey: EnvironmentKey { static let defaultValue: AITheme? = nil }
extension EnvironmentValues {
    public var aiThemeOverride: AITheme? {
        get { self[AIThemeKey.self] }
        set { self[AIThemeKey.self] = newValue }
    }
}
@propertyWrapper struct Theme: DynamicProperty {
    @Environment(\.aiThemeOverride) private var override
    @Environment(\.colorScheme) private var scheme
    var wrappedValue: AITheme { override ?? (scheme == .dark ? .dark : .light) }
}
extension View {
    public func aiTheme(_ theme: AITheme) -> some View { environment(\.aiThemeOverride, theme) }
    func aiFont(_ size: CGFloat = 14, weight: Font.Weight = .regular, mono: Bool = false) -> some View {
        font(AITypography.font(size, weight: weight, mono: mono))
    }
}
public enum AITypography {
    private static let registration: Void = {
        for url in Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
    public static func font(_ size: CGFloat = 14, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        _ = registration
        let suffix = weight == .semibold || weight == .bold ? "SemiBold" : weight == .medium ? "Medium" : "Regular"
        return .custom("\(mono ? "GeistMono" : "Geist")-\(suffix)", size: size, relativeTo: .body)
    }
}

public enum AIButtonVariant { case primary, outline, ghost, secondary }
public enum AIButtonSize { case tiny, small, regular, icon, iconSmall
    var height: CGFloat { self == .tiny ? 24 : self == .small || self == .iconSmall ? 28 : 32 }
    var isIcon: Bool { self == .icon || self == .iconSmall }
}
public struct AIButtonStyle: ButtonStyle {
    public var variant: AIButtonVariant
    public var size: AIButtonSize
    public var fill: Color?
    public init(_ variant: AIButtonVariant = .outline, compact: Bool = false, size: AIButtonSize? = nil, fill: Color? = nil) {
        self.fill = fill
        self.variant = variant; self.size = size ?? (compact ? .small : .regular)
    }
    public func makeBody(configuration: Configuration) -> some View {
        StyledAIButton(label: configuration.label, pressed: configuration.isPressed, variant: variant, size: size, fill: fill)
    }
}
private struct StyledAIButton<Label: View>: View {
    var label: Label; var pressed: Bool; var variant: AIButtonVariant; var size: AIButtonSize
    var fill: Color?
    @Theme private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @ScaledMetric(relativeTo: .body) private var scale = 1.0
    @State private var hovered = false
    private var buttonFill: Color {
        if let fill { return fill }
        switch variant {
        case .primary: return theme.primaryButtonFill ?? theme.foreground
        case .secondary: return theme.muted
        case .outline: return pressed || hovered ? theme.muted : theme.outlineButtonFill ?? theme.background
        case .ghost: return pressed || hovered ? theme.muted : .clear
        }
    }
    private var buttonLabel: Color {
        guard variant == .primary else { return theme.foreground }
        return fill == nil ? theme.primaryButtonLabel ?? theme.background : .white
    }
    var body: some View {
        label.aiFont(size == .tiny ? 12 : 14, weight: .medium)
            // CSS borders occupy one point on each side of the content box.
            .padding(.horizontal, size.isIcon ? 0 : size == .tiny ? 11 : 13)
            .frame(width: size.isIcon ? size.height * scale : nil, height: size.height * scale)
            .foregroundStyle(buttonLabel).environment(\.aiLabelForeground, buttonLabel)
            .background(buttonFill, in: Capsule())
            .overlay(Capsule().strokeBorder(focused ? theme.mutedForeground : variant == .outline ? theme.border : .clear, lineWidth: focused ? 2 : 1))
            .clipShape(Capsule())
            .aiHitTarget().opacity(enabled ? (pressed ? 0.75 : 1) : 0.5)
            .onHover { hovered = $0 }
    }
}

public struct AIBadge: View {
    public var text: String
    @Theme private var theme
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text).aiFont(12, weight: .medium).padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(theme.foreground).background(theme.muted, in: Capsule())
    }
}

struct AIShimmer: ViewModifier {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.aiAnimationsActive) private var animationsActive
    @Environment(\.scenePhase) private var scenePhase
    @Theme private var theme
    func body(content: Content) -> some View {
        if active && !reduceMotion && animationsActive && scenePhase != .background {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                content.overlay {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, theme.foreground.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.45).offset(x: proxy.size.width * (phase * 1.8 - 0.5))
                    }.mask(content)
                }
            }
        } else { content }
    }
}

/// Native touch spacing on iOS; reference spacing on macOS. Visual control shapes stay compact.
public enum AIControlDensity: Sendable { case reference, comfortable }
private struct AIControlDensityKey: EnvironmentKey {
    #if os(iOS)
    static let defaultValue = AIControlDensity.comfortable
    #else
    static let defaultValue = AIControlDensity.reference
    #endif
}
extension EnvironmentValues {
    public var aiControlDensity: AIControlDensity {
        get { self[AIControlDensityKey.self] }
        set { self[AIControlDensityKey.self] = newValue }
    }
}
extension View {
    public func aiControlDensity(_ density: AIControlDensity) -> some View { environment(\.aiControlDensity, density) }
    func aiHitTarget() -> some View { modifier(AIHitTarget()) }
}
private struct AIHitTarget: ViewModifier {
    @Environment(\.aiControlDensity) private var density
    func body(content: Content) -> some View {
        content.frame(minWidth: density == .comfortable ? 44 : nil, minHeight: density == .comfortable ? 44 : nil)
            .contentShape(Rectangle())
    }
}

// The row keeps its full hit rectangle. Only the visible label moves into
// spare vertical space. The first and last labels face the middle of the list.
struct AIListRowTarget: ViewModifier {
    var index: Int
    var count: Int
    @Environment(\.aiControlDensity) private var density
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        if density == .comfortable && count > 1 && !typeSize.isAccessibilitySize {
            let fraction = 1 - CGFloat(index) / CGFloat(count - 1)
            TouchRowLayout(fraction: fraction) { content }.contentShape(Rectangle())
        } else {
            content.aiHitTarget()
        }
    }
}

private struct TouchRowLayout: Layout {
    let fraction: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let label = subviews[0].sizeThatFits(.init(width: proposal.width, height: nil))
        return CGSize(width: max(44, label.width), height: max(44, label.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        let height = subviews[0].sizeThatFits(proposal).height
        let inset = max(0, bounds.height - height) * fraction
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY + inset),
                          anchor: .topLeading, proposal: proposal)
    }
}

private struct AIAnimationsKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var aiAnimationsActive: Bool { get { self[AIAnimationsKey.self] } set { self[AIAnimationsKey.self] = newValue } }
}
/// A single spinner shared by submitted prompts and streaming reasoning.
struct AISpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.aiAnimationsActive) private var active
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !active)) { context in
            AIIcon(.loaderCircle).rotationEffect(.degrees(reduceMotion || !active ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360))
        }
    }
}
/// macOS hover preview; touch platforms retain their explicit button action.
struct AIHoverPreview<Preview: View>: ViewModifier {
    @Binding var showing: Bool
    @ViewBuilder var preview: () -> Preview
    @State private var closeTask: Task<Void, Never>?
    func body(content: Content) -> some View {
        #if os(macOS)
        content.onHover { inside in
            updateHover(inside)
            if inside { showing = true }
        }.popover(isPresented: $showing) { preview().onHover(perform: updateHover) }
            .onDisappear { closeTask?.cancel() }
        #else
        content.popover(isPresented: $showing) { preview() }
        #endif
    }
    private func updateHover(_ inside: Bool) {
        closeTask?.cancel()
        if !inside {
            closeTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                showing = false
            }
        }
    }
}

extension View {
    /// Pause decorative activity animations in offscreen surfaces or deterministic captures.
    public func aiAnimationsEnabled(_ enabled: Bool) -> some View { environment(\.aiAnimationsActive, enabled) }
}

private struct AIParagraphMutedKey: EnvironmentKey { static let defaultValue = false }
private struct AIParagraphLineHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 20 }
extension EnvironmentValues {
    var aiParagraphMuted: Bool {
        get { self[AIParagraphMutedKey.self] }
        set { self[AIParagraphMutedKey.self] = newValue }
    }
    var aiParagraphLineHeight: CGFloat {
        get { self[AIParagraphLineHeightKey.self] }
        set { self[AIParagraphLineHeightKey.self] = newValue }
    }
}
