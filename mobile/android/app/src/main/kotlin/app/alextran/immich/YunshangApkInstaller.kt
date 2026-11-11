package app.alextran.immich

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native helpers for the in-app updater of the unofficial yunshang build:
 * ABI detection, "install unknown apps" state, and opening the system package
 * installer with a FileProvider content URI.
 */
class YunshangApkInstaller(private val activity: Activity) {
  companion object {
    private const val CHANNEL = "app.alextran.immich/yunshang_installer"
    private const val AUTHORITY_SUFFIX = ".fileprovider"
  }

  fun register(messenger: BinaryMessenger) {
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "getAbi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")

          "canRequestPackageInstalls" ->
            result.success(
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.packageManager.canRequestPackageInstalls()
              } else {
                true
              },
            )

          "openInstallSettings" -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
              val intent =
                Intent(
                  Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                  Uri.parse("package:${activity.packageName}"),
                )
              activity.startActivity(intent)
            }
            result.success(null)
          }

          "installApk" -> {
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
              result.error("bad_args", "Missing APK path", null)
              return@setMethodCallHandler
            }

            val file = File(path)
            if (!file.exists()) {
              result.error("missing_file", "APK not found: $path", null)
              return@setMethodCallHandler
            }

            val uri =
              FileProvider.getUriForFile(
                activity,
                activity.packageName + AUTHORITY_SUFFIX,
                file,
              )
            val intent =
              Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = uri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
              }
            activity.startActivity(intent)
            result.success(null)
          }

          else -> result.notImplemented()
        }
      } catch (error: Exception) {
        result.error("installer_error", error.message, null)
      }
    }
  }
}
