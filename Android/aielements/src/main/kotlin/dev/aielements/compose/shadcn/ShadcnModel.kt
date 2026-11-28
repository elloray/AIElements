package dev.aielements.compose

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
enum class AIShadcnKind {
    @SerialName("accordion") Accordion,
    @SerialName("alert") Alert,
    @SerialName("alert-dialog") AlertDialog,
    @SerialName("aspect-ratio") AspectRatio,
    @SerialName("attachment") Attachment,
    @SerialName("avatar") Avatar,
    @SerialName("badge") Badge,
    @SerialName("breadcrumb") Breadcrumb,
    @SerialName("bubble") Bubble,
    @SerialName("button") Button,
    @SerialName("button-group") ButtonGroup,
    @SerialName("calendar") Calendar,
    @SerialName("card") Card,
    @SerialName("carousel") Carousel,
    @SerialName("chart") Chart,
    @SerialName("checkbox") Checkbox,
    @SerialName("code-block") CodeBlock,
    @SerialName("collapsible") Collapsible,
    @SerialName("combobox") Combobox,
    @SerialName("command") Command,
    @SerialName("context-menu") ContextMenu,
    @SerialName("data-table") DataTable,
    @SerialName("date-picker") DatePicker,
    @SerialName("dialog") Dialog,
    @SerialName("direction") Direction,
    @SerialName("drawer") Drawer,
    @SerialName("dropdown-menu") DropdownMenu,
    @SerialName("empty") Empty,
    @SerialName("field") Field,
    @SerialName("hover-card") HoverCard,
    @SerialName("input") Input,
    @SerialName("input-group") InputGroup,
    @SerialName("input-otp") InputOtp,
    @SerialName("item") Item,
    @SerialName("kbd") Kbd,
    @SerialName("label") Label,
    @SerialName("marker") Marker,
    @SerialName("menubar") Menubar,
    @SerialName("message") Message,
    @SerialName("message-scroller") MessageScroller,
    @SerialName("native-select") NativeSelect,
    @SerialName("navigation-menu") NavigationMenu,
    @SerialName("pagination") Pagination,
    @SerialName("popover") Popover,
    @SerialName("progress") Progress,
    @SerialName("questionnaire") Questionnaire,
    @SerialName("radio-group") RadioGroup,
    @SerialName("resizable") Resizable,
    @SerialName("scroll-area") ScrollArea,
    @SerialName("select") Select,
    @SerialName("separator") Separator,
    @SerialName("sheet") Sheet,
    @SerialName("sidebar") Sidebar,
    @SerialName("skeleton") Skeleton,
    @SerialName("slider") Slider,
    @SerialName("sonner") Sonner,
    @SerialName("spinner") Spinner,
    @SerialName("switch") Switch,
    @SerialName("table") Table,
    @SerialName("tabs") Tabs,
    @SerialName("textarea") Textarea,
    @SerialName("toast") Toast,
    @SerialName("toggle") Toggle,
    @SerialName("toggle-group") ToggleGroup,
    @SerialName("tooltip") Tooltip,
    @SerialName("trace") Trace,
    @SerialName("typography") Typography,
    @SerialName("column") Column,
    @SerialName("row") Row,
    @SerialName("text") Text,
    @SerialName("image") Image;

    val slug: String
        get() = name.replace(Regex("([a-z])([A-Z])"), "$1-$2").lowercase()
}

@Serializable
data class AIShadcnItem(
    val label: String,
    val id: String? = null,
    val detail: String = "",
    val icon: String? = null,
    val disabled: Boolean = false,
) {
    val key
        get() = id ?: label
}

@Serializable
data class AIShadcnNode(
    val kind: AIShadcnKind,
    val label: String = "",
    val id: String? = null,
    val heading: String = "",
    val detail: String = "",
    val value: String = "",
    val placeholder: String = "",
    val action: String? = null,
    val variant: String = "",
    val icon: String? = null,
    val asset: String? = null,
    val align: String = "",
    val width: Float? = null,
    val height: Float? = null,
    val size: Float? = null,
    val gap: Float = 8f,
    val items: List<AIShadcnItem> = emptyList(),
    val children: List<AIShadcnNode> = emptyList(),
    val columns: List<String> = emptyList(),
    val rows: List<List<String>> = emptyList(),
    val rowIDs: List<String>? = null,
    val filterColumn: Int? = null,
)

@Serializable
data class AIShadcnExample(
    val id: String,
    val title: String,
    val summary: String,
    val section: String? = null,
    val selector: String? = null,
    val root: AIShadcnNode,
)

object AIShadcnCatalog {
    fun examples(context: Context): List<AIShadcnExample> =
        context.assets.open("shadcn-catalog.json").bufferedReader().use {
            Json.decodeFromString(it.readText())
        }
}

class AIShadcnState(initial: Map<String, String> = emptyMap()) {
    val values = mutableStateMapOf<String, String>().apply { putAll(initial) }
}

@Composable
fun rememberAIShadcnState(): AIShadcnState =
    rememberSaveable(
        saver =
            listSaver(
                save = { state -> state.values.flatMap { listOf(it.key, it.value) } },
                restore = { entries ->
                    AIShadcnState(entries.chunked(2).associate { it[0] to it[1] })
                },
            )
    ) {
        AIShadcnState()
    }
