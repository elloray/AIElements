@file:OptIn(
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.foundation.layout.ExperimentalLayoutApi::class,
)

package dev.aielements.compose

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.triStateToggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.*
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.Dialog
import dev.aielements.compose.AIShadcnKind.*
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
internal fun ShadcnPart.Overlay() {
    val c = AITheme.colors
    var open by rememberSaveable { mutableStateOf(false) }
    var revision by remember { mutableIntStateOf(0) }
    val toast = node.kind == Toast
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (node.kind == DatePicker && node.label.isNotEmpty()) Caption(node.label, bold = true)
        val label =
            if (node.kind == DatePicker)
                runCatching {
                        LocalDate.parse(value)
                            .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG))
                    }
                    .getOrDefault(node.placeholder)
            else node.label
        Box {
            if (node.kind == DatePicker) {
                Box(
                    Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) {
                        open = true
                    },
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Box(
                        Modifier.fillMaxWidth()
                            .heightIn(min = 32.dp)
                            .panel(c.input, c.inputBorder)
                            .padding(horizontal = 10.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        Caption(label)
                    }
                }
            } else
                AIButton(
                    label,
                    variant =
                        when (node.kind) {
                            Drawer -> "secondary"
                            HoverCard -> "ghost"
                            else -> "outline"
                        },
                    capsule = false,
                ) {
                    open = !open || toast
                    revision++
                }
            if (open && node.kind in setOf(Popover, HoverCard, Tooltip, DatePicker)) {
                DropdownMenu(
                    true,
                    { open = false },
                    containerColor = if (node.kind == Tooltip) c.primary else c.card,
                ) {
                    if (node.kind == DatePicker) CalendarPage { open = false }
                    else if (node.kind == Tooltip)
                        Text(
                            node.detail,
                            Modifier.padding(horizontal = 8.dp),
                            color = c.onPrimary,
                            style = AITypography.caption,
                        )
                    else
                        Column(
                            Modifier.widthIn(max = 256.dp).padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            if (node.heading.isNotEmpty()) Caption(node.heading, bold = true)
                            Caption(node.detail)
                            Children()
                            if (node.value.isNotEmpty()) Caption(node.value, 12, muted = true)
                        }
                }
            }
        }
        if (open && toast) {
            LaunchedEffect(revision) {
                delay(5000)
                open = false
            }
            Row(
                Modifier.panel(c.card, c.border, 12).padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Caption(node.heading, bold = true)
                    Caption(node.detail, muted = true)
                }
                node.action?.let {
                    AIButton(it, variant = "outline", capsule = false) {
                        press(it)
                        open = false
                    }
                }
            }
        }
    }
    if (open && node.kind in setOf(AlertDialog, Dialog, Drawer, Sheet)) {
        val content: @Composable () -> Unit = {
            Column(
                Modifier.widthIn(max = 384.dp)
                    .fillMaxWidth()
                    .panel(c.card, c.border, 14)
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Caption(node.heading, 18, true)
                if (node.detail.isNotEmpty()) Caption(node.detail, muted = true)
                Children()
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AIButton("Cancel", variant = "outline", capsule = false) { open = false }
                    node.action?.let {
                        AIButton(it, capsule = false) {
                            press(it)
                            open = false
                        }
                    }
                }
            }
        }
        if (node.kind == Drawer)
            ModalBottomSheet(onDismissRequest = { open = false }, containerColor = c.card) {
                content()
            }
        else if (node.kind == Sheet)
            Dialog(
                onDismissRequest = { open = false },
                properties =
                    androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
            ) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterEnd) {
                    Box(Modifier.matchParentSize().clickable { open = false })
                    Box(Modifier.fillMaxHeight().widthIn(max = 360.dp).background(c.card)) {
                        content()
                    }
                }
            }
        else Dialog(onDismissRequest = { open = false }) { content() }
    }
}

