import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci penandatanganan rilis.
//
// Pembaruan mandiri hanya bisa terpasang bila APK baru ditandatangani kunci yang
// sama dengan yang sudah terpasang. Kunci debug dibuat ulang di tiap mesin dan
// tiap runner CI, jadi rilis wajib memakai keystore tetap.
//
// Lokal  : isi android/key.properties (tidak masuk git).
// CI     : isi variabel lingkungan SEATRACK_KEYSTORE dan kawan-kawan.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(propKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propKey) ?: System.getenv(envKey)

val releaseStorePath = signingValue("storeFile", "SEATRACK_KEYSTORE")
val releaseStorePassword = signingValue("storePassword", "SEATRACK_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "SEATRACK_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "SEATRACK_KEY_PASSWORD")
val hasReleaseSigning = releaseStorePath != null &&
    file(releaseStorePath).exists() &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null

android {
    namespace = "com.rendydev404.seatrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.rendydev404.seatrack"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Tanpa keystore rilis, build tetap jalan dengan kunci debug agar
            // `flutter run --release` bisa dipakai lokal. APK seperti itu tidak
            // boleh diterbitkan: perangkat menolak memasangnya sebagai pembaruan.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("SeaTrack: keystore rilis tidak ditemukan, memakai kunci debug.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider dan NotificationCompat untuk modul pembaruan mandiri.
    implementation("androidx.core:core-ktx:1.13.1")
    // Menyusun ulang APK dari delta patch File-by-File v1.
    implementation("com.eidu:archive-patcher:3.0.0")
}
