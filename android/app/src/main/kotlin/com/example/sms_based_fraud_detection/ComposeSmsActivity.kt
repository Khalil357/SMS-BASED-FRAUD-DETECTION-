package com.example.sms_based_fraud_detection

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Telephony
import android.telephony.SmsManager
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast

class ComposeSmsActivity : Activity() {

    private lateinit var recipientsInput: EditText
    private lateinit var bodyInput: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }       

        recipientsInput = EditText(this).apply {
            hint = "Recipient phone number"
            inputType = InputType.TYPE_CLASS_PHONE
        }
        bodyInput = EditText(this).apply {
            hint = "Type a message"
            gravity = Gravity.TOP
            minHeight = 160
        }
        val sendButton = Button(this).apply { text = "Send" }
        val sendButtonOld = sendButton

        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        root.addView(recipientsInput, lp)
        root.addView(bodyInput, lp)
        root.addView(sendButtonOld, lp)

        setContentView(root)

        loadPrefill()

        sendButtonOld.setOnClickListener {
            val destination = recipientsInput.text.toString().trim()
            val message = bodyInput.text.toString().trim()
            if (destination.isEmpty()) {
                Toast.makeText(this, "Enter a recipient", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            if (message.isEmpty()) {
                Toast.makeText(this, "Enter a message", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            if (canSendSms()) {
                send(destination, message)
            } else {
                requestPermissions(arrayOf(Manifest.permission.SEND_SMS), REQUEST_SEND_SMS)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_SEND_SMS && grantResults.isNotEmpty()) {
            val destination = recipientsInput.text.toString().trim()
            val message = bodyInput.text.toString().trim()
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED && destination.isNotEmpty()) {
                send(destination, message)
            }
        }
    }

    private fun canSendSms(): Boolean {
        return Telephony.Sms.getDefaultSmsPackage(this) == packageName ||
            checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun send(destination: String, message: String) {
        try {
            val manager = SmsManager.getDefault()
            val parts = manager.divideMessage(message)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(destination, null, parts, null, null)
            } else {
                manager.sendTextMessage(destination, null, message, null, null)
            }
            Toast.makeText(this, "Message sent", Toast.LENGTH_SHORT).show()
            finish()
        } catch (e: Exception) {
            Toast.makeText(this, "Failed to send: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun loadPrefill() {
        val body = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
        if (body.isNotEmpty()) bodyInput.setText(body)
        resolveRecipient(intent)?.takeIf { it.isNotEmpty() }?.let {
            recipientsInput.setText(it)
        }
    }

    private fun resolveRecipient(intent: Intent): String? {
        val uri = intent.data ?: return null
        val spec = uri.schemeSpecificPart?.trim()
        if (spec.isNullOrEmpty()) return null
        return when (spec) {
            "number=,body=" -> ""
            else -> {
                val at = spec.indexOf('?')
                var base = if (at >= 0) spec.substring(0, at) else spec
                if (base.startsWith("number=")) {
                    base = Uri.decode(base.substring("number=".length))
                }
                val bodyIdx = spec.indexOf("body=")
                if (bodyIdx >= 0) {
                    val b = Uri.decode(spec.substring(bodyIdx + "body=".length))
                    if (b.isNotEmpty()) bodyInput.setText(b)
                }
                base
            }
        }
    }

    private companion object {
        const val REQUEST_SEND_SMS = 1001
    }
}