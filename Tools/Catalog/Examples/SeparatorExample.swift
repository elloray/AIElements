import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example separator
@MainActor public struct SeparatorExample: View {
    @StateObject private var store = AIUIStore()
    public init() {}

    public var body: some View {
        AIUIRenderer(store: store)
            .task { @MainActor in
                do {
                    let data = try AIUIResources.data(named: "separator")
                    try store.load(AIUIDocument.decode(data))
                } catch { store.interrupt(error.localizedDescription) }
            }
    }
}
