import SwiftUI
import AIElements

// JSON counterpart: ./aielements ui example table
@MainActor public struct TableExample: View {
    public init() {}

    public var body: some View {
        AITable(columns: [
            .init("name", label: "Product", emphasized: true),
            .init("amount", label: "Amount", width: 100, alignment: .trailing)
        ], rows: [["name": "Subscription", "amount": "$25.00"]],
        caption: "This month’s invoices.", footer: ["name": "Total", "amount": "$25.00"])
    }
}
