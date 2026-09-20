package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Minimal stub required by Android to qualify as a default SMS app candidate.
 * Full MMS handling is out of scope for the block/unblock feature.
 */
class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {}
}
