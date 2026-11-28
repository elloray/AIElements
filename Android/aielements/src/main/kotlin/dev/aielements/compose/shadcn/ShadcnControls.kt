@file:OptIn(
    androidx.compose.foundation.ExperimentalFoundationApi::class,
    androidx.compose.foundation.layout.ExperimentalLayoutApi::class,
)

package dev.aielements.compose

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.Dialog
import dev.aielements.compose.AIShadcnKind.*

@Composable
internal fun ShadcnPart.Form() {
    val c = AITheme.colors
    when (node.kind) {
        Checkbox ->
            CheckRow(node.label, value == "true", false) { set((value != "true").toString()) }
        Label ->
            if (node.children.firstOrNull()?.kind == Checkbox) {
                val control = child(0)
                CheckRow(node.label, control.value == "true", false) {
                    control.set((control.value != "true").toString())
                }
            } else
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Children()
                    Caption(node.label, bold = true)
                }
        Field ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Caption(node.label, bold = true)
                if (node.variant == "description-first") Caption(node.detail, muted = true)
                Children()
                if (node.variant != "description-first" && node.detail.isNotEmpty())
                    Caption(node.detail, muted = true)
            }
        Input,
        InputGroup,
        Textarea ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (node.label.isNotEmpty())
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Caption(node.label, bold = true, modifier = Modifier.weight(1f))
                        node.action?.let {
                            Caption(it, modifier = Modifier.clickable { press(it) })
                        }
                    }
                val multiline = node.kind == Textarea
                Row(
                    Modifier.fillMaxWidth()
                        .heightIn(min = if (multiline) 64.dp else 32.dp)
                        .panel(c.input, c.inputBorder)
                        .padding(horizontal = 11.dp, vertical = if (multiline) 8.dp else 4.dp),
                    verticalAlignment =
                        if (multiline) Alignment.Top else Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (node.kind == InputGroup) AIIcon(glyph(node.icon ?: "search"))
                    BasicTextField(
                        value,
                        ::set,
                        Modifier.weight(1f).semantics {
                            contentDescription = node.label.ifEmpty { node.placeholder }
                        },
                        textStyle = AITypography.body.copy(color = c.foreground),
                        singleLine = !multiline,
                        minLines = if (multiline) 2 else 1,
                        visualTransformation =
                            if (node.variant == "password") PasswordVisualTransformation()
                            else VisualTransformation.None,
                        keyboardOptions =
                            KeyboardOptions(
                                keyboardType =
                                    if (node.variant == "password") KeyboardType.Password
                                    else KeyboardType.Text
                            ),
                        cursorBrush = SolidColor(c.foreground),
                        decorationBox = { field ->
                            Box {
                                if (value.isEmpty()) Caption(node.placeholder, muted = true)
                                field()
                            }
                        },
                    )
                    Children()
                }
            }
        InputOtp -> {
            val length = (node.size?.toInt() ?: 6).coerceIn(1, 32)
            BasicTextField(
                value,
                { set(it.filter(Char::isDigit).take(length)) },
                singleLine = true,
                modifier =
                    Modifier.semantics {
                        contentDescription = node.label.ifEmpty { "One-time password" }
                    },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                decorationBox = { inner ->
                    Box {
                        Row(Modifier.panel(c.input, c.inputBorder, 10)) {
                            repeat(length) { i ->
                                if (i > 0)
                                    Box(
                                        Modifier.width(1.dp).height(32.dp).background(c.inputBorder)
                                    )
                                Box(
                                    Modifier.size(31.dp, 32.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Caption(value.getOrNull(i)?.toString().orEmpty())
                                }
                            }
                        }
                        Box(Modifier.matchParentSize().alpha(0f)) { inner() }
                    }
                },
            )
        }
        RadioGroup ->
            Column(
                modifier = Modifier.selectableGroup(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (node.label.isNotEmpty()) Caption(node.label, 16, true)
                if (node.detail.isNotEmpty()) Caption(node.detail, muted = true)
                node.items.forEach { item ->
                    CheckRow(item.label, value == item.key, true, item.detail, !item.disabled) {
                        set(item.key)
                    }
                }
            }
        Slider -> {
            val number = (value.toFloatOrNull() ?: 0f).coerceIn(0f, 100f)
            CompactRange(number, { set(it.toInt().toString()) }, node.label)
        }
        Toggle ->
            Row(
                Modifier.heightIn(min = 28.dp)
                    .panel(
                        if (value == "true") c.muted else Color.Transparent,
                        if (node.variant == "outline") c.inputBorder else Color.Transparent,
                        8,
                    )
                    .toggleable(value == "true", role = Role.Checkbox) { set(it.toString()) }
                    .padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                node.icon?.let { AIIcon(glyph(it), Modifier.size(14.dp), c.foreground) }
                Caption(node.label, bold = true)
            }
        else -> Unit
    }
}

