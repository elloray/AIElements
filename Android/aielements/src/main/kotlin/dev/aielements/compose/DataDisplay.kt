package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import kotlin.math.*

data class AITableColumn(val key: String, val label: String, val width: Dp = Dp.Unspecified, val trailing: Boolean = false, val emphasized: Boolean = false)
@Composable fun AITable(columns: List<AITableColumn>, rows: List<Map<String, String>>, modifier: Modifier = Modifier, caption: String = "", footer: Map<String, String>? = null) {
    val measurer = rememberTextMeasurer(); val density = LocalDensity.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val intrinsic = columns.map { col ->
                val values = listOf(col.label to AITypography.title) + rows.map { it[col.key].orEmpty() to if (col.emphasized) AITypography.title else AITypography.body } + listOfNotNull(footer?.get(col.key)?.let { it to AITypography.title })
                with(density) { values.maxOf { (text, style) -> measurer.measure(text, style, softWrap = false).size.width }.toDp() } + 16.dp
            }
            val widths = columns.mapIndexed { i, col -> maxOf(intrinsic[i], if (col.width.isSpecified) col.width else 0.dp) }.toMutableList()
            var deficit = maxOf(0.dp, widths.fold(0.dp) { a, b -> a + b } - maxWidth)
            for (i in widths.indices) { val reduction = minOf(deficit, widths[i] - intrinsic[i]); widths[i] -= reduction; deficit -= reduction }
            val flexible = columns.indices.filter { !columns[it].width.isSpecified }.ifEmpty { columns.indices.toList() }
            if (flexible.isNotEmpty()) {
                val surplus = maxOf(0.dp, maxWidth - widths.fold(0.dp) { a, b -> a + b })
                val basis = flexible.sumOf { widths[it].value.toDouble() }.toFloat()
                flexible.forEach { widths[it] += surplus * (if (basis > 0f) widths[it].value / basis else 1f / flexible.size) }
            }
            val total = widths.fold(0.dp) { a, b -> a + b }
            Column(Modifier.horizontalScroll(rememberScrollState())) {
                @Composable fun TableRow(values: Map<String, String>, header: Boolean = false, isFooter: Boolean = false) {
                    val border = AITheme.colors.border
                    // Paint the shared border inside the row: a separate rounded-up 1 dp child
                    // accumulates height drift on fractional-density Android displays.
                    Row(Modifier.width(total).background(if (isFooter) AITheme.colors.muted.copy(alpha = .5f) else Color.Transparent)
                        .drawBehind { if (!header) drawLine(border, Offset(0f, .5.dp.toPx()), Offset(size.width, .5.dp.toPx()), 1.dp.toPx()) }) {
                        columns.forEachIndexed { i, col ->
                            Box(Modifier.width(widths[i]).heightIn(min = if (header) 40.dp else if (isFooter) 36.5.dp else 37.dp).padding(horizontal = 8.dp, vertical = 8.dp), contentAlignment = if (col.trailing) Alignment.CenterEnd else Alignment.CenterStart) {
                                Text(values[col.key].orEmpty(), color = AITheme.colors.foreground, style = if (header || col.emphasized || isFooter) AITypography.title else AITypography.body, softWrap = false)
                            }
                        }
                    }
                }
                TableRow(columns.associate { it.key to it.label }, header = true)
                rows.forEach { TableRow(it) }; footer?.let { TableRow(it, isFooter = true) }
            }
        }
        if (caption.isNotEmpty()) Text(caption, Modifier.fillMaxWidth(), style = AITypography.body, color = AITheme.colors.mutedForeground, textAlign = TextAlign.Center)
    }
}
data class AIChartSeries(val key: String, val label: String)
data class AIChartRow(val label: String, val values: Map<String, Double>)
enum class AIChartKind { Bar, Line, Area }
@Composable fun AIChart(data: List<AIChartRow>, series: List<AIChartSeries>, modifier: Modifier = Modifier, kind: AIChartKind = AIChartKind.Bar,
    label: String = "Chart", height: Dp = Dp.Unspecified, legend: Boolean = false, onSelect: (AIChartRow) -> Unit = {}) {
    val c = AITheme.colors; val measurer = rememberTextMeasurer()
    val colors = listOf(Color(.557f, .773f, 1f), Color(.169f, .498f, 1f), Color(.082f, .365f, .988f), Color(.078f, .278f, .902f), Color(.118f, .227f, .541f))
    val rows = data.distinctBy { it.label }.take(200)
    var selectedLabel by remember { mutableStateOf<String?>(null) }
    var showData by remember { mutableStateOf(false) }
    val selected = rows.firstOrNull { it.label == selectedLabel }
    val allValues = rows.flatMap { row -> series.mapNotNull { row.values[it.key] } }
    val domain = remember(allValues) { chartDomain(allValues) }
    fun pick(index: Int) { rows.getOrNull(index)?.let { selectedLabel = it.label; onSelect(it) } }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.fillMaxWidth().then(if (height.isSpecified) Modifier.height(height.coerceIn(120.dp, 600.dp)) else Modifier.aspectRatio(16f / 9f))) {
            Canvas(Modifier.fillMaxSize().semantics {
                contentDescription = "$label. ${rows.size} values. Long press to view data."
                stateDescription = selected?.let { r -> r.label + ": " + series.joinToString { "${it.label} ${r.values[it.key] ?: 0.0}" } } ?: "No selection"
                customActions = listOf(CustomAccessibilityAction("View data") { showData = true; true },
                    CustomAccessibilityAction("Next value") { pick((rows.indexOfFirst { it.label == selectedLabel } + 1).coerceAtMost(rows.lastIndex)); true },
                    CustomAccessibilityAction("Previous value") { pick((rows.indexOfFirst { it.label == selectedLabel } - 1).coerceAtLeast(0)); true })
            }.pointerInput(rows, series, kind) {
                detectTapGestures(onLongPress = { showData = true }, onTap = { point ->
                    if (rows.isNotEmpty()) {
                        val left = (if (kind == AIChartKind.Bar) 5 else 12).dp.toPx()
                        val width = (size.width - 2 * left).coerceAtLeast(1f)
                        val index = if (kind == AIChartKind.Bar) floor((point.x - left) / width * rows.size).toInt() else ((point.x - left) / width * (rows.size - 1)).roundToInt()
                        pick(index.coerceIn(rows.indices))
                    }
                })
            }) {
                val points = kind != AIChartKind.Bar
                val left = (if (points) 12 else 5).dp.toPx(); val top = (if (points) 0 else 5).dp.toPx()
                val plotWidth = (size.width - left * 2).coerceAtLeast(1f)
                val plotHeight = (size.height - (if (points) 30 else 40).dp.toPx()).coerceAtLeast(1f)
                val band = plotWidth / rows.size.coerceAtLeast(1)
                fun x(i: Int) = if (points) left + if (rows.size > 1) plotWidth * i / (rows.size - 1) else plotWidth / 2 else left + band * (i + .5f)
                fun y(v: Double) = top + plotHeight * (1 - ((v - domain.first) / (domain.second - domain.first)).coerceIn(0.0, 1.0)).toFloat()
                listOf(0, 2, 3, 4).forEach { line -> val py = top + plotHeight * line / 4f; drawLine(c.border.copy(alpha = c.border.alpha * .5f), Offset(left, py), Offset(size.width - left, py), 1.dp.toPx()) }
                series.take(5).forEachIndexed { s, entry ->
                    val color = colors[s]; val plot = rows.mapIndexedNotNull { i, row -> row.values[entry.key]?.takeIf { it.isFinite() && abs(it) <= 1e15 }?.let { Offset(x(i), y(it)) } }
                    if (kind == AIChartKind.Bar) rows.forEachIndexed { i, row ->
                        val value = row.values[entry.key]?.takeIf { it.isFinite() && abs(it) <= 1e15 } ?: return@forEachIndexed
                        val count = series.size.coerceIn(1, 5); val width = ((band * .8f - (count - 1) * 4.dp.toPx()) / count).coerceAtLeast(1f)
                        val py = y(value); val h = abs(y(0.0) - py); val radius = minOf(8.dp.toPx(), width / 2, h / 2)
                        drawRoundRect(color, Offset(x(i) - band * .4f + s * (width + 4.dp.toPx()), min(py, y(0.0))), Size(width, h), CornerRadius(radius))
                    } else if (plot.isNotEmpty()) {
                        val path = Path().apply {
                            moveTo(plot[0].x, plot[0].y)
                            val dx = naturalDerivatives(plot.map { it.x }); val dy = naturalDerivatives(plot.map { it.y })
                            for (i in 1 until plot.size) cubicTo(plot[i - 1].x + dx[i - 1] / 3, plot[i - 1].y + dy[i - 1] / 3, plot[i].x - dx[i] / 3, plot[i].y - dy[i] / 3, plot[i].x, plot[i].y)
                        }
                        if (kind == AIChartKind.Area) drawPath(Path().apply { addPath(path); lineTo(plot.last().x, y(0.0)); lineTo(plot.first().x, y(0.0)); close() }, color.copy(alpha = .4f))
                        drawPath(path, color, style = Stroke((if (kind == AIChartKind.Area) 1 else 2).dp.toPx()))
                        if (plot.size == 1) drawCircle(color, 3.dp.toPx(), plot.first())
                    }
                }
                val stride = ceil(rows.size * 34.dp.toPx() / size.width).toInt().coerceAtLeast(1)
                rows.forEachIndexed { i, row -> if (i % stride == 0) {
                    val text = measurer.measure(row.label.take(3), AITypography.caption.copy(color = Color(0xFF666666)))
                    drawText(text, topLeft = Offset(x(i) - text.size.width / 2f, top + plotHeight + 20.dp.toPx() - text.size.height / 2f))
                } }
            }
            if (rows.isEmpty()) AIText("No data yet", Modifier.align(Alignment.Center), muted = true)
            selected?.let { row -> Column(Modifier.align(Alignment.TopEnd).padding(8.dp).background(c.card, RoundedCornerShape(8.dp)).border(1.dp, c.border, RoundedCornerShape(8.dp)).padding(10.dp)) {
                AIText(row.label, variant = "label"); series.forEach { AIText("${it.label}: ${row.values[it.key] ?: 0.0}", variant = "caption") }
            } }
        }
        if (legend) Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            series.take(5).forEachIndexed { i, s -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { Box(Modifier.size(8.dp).background(colors[i], RoundedCornerShape(2.dp))); AIText(s.label, variant = "caption") } }
        }
    }
    if (showData) AlertDialog(onDismissRequest = { showData = false }, title = { AIText(label, variant = "title") }, text = {
        LazyColumn { items(rows.size) { i -> val row = rows[i]; AIButton(row.label + ": " + series.joinToString { "${it.label} ${row.values[it.key] ?: 0.0}" }, variant = "ghost") { pick(i); showData = false } } }
    }, confirmButton = { AIButton("Close", variant = "ghost") { showData = false } })
}
@Composable fun AIBarChart(data: List<AIChartRow>, series: List<AIChartSeries>, modifier: Modifier = Modifier, onSelect: (AIChartRow) -> Unit = {}) { AIChart(data, series, modifier, AIChartKind.Bar, onSelect = onSelect) }
@Composable fun AILineChart(data: List<AIChartRow>, series: List<AIChartSeries>, modifier: Modifier = Modifier, onSelect: (AIChartRow) -> Unit = {}) { AIChart(data, series, modifier, AIChartKind.Line, onSelect = onSelect) }
@Composable fun AIAreaChart(data: List<AIChartRow>, series: List<AIChartSeries>, modifier: Modifier = Modifier, onSelect: (AIChartRow) -> Unit = {}) { AIChart(data, series, modifier, AIChartKind.Area, onSelect = onSelect) }
