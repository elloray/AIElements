@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package dev.aielements.compose

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.aielements.protocol.*
import kotlinx.serialization.json.*

/** Comparison fixtures only: align example data, never override library typography, colors or touch targets. */
internal val auditPatterns = listOf("chain-of-thought", "chat", "checkpoint", "confirmation", "confirmation-approval", "context", "file-tree", "inline-citation", "message", "model-selector", "plan", "prompt-input", "queue", "reasoning", "sources", "stack-trace", "subagent", "suggestion", "task", "terminal", "test-results", "tool")
internal val auditFoundations = listOf("stack", "row", "card", "text", "button", "badge", "input", "select", "switch", "progress", "separator", "table", "bar-chart", "line-chart", "area-chart")
private val auditSources = listOf(AISource("Install Astro | docs.astro.build", "https://docs.astro.build/en/install-and-setup/"), AISource("create-astro | npmjs.com", "https://www.npmjs.com/package/create-astro"), AISource("pnpm create | pnpm.io", "https://pnpm.io/cli/create"))
private val auditModels = listOf(AIModel("gpt-5", "GPT-5", "OpenAI"), AIModel("gpt-5-mini", "GPT-5 mini", "OpenAI"), AIModel("claude-sonnet", "Claude Sonnet", "Anthropic"))
private const val auditBody = "A set of beautifully designed components that you can customize, extend, and build on."
private const val slowQuestion = "Why is the checkout deploy so slow?"
private const val messageQuestion = "How do I add a settings dialog? It should open from the gear icon in the header."
private const val messageAnswer = "Install Dialog, then open it from the gear button in `site-header.tsx`.\n\n```bash\nnpx shadcn@latest add dialog\n```\n\nWrap the button in a `DialogTrigger` and put the settings form in `DialogContent`. Focus moves into the dialog when it opens, and **Esc** closes it."
@Composable private fun Question(text: String) { AIMessage(AIMessageRole.User) { AIMessageResponse(text) } }
@Composable private fun Answer(text: String) { AIMessage(AIMessageRole.Assistant) { AIMessageResponse(text) } }
@Composable private fun Replay() { AIButton("Replay", variant = "outline") {} }
@Composable private fun AuditComposer(models: Boolean = true, text: String = "", compact: Boolean = false) {
    AIPromptInput(text, {}, placeholder = if (compact) "Ask the agent..." else "Ask the agent to change your code...", onAttachmentsChange = {}, sendAccent = compact, toolbar = {
        if (models) AIModelSelector(auditModels, "gpt-5", {}, effort = "Medium", onEffortChange = {})
    }) {}
}
@Composable internal fun VisualAuditFixture(name: String) {
    if (name in auditFoundations) { FoundationFixture(name); return }
    if (name == "chat") {
        Column(Modifier.fillMaxWidth().height(800.dp).padding(32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            AIChatHeader("New Thread", "Ask the agent to change your code.") {}
            AIChat(emptyList(), Modifier.weight(1f))
            AuditComposer(models = false, text = "Add a dark mode toggle to the settings page.", compact = true)
        }; return
    }
    if (name == "context") { Box(Modifier.fillMaxWidth().padding(vertical = 48.dp), contentAlignment = Alignment.Center) { AIContext(8420, 1260, 980, 128000) }; return }
    if (name == "file-tree") {
        Box(Modifier.fillMaxWidth().padding(vertical = 24.dp), contentAlignment = Alignment.Center) {
            AIFileTree(listOf(AIFileNode("app", listOf(AIFileNode("app/layout.tsx"), AIFileNode("app/page.tsx"))), AIFileNode("components", listOf(AIFileNode("components/ui", listOf(AIFileNode("components/ui/button.tsx"))), AIFileNode("components/login-form.tsx")))),
                selection = "components/ui/button.tsx", modifier = Modifier.width(320.dp), expandedPaths = setOf("app", "components", "components/ui")) {}
        }; return
    }
    val minHeight = if (name in listOf("chain-of-thought", "checkpoint", "confirmation", "confirmation-approval", "plan", "queue", "reasoning", "sources", "stack-trace", "subagent", "task", "terminal", "test-results", "tool")) 288.dp else 0.dp
    Column(Modifier.fillMaxWidth().then(if (name == "confirmation") Modifier.height(288.dp) else Modifier.heightIn(min = minHeight)).padding(vertical = 24.dp), verticalArrangement = Arrangement.spacedBy(if (name == "message") 32.dp else 16.dp)) {
        when (name) {
            "chain-of-thought" -> {
                Question(slowQuestion)
                AIChainOfThought(listOf(AIStep("log", "Read the build log for dpl_8Kx2", AIStatus.Completed, "install    41s\ncompile    38s\nimages   3m 52s"), AIStep("search", "Searched the web for next.js image cache key", AIStatus.Completed), AIStep("code", "Searched the code for cacheKey", AIStatus.Completed, "const cacheKey = process.env.VERCEL_GIT_COMMIT_SHA")))
                Answer("Image optimization takes almost four minutes because its cache key includes the commit hash. Key it on the image directory instead."); Replay()
            }
            "checkpoint" -> { Question("Rename the button component to action."); Answer("Renamed Button to Action in components/ui/button.tsx."); AICheckpoint("Button renamed") {}; Question("Update the docs to match."); Answer("Updated the Button page to say Action.") }
            "confirmation" -> { Spacer(Modifier.weight(1f)); AIButton("Send message", variant = "outline") {} }
            "confirmation-approval" -> {
                Question("Clean up the build folder."); AIReasoning("The build artifacts are in dist. Ask for approval before removing them.")
                AIConfirmation("Run rm -rf dist?", "The command runs in this project.", AIConfirmationDecision.Pending, {})
                AIButton("Reset", variant = "outline") {}
            }
            "inline-citation" -> AICitedText(listOf(
                AICitedPart.Text("Next.js streams a route in chunks, so the page shows up before every request finishes. "), AICitedPart.Citation(listOf(AISource("Streaming", "https://nextjs.org/docs/app/building-your-application/routing/loading-ui-and-streaming"))),
                AICitedPart.Text("\n\nWrap a slow part of the page in a Suspense boundary and React sends the fallback first. When the data resolves, the finished HTML streams into the same response and replaces the fallback, with no extra request from the browser. "), AICitedPart.Citation(listOf(AISource("Suspense", "https://react.dev/reference/react/Suspense"))),
                AICitedPart.Text(" Server Components help here, because their code never ships to the browser. "), AICitedPart.Citation(listOf(AISource("Server Components", "https://react.dev/reference/rsc/server-components"))),
                AICitedPart.Text("\n\nA loading.tsx file does the same for a whole route segment. "), AICitedPart.Citation(listOf(AISource("Loading UI", "https://nextjs.org/docs/app/api-reference/file-conventions/loading"))),
                AICitedPart.Text(" It all runs over chunked transfer encoding, so there is nothing extra to set up. "), AICitedPart.Citation(listOf(AISource("Transfer-Encoding", "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding")))
            ))
            "message" -> {
                Column { Question(messageQuestion); AIMessageActions(messageQuestion, onEdit = {}) }
                Column { Answer(messageAnswer); AIMessageActions(messageAnswer, onRetry = {}, onFeedback = {}) }
            }
            "model-selector", "prompt-input" -> AuditComposer()
            "plan" -> {
                Question("Migrate the dialog components to Base UI.")
                AIPlan("migrate to Base UI", listOf("Install @base-ui/react", "Replace the Radix imports", "Rename asChild to render", "Run the type checker").mapIndexed { i, s -> AIStep("$i", s, AIStatus.Completed) })
                Answer("Migrated Dialog and AlertDialog. The type checker passes."); Replay()
            }
            "queue" -> {
                Question("Add dark mode to the settings page.")
                AIQueue(listOf("Add a dark variant to the theme tokens", "Read the theme from a cookie", "Add a toggle to the settings page", "Check contrast on the charts").mapIndexed { i, s -> AIStep("$i", s, AIStatus.Completed) })
                Answer("Dark mode is in. The toggle is under Settings, Appearance."); Replay()
            }
            "reasoning" -> {
                Question(slowQuestion)
                AIReasoning("The deploy log has three phases. Install takes 38s and next build takes 52s, both normal for this repo.\n\nImage optimization takes 3m 50s. It reruns on every deploy because its cache key includes the commit hash, so the cache never hits.", durationSeconds = 5)
                Answer("Image optimization is the bottleneck. Key its cache on the lockfile and the image directory instead of the commit hash, and the deploy should take under two minutes."); Replay()
            }
            "sources" -> { Question("How do I start an Astro project with pnpm?"); Answer("Run pnpm create astro@latest and follow the prompts. It scaffolds the project and installs the dependencies."); AISources(auditSources); Replay() }
            "stack-trace" -> {
                Question("Reset the database and seed it.")
                AITrace { AITool("pnpm prisma migrate reset --skip-seed", output = "Database reset."); AIStackTrace("TypeError: Cannot read properties of undefined (reading 'email')", listOf(AIStackFrame("1", "seedUsers", "prisma/seed.ts", 27), AIStackFrame("2", "main", "prisma/seed.ts", 51), AIStackFrame("3", "process", "node_modules/server/index.js", 89), AIStackFrame("4", "run", "node_modules/tsx/index.js", 19), AIStackFrame("5", "handle", "node:internal/modules/cjs/loader", 12), AIStackFrame("6", "launch", "node:internal/main/run_main_module", 18))) }
                Answer("The migrations ran, but the seed failed in seedUsers. One fixture has no profile, so profile.email is undefined."); Replay()
            }
            "subagent" -> {
                Question("Why does image optimization rerun on every deploy?")
                AISubagent("research", AIStatus.Completed) {
                    AITool("grep -rn cacheKey scripts", icon = AIIconName.circleCheck, output = "scripts/optimize-images.ts:14: cacheKey = commit.sha")
                    AITool("sed -n 13,15p scripts/optimize-images.ts", icon = AIIconName.circleCheck, output = "const cacheKey = commit.sha")
                    AITool("ls public/images | wc -l", icon = AIIconName.circleCheck, output = "1240")
                    AIText("The cache is keyed on the commit SHA, so every deploy misses it and optimizes all 1,240 images again.", muted = true)
                }
                Answer("Image optimization reruns because its cache is keyed on the commit SHA, which changes on every deploy. Key the cache on a hash of public/images instead, and unchanged images will be skipped."); Replay()
            }
            "suggestion" -> { AISuggestions(listOf("Add a dark mode toggle", "Fix the failing build", "Write tests for the form", "Upgrade to Next.js 16", "Add a loading state", "Find unused dependencies")) {}; AuditComposer(models = false) }
            "task" -> {
                Question("Add Open Graph metadata to the home page.")
                AITrace { AITask("Found the project files", listOf(AIStep("find", "Searched for app/page.tsx", AIStatus.Completed), AIStep("read", "Read app/page.tsx", AIStatus.Completed, "export default function Page() {\n  return <Chat />\n}"))); AITask("Updated the page metadata", listOf(AIStep("layout", "Edited app/layout.tsx", AIStatus.Completed), AIStep("page", "Edited app/page.tsx", AIStatus.Completed))) }
                Answer("Added Open Graph defaults to app/layout.tsx and a title, description and image for the home page in app/page.tsx."); Replay()
            }
            "terminal" -> {
                Question("Run the checks, then build the app.")
                AITrace {
                    AITerminal("pnpm lint", "No lint errors."); AITerminal("pnpm test", "All tests passed.")
                    AITerminal("pnpm build", "> acme-chat@0.1.0 build\n> next build\n\n   ▲ Next.js 16.3.0\n   Creating an optimized production build ...\n ✓ Compiled successfully in 4.2s\n ✓ Generating static pages (12/12)\n\nRoute (app)                Size  First Load JS\n┌ ○ /                     1.9 kB       112 kB\n└ ƒ /api/chat              141 B       102 kB")
                }
                Answer("Lint and tests pass, and the build compiled both routes."); Replay()
            }
            "test-results" -> {
                Question("Run the checkout tests.")
                AITestResults("pnpm test checkout", listOf(AITestResult("a", "adds an item", AIStatus.Completed, suite = "cart.test.ts"), AITestResult("b", "removes an item", AIStatus.Completed, suite = "cart.test.ts"), AITestResult("c", "calculates the total", AIStatus.Completed, suite = "cart.test.ts"), AITestResult("d", "charges the saved card", AIStatus.Completed, suite = "payment.test.ts"), AITestResult("e", "retries a declined card", AIStatus.Failed, "Expected 2 charge attempts, received 1\n\n  at Object.<anonymous> (src/payment.test.ts:58:22)", suite = "payment.test.ts")))
                Answer("One test failed. The payment client does not retry a declined card, so the second charge attempt never happens."); Replay()
            }
            "tool" -> {
                Question("Which package managers are installed?")
                AITrace { AITool("node --version", output = "v24.0.0"); AITool("npm --version", output = "11.0.0"); AITool("pnpm --version", AIStatus.Failed, "command not found: pnpm") }
                Answer("Node 24 and npm 11 are installed. pnpm is not."); Replay()
            }
        }
    }
}
@Composable private fun FoundationFixture(name: String) {
    val control = name in listOf("button", "badge", "row", "input", "select", "switch", "progress", "separator")
    Box(Modifier.fillMaxWidth().then(if (control) Modifier.heightIn(min = 64.dp) else Modifier), contentAlignment = Alignment.Center) {
        when (name) {
            "text" -> AIText(auditBody)
            "stack" -> AIStack(gap = 16.dp) { AIStack(gap = 6.dp) { AIText("shadcn/ui", variant = "label"); AIText("The Foundation for your Design System", muted = true) }; AISeparator(); AIText(auditBody) }
            "row", "badge" -> AIRow(gap = 8.dp) { listOf("Badge", "Secondary", "Destructive", "Outline").zip(listOf("primary", "secondary", "destructive", "outline")).forEach { (label, variant) -> AIBadge(label, variant) } }
            "button" -> AIButton("Button", capsule = false) {}
            "input" -> AIInput("", {}, Modifier.width(320.dp), placeholder = "Enter text")
            "select" -> AISelect("", listOf("Apple", "Banana", "Blueberry", "Grapes", "Pineapple").map { AIOption(it.lowercase(), it) }, {}, Modifier.width(192.dp), placeholder = "Select a fruit")
            "switch" -> AISwitch(false, {}, "Airplane Mode")
            "progress" -> AIProgress(66f, modifier = Modifier.width(216.dp))
            "separator" -> AISeparator()
            "card" -> AICard(title = "Login to your account", description = "Enter your email below to login to your account",
                headerAction = { AIButton("Sign Up", variant = "ghost") {} }, footerContent = {
                    AIButton("Login", Modifier.fillMaxWidth(), capsule = false) {}
                    AIButton("Login with Google", Modifier.fillMaxWidth(), variant = "outline", capsule = false) {}
                }) {
                AIInput("", {}, label = "Email", placeholder = "m@example.com")
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AIText("Password", Modifier.weight(1f), variant = "label")
                        AIButton("Forgot your password?", variant = "link") {}
                    }
                    AIInput("", {}, placeholder = "")
                }
            }
            "table" -> {
                val data = listOf(listOf("INV001", "Paid", "Credit Card", "$250.00"), listOf("INV002", "Pending", "PayPal", "$150.00"), listOf("INV003", "Unpaid", "Bank Transfer", "$350.00"), listOf("INV004", "Paid", "Credit Card", "$450.00"), listOf("INV005", "Paid", "PayPal", "$550.00"), listOf("INV006", "Pending", "Bank Transfer", "$200.00"), listOf("INV007", "Unpaid", "Credit Card", "$300.00"))
                val labels = listOf("Invoice", "Status", "Method", "Amount")
                AITable(listOf(AITableColumn("Invoice", "Invoice", 100.dp, emphasized = true), AITableColumn("Status", "Status"), AITableColumn("Method", "Method"), AITableColumn("Amount", "Amount", trailing = true)), data.map { labels.zip(it).toMap() }, caption = "A list of your recent invoices.", footer = mapOf("Invoice" to "Total", "Amount" to "$2,500.00"))
            }
            else -> {
                val document = remember(name) {
                    val source = AIUIDocument.decode(AIUIResources.bytes(name))
                    if (name != "area-chart") source else source.copy(nodes = source.nodes.mapValues { (id, node) -> if (id == source.root) node.copy(props = JsonObject(node.props + ("description" to JsonPrimitive("Showing total visitors for the last 6 months")) + ("footnote" to JsonPrimitive("January - June 2024")))) else node })
                }
                val store = remember(document) { AIUIStore(document) }; AIUIRenderer(store) {}
            }
        }
    }
}
