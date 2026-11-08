import SwiftUI
import AIElements

public struct CheckpointExample: View {
    @State private var restored = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading) {
            AICheckpoint("Saved draft", isEnabled: !restored) { restored = true }
            if restored { Text("Restore requested (demo)") }
        }
    }
}
