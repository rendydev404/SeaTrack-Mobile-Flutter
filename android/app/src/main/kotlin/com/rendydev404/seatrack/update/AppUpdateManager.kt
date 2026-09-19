package com.rendydev404.seatrack.update

import android.app.DownloadManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Pembaruan mandiri berbasis delta patch dan pemasangan diam-diam.
 *
 * Diadaptasi dari modul `core/update` SUPER-APPS, dengan satu perbedaan: sumber
 * versi bukan baris Supabase yang didorong lewat WebSocket, melainkan berkas
 * JSON statis yang diterbitkan GitHub Actions setiap kali `main` diperbarui.
 * Perangkat menariknya saat aplikasi dibuka, paling sering sekali tiap 4 jam.
 *
 * Bila tersedia patch untuk versi yang sedang terpasang, yang diunduh hanya
 * selisihnya, lalu APK utuh disusun ulang di perangkat oleh [ApkDeltaApplier].
 * Kegagalan apa pun pada jalur patch otomatis jatuh kembali ke APK penuh.
 *
 * Tanpa coroutine: satu executor untuk kerja I/O dan satu scheduler untuk
 * polling, supaya tidak perlu menambah kotlinx-coroutines ke aplikasi ini.
 */
object AppUpdateManager {

    private const val TAG = "SeaTrackUpdate"
    private const val PREFS = "seatrack_update"
    private const val KEY_LAST_CHECK = "last_check_at"
    private const val KEY_DOWNLOADED_PREFIX = "downloaded_"
    private const val KEY_ACKNOWLEDGED = "acknowledged_version"

    /** Jeda minimum antar pengecekan otomatis. Tombol manual mengabaikannya. */
    private const val CHECK_INTERVAL_MS = 4 * 60 * 60 * 1000L
    private const val INSTALL_TIMEOUT_MS = 120_000L

    const val STATE_IDLE = "idle"
    const val STATE_CHECKING = "checking"
    const val STATE_AVAILABLE = "available"
    const val STATE_DOWNLOADING = "downloading"
    const val STATE_READY = "ready"
    const val STATE_INSTALLING = "installing"
    const val STATE_NEEDS_PERMISSION = "needsPermission"
    const val STATE_FAILED = "failed"

    private val io = Executors.newSingleThreadExecutor { r -> Thread(r, "seatrack-update") }
    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor { r ->
        Thread(r, "seatrack-update-poll").apply { isDaemon = true }
    }

    /**
     * Gerbang atomik: penerima siaran DownloadManager dan polling kemajuan bisa
     * sama-sama menyimpulkan "unduhan selesai" nyaris bersamaan. Tanpa ini,
     * berkas yang sama ditambal dua kali dan hasilnya rusak.
     */
    private val processingPayload = AtomicBoolean(false)

    @Volatile private var appContext: Context? = null
    @Volatile private var listener: ((Map<String, Any?>) -> Unit)? = null

    private var state = STATE_IDLE
    private var progress = 0
    private var errorMessage: String? = null
    private var pending: UpdateManifest? = null
    private var pendingDelta: UpdateDelta? = null
    private var pendingUserAction: Intent? = null

    /** Versi yang jalur patch-nya sudah gagal sekali, jadi harus lewat APK penuh. */
    private var forceFullForVersion: Int? = null
    private var payloadIsDelta = false
    private var payloadSizeBytes: Long? = null
    private var downloadId = -1L
    private var receiverRegistered = false
    private var manifestUrl: String = ""

    var currentVersionCode = 1
        private set
    var currentVersionName = "1.0.0"
        private set

    /** Versi yang baru saja terpasang, untuk ditampilkan sekali sebagai konfirmasi. */
    private var justInstalledVersion: String? = null

