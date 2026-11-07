import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';

import 'update_config.dart';
import 'update_dialog.dart';
import 'update_service.dart';

/// Checks the GitHub releases of the unofficial build once per launch (and at
/// most once per [kYunshangCheckInterval]) and offers to update.
class YunshangUpdater {
  static bool _checking = false;

  static Future<void> maybeCheckOnLaunch(BuildContext context) async {
    if (!Platform.isAndroid || _checking) {
      return;
    }

    _checking = true;
    try {
      final enabled = Store.get(StoreKey.yunshangCheckUpdates, true);
      if (!enabled) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final lastCheck = Store.tryGet(StoreKey.yunshangLastCheck) ?? 0;
      if (lastCheck > 0 && now - lastCheck < kYunshangCheckInterval.inSeconds) {
        return;
      }

      final release = await YunshangUpdateService.fetchLatest();
      if (release == null) {
        return;
      }

      await Store.put(StoreKey.yunshangLastCheck, now);

      final abi = await YunshangUpdateService.deviceAbi();
      final asset = release.assetForAbi(abi);
      // Split APKs get an ABI-specific versionCode from Flutter, so compare
      // against the asset that will actually be installed.
      final remoteCode = asset?.versionCode ?? release.versionCode;
      final currentCode = await YunshangUpdateService.currentVersionCode();
      if (remoteCode <= currentCode) {
        return;
      }

      final ignored = Store.tryGet(StoreKey.yunshangIgnoredVersion);
      if (ignored == release.tag) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      final autoDownload = Store.get(StoreKey.yunshangAutoDownload, false);
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => YunshangUpdateDialog(release: release, autoDownload: autoDownload),
      );
    } finally {
      _checking = false;
    }
  }
}
