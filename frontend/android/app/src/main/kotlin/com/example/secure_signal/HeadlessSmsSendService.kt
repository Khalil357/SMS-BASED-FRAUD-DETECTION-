package com.example.secure_signal

import android.app.Service
import android.content.Intent
import android.os.IBinder

/** Minimal quick-reply endpoint required for the default SMS role. */
class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
