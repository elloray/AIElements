@_exported import AIElementsCatalog
import SwiftUI

/// Renders a composable shadcn control. Supply values to own its state, or omit them for local state.
/// Actions report the stable component ID (or its structural path) and the activated item / new value.
public struct AIShadcnView: View {
  private let images: (String) -> Image?
  public var node: AIShadcnNode
  private var controlled: Binding<[String: String]>?
  private var onAction: (String, String) -> Void
  @State private var local: [String: String] = [:]

  public init(
    _ node: AIShadcnNode, values: Binding<[String: String]>? = nil,
    images: @escaping (String) -> Image? = { _ in nil },
    onAction: @escaping (String, String) -> Void = { _, _ in }
  ) {
    self.images = images
    self.node = node
    self.controlled = values
    self.onAction = onAction
  }
  public var body: some View {
    ShadcnPart(
      node: node, path: node.id ?? node.kind.rawValue, values: controlled ?? $local,
      action: onAction
    ).id(node.kind).id(node.id ?? node.kind.rawValue).environment(\.shadcnImages, images)
  }
}

private struct ShadcnImageKey: EnvironmentKey {
  static let defaultValue: (String) -> Image? = { _ in nil }
}
extension EnvironmentValues {
  fileprivate var shadcnImages: (String) -> Image? {
    get { self[ShadcnImageKey.self] }
    set { self[ShadcnImageKey.self] = newValue }
  }
}
struct ShadcnPart: View {
  @Environment(\.shadcnImages) private var suppliedImage
  let node: AIShadcnNode
  let path: String
  @Binding var values: [String: String]
  let action: (String, String) -> Void
  @Theme var theme
  @Environment(\.colorScheme) var scheme
  @Environment(\.layoutDirection) var direction
  @Environment(\.aiControlDensity) var density
  @ScaledMetric(relativeTo: .body) private var sourceLineHeight: CGFloat = 22.75
  @State var showing = false
  @State var query = ""
  @FocusState var focused: Bool
  @State var page = 0
  @State var month = Date()
  @State var sortColumn: Int?
  @State var ascending = true
  @State var requiredError = false
  @State var toastRevision = 0
  @State var notices: [UUID] = []

  var label: String { node.label ?? "" }
  var detail: String { node.detail ?? "" }
  var items: [AIShadcnItem] { node.items ?? [] }
  var children: [AIShadcnNode] { node.children ?? [] }
  var primary: Color { theme.primaryButtonFill ?? theme.foreground }
  var onPrimary: Color { theme.primaryButtonLabel ?? theme.background }
  var fieldBorder: Color { scheme == .dark ? .white.opacity(0.15) : theme.border }
  var fieldFill: Color { scheme == .dark ? .white.opacity(0.045) : .clear }
  var isOn: Bool { value == "true" }
  var value: String { values[path] ?? node.value ?? "" }
  func set(_ newValue: String) {
    values[path] = newValue
    action(path, newValue)
  }
  func activate(_ name: String) { action(path, name) }
  var binding: Binding<String> { Binding(get: { value }, set: set) }
  var boolBinding: Binding<Bool> { Binding(get: { isOn }, set: { set(String($0)) }) }
  func child(_ index: Int) -> AnyView {
    let item = children[index]
    return AnyView(
      ShadcnPart(node: item, path: childID(index), values: $values, action: action)
        .id(item.kind).id(childID(index)))
  }
  var parts: some View {
    ForEach(children.indices.map { (key: childID($0), index: $0) }, id: \.key) { entry in
      child(entry.index)
    }
  }
  private func childID(_ index: Int) -> String { children[index].id ?? "\(path)/\(index)" }

  var body: some View {
    component.font(AITypography.font()).foregroundStyle(theme.foreground)
      .modifier(ShadcnWidth(width: node.width))
  }

