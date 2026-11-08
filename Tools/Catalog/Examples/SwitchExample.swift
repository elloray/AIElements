import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example switch
@MainActor public struct SwitchExample: View {
    @State private var enabled = false
    public init() {}

    public var body: some View {
        AISwitch("Enable alerts", isOn: $enabled)
    }
}
