package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** Declares the SMS delivery endpoint required for the default SMS role. */
class SmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
            // SMS_DELIVER reaches the selected default SMS app. The Flutter
            // telephony receiver continues to process SMS_RECEIVED broadcasts.
            // A production default-SMS experience must also persist messages and
            // provide an inbox/conversation UI.
        }
    }
}