  @ViewBuilder private var component: some View {
    switch node.kind {
    case .column:
      VStack(alignment: node.align == "center" ? .center : .leading, spacing: node.gap ?? 8) {
        parts
      }
    case .row:
      AIFlowLayout(spacing: node.gap ?? 8, fitsContent: true) { parts }.fixedSize(
        horizontal: false, vertical: true)
    case .text, .typography: typography
    case .image:
      sampleImage(node.value ?? "").overlay {
        if value == "shadcn-aspect" && scheme == .dark { Color.black.opacity(0.8) }
      }.accessibilityLabel(label)
    case .accordion: accordion
    case .alert, .item, .attachment: information
    case .aspectRatio:
      Color.clear.aspectRatio(max(0.01, Double(value) ?? 16 / 9), contentMode: .fit)
        .overlay { parts }.clipShape(RoundedRectangle(cornerRadius: 10))
    case .avatar: avatar
    case .badge: badge
    case .bubble, .message, .marker: messageContent
    case .button: button(label, variant: node.variant ?? "primary") { activate(label) }
    case .buttonGroup, .toggleGroup, .tabs, .pagination, .breadcrumb: segmented
    case .calendar: calendarPage
    case .card: card
    case .carousel: carousel
    case .chart: chart
    case .checkbox: check(label, checked: isOn, radio: false) { set(String(!isOn)) }
    case .codeBlock:
      if node.action != nil {
        AICodeBlock(value, showCopy: true, showsWrapControl: false)
      } else {
        ScrollView(.horizontal) {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(value.components(separatedBy: "\n").enumerated()), id: \.offset) {
              _, line in
              Text(verbatim: line.isEmpty ? " " : line).aiFont(14, mono: true)
                .fixedSize().frame(minHeight: sourceLineHeight, alignment: .leading)
            }
          }.textSelection(.enabled).padding(16)
        }.scrollIndicators(.hidden).background(theme.muted, in: RoundedRectangle(cornerRadius: 14))
          .accessibilityElement(children: .ignore).accessibilityLabel(value)
      }
    case .collapsible: collapsible
    case .combobox, .command, .contextMenu, .dropdownMenu, .nativeSelect: choiceControl
    case .dataTable, .table: tabular
    case .datePicker, .alertDialog, .dialog, .drawer, .sheet, .popover, .hoverCard, .tooltip,
      .toast:
      overlayControl
    case .sonner: sonner
    case .direction:
      let language = items.firstIndex { $0.key == value } ?? 0
      VStack(alignment: .trailing, spacing: 6) {
        if node.variant == "picker" && !items.isEmpty {
          Menu(items[language].label) {
            ForEach(items, id: \.key) { item in Button(item.label) { set(item.key) } }
          }
          .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(label)
        }
        if !items.isEmpty && children.indices.contains(language) {
          child(language).environment(
            \.layoutDirection, items[language].detail == "rtl" ? .rightToLeft : .leftToRight)
        } else {
          Group { parts }.environment(
            \.layoutDirection, value == "rtl" ? .rightToLeft : .leftToRight)
        }
      }
    case .empty: emptyState
    case .field, .label, .input, .inputGroup, .inputOtp, .radioGroup, .slider, .textarea, .toggle:
      formControl
    case .kbd:
      Text(label).aiFont(12, weight: .medium).foregroundStyle(theme.mutedForeground)
        .padding(.horizontal, 4).frame(minWidth: 20, minHeight: 20).background(
          theme.muted, in: RoundedRectangle(cornerRadius: 5))
    case .menubar, .navigationMenu, .sidebar: navigation
    case .messageScroller:
      AIConversation(
        revision: children, initialScrollToBottom: node.align != "start", contentInset: 0
      ) {
        VStack(alignment: .leading, spacing: 16) { parts }.padding(20)
      }.frame(height: node.height ?? 320)
    case .progress: AIProgress(value: Double(value) ?? 0, label: node.label)
    case .questionnaire: questionnaire
    case .resizable: resizable
    case .scrollArea: scrollArea
    case .select:
      AISelect(
        label, options: items.map { .init($0.key, label: $0.label, disabled: $0.disabled == true) },
        selection: binding,
        placeholder: node.placeholder ?? "Select…")
    case .separator: Rectangle().fill(theme.border).frame(height: 1)
    case .skeleton:
      RoundedRectangle(cornerRadius: 6).fill(theme.muted).frame(height: node.height ?? 16).modifier(
        ShadcnPulse())
    case .spinner: spinner
    case .switchControl: AISwitch(label, isOn: boolBinding)
    case .trace: AITrace { AITraceLine(label, icon: iconName(node.icon), detail: node.detail) }
    }
  }

  func iconName(_ name: String?) -> AIIconName {
    name.flatMap(AIIconName.init(rawValue:)) ?? .circle
  }
  func icon(_ name: String?, _ size: CGFloat = 16) -> some View {
    AIIcon(iconName(name), size: size)
  }
  func button(_ text: String, variant: String = "outline", action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) { Text(text) }.buttonStyle(
      AIFoundationButtonStyle(AIFoundationVariant(rawValue: variant) ?? .outline))
  }
  @ViewBuilder func sampleImage(_ name: String) -> some View {
    if let image = suppliedImage(name) {
      image.resizable().scaledToFill()
    } else if let url = Bundle.module.url(forResource: name, withExtension: "png") {
      #if os(macOS)
        if let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().scaledToFill() }
      #else
        if let image = UIImage(contentsOfFile: url.path) {
          Image(uiImage: image).resizable().scaledToFill()
        }
      #endif
    }
  }
}

struct ShadcnWidth: ViewModifier {
  var width: Double?
  @ViewBuilder func body(content: Content) -> some View {
    if let width {
      content.frame(maxWidth: .infinity, alignment: .leading).frame(maxWidth: max(1, width))
    } else {
      content
    }
  }
}

