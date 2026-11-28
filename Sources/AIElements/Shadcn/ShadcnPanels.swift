import SwiftUI

private struct ShadcnTableRow: Identifiable {
  let id: String
  let index: Int
  let cells: [String]
}

extension ShadcnPart {
  @ViewBuilder var overlayControl: some View {
    switch node.kind {
    case .datePicker:
      VStack(alignment: .leading, spacing: 6) {
        if !label.isEmpty { Text(label).aiFont(14, weight: .medium) }
        Button {
          showing = true
        } label: {
          Text(
            dateFromValue?.formatted(date: .long, time: .omitted) ?? node.placeholder
              ?? "Pick a date"
          ).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(AIFoundationButtonStyle(.outline)).popover(isPresented: $showing) {
          calendarPage.padding(4).presentationCompactAdaptation(.popover)
        }
      }
    case .tooltip, .hoverCard, .popover:
      button(label, variant: node.kind == .hoverCard ? "ghost" : "outline") { showing.toggle() }
        .onHover { inside in if node.kind != .popover { showing = inside } }
        .popover(isPresented: $showing) {
          VStack(alignment: .leading, spacing: 5) {
            if let heading = node.heading { Text(heading).aiFont(14, weight: .semibold) }
            Text(detail).aiFont(node.kind == .tooltip ? 12 : 14)
            if let meta = node.value {
              Text(meta).aiFont(12).foregroundStyle(theme.mutedForeground)
            }
            parts
          }.padding(node.kind == .tooltip ? 8 : 16).frame(
            idealWidth: node.kind == .tooltip ? nil : 256
          )
          .presentationCompactAdaptation(.popover)
        }
    case .toast:
      VStack(spacing: 10) {
        button(label) {
          showing = true
          toastRevision += 1
        }
        if showing {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text(node.heading ?? label).aiFont(14, weight: .medium)
              hint
            }
            if let command = node.action {
              button(command) {
                activate(command)
                showing = false
              }
            }
          }.padding(12).shadcnBox(theme.cardBackground, stroke: theme.border, radius: 12)
            .accessibilityElement(children: .contain)
        }
      }.task(id: toastRevision) {
        guard showing else { return }
        do {
          try await Task.sleep(for: .seconds(5))
          showing = false
        } catch {}
      }
    case .drawer:
      button(label, variant: "secondary") { showing = true }
        .sheet(isPresented: $showing) {
          modalBody.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    case .alertDialog, .dialog, .sheet:
      #if os(iOS)
        button(label) { showing = true }
          .fullScreenCover(isPresented: $showing) {
            GeometryReader { geometry in
              let side = node.kind == .sheet
              ZStack(alignment: side ? .trailing : .center) {
                Color.black.opacity(0.48).ignoresSafeArea().onTapGesture {
                  if node.kind != .alertDialog { showing = false }
                }
                ScrollView { modalBody }
                  .scrollBounceBehavior(.basedOnSize)
                  .frame(maxWidth: min(384, max(1, geometry.size.width - (side ? 48 : 32))))
                  .fixedSize(horizontal: false, vertical: !side)
                  .frame(maxHeight: side ? .infinity : nil, alignment: .topLeading)
                  .shadcnBox(theme.cardBackground, stroke: theme.border, radius: side ? 0 : 14)
              }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.presentationBackground(.clear)
          }
      #else
        button(label) { showing = true }.sheet(isPresented: $showing) {
          modalBody.frame(minWidth: 320, idealWidth: 384)
        }
      #endif
    default: EmptyView()
    }
  }

  var sonner: some View {
    VStack(alignment: .trailing, spacing: 8) {
      button(label) { notices = Array(notices.suffix(2)) + [UUID()] }
      ForEach(notices.suffix(3), id: \.self) { id in
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(node.heading ?? label).aiFont(14, weight: .medium)
            if !detail.isEmpty { Text(detail).aiFont(13).foregroundStyle(theme.mutedForeground) }
          }.frame(maxWidth: .infinity, alignment: .leading)
          if let title = node.action {
            button(title, variant: "primary") {
              activate(title)
              notices.removeAll { $0 == id }
            }
          }
        }.padding(12).frame(maxWidth: 356).shadcnBox(
          theme.cardBackground, stroke: theme.border, radius: 10
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Dismiss") { notices.removeAll { $0 == id } }
        .task {
          do {
            try await Task.sleep(for: .seconds(4))
            notices.removeAll { $0 == id }
          } catch {}
        }
      }
    }
  }

