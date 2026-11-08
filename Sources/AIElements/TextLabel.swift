import SwiftUI

private struct AILabelForegroundKey: EnvironmentKey { static let defaultValue: Color? = nil }
extension EnvironmentValues {
    var aiLabelForeground: Color? {
        get { self[AILabelForegroundKey.self] }
        set { self[AILabelForegroundKey.self] = newValue }
    }
}

/// A noneditable label using the library's font rendering on both platforms.
/// Use paragraphs or code blocks for selectable content.
public struct AITextLabel: View {
    public var text: String
    public var weight: Font.Weight
    public var color: Color?
    public var lineLimit: Int?
    public var tracking: CGFloat
    private let baseSize: CGFloat
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 14
    @Theme private var theme
    @Environment(\.aiLabelForeground) private var inheritedColor
    public init(_ text: String, size: CGFloat = 14, weight: Font.Weight = .regular,
                color: Color? = nil, lineLimit: Int? = nil, tracking: CGFloat = 0) {
        self.text = text; self.weight = weight; self.color = color; self.baseSize = size
        self.lineLimit = lineLimit; self.tracking = tracking
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }
    public var body: some View {
        #if os(macOS)
        ReferenceLabel(text: text, size: size, weight: weight,
                       color: color ?? inheritedColor ?? theme.foreground,
                       lineLimit: lineLimit, tracking: tracking)
            .accessibilityElement(children: .ignore).accessibilityLabel(text).accessibilityAddTraits(.isStaticText)
        #else
        Text(text).aiFont(baseSize, weight: weight).tracking(tracking)
            .foregroundStyle(color ?? inheritedColor ?? theme.foreground).lineLimit(lineLimit)
        #endif
    }
}

#if os(macOS)
import AppKit
private struct ReferenceLabel: NSViewRepresentable {
    var text: String; var size: CGFloat; var weight: Font.Weight
    var color: Color; var lineLimit: Int?; var tracking: CGFloat
    func makeNSView(context: Context) -> LabelView { LabelView() }
    func updateNSView(_ view: LabelView, context: Context) {
        _ = AITypography.font()
        let suffix = weight == .bold || weight == .semibold ? "SemiBold" : weight == .medium ? "Medium" : "Regular"
        let font = NSFont(name: "Geist-\(suffix)", size: size) ?? .systemFont(ofSize: size)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = lineLimit == 1 ? .byTruncatingTail : .byWordWrapping
        // CSS text-overflow truncates without AppKit's automatic letter tightening.
        paragraph.allowsDefaultTighteningForTruncation = false
        var attributes: [NSAttributedString.Key: Any] = [.font: font,
            .foregroundColor: NSColor(color), .paragraphStyle: paragraph]
        // An explicit zero kern disables the font’s normal kerning pairs.
        if tracking != 0 { attributes[.kern] = tracking }
        view.text = NSAttributedString(string: text, attributes: attributes)
        view.maximumLines = lineLimit
        view.lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        view.needsDisplay = true
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LabelView, context: Context) -> CGSize? {
        let natural = nsView.text.size()
        // Round intrinsic width outwards. SwiftUI may otherwise round a fractional
        // advance down, causing even an unconstrained short label to truncate.
        let scale = nsView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let naturalWidth = ceil(natural.width * scale) / scale
        let width = max(0, min(proposal.width ?? naturalWidth, naturalWidth))
        let height = nsView.text.boundingRect(with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        return CGSize(width: width, height: min(ceil(height), nsView.maximumLines.map { CGFloat($0) * nsView.lineHeight } ?? .greatestFiniteMagnitude))
    }
}
private final class LabelView: NSView {
    var text = NSAttributedString(string: "")
    var maximumLines: Int?
    var lineHeight: CGFloat = 18
    override var isFlipped: Bool { true }
    // Let the containing SwiftUI button own pointer events and accessibility.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState(); context.setShouldSmoothFonts(false)
        text.draw(with: bounds, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine])
        context.restoreGState()
    }
}
#endif
