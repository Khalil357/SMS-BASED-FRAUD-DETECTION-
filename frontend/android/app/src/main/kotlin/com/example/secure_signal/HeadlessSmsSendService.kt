package com.example.secure_signal

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Minimal stub required by Android to qualify as a default SMS app candidate
 * (handles "quick reply" from notifications). Not used by this app's flow.
 */
class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf()
        return START_NOT_STICKY
    }
}
