package com.k.todo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import android.util.TypedValue
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Implementation of App Widget functionality.
 */


class Note : AppWidgetProvider() {
    /*
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }*/

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs: SharedPreferences =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val useCasualFont: Boolean = prefs.getBoolean("useCasualFont", false)
        var  textSize=22f
        val textSizeString = prefs.getString("widgetTextSize", "1")
        if(textSizeString!=null){
            val tempTextSize = textSizeString.toFloatOrNull()
            if(tempTextSize!=null){
                textSize=tempTextSize*22
            }
        }
        Log.d("WidgetDebug", "Text Size: $textSize")
        // There may be multiple widgets active, so update all of them
        val widgetData = HomeWidgetPlugin.getData(context)
        val note = widgetData.getString("note", "Note")
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.note)

            if (useCasualFont) {
                views.setTextViewText(R.id.noteTextC, note)
                views.setViewVisibility(R.id.noteTextA, android.view.View.GONE)
                views.setViewVisibility(R.id.noteTextC, android.view.View.VISIBLE)
            } else {
                views.setTextViewText(R.id.noteTextA, note)
                views.setViewVisibility(R.id.noteTextA, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.noteTextC, android.view.View.GONE)
            }
            views.setTextViewTextSize(R.id.noteTextA, TypedValue.COMPLEX_UNIT_SP, textSize)
            views.setTextViewTextSize(R.id.noteTextC, TypedValue.COMPLEX_UNIT_SP, textSize)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }
}
/*
internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val widgetText = context.getString(R.string.appwidget_text)
    // Construct the RemoteViews object
    val views = RemoteViews(context.packageName, R.layout.note)
    views.setTextViewText(R.id.noteText, widgetText)

    // Instruct the widget manager to update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
}*/