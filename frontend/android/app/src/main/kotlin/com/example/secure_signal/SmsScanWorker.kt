package com.example.secure_signal

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

/**
 * Background-safe SMS scanner. Results are stored in the same Android shared
 * preferences namespace used by Flutter's shared_preferences plugin, so they
 * appear in the dashboard the next time the app is opened.
 */
class SmsScanWorker(appContext: Context, parameters: WorkerParameters) :
    Worker(appContext, parameters) {

    companion object {
        private const val TAG = "ArgusSmsWorker"
        const val KEY_SENDER = "sender"
        const val KEY_BODY = "body"
        const val KEY_LOG_ID = "log_id"
        private const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
        private const val KEY_SMS_LOGS = "flutter.sms_logs_v1"
        private const val KEY_AUTH_TOKEN = "flutter.auth_token_v1"
        private const val KEY_REFRESH_TOKEN = "flutter.auth_refresh_token_v1"
        private const val KEY_INGESTION_ENABLED = "flutter.settings_ingestion_enabled"
        private const val KEY_NOTIFICATIONS_ENABLED = "flutter.settings_notifications_enabled"
        private const val KEY_NOTIFICATION_THRESHOLD = "flutter.settings_notification_threshold"
        private const val CHANNEL_ID = "secure_signal_threats"
        private const val CHANNEL_NAME = "Threat Alerts"
        // The app backend owns the model credential and proxies scans to the
        // ML service at https://13.53.200.176/predict. Never embed that API key
        // in a mobile APK.
        private const val SCAN_API_URL = "https://54.242.107.64/api/scans"
        private const val REFRESH_API_URL = "https://54.242.107.64/api/auth/refresh"

        fun isIngestionEnabled(context: Context): Boolean = context
            .getSharedPreferences(FLUTTER_PREFERENCES, Context.MODE_PRIVATE)
            .getBoolean(KEY_INGESTION_ENABLED, true)

        /** Persist immediately, before WorkManager or the network gets a turn. */
        fun savePendingLog(context: Context, sender: String, body: String): String {
            val logId = "auto_${UUID.randomUUID()}"
            val preferences = context.getSharedPreferences(FLUTTER_PREFERENCES, Context.MODE_PRIVATE)
            val logs = try {
                JSONArray(preferences.getString(KEY_SMS_LOGS, "[]"))
            } catch (_: Exception) {
                JSONArray()
            }
            val pending = JSONObject().apply {
                put("id", logId)
                put("sender", sender.ifBlank { "Unknown" })
                put("message", body)
                put("type", "Pending")
                put("isScam", false)
                put("scanStatus", "PENDING")
                put("time", Instant.now().toString())
                put("threat", 0.0)
                put("matchedReasons", JSONArray(listOf("Waiting for fraud-detection model")))
                put("hasFeedback", false)
                put("userFeedback", JSONObject.NULL)
                // The deployed API currently accepts the same source value as
                // a manual scan. The native log still retains its real source
                // (BACKGROUND_SMS_RECEIVER); this field is API compatibility.
                put("source", "MANUAL_QUERY")
            }
            val updated = JSONArray().put(pending)
            for (index in 0 until logs.length()) updated.put(logs.get(index))
            if (!preferences.edit().putString(KEY_SMS_LOGS, updated.toString()).commit()) {
                Log.e(TAG, "Could not save pending SMS scan")
            } else {
                Log.i(TAG, "Saved pending SMS scan $logId")
            }
            return logId
        }
    }

    override fun doWork(): Result {
        val sender = inputData.getString(KEY_SENDER).orEmpty()
        val body = inputData.getString(KEY_BODY).orEmpty()
        val logId = inputData.getString(KEY_LOG_ID)
        if (body.isBlank()) return Result.failure()

        val preferences = applicationContext.getSharedPreferences(
            FLUTTER_PREFERENCES,
            Context.MODE_PRIVATE,
        )
        if (!preferences.getBoolean(KEY_INGESTION_ENABLED, true)) {
            Log.i(TAG, "SMS scan skipped because auto-ingestion is disabled")
            return Result.success()
        }

        val analysis = try {
            scanWithModel(preferences, body, sender)
        } catch (error: ModelUnavailableException) {
            Log.w(TAG, "Fraud model is unavailable: ${error.message}")
            // Keep the received message visible instead of silently losing the
            // scan when the upstream model is temporarily unavailable.
            Analysis("Error", 0.0, listOf("Model scan failed: ${error.message}"))
        } catch (error: AuthenticationException) {
            Log.w(TAG, "SMS was not scanned because the login session is invalid: ${error.message}")
            Analysis("Error", 0.0, listOf("Sign in again to scan this SMS: ${error.message}"))
        } catch (error: Exception) {
            Log.e(TAG, "Unexpected model scan failure", error)
            Analysis("Error", 0.0, listOf("Unexpected scan error: ${error.message ?: "unknown error"}"))
        }
        val log = JSONObject().apply {
            put("id", logId ?: savePendingLog(applicationContext, sender, body))
            put("sender", sender.ifBlank { "Unknown" })
            put("message", body)
            put("type", analysis.classification)
            put("isScam", analysis.classification == "Fraud")
            put("scanStatus", if (analysis.classification == "Error") "FAILED" else "COMPLETED")
            put("time", Instant.now().toString())
            put("threat", analysis.threatLevel)
            put("matchedReasons", JSONArray(analysis.reasons))
            put("hasFeedback", false)
            put("userFeedback", JSONObject.NULL)
            put("source", "BACKGROUND_SMS_RECEIVER")
        }

        val logs = try {
            JSONArray(preferences.getString(KEY_SMS_LOGS, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val updatedLogs = JSONArray().put(log)
        for (index in 0 until logs.length()) {
            if (logs.getJSONObject(index).optString("id") != log.getString("id")) {
                updatedLogs.put(logs.get(index))
            }
        }

        val saved = preferences.edit().putString(KEY_SMS_LOGS, updatedLogs.toString()).commit()
        if (saved) {
            Log.i(TAG, "Saved SMS scan; ${updatedLogs.length()} log entries are now stored")
        } else {
            Log.e(TAG, "Could not save SMS scan to local storage")
        }
        if (saved && shouldNotify(preferences, analysis)) {
            showThreatNotification(sender, body, analysis.threatLevel)
        }

        return if (saved) {
            Result.success()
        } else {
            Result.retry()
        }
    }

    private fun shouldNotify(preferences: android.content.SharedPreferences, analysis: Analysis): Boolean {
        if (analysis.classification != "Fraud") return false
        if (!preferences.getBoolean(KEY_NOTIFICATIONS_ENABLED, true)) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false

        val threshold = preferences.all[KEY_NOTIFICATION_THRESHOLD]
            ?.let { value -> (value as? Number)?.toDouble() }
            ?.coerceIn(0.50, 1.00)
            ?: 0.50
        return analysis.threatLevel >= threshold
    }

    private fun showThreatNotification(sender: String, body: String, threatLevel: Double) {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Alerts for high-risk phishing or scam SMS messages."
                },
            )
        }

        val launchIntent = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
            ?: Intent(applicationContext, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val percentage = (threatLevel * 100).toInt()
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(com.example.secure_signal.R.mipmap.ic_launcher)
            .setContentTitle("High-threat SMS intercepted")
            .setContentText("$sender • $percentage% threat")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Sender: $sender\nThreat index: $percentage%\n\n$body"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        manager.notify(UUID.randomUUID().hashCode(), notification)
    }

    /** Calls the authenticated backend, which is the single gateway to the ML model. */
    private fun scanWithModel(
        preferences: android.content.SharedPreferences,
        body: String,
        sender: String,
        allowRefresh: Boolean = true,
    ): Analysis {
        val token = preferences.getString(KEY_AUTH_TOKEN, null)?.trim()
        if (token.isNullOrBlank() || token == "auth_session_active") {
            throw AuthenticationException("No valid saved login token")
        }

        val connection = (URL(SCAN_API_URL).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 5_000
            readTimeout = 12_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", if (token.startsWith("Bearer ")) token else "Bearer $token")
        }
        try {
            val payload = JSONObject().apply {
                put("sender", sender)
                // Keep this payload identical to the working Flutter manual
                // scan. Some deployed backend versions accept snake_case,
                // while newer ones bind the camelCase field.
                put("messageBody", body)
                put("message_body", body)
                put("message", body)
                put("source", "BACKGROUND_SMS_RECEIVER")
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { it.write(payload.toString()) }
            val status = connection.responseCode
            if (status == HttpURLConnection.HTTP_UNAUTHORIZED || status == HttpURLConnection.HTTP_FORBIDDEN) {
                if (allowRefresh && refreshAccessToken(preferences)) {
                    return scanWithModel(preferences, body, sender, allowRefresh = false)
                }
                throw AuthenticationException("Backend returned HTTP $status")
            }
            if (status !in 200..299) {
                val errorBody = try {
                    connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                } catch (_: Exception) {
                    ""
                }
                Log.w(TAG, "Backend/model returned HTTP $status: $errorBody")
                throw ModelUnavailableException(
                    "Backend/model returned HTTP $status" +
                        if (errorBody.isBlank()) "" else ": $errorBody",
                )
            }
            val text = BufferedReader(connection.inputStream.reader()).use { it.readText() }
            val responseJson = JSONObject(text)
            val data = responseJson.optJSONObject("data")
            // Older deployed API versions intentionally return data: null when
            // the model clears an SMS. That is a valid Safe verdict, not a
            // transport or model failure.
            if (data == null) {
                val serverMessage = responseJson.optString("message")
                // A 2xx response means the backend completed the model call.
                // Legacy deployments omit the data object for a non-fraud
                // result, so use that response as the Safe verdict instead
                // of falsely showing a Scan Error.
                Log.i(TAG, "Model returned a Safe verdict without details: $serverMessage")
                return Analysis(
                    "Safe",
                    0.0,
                    listOf(
                        "Fraud-detection model cleared this SMS",
                        if (serverMessage.isBlank())
                            "No fraud indicators were returned by the model"
                        else serverMessage,
                    ),
                )
            }
            val label = data.optString("label").lowercase().trim()
            val isScam = data.optBoolean("isScam", data.optBoolean("is_scam", false)) ||
                label in setOf("fraud", "scam", "phishing", "spam")
            // Safe responses from the deployed model often omit confidence.
            // Use a conservative zero threat level in that case, rather than
            // turning a valid Safe result into a Scan Error.
            val confidence = data.optDouble(
                "confidence",
                data.optDouble("probability", data.optDouble("score", Double.NaN)),
            ).let { value ->
                if (value.isNaN()) {
                    if (isScam) 0.95 else 1.0
                } else value
            }
            val threat = if (isScam) confidence else 1.0 - confidence
            return Analysis(
                if (isScam) "Fraud" else "Safe",
                threat.coerceIn(0.0, 1.0),
                listOf(
                    if (isScam) "Flagged by the fraud-detection model"
                    else "Cleared by the fraud-detection model",
                    if (label.isBlank()) "Model returned no confidence score" else "Model label: $label",
                ),
            )
        } finally {
            connection.disconnect()
        }
    }

    /** Refreshes an expired access token for unattended background scans. */
    private fun refreshAccessToken(preferences: android.content.SharedPreferences): Boolean {
        val savedRefresh = preferences.getString(KEY_REFRESH_TOKEN, null)?.trim()
        if (savedRefresh.isNullOrBlank()) return false
        val connection = (URL(REFRESH_API_URL).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 5_000
            readTimeout = 12_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }
        return try {
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use {
                it.write(JSONObject().put("refreshToken", savedRefresh).toString())
            }
            if (connection.responseCode !in 200..299) return false
            val data = JSONObject(BufferedReader(connection.inputStream.reader()).use { it.readText() })
                .optJSONObject("data") ?: return false
            val nextAccess = data.optString("token").trim()
            if (nextAccess.split('.').size != 3) return false
            val nextRefresh = data.optString("refreshToken", savedRefresh).trim()
            preferences.edit()
                .putString(KEY_AUTH_TOKEN, nextAccess)
                .putString(KEY_REFRESH_TOKEN, nextRefresh)
                .commit()
        } catch (error: Exception) {
            Log.w(TAG, "Background token refresh failed", error)
            false
        } finally {
            connection.disconnect()
        }
    }

    private data class Analysis(
        val classification: String,
        val threatLevel: Double,
        val reasons: List<String>,
    )

    private class ModelUnavailableException(message: String) : Exception(message)
    private class AuthenticationException(message: String) : Exception(message)

}