  private var modalBody: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        Text(node.heading ?? label).aiFont(18, weight: .semibold).accessibilityAddTraits(.isHeader)
        Spacer()
        if node.kind == .dialog || node.kind == .sheet {
          iconButton(.x, "Close") { showing = false }
        }
      }
      if !detail.isEmpty { hint }
      parts
      HStack(spacing: 8) {
        Spacer()
        button("Cancel") { showing = false }.keyboardShortcut(.cancelAction)
        if let cmd = node.action {
          button(cmd, variant: "primary") {
            activate(cmd)
            showing = false
          }
        }
      }
    }.padding(20).foregroundStyle(theme.foreground).background(theme.cardBackground)
  }

  private var gregorian: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    return calendar
  }
  private var dateFromValue: Date? {
    let pieces = value.split(separator: "-", omittingEmptySubsequences: false)
    guard pieces.map(\.count) == [4, 2, 2], let year = Int(pieces[0]), let month = Int(pieces[1]),
      let day = Int(pieces[2]),
      let date = gregorian.date(from: DateComponents(year: year, month: month, day: day)),
      dateID(date) == value
    else { return nil }
    return date
  }
  private func dateID(_ date: Date) -> String {
    let c = gregorian.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
  var calendarPage: some View {
    let cal = gregorian
    let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
    let offset = cal.component(.weekday, from: first) - 1
    let count = cal.range(of: .day, in: .month, for: first)!.count
    let cells = ((count + offset + 6) / 7) * 7
    return VStack(spacing: 4) {
      HStack {
        iconButton(.chevronLeft, "Previous month") {
          if let d = cal.date(byAdding: .month, value: -1, to: first) { month = d }
        }
        Spacer()
        Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_US"))))
          .aiFont(14, weight: .medium)
        Spacer()
        iconButton(.chevronRight, "Next month") {
          if let d = cal.date(byAdding: .month, value: 1, to: first) { month = d }
        }
      }
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 7)
      {
        ForEach(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"], id: \.self) {
          Text($0).aiFont(12).foregroundStyle(theme.mutedForeground).frame(height: 26)
        }
        ForEach(0..<cells, id: \.self) { i in
          let date = cal.date(byAdding: .day, value: i - offset, to: first)!
          let id = dateID(date)
          let outside = !cal.isDate(date, equalTo: first, toGranularity: .month)
          Button {
            set(id)
            month = date
            if node.kind == .datePicker { showing = false }
          } label: {
            Text(String(cal.component(.day, from: date))).aiFont(14)
              .frame(maxWidth: .infinity, minHeight: 28)
              .foregroundStyle(
                value == id ? onPrimary : outside ? theme.mutedForeground : theme.foreground
              )
              .background(
                value == id ? primary : cal.isDateInToday(date) ? theme.muted : .clear,
                in: RoundedRectangle(cornerRadius: 8))
          }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(id == value ? .isSelected : [])
        }
      }
    }.padding(10).frame(
      maxWidth: node.width == nil || node.kind == .datePicker ? 214 : CGFloat(node.width ?? 214)
    )
    .shadcnBox(theme.background, stroke: theme.border, radius: 10)
    .onChange(of: dateFromValue, initial: true) { _, date in if let date { month = date } }
  }

  func iconButton(
    _ glyph: AIIconName, _ title: String, enabled: Bool = true, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) { AIIcon(glyph).frame(width: 28, height: 28).contentShape(Rectangle()) }
      .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.45).accessibilityLabel(title)
  }

  var navigation: some View {
    Group {
      if node.kind == .sidebar {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            if !showing {
              Text(label).aiFont(12, weight: .medium).foregroundStyle(theme.mutedForeground)
              Spacer()
            }
            iconButton(.panelLeft, "Toggle sidebar") { showing.toggle() }
          }
          ForEach(items, id: \.key) { item in
            Button {
              set(item.key)
            } label: {
              HStack(spacing: 8) {
                icon(item.icon)
                if !showing {
                  Text(item.label)
                  Spacer()
                }
              }
              .padding(.horizontal, 8).frame(minHeight: 32).background(
                value == item.key ? theme.muted : .clear, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).disabled(item.disabled == true).accessibilityLabel(item.label)
          }
        }.padding(8).frame(maxWidth: showing ? 48 : .infinity, alignment: .leading).background(
          theme.muted.opacity(0.55))
      } else {
        AIFlowLayout(spacing: 2, fitsContent: true) {
          ForEach(Array(children.enumerated()), id: \.offset) { index, menu in
            if menu.kind == .button {
              child(index)
            } else {
              Menu {
                ForEach(menu.items ?? [], id: \.key) { item in
                  Button(item.label) {
                    let key = menu.id ?? "\(path)/\(index)"
                    values[key] = item.key
                    action(key, item.key)
                  }.disabled(item.disabled == true)
                }
              } label: {
                HStack(spacing: 4) {
                  Text(menu.label ?? "").aiFont(14, weight: .medium)
                  if node.kind == .navigationMenu { AIIcon(.chevronDown, size: 12) }
                }.padding(.horizontal, 6).frame(minHeight: 26)
              }
              .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
          }
        }.padding(3).shadcnBox(
          theme.background, stroke: node.kind == .menubar ? theme.border : .clear, radius: 10)
      }
    }
  }

  var carousel: some View {
    let index = min(max(0, Int(value) ?? 0), max(0, max(items.count, children.count) - 1))
    let count = max(items.count, children.count)
    return ZStack {
      Color.clear.aspectRatio(1, contentMode: .fit).padding(.vertical, 16).overlay {
        if children.indices.contains(index) {
          child(index)
        } else if items.indices.contains(index) {
          Text(items[index].label).aiFont(36, weight: .semibold)
        }
      }.frame(height: node.height.map { CGFloat($0) }).shadcnBox(
        theme.cardBackground, stroke: theme.border, radius: 14
      )
      .padding(4).frame(maxWidth: 320).padding(.horizontal, 20)
      .contentShape(Rectangle()).gesture(
        DragGesture(minimumDistance: 20).onEnded { d in
          let delta = d.translation.width * (direction == .rightToLeft ? -1 : 1)
          if abs(delta) > abs(d.translation.height), count > 0 {
            set(String(min(count - 1, max(0, index + (delta < 0 ? 1 : -1)))))
          }
        })
      HStack {
        iconButton(.arrowLeft, "Previous slide", enabled: index > 0) { set(String(index - 1)) }
          .shadcnBox(theme.background, stroke: theme.border, radius: 30)
        Spacer()
        iconButton(.arrowRight, "Next slide", enabled: index + 1 < count) { set(String(index + 1)) }
          .shadcnBox(theme.background, stroke: theme.border, radius: 30)
      }
    }
  }
  var resizable: some View {
    GeometryReader { g in
      let fraction = min(0.9, max(0.1, (Double(value) ?? 50) / 100))
      HStack(spacing: 0) {
        if !children.isEmpty { child(0).frame(width: max(0, (g.size.width - 1) * fraction)) }
        Rectangle().fill(theme.border).frame(width: 1).overlay {
          AIIcon(.gripVertical, size: 12).frame(width: 10, height: 16).background(
            theme.background, in: Capsule()
          )
          .overlay(Capsule().strokeBorder(theme.border)).frame(width: 28, height: 40).contentShape(
            Rectangle()
          )
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(path)).onChanged { d in
              let ratio = d.location.x / max(1, g.size.width)
              set(
                String(Int(min(90, max(10, (direction == .rightToLeft ? 1 - ratio : ratio) * 100))))
              )
            }
          ).accessibilityElement(children: .ignore).accessibilityLabel("Resize panels")
          .accessibilityValue(value)
          .accessibilityAdjustableAction { d in
            set(String(min(90, max(10, (Int(value) ?? 50) + (d == .increment ? 5 : -5)))))
          }
        }.frame(maxHeight: .infinity)
        if children.count > 1 { child(1).frame(maxWidth: .infinity) }
      }.coordinateSpace(name: path)
    }.frame(height: node.height ?? 200).shadcnBox(theme.background, stroke: theme.border, radius: 9)
  }
  var scrollArea: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if !label.isEmpty { Text(label).aiFont(14, weight: .medium).padding(.bottom, 16) }
        ForEach(items, id: \.key) { item in
          Text(item.label).aiFont()
          Rectangle().fill(theme.border).frame(height: 1).padding(.vertical, 8)
        }
        parts
      }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }.frame(height: node.height ?? 288).shadcnBox(theme.background, stroke: theme.border, radius: 8)
  }
  var questionnaire: some View {
    let current = max(0, min(page, children.count))
    return VStack(alignment: .leading, spacing: 12) {
      if current < children.count {
        let question = children[current]
        let key = question.id ?? "\(path)/\(current)"
        let answer = values[key] ?? question.value ?? ""
        HStack {
          Text("Question \(current+1) of \(children.count)").aiFont(12, weight: .medium)
          Spacer()
          if let checkpoint = question.heading {
            Text("Current checkpoint: \(checkpoint)").aiFont(14)
          }
        }.foregroundStyle(theme.mutedForeground)
        VStack(alignment: .leading, spacing: 4) {
          Text(question.label ?? "").aiFont(16, weight: .medium)
          if let help = question.detail {
            Text(help).aiFont(14).foregroundStyle(theme.mutedForeground)
          }
        }
        VStack(spacing: 8) {
          ForEach(question.items ?? [], id: \.key) { item in
            Button {
              values[key] = item.key
              action(key, item.key)
              requiredError = false
            } label: {
              HStack(spacing: 10) {
                Circle().strokeBorder(answer == item.key ? primary : fieldBorder)
                  .frame(width: 16, height: 16).overlay {
                    if answer == item.key { Circle().fill(primary).frame(width: 8, height: 8) }
                  }
                Text(item.label).aiFont()
                Spacer()
              }
              .padding(.horizontal, 12).frame(minHeight: 44)
              .shadcnBox(
                answer == item.key ? theme.muted : fieldFill, stroke: fieldBorder, radius: 10)
            }.buttonStyle(.plain).disabled(item.disabled == true).accessibilityAddTraits(
              answer == item.key ? .isSelected : [])
          }
        }
        if requiredError {
          Text("Select an answer to continue.").aiFont(12).foregroundStyle(theme.destructive)
        }
        HStack {
          if current > 0 {
            button("Back") {
              page -= 1
              requiredError = false
            }
          }
          Spacer()
          button(current + 1 == children.count ? "Submit" : "Next", variant: "primary") {
            guard
              question.items?.contains(where: { $0.key == answer && $0.disabled != true }) == true
            else {
              requiredError = true
              return
            }
            if current + 1 == children.count { activate("submit") }
            page += 1
          }
        }
      } else {
        Text("Answers submitted").aiFont(16, weight: .medium)
        button("Start again") {
          for (index, question) in children.enumerated() {
            let key = question.id ?? "\(path)/\(index)"
            if let old = values.removeValue(forKey: key), old != (question.value ?? "") {
              action(key, question.value ?? "")
            }
          }
          requiredError = false
          page = 0
        }
      }
    }
  }
  var chart: some View {
    let columns = node.columns ?? []
    let series = columns.dropFirst().enumerated().map {
      AIChartSeries(String($0.offset), label: $0.element)
    }
    let data = (node.rows ?? []).compactMap { row -> AIChartRow? in
      guard let label = row.first else { return nil }
      return AIChartRow(
        label,
        values: Dictionary(
          uniqueKeysWithValues: zip(series, row.dropFirst()).map { ($0.id, Double($1) ?? 0) }))
    }
    return AICard(
      node.label, description: node.detail, footer: node.action, footnote: node.placeholder,
      footerIcon: .trendingUp, style: .chart
    ) {
      AIChart(
        node.variant == "line" ? .line : node.variant == "area" ? .area : .bar, data: data,
        series: series, label: label
      ) { set($0.label) }.aspectRatio(16 / 9, contentMode: .fit)
    }
  }

  private func rowFlag(_ id: String) -> String { "\(path)/row/\(id)" }
  private func selectedRow(_ id: String) -> Bool { values[rowFlag(id)] == "true" }
  private func setRow(_ id: String, _ flag: Bool) {
    values[rowFlag(id)] = String(flag)
    action(rowFlag(id), String(flag))
  }
  private func sortBy(_ i: Int) {
    ascending = sortColumn == i ? !ascending : true
    sortColumn = i
    page = 0
  }

  @ViewBuilder private func selectionBox(
    _ checked: Bool, _ label: String, mixed: Bool = false, _ change: @escaping () -> Void
  ) -> some View {
    Button(action: change) {
      RoundedRectangle(cornerRadius: 4).fill(checked || mixed ? primary : fieldFill)
        .overlay(
          RoundedRectangle(cornerRadius: 4).strokeBorder(checked || mixed ? primary : fieldBorder)
        )
        .frame(width: 16, height: 16).overlay {
          if checked {
            AIIcon(.check, size: 12).foregroundStyle(onPrimary)
          } else if mixed {
            Capsule().fill(onPrimary).frame(width: 8, height: 2)
          }
        }
    }.buttonStyle(.plain).accessibilityLabel(label).accessibilityValue(
      mixed ? "Mixed" : checked ? "Selected" : "Unselected")
  }
  private func dataCellWidth(_ title: String) -> CGFloat {
    title == "Email" ? 180 : title == "Status" ? 78 : 88
  }

  private func dataGrid(
    _ columns: [(offset: Int, element: String)], rows: [ShadcnTableRow]
  ) -> some View {
    let all = !rows.isEmpty && rows.allSatisfy { selectedRow($0.id) }
    return ScrollView(.horizontal) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          selectionBox(
            all, "Select all rows on this page", mixed: !all && rows.contains { selectedRow($0.id) }
          ) {
            for row in rows { setRow(row.id, !all) }
          }
          ForEach(columns, id: \.offset) { i, title in
            Button {
              sortBy(i)
            } label: {
              HStack(spacing: 4) {
                Text(title)
                if title == "Email" || sortColumn == i { AIIcon(.chevronsUpDown, size: 12) }
              }
              .frame(
                width: dataCellWidth(title), alignment: title == "Amount" ? .trailing : .leading)
            }.buttonStyle(.plain).accessibilityLabel("Sort by \(title)")
          }
          Color.clear.frame(width: 28)
        }.padding(.horizontal, 8).frame(minHeight: 40).aiFont(14, weight: .medium)
        ForEach(rows) { entry in
          let row = entry.cells
          Rectangle().fill(theme.border).frame(height: 1)
          HStack(spacing: 8) {
            selectionBox(selectedRow(entry.id), "Select row \(entry.index+1)") {
              setRow(entry.id, !selectedRow(entry.id))
            }
            ForEach(columns, id: \.offset) { i, title in
              Text(row.indices.contains(i) ? row[i] : "")
                .frame(
                  width: dataCellWidth(title), alignment: title == "Amount" ? .trailing : .leading)
            }
            Menu {
              Button("View details") { action(rowFlag(entry.id), "details") }
            } label: {
              AIIcon(.ellipsis, size: 16).frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).accessibilityLabel("Row actions")
          }.padding(.horizontal, 8).frame(minHeight: 40).background(
            selectedRow(entry.id) ? theme.muted : .clear)
        }
        if rows.isEmpty { Text("No results.").frame(minHeight: 48).padding(.horizontal, 8) }
      }
    }.scrollIndicators(.hidden).shadcnBox(theme.background, stroke: theme.border, radius: 8)
  }
  var tabular: some View {
    let columns = node.columns ?? []
    let dataTable = node.kind == .dataTable
    let indexed = tableEntries(interactive: dataTable)
    let pages = max(1, (indexed.count + 4) / 5)
    let current = min(page, pages - 1)
    let visible = dataTable ? Array(indexed.dropFirst(current * 5).prefix(5)) : indexed
    let shown = columns.enumerated().filter { values["\(path)/hide/\($0.offset)"] != "true" }
    let tableColumns = shown.map {
      AITableColumn(
        String($0.offset), label: $0.element, width: !dataTable && $0.offset == 0 ? 100 : nil,
        alignment: $0.element == "Amount" ? .trailing : .leading,
        emphasized: !dataTable && $0.offset == 0)
    }
    let rows = visible.map { row in
      Dictionary(
        uniqueKeysWithValues: row.cells.enumerated().map { (String($0.offset), $0.element) })
    }
    return VStack(alignment: .leading, spacing: dataTable ? 0 : 12) {
      if dataTable {
        HStack {
          AIInput("", text: $query, placeholder: node.placeholder ?? "Filter…").onChange(of: query)
          { _, _ in page = 0 }
          Menu("Columns") {
            ForEach(Array(columns.enumerated()), id: \.offset) { i, title in
              Toggle(
                title,
                isOn: Binding(
                  get: { values["\(path)/hide/\(i)"] != "true" },
                  set: { values["\(path)/hide/\(i)"] = String(!$0) }))
              Button("Sort by \(title)") {
                if sortColumn == i {
                  ascending.toggle()
                } else {
                  sortColumn = i
                  ascending = true
                }
                page = 0
              }
            }
          }.fixedSize()
        }.padding(.vertical, density == .comfortable ? 10 : 16)
      }
      if dataTable {
        dataGrid(shown, rows: visible)
      } else {
        AITable(
          columns: tableColumns, rows: rows, caption: node.detail,
          footer: items.first.map {
            ["0": $0.label, String(max(1, columns.count - 1)): $0.detail ?? ""]
          })
      }
      if dataTable {
        HStack {
          Text(
            "\(indexed.filter { selectedRow($0.id) }.count) of \(indexed.count) row(s) selected."
          ).aiFont(12).foregroundStyle(theme.mutedForeground)
          Spacer()
          button("Previous") { page = current - 1 }.disabled(current == 0)
          button("Next") { page = current + 1 }.disabled(current + 1 >= pages)
        }.padding(.vertical, density == .comfortable ? 8 : 14)
      }
    }
  }
  private func tableEntries(interactive: Bool) -> [ShadcnTableRow] {
    let rows = node.rows ?? []
    let ids = node.rowIDs.flatMap {
      $0.count == rows.count && !$0.contains("") && Set($0).count == rows.count ? $0 : nil
    }
    let entries = rows.enumerated().compactMap { index, cells -> ShadcnTableRow? in
      if interactive && !query.isEmpty {
        if let column = node.filterColumn {
          guard cells.indices.contains(column),
            cells[column].localizedCaseInsensitiveContains(query)
          else { return nil }
        } else if !cells.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
          return nil
        }
      }
      return ShadcnTableRow(id: ids?[index] ?? String(index), index: index, cells: cells)
    }
    guard interactive, let column = sortColumn else { return entries }
    return entries.sorted { a, b in
      let left = a.cells.indices.contains(column) ? a.cells[column] : ""
      let right = b.cells.indices.contains(column) ? b.cells[column] : ""
      let order = left.localizedStandardCompare(right)
      if order == .orderedSame { return a.index < b.index }
      return ascending ? order == .orderedAscending : order == .orderedDescending
    }
  }
}
