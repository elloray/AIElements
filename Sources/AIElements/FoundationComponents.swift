import SwiftUI

/// shadcn/ui Card geometry; distinct from the compact AI Elements trace surfaces.
public struct AICard<Content: View>: View {
    public var title: String?
    public var description: String?
    public var footer: String?
    public var footnote: String?
    public var footerIcon: AIIconName?
    private let content: Content
    @Theme private var theme
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric private var lineTrim = 2.0
    public init(_ title: String? = nil, description: String? = nil, footer: String? = nil, footnote: String? = nil, footerIcon: AIIconName? = nil,
                @ViewBuilder content: () -> Content) {
        self.title = title; self.description = description; self.footer = footer; self.footnote = footnote; self.footerIcon = footerIcon
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if title != nil || description != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let title { AITextLabel(title, size: 16, weight: .semibold).fixedSize(horizontal: false, vertical: true).padding(.vertical, -lineTrim) }
                    if let description { NativeTextParagraph(verbatim: description).environment(\.aiParagraphLineHeight, 20).environment(\.aiParagraphMuted, true) }
                }
            }
            content
            if footer != nil || footnote != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let footer { HStack(spacing: 8) {
                        AITextLabel(footer, weight: .medium).fixedSize(horizontal: false, vertical: true).padding(.vertical, -lineTrim)
                        if let footerIcon { AIIcon(footerIcon, size: 16) }
                    } }
                    if let footnote { NativeTextParagraph(verbatim: footnote).environment(\.aiParagraphLineHeight, 14).environment(\.aiParagraphMuted, true) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).padding(1)
            .foregroundStyle(theme.foreground)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))
    }
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
    var fill: Color {
        switch variant {
        case .primary: theme.primaryButtonFill ?? theme.foreground
        case .secondary: theme.muted
        case .destructive: theme.destructive
        case .outline: hovered ? theme.muted : theme.background
        case .ghost: hovered ? theme.muted : .clear
        }
    }
    var body: some View {
        label.aiFont(14, weight: .medium).padding(.horizontal, 16).frame(minHeight: 36 * scale)
            .foregroundStyle(variant == .primary ? (theme.primaryButtonLabel ?? theme.background) : variant == .destructive ? Color.white : theme.foreground)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? theme.mutedForeground : variant == .outline ? theme.border : .clear, lineWidth: focused ? 2 : 1))
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
                Capsule().fill(theme.foreground.opacity(0.2)).overlay(alignment: .leading) {
                    Rectangle().fill(theme.foreground).frame(width: proxy.size.width * fraction)
                }.clipShape(Capsule())
            }.frame(height: 8)
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
    public init(_ label: String, text: Binding<String>, placeholder: String = "") { self.label = label; self._text = text; self.placeholder = placeholder }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).aiFont(14, weight: .medium)
            TextField(placeholder, text: $text).textFieldStyle(.plain).aiFont().focused($focused)
                .padding(.horizontal, 12).frame(minHeight: 36)
                .background(theme.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? theme.mutedForeground : theme.border, lineWidth: focused ? 2 : 1))
                .aiHitTarget().onTapGesture { focused = true }.accessibilityLabel(label)
        }.foregroundStyle(theme.foreground)
    }
}

public struct AISwitch: View {
    public var label: String
    @Binding public var isOn: Bool
    @Theme private var theme
    @Environment(\.isEnabled) private var enabled
    public init(_ label: String, isOn: Binding<Bool>) { self.label = label; self._isOn = isOn }
    public var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                Capsule().fill(isOn ? theme.foreground : theme.border).frame(width: 32, height: 18)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(theme.background).frame(width: 14, height: 14).padding(2)
                    }
                Text(label).aiFont(14, weight: .medium)
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
    @Theme private var theme
    public init(_ label: String, options: [AISelectOption], selection: Binding<String>) {
        self.label = label; self.options = options; self._selection = selection
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).aiFont(14, weight: .medium)
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
    private var selectedLabel: String { options.first { $0.id == selection }?.label ?? "Select…" }
    private var selectLabel: some View {
        HStack(spacing: 8) {
            AITextLabel(selectedLabel)
            Spacer(minLength: 8)
            AIIcon(.chevronsUpDown, size: 16).foregroundStyle(theme.mutedForeground)
        }.padding(.horizontal, 12).frame(minHeight: 36)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border, lineWidth: 1))
            .aiHitTarget()
    }

}
