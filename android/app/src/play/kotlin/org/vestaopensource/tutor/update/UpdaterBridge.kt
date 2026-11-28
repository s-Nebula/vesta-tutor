package org.vestaopensource.tutor.update

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play build: Play installs the updates. The channel only answers
 * "supported: false" so the Flutter side uses the Play in-app update instead.
 */
object UpdaterBridge {
    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "vesta/updater")
            .setMethodCallHandler { call, result ->
                if (call.method == "status") result.success(mapOf("supported" to false))
                else result.notImplemented()
            }
    }

    fun onResume(activity: Activity) = Unit
    fun onPause(activity: Activity) = Unit
}
