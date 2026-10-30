package com.k.todo

import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.time.ZoneId
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.k.todo/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "hideFromRecents" -> {
                    hideFromRecents(call.arguments as Boolean)
                    result.success(null)
                }
                // Counts the time the phone has slept, and turning its clock
                // can't change it.
                "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                // The same, with which start of the phone it counts from, as
                // a restart starts it again.
                "bootTime" -> result.success(
                    mapOf(
                        "boot" to Settings.Global.getInt(
                            contentResolver, Settings.Global.BOOT_COUNT, 0
                        ),
                        "sinceBoot" to SystemClock.elapsedRealtime(),
                    )
                )
                // The phone's time zone, such as "Africa/Cairo", which
                // reminders go by to keep to its clock through summer time.
                "timeZone" -> result.success(ZoneId.systemDefault().id)
                // As Home does, keeping the app's pages, where Back would
                // close them.
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "com.k.todo/biometrics").setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticate" -> authenticate(call.argument<String>("reason")!!, result)
                else -> result.notImplemented()
            }
        }
        // Off the main thread, as stretching a password is slow on purpose.
        MethodChannel(
            messenger,
            "com.k.todo/backup",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pbkdf2" -> result.success(
                    pbkdf2(
                        call.argument<String>("password")!!,
                        call.argument<ByteArray>("salt")!!,
                        call.argument<Int>("iterations")!!,
                    )
                )
                else -> result.notImplemented()
            }
        }
    }

    // Keeps the app's last screen out of the recent apps, where anyone could
    // see it without unlocking the app. Before Android 13 that takes keeping
    // it out of screenshots too.
    private fun hideFromRecents(hidden: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!hidden)
        } else if (hidden) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    // Asks for the user's fingerprint, or another biometric as strong, giving
    // [reason], and replies "passed", "failed", "lockedOut" or "unavailable".
    private fun authenticate(reason: String, result: MethodChannel.Result) {
        val authenticators = strongestBiometrics()
        // A prompt that can't show now, with the app put away, would never
        // reply.
        if (authenticators == null || supportFragmentManager.isStateSaved) {
            result.success(if (authenticators == null) "unavailable" else "failed")
            return
        }
        var replied = false
        fun reply(outcome: String) {
            if (replied) return
            replied = true
            result.success(outcome)
        }
        BiometricPrompt(this, mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) =
                reply("passed")

            // Not onAuthenticationFailed, for a single fingerprint that didn't
            // match: the prompt stays up for another.
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) =
                reply(
                    when (errorCode) {
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "lockedOut"
                        BiometricPrompt.ERROR_HW_UNAVAILABLE,
                        BiometricPrompt.ERROR_HW_NOT_PRESENT,
                        BiometricPrompt.ERROR_NO_BIOMETRICS,
                        BiometricPrompt.ERROR_SECURITY_UPDATE_REQUIRED -> "unavailable"
                        else -> "failed"
                    }
                )
        }).authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Authentication required")
                .setSubtitle("Verify identity")
                .setDescription(reason)
                .setNegativeButtonText("Cancel")
                .setAllowedAuthenticators(authenticators)
                .build()
        )
    }

    // Android's Class 3 biometrics, such as a fingerprint, on a phone with one
    // set up, rather than also its Class 2 ones, such as a face unlock that a
    // photo can fool. Class 2 only on a phone with no Class 3 one to set up,
    // or none set up, as there's nothing stronger to ask for, and refusing
    // them would lock out anyone the App Lock already takes them from. Null
    // for a phone that can't take any just now.
    private fun strongestBiometrics(): Int? {
        val biometrics = BiometricManager.from(this)
        return when (biometrics.canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BIOMETRIC_STRONG
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED,
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
                if (biometrics.canAuthenticate(BIOMETRIC_WEAK) ==
                    BiometricManager.BIOMETRIC_SUCCESS
                ) BIOMETRIC_WEAK else null
            else -> null
        }
    }

    // PBKDF2-HMAC-SHA256 (RFC 8018) of the password's UTF-8, for its first
    // block: a 256-bit key. On the phone's own HMAC, which is native, rather
    // than through its PBKDF2WithHmacSHA256, which isn't, and takes several
    // times as long.
    private fun pbkdf2(password: String, salt: ByteArray, iterations: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(password.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        mac.update(salt)
        var block = mac.doFinal(byteArrayOf(0, 0, 0, 1))
        val key = block.copyOf()
        repeat(iterations - 1) {
            block = mac.doFinal(block)
            for (i in key.indices) {
                key[i] = (key[i].toInt() xor block[i].toInt()).toByte()
            }
        }
        return key
    }
}
