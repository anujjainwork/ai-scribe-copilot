package com.example.drlogger.upload

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

class BootReceiver : BroadcastReceiver() {
    @RequiresApi(Build.VERSION_CODES.O)
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Boot completed - starting UploadForegroundService")
            val svcIntent = Intent(context, UploadForegroundService::class.java)
            try {
                context.startForegroundService(svcIntent)
            } catch (e: Exception) {
                context.startService(svcIntent)
            }
        }
    }
}
