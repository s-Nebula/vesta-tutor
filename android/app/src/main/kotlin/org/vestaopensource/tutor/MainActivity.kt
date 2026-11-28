package org.vestaopensource.tutor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.vestaopensource.tutor.update.UpdaterBridge

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UpdaterBridge.register(flutterEngine, this)
    }

    override fun onResume() {
        super.onResume()
        UpdaterBridge.onResume(this)
    }

    override fun onPause() {
        UpdaterBridge.onPause(this)
        super.onPause()
    }
}
