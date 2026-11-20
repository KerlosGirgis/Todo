package com.k.todo

import android.content.SharedPreferences
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.text.style.TypefaceSpan
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * How one of the app's widgets looks, as the app's settings set it: its
 * background, the colour, size and font of its text, and for the to-do
 * widget, the colour of its checks and whether it lists the tasks that are
 * done.
 *
 * The app keeps it as JSON, as lib/models/widget_style.dart writes it, and
 * its settings draw their preview by the same rules as these: change both
 * together.
 */
data class WidgetStyle(
    /** The background's colour, or null for the theme's, which follows dark mode. */
    val background: Int?,
    /** How much of the background shows, from 0 to 1. */
    val opacity: Float,
    /** The text's colour, or null for automatic: see [ink]. */
    val textColor: Int?,
    val accent: Int,
    /** The text's size, as a multiple of the layout's. */
    val textSize: Float,
    val casual: Boolean,
    val showDone: Boolean,
) {
    /**
     * The text's colour: its own, or for automatic, black or white against a
     * background of a colour of its own that shows enough. Null for the
     * theme's, which the layouts start with, and which the launcher works
     * out afresh in dark mode.
     */
    val ink: Int? get() = textColor ?: inkOn(background, opacity)

    /** Text that comes second, as a task's details: [ink], fainter, or null for the theme's. */
    val secondaryInk: Int? get() = ink?.let { withAlpha(it, 0.6f) }

    /**
     * Colours the widget's background, [id], an image of the theme's widget
     * background, with its corners: in the style's colour, or the theme's,
     * showing as much as its opacity has it.
     */
    fun paintBackground(views: RemoteViews, id: Int) {
        if (opacity <= 0f) {
            views.setViewVisibility(id, View.GONE)
            return
        }
        views.setViewVisibility(id, View.VISIBLE)
        background?.let { views.setInt(id, "setColorFilter", it or OPAQUE) }
        views.setInt(id, "setImageAlpha", (opacity * 255).roundToInt())
    }

    /** [text] in the style's font, and struck through if it's [struck]. */
    fun styled(text: CharSequence, struck: Boolean = false): CharSequence {
        if (!casual && !struck) return text
        val styled = SpannableString(text)
        if (casual) styled.setSpan(TypefaceSpan("casual"), 0, styled.length, WHOLE)
        if (struck) styled.setSpan(StrikethroughSpan(), 0, styled.length, WHOLE)
        return styled
    }

    /** Sizes the text of [id], [base] sp at the style's own size. */
    fun size(views: RemoteViews, id: Int, base: Float) =
        views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, base * textSize)

    companion object {
        private const val OPAQUE = 0xFF000000.toInt()
        private const val WHOLE = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE

        /** Text colours for light backgrounds, and for dark ones. */
        private const val DARK_INK = 0xDE000000.toInt()
        private const val LIGHT_INK = 0xFFFFFFFF.toInt()

        /** The app's blue. */
        private const val APP_BLUE = 0xFF3D5AFE.toInt()

        /** The to-do widget's, as it first comes. */
        val TASKS = WidgetStyle(null, 1f, null, APP_BLUE, 1f, casual = false, showDone = false)

        /** The note widget's, as it first comes: bold text with no background. */
        val NOTE = TASKS.copy(opacity = 0f)

        /** The style kept under [key], with [defaults] for anything it lacks; null when there's none, or it can't be read. */
        fun read(prefs: SharedPreferences, key: String, defaults: WidgetStyle): WidgetStyle? {
            val saved = prefs.getString(key, null) ?: return null
            return try {
                parse(JSONObject(saved), defaults)
            } catch (e: Exception) {
                null
            }
        }

        private fun parse(json: JSONObject, defaults: WidgetStyle) = WidgetStyle(
            background = color(json, "background", defaults.background),
            opacity = number(json, "opacity", defaults.opacity, 0f, 1f),
            textColor = color(json, "textColor", defaults.textColor),
            accent = color(json, "accent", defaults.accent) ?: defaults.accent,
            textSize = number(json, "textSize", defaults.textSize, 0.25f, 2f),
            casual = if (json.has("font")) json.optString("font") == "casual" else defaults.casual,
            showDone = json.optBoolean("showDone", defaults.showDone),
        )

        /** An ARGB colour the app wrote as a number, or null, for automatic. */
        private fun color(json: JSONObject, key: String, fallback: Int?): Int? = when {
            !json.has(key) -> fallback
            json.isNull(key) -> null
            else -> json.optLong(key).toInt()
        }

        private fun number(json: JSONObject, key: String, fallback: Float, min: Float, max: Float): Float {
            val value = json.optDouble(key)
            return if (value.isNaN()) fallback else value.toFloat().coerceIn(min, max)
        }

        /** The automatic text colour on [background] showing at [opacity]: see [ink]. */
        fun inkOn(background: Int?, opacity: Float): Int? {
            if (background == null || opacity < 0.5f) return null
            return if (isLight(background)) DARK_INK else LIGHT_INK
        }

        /**
         * Whether [color] is light enough for dark text, by the same measure
         * as Flutter's ThemeData.estimateBrightnessForColor: its relative
         * luminance in sRGB, as WCAG has it.
         */
        fun isLight(color: Int): Boolean {
            fun channel(shift: Int): Double {
                val value = ((color shr shift) and 0xFF) / 255.0
                return if (value <= 0.03928) value / 12.92 else ((value + 0.055) / 1.055).pow(2.4)
            }
            val luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
            return (luminance + 0.05) * (luminance + 0.05) > 0.15
        }

        /** [color] with its opacity times [factor]. */
        fun withAlpha(color: Int, factor: Float): Int =
            (((color ushr 24) * factor).roundToInt() shl 24) or (color and 0xFFFFFF)
    }
}
