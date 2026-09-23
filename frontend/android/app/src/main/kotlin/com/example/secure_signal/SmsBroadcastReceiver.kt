package com.example.secure_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import android.provider.Telephony
import android.util.Log
import androidx.core.content.ContextCompat
import android.net.Uri
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
        private val TRUSTED_SERVICE_SENDERS = listOf(
            "mpesa", "m-pesa", "mixx", "mixx by yas", "yas", "tigopesa",
            "tigo pesa", "airtel money", "airtelmoney", "halopesa", "halotel",
            "vodacom", "zantel", "ttcl", "tanzania telecom",
        )
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
        if (isTrustedServiceSender(sender)) {
            Log.i(TAG, "SMS scan skipped for trusted service sender: $sender")
            return
        }
        if (!canReadContacts(context)) {
            Log.w(TAG, "SMS scan skipped because Contacts permission is not granted")
            return
        }
        if (isSavedContact(context, sender)) {
            Log.i(TAG, "SMS scan skipped for saved contact: $sender")
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

    private fun isTrustedServiceSender(sender: String): Boolean {
        val normalized = sender.lowercase().replace(Regex("[^a-z0-9]"), "")
        return TRUSTED_SERVICE_SENDERS.any { provider ->
            normalized.contains(provider.replace(Regex("[^a-z0-9]"), ""))
        }
    }

    private fun canReadContacts(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    /** PhoneLookup handles number formatting and country-code differences. */
    private fun isSavedContact(context: Context, sender: String): Boolean {
        if (sender.isBlank()) return false
        return try {
            val lookupUri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(sender),
            )
            context.contentResolver.query(
                lookupUri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null,
                null,
                null,
            )?.use { it.moveToFirst() } ?: false
        } catch (error: SecurityException) {
            Log.w(TAG, "Could not read contacts", error)
            false
        }
    }
}
