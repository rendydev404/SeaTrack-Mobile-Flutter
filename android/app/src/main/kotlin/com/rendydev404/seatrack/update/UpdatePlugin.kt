package com.rendydev404.seatrack.update

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Jembatan antara [AppUpdateManager] dan Dart.
 *
 * `seatrack/update` untuk perintah, `seatrack/update/events` untuk aliran status.
 * Status selalu dikirim di main thread karena sumbernya adalah executor I/O.
 */
class UpdatePlugin(private val context: Context) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, "seatrack/update").setMethodCallHandler(this)
        EventChannel(messenger, "seatrack/update/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                AppUpdateManager.initialize(context, call.argument<String>("manifestUrl").orEmpty())
                result.success(AppUpdateManager.snapshot())
            }
            "check" -> {
                AppUpdateManager.checkForUpdate(call.argument<Boolean>("force") ?: false)
                result.success(null)
            }
            "install" -> {
                AppUpdateManager.install(context)
                result.success(null)
            }
            "continueWithUserAction" -> {
                AppUpdateManager.continueWithUserAction(context)
                result.success(null)
            }
            "resumeAfterPermission" -> {
                AppUpdateManager.resumeAfterPermission()
                result.success(null)
            }
            "acknowledgeInstall" -> {
                AppUpdateManager.acknowledgeInstall()
                result.success(null)
            }
            "requestOverlayPermission" -> {
                runCatching {
                    context.startActivity(
                        AppUpdateRelauncher.overlayPermissionIntent(context)
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
                result.success(null)
            }
            "snapshot" -> result.success(AppUpdateManager.snapshot())
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        AppUpdateManager.setListener { snapshot ->
            main.post { events?.success(snapshot) }
        }
    }

    override fun onCancel(arguments: Any?) {
        AppUpdateManager.setListener(null)
        events = null
    }
}
