package dev.aielements.compose

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextMotion
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.sp

@Immutable
data class AIColors(val background: Color, val foreground: Color, val muted: Color, val mutedForeground: Color, val border: Color, val destructive: Color, val card: Color = background,
    val primary: Color = foreground, val onPrimary: Color = background,
    val input: Color = Color.Transparent, val inputBorder: Color = border,
    val accent: Color = muted, val dark: Boolean = false,
    val prompt: Color = Color(0xFFF2F2F2))
private val Light = AIColors(Color.White, Color.Black, Color(0.960587f, 0.960587f, 0.960587f), Color(0.451519f, 0.451519f, 0.451519f), Color(0.898161f, 0.898161f, 0.898161f), Color(0.906411f, 0f, 0.042121f))
private val Dark = AIColors(Color(0.039388f, 0.039388f, 0.039388f), Color(0.980256f, 0.980256f, 0.980256f), Color(0.149382f, 0.149382f, 0.149382f), Color(0.630163f, 0.630163f, 0.630163f), Color.White.copy(alpha = .1f), Color(1f, .391179f, .403845f),
    card = Color(0xFF171717), primary = Color(0xFFE5E5E5), onPrimary = Color(0xFF171717),
    // Web dark:bg-input/30 composites the 15% white input token at 30% opacity.
    input = Color.White.copy(alpha = .045f), inputBorder = Color.White.copy(alpha = .15f),
    accent = Color(0xFF404040), dark = true, prompt = Color(0xFF1C1C1C))
private val LocalAIColors = staticCompositionLocalOf { Light }
object AITheme { val colors: AIColors @Composable get() = LocalAIColors.current }
object AITypography {
    val geist = FontFamily(Font(R.font.geist_regular), Font(R.font.geist_medium, FontWeight.Medium), Font(R.font.geist_semibold, FontWeight.SemiBold))
    val mono = FontFamily(Font(R.font.geistmono_regular))
    // Fractional advances keep bundled Geist's widths stable across display densities.
    val body = TextStyle(fontFamily = geist, fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.sp, textMotion = TextMotion.Animated,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None))
    val title = body.copy(fontWeight = FontWeight.Medium)
    val label = body.copy(fontSize = 14.sp, lineHeight = 14.sp, fontWeight = FontWeight.Medium, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both, LineHeightStyle.Mode.Fixed), platformStyle = PlatformTextStyle(includeFontPadding = false))
    val caption = body.copy(fontSize = 12.sp, lineHeight = 16.sp)
    val code = body.copy(fontFamily = mono, fontSize = 12.sp, lineHeight = 20.sp)
}
@Composable
fun AIElementsTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val c = if (darkTheme) Dark else Light
    val scheme = (if (darkTheme) darkColorScheme() else lightColorScheme()).copy(
        primary = c.primary, onPrimary = c.onPrimary, secondary = c.mutedForeground, onSecondary = c.background,
        background = c.background, onBackground = c.foreground, surface = c.background, onSurface = c.foreground,
        surfaceVariant = c.muted, onSurfaceVariant = c.mutedForeground, surfaceContainer = c.muted,
        surfaceContainerHigh = c.muted, surfaceContainerHighest = c.muted, surfaceContainerLow = c.background,
        outline = c.border, outlineVariant = c.border, error = c.destructive,
        secondaryContainer = c.muted, onSecondaryContainer = c.foreground,
    )
    CompositionLocalProvider(LocalAIColors provides c) {
        MaterialTheme(colorScheme = scheme, typography = Typography(
            bodyLarge = AITypography.body, bodyMedium = AITypography.body, bodySmall = AITypography.label,
            titleLarge = AITypography.title.copy(fontSize = 20.sp, lineHeight = 28.sp),
            titleMedium = AITypography.title, titleSmall = AITypography.label,
            labelLarge = AITypography.title, labelMedium = AITypography.label, labelSmall = AITypography.label,
        )) { ProvideTextStyle(AITypography.body) { content() } }
    }
}
