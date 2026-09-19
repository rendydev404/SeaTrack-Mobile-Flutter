import com.google.archivepatcher.generator.FileByFileV1DeltaGenerator;
import com.google.archivepatcher.shared.DefaultDeflater;
import com.google.archivepatcher.shared.IDeflater;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.function.BiFunction;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;

/**
 * Membuat patch File-by-File v1 antara dua APK, dimampatkan deflate mentah.
 *
 * Pasangan dari ApkDeltaApplier.kt di aplikasi: keduanya harus memakai deflate
 * tanpa header zlib (nowrap = true), kalau tidak patch gagal dibaca perangkat.
 *
 * Dijalankan langsung dari sumber, tanpa perlu dikompilasi lebih dulu:
 * <pre>
 *   java -cp archive-patcher-3.0.0.jar tools/DeltaGen.java lama.apk baru.apk keluaran.patch
 * </pre>
 */
public final class DeltaGen {

    private static final int BUFFER = 32 * 1024;

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            System.err.println("Pemakaian: DeltaGen <apk-lama> <apk-baru> <patch-keluaran>");
            System.exit(2);
        }
        File oldApk = new File(args[0]);
        File newApk = new File(args[1]);
        File output = new File(args[2]);

        if (!oldApk.isFile()) throw new IllegalArgumentException("APK lama tidak ada: " + oldApk);
        if (!newApk.isFile()) throw new IllegalArgumentException("APK baru tidak ada: " + newApk);

        File parent = output.getAbsoluteFile().getParentFile();
        if (parent != null) parent.mkdirs();

        BiFunction<Integer, Boolean, IDeflater> deflaterFactory = DefaultDeflater::new;
        Deflater deflater = new Deflater(Deflater.BEST_COMPRESSION, true);
        try (OutputStream file = new BufferedOutputStream(new FileOutputStream(output), BUFFER);
             DeflaterOutputStream compressed = new DeflaterOutputStream(file, deflater, BUFFER)) {
            new FileByFileV1DeltaGenerator(deflaterFactory).generateDelta(oldApk, newApk, compressed);
            compressed.finish();
        } finally {
            deflater.end();
        }

        System.out.printf(
            "patch %s -> %s : %,d byte (%.1f%% dari APK penuh)%n",
            oldApk.getName(), newApk.getName(), output.length(),
            output.length() * 100.0 / newApk.length());
    }

    private DeltaGen() {}
}
