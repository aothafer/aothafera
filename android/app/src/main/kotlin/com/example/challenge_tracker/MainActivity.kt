package com.example.challenge_tracker

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.challenge_tracker/notification_settings"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getPendingChallengeId" -> {
                        result.success(intent?.getStringExtra(EXTRA_CHALLENGE_ID))
                        intent?.removeExtra(EXTRA_CHALLENGE_ID)
                    }
                    "scheduleAlarm" -> {
                        val exact = ReminderAlarmScheduler.schedule(
                            context = this,
                            id = call.argument<Int>("id") ?: error("Missing alarm id"),
                            atMillis = call.argument<Long>("atMillis") ?: error("Missing alarm time"),
                            title = call.argument<String>("title") ?: "حان وقت تحديك",
                            body = call.argument<String>("body") ?: "افتح التطبيق وسجّل تقدمك",
                            year = call.argument<Int>("year") ?: error("Missing alarm year"),
                            month = call.argument<Int>("month") ?: error("Missing alarm month"),
                            day = call.argument<Int>("day") ?: error("Missing alarm day"),
                            hour = call.argument<Int>("hour") ?: error("Missing alarm hour"),
                            minute = call.argument<Int>("minute") ?: error("Missing alarm minute"),
                            challengeId = call.argument<String>("challengeId"),
                        )
                        result.success(exact)
                    }
                    "cancelChallengeAlarms" -> {
                        val challengeId = call.argument<String>("challengeId")
                            ?: error("Missing challenge id")
                        ReminderAlarmScheduler.cancelChallenge(this, challengeId)
                        result.success(null)
                    }
                    "restoreAlarms" -> {
                        ReminderAlarmScheduler.restore(this)
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(null)
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("SETTINGS_FAILED", error.message, null)
            }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(EXTRA_CHALLENGE_ID)?.let { challengeId ->
            notificationChannel?.invokeMethod("openChallengeProgress", challengeId)
            intent.removeExtra(EXTRA_CHALLENGE_ID)
        }
    }

    companion object {
        const val EXTRA_CHALLENGE_ID = "open_challenge_id"
    }
}
