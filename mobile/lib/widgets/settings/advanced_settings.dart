import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/services/log.service.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/infrastructure/readonly_mode.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/repositories/permission.repository.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/utils/bytes_units.dart';
import 'package:immich_mobile/utils/hooks/app_settings_update_hook.dart';
import 'package:immich_mobile/widgets/settings/custom_proxy_headers_settings/custom_proxy_headers_settings.dart';
import 'package:immich_mobile/widgets/settings/ssl_client_cert_settings.dart';
import 'package:immich_ui/immich_ui.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:immich_mobile/yunshang/updater/yunshang_updater.dart';

class AdvancedSettings extends HookConsumerWidget {
  const AdvancedSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advancedTroubleshooting = useAppSettingsState(AppSettingsEnum.advancedTroubleshooting);
    final manageLocalMediaAndroid = useAppSettingsState(AppSettingsEnum.manageLocalMediaAndroid);
    final isManageMediaSupported = useState(false);
    final manageMediaAndroidPermission = useState(false);
    final levelId = useState<int>(ref.watch(appConfigProvider).logLevel.index);
    final preferRemote = useState(ref.watch(appConfigProvider).image.preferRemote);
    useValueChanged(
      preferRemote.value,
      (_, _) => unawaited(ref.read(settingsProvider).write(.imagePreferRemote, preferRemote.value)),
    );
    final readonlyModeEnabled = useAppSettingsState(AppSettingsEnum.readonlyModeEnabled);
    final yunshangCheckUpdates = useAppSettingsState(AppSettingsEnum.yunshangCheckUpdates);
    final yunshangAutoDownload = useAppSettingsState(AppSettingsEnum.yunshangAutoDownload);
    final currentAppVersion = useState<String>('…');
    final checkingUpdate = useState(false);

    useEffect(() {
      var cancelled = false;
      PackageInfo.fromPlatform().then((info) {
        if (!cancelled) {
          currentAppVersion.value = info.version;
        }
      });
      return () => cancelled = true;
    }, const []);