    fun initialize(context: Context, manifestUrl: String) {
        val ctx = context.applicationContext
        appContext = ctx
        this.manifestUrl = manifestUrl.trim()

        val info = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                ctx.packageManager.getPackageInfo(ctx.packageName, 0)
            }
        }.getOrNull()

        if (info != null) {
            currentVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode
            }
            currentVersionName = info.versionName.orEmpty().ifBlank { "1.0.0" }
        }

        cleanOldInstallers(ctx)

        val prefs = prefs(ctx)
        if (prefs.getInt(KEY_ACKNOWLEDGED, 0) != currentVersionCode) {
            val wasUpdated = info != null && info.lastUpdateTime - info.firstInstallTime > 1_000L
            if (wasUpdated) {
                justInstalledVersion = currentVersionName
            } else {
                prefs.edit().putInt(KEY_ACKNOWLEDGED, currentVersionCode).apply()
            }
        }
        emit()
    }

    fun setListener(l: ((Map<String, Any?>) -> Unit)?) {
        listener = l
        if (l != null) emit()
    }

    fun acknowledgeInstall() {
        val ctx = appContext ?: return
        prefs(ctx).edit().putInt(KEY_ACKNOWLEDGED, currentVersionCode).apply()
        justInstalledVersion = null
        emit()
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "state" to state,
        "progress" to progress,
        "error" to errorMessage,
        "currentVersionCode" to currentVersionCode,
        "currentVersionName" to currentVersionName,
        "justInstalledVersion" to justInstalledVersion,
        "canInstall" to (appContext?.let { canRequestInstall(it) } ?: false),
        "configured" to manifestUrl.startsWith("https://"),
        "isDelta" to payloadIsDelta,
        "payloadSizeBytes" to payloadSizeBytes,
        "manifest" to pending?.toMap(),
    )

    // ---------------------------------------------------------------- checking

    /**
     * Mengambil manifest lalu mulai mengunduh bila versinya lebih baru.
     * [force] melewati jeda 4 jam dan dipakai tombol "Periksa".
     */
    fun checkForUpdate(force: Boolean) {
        val ctx = appContext ?: return
        if (!manifestUrl.startsWith("https://")) return
        if (state == STATE_CHECKING || state == STATE_DOWNLOADING || state == STATE_INSTALLING) return

        // APK untuk versi ini sudah siap: lanjutkan memasang, jangan unduh ulang.
        if (state == STATE_READY && pending != null) {
            maybeAutoInstall(ctx)
            return
        }

        val prefs = prefs(ctx)
        val last = prefs.getLong(KEY_LAST_CHECK, 0L)
        if (!force && System.currentTimeMillis() - last < CHECK_INTERVAL_MS) return

        setState(STATE_CHECKING)
        io.execute {
            val json = runCatching { fetch(manifestUrl) }.getOrElse {
                Log.w(TAG, "Gagal mengambil manifest: ${it.message}")
                setState(if (pending != null) STATE_AVAILABLE else STATE_IDLE)
                return@execute
            }
            prefs.edit().putLong(KEY_LAST_CHECK, System.currentTimeMillis()).apply()

            val manifest = UpdateManifest.parse(json)
            if (manifest == null) {
                Log.w(TAG, "Manifest tidak valid")
                setState(STATE_IDLE)
                return@execute
            }
            if (manifest.versionCode <= currentVersionCode) {
                pending = null
                setState(STATE_IDLE)
                return@execute
            }
            applyNewer(ctx, manifest)
        }
    }

    private fun fetch(url: String): String {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 15_000
            instanceFollowRedirects = true
            requestMethod = "GET"
            setRequestProperty("User-Agent", "SeaTrack-Updater/$currentVersionName")
            setRequestProperty("Accept", "application/json")
        }
        try {
            if (conn.responseCode !in 200..299) error("HTTP ${conn.responseCode}")
            return conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    private fun applyNewer(ctx: Context, manifest: UpdateManifest) {
        if (pending?.versionCode != manifest.versionCode) {
            cancelDownload(ctx)
            pendingUserAction = null
            pendingDelta = null
            forceFullForVersion = null
            processingPayload.set(false)
            progress = 0
        }
        pending = manifest
        setState(STATE_AVAILABLE)
        startDownload(ctx, manifest)
    }

    // --------------------------------------------------------------- download

    private fun startDownload(ctx: Context, manifest: UpdateManifest) {
        if (state == STATE_DOWNLOADING || processingPayload.get()) return

        val apk = apkFile(ctx, manifest.versionCode)
        if (apk.exists() && prefs(ctx).getBoolean("$KEY_DOWNLOADED_PREFIX${manifest.versionCode}", false)) {
            progress = 100
            setState(STATE_READY)
            maybeAutoInstall(ctx)
            return
        }

        // Patch hanya dipakai bila lebih kecil dari APK penuh dan hash target
        // diketahui; tanpa hash target, hasil rekonstruksi tidak bisa dibuktikan.
        val delta = manifest.deltaFor(currentVersionCode)?.takeIf {
            forceFullForVersion != manifest.versionCode &&
                !manifest.apkSha256.isNullOrBlank() &&
                (manifest.apkSizeBytes == null || it.patchSizeBytes < manifest.apkSizeBytes)
        }
        pendingDelta = delta
        payloadIsDelta = delta != null
        payloadSizeBytes = delta?.patchSizeBytes ?: manifest.apkSizeBytes

        val payloadFile = if (delta != null) {
            patchFile(ctx, delta.baseVersionCode, manifest.versionCode)
        } else {
            apk
        }
        if (apk.exists()) apk.delete()
        if (payloadFile.exists()) payloadFile.delete()

        progress = 0
        setState(STATE_DOWNLOADING)
        registerReceiver(ctx)

        val dm = ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(delta?.patchUrl ?: manifest.apkUrl))
            .setTitle("Pembaruan SeaTrack")
            .setDescription(
                if (delta != null) "Mengunduh patch versi ${manifest.versionName}"
                else "Mengunduh versi ${manifest.versionName}"
            )
            .addRequestHeader("User-Agent", "SeaTrack-Updater/$currentVersionName")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationUri(Uri.fromFile(payloadFile))
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)

        downloadId = runCatching { dm.enqueue(request) }.getOrElse {
            fail("Gagal memulai unduhan: ${it.message}")
            return
        }
        pollProgress(ctx, dm)
    }

    private fun pollProgress(ctx: Context, dm: DownloadManager) {
        scheduler.schedule(object : Runnable {
            override fun run() {
                if (downloadId == -1L) return
                var finished = false
                runCatching { dm.query(DownloadManager.Query().setFilterById(downloadId)) }
                    .getOrNull()?.use {
                        if (!it.moveToFirst()) return@use
                        val statusIdx = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
                        val bytesIdx = it.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                        val totalIdx = it.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                        val status = if (statusIdx >= 0) it.getInt(statusIdx) else -1
                        val bytes = if (bytesIdx >= 0) it.getLong(bytesIdx) else 0L
                        val total = if (totalIdx >= 0) it.getLong(totalIdx) else -1L

                        if (total > 0 && state == STATE_DOWNLOADING) {
                            val pct = ((bytes * 100) / total).toInt().coerceIn(0, 100)
                            if (pct != progress) {
                                progress = pct
                                emit()
                            }
                        }
                        when (status) {
                            DownloadManager.STATUS_SUCCESSFUL -> {
                                finished = true
                                onDownloadFinished(ctx)
                            }
                            DownloadManager.STATUS_FAILED -> {
                                finished = true
                                fail("Unduhan gagal")
                            }
                        }
                    }
                if (!finished && downloadId != -1L) {
                    scheduler.schedule(this, 1, TimeUnit.SECONDS)
                }
            }
        }, 1, TimeUnit.SECONDS)
    }

    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (id != downloadId) return
            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val status = dm.query(DownloadManager.Query().setFilterById(id))?.use {
                if (!it.moveToFirst()) return@use null
                val idx = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
                if (idx >= 0) it.getInt(idx) else null
            }
            when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> onDownloadFinished(context.applicationContext)
                DownloadManager.STATUS_FAILED -> fail("Unduhan gagal")
            }
        }
    }

    /**
     * Memverifikasi berkas yang baru diunduh, menambal bila berupa patch, lalu
     * menandainya siap pasang. Hanya satu pemanggil yang lolos gerbang atomik.
     */
    private fun onDownloadFinished(ctx: Context) {
        if (state == STATE_READY || state == STATE_INSTALLING) return
        val manifest = pending ?: return
        if (!processingPayload.compareAndSet(false, true)) return

        io.execute {
            var retryAsFull = false
            try {
                val apk = apkFile(ctx, manifest.versionCode)
                val delta = pendingDelta
                if (delta != null) {
                    val patch = patchFile(ctx, delta.baseVersionCode, manifest.versionCode)
                    require(patch.length() == delta.patchSizeBytes) { "Ukuran patch tidak cocok" }
                    require(ApkDeltaApplier.sha256(patch).equals(delta.patchSha256, true)) {
                        "SHA-256 patch tidak cocok"
                    }
                    ApkDeltaApplier.apply(
                        installedApk = File(ctx.applicationInfo.sourceDir),
                        patchFile = patch,
                        outputApk = apk,
                        expectedBaseVersion = delta.baseVersionCode,
                        expectedTargetVersion = manifest.versionCode,
                        expectedTargetSha256 = requireNotNull(manifest.apkSha256),
                    )
                    patch.delete()
                } else {
                    require(apk.exists() && apk.length() > 0L) { "Berkas unduhan tidak ditemukan" }
                    manifest.apkSizeBytes?.let {
                        require(apk.length() == it) { "Ukuran berkas tidak cocok" }
                    }
                    manifest.apkSha256?.let {
                        require(ApkDeltaApplier.sha256(apk).equals(it, true)) {
                            "SHA-256 tidak cocok"
                        }
                    }
                }

                prefs(ctx).edit()
                    .putBoolean("$KEY_DOWNLOADED_PREFIX${manifest.versionCode}", true).apply()
                downloadId = -1L
                progress = 100
                setState(STATE_READY)
                maybeAutoInstall(ctx)
            } catch (e: Exception) {
                Log.e(TAG, "Validasi unduhan gagal", e)
                prefs(ctx).edit().remove("$KEY_DOWNLOADED_PREFIX${manifest.versionCode}").apply()
                // Patch bisa gagal karena APK terpasang tidak persis sama dengan
                // yang dipakai saat patch dibuat. APK penuh selalu bisa dipakai.
                retryAsFull = pendingDelta != null
                pendingDelta?.let {
                    patchFile(ctx, it.baseVersionCode, manifest.versionCode).delete()
                }
                if (!retryAsFull) {
                    runCatching { apkFile(ctx, manifest.versionCode).delete() }
                    fail(e.message ?: "Berkas pembaruan rusak")
                }
            } finally {
                processingPayload.set(false)
            }

            if (retryAsFull) {
                Log.i(TAG, "Patch gagal, mengunduh APK penuh")
                forceFullForVersion = manifest.versionCode
                pendingDelta = null
                progress = 0
                downloadId = -1L
                state = STATE_AVAILABLE
                startDownload(ctx, manifest)
            }
        }
    }

    // ---------------------------------------------------------------- install

    /**
     * Memasang sendiri bila izin sudah ada. Diberi jeda singkat supaya UI sempat
     * menampilkan status "siap dipasang" sebelum installer mengambil alih layar.
     */
    private fun maybeAutoInstall(ctx: Context) {
        if (!canRequestInstall(ctx)) {
            setState(STATE_NEEDS_PERMISSION)
            return
        }
        scheduler.schedule({
            if (state == STATE_READY) install(ctx)
        }, 1200, TimeUnit.MILLISECONDS)
    }

    fun install(context: Context) {
        val ctx = context.applicationContext
        val manifest = pending ?: return
        val apk = apkFile(ctx, manifest.versionCode)
        if (!apk.exists()) {
            fail("Berkas pembaruan tidak ditemukan")
            return
        }
        if (!canRequestInstall(ctx)) {
            pendingUserAction = null
            setState(STATE_NEEDS_PERMISSION)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            installSilently(ctx, apk)
        } else {
            launchLegacyInstaller(ctx, apk)
        }
    }

    private fun installSilently(ctx: Context, apk: File) {
        if (state == STATE_INSTALLING) return
        setState(STATE_INSTALLING)
        pendingUserAction = null

        io.execute {
            val installer = ctx.packageManager.packageInstaller
            var sessionId: Int? = null
            try {
                val params = PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL
                ).apply {
                    setAppPackageName(ctx.packageName)
                    setSize(apk.length())
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
                    }
                }
                sessionId = installer.createSession(params)
                installer.openSession(sessionId).use { session ->
                    FileInputStream(apk).use { input ->
                        session.openWrite("base.apk", 0, apk.length()).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    val callback = PendingIntent.getBroadcast(
                        ctx,
                        0,
                        Intent(ctx, UpdateInstallResultReceiver::class.java)
                            .setAction(UpdateInstallResultReceiver.ACTION_INSTALL_STATUS),
                        PendingIntent.FLAG_UPDATE_CURRENT or
                            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0),
                    )
                    AppUpdateRelauncher.markPending(ctx)
                    session.commit(callback.intentSender)
                }
                scheduler.schedule({
                    if (state == STATE_INSTALLING) fail("Pemasangan tidak selesai")
                }, INSTALL_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            } catch (e: Exception) {
                sessionId?.let { id -> runCatching { installer.abandonSession(id) } }
                Log.e(TAG, "Pemasangan gagal", e)
                fail(e.message ?: "Pemasangan gagal")
            }
        }
    }

    private fun launchLegacyInstaller(ctx: Context, apk: File) {
        val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        AppUpdateRelauncher.markPending(ctx)
        if (!startActivitySafely(ctx, intent)) fail("Tidak bisa membuka installer sistem")
    }

    /** Dipanggil [UpdateInstallResultReceiver] saat sesi PackageInstaller melapor. */
    fun handleInstallStatus(ctx: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_SUCCESS -> {
                pending = null
                pendingDelta = null
                progress = 0
                setState(STATE_IDLE)
            }
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                pendingUserAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                setState(STATE_NEEDS_PERMISSION)
            }
            else -> {
                val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                Log.e(TAG, "Pemasangan gagal: $msg")
                AppUpdateRelauncher.clearPending(ctx)
                fail(msg ?: "Pemasangan ditolak sistem")
            }
        }
    }

    /**
     * Melanjutkan setelah pengguna memberi izin, atau membuka dialog konfirmasi
     * sistem. Mengembalikan `false` bila layar sistem tidak bisa dibuka, supaya
     * UI bisa menyarankan pengaturan manual tanpa mengubah status pembaruan.
     */
    fun continueWithUserAction(context: Context): Boolean {
        val ctx = context.applicationContext
        pendingUserAction?.let { return startActivitySafely(ctx, it) }
        if (!canRequestInstall(ctx)) {
            return startActivitySafely(ctx, installPermissionIntent(ctx))
        }
        install(ctx)
        return true
    }

    /**
     * Semua intent di kelas ini diluncurkan dari context aplikasi, bukan Activity.
     * Tanpa FLAG_ACTIVITY_NEW_TASK, Android melempar AndroidRuntimeException dan
     * layar yang dituju tidak pernah terbuka.
     */
    private fun startActivitySafely(ctx: Context, intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { ctx.startActivity(intent) }
            .onFailure { Log.e(TAG, "Tidak bisa membuka layar sistem", it) }
            .isSuccess
    }

    fun canRequestInstall(ctx: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun installPermissionIntent(ctx: Context) =
        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${ctx.packageName}"))

    /** Dipanggil saat aplikasi kembali ke depan, setelah pengguna mengatur izin. */
    fun resumeAfterPermission() {
        val ctx = appContext ?: return
        if (state == STATE_NEEDS_PERMISSION && pendingUserAction == null && canRequestInstall(ctx)) {
            install(ctx)
        } else {
            emit()
        }
    }

    // ----------------------------------------------------------------- utils

    private fun cancelDownload(ctx: Context) {
        if (downloadId == -1L) return
        val dm = ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        runCatching { dm.remove(downloadId) }
        downloadId = -1L
    }

    private fun registerReceiver(ctx: Context) {
        if (receiverRegistered) return
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(downloadReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                ctx.registerReceiver(downloadReceiver, filter)
            }
            receiverRegistered = true
        }
    }

    private fun updatesDir(ctx: Context) =
        File(ctx.getExternalFilesDir(null), "updates").apply { mkdirs() }

    private fun apkFile(ctx: Context, versionCode: Int) =
        File(updatesDir(ctx), "seatrack-$versionCode.apk")

    private fun patchFile(ctx: Context, base: Int, target: Int) =
        File(updatesDir(ctx), "seatrack-$base-to-$target.patch")

    /**
     * Membuang berkas yang versinya sudah tidak lebih baru dari yang terpasang,
     * agar folder update tidak menumpuk puluhan megabyte.
     */
    fun cleanOldInstallers(ctx: Context) {
        runCatching {
            val dir = File(ctx.getExternalFilesDir(null), "updates")
            if (!dir.isDirectory) return
            dir.listFiles()?.forEach { file ->
                val name = file.name
                if (name.endsWith(".partial") || name.endsWith(".patch")) {
                    file.delete()
                    return@forEach
                }
                if (!name.endsWith(".apk")) return@forEach
                val target = Regex("""seatrack-(\d+)\.apk$""").find(name)
                    ?.groupValues?.get(1)?.toIntOrNull()
                if (target == null || target <= currentVersionCode) {
                    if (file.delete()) Log.i(TAG, "Menghapus installer lama: $name")
                }
            }
        }
    }

    private fun prefs(ctx: Context) =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun setState(next: String) {
        state = next
        if (next != STATE_FAILED) errorMessage = null
        emit()
    }

    private fun fail(message: String) {
        errorMessage = message
        state = STATE_FAILED
        downloadId = -1L
        emit()
    }

    private fun emit() {
        val snapshot = snapshot()
        listener?.let { l -> runCatching { l(snapshot) } }
    }
}
