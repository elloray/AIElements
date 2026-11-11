@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package dev.aielements.gallery

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import dev.aielements.compose.*
import dev.aielements.protocol.AIUIResources

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { Gallery(intent.getStringExtra("pattern"), intent.getStringExtra("theme")) }
    }
}
val patterns = listOf("Chain of Thought", "Chat", "Checkpoint", "Confirmation", "Context", "File Tree", "Inline Citation", "Message", "Model Selector", "Plan", "Prompt Input", "Queue", "Reasoning", "Sources", "Stack Trace", "Subagent", "Suggestion", "Task", "Terminal", "Test Results", "Tool")
val foundations = AIUIResources.exampleNames.filter { it != "dashboard" }
fun String.displayName() = split('-').joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
@Composable fun Gallery(initialPattern: String?, initialTheme: String?) {
    var theme by rememberSaveable { mutableStateOf(initialTheme ?: "System") }
    var selected by rememberSaveable { mutableStateOf(initialPattern) }
    var query by rememberSaveable { mutableStateOf("") }
    var themeMenu by remember { mutableStateOf(false) }
    val dark = when (theme) { "Dark" -> true; "Light" -> false; else -> isSystemInDarkTheme() }
    val view = LocalView.current
    SideEffect {
        val activity = view.context as? ComponentActivity
        if (activity != null) WindowCompat.getInsetsController(activity.window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
    AIElementsTheme(dark) {
        Surface(Modifier.fillMaxSize()) {
            BoxWithConstraints(Modifier.safeDrawingPadding().imePadding()) {
                val wide = maxWidth >= 760.dp && maxHeight >= 480.dp
                BackHandler(selected != null) { selected = null }
                Column {
                    TopAppBar(title = { AIText(if (wide || selected == null) "AIElements" else selected!!.displayName(), variant = "title") },
                        navigationIcon = { if (!wide && selected != null) AIButton("Back", variant = "ghost") { selected = null } },
                        actions = { Box {
                            AIIconButton(if (dark) AIIconName.moon else AIIconName.sun, "Appearance") { themeMenu = true }
                            DropdownMenu(themeMenu, { themeMenu = false }) { listOf("System", "Light", "Dark").forEach { value ->
                                DropdownMenuItem({ AIText(value) }, { theme = value; themeMenu = false }, trailingIcon = { if (theme == value) AIIcon(AIIconName.check) })
                            } }
                        } })
                    AISeparator()
                    Row(Modifier.weight(1f)) {
                        if (wide || selected == null) Column(if (wide) Modifier.width(280.dp).fillMaxHeight() else Modifier.fillMaxSize()) {
                            AIText("Native components for AI interfaces", Modifier.padding(horizontal = 20.dp, vertical = 12.dp), muted = true)
                            AIInput(query, { query = it }, Modifier.padding(horizontal = 20.dp), placeholder = "Search components")
                            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(12.dp)) {
                                val groups = listOf("AI patterns · 21" to patterns, "Generative UI" to listOf("Generative UI"), "Foundation · 15" to foundations)
                                groups.forEach { (group, names) ->
                                    val matches = names.filter { it.displayName().contains(query, ignoreCase = true) }
                                    if (matches.isNotEmpty()) {
                                        item("section:$group") { AIText(group, Modifier.padding(8.dp), muted = true, variant = "caption") }
                                        items(matches, key = { "component:$it" }) { name ->
                                            ListItem(headlineContent = { AIText(name.displayName()) }, trailingContent = { AIIcon(AIIconName.chevronRight) },
                                                colors = ListItemDefaults.colors(containerColor = if (selected == name) AITheme.colors.muted else AITheme.colors.background),
                                                modifier = Modifier.clickable { selected = name })
                                        }
                                    }
                                }
                                if ((patterns + foundations + "Generative UI").none { it.displayName().contains(query, true) }) item { AIText("No components match this search.", Modifier.padding(12.dp), muted = true) }
                            }
                        }
                        if (wide) VerticalDivider(color = AITheme.colors.border)
                        if (wide || selected != null) Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.TopCenter) {
                            val name = selected ?: "Chat"
                            key(name) {
                                Column(Modifier.widthIn(max = 720.dp).fillMaxSize().padding(horizontal = 20.dp)) {
                                    if (wide) AIText(name.displayName(), Modifier.padding(top = 24.dp), variant = "title")
                                    AIText("Interactive local demo · No model or commands run", Modifier.padding(vertical = 12.dp), muted = true, variant = "caption")
                                    if (name == "Chat") ChatDemo(Modifier.weight(1f))
                                    else Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                        if (name in foundations) FoundationDemo(name) else PatternDemo(name)
                                        Spacer(Modifier.height(24.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
