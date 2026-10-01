package com.example.challenge_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class RingingAlarmService : Service() {
    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            val challengeId = intent.getStringExtra("challengeId")
            val alarmId = intent.getIntExtra("alarmId", NOTIFICATION_ID)
            val title = intent.getStringExtra("title") ?: "حان وقت تحديك"
            val body = intent.getStringExtra("body") ?: "سجّل تقدمك في التحدي"
            stopRinging()
            if (!challengeId.isNullOrBlank()) {
                showProgressNotification(alarmId, challengeId, title, body)
            }
            return START_NOT_STICKY
        }

        val alarmId = intent?.getIntExtra("id", NOTIFICATION_ID) ?: NOTIFICATION_ID
        val challengeId = intent?.getStringExtra("challengeId")
        val title = intent?.getStringExtra("title") ?: "حان وقت تحديك"
        val body = intent?.getStringExtra("body") ?: "افتح التطبيق وسجّل تقدمك"
        startForeground(
            NOTIFICATION_ID,
            createRingingNotification(alarmId, challengeId, title, body),
        )
        startAlarmTone()
        return START_STICKY
    }

    private fun createRingingNotification(
        alarmId: Int,
        challengeId: String?,
        title: String,
        body: String,
    ): Notification {
        ensureChannel()
        val stopIntent = Intent(this, RingingAlarmService::class.java)
            .setAction(ACTION_STOP)
            .putExtra("alarmId", alarmId)
            .putExtra("challengeId", challengeId)
            .putExtra("title", title)
            .putExtra("body", body)
        val stopPendingIntent = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openIntent = Intent(this, MainActivity::class.java)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        if (!challengeId.isNullOrBlank()) {
            openIntent.putExtra(MainActivity.EXTRA_CHALLENGE_ID, challengeId)
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            alarmId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(openPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "إيقاف المنبه",
                stopPendingIntent,
            )
            .build()
    }

    private fun showProgressNotification(
        alarmId: Int,
        challengeId: String,
        title: String,
        body: String,
    ) {
        ensureFollowUpChannel()
        val openIntent = Intent(this, MainActivity::class.java)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            .putExtra(MainActivity.EXTRA_CHALLENGE_ID, challengeId)
        val openPendingIntent = PendingIntent.getActivity(
            this,
            alarmId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, FOLLOW_UP_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .build()
        getSystemService(NotificationManager::class.java).notify(alarmId, notification)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "منبهات التحديات التي ترن",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "منبه مستمر لتذكيرك بموعد التحدي"
            setSound(null, null)
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun ensureFollowUpChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(FOLLOW_UP_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            FOLLOW_UP_CHANNEL_ID,
            "تذكير بتسجيل التقدم",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "إشعار هادئ لفتح تسجيل التقدم في التحدي"
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun startAlarmTone() {
        if (player != null) return
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        player = MediaPlayer().apply {
            setAudioAttributes(attributes)
            isLooping = true
            setOnPreparedListener { mediaPlayer -> mediaPlayer.start() }
            setOnErrorListener { mediaPlayer, _, _ ->
                mediaPlayer.release()
                if (player === mediaPlayer) player = null
                true
            }
            try {
                setDataSource(this@RingingAlarmService, alarmUri)
                prepareAsync()
            } catch (_: Exception) {
                release()
                player = null
            }
        }
    }

    private fun stopRinging() {
        player?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: IllegalStateException) {
                // The player may not have finished preparing yet.
            }
            it.release()
        }
        player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "challenge_ringing_alarm_v1"
        private const val FOLLOW_UP_CHANNEL_ID = "challenge_progress_follow_up_v1"
        private const val NOTIFICATION_ID = 2147483644
        private const val STOP_REQUEST_CODE = 2147483643
        const val ACTION_STOP = "com.example.challenge_tracker.STOP_ALARM"
    }
}
