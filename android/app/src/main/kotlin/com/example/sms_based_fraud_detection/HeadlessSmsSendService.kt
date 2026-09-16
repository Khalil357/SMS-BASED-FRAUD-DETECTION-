package com.example.sms_based_fraud_detection

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.provider.Telephony
import android.telephony.SmsManager

class HeadlessSmsSendService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val message = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
            val destination = resolveAddress(intent)
            if (destination.isNotEmpty() && message.isNotEmpty()) {
                try {
                    sendMessage(destination, message, intent)
                } catch (_: Exception) {
                }
            }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun resolveAddress(intent: Intent): String {
        val uri = intent.data ?: return ""
        return when (uri.scheme) {
            "sms", "smsto", "mms", "mmsto" -> uri.schemeSpecificPart?.trim() ?: ""
            "content" -> queryAddress(intent)
            else -> uri.schemeSpecificPart?.trim() ?: ""
        }
    }

    private fun queryAddress(intent: Intent): String {
        return try {
            val uri = intent.data ?: return ""
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                val idx = it.getColumnIndex(Telephony.Sms.ADDRESS)
                if (idx >= 0 && it.moveToFirst()) it.getString(idx) ?: "" else ""
            } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun sendMessage(destination: String, message: String, intent: Intent) {
        val subId = intent.getIntExtra(
            EXTRA_SUBSCRIPTION_INDEX,
            SmsManager.getDefaultSmsSubscriptionId()
        )
        val manager = if (subId >= 0) {
            SmsManager.getSmsManagerForSubscriptionId(subId)
        } else {
            SmsManager.getDefault()
        }
        val parts = manager.divideMessage(message)
        if (parts.size > 1) {
            manager.sendMultipartTextMessage(destination, null, parts, null, null)
        } else {
            manager.sendTextMessage(destination, null, message, null, null)
        }
    }

    private companion object {
        const val EXTRA_SUBSCRIPTION_INDEX = "android.telephony.extra.SUBSCRIPTION_INDEX"
    }
}