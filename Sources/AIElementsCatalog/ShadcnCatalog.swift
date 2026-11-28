import Foundation

/// Components in the official shadcn/ui component indexes, plus four layout/content primitives for composition.
public enum AIShadcnKind: String, CaseIterable, Codable, Sendable {
  case accordion
  case alert
  case alertDialog = "alert-dialog"
  case aspectRatio = "aspect-ratio"
  case attachment
  case avatar
  case badge
  case breadcrumb
  case bubble
  case button
  case buttonGroup = "button-group"
  case calendar
  case card
  case carousel
  case chart
  case checkbox
  case codeBlock = "code-block"
  case collapsible
  case combobox
  case command
  case contextMenu = "context-menu"
  case dataTable = "data-table"
  case datePicker = "date-picker"
  case dialog
  case direction
  case drawer
  case dropdownMenu = "dropdown-menu"
  case empty
  case field
  case hoverCard = "hover-card"
  case input
  case inputGroup = "input-group"
  case inputOtp = "input-otp"
  case item
  case kbd
  case label
  case marker
  case menubar
  case message
  case messageScroller = "message-scroller"
  case nativeSelect = "native-select"
  case navigationMenu = "navigation-menu"
  case pagination
  case popover
  case progress
  case questionnaire
  case radioGroup = "radio-group"
  case resizable
  case scrollArea = "scroll-area"
  case select
  case separator
  case sheet
  case sidebar
  case skeleton
  case slider
  case sonner
  case spinner
  case switchControl = "switch"
  case table
  case tabs
  case textarea
  case toast
  case toggle
  case toggleGroup = "toggle-group"
  case tooltip
  case trace
  case typography
  case column, row, text, image
}

public struct AIShadcnItem: Codable, Hashable, Sendable {
  public var label: String
  public var id: String?
  public var detail: String?
  public var icon: String?
  public var disabled: Bool?
  public var key: String { id ?? label }

  public init(
    _ label: String, id: String? = nil, detail: String? = nil, icon: String? = nil,
    disabled: Bool = false
  ) {
    self.label = label
    self.id = id
    self.detail = detail
    self.icon = icon
    self.disabled = disabled
  }
}

/// Native component configuration. Give interactive children stable IDs when reordering them.
public struct AIShadcnNode: Codable, Hashable, Sendable {
  public var kind: AIShadcnKind
  public var id: String?
  public var label: String?
  public var heading: String?
  public var detail: String?
  public var value: String?
  public var placeholder: String?
  public var action: String?
  public var variant: String?
  public var icon: String?
  public var asset: String?
  public var align: String?
  public var width: Double?
  public var height: Double?
  public var size: Double?
  public var gap: Double?
  public var items: [AIShadcnItem]?
  public var children: [Self]?
  public var columns: [String]?
  public var rows: [[String]]?
  /// Supply unique, nonempty IDs in row order when the host replaces or reorders table data.
  public var rowIDs: [String]?
  /// Zero-based filter column. Omitting it searches all cells.
  public var filterColumn: Int?

  public init(
    _ kind: AIShadcnKind, _ label: String? = nil, id: String? = nil, heading: String? = nil,
    detail: String? = nil, value: String? = nil, placeholder: String? = nil, action: String? = nil,
    variant: String? = nil, icon: String? = nil, asset: String? = nil, align: String? = nil,
    width: Double? = nil, height: Double? = nil, size: Double? = nil, gap: Double? = nil,
    items: [AIShadcnItem]? = nil, children: [Self]? = nil, columns: [String]? = nil,
    rows: [[String]]? = nil, rowIDs: [String]? = nil, filterColumn: Int? = nil
  ) {
    self.kind = kind
    self.label = label
    self.id = id
    self.heading = heading
    self.detail = detail
    self.value = value
    self.placeholder = placeholder
    self.action = action
    self.variant = variant
    self.icon = icon
    self.asset = asset
    self.align = align
    self.width = width
    self.height = height
    self.size = size
    self.gap = gap
    self.items = items
    self.children = children
    self.columns = columns
    self.rows = rows
    self.rowIDs = rowIDs
    self.filterColumn = filterColumn
  }
}

public struct AIShadcnExample: Decodable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let section: String?
  public let selector: String?
  public let root: AIShadcnNode
  public var source: URL {
    URL(
      string: selector
        ?? ("https://ui.shadcn.com/docs/components/base/" + id + (section.map { "#" + $0 } ?? "")))!
  }
}

public enum AIShadcnCatalog {
  public static let examples: [AIShadcnExample] = {
    guard let url = Bundle.module.url(forResource: "shadcn-catalog", withExtension: "json") else {
      preconditionFailure("Missing bundled shadcn catalog")
    }
    do {
      return try JSONDecoder().decode([AIShadcnExample].self, from: Data(contentsOf: url))
    } catch { preconditionFailure("Invalid bundled shadcn catalog: \(error)") }
  }()
}
