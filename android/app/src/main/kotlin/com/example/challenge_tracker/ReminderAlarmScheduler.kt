package com.example.challenge_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

internal object ReminderAlarmScheduler {
    private const val PREFS = "challenge_alarm_schedule"
    private const val SCHEDULES = "alarms"
    private const val ACTION_FIRE = "com.example.challenge_tracker.FIRE_REMINDER"

    fun schedule(
        context: Context,
        id: Int,
        atMillis: Long,
        title: String,
        body: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        challengeId: String?,
    ): Boolean {
        val record = JSONObject()
            .put("id", id)
            .put("atMillis", atMillis)
            .put("title", title)
            .put("body", body)
            .put("year", year)
            .put("month", month)
            .put("day", day)
            .put("hour", hour)
            .put("minute", minute)
            .put("challengeId", challengeId)
        saveRecord(context, record)
        return scheduleRecord(context, record)
    }

    fun cancelChallenge(context: Context, challengeId: String) {
        val schedules = readSchedules(context)
        val keys = schedules.keys()
        val toRemove = mutableListOf<String>()
        while (keys.hasNext()) {
            val key = keys.next()
            if (schedules.optJSONObject(key)?.optString("challengeId") == challengeId) {
                cancelPendingIntent(context, key.toInt())
                toRemove.add(key)
            }
        }
        toRemove.forEach(schedules::remove)
        saveSchedules(context, schedules)
    }

    fun cancel(context: Context, id: Int) {
        cancelPendingIntent(context, id)
        val schedules = readSchedules(context)
        schedules.remove(id.toString())
        saveSchedules(context, schedules)
    }

    fun forget(context: Context, id: Int) {
        val schedules = readSchedules(context)
        schedules.remove(id.toString())
        saveSchedules(context, schedules)
    }

    fun restore(context: Context) {
        val schedules = readSchedules(context)
        val records = mutableListOf<JSONObject>()
        val keys = schedules.keys()
        while (keys.hasNext()) {
            schedules.optJSONObject(keys.next())?.let(records::add)
        }
        records.forEach { record ->
            scheduleRecord(context, record)
        }
    }

    private fun scheduleRecord(context: Context, record: JSONObject): Boolean {
        val id = record.getInt("id")
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra("id", id)
            .putExtra("title", record.optString("title"))
            .putExtra("body", record.optString("body"))
        val alarmPendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.cancel(alarmPendingIntent)

        val atMillis = if (record.has("year")) {
            LocalDateTime.of(
                record.getInt("year"),
                record.getInt("month"),
                record.getInt("day"),
                record.getInt("hour"),
                record.getInt("minute"),
            ).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        } else {
            record.getLong("atMillis")
        }
        if (atMillis <= System.currentTimeMillis()) {
            forget(context, id)
            return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        }

        val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (exactAllowed) {
            val openAppIntent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val showIntent = PendingIntent.getActivity(
                context,
                id,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(atMillis, showIntent),
                alarmPendingIntent,
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                atMillis,
                alarmPendingIntent,
            )
        }
        return exactAllowed
    }

    private fun cancelPendingIntent(context: Context, id: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun saveRecord(context: Context, record: JSONObject) {
        val schedules = readSchedules(context)
        schedules.put(record.getInt("id").toString(), record)
        saveSchedules(context, schedules)
    }

    private fun readSchedules(context: Context): JSONObject = try {
        JSONObject(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(SCHEDULES, "{}"),
        )
    } catch (_: Exception) {
        JSONObject()
    }

    private fun saveSchedules(context: Context, schedules: JSONObject) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(SCHEDULES, schedules.toString())
            .apply()
    }
}
