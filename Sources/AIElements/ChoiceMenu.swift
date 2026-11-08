import SwiftUI
struct AIChoice { var id: String; var title: String; var group: String? = nil }
struct AIChoiceMenu: View {
    var title: String
    var accessibilityLabel: String
    var choices: [AIChoice]
    var selected: String
    var expandedLabel = false
    var prefix: String? = nil
    var onSelect: (String) -> Void
    @Theme private var theme
    @State private var hovered = false
    var body: some View {
        #if os(macOS)
        label.overlay { NativeChoiceMenu(label: accessibilityLabel, choices: choices, selected: selected, onSelect: onSelect) }
            .onHover { hovered = $0 }.aiHitTarget()
        #else
        if expandedLabel {
            label.aiHitTarget().accessibilityHidden(true).overlay {
                Menu { menuItems } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel(accessibilityLabel)
            }.disabled(choices.isEmpty)
        } else {
            Menu { menuItems } label: { label.aiHitTarget() }
                .buttonStyle(.plain).disabled(choices.isEmpty).accessibilityLabel(accessibilityLabel)
        }
        #endif
    }
    @ViewBuilder private var menuItems: some View {
        ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
            if let group = choice.group, index == 0 || choices[index - 1].group != group { Text(group) }
            Button { onSelect(choice.id) } label: {
                if selected == choice.id { Label(choice.title, systemImage: "checkmark") } else { Text(choice.title) }
            }
        }
    }
    private var label: some View {
        HStack(spacing: 8) {
            if let prefix { AITextLabel(prefix, weight: .medium, color: theme.mutedForeground) }
            AITextLabel(title, weight: .medium, color: theme.mutedForeground, lineLimit: expandedLabel ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
            AIIcon(.chevronDown, size: 16)
        }
            .aiFont(14, weight: .medium).padding(.horizontal, 13).frame(minHeight: 32)
            .foregroundStyle(theme.mutedForeground).background(hovered ? theme.muted : theme.outlineButtonFill ?? theme.background, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
            .clipShape(Capsule())
    }
}
#if os(macOS)
import AppKit
private struct NativeChoiceMenu: NSViewRepresentable {
    var label: String
    var choices: [AIChoice]
    var selected: String
    var onSelect: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.isTransparent = true; button.isBordered = false; button.focusRingType = .exterior
        button.setAccessibilityRole(.popUpButton)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self; button.isEnabled = !choices.isEmpty
        button.setAccessibilityLabel(label); button.setAccessibilityValue(choices.first { $0.id == selected }?.title)
    }
    final class Coordinator: NSObject {
        var parent: NativeChoiceMenu?
        @objc func open(_ sender: NSButton) {
            guard let parent else { return }
            let menu = NSMenu(); menu.autoenablesItems = false
            var previousGroup: String?, selectedItem: NSMenuItem?
            for choice in parent.choices {
                if let group = choice.group, previousGroup != group {
                    if previousGroup != nil { menu.addItem(.separator()) }
                    let header = NSMenuItem(title: group, action: nil, keyEquivalent: ""); header.isEnabled = false; menu.addItem(header); previousGroup = group
                }
                let item = NSMenuItem(title: choice.title, action: #selector(choose(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = choice.id; item.state = choice.id == parent.selected ? .on : .off
                menu.addItem(item); if choice.id == parent.selected { selectedItem = item }
            }
            menu.popUp(positioning: selectedItem, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
        }
        @objc func choose(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { parent?.onSelect(id) } }
    }
}
#endif
