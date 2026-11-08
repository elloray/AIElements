import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example stack
@MainActor public struct StackExample: View {
    @StateObject private var store = AIUIStore()
    public init() {}

    public var body: some View {
        AIUIRenderer(store: store)
            .task { @MainActor in
                do {
                    let data = try AIUIResources.data(named: "stack")
                    try store.load(AIUIDocument.decode(data))
                } catch { store.interrupt(error.localizedDescription) }
            }
    }
}
