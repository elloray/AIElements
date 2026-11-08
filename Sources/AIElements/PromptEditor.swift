import SwiftUI
#if os(macOS)
import AppKit

struct AIPromptEditor: NSViewRepresentable {
    @Binding var text: String
    var foreground: Color
    var onSend: () -> Void
    var onFocus: (Bool) -> Void
    var onFiles: ([URL]) -> Void
    var onImage: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let editor = PromptTextView()
        editor.isRichText = false; editor.drawsBackground = false; editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.textContainerInset = .zero; editor.textContainer?.lineFragmentPadding = 0
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.documentView = editor
        update(editor, context: context)
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) { context.coordinator.parent = self; if let editor = scroll.documentView as? PromptTextView { update(editor, context: context) } }
    private func update(_ editor: PromptTextView, context: Context) {
        if editor.string != text && !editor.hasMarkedText() { editor.string = text }
        _ = AITypography.font()
        editor.font = NSFont(name: "Geist-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 24; paragraph.maximumLineHeight = 24
        editor.defaultParagraphStyle = paragraph
        if !editor.hasMarkedText() { editor.textStorage?.addAttributes([.paragraphStyle: paragraph, .baselineOffset: 2], range: NSRange(location: 0, length: (editor.string as NSString).length)) }
        editor.typingAttributes[.paragraphStyle] = paragraph
        editor.typingAttributes[.baselineOffset] = 2
        editor.textColor = NSColor(foreground); editor.insertionPointColor = NSColor(foreground)
        editor.onSend = onSend; editor.onFocus = onFocus; editor.onFiles = onFiles; editor.onImage = onImage
        editor.setAccessibilityLabel("Message")
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, let editor = nsView.documentView as? NSTextView, let container = editor.textContainer, let manager = editor.layoutManager else { return nil }
        container.containerSize = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        return CGSize(width: width, height: min(160, max(40, manager.usedRect(for: container).height)))
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AIPromptEditor
        init(_ parent: AIPromptEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}
private final class PromptTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { super.draw(dirtyRect); return }
        context.saveGState(); context.setShouldSmoothFonts(false)
        super.draw(dirtyRect)
        context.restoreGState()
    }
    var onSend: () -> Void = {}
    var onFocus: (Bool) -> Void = { _ in }
    var onFiles: ([URL]) -> Void = { _ in }
    var onImage: (Data) -> Void = { _ in }
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onFocus(true) }; return result }
    override func resignFirstResponder() -> Bool { let result = super.resignFirstResponder(); if result { onFocus(false) }; return result }
    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 36 || event.keyCode == 76), !event.modifierFlags.contains(.shift), !hasMarkedText() { onSend(); return }
        super.keyDown(with: event)
    }
    override func paste(_ sender: Any?) {
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { onFiles(urls); return }
        if let data = NSPasteboard.general.data(forType: .png) { onImage(data); return }
        if let data = NSPasteboard.general.data(forType: .tiff), let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) { onImage(png); return }
        super.paste(sender)
    }
}
#else
import UIKit
struct AIPromptEditor: UIViewRepresentable {
    @Binding var text: String
    var foreground: Color
    var onSend: () -> Void
    var onFocus: (Bool) -> Void
    var onFiles: ([URL]) -> Void
    var onImage: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> PromptTextView {
        // TextKit 1 keeps baseline offsets independent of the line-fragment height.
        let view = PromptTextView(usingTextLayoutManager: false); view.delegate = context.coordinator; view.backgroundColor = .clear
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityLabel = "Message"; view.adjustsFontForContentSizeCategory = true
        return view
    }
    func updateUIView(_ view: PromptTextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text && view.markedTextRange == nil { view.text = text }
        _ = AITypography.font()
        view.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: "Geist-Regular", size: 16) ?? .systemFont(ofSize: 16))
        let paragraph = NSMutableParagraphStyle()
        // Keep the measured and rendered lines at the same 24pt rhythm.
        paragraph.minimumLineHeight = 24 * (view.font?.pointSize ?? 16) / 16
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        let baseline = 2 * (view.font?.pointSize ?? 16) / 16
        if view.markedTextRange == nil { view.textStorage.addAttributes([.paragraphStyle: paragraph, .baselineOffset: baseline], range: NSRange(location: 0, length: (view.text as NSString).length)) }
        view.typingAttributes[.paragraphStyle] = paragraph
        view.typingAttributes[.baselineOffset] = baseline
        view.textColor = UIColor(foreground); view.onSend = onSend; view.onFiles = onFiles; view.onImage = onImage
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PromptTextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: min(240, max(40, height)))
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AIPromptEditor
        init(_ parent: AIPromptEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onFocus(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onFocus(false) }
    }
}
final class PromptTextView: UITextView {
    var onSend: () -> Void = {}
    var onFiles: ([URL]) -> Void = { _ in }
    var onImage: (Data) -> Void = { _ in }
    override var keyCommands: [UIKeyCommand]? {
        guard markedTextRange == nil else { return super.keyCommands }
        return (super.keyCommands ?? []) + [UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(sendFromKeyboard))]
    }
    @objc private func sendFromKeyboard() { if markedTextRange == nil { onSend() } }
    override func paste(_ sender: Any?) {
        if !handlePaste(from: .general) { super.paste(sender) }
    }
    func handlePaste(from pasteboard: UIPasteboard) -> Bool {
        if let urls = pasteboard.urls, !urls.isEmpty {
            if urls.allSatisfy(\.isFileURL) { onFiles(urls) }
            else { insertText(pasteboard.string ?? urls.map(\.absoluteString).joined(separator: "\n")) }
            return true
        }
        if let data = pasteboard.image?.pngData() { onImage(data); return true }
        return false
    }
}
#endif
