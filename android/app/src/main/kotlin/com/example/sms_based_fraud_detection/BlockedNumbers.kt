package com.example.sms_based_fraud_detection

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.provider.BlockedNumberContract
import android.telephony.PhoneNumberUtils

object BlockedNumbers {
    fun normalize(number: String): String {
        val digits = PhoneNumberUtils.stripSeparators(number)
        return if (digits.startsWith("+")) digits else "+$digits"
    }

    fun isBlocked(context: Context, number: String): Boolean {
        return try {
            BlockedNumberContract.isBlocked(context, number)
        } catch (_: Exception) {
            false
        }
    }

    fun canModify(context: Context): Boolean {
        val defaultSmsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(context)
        return defaultSmsPackage == context.packageName
    }

    fun block(context: Context, number: String): Boolean {
        return try {
            if (!canModify(context)) return false
            val values = ContentValues().apply {
                put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, normalize(number))
            }
            context.contentResolver.insert(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                values
            ) != null
        } catch (_: Exception) {
            false
        }
    }

    fun unblock(context: Context, number: String): Boolean {
        return try {
            if (!canModify(context)) return false
            val deleted = context.contentResolver.delete(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                "${BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER} = ?",
                arrayOf(normalize(number))
            )
            deleted > 0
        } catch (_: Exception) {
            false
        }
    }

    fun getAll(context: Context): List<String> {
        val numbers = mutableListOf<String>()
        val projection = arrayOf(
            BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER,
            BlockedNumberContract.BlockedNumbers.COLUMN_E164_NUMBER
        )
        val cursor: Cursor? = try {
            context.contentResolver.query(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                projection,
                null,
                null,
                null
            )
        } catch (_: Exception) {
            null
        }
        cursor?.use {
            val colIndex = it.getColumnIndex(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER)
            while (it.moveToNext()) {
                val value = if (colIndex >= 0) it.getString(colIndex) else null
                if (!value.isNullOrBlank() && !numbers.contains(normalize(value))) {
                    numbers.add(normalize(value))
                }
            }
        }
        return numbers
    }
}