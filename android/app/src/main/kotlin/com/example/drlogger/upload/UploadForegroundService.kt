package com.example.drlogger.upload

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class UploadForegroundService : Service() {
    private val CHANNEL_ID = "drlogger_upload_channel"
    private val uploadManager by lazy { UploadManager.getInstance(applicationContext) }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(42, buildNotification("Uploading audio in background"))
        // resume pending uploads from DB
        uploadManager.resumePendingUploads()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Keep sticky so system restarts service if killed (we still depend on WorkManager as fallback)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("drlogger — Uploads")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Uploads", NotificationManager.IMPORTANCE_LOW))
        }
    }
}