@Composable
internal fun CheckRow(
    label: String,
    checked: Boolean,
    radio: Boolean,
    detail: String = "",
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val c = AITheme.colors
    val shape = if (radio) CircleShape else RoundedCornerShape(4.dp)
    val interactive =
        if (radio) Modifier.selectable(checked, enabled, Role.RadioButton, onClick)
        else Modifier.toggleable(checked, enabled, Role.Checkbox) { onClick() }
    Row(
        interactive.alpha(if (enabled) 1f else .5f),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (radio) 12.dp else 8.dp),
    ) {
        Box(
            Modifier.size(16.dp)
                .background(if (checked) c.primary else c.input, shape)
                .border(1.dp, if (checked) c.primary else c.inputBorder, shape),
            contentAlignment = Alignment.Center,
        ) {
            if (checked) {
                if (radio) Box(Modifier.size(6.dp).background(c.onPrimary, CircleShape))
                else AIIcon(AIIconName.check, Modifier.size(14.dp), c.onPrimary)
            }
        }
        if (label.isNotEmpty())
            Column {
                Caption(label, bold = true)
                if (detail.isNotEmpty()) Caption(detail, muted = true)
            }
    }
}

@Composable
internal fun ShadcnPart.Segmented() {
    val c = AITheme.colors
    val separate = node.kind == ToggleGroup && node.variant == "multiple"
    val crumbs = node.kind == Breadcrumb
    val group = node.kind == ButtonGroup || node.kind == ToggleGroup
    val tabs = node.kind == Tabs
    val page = node.kind == Pagination
    val current = value.ifEmpty { node.items.firstOrNull()?.key.orEmpty() }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        FlowRow(
            Modifier.panel(
                if (group && node.variant == "secondary") c.muted else Color.Transparent,
                if (group && !separate && node.variant != "secondary") c.inputBorder
                else Color.Transparent,
                9,
            ),
            horizontalArrangement =
                Arrangement.spacedBy(
                    if (crumbs || separate) 8.dp else if (tabs || page) 4.dp else 0.dp
                ),
            itemVerticalAlignment = Alignment.CenterVertically,
        ) {
            node.items.forEachIndexed { i, item ->
                val multiple = node.kind == ToggleGroup && node.variant == "multiple"
                val itemPath = "$path/" + item.key
                val active =
                    if (multiple) state.values[itemPath] == "true"
                    else !crumbs && node.kind != ButtonGroup && current == item.key
                if (crumbs && i > 0) AIIcon(AIIconName.chevronRight, Modifier.size(12.dp))
                if (group && !separate && i > 0)
                    Box(Modifier.size(1.dp, 28.dp).background(c.border))
                Box(
                    Modifier.heightIn(min = if (crumbs) 20.dp else 32.dp)
                        .then(if (group || page) Modifier.widthIn(min = 32.dp) else Modifier)
                        .panel(
                            if (active && (group || tabs && node.variant != "line")) c.muted
                            else Color.Transparent,
                            if (separate || page && active) c.inputBorder else Color.Transparent,
                            if (group && !separate) 0 else 8,
                        )
                        .clickable(
                            enabled = !item.disabled && !(crumbs && i == node.items.lastIndex),
                            role = if (tabs) Role.Tab else Role.Button,
                        ) {
                            when {
                                crumbs || node.kind == ButtonGroup -> press(item.key)
                                multiple -> {
                                    state.values[itemPath] = (!active).toString()
                                    action(itemPath, (!active).toString())
                                }
                                else -> set(item.key)
                            }
                        }
                        .semantics {
                            if (item.icon != null) contentDescription = item.label
                            if (!crumbs) selected = active
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    if (item.icon != null)
                        AIIcon(glyph(item.icon), Modifier.padding(horizontal = 8.dp), c.foreground)
                    else
                        Caption(
                            item.label,
                            bold = !crumbs,
                            muted = crumbs && i < node.items.lastIndex || tabs && !active,
                            modifier = Modifier.padding(horizontal = if (crumbs) 0.dp else 8.dp),
                        )
                    if (tabs && active && node.variant == "line")
                        Box(Modifier.matchParentSize(), contentAlignment = Alignment.BottomCenter) {
                            Box(
                                Modifier.fillMaxWidth()
                                    .height(2.dp)
                                    .background(c.foreground, CircleShape)
                            )
                        }
                }
            }
        }
        val i = node.items.indexOfFirst { it.key == current }
        if (tabs && i in node.children.indices) child(i).Render()
    }
}

