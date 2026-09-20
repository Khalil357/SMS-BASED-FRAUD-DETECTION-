package com.example.secure_signal

import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQUEST_CALL_SCREENING_ROLE = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        requestCallScreeningRole()
    }

    private fun requestCallScreeningRole() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            println("ARGUS ROLE: Call screening role requires Android 10 or newer")
            return
        }

        val roleManager = getSystemService(RoleManager::class.java)

        if (roleManager == null) {
            println("ARGUS ROLE: RoleManager unavailable")
            return
        }

        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            println("ARGUS ROLE: CALL_SCREENING role is not available")
            return
        }

        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            println("ARGUS ROLE: Argus already holds CALL_SCREENING role")
            return
        }

        println("ARGUS ROLE: Requesting CALL_SCREENING role")

        val intent = roleManager.createRequestRoleIntent(
            RoleManager.ROLE_CALL_SCREENING
        )

        startActivityForResult(
            intent,
            REQUEST_CALL_SCREENING_ROLE
        )
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CALL_SCREENING_ROLE) {

            if (resultCode == Activity.RESULT_OK) {
                println("ARGUS ROLE: CALL_SCREENING role GRANTED")
            } else {
                println("ARGUS ROLE: CALL_SCREENING role NOT granted")
            }
        }
    }
}
