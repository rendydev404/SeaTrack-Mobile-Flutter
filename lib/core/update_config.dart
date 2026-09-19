/// URL berkas JSON yang berisi versi terbaru aplikasi.
///
/// Nilai bawaan menunjuk ke aset rilis terbaru di GitHub. URL itu tetap,
/// GitHub sendiri yang mengalihkannya ke rilis paling baru, dan berkasnya
/// diterbitkan otomatis oleh `.github/workflows/release.yml` setiap kali
/// cabang `main` diperbarui.
///
/// Bisa ditimpa saat build, misalnya untuk menguji dari server lain:
/// ```
/// flutter build apk --release --dart-define=SEATRACK_UPDATE_URL=https://contoh.com/update.json
/// ```
///
/// Kosongkan [_fallback] dan jangan pakai --dart-define bila fitur pembaruan
/// ingin dimatikan total: tidak ada permintaan jaringan dan menunya tersembunyi.
const String _fallback =
    'https://github.com/rendydev404/SeaTrack-Mobile-Flutter/releases/latest/download/update.json';

const String kUpdateManifestUrl = String.fromEnvironment(
  'SEATRACK_UPDATE_URL',
  defaultValue: _fallback,
);
