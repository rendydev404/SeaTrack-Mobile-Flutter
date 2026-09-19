package com.rendydev404.seatrack.update

import com.google.archivepatcher.applier.FileByFileV1DeltaApplier
import com.google.archivepatcher.shared.DefaultDeflater
import com.google.archivepatcher.shared.IDeflater
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.function.BiFunction
import java.util.zip.Inflater
import java.util.zip.InflaterInputStream

/**
 * Menyusun ulang APK baru dari APK yang sedang terpasang plus sebuah patch
 * File-by-File v1 (Google archive-patcher) yang dimampatkan deflate mentah.
 *
 * Hasilnya ditulis ke berkas `.partial` dulu, lalu baru dipindahkan setelah
 * SHA-256-nya cocok, supaya APK setengah jadi tidak pernah sampai ke installer.
 */
internal object ApkDeltaApplier {

    private const val BUFFER = 32 * 1024

    private val deflaterFactory = BiFunction<Int, Boolean, IDeflater> { level, nowrap ->
        DefaultDeflater(level, nowrap)
    }

    /**
     * @param installedApk berkas APK aplikasi yang sedang berjalan
     * @param expectedTargetSha256 hash APK hasil rekonstruksi menurut manifest
     * @throws IllegalArgumentException bila hasil rekonstruksi tidak cocok
     */
    fun apply(
        installedApk: File,
        patchFile: File,
        outputApk: File,
        expectedBaseVersion: Int,
        expectedTargetVersion: Int,
        expectedTargetSha256: String,
    ) {
        require(installedApk.isFile) { "APK terpasang tidak terbaca" }
        require(patchFile.isFile) { "Berkas patch tidak ditemukan" }
        require(expectedBaseVersion > 0 && expectedTargetVersion > expectedBaseVersion) {
            "Rentang versi patch tidak masuk akal"
        }

        val partial = File(outputApk.parentFile, "${outputApk.name}.partial")
        partial.delete()
        val inflater = Inflater(true)
        try {
            BufferedInputStream(FileInputStream(patchFile), BUFFER).use { compressed ->
                InflaterInputStream(compressed, inflater, BUFFER).use { patch ->
                    BufferedOutputStream(FileOutputStream(partial), BUFFER).use { output ->
                        FileByFileV1DeltaApplier(outputApk.parentFile, deflaterFactory)
                            .applyDelta(installedApk, patch, output)
                    }
                }
            }
            val actual = sha256(partial)
            require(actual.equals(expectedTargetSha256, ignoreCase = true)) {
                "SHA-256 hasil patch tidak cocok"
            }
            if (outputApk.exists()) require(outputApk.delete()) { "APK lama tidak bisa diganti" }
            require(partial.renameTo(outputApk)) { "APK hasil patch tidak bisa difinalkan" }
        } catch (error: Exception) {
            partial.delete()
            throw error
        } finally {
            inflater.end()
        }
    }

    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(BUFFER)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }
}