@Composable
internal fun ShadcnPart.Choice() {
    val c = AITheme.colors
    var open by rememberSaveable { mutableStateOf(false) }
    var query by rememberSaveable { mutableStateOf("") }
    val combo = node.kind == Combobox
    val command = node.kind == Command
    val context = node.kind == ContextMenu
    val select = node.kind == Select || node.kind == NativeSelect
    val choose: (AIShadcnItem) -> Unit = { item ->
        set(item.key)
        open = false
        query = ""
    }
    Box {
        when {
            context ->
                Box(
                    Modifier.fillMaxWidth()
                        .height((node.height ?: 180f).dp)
                        .panel(c.background, c.border, 12)
                        .combinedClickable(
                            onClick = { open = true },
                            onLongClick = { open = true },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Caption("Long press here")
                }
            combo ->
                Row(
                    Modifier.fillMaxWidth()
                        .heightIn(min = 32.dp)
                        .panel(c.input, c.inputBorder)
                        .padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    BasicTextField(
                        if (open) query
                        else node.items.firstOrNull { it.key == value }?.label.orEmpty(),
                        {
                            query = it
                            open = true
                        },
                        Modifier.weight(1f).semantics { contentDescription = node.placeholder },
                        singleLine = true,
                        textStyle = AITypography.body.copy(color = c.foreground),
                        decorationBox = { field ->
                            Box {
                                if (query.isEmpty() && (open || value.isEmpty()))
                                    Caption(node.placeholder, muted = true)
                                field()
                            }
                        },
                    )
                    AIIconButton(AIIconName.chevronDown, "Show choices") {
                        query = ""
                        open = !open
                    }
                }
            select ->
                Row(
                    Modifier.defaultMinSize(minHeight = 32.dp)
                        .then(if (node.width != null) Modifier.fillMaxWidth() else Modifier)
                        .panel(c.input, c.inputBorder)
                        .clickable(role = Role.DropdownList) { open = true }
                        .padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Caption(
                        node.items.firstOrNull { it.key == value }?.label ?: node.placeholder,
                        muted = value.isEmpty(),
                        modifier = if (node.width != null) Modifier.weight(1f) else Modifier,
                    )
                    AIIcon(AIIconName.chevronDown, Modifier.size(14.dp))
                }
            else ->
                AIButton(
                    node.label,
                    variant = node.variant.ifEmpty { "outline" },
                    capsule = false,
                ) {
                    query = ""
                    open = true
                }
        }
        if (command && open) {
            Dialog(onDismissRequest = { open = false }) {
                Column(Modifier.fillMaxWidth().panel(c.card, c.border, 12).padding(8.dp)) {
                    AIInput(query, { query = it }, placeholder = node.placeholder)
                    Options(query, choose)
                }
            }
        } else if (!command) {
            DropdownMenu(
                open,
                { open = false },
                containerColor = c.card,
                properties = androidx.compose.ui.window.PopupProperties(focusable = !combo),
            ) {
                Options(if (combo) query else "", choose)
            }
        }
    }
}

@Composable
internal fun ShadcnPart.Options(query: String, choose: (AIShadcnItem) -> Unit) {
    if (node.heading.isNotEmpty()) Caption(node.heading, 12, true, true, Modifier.padding(8.dp))
    val choices = node.items.filter { it.label.contains(query, true) }
    if (choices.isEmpty()) Caption("No results found.", modifier = Modifier.padding(8.dp))
    choices.forEach { item ->
        Row(
            Modifier.widthIn(min = 144.dp)
                .fillMaxWidth()
                .heightIn(min = 28.dp)
                .clickable(enabled = !item.disabled) { choose(item) }
                .alpha(if (item.disabled) .5f else 1f)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Caption(item.label, modifier = Modifier.weight(1f))
            if (value == item.key) AIIcon(AIIconName.check, Modifier.size(14.dp))
        }
    }
}
