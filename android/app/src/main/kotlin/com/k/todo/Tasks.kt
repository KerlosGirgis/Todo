package com.k.todo

import android.app.ActivityOptions
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.widget.RemoteViewsCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The to-do widget: the tasks still to do, or all of them, checked off or
 * not, in the to-do page's order, each subtask under its task, with how many
 * are left. Only how many are left while the App Lock is on. A tap opens the
 * app on its to-do page.
 *
 * It goes by what the app last gave it, worked out a week ahead, so it
 * draws itself again as each day begins, a daily task done yesterday being
 * to do again, and as a task becomes overdue.
 */
class Tasks : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        val style = WidgetStyle.read(prefs, STYLE_KEY, WidgetStyle.TASKS) ?: WidgetStyle.TASKS
        val snapshot = TasksSnapshot.read(prefs)
        val now = System.currentTimeMillis()
        for (id in ids) {
            manager.updateAppWidget(id, render(context, id, style, snapshot, now))
        }
        redrawLater(context, snapshot, style, now)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REDRAW) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, Tasks::class.java))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onDisabled(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(redrawIntent(context))
    }

    private fun render(
        context: Context,
        id: Int,
        style: WidgetStyle,
        snapshot: TasksSnapshot?,
        now: Long,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_tasks)
        style.paintBackground(views, android.R.id.background)

        views.setTextViewText(R.id.tasks_title, style.styled(context.getString(R.string.tasks_widget_title)))
        style.size(views, R.id.tasks_title, TITLE_SIZE)
        style.ink?.let { views.setTextColor(R.id.tasks_title, it) }
        if (snapshot == null) {
            // Nothing to count until the app has given it the tasks.
            views.setViewVisibility(R.id.tasks_count, View.GONE)
        } else {
            views.setViewVisibility(R.id.tasks_count, View.VISIBLE)
            views.setTextViewText(R.id.tasks_count, style.styled("${snapshot.leftOn(now)}"))
            style.size(views, R.id.tasks_count, COUNT_SIZE)
            views.setTextColor(R.id.tasks_count, style.accent)
        }

        val rows = if (snapshot == null || snapshot.locked) emptyList() else snapshot.rowsOn(now, style.showDone)
        val items = RemoteViewsCompat.RemoteCollectionItems.Builder().setViewTypeCount(2)
        rows.forEachIndexed { index, row -> items.addItem(index.toLong(), row(context, row, style)) }
        RemoteViewsCompat.setRemoteAdapter(context, views, id, R.id.tasks_list, items.build())

        val empty = when {
            snapshot == null -> R.string.tasks_widget_waiting
            snapshot.locked -> R.string.tasks_widget_locked
            snapshot.total == 0 -> R.string.tasks_widget_empty
            else -> R.string.tasks_widget_done
        }
        views.setEmptyView(R.id.tasks_list, R.id.tasks_empty)
        views.setTextViewText(R.id.tasks_empty, style.styled(context.getString(empty)))
        style.size(views, R.id.tasks_empty, EMPTY_SIZE)
        style.secondaryInk?.let { views.setTextColor(R.id.tasks_empty, it) }

        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, OPEN_URI)
        views.setOnClickPendingIntent(R.id.widget_root, open)
        views.setOnClickPendingIntent(R.id.tasks_empty, open)
        views.setPendingIntentTemplate(R.id.tasks_list, openTemplate(context))
        return views
    }

    private fun row(context: Context, row: TasksSnapshot.Row, style: WidgetStyle): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            if (row.done) R.layout.widget_task_row_done else R.layout.widget_task_row,
        )
        val density = context.resources.displayMetrics.density
        val padding = (ROW_PADDING * density).roundToInt()
        val indent = (INDENT * min(row.depth, MAX_INDENTS) * density).roundToInt()
        views.setViewPadding(R.id.task_row, indent, padding, 0, padding)

        views.setImageViewResource(
            R.id.task_check,
            if (row.done) R.drawable.widget_check_done else R.drawable.widget_check_open,
        )
        views.setInt(R.id.task_check, "setColorFilter", style.accent)

        views.setTextViewText(R.id.task_title, style.styled(row.title, struck = row.done))
        style.size(views, R.id.task_title, ROW_TITLE_SIZE)
        (if (row.done) style.secondaryInk else style.ink)?.let { views.setTextColor(R.id.task_title, it) }

        val details = row.details
        if (details == null) {
            views.setViewVisibility(R.id.task_details, View.GONE)
        } else {
            views.setViewVisibility(R.id.task_details, View.VISIBLE)
            views.setTextViewText(R.id.task_details, style.styled(details))
            style.size(views, R.id.task_details, DETAILS_SIZE)
            (if (row.late) RED else style.secondaryInk)?.let { views.setTextColor(R.id.task_details, it) }
        }

        views.setContentDescription(
            R.id.task_row,
            listOfNotNull(
                row.title,
                details,
                context.getString(if (row.done) R.string.tasks_widget_row_done else R.string.tasks_widget_row_to_do),
            ).joinToString(", "),
        )
        views.setOnClickFillInIntent(R.id.task_row, Intent())
        return views
    }

    /** Opens the app on its to-do page from a task's row. */
    private fun openTemplate(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
            .setData(OPEN_URI)
        // Mutable, as a template for its rows has to be.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return PendingIntent.getActivity(context, ROWS_REQUEST, intent, flags)
        }
        // As home_widget's own, which the launcher starts the app with.
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            )
        } else {
            @Suppress("DEPRECATION")
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(context, ROWS_REQUEST, intent, flags, options.toBundle())
    }

    /**
     * Has the widget draw itself again as the next day begins, or as the
     * next task listed becomes overdue, if that's sooner. Only once the
     * phone is awake, which is when the home screen can be seen.
     */
    private fun redrawLater(context: Context, snapshot: TasksSnapshot?, style: WidgetStyle, now: Long) {
        val zone = ZoneId.systemDefault()
        var next = LocalDate.now(zone).plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        if (snapshot != null && !snapshot.locked) {
            val day = snapshot.dayOf(now)
            for (task in snapshot.tasks) {
                val due = task.due ?: continue
                if (due in (now + 1)..<next && (style.showDone || !task.doneOn(day))) next = due
            }
        }
        context.getSystemService(AlarmManager::class.java)
            ?.set(AlarmManager.RTC, next + REDRAW_MARGIN, redrawIntent(context))
    }

    private fun redrawIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, Tasks::class.java).setAction(ACTION_REDRAW),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private companion object {
        const val STYLE_KEY = "tasksWidgetStyle"
        val OPEN_URI: Uri = Uri.parse("todo://tasks")
        const val ROWS_REQUEST = 1
        const val ACTION_REDRAW = "com.k.todo.action.REDRAW_TASKS"

        /** A second past the time, so the time has gone once it's drawn. */
        const val REDRAW_MARGIN = 1000L

        /** iOS's system red, which an overdue task's details turn. */
        const val RED = 0xFFFF3B30.toInt()

        // In sp and dp, as the layouts have them, and the settings' preview:
        // lib/view/screens/profile/profile_page/widgets/widget_previews.dart.
        const val TITLE_SIZE = 15f
        const val COUNT_SIZE = 22f
        const val EMPTY_SIZE = 14f
        const val ROW_TITLE_SIZE = 14f
        const val DETAILS_SIZE = 11.5f
        const val ROW_PADDING = 5f
        const val INDENT = 22f
        const val MAX_INDENTS = 3
    }
}
