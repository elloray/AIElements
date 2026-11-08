import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct AIModelSelector: View {
    public var models: [AIModel]
    @Binding public var selection: String
    @Binding public var effort: AIEffort
    public var showEffort: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(models: [AIModel], selection: Binding<String>, effort: Binding<AIEffort>, showEffort: Bool = true) {
        self.models = models; self._selection = selection; self._effort = effort; self.showEffort = showEffort
    }
    private var selected: AIModel? { AIModel.selected(in: models, id: selection) }
    private var efforts: [AIEffort] { selected?.supportedEfforts ?? [] }
    public var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { menus(stacked: true) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { menus(stacked: false) }.fixedSize()
                    VStack(alignment: .leading, spacing: 4) { menus(stacked: true) }
                }
            }
        }
        .onChange(of: selection) { reconcileSelection() }
        .onChange(of: models, initial: true) { reconcileSelection() }
    }
    @ViewBuilder private func menus(stacked: Bool) -> some View {
        AIChoiceMenu(title: selected?.name ?? "No models", accessibilityLabel: "Model: \(selected?.name ?? "No models")", choices: models.map { .init(id: $0.id, title: $0.name, group: $0.provider) }, selected: selected?.id ?? "", expandedLabel: stacked) { id in
            selection = id; reconcileEffort(models.first { $0.id == id }?.supportedEfforts ?? [])
        }
        if showEffort && !efforts.isEmpty {
            AIChoiceMenu(title: effort.rawValue.capitalized, accessibilityLabel: "Reasoning effort: \(effort.rawValue.capitalized)", choices: efforts.map { .init(id: $0.rawValue, title: $0.rawValue.capitalized) }, selected: effort.rawValue, expandedLabel: stacked, prefix: "Effort") { id in if let value = AIEffort(rawValue: id) { effort = value } }
        }
    }
    private func reconcileSelection() {
        let id = selected?.id ?? ""
        if selection != id { selection = id }
        reconcileEffort(efforts)
    }
    private func reconcileEffort(_ supported: [AIEffort]) { if !supported.contains(effort), let first = supported.first { effort = first } }
}
public struct AIAttachmentView: View {
    public var attachment: AIAttachment
    public var onRemove: (() -> Void)?
    @Theme private var theme
    public init(_ attachment: AIAttachment, onRemove: (() -> Void)? = nil) { self.attachment = attachment; self.onRemove = onRemove }
    public var body: some View {
        HStack(spacing: 8) {
            preview
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name).lineLimit(1)
                if let bytes = attachment.byteCount { Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)).aiFont(10).foregroundStyle(theme.mutedForeground) }
            }
            if let onRemove { Button(action: onRemove) { AIIcon(.x, size: 12) }.buttonStyle(AIButtonStyle(.ghost, size: .iconSmall)).accessibilityLabel("Remove \(attachment.name)") }
        }.aiFont(12).padding(8).foregroundStyle(theme.foreground).background(theme.muted, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border, lineWidth: 1))
    }
    @ViewBuilder private var preview: some View {
        if let data = attachment.data {
            #if os(macOS)
            if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFill().frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 4)) }
            else { AIIcon(.file, size: 14) }
            #else
            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 4)) }
            else { AIIcon(.file, size: 14) }
            #endif
        } else { AIIcon(attachment.mediaType?.hasPrefix("text/") == true ? .fileText : .file, size: 14) }
    }
}
public enum AIPromptStatus: Sendable { case ready, submitted, streaming, failed }
public struct AIPromptSubmission: Sendable {
    public var text: String
    public var attachments: [AIAttachment]
    public var modelID: String
    public var effort: AIEffort
    public init(text: String, attachments: [AIAttachment], modelID: String, effort: AIEffort) {
        self.text = text; self.attachments = attachments; self.modelID = modelID; self.effort = effort
    }
    public var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty }
}
public struct AIAttachmentPolicy {
    public var allowedTypes: [UTType]
    public var maximumCount: Int?
    public var maximumBytes: Int64?
    public init(allowedTypes: [UTType] = [.item], maximumCount: Int? = nil, maximumBytes: Int64? = nil) {
        self.allowedTypes = allowedTypes; self.maximumCount = maximumCount; self.maximumBytes = maximumBytes
    }
    public func validate(_ attachment: AIAttachment, existingCount: Int) throws {
        if let maximumCount, existingCount >= maximumCount { throw AIAttachmentError("You can attach up to \(maximumCount) files.") }
        if let maximumBytes, let bytes = attachment.byteCount, bytes > maximumBytes { throw AIAttachmentError("\(attachment.name) exceeds the file size limit.") }
        if !allowedTypes.contains(.item) {
            let type = attachment.mediaType.flatMap { UTType(mimeType: $0) } ?? attachment.url.flatMap { UTType(filenameExtension: $0.pathExtension) }
            guard let type, allowedTypes.contains(where: { type.conforms(to: $0) }) else { throw AIAttachmentError("\(attachment.name) is not a supported file type.") }
        }
    }
}
public struct AIAttachmentError: LocalizedError { public let message: String; public init(_ message: String) { self.message = message }; public var errorDescription: String? { message } }
/// Attachments/model/effort may be controlled by bindings or owned internally.
public struct AIPromptInput: View {
    @Binding public var text: String
    private var externalAttachments: Binding<[AIAttachment]>?
    private var externalModel: Binding<String>?
    private var externalEffort: Binding<AIEffort>?
    @State private var localAttachments: [AIAttachment] = []
    @State private var localModel: String
    @State private var localEffort = AIEffort.medium
    public var models: [AIModel]
    public var status: AIPromptStatus
    public var placeholder: String
    /// Chat uses smaller text insets; controls retain their full touch targets.
    public var compact: Bool
    public var errorMessage: String?
    public var attachmentPolicy: AIAttachmentPolicy
    public var attachmentResetID: AnyHashable
    public var onSubmit: (AIPromptSubmission) -> Void
    public var onStop: () -> Void
    public var onAttach: (() -> Void)?
    public var onAttachmentError: (Error) -> Void
    @State private var importing = false
    @State private var focused = false
    @State private var attachmentError: String?
    @Theme private var theme
    public init(text: Binding<String>, attachments: Binding<[AIAttachment]>? = nil, models: [AIModel] = [],
                modelID: Binding<String>? = nil, effort: Binding<AIEffort>? = nil,
                status: AIPromptStatus = .ready, placeholder: String = "Ask the agent to change your code...",
                errorMessage: String? = nil, sendButtonColor: Color? = nil, attachmentPolicy: AIAttachmentPolicy = .init(), attachmentResetID: AnyHashable = 0, compact: Bool = false,
                onAttach: (() -> Void)? = nil, onAttachmentError: @escaping (Error) -> Void = { _ in },
                onStop: @escaping () -> Void = {}, onSubmit: @escaping (AIPromptSubmission) -> Void) {
        self.sendButtonColor = sendButtonColor
        self.compact = compact
        self._text = text; self.externalAttachments = attachments; self.models = models; self.externalModel = modelID; self.externalEffort = effort
        self._localModel = State(initialValue: models.first?.id ?? "")
        self.status = status; self.placeholder = placeholder; self.errorMessage = errorMessage; self.attachmentPolicy = attachmentPolicy; self.attachmentResetID = attachmentResetID
        self.onAttach = onAttach; self.onAttachmentError = onAttachmentError; self.onStop = onStop; self.onSubmit = onSubmit
    }
    private var attachments: Binding<[AIAttachment]> { externalAttachments ?? $localAttachments }
    private var model: Binding<String> { externalModel ?? $localModel }
    private var effort: Binding<AIEffort> { externalEffort ?? $localEffort }
    @Environment(\.aiControlDensity) private var density
    public var sendButtonColor: Color?
    private var comfortable: Bool { density == .comfortable }
    private var busy: Bool { status == .streaming || status == .submitted }
    var submission: AIPromptSubmission {
        let selected = AIModel.selected(in: models, id: model.wrappedValue)
        return .init(text: text, attachments: attachments.wrappedValue,
                     modelID: selected?.id ?? (externalModel?.wrappedValue ?? ""),
                     effort: selected?.resolvedEffort(effort.wrappedValue) ?? effort.wrappedValue)
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: comfortable ? (compact ? 6 : 12) : (compact ? 12 : 18)) {
                if !attachments.wrappedValue.isEmpty {
                    AIHorizontalScroll { HStack(spacing: 8) { ForEach(attachments.wrappedValue) { attachment in AIAttachmentView(attachment) { attachments.wrappedValue.removeAll { $0.id == attachment.id } } } } }.padding(.horizontal, compact ? 11 : 13).padding(.bottom, 8)
                }
                AIPromptEditor(text: $text, foreground: theme.foreground, onSend: send, onFocus: { focused = $0 }, onFiles: importFiles, onImage: importImage)
                    .frame(minHeight: 40)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty { AITextLabel(placeholder, size: 16, color: theme.mutedForeground).frame(minHeight: 24).allowsHitTesting(false) }
                    }.padding(.horizontal, compact ? 11 : 13).accessibilityLabel("Message")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: comfortable ? 2 : 8) { attachButton; Spacer(minLength: 0); selector.fixedSize(horizontal: true, vertical: true); sendButton }
                    VStack(alignment: .leading, spacing: 8) {
                        selector
                        HStack { attachButton; Spacer(); sendButton }
                    }
                }.padding(.horizontal, comfortable ? 5 : 11)
            }.padding(.top, compact ? 9 : 13)
                .padding(.bottom, comfortable ? 3 : 9).background(theme.inputBackground, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(focused ? theme.mutedForeground.opacity(0.6) : .clear, lineWidth: focused ? 2 : 1))
                .dropDestination(for: URL.self) { urls, _ in importFiles(urls); return !urls.isEmpty }
            if let message = attachmentError ?? errorMessage ?? (status == .failed ? "Could not send. Your message is ready to retry." : nil) {
                Text(message).aiFont(12).foregroundStyle(theme.destructive).accessibilityLabel("Error: \(message)")
            }
        }.onChange(of: attachmentResetID) { _, _ in if externalAttachments == nil { localAttachments = [] } }
        .onChange(of: models) { previous, current in
            if !previous.isEmpty && current.isEmpty { model.wrappedValue = "" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: attachmentPolicy.allowedTypes, allowsMultipleSelection: true) { result in
            switch result { case .success(let urls): importFiles(urls); case .failure(let error): report(error) }
        }
    }
    @ViewBuilder private var selector: some View { if !models.isEmpty { AIModelSelector(models: models, selection: model, effort: effort) } }
    private var attachButton: some View {
        Button { if let onAttach { onAttach() } else { importing = true } } label: { AIIcon(.plus).foregroundStyle(theme.mutedForeground) }
            .buttonStyle(AIButtonStyle(.outline, size: .icon)).accessibilityLabel("Attach files").help("Attach files")
    }
    private var sendButton: some View {
        Button { if busy { onStop() } else { send() } } label: {
            if status == .submitted { AISpinner() } else { AIIcon(busy ? .square : .arrowUp, size: busy ? 12 : 16) }
        }.buttonStyle(AIButtonStyle(.primary, size: .icon, fill: sendButtonColor)).disabled(!busy && !submission.canSend)
            .accessibilityLabel(busy ? "Stop generating" : "Send message").help(busy ? "Stop generating" : "Send message (Enter)")
    }
    private func send() { guard !busy, submission.canSend else { return }; attachmentError = nil; onSubmit(submission) }
    private func append(_ attachment: AIAttachment) {
        do { try attachmentPolicy.validate(attachment, existingCount: attachments.wrappedValue.count); attachments.wrappedValue.append(attachment) }
        catch { report(error) }
    }
    private func importFiles(_ urls: [URL]) {
        attachmentError = nil
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isDirectoryKey])
                guard values.isDirectory != true else { throw AIAttachmentError("Choose a file rather than a folder.") }
                var attachment = AIAttachment(name: url.lastPathComponent, url: url, byteCount: values.fileSize.map(Int64.init), mediaType: values.contentType?.preferredMIMEType)
                try attachmentPolicy.validate(attachment, existingCount: attachments.wrappedValue.count)
                // Bounded image previews; the host still owns reading/uploading full files.
                if values.contentType?.conforms(to: .image) == true, (values.fileSize ?? Int.max) <= 8_000_000 { attachment.data = try? Data(contentsOf: url) }
                attachments.wrappedValue.append(attachment)
            } catch { report(error) }
        }
    }
    private func importImage(_ data: Data) { attachmentError = nil; append(.init(name: "Pasted image.png", byteCount: Int64(data.count), data: data, mediaType: "image/png")) }
    private func report(_ error: Error) { attachmentError = error.localizedDescription; onAttachmentError(error) }
}
