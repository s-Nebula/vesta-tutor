package org.vestaopensource.tutor.update

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.vestaopensource.tutor.BuildConfig
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Self-updater of the APK distributed from vestasecurity.date ("web" flavour
 * only; the Google Play build has none of this code).
 *
 * It reads version.json, downloads the new APK, checks its SHA-256 and that
 * it is signed with the same key as the installed app, and installs it with
 * PackageInstaller. On Android 12+ the update goes in without a tap once the
 * user has allowed "install unknown apps" for this app; otherwise Android
 * shows its confirmation, from the app or from a notification.
 *
 * version.json:
 * { "<applicationId>": { "versionCode": 11, "versionName": "1.1.1",
 *     "url": "https://vestasecurity.date/downloads/…apk", "sha256": "…",
 *     "minVersionCode": 0, "notes": { "es": "…", "en": "…" } } }
 */
object Updater {
    private const val TAG = "VestaUpdater"
    private const val PREFS = "vesta_updater"
    private const val CHANNEL_ID = "vesta_updates"
    private const val NOTIFICATION_ID = 7401
    const val JOB_ID = 7400
    private const val PERIOD_MS = 6L * 60 * 60 * 1000

    private val running = AtomicBoolean(false)

    /** Activity in the foreground, to show Android's confirmation directly. */
    @Volatile
    var foregroundActivity: android.app.Activity? = null

    // ---------------------------------------------------------------- texts

    private fun isSpanish(context: Context): Boolean {
        val saved = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.app_language", null)
        return when (saved) {
            "es" -> true
            "en" -> false
            else -> Locale.getDefault().language == "es"
        }
    }

    private fun t(context: Context, es: String, en: String) =
        if (isSpanish(context)) es else en

    // ------------------------------------------------------------- schedule

