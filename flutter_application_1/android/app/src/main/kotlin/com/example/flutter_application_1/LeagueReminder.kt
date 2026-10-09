package com.example.flutter_application_1

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object LeagueReminder {
    private const val PREFS = "league_reminder"
    private const val CHANNEL = "daily_league"
    private const val REQUEST = 3101
    private const val HOUR = 3_600_000L

    fun permitted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 &&
            manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE)
            return false
        return true
    }

    fun update(context: Context, deadline: Long, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("deadline", deadline).putBoolean("enabled", enabled).apply()
        restore(context)
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val deadline = prefs.getLong("deadline", 0L)
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, LeagueReminderReceiver::class.java)
            .putExtra("deadline", deadline)
        val pending = PendingIntent.getBroadcast(context, REQUEST, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(pending)
        if (!prefs.getBoolean("enabled", false) || deadline <= System.currentTimeMillis()) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(REQUEST)
            return
        }
        if (prefs.getLong("notifiedDeadline", 0L) == deadline) return
        val trigger = maxOf(System.currentTimeMillis() + 1_000L, deadline - HOUR)
        // Offline reminder, including idle devices; no exact-alarm permission is needed.
        if (Build.VERSION.SDK_INT >= 23) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending)
        } else {
            alarm.set(AlarmManager.RTC_WAKEUP, trigger, pending)
        }
    }

    fun notify(context: Context, expectedDeadline: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val deadline = prefs.getLong("deadline", 0L)
        if (!prefs.getBoolean("enabled", false) || deadline != expectedDeadline ||
            deadline <= System.currentTimeMillis() ||
            prefs.getLong("notifiedDeadline", 0L) == deadline || !permitted(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL,
                "Günlük Lig hatırlatıcısı", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Günlük lig süresinin son bir saatinde hatırlatır."
            })
        }
        val open = PendingIntent.getActivity(context, REQUEST,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else Notification.Builder(context)
        val notification = builder
            .setSmallIcon(R.drawable.ic_league_notification)
            .setContentTitle("Günlük Lig · Son 1 saat!")
            .setContentText("20 elini tamamla, sıralamanı kesinleştir ve günlük ödülünü kazan.")
            .setContentIntent(open).setAutoCancel(true).build()
        try {
            manager.notify(REQUEST, notification)
            prefs.edit().putLong("notifiedDeadline", deadline).apply()
        } catch (_: SecurityException) {
            // The permission may have been revoked between check and delivery.
        }
    }
}

class LeagueReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LeagueReminder.notify(context, intent.getLongExtra("deadline", 0L))
    }
}

class LeagueBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LeagueReminder.restore(context)
    }
}
