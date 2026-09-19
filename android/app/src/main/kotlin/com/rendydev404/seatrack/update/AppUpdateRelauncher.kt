package com.rendydev404.seatrack.update

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * Membuka kembali SeaTrack begitu APK baru selesai terpasang.
 *
 * Proses lama ikut mati saat dirinya sendiri di-update, jadi pemicunya adalah
 * `MY_PACKAGE_REPLACED` yang diterima proses versi baru. Sejak Android 10,
 * receiver latar belakang tidak boleh membuka activity. Pengecualian yang bisa
 * dipakai aplikasi distribusi mandiri hanya izin "Tampil di atas aplikasi lain",
 * dan sejak Android 15 izin itu baru berlaku bila aplikasi benar-benar punya
 * jendela overlay yang sedang tampil. Karena itu dipasang overlay 1x1 transparan
 * yang langsung dilepas begitu layar utama muncul.
 *
 * Bila cara itu gagal, notifikasi "ketuk untuk membuka" menjadi jaring pengaman.
 * Relaunch hanya dilakukan bila update dipasang saat aplikasi sedang dipakai,
 * supaya pembaruan di latar belakang tidak tiba-tiba menyerobot layar.
 */
object AppUpdateRelauncher {

    private const val TAG = "SeaTrackRelaunch"
    private const val PREFS = "seatrack_update_relaunch"
    private const val KEY_PENDING_AT = "relaunch_pending_at"
    private const val PENDING_TTL_MS = 15 * 60_000L

    private const val OVERLAY_SETTLE_MS = 200L
    private const val RETRY_AFTER_MS = 1_000L
    private const val FALLBACK_AFTER_MS = 3_000L

    private const val CHANNEL_ID = "seatrack_update_relaunch"
    const val NOTIFICATION_ID = 99125

    @Volatile private var appVisible = false
    private var overlayView: View? = null

    fun onAppVisible(context: Context) {
        appVisible = true
        removeOverlay(context)
        runCatching {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        }
    }

    fun onAppHidden() {
        appVisible = false
    }

    /** Dipanggil tepat sebelum instalasi diserahkan ke sistem. */
    fun markPending(context: Context) {
        if (!appVisible) return
        // commit(), bukan apply(): proses bisa dibunuh installer sebelum apply() menulis.
        prefs(context).edit().putLong(KEY_PENDING_AT, System.currentTimeMillis()).commit()
    }

    fun clearPending(context: Context) {
        prefs(context).edit().remove(KEY_PENDING_AT).apply()
    }

    fun onPackageReplaced(context: Context, pendingResult: BroadcastReceiver.PendingResult) {
        val ctx = context.applicationContext
        val pendingAt = prefs(ctx).getLong(KEY_PENDING_AT, 0L)
        clearPending(ctx)
        if (System.currentTimeMillis() - pendingAt !in 0..PENDING_TTL_MS) {
            pendingResult.finish()
            return
        }

        val handler = Handler(Looper.getMainLooper())
        val overlayShown = showOverlay(ctx)
        Log.i(TAG, "Update terpasang, membuka aplikasi (overlay=$overlayShown)")

        handler.postDelayed({ startMain(ctx, clearTask = true) }, if (overlayShown) OVERLAY_SETTLE_MS else 0L)
        // Perangkat lambat kadang belum menganggap overlay tampil pada percobaan pertama.
        handler.postDelayed({ if (!appVisible) startMain(ctx, clearTask = false) }, RETRY_AFTER_MS)
        handler.postDelayed({
            removeOverlay(ctx)
            if (!appVisible) postFallbackNotification(ctx)
            pendingResult.finish()
        }, FALLBACK_AFTER_MS)
    }

    private fun startMain(ctx: Context, clearTask: Boolean) {
        val intent = launchIntent(ctx) ?: return
        if (clearTask) intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
        runCatching { ctx.startActivity(intent) }
            .onFailure { Log.w(TAG, "Gagal membuka activity: ${it.message}") }
    }

    private fun launchIntent(ctx: Context): Intent? =
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        }

    fun canDrawOverlays(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Settings.canDrawOverlays(ctx)

    fun overlayPermissionIntent(ctx: Context): Intent =
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}"))

    private fun showOverlay(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || !Settings.canDrawOverlays(ctx)) return false
        return runCatching {
            val view = View(ctx)
            val params = WindowManager.LayoutParams(
                1,
                1,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.TOP or Gravity.START }
            ctx.getSystemService(WindowManager::class.java).addView(view, params)
            overlayView = view
            true
        }.getOrElse {
            Log.w(TAG, "Gagal memasang overlay: ${it.message}")
            false
        }
    }

    private fun removeOverlay(ctx: Context) {
        val view = overlayView ?: return
        overlayView = null
        runCatching {
            ctx.applicationContext.getSystemService(WindowManager::class.java).removeViewImmediate(view)
        }
    }

    private fun postFallbackNotification(ctx: Context) {
        val intent = launchIntent(ctx) ?: return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Pembaruan Selesai", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Membuka kembali aplikasi setelah pembaruan"
                    setSound(null, null)
                    enableVibration(false)
                }
            )
        }
        val pi = PendingIntent.getActivity(
            ctx,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("SeaTrack sudah diperbarui")
            .setContentText("Ketuk untuk membuka kembali aplikasi")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        // Tanpa izin POST_NOTIFICATIONS, notify() melempar SecurityException di sebagian ROM.
        runCatching { nm.notify(NOTIFICATION_ID, notification) }
    }

    private fun prefs(ctx: Context) =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
