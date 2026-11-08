import SwiftUI
import CoreText
#if os(macOS)
import AppKit
private typealias ParagraphFont = NSFont
private typealias ParagraphColor = NSColor
#else
import UIKit
private typealias ParagraphFont = UIFont
private typealias ParagraphColor = UIColor
#endif

// Keep code identifiers together at punctuation without inserting invisible characters
// into selectable text. TextKit still wraps an identifier wider than the whole line.
private let codeToken = NSAttributedString.Key("AIElements.CodeToken")
final class InlineCodeLineBreaker: NSObject, NSLayoutManagerDelegate {
    private let storage = NSTextStorage()

    func makeTextContainer() -> NSTextContainer {
        let manager = ParagraphLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.delegate = self
        return container
    }

    #if os(iOS)
    func layoutManager(_ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
        let index = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        guard let storage = layoutManager.textStorage, index < storage.length,
              storage.attribute(codeToken, at: index, effectiveRange: nil) != nil,
              let paragraph = storage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle,
              paragraph.maximumLineHeight > 0 else { return false }
        // UIKit expands lines containing the larger symbol fallback despite the
        // fixed line height. Preserve glyph baselines, but keep subsequent lines
        // on the CSS line-height grid (including the scroll viewport's last line).
        lineFragmentRect.pointee.size.height = paragraph.maximumLineHeight
        lineFragmentUsedRect.pointee.size.height = paragraph.maximumLineHeight
        return true
    }
    #endif

    func layoutManager(_ layoutManager: NSLayoutManager, shouldBreakLineByWordBeforeCharacterAt index: Int) -> Bool {
        guard let storage = layoutManager.textStorage, index > 0, index < storage.length else { return true }
        var range = NSRange()
        guard storage.attribute(codeToken, at: index, effectiveRange: &range) != nil,
              index > range.location else {
            let previous = (storage.string as NSString).character(at: index - 1)
            return previous != 0x2f // Keep paths such as app/page.tsx intact.
        }
        let previous = (storage.string as NSString).character(at: index - 1)
        return UnicodeScalar(previous).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
    }
}

// Preserve TextKit's native selection and marked-text highlights. Only decorate
// the background attributed to an inline code span.
private final class ParagraphLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let storage = textStorage else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(.backgroundColor, in: characters) { background, range, _ in
            let glyphs = NSIntersectionRange(glyphsToShow, glyphRange(forCharacterRange: range, actualCharacterRange: nil))
            let isInlineCode = background != nil && storage.attribute(codeToken, at: range.location, effectiveRange: nil) != nil
            let fontSize = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? ParagraphFont)?.pointSize ?? 12.6
            guard isInlineCode else {
                super.drawGlyphs(forGlyphRange: glyphs, at: origin)
                return
            }
            // Reserve padding at ordinary word boundaries. Oversized identifiers may
            // wrap by character, so constrain each fragment to its actual line width.
            enumerateLineFragments(forGlyphRange: glyphs) { line, _, container, lineGlyphs, _ in
                let segment = NSIntersectionRange(glyphs, lineGlyphs)
                let bounds = self.boundingRect(forGlyphRange: segment, in: container)
                let last = self.characterIndexForGlyph(at: NSMaxRange(segment) - 1)
                let trailing = (storage.attribute(.kern, at: last, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0
                let offset = min(4 * fontSize / 12.6, max(0, line.maxX - bounds.maxX + trailing))
                super.drawGlyphs(forGlyphRange: segment, at: CGPoint(x: origin.x + offset, y: origin.y))
            }
        }
    }

    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<CGRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: ParagraphColor) {
        guard let storage = textStorage, charRange.location < storage.length,
              storage.attribute(codeToken, at: charRange.location, effectiveRange: nil) != nil,
              let background = storage.attribute(.backgroundColor, at: charRange.location, effectiveRange: nil) as? ParagraphColor,
              color.isEqual(background) else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }
        for rect in UnsafeBufferPointer(start: rectArray, count: rectCount) {
            let bounds = rect.insetBy(dx: 0, dy: 1)
            let radius = min(6, bounds.height / 2)
            #if os(macOS)
            NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
            #else
            UIBezierPath(roundedRect: bounds, cornerRadius: radius).fill()
            #endif
        }
    }
}

