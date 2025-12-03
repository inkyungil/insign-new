package app.insign

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.back_button"
    private var backPressedTime: Long = 0
    private val BACK_PRESSED_INTERVAL: Long = 2000 // 2초
    private var methodChannel: MethodChannel? = null
    private var backCallback: OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Let content draw behind system bars; handled via WindowInsets in Flutter side.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "Configuring Flutter Engine")

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentRoute" -> {
                    result.success("success")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Android 13+ 백버튼 처리
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Log.d("MainActivity", "Registering OnBackInvokedCallback for Android 13+")
            backCallback = OnBackInvokedCallback {
                Log.d("MainActivity", "OnBackInvokedCallback triggered")
                handleBackPressed()
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback!!
            )
        }
    }

    override fun onBackPressed() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Log.d("MainActivity", "onBackPressed for Android < 13")
            handleBackPressed()
        }
    }

    private fun handleBackPressed() {
        Log.d("MainActivity", "handleBackPressed called")

        methodChannel?.let { channel ->
            channel.invokeMethod("onBackPressed", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val shouldHandleInApp = result as? Boolean ?: false
                    Log.d("MainActivity", "Flutter response: shouldHandleInApp=$shouldHandleInApp")
                    if (!shouldHandleInApp) {
                        // Flutter에서 처리하지 않는다면 기본 앱 종료 처리
                        handleAppExit()
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e("MainActivity", "Flutter error: $errorCode - $errorMessage")
                    // 에러 발생 시 기본 앱 종료 처리
                    handleAppExit()
                }

                override fun notImplemented() {
                    Log.w("MainActivity", "Flutter method not implemented")
                    // 구현되지 않은 경우 기본 앱 종료 처리
                    handleAppExit()
                }
            })
        } ?: run {
            Log.e("MainActivity", "MethodChannel is null, handling app exit")
            handleAppExit()
        }
    }

    private fun handleAppExit() {
        Log.d("MainActivity", "handleAppExit called")
        val currentTime = System.currentTimeMillis()

        if (currentTime - backPressedTime < BACK_PRESSED_INTERVAL) {
            Log.d("MainActivity", "Double back press detected, finishing app")
            // 2초 이내에 다시 백버튼을 눌렀으면 앱 종료
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                finishAndRemoveTask()
            } else {
                super.onBackPressed()
            }
        } else {
            Log.d("MainActivity", "First back press, showing toast")
            // 첫 번째 백버튼 클릭
            backPressedTime = currentTime
            Toast.makeText(this, "뒤로가기를 한 번 더 누르면 종료됩니다", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backCallback != null) {
            onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backCallback!!)
        }
    }
}
