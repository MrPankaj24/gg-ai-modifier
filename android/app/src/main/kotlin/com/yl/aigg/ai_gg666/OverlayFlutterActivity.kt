package com.yl.aigg.ai_gg666

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Implementation detail.
 * Implementation detail.
 */
class OverlayFlutterActivity : FlutterActivity() {

    companion object {
        private const val ENGINE_ID = "overlay_flutter_engine"
        const val EXTRA_PAGE = "page"

        fun withPage(context: Context, page: String): Intent {
            return Intent(context, OverlayFlutterActivity::class.java).apply {
                putExtra(EXTRA_PAGE, page)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        // Implementation detail.
        var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)

        if (engine == null) {
            // Implementation detail.
            engine = FlutterEngine(context)

            // Implementation detail.
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            // Implementation detail.
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        }

        return engine
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Implementation detail.
        val page = intent.getStringExtra(EXTRA_PAGE) ?: "chat"

        // Implementation detail.
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = io.flutter.plugin.common.MethodChannel(messenger, "com.yl.aigg/overlay")
            channel.invokeMethod("navigateTo", page)
        }
    }

    override fun onDestroy() {
        // Implementation detail.
        super.onDestroy()
    }
}