// The browser's pre-wrap permits a line beginning with punctuation (for example
// "..."). TextKit's word wrapper groups it with the previous word. Generate only
// the display line breaks, and map selections back to the untouched source.
struct CodeTextWrapping {
    let text: String
    let attributedText: NSAttributedString
    let sourceOffsets: [Int]
    init(_ source: NSAttributedString, width: CGFloat) {
        let raw = source.string as NSString
        let typesetter = CTTypesetterCreateWithAttributedString(source)
        var output = "", offsets = [0], start = 0
        let styledOutput = NSMutableAttributedString(string: "")
        func append(_ range: NSRange) {
            output += raw.substring(with: range)
            styledOutput.append(source.attributedSubstring(from: range))
            for i in range.location..<(range.location + range.length) { offsets.append(i + 1) }
        }
        while start < raw.length {
            let newline = raw.range(of: "\n", range: NSRange(location: start, length: raw.length - start))
            let end = newline.location == NSNotFound ? raw.length : newline.location
            let suggested = CTTypesetterSuggestClusterBreak(typesetter, start, max(1, width))
            let fit = suggested > 0 ? suggested : raw.rangeOfComposedCharacterSequence(at: start).length
            if start + fit >= end {
                append(NSRange(location: start, length: end - start))
                if end < raw.length { append(NSRange(location: end, length: 1)) }
                start = min(raw.length, end + 1)
                continue
            }
            let limit = start + fit
            var split: Int? = nil
            for i in start...min(limit, end - 1) where raw.character(at: i) == 32 || raw.character(at: i) == 9 { split = i }
            // Do not turn indentation alone into a blank line.
            if let candidate = split, raw.substring(with: NSRange(location: start, length: candidate - start)).trimmingCharacters(in: .whitespaces).isEmpty { split = nil }
            let endOfLine = split ?? limit
            append(NSRange(location: start, length: endOfLine - start))
            output += "\n"
            styledOutput.append(NSAttributedString(string: "\n", attributes: source.attributes(at: min(endOfLine, raw.length - 1), effectiveRange: nil)))
            start = split.map { $0 + 1 } ?? limit
            offsets.append(start)
        }
        text = output
        attributedText = styledOutput
        sourceOffsets = offsets
    }
    func copiedText(from source: String, selection: NSRange) -> String? {
        guard selection.location >= 0, selection.length > 0, NSMaxRange(selection) < sourceOffsets.count else { return nil }
        let start = sourceOffsets[selection.location], end = sourceOffsets[NSMaxRange(selection)]
        return (source as NSString).substring(with: NSRange(location: start, length: end - start))
    }
}

