package com.example.secure_signal

import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.BlockedNumberContract
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.secure_signal/sms_block"
        private const val REQUEST_DEFAULT_SMS = 100
    }

    private var pendingRoleResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultSmsApp" -> result.success(isDefaultSmsApp())
            "requestDefaultSmsRole" -> requestDefaultSmsRole(result)
            "blockNumber" -> updateSystemBlocklist(call, result, block = true)
            "unblockNumber" -> updateSystemBlocklist(call, result, block = false)
            else -> result.notImplemented()
        }
    }

    private fun isDefaultSmsApp(): Boolean =
        Telephony.Sms.getDefaultSmsPackage(this) == packageName

    private fun requestDefaultSmsRole(result: MethodChannel.Result) {
        if (pendingRoleResult != null) {
            result.error("ROLE_REQUEST_IN_PROGRESS", "A default SMS role request is already open.", null)
            return
        }
        pendingRoleResult = result
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (!roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                pendingRoleResult = null
                result.error("ROLE_UNAVAILABLE", "The SMS role is not available on this device.", null)
                return
            }
            roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
            Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            }
        }
        startActivityForResult(intent, REQUEST_DEFAULT_SMS)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DEFAULT_SMS) {
            pendingRoleResult?.success(isDefaultSmsApp())
            pendingRoleResult = null
        }
    }

    private fun updateSystemBlocklist(call: MethodCall, result: MethodChannel.Result, block: Boolean) {
        val number = call.argument<String>("number")?.trim()
        if (number.isNullOrEmpty()) {
            result.error("ARG", "A non-empty phone number is required.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.error("UNSUPPORTED", "System number blocking requires Android 7.0 or newer.", null)
            return
        }
        if (!isDefaultSmsApp()) {
            result.error("DEFAULT_SMS_REQUIRED", "Set Argus as the default SMS app to update Android's blocklist.", null)
            return
        }
        try {
            if (block) {
                val values = ContentValues().apply {
                    put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
                }
                result.success(contentResolver.insert(BlockedNumberContract.BlockedNumbers.CONTENT_URI, values) != null)
            } else {
                contentResolver.delete(
                    BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                    "${BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER} = ?",
                    arrayOf(number),
                )
                result.success(true)
            }
        } catch (exception: Exception) {
            result.error(
                if (block) "BLOCK_FAILED" else "UNBLOCK_FAILED",
                exception.message ?: "Android could not update the system blocklist.",
                null,
            )
        }
    }
}
