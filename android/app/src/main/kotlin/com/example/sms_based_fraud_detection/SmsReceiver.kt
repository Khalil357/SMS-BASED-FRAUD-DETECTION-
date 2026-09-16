package com.example.sms_based_fraud_detection

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return

        val sender = messages.first().originatingAddress?.trim()
        if (sender.isNullOrEmpty()) return

        if (BlockedNumbers.isBlocked(context, sender)) {
            abortBroadcast()
            return
        }

        storeToInbox(context, messages)
    }

    private fun storeToInbox(context: Context, messages: Array<SmsMessage>) {
        val sender = messages.first().originatingAddress?.trim() ?: return
        val body = messages.joinToString("") { it.messageBody ?: "" }
        if (body.isEmpty()) return

        val timestamp = messages.first().timestampMillis
            .takeIf { it > 0 } ?: System.currentTimeMillis()

        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, sender)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, timestamp)
            put(Telephony.Sms.DATE_SENT, timestamp)
            put(Telephony.Sms.READ, 0)
            put(Telephony.Sms.SEEN, 0)
        }

        try {
            context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
        } catch (_: Exception) {
        }
    }
}