    /** Periodic check every 6 h on an unmetered network. Idempotent. */
    fun schedule(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        if (scheduler.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, UpdateJobService::class.java))
            .setPeriodic(PERIOD_MS)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_UNMETERED)
            .setPersisted(true)
            .build()
        try {
            scheduler.schedule(job)
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo programar la comprobación", e)
        }
    }

    // ---------------------------------------------------------------- state

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun installedInfo(context: Context): PackageInfo =
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(
                context.packageName, PackageManager.PackageInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)
        }

    @Suppress("DEPRECATION")
    private fun versionCodeOf(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()

    /** Silent updates are possible on Android 12+ (once installs are allowed). */
    fun silentSupported(): Boolean = Build.VERSION.SDK_INT >= 31

    fun status(context: Context): Map<String, Any?> {
        val info = installedInfo(context)
        val current = versionCodeOf(info)
        val p = prefs(context)
        val availableCode = p.getLong("availableCode", 0)
        val available = availableCode > current
        return mapOf(
            "supported" to true,
            "currentVersionName" to info.versionName,
            "currentVersionCode" to current,
            "canInstall" to canInstall(context),
            "silent" to silentSupported(),
            "available" to available,
            "availableVersionName" to if (available) p.getString("availableName", null) else null,
            "mandatory" to (available && current < p.getLong("minVersionCode", 0)),
            "notes" to if (available) p.getString("notes", null) else null,
            "lastCheck" to p.getLong("lastCheck", 0),
            "lastError" to p.getString("lastError", null),
        )
    }

    fun openInstallSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= 26) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}")
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    // ---------------------------------------------------------------- check

    /**
     * Checks, downloads and installs. Blocking: call from a worker thread.
     * [manual]: the user asked for it (also on mobile data).
     */
    fun run(context: Context, manual: Boolean) {
        if (!running.compareAndSet(false, true)) return
        val app = context.applicationContext
        try {
            runInternal(app)
            prefs(app).edit().remove("lastError").apply()
        } catch (e: Exception) {
            Log.w(TAG, "Fallo al actualizar", e)
            prefs(app).edit().putString("lastError", e.message ?: e.javaClass.simpleName).apply()
        } finally {
            prefs(app).edit().putLong("lastCheck", System.currentTimeMillis()).apply()
            running.set(false)
        }
    }

    private fun runInternal(context: Context) {
        val manifestUrl = URL(BuildConfig.UPDATE_MANIFEST_URL)
        val json = JSONObject(httpGetText(manifestUrl))
        val entry = json.optJSONObject(context.packageName) ?: return

        val code = entry.getLong("versionCode")
        val name = entry.optString("versionName", code.toString())
        val minCode = entry.optLong("minVersionCode", 0)
        val sha256 = entry.getString("sha256").lowercase(Locale.ROOT)
        val apkUrl = URL(entry.getString("url"))
        val notes = entry.optJSONObject("notes")
            ?.optString(if (isSpanish(context)) "es" else "en")
            ?.takeIf { it.isNotBlank() }

        // The APK must come from the same HTTPS host as version.json.
        require(apkUrl.protocol == "https" && apkUrl.host == manifestUrl.host) {
            "URL de la APK no permitida"
        }
        require(Regex("^[0-9a-f]{64}$").matches(sha256)) { "SHA-256 no válido" }

        prefs(context).edit()
            .putLong("availableCode", code)
            .putString("availableName", name)
            .putLong("minVersionCode", minCode)
            .putString("notes", notes)
            .apply()

        val current = versionCodeOf(installedInfo(context))
        if (code <= current) {
            cleanDownloads(context)
            return
        }

        val apk = download(context, apkUrl, code, sha256)
        verifyApk(context, apk, code)

        if (!canInstall(context)) {
            notify(
                context,
                t(context, "Hay una actualización de Vesta ($name)", "A Vesta update is available ($name)"),
                t(
                    context,
                    "Toca para permitir que Vesta instale sus actualizaciones.",
                    "Tap to allow Vesta to install its updates."
                ),
                openInstallSettingsIntent(context),
            )
            return
        }

        install(context, apk)
    }

    // ------------------------------------------------------------- download

    private fun open(url: URL): HttpURLConnection {
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 20_000
        conn.readTimeout = 60_000
        conn.instanceFollowRedirects = false
        conn.setRequestProperty("Cache-Control", "no-cache")
        if (conn.responseCode != 200) {
            conn.disconnect()
            throw IllegalStateException("HTTP ${conn.responseCode} en ${url.path}")
        }
        return conn
    }

    private fun httpGetText(url: URL): String {
        val conn = open(url)
        try {
            return conn.inputStream.use { it.readBytes() }.toString(Charsets.UTF_8)
        } finally {
            conn.disconnect()
        }
    }

    private fun updatesDir(context: Context) =
        File(context.filesDir, "updates").apply { mkdirs() }

    fun cleanDownloads(context: Context) {
        updatesDir(context).listFiles()?.forEach { it.delete() }
    }

    private fun sha256Of(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun download(context: Context, url: URL, code: Long, sha256: String): File {
        val dir = updatesDir(context)
        val target = File(dir, "$code.apk")
        if (target.exists() && sha256Of(target) == sha256) return target

        dir.listFiles()?.forEach { it.delete() }
        val part = File(dir, "$code.apk.part")
        val conn = open(url)
        try {
            conn.inputStream.use { input ->
                part.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
            }
        } finally {
            conn.disconnect()
        }

        if (sha256Of(part) != sha256) {
            part.delete()
            throw SecurityException("La APK descargada no coincide con su SHA-256")
        }
        if (!part.renameTo(target)) throw IllegalStateException("No se pudo guardar la APK")
        return target
    }

    // --------------------------------------------------------------- verify

    @Suppress("DEPRECATION")
    private fun signaturesOf(info: PackageInfo?): Set<String> {
        if (info == null) return emptySet()
        val sigs = if (Build.VERSION.SDK_INT >= 28) {
            val signing = info.signingInfo ?: return emptySet()
            if (signing.hasMultipleSigners()) signing.apkContentsSigners
            else signing.signingCertificateHistory
        } else {
            info.signatures
        } ?: return emptySet()
        val md = MessageDigest.getInstance("SHA-256")
        return sigs.map { s -> md.digest(s.toByteArray()).joinToString("") { "%02x".format(it) } }
            .toSet()
    }

    @Suppress("DEPRECATION")
    private fun verifyApk(context: Context, apk: File, code: Long) {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
        else PackageManager.GET_SIGNATURES

        val archive = pm.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: throw SecurityException("La APK descargada no es válida")
        val installed = pm.getPackageInfo(context.packageName, flags)

        if (archive.packageName != context.packageName || versionCodeOf(archive) != code) {
            apk.delete()
            throw SecurityException("La APK descargada no corresponde a esta app")
        }
        // Android also rejects an update signed with another key; checking here
        // avoids downloading and offering it again and again.
        val installedSigs = signaturesOf(installed)
        if (installedSigs.isEmpty() || signaturesOf(archive).none { it in installedSigs }) {
            apk.delete()
            throw SecurityException("La APK descargada no está firmada con la clave de Vesta")
        }
    }

    // -------------------------------------------------------------- install

    private fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(context.packageName)
        params.setSize(apk.length())
        if (Build.VERSION.SDK_INT >= 31) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }

        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("vesta.apk", 0, apk.length()).use { output ->
                    input.copyTo(output, 64 * 1024)
                    session.fsync(output)
                }
            }
            val intent = Intent(context, InstallStatusReceiver::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
    }

    /** Android asks the user to confirm: from the app if open, else a notification. */
    fun onUserActionRequired(context: Context, confirm: Intent) {
        confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val activity = foregroundActivity
        if (activity != null) {
            try {
                activity.startActivity(confirm)
                return
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo abrir la confirmación", e)
            }
        }
        val name = prefs(context).getString("availableName", "") ?: ""
        notify(
            context,
            t(context, "Actualización de Vesta lista ($name)", "Vesta update ready ($name)"),
            t(context, "Toca para instalarla.", "Tap to install it."),
            PendingIntent.getActivity(
                context, 1, confirm,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ),
        )
    }

    fun onInstallFailed(context: Context, message: String?) {
        prefs(context).edit().putString("lastError", message ?: "Instalación fallida").apply()
    }

    // --------------------------------------------------------- notification

    private fun openInstallSettingsIntent(context: Context): PendingIntent {
        val intent = if (Build.VERSION.SDK_INT >= 26) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}")
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        return PendingIntent.getActivity(
            context, 2, intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun notify(context: Context, title: String, text: String, tap: PendingIntent) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    t(context, "Actualizaciones", "Updates"),
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID)
        else @Suppress("DEPRECATION") Notification.Builder(context)
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Sin permiso de notificaciones", e)
        }
    }

    fun clearNotification(context: Context) {
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }
}
