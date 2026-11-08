import Foundation
import SwiftUI
import AIElements

/// The host supplies JSONL bytes as they arrive, not a buffered final document.
/// Create a fresh view identity for each request. Wire the stream's onTermination
/// to cancellation of the host network task. No model provider is selected here.
@MainActor public struct StreamingUIExample: View {
    @StateObject private var store = AIUIStore()
    private let chunks: AsyncThrowingStream<Data, Error>
    private let onEvent: (AIUIEvent) -> Void

    public init(chunks: AsyncThrowingStream<Data, Error>, onEvent: @escaping (AIUIEvent) -> Void) {
        self.chunks = chunks
        self.onEvent = onEvent
    }

    public var body: some View {
        AIMessage(role: .assistant) {
            AIUIRenderer(store: store, onEvent: onEvent)
        }
        .task { @MainActor in
            store.reset()
            do {
                for try await chunk in chunks {
                    try Task.checkCancellation()
                    try store.receive(chunk)
                }
                try Task.checkCancellation()
                try store.finish()
                // finish() also marks missing surface.complete as failed.
                // Inspect store.session.phase/errorMessage before persisting success.
            } catch is CancellationError {
                store.interrupt("Generation stopped. Start a new request to retry.")
            } catch {
                store.interrupt(error.localizedDescription)
            }
        }
    }
}
