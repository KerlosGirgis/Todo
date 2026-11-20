package com.k.todo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * The note widget: the text of the note the app put on it, bold in the
 * middle, or "Note" with none, styled as the app's settings have it. A tap
 * opens the app on its notes page.
 */
class Note : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val style = WidgetStyle.read(prefs, STYLE_KEY, WidgetStyle.NOTE) ?: legacyStyle(prefs)
        val note = prefs.getString("note", null) ?: context.getString(R.string.appwidget_text)
        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, OPEN_URI)
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.note)
            style.paintBackground(views, android.R.id.background)
            views.setTextViewText(R.id.note_text, style.styled(note))
            style.size(views, R.id.note_text, TEXT_SIZE)
            style.ink?.let { views.setTextColor(R.id.note_text, it) }
            views.setOnClickPendingIntent(R.id.widget_root, open)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /**
     * The style from before the widget had one of its own: its text sized
     * and in the font the notes' settings last set, kept until its style is
     * set.
     */
    private fun legacyStyle(prefs: SharedPreferences): WidgetStyle {
        val size = prefs.getString("widgetTextSize", null)?.toFloatOrNull() ?: 1f
        return WidgetStyle.NOTE.copy(
            textSize = size.coerceIn(0.25f, 2f),
            casual = prefs.getBoolean("useCasualFont", false),
        )
    }

    private companion object {
        const val STYLE_KEY = "noteWidgetStyle"
        val OPEN_URI: Uri = Uri.parse("todo://note")

        /** In sp, as the layout has it, and the settings' preview. */
        const val TEXT_SIZE = 22f
    }
}
