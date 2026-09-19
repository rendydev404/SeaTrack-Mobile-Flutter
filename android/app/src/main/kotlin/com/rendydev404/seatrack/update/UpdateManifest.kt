package com.rendydev404.seatrack.update

import org.json.JSONObject

/**
 * Patch dari satu versi lama ke versi di manifest ini. Perangkat hanya memakai
 * entri yang `base_version_code`-nya sama persis dengan versi terpasang.
 */
data class UpdateDelta(
    val baseVersionCode: Int,
    val patchUrl: String,
    val patchSha256: String,
    val patchSizeBytes: Long,
)

/**
 * Isi berkas JSON yang menjadi sumber versi terbaru.
 *
 * SeaTrack didistribusikan sendiri (bukan lewat Play Store), jadi pembaruan
 * dicek dan dipasang dari dalam aplikasi. Berbeda dari proyek rujukan yang
 * membaca baris `global_settings` di Supabase, di sini manifest cukup berkas
 * statis; alur rilis di `.github/workflows/release.yml` menerbitkannya sebagai
 * aset GitHub Release.
 *
 * ```json
 * {
 *   "version_code": 12,
 *   "version_name": "1.0.1",
 *   "apk_url": "https://…/seatrack-12.apk",
 *   "apk_sha256": "…64 hex…",
 *   "apk_size_bytes": 54120000,
 *   "deltas": [
 *     {
 *       "base_version_code": 11,
 *       "patch_url": "https://…/seatrack-11-to-12.patch",
 *       "patch_sha256": "…64 hex…",
 *       "patch_size_bytes": 820000
 *     }
 *   ],
 *   "notes": "Perbaikan parser DANA",
 *   "mandatory": false
 * }
 * ```
 */
data class UpdateManifest(
    val versionCode: Int,
    val versionName: String,
    val apkUrl: String,
    val apkSha256: String?,
    val apkSizeBytes: Long?,
    val deltas: List<UpdateDelta>,
    val notes: String?,
    val mandatory: Boolean,
) {
    /** Patch yang cocok untuk perangkat yang sedang memakai [baseVersionCode]. */
    fun deltaFor(baseVersionCode: Int): UpdateDelta? =
        deltas.firstOrNull { it.baseVersionCode == baseVersionCode }

    fun toMap(): Map<String, Any?> = mapOf(
        "versionCode" to versionCode,
        "versionName" to versionName,
        "apkSizeBytes" to apkSizeBytes,
        "notes" to notes,
        "mandatory" to mandatory,
    )

    companion object {
        /**
         * Mengembalikan `null` bila JSON tidak lengkap atau URL bukan HTTPS.
         * APK hanya boleh diunduh lewat kanal terenkripsi, karena berkas inilah
         * yang nantinya dipasang sebagai aplikasi.
         */
        fun parse(json: String): UpdateManifest? = try {
            val o = JSONObject(json)
            val versionCode = o.optInt("version_code")
            val apkUrl = o.optString("apk_url")
            when {
                versionCode <= 0 -> null
                !apkUrl.startsWith("https://") -> null
                else -> UpdateManifest(
                    versionCode = versionCode,
                    versionName = o.optString("version_name").ifBlank { versionCode.toString() },
                    apkUrl = apkUrl,
                    apkSha256 = o.optString("apk_sha256").takeIf { it.length == 64 },
                    apkSizeBytes = o.optLong("apk_size_bytes").takeIf { it > 0 },
                    deltas = parseDeltas(o),
                    notes = if (o.isNull("notes")) null else o.optString("notes").ifBlank { null },
                    mandatory = o.optBoolean("mandatory", false),
                )
            }
        } catch (e: Exception) {
            null
        }

        private fun parseDeltas(o: JSONObject): List<UpdateDelta> {
            val array = o.optJSONArray("deltas") ?: return emptyList()
            return buildList {
                for (i in 0 until array.length()) {
                    val d = array.optJSONObject(i) ?: continue
                    val base = d.optInt("base_version_code")
                    val url = d.optString("patch_url")
                    val sha = d.optString("patch_sha256")
                    val size = d.optLong("patch_size_bytes")
                    if (base > 0 && url.startsWith("https://") && sha.length == 64 && size > 0) {
                        add(UpdateDelta(base, url, sha, size))
                    }
                }
            }
        }
    }
}
