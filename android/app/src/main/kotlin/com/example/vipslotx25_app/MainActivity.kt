package com.example.vipslotx25_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent // Import Intent

class MainActivity: FlutterActivity() {
    // 1. Đặt tên "cầu nối" (phải giống hệt bên Dart)
    private val CHANNEL = "com.example/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 2. Tạo MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->

            // 3. Lắng nghe lệnh 'startService'
            if (call.method == "startService") {
                startMyService() // Gọi hàm Kotlin của bạn
                result.success(null) // Báo cho Dart là đã thành công
            } else {
                result.notImplemented()
            }
        }
    }

    // 4. Hàm Kotlin để khởi động Service
    private fun startMyService() {
        val serviceIntent = Intent(this, MyForegroundService::class.java)
        startService(serviceIntent)
    }
}