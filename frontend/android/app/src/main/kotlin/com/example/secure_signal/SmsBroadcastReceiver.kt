package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager

/**
 * System entry point for received SMS messages.
 *
 * It does only the minimal, time-sensitive work required by a broadcast receiver:
 * extract the message and enqueue durable work. The worker can then finish even
 * when no Flutter activity or Dart isolate is running.
 */
class SmsBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ArgusSmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) {
            Log.w(TAG, "SMS_RECEIVED broadcast contained no messages")
            return
        }

        val sender = messages.first().originatingAddress ?: "Unknown"
        val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }
        if (body.isBlank()) {
            Log.w(TAG, "Ignoring empty SMS from $sender")
            return
        }
        if (!SmsScanWorker.isIngestionEnabled(context.applicationContext)) {
            Log.i(TAG, "SMS scan skipped because auto-ingestion is disabled")
            return
        }

        // The dashboard must show receipt of this SMS even if the model is
        // slow, unreachable, or Android defers the worker.
        val logId = SmsScanWorker.savePendingLog(context.applicationContext, sender, body)

        val pendingResult = goAsync()
        try {
            val input = Data.Builder()
                .putString(SmsScanWorker.KEY_SENDER, sender)
                .putString(SmsScanWorker.KEY_BODY, body)
                .putString(SmsScanWorker.KEY_LOG_ID, logId)
                .build()
            val request = OneTimeWorkRequestBuilder<SmsScanWorker>()
                .setInputData(input)
                // SMS threat checks are user-visible safety work. Start promptly
                // when quota allows, while retaining a normal-work fallback.
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueue(request)
            Log.i(TAG, "Queued SMS scan for $sender (${body.length} characters)")
        } catch (error: Exception) {
            Log.e(TAG, "Could not queue SMS scan", error)
        } finally {
            // Enqueuing is complete; the worker owns all further processing.
            pendingResult.finish()
        }
    }
}
