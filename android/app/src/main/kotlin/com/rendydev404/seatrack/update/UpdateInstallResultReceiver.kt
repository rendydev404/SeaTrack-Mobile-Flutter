package com.rendydev404.seatrack.update

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Status sesi [android.content.pm.PackageInstaller]. Membuka kembali aplikasi
 * bukan tugas receiver ini; itu ditangani [AppUpdateRelaunchReceiver] lewat
 * `MY_PACKAGE_REPLACED`, supaya tidak ada dua jalur yang sama-sama membuka layar.
 */
class UpdateInstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AppUpdateManager.handleInstallStatus(context.applicationContext, intent)
    }

    companion object {
        const val ACTION_INSTALL_STATUS = "com.rendydev404.seatrack.UPDATE_INSTALL_STATUS"
    }
}