@Composable
internal fun ShadcnPart.CalendarPage(onSelect: () -> Unit = {}) {
    val c = AITheme.colors
    val initial =
        runCatching { YearMonth.from(LocalDate.parse(value)) }.getOrDefault(YearMonth.now())
    var shown by rememberSaveable(value) { mutableStateOf(initial.toString()) }
    val month = YearMonth.parse(shown)
    val first = month.atDay(1)
    val offset = first.dayOfWeek.value % 7
    val weeks = (month.lengthOfMonth() + offset + 6) / 7
    Column(
        Modifier.widthIn(max = 214.dp).fillMaxWidth().panel(c.background, c.border).padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            SmallIcon(AIIconName.chevronLeft, "Previous month") {
                shown = month.minusMonths(1).toString()
            }
            Caption(
                month.format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.ENGLISH)),
                bold = true,
            )
            SmallIcon(AIIconName.chevronRight, "Next month") {
                shown = month.plusMonths(1).toString()
            }
        }
        Row {
            listOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa").forEach {
                Box(Modifier.weight(1f).height(26.dp), contentAlignment = Alignment.Center) {
                    Caption(it, 12, muted = true)
                }
            }
        }
        repeat(weeks) { week ->
            Row {
                repeat(7) { day ->
                    val date = first.plusDays((week * 7 + day - offset).toLong())
                    val selected = value == date.toString()
                    Box(
                        Modifier.weight(1f)
                            .heightIn(min = 28.dp)
                            .panel(
                                if (selected) c.primary
                                else if (date == LocalDate.now()) c.muted else Color.Transparent,
                                Color.Transparent,
                                8,
                            )
                            .clickable(role = Role.Button) {
                                set(date.toString())
                                shown = YearMonth.from(date).toString()
                                onSelect()
                            }
                            .semantics {
                                contentDescription = date.toString()
                                this.selected = selected
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            date.dayOfMonth.toString(),
                            style = AITypography.body,
                            color =
                                if (selected) c.onPrimary
                                else if (date.month != month.month) c.mutedForeground
                                else c.foreground,
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun SmallIcon(
    glyph: AIIconName,
    label: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        Modifier.size(28.dp)
            .alpha(if (enabled) 1f else .45f)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        AIIcon(glyph, color = AITheme.colors.foreground)
    }
}

@Composable
internal fun ShadcnPart.Navigation() {
    val c = AITheme.colors
    if (node.kind == Sidebar) {
        var collapsed by rememberSaveable { mutableStateOf(false) }
        Column(
            Modifier.then(if (collapsed) Modifier.width(48.dp) else Modifier.fillMaxWidth())
                .background(c.muted.copy(alpha = .55f))
                .padding(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (!collapsed) Caption(node.label, 12, true, true, Modifier.weight(1f))
                SmallIcon(AIIconName.panelLeft, "Toggle sidebar") { collapsed = !collapsed }
            }
            node.items.forEach { item ->
                Row(
                    Modifier.fillMaxWidth()
                        .heightIn(min = 32.dp)
                        .panel(
                            if (value == item.key) c.muted else Color.Transparent,
                            Color.Transparent,
                            7,
                        )
                        .clickable(enabled = !item.disabled) { set(item.key) }
                        .semantics { contentDescription = item.label }
                        .padding(horizontal = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AIIcon(glyph(item.icon))
                    if (!collapsed) Caption(item.label)
                }
            }
        }
    } else
        FlowRow(
            Modifier.panel(c.background, if (node.kind == Menubar) c.border else Color.Transparent)
                .padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            node.children.forEachIndexed { index, menu ->
                var expanded by remember { mutableStateOf(false) }
                Box {
                    Row(
                        Modifier.clickable {
                                if (menu.kind == AIShadcnKind.Button) child(index).press(menu.label)
                                else expanded = true
                            }
                            .heightIn(min = 26.dp)
                            .padding(horizontal = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Caption(menu.label, bold = true)
                        if (node.kind == NavigationMenu && menu.kind != AIShadcnKind.Button)
                            AIIcon(AIIconName.chevronDown, Modifier.size(12.dp))
                    }
                    DropdownMenu(expanded, { expanded = false }, containerColor = c.card) {
                        child(index).Options("") {
                            child(index).set(it.key)
                            expanded = false
                        }
                    }
                }
            }
        }
}

@Composable
internal fun ShadcnPart.CarouselPanel() {
    val c = AITheme.colors
    val count = maxOf(node.children.size, node.items.size)
    val index = (value.toIntOrNull() ?: 0).coerceIn(0, (count - 1).coerceAtLeast(0))
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    BoxWithConstraints(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        val width = (maxWidth - 48.dp).coerceIn(1.dp, 312.dp)
        Box(
            Modifier.width(width)
                .height(node.height?.dp ?: width + 32.dp)
                .panel(c.card, c.border, 14)
                .pointerInput(index, rtl, count) {
                    var moved = 0f
                    detectHorizontalDragGestures(
                        onDragStart = { moved = 0f },
                        onDragEnd = {
                            if (kotlin.math.abs(moved) > 24.dp.toPx() && count > 0)
                                set(
                                    (index + if ((moved < 0) != rtl) 1 else -1)
                                        .coerceIn(0, count - 1)
                                        .toString()
                                )
                        },
                    ) { change, dx ->
                        change.consume()
                        moved += dx
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            if (index in node.children.indices) child(index).Render()
            else node.items.getOrNull(index)?.let { Caption(it.label, 36, true) }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            SmallIcon(AIIconName.arrowLeft, "Previous slide", index > 0) {
                set((index - 1).toString())
            }
            SmallIcon(AIIconName.arrowRight, "Next slide", index + 1 < count) {
                set((index + 1).toString())
            }
        }
    }
}

@Composable
internal fun CompactRange(number: Float, onChange: (Float) -> Unit, label: String) {
    val c = AITheme.colors
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val latest by rememberUpdatedState(onChange)
    BoxWithConstraints(
        Modifier.fillMaxWidth()
            .height(32.dp)
            .semantics {
                contentDescription = label
                progressBarRangeInfo = ProgressBarRangeInfo(number, 0f..100f)
                setProgress {
                    latest(it.coerceIn(0f, 100f))
                    true
                }
            }
            .pointerInput(rtl) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    fun update(x: Float) {
                        val v =
                            ((x - 6.dp.toPx()) / (size.width - 12.dp.toPx()).coerceAtLeast(1f))
                                .coerceIn(0f, 1f)
                        latest((if (rtl) 1f - v else v) * 100)
                    }
                    update(down.position.x)
                    down.consume()
                    horizontalDrag(down.id) {
                        update(it.position.x)
                        it.consume()
                    }
                }
            },
        contentAlignment = Alignment.CenterStart,
    ) {
        val x = (maxWidth - 12.dp).coerceAtLeast(0.dp) * (number / 100)
        Box(Modifier.fillMaxWidth().height(4.dp).background(c.muted, CircleShape))
        Box(Modifier.width(x + 6.dp).height(4.dp).background(c.primary, CircleShape))
        Box(
            Modifier.offset(x = x)
                .size(12.dp)
                .background(c.background, CircleShape)
                .border(1.dp, c.mutedForeground.copy(alpha = .55f), CircleShape)
        )
    }
}

@Composable
internal fun ShadcnPart.ResizablePanel() {
    val c = AITheme.colors
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val percent = (value.toFloatOrNull() ?: 50f).coerceIn(10f, 90f)
    BoxWithConstraints(
        Modifier.fillMaxWidth().height((node.height ?: 200f).dp).panel(c.background, c.border)
    ) {
        val width = maxWidth
        val x = width * (percent / 100)
        Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.width(x), contentAlignment = Alignment.Center) {
                if (node.children.isNotEmpty()) child(0).Render()
            }
            Box(Modifier.width(1.dp).fillMaxHeight().background(c.border))
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                if (node.children.size > 1) child(1).Render()
            }
        }
        val start by rememberUpdatedState(percent)
        Box(
            Modifier.offset(x = x - 14.dp)
                .width(28.dp)
                .fillMaxHeight()
                .semantics {
                    contentDescription = "Resize panels"
                    progressBarRangeInfo = ProgressBarRangeInfo(percent, 10f..90f)
                    setProgress {
                        set(it.coerceIn(10f, 90f).toInt().toString())
                        true
                    }
                }
                .pointerInput(width, rtl) {
                    var current = 0f
                    detectHorizontalDragGestures(onDragStart = { current = start }) { event, delta
                        ->
                        event.consume()
                        current =
                            (current +
                                    delta / width.toPx().coerceAtLeast(1f) * if (rtl) -100 else 100)
                                .coerceIn(10f, 90f)
                        set(current.toInt().toString())
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            AIIcon(AIIconName.gripVertical, Modifier.size(12.dp).background(c.background))
        }
    }
}

@Composable
internal fun ShadcnPart.Scroller() {
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    var following by remember { mutableStateOf(node.align != "start") }
    LaunchedEffect(scroll.value, scroll.maxValue) {
        if (scroll.maxValue > 0) following = scroll.maxValue - scroll.value < 12
    }
    LaunchedEffect(node.children) { if (following) scroll.scrollTo(scroll.maxValue) }
    Box(Modifier.fillMaxWidth().height((node.height ?: 300f).dp)) {
        Column(
            Modifier.fillMaxSize().verticalScroll(scroll).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Children()
        }
        if (!following)
            Box(Modifier.align(Alignment.BottomEnd)) {
                SmallIcon(AIIconName.arrowDown, "Jump to latest") {
                    scope.launch { scroll.animateScrollTo(scroll.maxValue) }
                }
            }
    }
}

@Composable
internal fun ShadcnPart.QuestionnairePanel() {
    var index by rememberSaveable { mutableIntStateOf(0) }
    val c = AITheme.colors
    var requiredError by rememberSaveable { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (index in node.children.indices) {
            val current = child(index)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Caption("Question ${index+1} of ${node.children.size}", 12, true, true)
                if (current.node.heading.isNotEmpty())
                    Caption("Current checkpoint: " + current.node.heading, muted = true)
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Caption(current.node.label, 16, true)
                if (current.node.detail.isNotEmpty()) Caption(current.node.detail, muted = true)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                current.node.items.forEach { item ->
                    val selected = current.value == item.key
                    Row(
                        Modifier.fillMaxWidth()
                            .heightIn(min = 44.dp)
                            .panel(if (selected) c.muted else c.input, c.inputBorder, 10)
                            .clickable(enabled = !item.disabled, role = Role.RadioButton) {
                                current.set(item.key)
                                requiredError = false
                            }
                            .semantics { this.selected = selected }
                            .padding(horizontal = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier.size(16.dp)
                                .border(
                                    1.dp,
                                    if (selected) c.primary else c.inputBorder,
                                    CircleShape,
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (selected)
                                Box(Modifier.size(8.dp).background(c.primary, CircleShape))
                        }
                        Caption(item.label)
                    }
                }
            }
            if (requiredError) Caption("Select an answer to continue.", 12)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                if (index > 0)
                    AIButton("Back", variant = "outline", capsule = false) {
                        index--
                        requiredError = false
                    }
                Spacer(Modifier.weight(1f))
                AIButton(
                    if (index == node.children.lastIndex) "Submit" else "Next",
                    capsule = false,
                ) {
                    if (current.node.items.none { it.key == current.value && !it.disabled })
                        requiredError = true
                    else {
                        if (index == node.children.lastIndex) press("submit")
                        index++
                    }
                }
            }
        } else {
            Caption("Answers submitted", 16, true)
            AIButton("Start again", capsule = false) {
                node.children.indices.forEach { i ->
                    val question = child(i)
                    val old = state.values.remove(question.path)
                    if (old != null && old != question.node.value)
                        action(question.path, question.node.value)
                }
                requiredError = false
                index = 0
            }
        }
    }
}

@Composable
internal fun ShadcnPart.ChartPanel() {
    val series =
        node.columns.drop(1).mapIndexed { index, label -> AIChartSeries(index.toString(), label) }
    val data =
        node.rows.mapNotNull { row ->
            row.firstOrNull()?.let { label ->
                AIChartRow(
                    label,
                    series
                        .mapIndexed { i, key ->
                            key.key to (row.getOrNull(i + 1)?.toDoubleOrNull() ?: 0.0)
                        }
                        .toMap(),
                )
            }
        }
    AICard(
        title = node.label,
        description = node.detail,
        footer = node.action.orEmpty(),
        footnote = node.placeholder,
        chartStyle = true,
        footerIcon = AIIconName.trendingUp,
    ) {
        AIChart(
            data,
            series,
            kind =
                when (node.variant) {
                    "line" -> AIChartKind.Line
                    "area" -> AIChartKind.Area
                    else -> AIChartKind.Bar
                },
            onSelect = { set(it.label) },
        )
    }
}

@Composable
internal fun ShadcnPart.TablePanel() {
    var query by rememberSaveable { mutableStateOf("") }
    var page by rememberSaveable { mutableIntStateOf(0) }
    var column by rememberSaveable { mutableIntStateOf(-1) }
    var descending by rememberSaveable { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    val interactive = node.kind == DataTable
    val data =
        node.rows
            .withIndex()
            .filter { entry ->
                !interactive ||
                    query.isEmpty() ||
                    (node.filterColumn?.let { index ->
                        entry.value.getOrNull(index)?.contains(query, true) == true
                    } ?: entry.value.any { it.contains(query, true) })
            }
            .let { rows ->
                if (column < 0) rows
                else
                    rows.sortedWith(
                        compareBy<IndexedValue<List<String>>> {
                                it.value.getOrNull(column).orEmpty()
                            }
                            .let { if (descending) it.reversed() else it }
                    )
            }
    fun sortBy(i: Int) {
        descending = column == i && !descending
        column = i
        page = 0
    }
    val ids =
        node.rowIDs?.takeIf {
            it.size == node.rows.size && it.none(String::isEmpty) && it.toSet().size == it.size
        }
    fun rowKey(i: Int) = "$path/row/" + (ids?.get(i) ?: i.toString())
    fun selected(i: Int) = state.values[rowKey(i)] == "true"
    fun select(i: Int, next: Boolean) {
        val key = rowKey(i)
        state.values[key] = next.toString()
        action(key, next.toString())
    }
    val last = ((data.size - 1).coerceAtLeast(0)) / 5
    val current = page.coerceIn(0, last)
    val visible = node.columns.indices.filter { state.values["$path/hide/$it"] != "true" }
    Column(verticalArrangement = Arrangement.spacedBy(if (interactive) 0.dp else 12.dp)) {
        if (interactive)
            Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                AIInput(
                    query,
                    {
                        query = it
                        page = 0
                    },
                    Modifier.weight(1f),
                    placeholder = node.placeholder,
                )
                Box {
                    AIButton("Columns", variant = "outline", capsule = false) { menu = true }
                    DropdownMenu(menu, { menu = false }) {
                        node.columns.forEachIndexed { i, label ->
                            DropdownMenuItem(
                                text = { Caption(label) },
                                onClick = {
                                    state.values["$path/hide/$i"] = (i in visible).toString()
                                },
                            )
                            DropdownMenuItem(
                                text = { Caption("Sort by $label") },
                                onClick = {
                                    descending = column == i && !descending
                                    column = i
                                    page = 0
                                    menu = false
                                },
                            )
                        }
                    }
                }
            }
        if (interactive) {
            val pageRows = data.drop(current * 5).take(5)
            val c = AITheme.colors
            Column(
                Modifier.fillMaxWidth()
                    .panel(c.background, c.border, 8)
                    .horizontalScroll(rememberScrollState())
            ) {
                Row(
                    Modifier.heightIn(min = 40.dp).padding(horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    val all = pageRows.isNotEmpty() && pageRows.all { selected(it.index) }
                    GridCheck(
                        all,
                        "Select all rows on this page",
                        mixed = !all && pageRows.any { selected(it.index) },
                    ) {
                        pageRows.forEach { select(it.index, !all) }
                    }
                    visible.forEach { i ->
                        val title = node.columns[i]
                        Box(
                            Modifier.width(dataCellWidth(title)).clickable { sortBy(i) },
                            contentAlignment =
                                if (title == "Amount") Alignment.CenterEnd
                                else Alignment.CenterStart,
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Caption(title, bold = true)
                                if (title == "Email" || column == i)
                                    AIIcon(AIIconName.chevronsUpDown, Modifier.size(12.dp))
                            }
                        }
                    }
                    Spacer(Modifier.width(28.dp))
                }
                pageRows.forEach { row ->
                    AISeparator()
                    Row(
                        Modifier.background(if (selected(row.index)) c.muted else Color.Transparent)
                            .heightIn(min = 40.dp)
                            .padding(horizontal = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        GridCheck(selected(row.index), "Select row ${row.index+1}") {
                            select(row.index, !selected(row.index))
                        }
                        visible.forEach { i ->
                            Box(
                                Modifier.width(dataCellWidth(node.columns[i])),
                                contentAlignment =
                                    if (node.columns[i] == "Amount") Alignment.CenterEnd
                                    else Alignment.CenterStart,
                            ) {
                                Caption(row.value.getOrNull(i).orEmpty())
                            }
                        }
                        var open by remember(rowKey(row.index)) { mutableStateOf(false) }
                        Box {
                            SmallIcon(AIIconName.ellipsis, "Row actions") { open = true }
                            DropdownMenu(open, { open = false }) {
                                DropdownMenuItem(
                                    text = { Caption("View details") },
                                    onClick = {
                                        action(rowKey(row.index), "details")
                                        open = false
                                    },
                                )
                            }
                        }
                    }
                }
                if (pageRows.isEmpty()) Caption("No results.", modifier = Modifier.padding(12.dp))
            }
        } else if (visible.isNotEmpty())
            AITable(
                visible.map { i ->
                    AITableColumn(
                        i.toString(),
                        node.columns[i],
                        if (!interactive && i == 0) 100.dp else Dp.Unspecified,
                        node.columns[i] == "Amount",
                        !interactive && i == 0,
                    )
                },
                data.map { row ->
                    row.value.mapIndexed { i, text -> i.toString() to text }.toMap()
                },
                caption = node.detail,
                footer =
                    node.items.firstOrNull()?.let {
                        mapOf("0" to it.label, node.columns.lastIndex.toString() to it.detail)
                    },
            )
        if (interactive)
            Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Caption(
                    "${data.count { selected(it.index) }} of ${data.size} row(s) selected.",
                    12,
                    muted = true,
                    modifier = Modifier.weight(1f),
                )
                AIButton("Previous", variant = "outline", capsule = false, enabled = current > 0) {
                    page = current - 1
                }
                AIButton("Next", variant = "outline", capsule = false, enabled = current < last) {
                    page = current + 1
                }
            }
    }
}

@Composable
internal fun ShadcnPart.SkeletonShape() {
    val phase by
        rememberInfiniteTransition(label = "Skeleton")
            .animateFloat(
                1f,
                .5f,
                infiniteRepeatable(tween(1000), RepeatMode.Reverse),
                label = "Opacity",
            )
    Box(
        Modifier.fillMaxWidth()
            .height((node.height ?: 16f).dp)
            .alpha(phase)
            .panel(AITheme.colors.muted, Color.Transparent, 6)
    )
}

@Composable
internal fun ShadcnPart.SpinningIcon() {
    val angle by
        rememberInfiniteTransition(label = "Spinner")
            .animateFloat(
                0f,
                360f,
                infiniteRepeatable(tween(1000, easing = LinearEasing)),
                label = "Rotation",
            )
    AIIcon(
        AIIconName.loaderCircle,
        Modifier.size((node.size ?: 16f).dp).rotate(angle).semantics {
            contentDescription = "Loading"
        },
        AITheme.colors.foreground,
    )
}

private fun dataCellWidth(title: String) =
    when (title) {
        "Email" -> 180.dp
        "Status" -> 78.dp
        else -> 88.dp
    }

@Composable
private fun GridCheck(checked: Boolean, label: String, mixed: Boolean = false, change: () -> Unit) {
    val c = AITheme.colors
    val state = if (mixed) ToggleableState.Indeterminate else ToggleableState(checked)
    Box(
        Modifier.size(16.dp)
            .panel(if (checked || mixed) c.primary else c.input, c.inputBorder, 4)
            .triStateToggleable(state, role = Role.Checkbox, onClick = change)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        if (checked) AIIcon(AIIconName.check, Modifier.size(12.dp), c.onPrimary)
        else if (mixed) Box(Modifier.size(8.dp, 2.dp).background(c.onPrimary, CircleShape))
    }
}

@Composable
internal fun ShadcnPart.SonnerPanel() {
    val notices = remember { mutableStateListOf<Long>() }
    var sequence by remember { mutableLongStateOf(0L) }
    val c = AITheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(8.dp), horizontalAlignment = Alignment.End) {
        AIButton(node.label, variant = "outline", capsule = false) {
            if (notices.size >= 3) notices.removeAt(0)
            notices.add(++sequence)
        }
        notices.forEach { id ->
            key(id) {
                LaunchedEffect(id) {
                    delay(4000)
                    notices.remove(id)
                }
                Row(
                    Modifier.widthIn(max = 356.dp)
                        .fillMaxWidth()
                        .panel(c.card, c.border, 10)
                        .padding(12.dp)
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                            dismiss { notices.remove(id) }
                        },
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Caption(node.heading.ifEmpty { node.label }, bold = true)
                        if (node.detail.isNotEmpty()) Caption(node.detail, 13, muted = true)
                    }
                    node.action?.let { label ->
                        AIButton(label, compact = true, capsule = false) {
                            press(label)
                            notices.remove(id)
                        }
                    }
                }
            }
        }
    }
}
