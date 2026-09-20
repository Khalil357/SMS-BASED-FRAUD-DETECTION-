package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Required for this app to be selectable as the device's default SMS app.
 * Once granted, incoming texts are delivered here first. Existing detection
 * (via the `telephony` Flutter plugin's SMS_RECEIVED listener) keeps working
 * as before when the app is NOT the default SMS app. When it IS the default,
 * Android stops sending SMS_RECEIVED and sends SMS_DELIVER instead — this
 * receiver exists so no messages are silently dropped once that happens.
 */
class SmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
            // Messages from blocked numbers are already filtered by the OS
            // before reaching here (BlockedNumberContract), so anything that
            // arrives in this receiver has already passed the block check.
            // TODO: forward to the same storage/detection pipeline used by
            // sms_ingestion_service.dart once default-SMS-app mode is enabled.
        }
    }
}
