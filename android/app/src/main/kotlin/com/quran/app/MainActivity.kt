package com.quran.app

import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.quran.app/mushaf_pages"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val assetPackManager = AssetPackManagerFactory.getInstance(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMushafPagesPath" -> {
                    val location = assetPackManager.getPackLocation("mushaf_pages_pack")
                    if (location == null) {
                        result.error("NOT_AVAILABLE", "مجلد صفحات المصحف غير متاح بعد", null)
                    } else {
                        result.success(location.assetsPath())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
