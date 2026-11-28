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
fun String.displayName() = removePrefix("shadcn/").split('-').joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
@Composable fun Gallery(initialPattern: String?, initialTheme: String?) {
    var theme by rememberSaveable { mutableStateOf(initialTheme ?: "System") }
    var selected by rememberSaveable { mutableStateOf(initialPattern) }
    var query by rememberSaveable { mutableStateOf("") }
    var themeMenu by remember { mutableStateOf(false) }
    val dark = when (theme) { "Dark" -> true; "Light" -> false; else -> isSystemInDarkTheme() }
    val view = LocalView.current
    val shadcn = remember(view.context) { AIShadcnCatalog.examples(view.context).associateBy { "shadcn/" + it.id } }
    fun title(key: String) = shadcn[key]?.title ?: key.displayName()
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
                    TopAppBar(title = { AIText(if (wide || selected == null) "AIElements" else title(selected!!), variant = "title") },
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
                                val groups = listOf("AI patterns · 21" to patterns, "Generative UI" to listOf("Generative UI"), "Foundation · 15" to foundations, "shadcn/ui" to shadcn.keys.toList())
                                groups.forEach { (group, names) ->
                                    val matches = names.filter { title(it).contains(query, ignoreCase = true) }
                                    if (matches.isNotEmpty()) {
                                        item("section:$group") { AIText(group, Modifier.padding(8.dp), muted = true, variant = "caption") }
                                        items(matches, key = { "component:$it" }) { name ->
                                            ListItem(headlineContent = { AIText(title(name)) }, trailingContent = { AIIcon(AIIconName.chevronRight) },
                                                colors = ListItemDefaults.colors(containerColor = if (selected == name) AITheme.colors.muted else AITheme.colors.background),
                                                modifier = Modifier.clickable { selected = name })
                                        }
                                    }
                                }
                                if ((patterns + foundations + shadcn.keys + "Generative UI").none { title(it).contains(query, true) }) item { AIText("No components match this search.", Modifier.padding(12.dp), muted = true) }
                            }
                        }
                        if (wide) VerticalDivider(color = AITheme.colors.border)
                        if (wide || selected != null) Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.TopCenter) {
                            val name = selected ?: "Chat"
                            key(name) {
                                Column(Modifier.widthIn(max = 720.dp).fillMaxSize().padding(horizontal = 20.dp)) {
                                    if (wide) AIText(title(name), Modifier.padding(top = 24.dp), variant = "title")
                                    if (name !in shadcn) AIText("Interactive local demo · No model or commands run", Modifier.padding(vertical = 12.dp), muted = true, variant = "caption")
                                    if (name == "Chat") ChatDemo(Modifier.weight(1f))
                                    else Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                                        val official = shadcn[name]
                                        if (official != null) {
                                            AIText(official.summary, muted = true)
                                            Box(Modifier.fillMaxWidth().heightIn(min = 160.dp), contentAlignment = Alignment.Center) {
                                                AIShadcnView(if (official.id == "direction") official.root.copy(variant = "picker") else official.root)
                                            }
                                        } else if (name in foundations) FoundationDemo(name) else PatternDemo(name)
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