#if os(macOS)
typealias PlatformParagraphView = NSTextView
#else
typealias PlatformParagraphView = UITextView
#endif
final class ParagraphTextView: PlatformParagraphView {
    #if os(macOS)
    override func draw(_ dirtyRect: NSRect) {
        // Match the reference's antialiased text without changing font weight
        // or the host application's global font-smoothing preferences.
        guard let context = NSGraphicsContext.current?.cgContext else { super.draw(dirtyRect); return }
        context.saveGState()
        context.setShouldSmoothFonts(false)
        super.draw(dirtyRect)
        context.restoreGState()
    }
    #endif
    private var original: NSAttributedString?
    private var wrapping: CodeTextWrapping?
    private var wrappingWidth: CGFloat = 0
    private var isCode = false
    func setParagraph(_ source: NSAttributedString, code: Bool) {
        guard original?.isEqual(to: source) != true || isCode != code else { return }
        original = source; isCode = code
        applyParagraph()
    }
    func layoutCode(width: CGFloat) {
        guard width != wrappingWidth else { return }
        wrappingWidth = width
        if isCode { applyParagraph() }
    }
    private func applyParagraph() {
        guard let original else { return }
        let displayed: NSAttributedString
        if isCode && wrappingWidth > 0 {
            let wrapped = CodeTextWrapping(original, width: wrappingWidth)
            wrapping = wrapped
            displayed = wrapped.attributedText
        } else { wrapping = nil; displayed = original }
        #if os(macOS)
        textStorage?.setAttributedString(displayed)
        #else
        attributedText = displayed
        #endif
    }
    #if os(macOS)
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // ViewThatFits may probe several widths. Always commit the final view width,
        // rather than leaving TextKit at the last candidate's measuring width.
        if newSize.width > 0 {
            layoutCode(width: newSize.width)
            textContainer?.containerSize = CGSize(width: newSize.width, height: .greatestFiniteMagnitude)
        }
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0 {
            layoutCode(width: bounds.width)
            if abs(textContainer.size.width - bounds.width) > 0.01 {
                textContainer.size.width = bounds.width
            }
            layoutManager.ensureLayout(for: textContainer)
        }
    }
    #endif
    override func copy(_ sender: Any?) {
        #if os(macOS)
        let selection = selectedRange()
        #else
        let selection = selectedRange
        #endif
        guard let original, let value = wrapping?.copiedText(from: original.string, selection: selection) else { super.copy(sender); return }
        #if os(macOS)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }
}

struct NativeTextParagraph {
    private enum Content { case markdown(String), code(String), message(String), plain(String) }
    private let content: Content
    init(markdown: String) { content = .markdown(markdown) }
    init(verbatimCode: String) { content = .code(verbatimCode) }
    init(message: String) { content = .message(message) }
    init(verbatim: String) { content = .plain(verbatim) }
    @Environment(\.aiParagraphMuted) private var muted
    @Environment(\.aiParagraphLineHeight) private var lineHeight
    @Environment(\.multilineTextAlignment) private var alignment
    @Theme private var theme
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 14
    private var isCode: Bool { if case .code = content { return true }; return false }
    private func contentWidth(_ proposed: CGFloat) -> CGFloat {
        guard case .message = content else { return proposed }
        let natural = styled().size().width
        return min(proposed, ceil(natural))
    }
    func makeCoordinator() -> InlineCodeLineBreaker { InlineCodeLineBreaker() }

