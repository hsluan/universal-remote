package com.antigravity.universal_remote.apps

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel handler for `universal_remote/apps`: checks for, opens and installs the
 * makers' own apps (Mi Home, Tapo...), which the app links to for closed devices.
 *
 * On Android 11+ a package is only visible when AndroidManifest.xml lists it in <queries>.
 */
class AppLauncherBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package")
        if (packageName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENTS", "A package name is required", null)
            return
        }
        when (call.method) {
            "isInstalled" -> result.success(isInstalled(packageName))
            "launch" -> result.success(launch(packageName))
            "openStorePage" -> result.success(openStorePage(packageName))
            else -> result.notImplemented()
        }
    }

    private fun isInstalled(packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun launch(packageName: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent)
    }

    private fun openStorePage(packageName: String): Boolean {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (start(market)) return true
        val web = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(web)
    }

    private fun start(intent: Intent): Boolean = try {
        context.startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    companion object {
        const val CHANNEL = "universal_remote/apps"
    }
}
