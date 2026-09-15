package com.example.sms_based_fraud_detection

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.Locale

/**
 * Native Android BroadcastReceiver to receive SMS broadcasts even when the app is completely quitted/closed.
 * Evaluates threat heuristics natively, saves logs to Flutter SharedPreferences, and displays system alert notifications.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "argus_threat_channel_v1"
        private const val CHANNEL_NAME = "Argus SMS Threat Alerts"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_INGESTION = "flutter.settings_ingestion_enabled"
        private const val KEY_NOTIFICATIONS = "flutter.settings_notifications_enabled"
        private const val KEY_THRESHOLD = "flutter.settings_notification_threshold"
        private const val KEY_LOGS = "flutter.sms_logs_v1"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage> = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val fullBodyBuilder = StringBuilder()
        var sender = "Unknown"

        for (msg in messages) {
            sender = msg.originatingAddress ?: sender
            fullBodyBuilder.append(msg.messageBody ?: "")
        }

        val body = fullBodyBuilder.toString().trim()
        if (body.isEmpty()) return

        // Read settings from Flutter SharedPreferences
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ingestionEnabled = prefs.getBoolean(KEY_INGESTION, true)
        if (!ingestionEnabled) return

        val notificationsEnabled = prefs.getBoolean(KEY_NOTIFICATIONS, true)
        val thresholdRaw = try {
            prefs.getFloat(KEY_THRESHOLD, 0.80f).toDouble()
        } catch (_: Exception) {
            0.80
        }

        // Native Kotlin Threat Analysis Heuristics
        val analysisResult = analyzeMessage(body, sender)
        val isFraud = analysisResult.classification == "Fraud"
        val threatLevel = analysisResult.threatLevel

        // Persist Log to SharedPreferences for Flutter UI
        saveLogToPrefs(prefs, sender, body, analysisResult)

        // Show High-Priority System Notification if Threat detected or Fraud
        if (notificationsEnabled && (isFraud || threatLevel >= thresholdRaw)) {
            showNotification(context, sender, body, threatLevel, isFraud)
        }
    }

    private data class ThreatAnalysis(
        val classification: String,
        val threatLevel: Double,
        val reasons: List<String>
    )

    private fun analyzeMessage(message: String, sender: String): ThreatAnalysis {
        val lower = message.lowercase(Locale.ROOT)
        val reasons = mutableListOf<String>()
        var score = 0.05

        // Check 1: Hyperlinks & Suspicious URLs
        val urlRegex = Regex("(https?://|www\\.|bit\\.ly|tinyurl|[a-zA-Z0-9-]+\\.(info|top|xyz|club|site|online|click|link))")
        if (urlRegex.containsMatchIn(lower)) {
            score += 0.45
            reasons.add("Contains external hyperlink or suspicious web link")
        }

        // Check 2: Financial & Phishing Scam Keywords
        val scamKeywords = listOf(
            "win", "winner", "voucher", "claim", "urgent", "suspend", "suspended",
            "verify", "verification", "account", "bank", "login", "prize", "poverty",
            "grant", "otp", "passcode", "refund", "reward", "blocked", "deactivated",
            "security alert", "action required", "congratulations", "unclaimed"
        )
        val matchedKeywords = scamKeywords.filter { lower.contains(it) }
        if (matchedKeywords.isNotEmpty()) {
            score += (matchedKeywords.size * 0.15).coerceAtMost(0.45)
            reasons.add("Contains urgent scam/phishing keywords (${matchedKeywords.take(3).joinToString(", ")})")
        }

        // Check 3: Shortcode / Suspicious Sender
        if (!sender.startsWith("+") && sender.matches(Regex("^[0-9]{4,6}$"))) {
            // Legitimate 5-digit shortcode
            score = (score - 0.10).coerceAtLeast(0.01)
        }

        val finalScore = score.coerceIn(0.01, 0.99)
        val classification = if (finalScore >= 0.50) "Fraud" else "Safe"
        if (reasons.isEmpty()) {
            reasons.add("No suspicious patterns matched")
        }

        return ThreatAnalysis(classification, finalScore, reasons)
    }

    private fun saveLogToPrefs(
        prefs: android.content.SharedPreferences,
        sender: String,
        message: String,
        analysis: ThreatAnalysis
    ) {
        try {
            val existingJsonStr = prefs.getString(KEY_LOGS, null)
            val jsonArray = if (existingJsonStr != null) JSONArray(existingJsonStr) else JSONArray()

            val newLog = JSONObject().apply {
                put("id", "auto_${System.currentTimeMillis()}")
                put("sender", sender)
                put("message", message)
                put("type", analysis.classification)
                put("time", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).format(Date()))
                put("threat", analysis.threatLevel)
                val reasonsArray = JSONArray()
                analysis.reasons.forEach { reasonsArray.put(it) }
                put("matchedReasons", reasonsArray)
                put("hasFeedback", false)
                put("userFeedback", JSONObject.NULL)
            }

            val updatedArray = JSONArray()
            updatedArray.put(newLog)
            for (i in 0 until jsonArray.length().coerceAtMost(199)) {
                updatedArray.put(jsonArray.get(i))
            }

            prefs.edit().putString(KEY_LOGS, updatedArray.toString()).apply()
        } catch (_: Exception) {}
    }

    private fun showNotification(
        context: Context,
        sender: String,
        message: String,
        threatLevel: Double,
        isFraud: Boolean
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Real-time incoming SMS threat and fraud alerts"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val threatPct = (threatLevel * 100).toInt()
        val title = if (isFraud) "🚨 Argus Threat Alert: $sender" else "🛡️ SMS Verified Safe: $sender"
        val alertText = if (isFraud) "Scam/Phishing attempt detected ($threatPct% Threat Index). Click to inspect details." else "Message verified ($threatPct% Threat Index)."

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(alertText)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$alertText\n\nSMS: \"$message\""))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        notificationManager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
    }
}