private struct ShadcnBubbleWidth: ViewModifier {
  var fraction: CGFloat
  var trailing: Bool
  func body(content: Content) -> some View {
    AIAlignedWidthLayout(fraction: fraction, trailing: trailing) { content }
  }
}

private struct ShadcnPulse: ViewModifier {
  @Environment(\.accessibilityReduceMotion) var reduce
  @Environment(\.aiAnimationsActive) var animations
  func body(content: Content) -> some View {
    TimelineView(.animation(minimumInterval: 1 / 24, paused: reduce || !animations)) { t in
      content.opacity(
        reduce || !animations ? 1 : 0.75 + 0.25 * cos(t.date.timeIntervalSinceReferenceDate * .pi))
    }.accessibilityHidden(true)
  }
}

extension ShadcnPart {
  var typography: some View {
    let sizes = [
      "h1": 36.0, "h2": 30, "h3": 24, "h4": 20, "lead": 20, "large": 18, "small": 14, "muted": 14,
      "code": 14,
    ]
    let v = node.variant ?? "body"
    return Text(label).aiFont(
      sizes[v] ?? 14,
      weight: v.hasPrefix("h") || ["large", "semibold"].contains(v)
        ? .semibold : ["label", "small"].contains(v) ? .medium : .regular, mono: v == "code"
    )
    .tracking(v.hasPrefix("h") ? -0.6 : 0)
    .foregroundStyle(["muted", "lead"].contains(v) ? theme.mutedForeground : theme.foreground)
    .fixedSize(horizontal: false, vertical: true)
  }

