import SwiftUI

extension ShadcnPart {
  @ViewBuilder var formControl: some View {
    switch node.kind {
    case .checkbox: check(label, checked: isOn, radio: false) { set(String(!isOn)) }
    case .label:
      if children.first?.kind == .checkbox {
        let key = children[0].id ?? "\(path)/0"
        check(label, checked: (values[key] ?? children[0].value) == "true", radio: false) {
          let next = String((values[key] ?? children[0].value) != "true")
          values[key] = next
          action(key, next)
        }
      } else {
        HStack(spacing: 8) {
          parts
          Text(label).aiFont(14, weight: .medium)
        }
      }
    case .field:
      VStack(alignment: .leading, spacing: 6) {
        Text(label).aiFont(14, weight: .medium)
        if node.variant == "description-first" { hint }
        parts
        if node.variant != "description-first" { hint }
      }
    case .input:
      AIInput(
        label, text: binding, placeholder: node.placeholder ?? "",
        secure: node.variant == "password",
        labelAccessory: node.action.map { title in
          AnyView(Button(title) { activate(title) }.buttonStyle(.plain))
        })
    case .inputGroup:
      HStack(spacing: 8) {
        icon(node.icon ?? "search").foregroundStyle(theme.mutedForeground)
        TextField(
          label, text: binding,
          prompt: Text(node.placeholder ?? label).foregroundColor(theme.mutedForeground)
        ).textFieldStyle(.plain).focused($focused)
        parts
      }.padding(.horizontal, 10).frame(minHeight: 32).shadcnBox(
        fieldFill, stroke: focused ? theme.mutedForeground : fieldBorder, radius: 10)
    case .textarea:
      TextField(
        label, text: binding,
        prompt: Text(node.placeholder ?? label).foregroundColor(theme.mutedForeground),
        axis: .vertical
      ).lineLimit(2...12)
        .textFieldStyle(.plain).focused($focused).padding(.horizontal, 11).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .shadcnBox(fieldFill, stroke: focused ? theme.mutedForeground : fieldBorder, radius: 10)
    case .inputOtp: otp
    case .radioGroup: radioGroup
    case .slider:
      GeometryReader { g in
        let width = max(1, g.size.width - 12)
        let percentage = min(100, max(0, Double(value) ?? 0)) / 100
        ZStack(alignment: .leading) {
          Capsule().fill(theme.muted).frame(height: 4)
          Capsule().fill(primary).frame(width: width * percentage + 6, height: 4)
          Circle().fill(theme.background).overlay(
            Circle().strokeBorder(theme.mutedForeground.opacity(0.55), lineWidth: 1)
          )
          .frame(width: 12, height: 12).offset(x: width * percentage)
        }.frame(maxHeight: .infinity).contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0).onChanged { event in
              let x = direction == .rightToLeft ? g.size.width - event.location.x : event.location.x
              set(String(Int((min(1, max(0, (x - 6) / width)) * 100).rounded())))
            })
      }.frame(height: 32).accessibilityElement(children: .ignore).accessibilityLabel(
        label.isEmpty ? "Slider" : label
      )
      .accessibilityValue(value).accessibilityAdjustableAction { step in
        set(String(min(100, max(0, (Int(value) ?? 0) + (step == .increment ? 1 : -1)))))
      }
    case .toggle:
      Button {
        set(String(!isOn))
      } label: {
        HStack(spacing: 6) {
          if let name = node.icon { icon(name, 14) }
          Text(label).aiFont(14, weight: .medium)
        }
        .padding(.horizontal, 8).frame(minHeight: 28)
        .shadcnBox(
          isOn ? theme.muted : .clear, stroke: node.variant == "outline" ? fieldBorder : .clear,
          radius: 8)
      }.buttonStyle(.plain).aiHitTarget().accessibilityAddTraits(isOn ? .isSelected : [])
    default: EmptyView()
    }
  }

  var hint: some View {
    Text(detail).aiFont(14).foregroundStyle(theme.mutedForeground).fixedSize(
      horizontal: false, vertical: true)
  }

  func check(
    _ title: String, checked: Bool, radio: Bool, description: String? = nil, index: Int = 0,
    count: Int = 1,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: radio ? 12 : 8) {
        if radio {
          Circle().fill(checked ? primary : fieldFill).overlay(
            Circle().strokeBorder(checked ? primary : fieldBorder, lineWidth: 1)
          )
          .frame(width: 16, height: 16).overlay {
            if checked { Circle().fill(onPrimary).frame(width: 6, height: 6) }
          }
        } else {
          RoundedRectangle(cornerRadius: 4).fill(checked ? primary : fieldFill)
            .overlay(
              RoundedRectangle(cornerRadius: 4).strokeBorder(
                checked ? primary : fieldBorder, lineWidth: 1)
            )
            .frame(width: 16, height: 16).overlay {
              if checked { AIIcon(.check, size: 14).foregroundStyle(onPrimary) }
            }
        }
        if !title.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(title).aiFont(14, weight: .medium)
            if let description {
              Text(description).aiFont(14).foregroundStyle(theme.mutedForeground)
            }
          }
        }
      }.modifier(AIListRowTarget(index: index, count: count))
    }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(
      checked ? "Selected" : "Unselected"
    )
    .accessibilityAddTraits(checked ? .isSelected : [])
  }

  var radioGroup: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !label.isEmpty { Text(label).aiFont(16, weight: .semibold) }
      if !detail.isEmpty { hint }
      VStack(alignment: .leading, spacing: density == .comfortable ? 0 : 8) {
        ForEach(Array(items.enumerated()), id: \.element.key) { index, item in
          check(
            item.label, checked: value == item.key, radio: true, description: item.detail,
            index: index, count: items.count
          ) { set(item.key) }
          .disabled(item.disabled == true)
        }
      }
    }
  }

  private var otp: some View {
    let count = max(1, min(32, Int(node.size ?? 6)))
    let characters = Array(value.prefix(count))
    return ZStack {
      HStack(spacing: 0) {
        ForEach(0..<count, id: \.self) { index in
          ZStack {
            Text(index < characters.count ? String(characters[index]) : " ").aiFont(14)
            if focused && index == min(characters.count, count - 1) {
              Rectangle().stroke(theme.mutedForeground, lineWidth: 2)
            }
          }.frame(width: 32, height: 36).overlay(alignment: .leading) {
            if index > 0 { Rectangle().fill(fieldBorder).frame(width: 1) }
          }
        }
      }.shadcnBox(fieldFill, stroke: fieldBorder, radius: 10).accessibilityHidden(true)
      TextField(
        label,
        text: Binding(get: { value }, set: { set(String($0.filter(\.isNumber).prefix(count))) })
      )
      .textFieldStyle(.plain).focused($focused).foregroundStyle(.clear).tint(.clear).opacity(0.02)
      .textContentType(.oneTimeCode).frame(width: CGFloat(count) * 32, height: 36)
      #if os(iOS)
        .keyboardType(.numberPad)
      #endif
    }.contentShape(Rectangle()).onTapGesture { focused = true }
  }

  private func segmentActive(_ item: AIShadcnItem) -> Bool {
    if node.kind == .toggleGroup && node.variant == "multiple" {
      return values["\(path)/\(item.key)"] == "true"
    }
    return (value.isEmpty ? items.first?.key : value) == item.key
  }

  var segmented: some View {
    let group = node.kind == .buttonGroup || node.kind == .toggleGroup
    let separate = node.kind == .toggleGroup && node.variant == "multiple"
    let crumbs = node.kind == .breadcrumb
    let tabs = node.kind == .tabs
    let paged = node.kind == .pagination
    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: crumbs || separate ? 8 : paged ? 4 : tabs ? 6 : 0) {
        ForEach(Array(items.enumerated()), id: \.element.key) { i, item in
          let selected = segmentActive(item) && node.kind != .buttonGroup
          if crumbs && i > 0 {
            AIIcon(.chevronRight, size: 12).foregroundStyle(theme.mutedForeground)
          }
          if group && !separate && i > 0 {
            Rectangle().fill(theme.border).frame(width: 1, height: 28)
          }
          Button {
            if node.kind == .buttonGroup || crumbs {
              if !crumbs || i < items.count - 1 { activate(item.key) }
            } else if node.kind == .toggleGroup && node.variant == "multiple" {
              let key = "\(path)/\(item.key)"
              values[key] = String(!selected)
              action(key, String(!selected))
            } else {
              set(item.key)
            }
          } label: {
            Group {
              if let glyph = item.icon {
                icon(glyph, 16)
              } else {
                Text(item.label).aiFont(14, weight: crumbs ? .regular : .medium)
              }
            }.padding(.horizontal, crumbs ? 0 : 8).frame(
              minWidth: group || paged ? 32 : nil, minHeight: crumbs ? 20 : 32
            )
            .foregroundStyle(
              crumbs && i < items.count - 1 || tabs && !selected
                ? theme.mutedForeground : theme.foreground
            )
            .background(
              selected && (group || tabs && node.variant != "line") ? theme.muted : .clear
            )
            .overlay(alignment: .bottom) {
              if tabs && selected && node.variant == "line" {
                Capsule().fill(theme.foreground).frame(height: 2)
              }
            }
            .overlay {
              if separate || paged && selected {
                RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border)
              }
            }
            .contentShape(Rectangle())
          }.buttonStyle(.plain).disabled(item.disabled == true || crumbs && i == items.count - 1)
            .accessibilityLabel(item.label).accessibilityAddTraits(
              selected && !crumbs ? .isSelected : [])
        }
      }.shadcnBox(
        group && node.variant == "secondary" ? theme.muted : .clear,
        stroke: group && !separate && node.variant != "secondary" ? fieldBorder : .clear, radius: 9)
      if tabs, let i = items.firstIndex(where: segmentActive), children.indices.contains(i) {
        child(i)
      }
    }
  }

  @ViewBuilder var choiceControl: some View {
    switch node.kind {
    case .contextMenu:
      Text(label).frame(maxWidth: .infinity, minHeight: node.height ?? 160)
        .overlay(
          RoundedRectangle(cornerRadius: 12).strokeBorder(
            theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .contentShape(Rectangle()).contextMenu { choiceItems }
        .accessibilityAction(named: "Show menu") { showing = true }.popover(isPresented: $showing) {
          pickerList
        }
    case .combobox:
      HStack(spacing: 4) {
        TextField(
          node.placeholder ?? label,
          text: Binding(
            get: { focused ? query : (items.first { $0.key == value }?.label ?? query) },
            set: {
              query = $0
              showing = true
            })
        )
        .textFieldStyle(.plain).focused($focused).onSubmit {
          if let first = matches.first(where: { $0.disabled != true }) { choose(first) }
        }
        Button {
          query = ""
          showing.toggle()
        } label: {
          AIIcon(.chevronDown, size: 16)
        }.buttonStyle(.plain).accessibilityLabel("Show choices")
      }.padding(.horizontal, 10).frame(minHeight: 32).shadcnBox(
        fieldFill, stroke: fieldBorder, radius: 10
      )
      .onChange(of: focused) { _, active in
        if active {
          query = ""
          showing = true
        }
      }
      .popover(isPresented: $showing) { pickerList.presentationCompactAdaptation(.popover) }
    case .command:
      button(label) {
        query = ""
        showing = true
      }.sheet(isPresented: $showing) {
        VStack(spacing: 12) {
          AIInput("", text: $query, placeholder: node.placeholder ?? "Search")
          pickerList
          button("Close") { showing = false }
        }.padding(16).frame(idealWidth: 360).presentationDetents([.medium]).aiFont()
      }
    case .nativeSelect:
      #if os(macOS)
        nativeSelectTrigger.overlay {
          NativeChoiceMenu(
            label: label.isEmpty ? node.placeholder ?? "Select" : label,
            choices: items.map {
              AIChoice(id: $0.key, title: $0.label, disabled: $0.disabled == true)
            },
            selected: value, onSelect: set)
        }
      #else
        Menu {
          choiceItems
        } label: {
          nativeSelectTrigger
        }
        .buttonStyle(.plain).disabled(items.isEmpty)
      #endif
    default:
      button(label, variant: node.variant ?? "outline") { showing = true }.popover(
        isPresented: $showing
      ) { pickerList.presentationCompactAdaptation(.popover) }
    }
  }

  private var nativeSelectTrigger: some View {
    HStack(spacing: 12) {
      Text(items.first { $0.key == value }?.label ?? node.placeholder ?? label)
      AIIcon(.chevronDown, size: 14).foregroundStyle(theme.mutedForeground)
    }.fixedSize().padding(.horizontal, 10).frame(minHeight: 32)
      .shadcnBox(fieldFill, stroke: fieldBorder, radius: 10).contentShape(Rectangle())
  }

  private var matches: [AIShadcnItem] {
    query.isEmpty ? items : items.filter { $0.label.localizedCaseInsensitiveContains(query) }
  }
  private func choose(_ item: AIShadcnItem) {
    set(item.key)
    showing = false
    focused = false
    query = ""
  }
  @ViewBuilder var choiceItems: some View {
    ForEach(items, id: \.key) { item in
      Button(item.label) { choose(item) }.disabled(item.disabled == true)
    }
  }
  var pickerList: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let heading = node.heading {
        Text(heading).aiFont(12, weight: .medium).foregroundStyle(theme.mutedForeground).padding(6)
      }
      if matches.isEmpty { Text("No results found.").aiFont().padding(8) }
      ForEach(matches, id: \.key) { item in
        Button {
          choose(item)
        } label: {
          HStack {
            Text(item.label)
            Spacer()
            if value == item.key { AIIcon(.check, size: 14) }
          }
          .padding(.horizontal, 8).frame(minHeight: 28).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(item.disabled == true)
      }
    }.padding(4).frame(minWidth: 160).aiFont().foregroundStyle(theme.foreground).background(
      theme.cardBackground)
  }
}
