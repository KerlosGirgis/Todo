package com.k.todo

import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.widget.TextView

/**
 * How the phone draws the app's widgets, for the app's settings to draw
 * their previews alike: the corners and colours the widgets' theme gives
 * them in light and dark mode, the wallpaper's colours, and how big the
 * widgets on the home screen are. lib/models/widget_look.dart reads it.
 */
object WidgetLook {
    fun describe(context: Context): Map<String, Any?> = mapOf(
        "radius" to radius(context),
        "light" to colors(context, night = false),
        "dark" to colors(context, night = true),
        "wallpaper" to wallpaper(context),
        "sizes" to mapOf(
            "Tasks" to sizeOf(context, Tasks::class.java),
            "Note" to sizeOf(context, Note::class.java),
        ),
    )

    /** [context] in the widgets' theme, in dark mode or not, as the launcher draws them. */
    private fun themed(context: Context, night: Boolean): Context {
        val config = Configuration(context.resources.configuration)
        config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        return ContextThemeWrapper(
            context.createConfigurationContext(config),
            R.style.Theme_Android_AppWidgetContainer,
        )
    }

    /** The radius of the widgets' corners, in dp. */
    private fun radius(context: Context): Float {
        val themed = themed(context, night = false)
        val attributes = themed.obtainStyledAttributes(intArrayOf(R.attr.appWidgetRadius))
        try {
            return attributes.getDimension(0, 0f) / context.resources.displayMetrics.density
        } finally {
            attributes.recycle()
        }
    }

    /**
     * The widgets' background, their text and secondary text on it, and the
     * note widget's text, which has the colour a TextView has without one
     * of its own.
     */
    private fun colors(context: Context, night: Boolean): Map<String, Int> {
        val themed = themed(context, night)
        val attributes = themed.obtainStyledAttributes(
            intArrayOf(
                android.R.attr.colorBackground,
                android.R.attr.textColorPrimary,
                android.R.attr.textColorSecondary,
            )
        )
        try {
            val note = LayoutInflater.from(themed).inflate(R.layout.note, null)
                .findViewById<TextView>(R.id.note_text)
            return mapOf(
                "background" to attributes.getColor(0, 0),
                "text" to (attributes.getColorStateList(1)?.defaultColor ?: 0),
                "secondary" to (attributes.getColorStateList(2)?.defaultColor ?: 0),
                "note" to note.currentTextColor,
            )
        } finally {
            attributes.recycle()
        }
    }

    /** The wallpaper's main colours, the most prominent first: none if the phone won't say. */
    private fun wallpaper(context: Context): List<Int> {
        val colors = try {
            WallpaperManager.getInstance(context).getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
        } catch (e: Exception) {
            null
        } ?: return emptyList()
        return listOfNotNull(colors.primaryColor, colors.secondaryColor, colors.tertiaryColor)
            .map { it.toArgb() }
    }

    /** How big the first of [provider]'s widgets is, in dp, with the phone held upright. */
    private fun sizeOf(context: Context, provider: Class<*>): List<Int>? {
        val manager = AppWidgetManager.getInstance(context)
        val id = manager.getAppWidgetIds(ComponentName(context, provider)).firstOrNull()
            ?: return null
        val options = manager.getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return if (width > 0 && height > 0) listOf(width, height) else null
    }
}
