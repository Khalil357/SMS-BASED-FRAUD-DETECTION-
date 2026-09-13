package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Declares the MMS delivery endpoint required for the default SMS role. */
class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Unit
}
