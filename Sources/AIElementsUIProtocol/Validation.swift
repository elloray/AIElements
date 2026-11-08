import Foundation

public enum AIUIComponentCatalog {
    public static let types = ["Stack", "Row", "Card", "Text", "Button", "Badge", "Input", "Select", "Switch", "Progress", "Separator", "Table", "BarChart", "LineChart", "AreaChart"]
    static let properties: [String: Set<String>] = [
        "Stack": ["gap"], "Row": ["gap"],
        "Card": ["title", "description", "footer", "footerIcon", "footnote"],
        "Text": ["text", "variant"], "Button": ["label", "variant", "disabled"],
        "Badge": ["text", "variant"], "Input": ["label", "placeholder", "value", "disabled"],
        "Select": ["label", "value", "options", "disabled"], "Switch": ["label", "value", "disabled"],
        "Progress": ["label", "value", "max"], "Separator": [],
        "Table": ["columns", "rows", "caption"],
        "BarChart": ["data", "series", "height", "label", "legend"],
        "LineChart": ["data", "series", "height", "label", "legend"],
        "AreaChart": ["data", "series", "height", "label", "legend"]
    ]
}

extension AIUIDocument {
    public func validate(allowIncomplete: Bool = false) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw AIUIError.invalid(message) }
        }
        try require(version == "1.0", "Unsupported UI version: \(version)")
        try require(!id.isEmpty && id.count <= 128 && !root.isEmpty && root.count <= 128 && (0...9_007_199_254_740_991).contains(revision), "Invalid surface identity/revision.")
        try require(nodes.count <= 256 && state.count <= 256, "A surface is limited to 256 nodes and 256 state keys.")
        if !allowIncomplete { try require(nodes[root] != nil, "Missing root node: \(root)") }
        for value in state.values { try validateValue(value, depth: 0) }
        for (id, node) in nodes {
            try require(!id.isEmpty && id.count <= 128, "Invalid node ID.")
            guard let allowed = AIUIComponentCatalog.properties[node.type] else { throw AIUIError.invalid("Unsupported component: \(node.type)") }
            let supplied = Set((node.props ?? [:]).keys).union((node.bindings ?? [:]).keys)
            try require(supplied.isSubset(of: allowed), "Unknown property on \(id).")
            for value in (node.props ?? [:]).values { try validateValue(value, depth: 0) }
            for key in (node.bindings ?? [:]).values {
                try require(!key.isEmpty && key.count <= 128, "Invalid state binding on \(id).")
                if !allowIncomplete { try require(state[key] != nil, "Missing state key: \(key)") }
            }
            let children = node.children ?? []
            try require(Set(children).count == children.count && children.count <= 256, "Duplicate/excessive children on \(id).")
            try require(children.isEmpty || ["Stack", "Row", "Card"].contains(node.type), "\(node.type) cannot contain children.")
            for (event, action) in node.events ?? [:] {
                let supported = node.type == "Button" ? ["press"] : ["Input", "Select", "Switch"].contains(node.type) ? ["change"] : node.type.hasSuffix("Chart") ? ["select"] : []
                try require(supported.contains(event), "Unsupported event \(event) on \(id).")
                try require(!action.name.isEmpty && action.name.count <= 128, "Invalid action name.")
                try require((action.stateKeys ?? []).count <= 256, "Too many action state keys.")
                for value in (action.payload ?? [:]).values { try validateValue(value, depth: 0) }
            }
            try validateProps(node.resolved(in: state), type: node.type, id: id, allowIncomplete: allowIncomplete)
        }
        var visiting = Set<String>(), visited = Set<String>(), parents: [String: String] = [:]
        func walk(_ id: String, depth: Int) throws {
            try require(depth <= 32, "UI nesting exceeds 32 levels.")
            try require(!visiting.contains(id), "Cycle at node: \(id)")
            if visited.contains(id) { return }
            guard let node = nodes[id] else {
                try require(allowIncomplete, "Missing child node: \(id)"); return
            }
            visiting.insert(id)
            for child in node.children ?? [] {
                if let parent = parents[child] { try require(parent == id, "Node \(child) has multiple parents.") }
                parents[child] = id
                try walk(child, depth: depth + 1)
            }
            visiting.remove(id); visited.insert(id)
        }
        try walk(root, depth: 0)
        // Validate staged nodes too, even before a parent references them.
        for id in nodes.keys where !visited.contains(id) { try walk(id, depth: 0) }
    }
}

