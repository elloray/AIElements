@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.*

@Composable fun AIText(text: String, modifier: Modifier = Modifier, muted: Boolean = false, variant: String = "body") {
    val style = when (variant) { "title" -> AITypography.title.copy(fontSize = 16.sp, lineHeight = 22.sp); "caption" -> AITypography.caption; "label" -> AITypography.label; else -> if (LocalAITraceContent.current) AITypography.body.copy(lineHeight = 22.75.sp) else AITypography.body }
    Text(text, if (variant == "label") modifier.compactLineBox(style) else modifier,
        color = if (muted || variant in listOf("caption", "muted")) AITheme.colors.mutedForeground else AITheme.colors.foreground, style = style)
}

/** Remove the font's extra first/last-line leading, without clipping glyphs or fixing a multiline height. */
@Composable internal fun Modifier.compactLineBox(style: TextStyle): Modifier {
    val measurer = rememberTextMeasurer(); val density = LocalDensity.current
    val excess = (measurer.measure("Hg", style, softWrap = false).size.height - with(density) { style.lineHeight.roundToPx() }).coerceAtLeast(0)
    return if (excess == 0) this else layout { measurable, constraints ->
        val child = measurable.measure(constraints.copy(minHeight = 0))
        val height = (child.height - excess).coerceIn(constraints.minHeight, constraints.maxHeight)
        layout(child.width, height) { child.placeRelative(0, (height - child.height) / 2) }
    }
}

