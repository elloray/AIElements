import SwiftUI

public enum AICardStyle: String, Sendable { case standard, chart }

/// The current base Card and the roomier chart-gallery Card have separate geometry.
public struct AICard<Content: View>: View {
    public var title: String?
    public var description: String?
    public var footer: String?
    public var footnote: String?
    public var footerIcon: AIIconName?
    public var style: AICardStyle
    public var headerAction: AnyView?
    public var footerContent: AnyView?
    private let content: Content
    @Theme private var theme
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric private var lineTrim = 2.0
    public init(_ title: String? = nil, description: String? = nil, footer: String? = nil, footnote: String? = nil, footerIcon: AIIconName? = nil,
                style: AICardStyle = .standard, headerAction: AnyView? = nil, footerContent: AnyView? = nil,
                @ViewBuilder content: () -> Content) {
        self.title = title; self.description = description; self.footer = footer; self.footnote = footnote; self.footerIcon = footerIcon
        self.style = style; self.headerAction = headerAction; self.footerContent = footerContent
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: style == .chart ? 24 : 16) {
            if title != nil || description != nil || headerAction != nil {
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: style == .chart ? 8 : 4) {
                        if let title {
                            AITextLabel(title, size: 16, weight: style == .chart ? .semibold : .medium)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, style == .chart ? -lineTrim - 1 : 1)
                        }
                        if let description { NativeTextParagraph(verbatim: description).environment(\.aiParagraphLineHeight, 20).environment(\.aiParagraphMuted, true) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    headerAction
                }.padding(.horizontal, inset)
            }
            content.padding(.horizontal, inset)
            if footer != nil || footnote != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let footer { HStack(spacing: 8) {
                        AITextLabel(footer, weight: .medium).fixedSize(horizontal: false, vertical: true).padding(.vertical, -lineTrim)
                        if let footerIcon { AIIcon(footerIcon, size: 16) }
                    } }
                    if let footnote { NativeTextParagraph(verbatim: footnote).environment(\.aiParagraphLineHeight, 14).environment(\.aiParagraphMuted, true) }
                }.padding(.horizontal, inset)
            }
            if let footerContent {
                footerContent.padding(inset).frame(maxWidth: .infinity)
                    .background(theme.muted.opacity(0.5))
                    .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, inset).padding(.bottom, footerContent == nil ? inset : 0)
            .foregroundStyle(theme.foreground)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))
    }
    private var inset: CGFloat { style == .chart ? 25 : 16 }
}

public enum AIFoundationVariant: String, CaseIterable, Sendable { case primary, secondary, outline, ghost, destructive }
public struct AIFoundationButtonStyle: ButtonStyle {
    public var variant: AIFoundationVariant
    public init(_ variant: AIFoundationVariant = .primary) { self.variant = variant }
    public func makeBody(configuration: Configuration) -> some View {
        FoundationButtonBody(label: configuration.label, variant: variant, pressed: configuration.isPressed)
    }
}
private struct FoundationButtonBody<Label: View>: View {
    var label: Label; var variant: AIFoundationVariant; var pressed: Bool
    @Theme private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @ScaledMetric private var scale = 1.0
    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme
    var fill: Color {
        switch variant {
        case .primary: theme.primaryButtonFill ?? theme.foreground
        case .secondary: theme.muted
        case .destructive: theme.destructive.opacity(scheme == .dark ? 0.2 : 0.1)
        case .outline: hovered ? theme.muted : scheme == .dark ? Color.white.opacity(0.045) : theme.background
        case .ghost: hovered ? theme.muted : .clear
        }
    }
    var body: some View {
        label.aiFont(14, weight: .medium).padding(.horizontal, 11).frame(minHeight: 32 * scale)
            .foregroundStyle(variant == .primary ? (theme.primaryButtonLabel ?? theme.background) : variant == .destructive ? theme.destructive : theme.foreground)
            .background { RoundedRectangle(cornerRadius: 9).fill(fill).padding(1) }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focused ? theme.mutedForeground : variant == .outline ? theme.border : .clear, lineWidth: focused ? 2 : 1))
            .aiHitTarget().opacity(enabled ? pressed ? 0.8 : 1 : 0.5).onHover { hovered = $0 }
    }
}

