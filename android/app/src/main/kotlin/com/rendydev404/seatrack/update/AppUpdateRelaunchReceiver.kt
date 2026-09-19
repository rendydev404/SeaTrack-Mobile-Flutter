package com.rendydev404.seatrack.update

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Diterima proses versi baru begitu APK selesai dipasang. goAsync() menahan
 * receiver tetap hidup selama relauncher menunggu overlay tampil dan activity
 * terbuka.
 */
class AppUpdateRelaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        AppUpdateRelauncher.onPackageReplaced(context, goAsync())
    }
}
