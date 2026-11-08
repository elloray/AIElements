import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example badge
@MainActor public struct BadgeExample: View {
    @StateObject private var store = AIUIStore()
    public init() {}

    public var body: some View {
        AIUIRenderer(store: store)
            .task { @MainActor in
                do {
                    let data = try AIUIResources.data(named: "badge")
                    try store.load(AIUIDocument.decode(data))
                } catch { store.interrupt(error.localizedDescription) }
            }
    }
}