    Future<void> checkNow() async {
      if (checkingUpdate.value) {
        return;
      }
      checkingUpdate.value = true;
      final status = await YunshangUpdater.checkNow(context);
      checkingUpdate.value = false;
      if (!context.mounted) {
        return;
      }
      switch (status) {
        case UpdateCheckStatus.upToDate:
          context.scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('已是最新版本（${currentAppVersion.value}）')),
          );
          break;
        case UpdateCheckStatus.error:
          context.scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('检查更新失败，请检查网络后重试')),
          );
          break;
        case UpdateCheckStatus.busy:
          context.scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('正在检查更新，请稍候…')),
          );
          break;
        default:
          break;
      }
    }

    final logLevel = Level.LEVELS[levelId.value].name;

    useValueChanged(
      levelId.value,
      (_, _) => unawaited(LogService.I.setLogLevel(Level.LEVELS[levelId.value].toLogLevel())),
    );

    Future<bool> checkAndroidVersion() async {
      if (Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        final int sdkVersion = androidInfo.version.sdkInt;
        return sdkVersion >= 31;
      }
      return false;
    }

    useEffect(() {
      unawaited(() async {
        isManageMediaSupported.value = await checkAndroidVersion();
        if (isManageMediaSupported.value && context.mounted) {
          manageMediaAndroidPermission.value = await ref.read(permissionRepositoryProvider).hasManageMediaPermission();
        }
      }());
      return null;
    }, []);

    final advancedSettings = [
      SettingsSwitchListTile(
        enabled: true,
        valueNotifier: advancedTroubleshooting,
        title: context.t.advanced_settings_troubleshooting_title,
        subtitle: context.t.advanced_settings_troubleshooting_subtitle,
      ),
      if (isManageMediaSupported.value)
        Column(
          children: [
            SettingsSwitchListTile(
              enabled: true,
              valueNotifier: manageLocalMediaAndroid,
              title: context.t.advanced_settings_sync_remote_deletions_title,
              subtitle: context.t.advanced_settings_sync_remote_deletions_subtitle,
              onChanged: (value) async {
                if (value) {
                  final result = await ref.read(permissionRepositoryProvider).requestManageMediaPermission();
                  manageLocalMediaAndroid.value = result;
                  manageMediaAndroidPermission.value = result;
                }
              },
            ),
            SettingsActionTile(
              title: context.t.manage_media_access_title,
              statusText: manageMediaAndroidPermission.value ? context.t.allowed : context.t.not_allowed,
              subtitle: context.t.manage_media_access_rationale,
              statusColor: manageLocalMediaAndroid.value && !manageMediaAndroidPermission.value
                  ? const Color.fromARGB(255, 243, 188, 106)
                  : null,
              onActionTap: () async {
                final result = await ref.read(permissionRepositoryProvider).manageMediaPermission();
                manageMediaAndroidPermission.value = result;
              },
            ),
          ],
        ),
      SettingsSliderListTile(
        text: context.t.advanced_settings_log_level_title(level: logLevel),
        valueNotifier: levelId,
        maxValue: 8,
        minValue: 1,
        noDivisons: 7,
        label: logLevel,
      ),
      SettingsSwitchListTile(
        valueNotifier: preferRemote,
        title: context.t.advanced_settings_prefer_remote_title,
        subtitle: context.t.advanced_settings_prefer_remote_subtitle,
      ),
      SettingsSwitchListTile(
        enabled: true,
        valueNotifier: yunshangCheckUpdates,
        title: '启动时检查更新',
        subtitle: '检查 GitHub 上 yunshang 版本的新安装包',
      ),
      SettingsSwitchListTile(
        enabled: true,
        valueNotifier: yunshangAutoDownload,
        title: '自动下载更新包',
        subtitle: '发现新版本后自动下载；安装仍需在系统界面确认',
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: const Icon(Icons.refresh),
        title: const Text('立即检查更新'),
        subtitle: Text('当前版本 ${currentAppVersion.value}'),
        trailing: checkingUpdate.value
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        onTap: checkingUpdate.value ? null : checkNow,
      ),
      const CustomProxyHeaderSettings(),
      const SslClientCertSettings(),
      SettingsSwitchListTile(
        valueNotifier: readonlyModeEnabled,
        title: context.t.advanced_settings_readonly_mode_title,
        subtitle: context.t.advanced_settings_readonly_mode_subtitle,
        onChanged: (value) {
          readonlyModeEnabled.value = value;
          ref.read(readonlyModeProvider.notifier).setReadonlyMode(value);
          context.scaffoldMessenger.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(
                value ? context.t.readonly_mode_enabled : context.t.readonly_mode_disabled,
                style: context.textTheme.bodyLarge?.copyWith(color: context.primaryColor),
              ),
            ),
          );
        },
      ),
      ListTile(
        title: Text(context.t.advanced_settings_clear_image_cache, style: const TextStyle(fontWeight: FontWeight.w500)),
        leading: const Icon(Icons.playlist_remove_rounded),
        onTap: () async {
          final int clearedBytes;
          try {
            clearedBytes = await remoteImageApi.clearCache();
          } catch (e) {
            if (!context.mounted) {
              return;
            }

            context.scaffoldMessenger.showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(
                  context.t.advanced_settings_clear_image_cache_error,
                  style: context.textTheme.bodyLarge?.copyWith(color: context.themeData.colorScheme.error),
                ),
              ),
            );
            return;
          }

          if (clearedBytes < 0 || !context.mounted) {
            return;
          }

          // iOS always returns a small non-zero value
          final clearedMB = clearedBytes < (256 * 1024) ? "0 MiB" : formatHumanReadableBytes(clearedBytes, 2);
          context.scaffoldMessenger.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(
                context.t.advanced_settings_clear_image_cache_success(size: clearedMB),
                style: context.textTheme.bodyLarge?.copyWith(color: context.primaryColor),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 60),
    ];

    return SettingsSubPageScaffold(settings: advancedSettings);
  }
}
