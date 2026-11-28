import AIElementsCatalog
import Foundation

/// Emit pasteable SwiftUI examples from the same configuration the native galleries render.
enum ShadcnExampleSource {
  static func file(_ entry: AIShadcnExample, type: String) -> String {
    """
    import SwiftUI
    import AIElements

    public struct \(type): View {
        @State private var values: [String: String] = [:]
        public init() {}

        public var body: some View {
            AIShadcnView(\(expression(entry.root, indent: "            ")), values: $values)
        }
    }
    """
  }
  private static func quoted(_ string: String) -> String { String(reflecting: string) }
  private static func expression(_ node: AIShadcnNode, indent: String) -> String {
    let raw = node.kind.rawValue.split(separator: "-")
    let name =
      node.kind == .switchControl
      ? "switchControl" : String(raw[0]) + raw.dropFirst().map { $0.capitalized }.joined()
    var args = ["." + name]
    if let label = node.label { args.append(quoted(label)) }
    let strings: [(String, String?)] = [
      ("id", node.id), ("heading", node.heading), ("detail", node.detail),
      ("value", node.value), ("placeholder", node.placeholder), ("action", node.action),
      ("variant", node.variant),
      ("icon", node.icon), ("asset", node.asset), ("align", node.align),
    ]
    for (key, value) in strings { if let value { args.append(key + ": " + quoted(value)) } }
    for (key, value) in [
      ("width", node.width), ("height", node.height), ("size", node.size), ("gap", node.gap),
    ] {
      if let value { args.append("\(key): \(value)") }
    }
    let inner = indent + "    "
    if let items = node.items {
      args.append(
        "items: [\n"
          + items.map { item in
            var fields = [quoted(item.label)]
            for (key, value) in [("id", item.id), ("detail", item.detail), ("icon", item.icon)] {
              if let value { fields.append(key + ": " + quoted(value)) }
            }
            if item.disabled == true { fields.append("disabled: true") }
            return inner + ".init(" + fields.joined(separator: ", ") + ")"
          }.joined(separator: ",\n") + "\n" + indent + "]")
    }
    if let children = node.children {
      args.append(
        "children: [\n"
          + children.map { inner + expression($0, indent: inner) }.joined(separator: ",\n") + "\n"
          + indent + "]")
    }
    if let columns = node.columns {
      args.append("columns: [" + columns.map(quoted).joined(separator: ", ") + "]")
    }
    if let rows = node.rows {
      args.append(
        "rows: [\n"
          + rows.map { inner + "[" + $0.map(quoted).joined(separator: ", ") + "]" }.joined(
            separator: ",\n") + "\n" + indent + "]")
    }
    if let ids = node.rowIDs {
      args.append("rowIDs: [" + ids.map(quoted).joined(separator: ", ") + "]")
    }
    if let index = node.filterColumn { args.append("filterColumn: \(index)") }
    return ".init(" + args.joined(separator: ", ") + ")"
  }
}
