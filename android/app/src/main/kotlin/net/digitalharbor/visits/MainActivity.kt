package net.digitalharbor.visits

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import net.digitalharbor.visits.workday.WorkdayChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WorkdayChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