  var accordion: some View {
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.key) { i, item in
        let expanded = value == item.key
        Button {
          set(expanded ? "" : item.key)
        } label: {
          HStack {
            Text(item.label).aiFont(14, weight: .medium).multilineTextAlignment(.leading)
            Spacer()
            AIIcon(.chevronDown).rotationEffect(.degrees(expanded ? 180 : 0)).foregroundStyle(
              theme.mutedForeground)
          }.padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(item.disabled == true).accessibilityValue(
          expanded ? "Expanded" : "Collapsed")
        if expanded, let description = item.detail {
          Text(description).aiFont().frame(maxWidth: .infinity, alignment: .leading).fixedSize(
            horizontal: false, vertical: true
          ).padding(.bottom, 12)
        }
        if i < items.count - 1 { Rectangle().fill(theme.border).frame(height: 1) }
      }
    }
  }

  var collapsible: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        set(String(!isOn))
      } label: {
        HStack {
          Text(label).aiFont(14, weight: .medium)
          Spacer()
          AIIcon(.chevronDown).rotationEffect(.degrees(isOn ? 180 : 0))
        }
        .padding(8).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityValue(isOn ? "Expanded" : "Collapsed")
      if isOn {
        if !detail.isEmpty { Text(detail).padding(.horizontal, 8) }
        parts
        if let cmd = node.action { button(cmd, variant: "primary") { activate(cmd) }.padding(8) }
      }
    }.padding(16).shadcnBox(theme.cardBackground, stroke: theme.border, radius: 14)
  }

  var information: some View {
    let attachment = node.kind == .attachment
    let small = node.variant == "sm" || node.variant == "xs"
    return HStack(alignment: node.kind == .alert ? .top : .center, spacing: attachment ? 8 : 12) {
      if let name = node.icon {
        if attachment {
          icon(name, small ? 16 : 20).frame(width: small ? 28 : 36, height: small ? 28 : 36)
            .background(theme.muted, in: RoundedRectangle(cornerRadius: 6))
        } else {
          icon(name).padding(.top, node.kind == .alert ? 1 : 0)
        }
      }
      VStack(alignment: .leading, spacing: attachment ? 1 : 4) {
        Text(label).aiFont(attachment && small ? 12 : 14, weight: .medium)
        if !detail.isEmpty {
          Text(detail).aiFont(attachment ? 12 : 14).foregroundStyle(theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }
        parts
      }.frame(maxWidth: .infinity, alignment: .leading)
      if let cmd = node.action { button(cmd) { activate(cmd) } }
      if node.variant == "link" {
        Button {
          activate(label)
        } label: {
          AIIcon(.chevronRight)
        }.buttonStyle(.plain).accessibilityLabel(label)
      }
    }.padding(attachment ? (small ? 5 : 8) : 12).padding(.horizontal, node.kind == .alert ? 4 : 0)
      .shadcnBox(
        node.kind == .alert ? theme.cardBackground : theme.background, stroke: theme.border,
        radius: attachment ? 9 : 12)
  }

  var avatar: some View {
    ZStack {
      Circle().fill(theme.muted)
      Text(value).aiFont(14, weight: .medium)
      if let asset = node.asset { sampleImage(asset) }
    }.frame(width: node.size ?? 32, height: node.size ?? 32).clipShape(Circle()).accessibilityLabel(
      label)
  }

  var badge: some View {
    let variant = node.variant ?? "primary"
    let fill =
      variant == "primary"
      ? primary
      : variant == "secondary"
        ? theme.muted : variant == "destructive" ? theme.destructive.opacity(0.12) : .clear
    return Text(label).aiFont(12, weight: .medium).padding(.horizontal, 8).frame(minHeight: 20)
      .foregroundStyle(
        variant == "primary"
          ? onPrimary : variant == "destructive" ? theme.destructive : theme.foreground
      )
      .shadcnBox(fill, stroke: variant == "outline" ? theme.border : .clear, radius: 20)
  }

  @ViewBuilder var messageContent: some View {
    let end = node.align == "end"
    if node.kind == .marker {
      HStack(spacing: 8) {
        if node.variant == "separator" { Rectangle().fill(theme.border).frame(height: 1) }
        Text(label).aiFont(14).foregroundStyle(theme.mutedForeground).fixedSize(
          horizontal: false, vertical: true
        ).layoutPriority(1)
        if node.variant == "separator" { Rectangle().fill(theme.border).frame(height: 1) }
      }.frame(minHeight: 20)
    } else if node.kind == .message {
      VStack(alignment: end ? .trailing : .leading, spacing: 10) {
        if !label.isEmpty {
          Text(label).aiFont(12, weight: .medium).foregroundStyle(theme.mutedForeground)
            .frame(minHeight: 16).padding(.horizontal, 12)
        }
        parts
        if !detail.isEmpty {
          Text(detail).aiFont(12).foregroundStyle(theme.mutedForeground).frame(minHeight: 16)
            .padding(.horizontal, 12)
        }
      }.frame(maxWidth: .infinity, alignment: end ? .trailing : .leading)
    } else {
      let muted = node.variant == "muted" || node.variant == "secondary"
      let ghost = node.variant == "ghost"
      let blue =
        scheme == .dark
        ? Color(red: 25 / 255, green: 60 / 255, blue: 184 / 255)
        : Color(red: 20 / 255, green: 71 / 255, blue: 230 / 255)
      Text(label).aiFont(14).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, ghost ? 0 : 13).padding(.vertical, ghost ? 2 : 14)
        .foregroundStyle(muted || ghost ? theme.foreground : .white)
        .background(
          ghost ? .clear : muted ? theme.muted : blue, in: RoundedRectangle(cornerRadius: 24)
        )
        .modifier(ShadcnBubbleWidth(fraction: ghost ? 1 : 0.8, trailing: end))

    }
  }

  var card: some View {
    AICard(
      node.label, description: node.detail,
      headerAction: node.action.map { title in
        AnyView(button(title, variant: "ghost") { activate(title) })
      },
      footerContent: items.isEmpty
        ? nil
        : AnyView(
          VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.key) { i, item in
              Button {
                activate(item.key)
              } label: {
                Text(item.label).frame(maxWidth: .infinity)
              }.buttonStyle(AIFoundationButtonStyle(i == 0 ? .primary : .outline)).disabled(
                item.disabled == true)
            }
          })
    ) { VStack(alignment: .leading, spacing: 24) { parts } }
  }
  var emptyState: some View {
    VStack(spacing: 12) {
      if let name = node.icon {
        icon(name, 24).frame(width: 40, height: 40).background(
          theme.muted, in: RoundedRectangle(cornerRadius: 10))
      }
      Text(label).aiFont(18, weight: .medium)
      Text(detail).aiFont().foregroundStyle(theme.mutedForeground).multilineTextAlignment(.center)
      parts
      if let cmd = node.action { button(cmd) { activate(cmd) }.padding(.top, 8) }
    }.padding(24).frame(maxWidth: .infinity).overlay(
      RoundedRectangle(cornerRadius: 14).strokeBorder(
        theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
  }

  var spinner: some View {
    ShadcnSpinner(size: node.size ?? 16)
  }
}
private struct ShadcnSpinner: View {
  var size: CGFloat
  @Environment(\.aiAnimationsActive) var active
  @Environment(\.accessibilityReduceMotion) var reduce
  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !active || reduce)) { t in
      AIIcon(.loaderCircle, size: size).rotationEffect(
        .degrees(
          active && !reduce
            ? t.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360 : 0))
    }.accessibilityElement(children: .ignore).accessibilityLabel("Loading")
  }
}

extension View {
  func shadcnBox(_ color: Color, stroke: Color, radius: CGFloat) -> some View {
    background(color, in: RoundedRectangle(cornerRadius: radius)).overlay(
      RoundedRectangle(cornerRadius: radius).strokeBorder(stroke, lineWidth: 1))
  }
}
