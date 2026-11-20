package com.k.todo

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * The tasks as the app last gave them to the to-do widget, as
 * lib/models/tasks_widget_snapshot.dart writes them: each with how it
 * stands on each of the week's days from [from], as the widget can't work
 * out when a repeating task comes round again, and how many are left on
 * each. Without the tasks while the App Lock is on. [rowsOn] lists them as
 * the app's settings preview them: change both together.
 */
class TasksSnapshot(
    private val from: LocalDate,
    val locked: Boolean,
    private val left: IntArray,
    val total: Int,
    val tasks: List<Task>,
) {
    class Task(
        val title: String,
        /** Where the task it's in is among the tasks, or -1 for a task of its own. */
        val parent: Int,
        /** The days it's done on, a bit each, the first day the lowest. */
        private val done: Int,
        /** The days a repeating task is overdue on. */
        private val late: Int,
        /** When a task that doesn't repeat is due, in milliseconds since 1970. */
        val due: Long?,
        private val whenLabels: List<String?>,
        val repeat: String?,
    ) {
        fun doneOn(day: Int) = done and (1 shl day) != 0

        fun isLateAt(now: Long, day: Int) =
            if (due != null) now > due else late and (1 shl day) != 0

        fun whenOn(day: Int) = whenLabels.getOrNull(day)
    }

    /** A task as the widget lists it. */
    class Row(
        val title: String,
        /** How many of the tasks it's in are listed above it. */
        val depth: Int,
        val done: Boolean,
        val late: Boolean,
        whenLabel: String?,
        repeat: String?,
    ) {
        /** When it's for, and how it repeats. */
        val details: String? = listOfNotNull(whenLabel, repeat).joinToString(" · ").ifEmpty { null }
    }

    /** Which of the days [now] is on: the last once they've all gone, and the first before. */
    fun dayOf(now: Long): Int {
        val today = Instant.ofEpochMilli(now).atZone(ZoneId.systemDefault()).toLocalDate()
        return ChronoUnit.DAYS.between(from, today).coerceIn(0, DAYS - 1L).toInt()
    }

    /** How many tasks are left at [now]. */
    fun leftOn(now: Long) = left.getOrElse(dayOf(now)) { 0 }

    /**
     * The rows to list at [now]: the tasks, the ones that are done only if
     * [showDone], each as deep in as the tasks it's in that are listed.
     */
    fun rowsOn(now: Long, showDone: Boolean): List<Row> {
        val day = dayOf(now)
        val shown = BooleanArray(tasks.size) { showDone || !tasks[it].doneOn(day) }
        val depths = IntArray(tasks.size)
        val rows = mutableListOf<Row>()
        tasks.forEachIndexed { index, task ->
            // The tasks it's in come before it.
            val parent = task.parent
            depths[index] = if (parent in 0 until index) {
                depths[parent] + if (shown[parent]) 1 else 0
            } else 0
            if (!shown[index]) return@forEachIndexed
            val done = task.doneOn(day)
            rows += Row(
                title = task.title,
                depth = depths[index],
                done = done,
                late = !done && task.isLateAt(now, day),
                whenLabel = task.whenOn(day),
                repeat = task.repeat,
            )
        }
        return rows
    }

    companion object {
        /** How many days the app works the tasks out for. */
        const val DAYS = 7

        /** The tasks the app last gave the widget, or null for none yet. */
        fun read(prefs: SharedPreferences): TasksSnapshot? {
            val saved = prefs.getString("tasks", null) ?: return null
            return try {
                parse(JSONObject(saved))
            } catch (e: Exception) {
                null
            }
        }

        private fun parse(json: JSONObject): TasksSnapshot {
            val left = json.optJSONArray("left") ?: JSONArray()
            val tasks = json.optJSONArray("tasks") ?: JSONArray()
            return TasksSnapshot(
                from = LocalDate.parse(json.getString("from")),
                locked = json.optBoolean("locked"),
                left = IntArray(left.length()) { left.optInt(it) },
                total = json.optInt("total"),
                tasks = List(tasks.length()) { task(tasks.getJSONObject(it)) },
            )
        }

        private fun task(json: JSONObject): Task {
            val labels = when (val labels = json.opt("when")) {
                is JSONArray -> List(labels.length()) { if (labels.isNull(it)) null else labels.optString(it) }
                is String -> List(DAYS) { labels }
                else -> List(DAYS) { null }
            }
            return Task(
                title = json.optString("title"),
                parent = json.optInt("parent", -1),
                done = json.optInt("done"),
                late = json.optInt("late"),
                due = if (json.isNull("due")) null else json.optLong("due"),
                whenLabels = labels,
                repeat = if (json.isNull("repeat")) null else json.optString("repeat"),
            )
        }
    }
}
