import SwiftUI

public enum AICitationSegment: Equatable, Sendable {
    case text(String)
    case source(AISource)
}
/// Citations participate in the native text layout, selection, baselines and wrapping.
public struct AICitedText: View {
    public var segments: [AICitationSegment]
    @State private var selected: AISource?
    @State private var badgeRect = CGRect.zero
    @Theme private var theme
    public init(_ segments: [AICitationSegment]) { self.segments = segments }
    public var body: some View {
        CitationTextView(segments: segments, foreground: theme.foreground, badgeBackground: theme.muted) { source, rect in
            badgeRect = rect
            selected = source
        }.popover(item: $selected, attachmentAnchor: .rect(.rect(badgeRect))) { source in
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title).aiFont(14, weight: .medium)
                    if let summary = source.summary { Text(summary).aiFont().foregroundStyle(theme.mutedForeground) }
                    Link(destination: source.url) { HStack { Text(source.hostname); AIIcon(.arrowUpRight, size: 12) }.aiHitTarget() }.aiFont(12)
                }.padding(16).frame(width: 256).foregroundStyle(theme.foreground).presentationCompactAdaptation(.popover)
            }
    }
}
#if os(macOS)
import AppKit
private struct CitationTextView: NSViewRepresentable {
    var segments: [AICitationSegment]
    var foreground: Color
    var badgeBackground: Color
    var onSource: (AISource, CGRect) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> CitationNSTextView {
        let view = CitationNSTextView(); view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.textContainerInset = .zero; view.textContainer?.lineFragmentPadding = 0
        view.isHorizontallyResizable = false; view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = false; view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateNSView(_ view: CitationNSTextView, context: Context) {
        context.coordinator.parent = self
        view.textStorage?.setAttributedString(attributed())
        view.onLink = { [weak view, coordinator = context.coordinator] url, index in
            if let view { coordinator.select(url, index: index, in: view) }
        }
        view.linkTextAttributes = [.foregroundColor: NSColor(foreground), .underlineStyle: 0]
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CitationNSTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, let container = nsView.textContainer, let manager = nsView.layoutManager else { return nil }
        container.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        return CGSize(width: width, height: ceil(manager.usedRect(for: container).height))
    }
    private func attributed() -> NSAttributedString {
        _ = AITypography.font()
        let font = NSFont(name: "Geist-Regular", size: 14) ?? .systemFont(ofSize: 14)
        let paragraph = NSMutableParagraphStyle(); paragraph.minimumLineHeight = 22.75; paragraph.paragraphSpacing = 12
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(foreground), .paragraphStyle: paragraph]
        let result = NSMutableAttributedString()
        for segment in segments {
            switch segment {
            case .text(let text): result.append(NSAttributedString(string: text.replacingOccurrences(of: "\n\n", with: "\n"), attributes: attributes.merging([.baselineOffset: 3 * font.pointSize / 14]) { _, new in new }))
            case .source(let source):
                let labelFont = NSFont(name: "Geist-Medium", size: 12) ?? .systemFont(ofSize: 12)
                let label = NSAttributedString(string: source.hostname, attributes: [.font: labelFont, .foregroundColor: NSColor(foreground)])
                let size = CGSize(width: label.size().width + 22, height: 24)
                let image = NSImage(size: size)
                image.lockFocus()
                NSGraphicsContext.current?.cgContext.setShouldSmoothFonts(false)
                NSColor(badgeBackground).setFill()
                // The reference clips its fill inside a transparent 1pt border.
                NSBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11).fill()
                label.draw(at: CGPoint(x: 11, y: (24 - label.size().height) / 2))
                image.unlockFocus()
                let attachment = NSTextAttachment(); attachment.attachmentCell = CitationBadgeCell(imageCell: image)
                let string = NSMutableAttributedString(attachment: attachment)
                string.addAttributes(attributes.merging([.link: source.url]) { _, new in new }, range: NSRange(location: 0, length: string.length))
                result.append(string)
            }
        }
        return result
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CitationTextView
        init(_ parent: CitationTextView) { self.parent = parent }
        func select(_ url: URL, index: Int, in view: NSTextView) {
            guard let layout = view.layoutManager, let container = view.textContainer else { return }
            let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: index, length: 1), actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
                .offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
            if let source = parent.segments.compactMap({ if case .source(let source) = $0 { return source }; return nil }).first(where: { $0.url == url }) { parent.onSource(source, rect) }
        }
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL { select(url, index: charIndex, in: textView) }; return true
        }
    }
}
private final class CitationBadgeCell: NSTextAttachmentCell {
    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -6) }
}
private final class CitationNSTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { super.draw(dirtyRect); return }
        context.saveGState(); context.setShouldSmoothFonts(false)
        super.draw(dirtyRect)
        context.restoreGState()
    }
    var onLink: (URL, Int) -> Void = { _, _ in }
    private var area: NSTrackingArea?
    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area) }
        let new = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInActiveApp, .inVisibleRect], owner: self)
        addTrackingArea(new); area = new; super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) {
        guard let manager = layoutManager, let container = textContainer, let storage = textStorage else { return }
        let point = convert(event.locationInWindow, from: nil)
        let glyph = manager.glyphIndex(for: point, in: container)
        guard glyph < manager.numberOfGlyphs, manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).contains(point) else { return }
        let index = manager.characterIndexForGlyph(at: glyph)
        if index < storage.length, let url = storage.attribute(.link, at: index, effectiveRange: nil) as? URL { onLink(url, index) }
    }
}
#else
import UIKit
private struct CitationTextView: UIViewRepresentable {
    var segments: [AICitationSegment]
    var foreground: Color
    var badgeBackground: Color
    var onSource: (AISource, CGRect) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false); view.isEditable = false; view.isScrollEnabled = false; view.backgroundColor = .clear
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0; view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        _ = AITypography.font()
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: "Geist-Regular", size: 14) ?? .systemFont(ofSize: 14))
        let paragraph = NSMutableParagraphStyle(); paragraph.minimumLineHeight = font.pointSize * 1.625; paragraph.paragraphSpacing = 12
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(foreground), .paragraphStyle: paragraph]
        let result = NSMutableAttributedString(string: "")
        for segment in segments {
            switch segment {
            case .text(let text): result.append(NSAttributedString(string: text.replacingOccurrences(of: "\n\n", with: "\n"), attributes: attributes.merging([.baselineOffset: 3 * font.pointSize / 14]) { _, new in new }))
            case .source(let source):
                let small = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: "Geist-Medium", size: 12) ?? .systemFont(ofSize: 12))
                let label = NSAttributedString(string: source.hostname, attributes: [.font: small, .foregroundColor: UIColor(foreground)])
                let scale = small.pointSize / 12
                let height = 24 * scale, size = CGSize(width: label.size().width + 22 * scale, height: height)
                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    UIColor(badgeBackground).setFill()
                    UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: scale, dy: scale), cornerRadius: height / 2 - scale).fill()
                    label.draw(at: CGPoint(x: 11 * scale, y: (height - label.size().height) / 2))
                }
                // Keep the badge's descent within the body line's descent. A lower
                // attachment grows mixed text/badge lines beyond their 24pt height.
                let attachment = NSTextAttachment(); attachment.image = image; attachment.bounds = CGRect(x: 0, y: small.descender - 3 * scale, width: size.width, height: size.height)
                let string = NSMutableAttributedString(attachment: attachment); string.addAttributes(attributes.merging([.link: source.url]) { _, new in new }, range: NSRange(location: 0, length: string.length)); result.append(string)
            }
        }
        view.attributedText = result; view.linkTextAttributes = [.foregroundColor: UIColor(foreground), .underlineStyle: 0]
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }; return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CitationTextView
        init(_ parent: CitationTextView) { self.parent = parent }
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .link(let url) = textItem.content else { return defaultAction }
            guard let source = parent.segments.compactMap({ if case .source(let source) = $0 { return source }; return nil }).first(where: { $0.url == url }) else { return defaultAction }
            let glyphs = textView.layoutManager.glyphRange(forCharacterRange: textItem.range, actualCharacterRange: nil)
            let rect = textView.layoutManager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
            return UIAction { [weak self] _ in self?.parent.onSource(source, rect) }
        }
    }
}
#endif
