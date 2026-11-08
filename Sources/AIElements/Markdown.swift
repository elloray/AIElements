import SwiftUI

/// Native block Markdown: streaming fences, lists, tasks, tables, quotes, links and images.
public struct AIMessageResponse: View, Equatable {
    public var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(MarkdownCache.blocks(text).enumerated()), id: \.offset) { _, block in blockView(block) }
        }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .code(language, code):
            AICodeBlock(code, language: language.isEmpty ? nil : language, showLineNumbers: true, showCopy: true,
                        showsWrapControl: false)
        case let .heading(level, title): inline(title).aiFont(CGFloat(max(16, 26 - level * 2)), weight: .semibold).accessibilityAddTraits(.isHeader)
        case let .quote(value): inline(value).foregroundStyle(.secondary).padding(.leading, 12).overlay(alignment: .leading) { Rectangle().fill(.secondary.opacity(0.3)).frame(width: 1) }
        case let .text(value):
            NativeTextParagraph(markdown: value)
        case let .list(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let checked = item.checked { AIIcon(checked ? .check : .square, size: 14).accessibilityLabel(checked ? "Checked" : "Unchecked") }
                        else { Text(item.marker).aiFont().frame(minWidth: 14, alignment: .trailing).accessibilityHidden(true) }
                        inline(item.text).aiFont().lineSpacing(4)
                    }.padding(.leading, CGFloat(item.depth) * 16)
                }
            }
        case let .table(headers, rows):
            AIHorizontalScroll {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow { ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in inline(cell).aiFont(14, weight: .medium) } }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow { ForEach(Array(headers.indices), id: \.self) { index in inline(index < row.count ? row[index] : "").aiFont() } }
                    }
                }.padding(12)
            }.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.2), lineWidth: 1))
        case .rule: Divider()
        case .image(let alt, let url):
            AsyncImage(url: URL(string: url)) { phase in
                if let image = phase.image { image.resizable().scaledToFit().accessibilityLabel(alt) }
                else { Text(alt).aiFont().foregroundStyle(.secondary) }
            }
        }
    }
    private func inline(_ value: String) -> Text {
        var attributed = (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value)
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].font = AITypography.font(13, mono: true)
            attributed[run.range].backgroundColor = Color.secondary.opacity(0.12)
        }
        return Text(attributed)
    }
}
struct MarkdownListItem: Equatable { var depth: Int; var marker: String; var text: String; var checked: Bool? }
enum MarkdownBlock: Equatable {
    case text(String), code(String, String), heading(Int, String), quote(String)
    case list([MarkdownListItem]), table([String], [[String]]), rule, image(String, String)
    static func parse(_ text: String) -> [MarkdownBlock] {
        let source = text.components(separatedBy: "\n")
        var result: [MarkdownBlock] = [], paragraph: [String] = []
        var i = 0
        func flush() { if !paragraph.isEmpty { result.append(.text(paragraph.joined(separator: "\n"))); paragraph = [] } }
        while i < source.count {
            let line = source[i], trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flush(); let marker = String(trimmed.prefix(while: { $0 == trimmed.first! })); let language = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                i += 1; var code: [String] = []
                while i < source.count && !source[i].trimmingCharacters(in: .whitespaces).hasPrefix(marker) { code.append(source[i]); i += 1 }
                result.append(.code(language, code.joined(separator: "\n")))
            } else if trimmed.isEmpty { flush() }
            else if let space = trimmed.firstIndex(of: " "), trimmed[..<space].allSatisfy({ $0 == "#" }), (1...6).contains(trimmed.distance(from: trimmed.startIndex, to: space)) {
                flush(); result.append(.heading(trimmed.distance(from: trimmed.startIndex, to: space), String(trimmed[trimmed.index(after: space)...])))
            } else if trimmed.hasPrefix(">") {
                flush(); var quote: [String] = []
                while i < source.count && source[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quote.append(String(source[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces)); i += 1
                }
                result.append(.quote(quote.joined(separator: "\n"))); i -= 1
            } else if let item = listItem(line) {
                flush(); var items = [item]; i += 1
                while i < source.count {
                    if let next = listItem(source[i]) { items.append(next); i += 1 }
                    else if source[i].hasPrefix("  ") && !source[i].trimmingCharacters(in: .whitespaces).isEmpty { items[items.count - 1].text += "\n" + source[i].trimmingCharacters(in: .whitespaces); i += 1 }
                    else { break }
                }
                result.append(.list(items)); i -= 1
            } else if i + 1 < source.count, trimmed.contains("|"), isTableSeparator(source[i + 1]) {
                flush(); let headers = cells(trimmed); i += 2; var rows: [[String]] = []
                while i < source.count && source[i].contains("|") && !source[i].isEmpty { rows.append(cells(source[i])); i += 1 }
                result.append(.table(headers, rows)); i -= 1
            } else if ["---", "***", "___"].contains(trimmed) { flush(); result.append(.rule) }
            else if trimmed.hasPrefix("!["), let middle = trimmed.range(of: "]("), trimmed.hasSuffix(")") {
                flush(); result.append(.image(String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<middle.lowerBound]), String(trimmed[middle.upperBound..<trimmed.index(before: trimmed.endIndex)])))
            } else { paragraph.append(line) }
            i += 1
        }
        flush(); return result
    }
    private static func listItem(_ line: String) -> MarkdownListItem? {
        let pattern = #"^(\s*)([-+*]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        func part(_ index: Int) -> String? { Range(match.range(at: index), in: line).map { String(line[$0]) } }
        let marker = part(2) ?? "-"
        return .init(depth: (part(1)?.replacingOccurrences(of: "\t", with: "  ").count ?? 0) / 2, marker: ["-", "+", "*"].contains(marker) ? "•" : marker, text: part(4) ?? "", checked: part(3).map { $0.lowercased() == "x" })
    }
    private static func cells(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }; if value.hasSuffix("|") { value.removeLast() }
        // Escaped pipes stay inside their cell.
        return value.replacingOccurrences(of: "\\|", with: "\u{E000}").components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\u{E000}", with: "|") }
    }
    private static func isTableSeparator(_ line: String) -> Bool {
        let parts = cells(line)
        return !parts.isEmpty && parts.allSatisfy { cell in let stripped = cell.replacingOccurrences(of: ":", with: ""); return stripped.count >= 3 && stripped.allSatisfy { $0 == "-" } }
    }
}
private final class MarkdownBlocks: NSObject { let value: [MarkdownBlock]; init(_ value: [MarkdownBlock]) { self.value = value } }
private enum MarkdownCache {
    static let cache: NSCache<NSString, MarkdownBlocks> = { let cache = NSCache<NSString, MarkdownBlocks>(); cache.totalCostLimit = 2_000_000; cache.countLimit = 128; return cache }()
    static func blocks(_ text: String) -> [MarkdownBlock] {
        if let cached = cache.object(forKey: text as NSString) { return cached.value }
        let result = MarkdownBlock.parse(text); cache.setObject(MarkdownBlocks(result), forKey: text as NSString, cost: text.utf8.count); return result
    }
}
