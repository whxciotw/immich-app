import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:logging/logging.dart';
import 'package:immich_mobile/entities/store.entity.dart';

import 'update_config.dart';
import 'update_dialog.dart';
import 'update_service.dart';

enum UpdateCheckStatus { updateAvailable, upToDate, ignored, disabled, throttled, error, busy, notMounted }

/// Checks the GitHub releases of the unofficial build.
///
/// Automatic check: at most once per launch / [kYunshangCheckInterval].
/// Manual check ([checkNow]): bypasses the switch, the 24h throttle and the
/// per-version "ignore" record.
class YunshangUpdater {
  static final _log = Logger('YunshangUpdater');
  static bool _checking = false;
  static DateTime? _lastAutoCheckAt;

  static bool get isChecking => _checking;

  static Future<UpdateCheckStatus> checkForUpdates(BuildContext context, {bool manual = false}) async {
    if (!Platform.isAndroid) {
      return UpdateCheckStatus.error;
    }
    if (_checking) {
      return UpdateCheckStatus.busy;
    }

    _checking = true;
    try {
      _log.info(
        'Update check started (manual=$manual, testChannel=$kYunshangTestChannel, '
        'switch=${Store.get(StoreKey.yunshangCheckUpdates, true)}, '
        'autoDownload=${Store.get(StoreKey.yunshangAutoDownload, false)})',
      );
      if (!manual && !Store.get(StoreKey.yunshangCheckUpdates, true)) {
        _log.info('Automatic update check skipped: switch is off');
        return UpdateCheckStatus.disabled;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (!manual) {
        // Automatic checks run on every cold start (and on resume after a long
        // background period). Only de-dupe very rapid repeats from activity
        // recreation; do not apply the old 24h throttle here.
        final lastAutoCheck = _lastAutoCheckAt;
        if (lastAutoCheck != null && DateTime.now().difference(lastAutoCheck) < const Duration(minutes: 2)) {
          _log.info('Automatic update check skipped: de-duped within 2 minutes');
          return UpdateCheckStatus.throttled;
        }
        _lastAutoCheckAt = DateTime.now();
      }

      final fetched = await YunshangUpdateService.fetchLatest();
      final release = fetched.release;
      if (release == null) {
        _log.warning('Update check failed: ${fetched.error}');
        return UpdateCheckStatus.error;
      }
      _log.info('GitHub latest: ${release.tag} (${release.versionName}), versionCode=${release.versionCode}');

      await Store.put(StoreKey.yunshangLastCheck, now);

      final abi = await YunshangUpdateService.deviceAbi();
      final asset = release.assetForAbi(abi);
      // Split APKs get an ABI-specific versionCode from Flutter, so compare
      // against the asset that will actually be installed.
      final remoteCode = asset?.versionCode ?? release.versionCode;
      final currentCode = await YunshangUpdateService.currentVersionCode();
      final currentName = await YunshangUpdateService.currentVersionName();
      _log.info(
        'Version compare: current=$currentName ($currentCode), '
        'remote=${release.versionName} ($remoteCode), abi=$abi',
      );
      if (remoteCode <= currentCode) {
        _log.info('Update check result: already up to date');
        return UpdateCheckStatus.upToDate;
      }

      final ignored = Store.tryGet(StoreKey.yunshangIgnoredVersion);
      if (!manual && ignored == release.tag) {
        _log.info('Update check skipped: version ${release.tag} is ignored');
        return UpdateCheckStatus.ignored;
      }

      if (!context.mounted) {
        _log.warning('Update check aborted: dialog context is not mounted');
        return UpdateCheckStatus.notMounted;
      }

      final autoDownload = Store.get(StoreKey.yunshangAutoDownload, false);
      _log.info('Showing update dialog for ${release.tag} (autoDownload=$autoDownload)');
      try {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (_) => YunshangUpdateDialog(release: release, autoDownload: autoDownload),
        );
      } catch (error, stack) {
        _log.severe('Failed to show update dialog: $error', error, stack);
        return UpdateCheckStatus.error;
      }
      _log.info('Update dialog closed for ${release.tag}');
      return UpdateCheckStatus.updateAvailable;
    } finally {
      _checking = false;
    }
  }

  /// Silent check used when the app starts.
  static Future<void> maybeCheckOnLaunch(BuildContext context) async {
    await checkForUpdates(context);
  }

  /// Explicit "check now" from Settings: ignores the automatic-check switch,
  /// the throttle and the ignored-version record.
  static Future<UpdateCheckStatus> checkNow(BuildContext context) {
    return checkForUpdates(context, manual: true);
  }
}