public struct AIProgress: View {
    public var value: Double
    public var total: Double
    public var label: String?
    @Theme private var theme
    public init(value: Double, total: Double = 100, label: String? = nil) { self.value = value; self.total = total; self.label = label }
    private var fraction: Double { value.isFinite && total.isFinite && total > 0 ? min(1, max(0, value / total)) : 0 }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { Text(label).aiFont(14, weight: .medium) }
            GeometryReader { proxy in
                Capsule().fill(theme.muted).overlay(alignment: .leading) {
                    Rectangle().fill(theme.foreground).frame(width: proxy.size.width * fraction)
                }.clipShape(Capsule())
            }.frame(height: 4)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label ?? "Progress")
            .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

public struct AIInput: View {
    public var label: String
    public var placeholder: String
    @Binding public var text: String
    @Theme private var theme
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme
    public var secure: Bool
    public var labelAccessory: AnyView?
    public init(_ label: String, text: Binding<String>, placeholder: String = "", secure: Bool = false, labelAccessory: AnyView? = nil) { self.label = label; self._text = text; self.placeholder = placeholder; self.secure = secure; self.labelAccessory = labelAccessory }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty || labelAccessory != nil {
                HStack {
                    AITextLabel(label, weight: .medium).padding(.vertical, -2)
                    if let labelAccessory { Spacer(); labelAccessory }
                }
            }
            Group {
                if secure { SecureField("", text: $text) }
                else { TextField("", text: $text) }
            }.textFieldStyle(.plain).aiFont().focused($focused)
                .overlay(alignment: .leading) {
                    if text.isEmpty { AITextLabel(placeholder, color: theme.mutedForeground).allowsHitTesting(false).accessibilityHidden(true) }
                }
                .padding(.horizontal, 11).frame(minHeight: 32)
                .background(scheme == .dark ? Color.white.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focused ? theme.mutedForeground : scheme == .dark ? .white.opacity(0.15) : theme.border, lineWidth: focused ? 2 : 1))
                .aiHitTarget().onTapGesture { focused = true }.accessibilityLabel(label.isEmpty ? placeholder : label)
        }.foregroundStyle(theme.foreground)
    }
}

public struct AISwitch: View {
    public var label: String
    @Binding public var isOn: Bool
    @Theme private var theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    public init(_ label: String, isOn: Binding<Bool>) { self.label = label; self._isOn = isOn }
    public var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                Capsule().fill(isOn ? (theme.primaryButtonFill ?? theme.foreground) : scheme == .dark ? Color.white.opacity(0.12) : theme.border).frame(width: 32, height: 18.4)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(scheme == .dark ? (isOn ? (theme.primaryButtonLabel ?? theme.background) : theme.foreground) : theme.background).frame(width: 16, height: 16).padding(1)
                    }
                AITextLabel(label, weight: .medium)
            }.foregroundStyle(theme.foreground).aiHitTarget()
        }.buttonStyle(.plain).opacity(enabled ? 1 : 0.5)
            .accessibilityLabel(label).accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

public struct AISelectOption: Identifiable, Sendable {
    public var id: String
    public var label: String
    public init(_ id: String, label: String) { self.id = id; self.label = label }
}
public struct AISelect: View {
    public var label: String
    public var options: [AISelectOption]
    @Binding public var selection: String
    public var placeholder: String
    @Environment(\.colorScheme) private var scheme
    @Theme private var theme
    public init(_ label: String, options: [AISelectOption], selection: Binding<String>, placeholder: String = "Select…") {
        self.label = label; self.options = options; self._selection = selection; self.placeholder = placeholder
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty { AITextLabel(label, weight: .medium).padding(.vertical, -2) }
            #if os(macOS)
            selectLabel.overlay {
                NativeChoiceMenu(label: label, choices: options.map { AIChoice(id: $0.id, title: $0.label) }, selected: selection) { selection = $0 }
            }.disabled(options.isEmpty)
            #else
            Menu {
                ForEach(options) { option in Button(option.label) { selection = option.id } }
            } label: { selectLabel }
                .buttonStyle(.plain).disabled(options.isEmpty)
                .accessibilityLabel(label).accessibilityValue(selectedLabel)
            #endif
        }.foregroundStyle(theme.foreground)
    }
    private var selectedLabel: String { options.first { $0.id == selection }?.label ?? placeholder }
    private var selectLabel: some View {
        HStack(spacing: 6) {
            AITextLabel(selectedLabel, color: selection.isEmpty ? theme.mutedForeground : theme.foreground)
            Spacer(minLength: 8)
            AIIcon(.chevronDown, size: 16).foregroundStyle(theme.mutedForeground)
        }.padding(.leading, 11).padding(.trailing, 9).frame(minHeight: 32)
            .background(scheme == .dark ? Color.white.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(scheme == .dark ? .white.opacity(0.15) : theme.border, lineWidth: 1))
            .aiHitTarget()
    }

}
