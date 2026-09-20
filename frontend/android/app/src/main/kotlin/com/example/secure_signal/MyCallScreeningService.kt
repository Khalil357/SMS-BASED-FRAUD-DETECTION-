package com.example.secure_signal

import android.content.Context
import android.content.SharedPreferences
import android.telecom.Call
import android.telecom.CallScreeningService
import org.json.JSONArray

class MyCallScreeningService : CallScreeningService() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val BLOCKLIST_KEY = "flutter.blocked_numbers_v1"
    }

    override fun onScreenCall(callDetails: Call.Details) {

        val handle = callDetails.handle

        if (handle == null) {
            allowCall(callDetails)
            return
        }

        val phoneNumber = handle.schemeSpecificPart

        println("ARGUS CALL SCREENING: Incoming call from $phoneNumber")

        val isBlocked = isNumberBlocked(phoneNumber)

        if (isBlocked) {
            println("ARGUS CALL SCREENING: BLOCKED $phoneNumber")

            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(true)
                .setSkipNotification(true)
                .build()

            respondToCall(callDetails, response)
        } else {
            println("ARGUS CALL SCREENING: ALLOWED $phoneNumber")

            allowCall(callDetails)
        }
    }

    private fun allowCall(callDetails: Call.Details) {
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .build()

        respondToCall(callDetails, response)
    }

    private fun isNumberBlocked(phoneNumber: String): Boolean {

        val normalizedPhoneNumber = normalizeNumber(phoneNumber)

        val prefs: SharedPreferences = getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val jsonString = prefs.getString(BLOCKLIST_KEY, null)
            ?: return false

        return try {
            val blockedNumbers = JSONArray(jsonString)

            for (i in 0 until blockedNumbers.length()) {
                val item = blockedNumbers.optJSONObject(i) ?: continue

                val blockedNumber = item.optString("number", "")

                if (normalizeNumber(blockedNumber) == normalizedPhoneNumber) {
                    return true
                }
            }

            false
        } catch (e: Exception) {
            println(
                "ARGUS CALL SCREENING: Failed to read blocklist: ${e.message}"
            )
            false
        }
    }

    private fun normalizeNumber(number: String): String {
        return number.replace(Regex("[\\s\\-()]"), "")
    }
}
