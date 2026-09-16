package com.example.sms_based_fraud_detection

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val BLOCKLIST_CHANNEL = "com.yourapp.fraud_detector/blocklist"
        const val SMS_ROLE_CHANNEL = "com.yourapp.fraud_detector/sms_role"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKLIST_CHANNEL)
            .setMethodCallHandler(::handleBlocklistCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_ROLE_CHANNEL)
            .setMethodCallHandler(::handleSmsRoleCall)
    }

    private fun handleBlocklistCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "blockNumber" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                if (phoneNumber.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Phone number is required", null)
                    return
                }
                if (!BlockedNumbers.canModify(this)) {
                    result.error(
                        "DEFAULT_SMS_REQUIRED",
                        "Set Argus as your default SMS app to enable real system blocking",
                        null
                    )
                    return
                }
                if (BlockedNumbers.block(this, phoneNumber)) {
                    result.success("blocked")
                } else {
                    result.error("FAIL", "Could not block number", null)
                }
            }
            "unblockNumber" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                if (phoneNumber.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Phone number is required", null)
                    return
                }
                if (!BlockedNumbers.canModify(this)) {
                    result.error(
                        "DEFAULT_SMS_REQUIRED",
                        "Set Argus as your default SMS app to enable real system blocking",
                        null
                    )
                    return
                }
                if (BlockedNumbers.unblock(this, phoneNumber)) {
                    result.success("unblocked")
                } else {
                    result.error("FAIL", "Could not unblock number", null)
                }
            }
            "isNumberBlocked" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                if (phoneNumber.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Phone number is required", null)
                    return
                }
                result.success(BlockedNumbers.isBlocked(this, phoneNumber))
            }
            "getBlockedNumbers" -> {
                result.success(BlockedNumbers.getAll(this))
            }
            else -> result.notImplemented()
        }
    }

    private fun handleSmsRoleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultSmsApp" -> {
                result.success(isDefaultSmsApp())
            }
            "requestDefaultSmsApp" -> {
                requestDefaultSmsApp()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun isDefaultSmsApp(): Boolean {
        return try {
            Telephony.Sms.getDefaultSmsPackage(this) == packageName
        } catch (_: Exception) {
            false
        }
    }

    private fun requestDefaultSmsApp() {
        try {
            val intent: Intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            } else {
                Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                    putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
        }
    }
}