package com.example.secure_signal

import android.app.Activity
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.BlockedNumberContract
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.secure_signal/sms_block"
        private const val REQUEST_DEFAULT_SMS_ROLE = 2001
    }

    private var pendingRoleResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> {
                    result.success(Telephony.Sms.getDefaultSmsPackage(this) == packageName)
                }

                "requestDefaultSmsRole" -> {
                    pendingRoleResult = result
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(RoleManager::class.java)
                        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                            if (roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                                pendingRoleResult?.success(true)
                                pendingRoleResult = null
                            } else {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                                startActivityForResult(intent, REQUEST_DEFAULT_SMS_ROLE)
                            }
                        } else {
                            pendingRoleResult?.success(false)
                            pendingRoleResult = null
                        }
                    } else {
                        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                        intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                        startActivityForResult(intent, REQUEST_DEFAULT_SMS_ROLE)
                    }
                }

                "blockNumber" -> {
                    val number = call.argument<String>("number")
                    if (number == null) {
                        result.error("ARG", "number required", null)
                        return@setMethodCallHandler
                    }
                    if (Telephony.Sms.getDefaultSmsPackage(this) != packageName) {
                        result.error("NOT_DEFAULT", "App is not the default SMS app", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val values = ContentValues()
                        values.put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
                        contentResolver.insert(BlockedNumberContract.BlockedNumbers.CONTENT_URI, values)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BLOCK_FAILED", e.message, null)
                    }
                }

                "unblockNumber" -> {
                    val number = call.argument<String>("number")
                    if (number == null) {
                        result.error("ARG", "number required", null)
                        return@setMethodCallHandler
                    }
                    if (Telephony.Sms.getDefaultSmsPackage(this) != packageName) {
                        result.error("NOT_DEFAULT", "App is not the default SMS app", null)
                        return@setMethodCallHandler
                    }
                    try {
                        contentResolver.delete(
                            BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                            "${BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER} = ?",
                            arrayOf(number)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNBLOCK_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DEFAULT_SMS_ROLE) {
            val granted = resultCode == Activity.RESULT_OK ||
                Telephony.Sms.getDefaultSmsPackage(this) == packageName
            pendingRoleResult?.success(granted)
            pendingRoleResult = null
        }
    }
}