private func validateValue(_ value: AIUIValue, depth: Int) throws {
    guard depth <= 16 else { throw AIUIError.invalid("Value nesting exceeds 16 levels.") }
    switch value {
    case .number(let number): guard number.isFinite && abs(number) <= 1e15 else { throw AIUIError.invalid("Number is outside the supported range.") }
    case .string(let string): guard string.utf8.count <= 32_768 else { throw AIUIError.invalid("Text exceeds 32 KiB.") }
    case .array(let values):
        guard values.count <= 1_000 else { throw AIUIError.invalid("Array exceeds 1000 entries.") }
        for value in values { try validateValue(value, depth: depth + 1) }
    case .object(let values):
        guard values.count <= 256 else { throw AIUIError.invalid("Object exceeds 256 keys.") }
        for (key, value) in values {
            guard key.count <= 128 else { throw AIUIError.invalid("Object key exceeds 128 characters.") }
            try validateValue(value, depth: depth + 1)
        }
    default: break
    }
}

private func validateProps(_ props: [String: AIUIValue], type: String, id: String, allowIncomplete: Bool) throws {
    func fail(_ message: String) -> AIUIError { .invalid("\(id): \(message)") }
    if let icon = props["footerIcon"], icon.string != "trending-up" { throw fail("Unknown footerIcon.") }
    let text = Set(["title", "description", "footer", "footerIcon", "footnote", "text", "variant", "label", "placeholder", "caption"])
    for (key, value) in props {
        if text.contains(key), value.string == nil { throw fail("\(key) must be text.") }
        if ["disabled", "legend"].contains(key), value.bool == nil { throw fail("\(key) must be boolean.") }
        if ["height", "gap", "max"].contains(key), value.number == nil { throw fail("\(key) must be numeric.") }
    }
    if let height = props["height"]?.number, !(120...600).contains(height) { throw fail("height must be 120...600.") }
    if let gap = props["gap"]?.number, !(0...48).contains(gap) { throw fail("gap must be 0...48.") }
    if let variant = props["variant"]?.string {
        let variants = type == "Text" ? ["body", "title", "caption", "muted"] : ["primary", "secondary", "outline", "ghost", "destructive"]
        guard variants.contains(variant) else { throw fail("Unknown variant.") }
    }
    if let value = props["value"] {
        let valid = type == "Switch" ? value.bool != nil : type == "Progress" ? value.number != nil : value.string != nil
        guard valid else { throw fail("Invalid value type.") }
    }
    if type == "Progress" {
        let max = props["max"]?.number ?? 100
        guard max > 0 else { throw fail("max must be positive.") }
        if let value = props["value"]?.number, value < 0 || value > max { throw fail("Progress value must lie between 0 and max.") }
    }
    if type == "Select", let options = props["options"] {
        guard let array = options.array, array.count <= 100 else { throw fail("options must be an array of up to 100 items.") }
        var ids = Set<String>()
        for option in array {
            guard let item = option.object, item["label"]?.string != nil, let value = item["value"]?.string, ids.insert(value).inserted else { throw fail("Options require unique values and labels.") }
        }
        if let value = props["value"]?.string, !value.isEmpty, !ids.contains(value) { throw fail("Selected value is absent from options.") }
    }
    if type.hasSuffix("Chart") {
        if let series = props["series"] {
            guard let array = series.array, !array.isEmpty, array.count <= 5 else { throw fail("Chart series must contain 1...5 entries.") }
            var ids = Set<String>()
            for series in array {
                guard let item = series.object, let key = item["key"]?.string, key != "label", ids.insert(key).inserted,
                      item["label"]?.string != nil else { throw fail("Chart series require unique keys and labels.") }
            }
        }
        if let data = props["data"] {
            guard let rows = data.array, rows.count <= 200 else { throw fail("Chart data must contain at most 200 rows.") }
            var labels = Set<String>()
            for row in rows {
                guard let row = row.object, let label = row["label"]?.string, labels.insert(label).inserted else { throw fail("Chart rows require unique labels.") }
                for series in props["series"]?.array ?? [] {
                    guard let key = series.object?["key"]?.string, row[key]?.number != nil else { throw fail("Chart row is missing a numeric series value.") }
                }
            }
        }
        if !allowIncomplete, props["series"] == nil || props["data"] == nil { throw fail("Chart requires series and data.") }
    }
    if type == "Table" {
        if let columns = props["columns"] {
            guard let array = columns.array, !array.isEmpty, array.count <= 12 else { throw fail("Table requires 1...12 columns.") }
            var keys = Set<String>()
            for column in array {
                guard let item = column.object, let key = item["key"]?.string, keys.insert(key).inserted, item["label"]?.string != nil else { throw fail("Table columns require unique keys and labels.") }
            }
        }
        if let rows = props["rows"], rows.array == nil || rows.array!.contains(where: { $0.object == nil }) { throw fail("Table rows must be objects.") }
    }
}
