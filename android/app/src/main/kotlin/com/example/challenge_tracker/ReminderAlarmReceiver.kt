package com.example.challenge_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.example.challenge_tracker.FIRE_REMINDER") return

        val id = intent.getIntExtra("id", 0)
        ReminderAlarmScheduler.forget(context, id)
        val serviceIntent = Intent(context, RingingAlarmService::class.java)
            .putExtra("id", id)
            .putExtra("title", intent.getStringExtra("title"))
            .putExtra("body", intent.getStringExtra("body"))
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
