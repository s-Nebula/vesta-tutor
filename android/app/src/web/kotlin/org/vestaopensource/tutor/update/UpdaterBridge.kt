package org.vestaopensource.tutor.update

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Flutter side: channel "vesta/updater" (see lib/services/app_updater.dart). */
object UpdaterBridge {
    private val worker = Executors.newSingleThreadExecutor()

    fun register(engine: FlutterEngine, activity: Activity) {
        val context = activity.applicationContext
        Updater.schedule(context)
        MethodChannel(engine.dartExecutor.binaryMessenger, "vesta/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(Updater.status(context))
                    "checkNow" -> worker.execute {
                        Updater.run(context, manual = true)
                        activity.runOnUiThread { result.success(Updater.status(context)) }
                    }
                    "openInstallSettings" -> {
                        Updater.openInstallSettings(activity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    fun onResume(activity: Activity) {
        Updater.foregroundActivity = activity
    }

    fun onPause(activity: Activity) {
        if (Updater.foregroundActivity === activity) Updater.foregroundActivity = null
    }
}
