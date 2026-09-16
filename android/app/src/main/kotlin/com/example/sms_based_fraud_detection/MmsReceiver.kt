package com.example.sms_based_fraud_detection

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File

class MmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.WAP_PUSH_DELIVER") return

        val pdu = intent.getByteArrayExtra("data") ?: return

        val from = extractFromAddress(pdu)
        if (from != null && BlockedNumbers.isBlocked(context, from)) {
            abortBroadcast()
            return
        }

        storePdu(context, pdu)
    }

    private fun extractFromAddress(pdu: ByteArray): String? {
        val candidate = findDigits(pdu)
        if (candidate == null || candidate.length < 7 || candidate.length > 16) return null
        return candidate
    }

    private fun findDigits(pdu: ByteArray): String? {
        var start = -1
        val sb = StringBuilder()
        val pduLength = pdu.size
        var i = 0
        while (i < pduLength) {
            val byte = pdu[i].toInt() and 0xff
            if (byte == 0x89) {
                start = i
            }
            if (start >= 0) {
                val isDigit = byte in 0x30..0x39
                val isPlus = byte == 0x2b
                if (isDigit) {
                    sb.append(byte - 0x30)
                } else if (isPlus && sb.isEmpty()) {
                    sb.append('+')
                } else if (sb.isNotEmpty() && !isDigit) {
                    val result = sb.toString()
                    if (result.length >= 7 && result.length <= 16) return result
                    sb.clear()
                }
            }
            i++
        }
        if (sb.isNotEmpty() && sb.length >= 7 && sb.length <= 16) {
            return sb.toString()
        }
        return null
    }

    private fun storePdu(context: Context, pdu: ByteArray) {
        try {
            val dir = File(context.cacheDir, "mms")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, "mms_${System.currentTimeMillis()}.pdu")
            file.writeBytes(pdu)

            val values = ContentValues().apply {
                put("ct_t", "application/vnd.wap.multipart.related")
                put("ct_l", "0")
                put("d_tm", System.currentTimeMillis())
                put("read", 0)
                put("seen", 0)
                put("m_type", 2)
                put("_data", file.absolutePath)
            }
            context.contentResolver.insert(Uri.parse("content://mms/inbox"), values)
        } catch (_: Exception) {
        }
    }
}