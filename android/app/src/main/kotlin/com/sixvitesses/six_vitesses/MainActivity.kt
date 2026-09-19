package com.sixvitesses.six_vitesses

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "six_vitesses/location_permission"
        private const val REQUEST_CODE = 6101
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(
            flutterEngine?.dartExecutor?.binaryMessenger ?: return,
            CHANNEL,
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "request" -> requestLocationPermission(result)
                "status" -> result.success(currentPermissionStatus())
                else -> result.notImplemented()
            }
        }
    }

    private fun currentPermissionStatus(): String {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)

        return when {
            fine == PackageManager.PERMISSION_GRANTED ||
                coarse == PackageManager.PERMISSION_GRANTED -> "granted"
            else -> "denied"
        }
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (currentPermissionStatus() == "granted") {
            result.success("granted")
            return
        }

        if (pendingResult != null) {
            result.error("REQUEST_IN_PROGRESS", "Location permission request already in progress.", null)
            return
        }

        pendingResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != REQUEST_CODE) return

        val result = pendingResult
        pendingResult = null

        when {
            grantResults.any { it == PackageManager.PERMISSION_GRANTED } ->
                result?.success("granted")
            grantResults.isNotEmpty() ->
                result?.success("denied")
            else ->
                result?.success(currentPermissionStatus())
        }
    }

    override fun onDestroy() {
        pendingResult?.success(currentPermissionStatus())
        pendingResult = null
        super.onDestroy()
    }
}