/** A compact visible surface inside a separate, non-overlapping 48 dp target. */
@Composable fun AIButton(label: String, modifier: Modifier = Modifier, variant: String = "primary", enabled: Boolean = true,
    capsule: Boolean = true, trailingIcon: AIIconName? = null, compact: Boolean = false, onClick: () -> Unit) {
    val c = AITheme.colors
    val shape = if (capsule) RoundedCornerShape(50) else RoundedCornerShape(10.dp)
    val fill = when (variant) { "primary" -> c.primary; "secondary" -> c.muted; "destructive" -> c.destructive; "outline" -> if (capsule) Color.Transparent else c.input; "menu" -> if (c.dark) Color.Transparent else c.background; else -> Color.Transparent }
    val ink = when { variant == "primary" -> c.onPrimary; variant == "destructive" -> Color.White; variant == "menu" || compact -> c.mutedForeground; else -> c.foreground }
    Box(modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp).clip(RoundedCornerShape(12.dp)).clickable(enabled, role = Role.Button, onClick = onClick)
        .alpha(if (enabled) 1f else .5f).padding(vertical = if (compact) 12.dp else if (capsule && variant != "menu") 10.dp else 8.dp), propagateMinConstraints = true, contentAlignment = Alignment.Center) {
        Row(Modifier.heightIn(min = if (compact) 24.dp else if (variant == "menu" || !capsule) 32.dp else 28.dp).background(fill, shape)
            .then(if (variant in listOf("outline", "menu")) Modifier.border(1.dp, c.border, shape) else Modifier)
            .padding(horizontal = if (variant == "link") 0.dp else if (variant == "menu" || capsule) 13.dp else 11.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(if (variant == "menu") 8.dp else 6.dp, Alignment.CenterHorizontally)) {
            Text(label, color = ink, style = if (compact) AITypography.caption.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Medium) else if (variant == "link") AITypography.body else AITypography.title)
            trailingIcon?.let { AIIcon(it, color = ink) }
        }
    }
}
@Composable fun AIIconButton(icon: AIIconName, label: String, modifier: Modifier = Modifier, enabled: Boolean = true,
    variant: String = "ghost", accent: Boolean = false, visualAlignment: Alignment = Alignment.Center, onClick: () -> Unit) {
    val c = AITheme.colors
    IconButton(onClick, modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp).semantics { contentDescription = label }, enabled = enabled) {
        val fill = if (accent) Color(0xFF193BED) else if (variant == "primary") c.primary else if (variant == "outline" && !c.dark) c.background else Color.Transparent
        Box(Modifier.fillMaxSize(), contentAlignment = visualAlignment) {
            Box(Modifier.size(if (variant == "ghost") 28.dp else 32.dp).alpha(if (enabled) 1f else .5f).background(fill, RoundedCornerShape(50))
                .then(if (variant == "outline") Modifier.border(1.dp, c.border, RoundedCornerShape(50)) else Modifier), contentAlignment = Alignment.Center) {
                AIIcon(icon, color = if (accent) Color.White else if (variant == "primary") c.onPrimary else c.mutedForeground)
            }
        }
    }
}
@Composable fun AIBadge(text: String, variant: String = "secondary") {
    val c = AITheme.colors
    val fill = when (variant) { "primary" -> c.primary; "destructive" -> c.destructive.copy(alpha = if (c.dark) .2f else .1f); "outline", "ghost" -> Color.Transparent; else -> c.muted }
    Text(text, Modifier.background(fill, RoundedCornerShape(50)).then(if (variant == "outline") Modifier.border(1.dp, c.border, RoundedCornerShape(50)) else Modifier)
        .padding(horizontal = 8.dp, vertical = 2.dp), color = when (variant) { "primary" -> c.onPrimary; "destructive" -> c.destructive; else -> c.foreground }, style = AITypography.caption.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.Medium))
}
@Composable fun AICard(modifier: Modifier = Modifier, title: String = "", description: String = "", footer: String = "", footnote: String = "",
    chartStyle: Boolean = false, footerIcon: AIIconName? = null, headerAction: (@Composable () -> Unit)? = null,
    footerContent: (@Composable ColumnScope.() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val c = AITheme.colors; val inset = if (chartStyle) 25.dp else 16.dp
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(c.card).border(1.dp, c.border, RoundedCornerShape(14.dp))) {
        Column(Modifier.padding(inset), verticalArrangement = Arrangement.spacedBy(if (chartStyle) 24.dp else 16.dp)) {
            if (title.isNotEmpty() || description.isNotEmpty() || headerAction != null) Row(verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(if (chartStyle) 8.dp else 4.dp)) {
                    if (title.isNotEmpty()) {
                        if (chartStyle) {
                            val style = AITypography.title.copy(fontSize = 16.sp, lineHeight = 16.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, lineHeightStyle = AITypography.label.lineHeightStyle, platformStyle = AITypography.label.platformStyle)
                            Text(title, Modifier.compactLineBox(style), color = c.foreground, style = style)
                        }
                        else AIText(title, variant = "title")
                    }
                    if (description.isNotEmpty()) AIText(description, muted = true)
                }
                // Align the compact visual surface with the title; its 48 dp target stays in the header.
                if (headerAction != null) Box(Modifier.offset(y = (-8).dp)) { headerAction() }
            }
            // Card spacing separates its sections. The body owns spacing between its fields.
            Column(content = content)
            if (footer.isNotEmpty() || footnote.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (footer.isNotEmpty()) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AIText(footer, Modifier.weight(1f, fill = false), variant = "label"); footerIcon?.let { AIIcon(it, color = c.foreground) }
                }
                if (footnote.isNotEmpty()) {
                    val style = AITypography.body.copy(lineHeight = 14.sp, lineHeightStyle = AITypography.label.lineHeightStyle, platformStyle = AITypography.label.platformStyle)
                    Text(footnote, Modifier.compactLineBox(style), color = c.mutedForeground, style = style)
                }
            }
        }
        if (footerContent != null) { AISeparator(); Column(Modifier.fillMaxWidth().background(c.muted.copy(alpha = .5f)).padding(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(0.dp), content = footerContent) }
    }
}
@Composable fun AIInput(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, label: String = "", placeholder: String = "", enabled: Boolean = true) {
    val c = AITheme.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(0.dp)) {
        if (label.isNotEmpty()) AIText(label, variant = "label")
        BasicTextField(value, onValueChange, Modifier.fillMaxWidth().heightIn(min = 48.dp).semantics { contentDescription = label.ifEmpty { placeholder.ifEmpty { "Input" } } },
            enabled = enabled, singleLine = true, textStyle = AITypography.body.copy(color = c.foreground), cursorBrush = androidx.compose.ui.graphics.SolidColor(c.foreground),
            decorationBox = { inner -> Box(Modifier.fillMaxWidth().heightIn(min = 48.dp), contentAlignment = Alignment.CenterStart) {
                Box(Modifier.fillMaxWidth().heightIn(min = 32.dp).alpha(if (enabled) 1f else .5f).background(c.input, RoundedCornerShape(10.dp))
                    .border(1.dp, c.inputBorder, RoundedCornerShape(10.dp)).padding(horizontal = 11.dp, vertical = 4.dp), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) AIText(placeholder, muted = true); inner()
                }
            } })
    }
}
data class AIOption(val value: String, val label: String)
@Composable fun AISelect(value: String, options: List<AIOption>, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, label: String = "", placeholder: String = "Select an option", enabled: Boolean = true) {
    var open by rememberSaveable { mutableStateOf(false) }; val c = AITheme.colors
    Column(modifier) {
        if (label.isNotEmpty()) AIText(label, variant = "label")
        Box {
            Box(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(enabled, role = Role.DropdownList) { open = true }
                .semantics { contentDescription = label.ifEmpty { placeholder } }.alpha(if (enabled) 1f else .5f), contentAlignment = Alignment.Center) {
                Row(Modifier.fillMaxWidth().heightIn(min = 32.dp).background(c.input, RoundedCornerShape(10.dp)).border(1.dp, c.inputBorder, RoundedCornerShape(10.dp))
                    // Compose borders draw inside the bounds; include CSS's 1 px border in the inset.
                    .padding(start = 11.dp, end = 9.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    AIText(options.firstOrNull { it.value == value }?.label ?: placeholder, Modifier.weight(1f), muted = value.isEmpty()); AIIcon(AIIconName.chevronDown)
                }
            }
            DropdownMenu(open, { open = false }) { options.forEach { option -> DropdownMenuItem(text = { AIText(option.label) }, onClick = { onValueChange(option.value); open = false }, trailingIcon = { if (option.value == value) AIIcon(AIIconName.check) }) } }
        }
    }
}
@Composable fun AISwitch(value: Boolean, onValueChange: (Boolean) -> Unit, label: String, modifier: Modifier = Modifier, enabled: Boolean = true) {
    val c = AITheme.colors
    Row(modifier.heightIn(min = 48.dp).toggleable(value, enabled, Role.Switch, onValueChange).semantics { contentDescription = label }
        .alpha(if (enabled) 1f else .5f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.width(32.dp).height(18.4.dp).background(if (value) c.primary else if (c.dark) c.muted else c.border, RoundedCornerShape(50)).padding(1.2.dp)) {
            Box(Modifier.size(16.dp).align(if (value) Alignment.CenterEnd else Alignment.CenterStart).background(if (value) c.onPrimary else Color.White, RoundedCornerShape(50)))
        }
        AIText(label, variant = "label")
    }
}
@Composable fun AIProgress(value: Float, max: Float = 100f, label: String = "", modifier: Modifier = Modifier) {
    val progress = if (value.isFinite() && max.isFinite() && max > 0) (value / max).coerceIn(0f, 1f) else 0f
    val c = AITheme.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (label.isNotEmpty()) AIText(label)
        Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(50)).background(c.muted).semantics { contentDescription = label.ifEmpty { "Progress" }; progressBarRangeInfo = ProgressBarRangeInfo(progress, 0f..1f) }) {
            Box(Modifier.fillMaxWidth(progress).fillMaxHeight().background(c.primary))
        }
    }
}
@Composable fun AISeparator(modifier: Modifier = Modifier) { HorizontalDivider(modifier, color = AITheme.colors.border) }
@Composable fun AIStack(modifier: Modifier = Modifier, gap: Dp = 12.dp, content: @Composable ColumnScope.() -> Unit) { Column(modifier, verticalArrangement = Arrangement.spacedBy(gap), content = content) }
@Composable fun AIRow(modifier: Modifier = Modifier, gap: Dp = 8.dp, content: @Composable FlowRowScope.() -> Unit) { FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(gap), verticalArrangement = Arrangement.spacedBy(gap), content = content) }
