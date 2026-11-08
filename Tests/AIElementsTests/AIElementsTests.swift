import XCTest
import SwiftUI
import CoreText
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import AIElements

final class AIElementsTests: XCTestCase {
    @MainActor private func renderedLines(_ text: NSAttributedString, width: CGFloat) -> [String] {
        let breaker = InlineCodeLineBreaker()
        let container = breaker.makeTextContainer()
        container.size = CGSize(width: width, height: 10000)
        container.lineFragmentPadding = 0
        let manager = container.layoutManager!
        manager.textStorage!.setAttributedString(text)
        manager.ensureLayout(for: container)
        var lines: [String] = []
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, used, _, glyphs, _ in
            XCTAssertLessThanOrEqual(used.maxX, width + 0.5, "Text must stay inside its proposed width")
            let range = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            lines.append((text.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return lines
    }

    @MainActor func testPlainResponseKeepsPathTogether() {
        let text = NativeTextParagraph(markdown: "Added Open Graph defaults to app/layout.tsx and a title, description and image for the home page in app/page.tsx.").styled()
        let lines = renderedLines(text, width: 360)
        XCTAssertEqual(lines.last, "app/page.tsx.")
    }

    @MainActor func testTerminalKeepsBuildOnTheFirstLine() {
        let text = NativeTextParagraph(verbatimCode: "   Creating an optimized production build ...").styled()
        let wrapped = CodeTextWrapping(text, width: 308)
        XCTAssertEqual(wrapped.text, "   Creating an optimized production build\n...")
        XCTAssertEqual(wrapped.copiedText(from: text.string, selection: NSRange(location: 0, length: (wrapped.text as NSString).length)), text.string)
        let route = NativeTextParagraph(verbatimCode: "┌ ○ /                     1.9 kB       112 kB").styled()
        XCTAssertEqual(CodeTextWrapping(route, width: 308).text, "┌ ○ /                     1.9 kB       112\nkB")
        let columns = NativeTextParagraph(verbatimCode: "Route (app)                Size  First Load JS").styled()
        XCTAssertEqual(CodeTextWrapping(columns, width: 308).text, "Route (app)                Size  First\nLoad JS")
        let long = NativeTextParagraph(verbatimCode: String(repeating: "x", count: 120)).styled()
        let longWrapped = CodeTextWrapping(long, width: 130)
        XCTAssertGreaterThan(longWrapped.text.components(separatedBy: "\n").count, 1)
        XCTAssertEqual(longWrapped.copiedText(from: long.string, selection: NSRange(location: 0, length: (longWrapped.text as NSString).length)), long.string)
    }

    @MainActor func testTerminalSymbolFallbackKeepsFixedLineHeight() {
        let source = NativeTextParagraph(verbatimCode: "build\n   ▲ Next.js\ncompiled\n┌ ○ /\nlast line").styled()
        let breaker = InlineCodeLineBreaker()
        let container = breaker.makeTextContainer()
        container.size = CGSize(width: 308, height: 1000)
        container.lineFragmentPadding = 0
        let manager = container.layoutManager!
        manager.textStorage!.setAttributedString(source)
        manager.ensureLayout(for: container)
        var count = 0
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { rect, _, _, _, _ in
            XCTAssertEqual(rect.height, 19.5, accuracy: 0.001)
            XCTAssertEqual(rect.minY, CGFloat(count) * 19.5, accuracy: 0.001)
            count += 1
        }
        XCTAssertEqual(count, 5)
        XCTAssertEqual(manager.textStorage!.string, source.string)
    }

    @MainActor func testCodeWrappingPreservesBlankLinesUnicodeAndPartialCopy() {
        let source = "alpha beta gamma delta\n\n👩🏽‍💻 status: café\n"
        let attributed = NativeTextParagraph(verbatimCode: source).styled()
        let wrapped = CodeTextWrapping(attributed, width: 90)
        XCTAssertTrue(wrapped.text.contains("\n\n"))
        XCTAssertTrue(wrapped.text.contains("👩🏽‍💻"))
        let narrow = CodeTextWrapping(NativeTextParagraph(verbatimCode: "👩🏽‍💻").styled(), width: 1)
        XCTAssertEqual(narrow.text, "👩🏽‍💻")
        XCTAssertFalse(wrapped.text.contains("�"))
        XCTAssertEqual(wrapped.sourceOffsets.count, (wrapped.text as NSString).length + 1)
        XCTAssertEqual(wrapped.copiedText(from: source, selection: NSRange(location: 0, length: (wrapped.text as NSString).length)), source)
        let beta = (wrapped.text as NSString).range(of: "beta")
        let delta = (wrapped.text as NSString).range(of: "delta")
        XCTAssertEqual(wrapped.copiedText(from: source, selection: NSRange(location: beta.location, length: NSMaxRange(delta) - beta.location)), "beta gamma delta")
    }

    @MainActor func testCodeWrappingRetainsSymbolFallbackAndCopyAfterReflow() {
        let source = NativeTextParagraph(verbatimCode: "build output\n   ▲ Next.js 16.3.0\n ✓ Compiled successfully\n┌ ○ /  1.9 kB 112 kB").styled()
        for width: CGFloat in [308, 120] {
            let wrapped = CodeTextWrapping(source, width: width)
            XCTAssertEqual(wrapped.attributedText.string, wrapped.text)
            let symbol = (wrapped.text as NSString).range(of: "▲")
            let font = wrapped.attributedText.attribute(.font, at: symbol.location, effectiveRange: nil) as! CTFont
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, "ArialMT")
            XCTAssertEqual(CTFontGetSize(font), 12 * 1.3459, accuracy: 0.001)
            XCTAssertEqual(wrapped.copiedText(from: source.string, selection: NSRange(location: 0, length: (wrapped.text as NSString).length)), source.string)
        }
    }

    #if os(macOS)
    @MainActor func testLabelIntrinsicWidthDoesNotTruncateShortNames() {
        _ = AITypography.font()
        let font = NSFont(name: "Geist-Regular", size: 14)!
        for name in ["app", "button.tsx", "login-form.tsx"] {
            let host = NSHostingView(rootView: AITextLabel(name, lineLimit: 1).fixedSize())
            let width = NSAttributedString(string: name, attributes: [.font: font]).size().width
            XCTAssertGreaterThanOrEqual(host.fittingSize.width, width)
            XCTAssertLessThan(host.fittingSize.width - width, 1.01)
        }
    }

    @MainActor func testParagraphCommitsFinalWidthAfterAlternateProposals() {
        let breaker = InlineCodeLineBreaker()
        let container = breaker.makeTextContainer()
        let view = ParagraphTextView(frame: .zero, textContainer: container)
        view.textContainerInset = .zero
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        view.setParagraph(NativeTextParagraph(markdown: "The command runs in this project.").styled(), code: false)
        container.containerSize = CGSize(width: 1000, height: 1000)
        view.setFrameSize(CGSize(width: 140, height: 80))
        container.layoutManager!.ensureLayout(for: container)
        let used = container.layoutManager!.usedRect(for: container)
        XCTAssertLessThanOrEqual(used.width, 140)
        XCTAssertGreaterThanOrEqual(used.height, 40)
    }
    #endif

    #if os(iOS)
    @MainActor func testPromptBaselineDoesNotShortenOrStretchRenderedLines() {
        let text = "Add a dark mode toggle to the settings page."
        let editor = AIPromptEditor(text: .constant(text), foreground: .black,
            onSend: {}, onFocus: { _ in }, onFiles: { _ in }, onImage: { _ in })
        let host = UIHostingController(rootView: editor.frame(width: 274))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 274, height: 200))
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        _ = host.sizeThatFits(in: CGSize(width: 274, height: 200))
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        func editors(_ view: UIView) -> [UITextView] {
            (view as? UITextView).map { [$0] } ?? view.subviews.flatMap(editors)
        }
        guard let view = editors(host.view).first else { return XCTFail("Missing editor") }
        XCTAssertEqual(view.text, text)
        XCTAssertEqual(view.sizeThatFits(CGSize(width: 274, height: 500)).height, 48, accuracy: 0.5)
        let manager = view.layoutManager
        var fragments: [CGRect] = []
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: view.textContainer)) { rect, _, _, _, _ in fragments.append(rect) }
        XCTAssertEqual(fragments.count, 2)
        if fragments.count == 2 { XCTAssertEqual(fragments[1].minY - fragments[0].minY, 24, accuracy: 0.5) }
    }

    @MainActor func testAssistantParagraphFillsAvailableWidth() {
        let text = "Image optimization reruns because its cache is keyed on the commit SHA, which changes on every deploy. Key the cache on a hash of public/images instead, and unchanged images will be skipped."
        let host = UIHostingController(rootView: AIMessage(role: .assistant) { AIMessageResponse(text) }.frame(width: 360))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 300))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        _ = host.sizeThatFits(in: CGSize(width: 360, height: 300))
        host.view.frame = CGRect(x: 0, y: 0, width: 360, height: 300)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        host.view.layoutIfNeeded()
        func paragraphs(_ view: UIView) -> [ParagraphTextView] {
            (view as? ParagraphTextView).map { [$0] } ?? view.subviews.flatMap(paragraphs)
        }
        let paragraph = paragraphs(host.view).first
        XCTAssertNotNil(paragraph)
        XCTAssertEqual(paragraph?.bounds.width ?? 0, 360, accuracy: 0.5)
        if let paragraph {
            XCTAssertEqual(paragraph.textContainer.size.width, 360, accuracy: 0.5)
            let first = paragraph.layoutManager.lineFragmentUsedRect(forGlyphAt: 0, effectiveRange: nil)
            XCTAssertLessThanOrEqual(first.maxX, 360)
            var range = NSRange()
            _ = paragraph.layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: &range)
            let chars = paragraph.layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            let line = (paragraph.text as NSString).substring(with: chars).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(line, "Image optimization reruns because its cache is keyed")
        }
    }
    #endif

    @MainActor func testUserMessageUsesReferenceWordWrapping() {
        let text = "Migrate the dialog components to Base UI."
        let styled = NativeTextParagraph(message: text).styled()
        XCTAssertEqual(styled.string, text)
        XCTAssertEqual(renderedLines(styled, width: 262), ["Migrate the dialog components to Base", "UI."])
    }

    @MainActor func testInlineCodePreservesCopyAndWrapsLongIdentifiers() {
        let text = NativeTextParagraph(markdown: "Open `app/page.tsx` and `site-header.tsx`.").styled()
        XCTAssertEqual(text.string, "Open app/page.tsx and site-header.tsx.")
        let lines = renderedLines(text, width: 130)
        XCTAssertTrue(lines.contains { $0.contains("app/page.tsx") })
        XCTAssertTrue(lines.contains { $0.contains("site-header.tsx") })
        let long = NativeTextParagraph(markdown: "`" + String(repeating: "long_file_name", count: 8) + "`").styled()
        XCTAssertGreaterThan(renderedLines(long, width: 130).count, 1)
        XCTAssertEqual(long.string, String(repeating: "long_file_name", count: 8))
    }

    @MainActor func testPromptUsesVisibleModelWhenOptionsArriveOrSelectionDisappears() {
        let a = AIModel(id: "a", name: "A", provider: "Test", supportedEfforts: [.low])
        let b = AIModel(id: "b", name: "B", provider: "Test", supportedEfforts: [.high])
        func submit(_ models: [AIModel], selection: String) -> AIPromptSubmission {
            AIPromptInput(text: .constant("Hello"), attachments: .constant([]), models: models, modelID: .constant(selection), effort: .constant(.medium)) { _ in }.submission
        }
        XCTAssertEqual(submit([a], selection: "").modelID, "a")
        XCTAssertEqual(submit([b], selection: "a").modelID, "b")
        XCTAssertEqual(submit([a, b], selection: "b").effort, .high)
        XCTAssertEqual(submit([], selection: "host-provided").modelID, "host-provided")
    }

    func testCopyUsesOnlyDisplayedBodyInDisplayOrder() {
        let message = AIChatMessage(role: .assistant, text: "Lead", parts: [
            .text("First"), .reasoning(text: "Private", isStreaming: false),
            .tool(name: "read", status: .completed, output: "Tool log"),
            .attachment(.init(name: "sample")), .text("Last")
        ])
        XCTAssertEqual(message.copyableText, "Lead\n\nFirst\n\nLast")
        XCTAssertEqual(AIChatMessage(role: .assistant, parts: [.text("Parts only")]).copyableText, "Parts only")
    }

    @MainActor func testNumberedCodePreservesHighlightAndBlankLines() {
        var code = AttributedString("one\n\ntwo\n")
        code[code.range(of: "two")!].foregroundColor = .red
        let lines = AICodeBlock(String(code.characters), showLineNumbers: true, highlightedCode: code).styledLines
        XCTAssertEqual(lines.map { String($0.characters) }, ["one", "", "two", ""])
        XCTAssertEqual(lines[2].foregroundColor, .red)
    }

    #if os(iOS)
    @MainActor func testPasteWebLinkIntoSelectionAndImportFileURL() {
        let clipboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: clipboard.name) }
        let editor = PromptTextView()
        var files: [URL] = []
        editor.onFiles = { files = $0 }
        let link = URL(string: "https://example.com/doc")!
        clipboard.url = link
        editor.text = "see here"
        editor.selectedRange = NSRange(location: 4, length: 4)
        XCTAssertTrue(editor.handlePaste(from: clipboard))
        XCTAssertEqual(editor.text, "see " + link.absoluteString)
        XCTAssertTrue(files.isEmpty)
        let file = URL(fileURLWithPath: "/tmp/report.txt")
        clipboard.url = file
        XCTAssertTrue(editor.handlePaste(from: clipboard))
        XCTAssertEqual(files, [file])
        XCTAssertEqual(editor.text, "see " + link.absoluteString)
    }
    #endif

    func testContextClampsInvalidAndOverLimitUsage() {
        XCTAssertEqual(AIContextUsage(input: -2, output: 4, limit: 0).percent, 0)
        XCTAssertEqual(AIContextUsage(input: 20, output: 5, limit: 10).percent, 100)
        XCTAssertEqual(AIContextUsage(input: 8420, output: 1260, reasoning: 980, limit: 128000).percent, 8)
        XCTAssertEqual(AIContextUsage(input: Int.max, output: Int.max, reasoning: Int.max, limit: Int.max).percent, 100)
        XCTAssertEqual(AIContextUsage.format(128000), "128k")
        XCTAssertEqual(AIContextUsage.format(10660), "10.7k")
    }
    func testSubmissionSupportsAttachmentOnlyButRejectsWhitespace() {
        XCTAssertFalse(AIPromptSubmission(text: " \n ", attachments: [], modelID: "m", effort: .low).canSend)
        XCTAssertTrue(AIPromptSubmission(text: "", attachments: [.init(name: "test.swift")], modelID: "m", effort: .high).canSend)
    }
    func testStreamingMarkdownPreservesIncompleteFence() {
        XCTAssertEqual(MarkdownBlock.parse("Before\n\n```swift\nlet a = 1"), [.text("Before"), .code("swift", "let a = 1")])
        XCTAssertEqual(MarkdownBlock.parse("# Title\n\n**Bold**\n\n> quote"), [.heading(1, "Title"), .text("**Bold**"), .quote("quote")])
        XCTAssertEqual(MarkdownBlock.parse("```swift\nlet x = 1\n```\n\nDone"), [.code("swift", "let x = 1"), .text("Done")])
    }
    func testStableFileIdentityAndEmptyFolder() {
        let file = AIFileNode(path: "src/file.swift")
        XCTAssertEqual(file.id, "src/file.swift")
        XCTAssertEqual(file.name, "file.swift")
        XCTAssertNil(file.children)
        XCTAssertNotNil(AIFileNode(path: "empty", children: []).children)
    }
    func testSuiteFailureCounting() {
        let suite = AITestSuite(name: "Suite", tests: [.init(name: "a", status: .failed), .init(name: "b", status: .passed), .init(name: "c", status: .skipped)])
        XCTAssertEqual(suite.failedCount, 1)
    }
    func testBundledFontsActuallyRegister() {
        _ = AITypography.font()
        let font = CTFontCreateWithName("Geist-Regular" as CFString, 14, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(font) as String, "Geist-Regular")
        let mono = CTFontCreateWithName("GeistMono-Regular" as CFString, 12, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(mono) as String, "GeistMono-Regular")
    }
    @MainActor func testPromptToolbarFitsAt360AndWrapsAtNarrowerWidths() {
        let model = AIModel(id: "gpt-5", name: "GPT-5", provider: "Demo")
        func height(width: CGFloat, size: DynamicTypeSize = .large) -> CGFloat {
            let view = AIPromptInput(text: .constant(""), models: [model]) { _ in }
                .aiControlDensity(.comfortable).environment(\.dynamicTypeSize, size)
                .frame(width: width).fixedSize(horizontal: false, vertical: true)
            #if os(macOS)
            return NSHostingView(rootView: view).fittingSize.height
            #else
            return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 1200)).height
            #endif
        }
        let singleRow = height(width: 360)
        XCTAssertEqual(singleRow, 112, accuracy: 1)
        XCTAssertGreaterThan(height(width: 280), singleRow + 20)
        XCTAssertGreaterThan(height(width: 280, size: .accessibility2), singleRow + 44)
    }
    @MainActor func testComfortableTouchTargetsReserve44Points() {
        let content = HStack {
            AICopyButton("Test")
            Button("OK") {}.buttonStyle(AIButtonStyle(.outline, compact: true))
        }.aiControlDensity(.comfortable)
        let renderer = ImageRenderer(content: content)
        XCTAssertGreaterThanOrEqual(renderer.cgImage?.height ?? 0, 44)
        XCTAssertGreaterThanOrEqual(renderer.cgImage?.width ?? 0, 88)
    }
    func testExecutionLifecycleDoesNotReportPendingOrDeniedAsCompleted() {
        XCTAssertEqual(AIStatus.aggregate([.completed, .failed]), .failed)
        XCTAssertEqual(AIStatus.aggregate([.completed, .pending]), .pending)
        XCTAssertEqual(AIStatus.aggregate([.running, .failed]), .running)
        XCTAssertEqual(AIStatus.pending.verb, "Waiting to run")
        XCTAssertEqual(AIStatus.denied.verb, "Denied")
        XCTAssertEqual(AIToolPhase.outputAvailable(preliminary: true).status(streaming: true), .running)
        XCTAssertEqual(AIToolPhase.outputAvailable(preliminary: true).status(streaming: false), .failed)
        XCTAssertEqual(AIToolPhase.inputAvailable.status(streaming: false, clientTool: true), .pending)
        XCTAssertEqual(AIToolPhase.approvalResponded(approved: false).status(streaming: true), .denied)
    }
    func testSourcesDeduplicateRepeatedCitationsAndUseHostnameFallback() {
        let url = URL(string: "https://example.com/doc")!
        let empty = AISource(title: "  ", url: url)
        XCTAssertEqual(empty.title, "example.com")
        XCTAssertEqual(AISource.unique([empty, .init(title: "Repeated", url: url)]), [empty])
    }
    func testAttachmentValidationAndPastedImageSubmission() throws {
        let policy = AIAttachmentPolicy(allowedTypes: [.image], maximumCount: 2, maximumBytes: 1024)
        let image = AIAttachment(name: "pasted.png", byteCount: 512, data: Data([1, 2, 3]), mediaType: "image/png")
        XCTAssertNoThrow(try policy.validate(image, existingCount: 0))
        XCTAssertThrowsError(try policy.validate(image, existingCount: 2))
        XCTAssertThrowsError(try policy.validate(.init(name: "large.png", byteCount: 2048, mediaType: "image/png"), existingCount: 0))
        XCTAssertThrowsError(try policy.validate(.init(name: "script.sh", mediaType: "text/plain"), existingCount: 0))
        XCTAssertTrue(AIPromptSubmission(text: "", attachments: [image], modelID: "", effort: .medium).canSend)
    }
    func testMarkdownTablesTaskListsAndNestedFences() {
        let blocks = MarkdownBlock.parse("- [x] Done\n  - nested\n\n| Name | Value |\n| --- | ---: |\n| a\\|b | 2 |\n\n~~~~swift\n```literal\n~~~~")
        XCTAssertEqual(blocks, [
            .list([.init(depth: 0, marker: "•", text: "Done", checked: true), .init(depth: 1, marker: "•", text: "nested", checked: nil)]),
            .table(["Name", "Value"], [["a|b", "2"]]), .code("swift", "```literal")])
    }
    func testStackFramesPreserveFileLineColumnAndFrameworkGrouping() {
        let frames = AIStackFrame.parse("TypeError: example\n at seedUsers (prisma/seed.ts:27:18)\n at process (node_modules/server/index.js:89:3)")
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].function, "seedUsers")
        XCTAssertEqual(frames[0].file, "prisma/seed.ts")
        XCTAssertEqual(frames[0].line, 27)
        XCTAssertEqual(frames[0].column, 18)
        XCTAssertFalse(frames[0].isFramework)
        XCTAssertTrue(frames[1].isFramework)
    }
    func testSkippedTestsRemainVisibleInSummary() {
        XCTAssertEqual(AITestResults.counts([.init(name: "a", status: .passed), .init(name: "b", status: .failed), .init(name: "c", status: .skipped)]), "3 tests, 1 failed, 1 skipped")
    }
    func testContextFormattingRejectsNonFiniteValues() {
        XCTAssertEqual(AIContextUsage.format(.infinity), "—")
        XCTAssertEqual(AIContextUsage.format(.nan), "—")
    }
    @MainActor func testCitationsWrapUsingNativeTextLayout() {
        #if os(macOS)
        let source = AISource(url: URL(string: "https://example.com")!)
        let view = AICitedText([.text(String(repeating: "A long sentence with a source. ", count: 8)), .source(source), .text(" More text after the inline citation.")])
        let narrow = NSHostingView(rootView: view.frame(width: 240).fixedSize(horizontal: false, vertical: true))
        let wide = NSHostingView(rootView: view.frame(width: 480).fixedSize(horizontal: false, vertical: true))
        XCTAssertGreaterThan(narrow.fittingSize.height, wide.fittingSize.height)
        XCTAssertEqual(narrow.fittingSize.width, 240, accuracy: 1)
        #endif
    }
    @MainActor func testAllPublicPatternsRenderWithEmptyOrErrorData() {
        let views: [AnyView] = [
            AnyView(AIChainOfThought(steps: [], defaultOpen: true)),
            AnyView(AICheckpoint("Saved") {}),
            AnyView(AIConfirmation("Approve?", decision: .constant(.pending))),
            AnyView(AIContext(.init(input: 0, output: 0, limit: 0))),
            AnyView(AIFileTree([])),
            AnyView(AIInlineCitation(sources: [])),
            AnyView(AICitedText([.text("See "), .source(.init(url: URL(string: "https://example.com")!)), .text(" for details.")])),
            AnyView(AIMessage(role: .assistant) { AIMessageResponse("**Hello**") }),
            AnyView(AIModelSelector(models: [], selection: .constant(""), effort: .constant(.medium))),
            AnyView(AIPlan("Empty", steps: [])),
            AnyView(AIPromptInput(text: .constant("")) { _ in }),
            AnyView(AIQueue(items: [])),
            AnyView(AIReasoning("", isStreaming: false)),
            AnyView(AISources([], defaultOpen: true)),
            AnyView(AIStackTrace("Error", defaultOpen: true)),
            AnyView(AISubagent("test", defaultOpen: true) { Text("Done") }),
            AnyView(AISuggestion("Test") { _ in }),
            AnyView(AITask("Task", steps: [])),
            AnyView(AITerminal(command: "test", output: "")),
            AnyView(AITestResults(suites: [])),
            AnyView(AITestResults(suites: [], command: "pnpm test", commandError: "Spawn failed")),
            AnyView(AIChat(messages: [.init(role: .assistant, parts: [.toolApproval(id: "call-1", name: "Run checks")])], onToolApproval: { _, _ in }).frame(height: 300)),
            AnyView(AITool("test", status: .failed, output: "Error", defaultOpen: true)),
            AnyView(AIChat(messages: []).frame(height: 200))
        ]
        for (index, view) in views.enumerated() {
            #if os(macOS)
            let host = NSHostingView(rootView: view.padding(16).frame(width: 350).fixedSize(horizontal: false, vertical: true))
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            XCTAssertNotNil(bitmap, "Pattern \(index) failed to render")
            if let bitmap { host.cacheDisplay(in: host.bounds, to: bitmap) }
            #else
            let host = UIHostingController(rootView: view.padding(16).frame(width: 350))
            let size = host.sizeThatFits(in: CGSize(width: 350, height: 900))
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.layoutIfNeeded()
            XCTAssertGreaterThan(size.height, 0, "Pattern \(index) collapsed")
            let image = UIGraphicsImageRenderer(size: size).image { host.view.layer.render(in: $0.cgContext) }
            XCTAssertNotNil(image.cgImage, "Pattern \(index) failed to render")
            #endif
        }
    }
}