    func styled() -> NSAttributedString {
        _ = AITypography.font()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment == .center ? .center : alignment == .trailing ? .right : .left
        paragraph.lineBreakStrategy = []
        let markdown: String
        switch content {
        case .code(let code):
            paragraph.lineBreakMode = .byClipping
            let pointSize = size * 12 / 14
            paragraph.minimumLineHeight = pointSize * 1.625
            paragraph.maximumLineHeight = paragraph.minimumLineHeight
            let result = NSMutableAttributedString(string: code.isEmpty ? " " : code, attributes: [
                .font: ParagraphFont(name: "GeistMono-Regular", size: pointSize) ?? .monospacedSystemFont(ofSize: pointSize, weight: .regular),
                .foregroundColor: ParagraphColor(theme.foreground), .paragraphStyle: paragraph, .baselineOffset: pointSize / 6, codeToken: true
            ])
            // The webfont subset omits these terminal symbols. Its named Arial
            // fallback has size-adjust: 134.59%; the full bundled Geist font
            // otherwise supplies much smaller glyphs. Keep the source intact.
            if let fallback = ParagraphFont(name: "ArialMT", size: pointSize * 1.3459) {
                let raw = result.string as NSString
                for index in 0..<raw.length where [0x25b2, 0x25cb].contains(Int(raw.character(at: index))) {
                    result.addAttribute(.font, value: fallback, range: NSRange(location: index, length: 1))
                }
            }
            return result
        case .message(let text):
            paragraph.minimumLineHeight = size * 1.625
            paragraph.maximumLineHeight = paragraph.minimumLineHeight
            return NSAttributedString(string: text, attributes: [
                .font: ParagraphFont(name: "Geist-Regular", size: size) ?? .systemFont(ofSize: size),
                .foregroundColor: ParagraphColor(theme.foreground), .paragraphStyle: paragraph
            ])
        case .plain(let text):
            paragraph.minimumLineHeight = size * lineHeight / 14
            paragraph.maximumLineHeight = paragraph.minimumLineHeight
            return NSAttributedString(string: text, attributes: [
                .font: ParagraphFont(name: "Geist-Regular", size: size) ?? .systemFont(ofSize: size),
                .foregroundColor: ParagraphColor(muted ? theme.mutedForeground : theme.foreground), .paragraphStyle: paragraph
            ])
        case .markdown(let text): markdown = text
        }
        let parsed = (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
        let result = NSMutableAttributedString(string: "")
        paragraph.minimumLineHeight = size * lineHeight / 14
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        for run in parsed.runs {
            let intent = run.inlinePresentationIntent
            let code = intent?.contains(.code) == true
            let bold = intent?.contains(.stronglyEmphasized) == true
            let italic = intent?.contains(.emphasized) == true
            let face = (code ? "GeistMono-" : "Geist-") + (bold ? "SemiBold" : italic ? "Medium" : "Regular") + (italic ? "Italic" : "")
            let fontSize = size * (code ? 0.9 : 1)
            var attrs: [NSAttributedString.Key: Any] = [
                .font: ParagraphFont(name: face, size: fontSize) ?? .systemFont(ofSize: fontSize),
                .foregroundColor: ParagraphColor(muted ? theme.mutedForeground : theme.foreground), .paragraphStyle: paragraph
            ]
            if code { attrs[codeToken] = true; attrs[.backgroundColor] = ParagraphColor(theme.muted) }
            if let link = run.link { attrs[.link] = link }
            let fragment = NSMutableAttributedString(string: String(parsed[run.range].characters), attributes: attrs)
            if code && fragment.length > 0 {
                // Reserve both sides in the glyph advance without altering copied text.
                let lastCharacter = (fragment.string as NSString).rangeOfComposedCharacterSequence(at: fragment.length - 1)
                fragment.addAttribute(.kern, value: size * 8 / 14, range: lastCharacter)
            }
            result.append(fragment)
        }
        return result
    }
}
#if os(macOS)
extension NativeTextParagraph: NSViewRepresentable {
    func makeNSView(context: Context) -> ParagraphTextView {
        let view = ParagraphTextView(frame: .zero, textContainer: context.coordinator.makeTextContainer())
        view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.textContainerInset = .zero; view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = false
        return view
    }
    func updateNSView(_ view: ParagraphTextView, context: Context) { view.setParagraph(styled(), code: isCode) }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ParagraphTextView, context: Context) -> CGSize? {
        guard let proposed = proposal.width, let container = nsView.textContainer, let manager = nsView.layoutManager else { return nil }
        let width = contentWidth(proposed)
        nsView.layoutCode(width: width)
        container.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        return CGSize(width: width, height: manager.usedRect(for: container).height)
    }
}
#else
extension NativeTextParagraph: UIViewRepresentable {
    func makeUIView(context: Context) -> ParagraphTextView {
        let view = ParagraphTextView(frame: .zero, textContainer: context.coordinator.makeTextContainer())
        view.isEditable = false; view.isScrollEnabled = false; view.backgroundColor = .clear
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0
        return view
    }
    func updateUIView(_ view: ParagraphTextView, context: Context) { view.setParagraph(styled(), code: isCode) }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ParagraphTextView, context: Context) -> CGSize? {
        guard let proposed = proposal.width else { return nil }
        let width = contentWidth(proposed)
        uiView.layoutCode(width: width)
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        uiView.setNeedsLayout()
        return CGSize(width: width, height: measured.height)
    }
}
#endif
