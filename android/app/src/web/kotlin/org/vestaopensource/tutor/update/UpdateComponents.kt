package org.vestaopensource.tutor.update

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/** Periodic check (scheduled by [Updater.schedule]). */
class UpdateJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            Updater.run(applicationContext, manual = false)
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true
}

/** Result of the PackageInstaller session. */
class InstallStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) Updater.onUserActionRequired(context, confirm)
            }
            PackageInstaller.STATUS_SUCCESS -> Unit // The process is replaced.
            else -> Updater.onInstallFailed(
                context,
                intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
            )
        }
    }
}

/** After a reboot or an update: schedule the checks again and clean up. */
class UpdateBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Updater.cleanDownloads(context)
                Updater.clearNotification(context)
                Updater.schedule(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> Updater.schedule(context)
        }
    }
}
