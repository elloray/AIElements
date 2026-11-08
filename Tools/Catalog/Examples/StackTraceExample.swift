import SwiftUI
import AIElements

public struct StackTraceExample: View {
    @State private var selectedFrame = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading) {
            AIStackTrace("Error: Request failed\n    at loadData (src/client.ts:12:4)", defaultOpen: true, onOpenFrame: { frame in
                selectedFrame = "\(frame.file ?? "unknown"):\(frame.line ?? 0)"
            })
            Text(selectedFrame)
        }
    }
}
