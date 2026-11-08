import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'update_models.dart';
import 'update_service.dart';

enum _UpdatePhase { prompt, downloading, ready, error }

class YunshangUpdateDialog extends StatefulWidget {
  const YunshangUpdateDialog({super.key, required this.release, required this.autoDownload});

  final YunshangRelease release;
  final bool autoDownload;

  @override
  State<YunshangUpdateDialog> createState() => _YunshangUpdateDialogState();
}

class _YunshangUpdateDialogState extends State<YunshangUpdateDialog> with WidgetsBindingObserver {
  _UpdatePhase _phase = _UpdatePhase.prompt;
  double _progress = 0;
  String _message = '';
  String _currentVersion = '';
  File? _apk;
  bool _canInstall = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadCurrentVersion());
    if (widget.autoDownload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_downloadAndInstall());
        }
      });
    }
  }

  Future<void> _loadCurrentVersion() async {
    final version = await YunshangUpdateService.currentVersionName();
    if (mounted) {
      setState(() => _currentVersion = version);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _phase != _UpdatePhase.ready || _apk == null) {
      return;
    }
    unawaited(_recheckInstallPermission());
  }

  Future<void> _recheckInstallPermission() async {
    final canInstall = await YunshangUpdateService.canInstallPackages();
    if (!mounted) {
      return;
    }
    if (canInstall && !_canInstall) {
      setState(() {
        _canInstall = true;
      });
      await _install();
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_phase == _UpdatePhase.downloading) {
      return;
    }

    final abi = await YunshangUpdateService.deviceAbi();
    final asset = widget.release.assetForAbi(abi);
    if (asset == null) {
      if (mounted) {
        setState(() {
          _phase = _UpdatePhase.error;
          _message = '找不到适合本机的安装包，请到 Release 页面手动下载。';
        });
      }
      return;
    }

    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
      _message = '正在下载 ${widget.release.versionName}…';
    });

    final apk = await YunshangUpdateService.download(
      widget.release,
      asset,
      onProgress: (received, total) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = total > 0 ? received / total : 0;
          _message = '正在下载 ${widget.release.versionName}…'
              '${total > 0 ? ' ${(received / 1024 / 1024).toStringAsFixed(1)} / ${(total / 1024 / 1024).toStringAsFixed(1)} MB' : ''}';
        });
      },
    );

    if (!mounted) {
      return;
    }

    if (apk == null) {
      setState(() {
        _phase = _UpdatePhase.error;
        _message = '下载失败或校验不通过，请稍后重试，或到 Release 页面手动下载。';
      });
      return;
    }

    _apk = apk;

    final canInstall = await YunshangUpdateService.canInstallPackages();
    if (!mounted) {
      return;
    }
    _canInstall = canInstall;
    if (!canInstall) {
      setState(() {
        _phase = _UpdatePhase.ready;
        _message = '需要允许本应用“安装未知应用”，然后才能完成更新。';
      });
      return;
    }

    await _install();
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) {
      return;
    }

    setState(() {
      _phase = _UpdatePhase.ready;
      _message = '下载完成，正在打开系统安装器…';
    });

    try {
      await YunshangUpdateService.install(apk);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _UpdatePhase.error;
          _message = '无法打开安装器：$error';
        });
      }
    }
  }

  Future<void> _openInstallSettings() async {
    await YunshangUpdateService.openInstallSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _message = '已打开系统设置，允许后返回本页会自动继续安装。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDownloading = _phase == _UpdatePhase.downloading;
    final isReady = _phase == _UpdatePhase.ready;
    final canRetry = _phase == _UpdatePhase.prompt || _phase == _UpdatePhase.error;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '发现新版本',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!isDownloading)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '新版本',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      release.versionName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '当前版本 ${_currentVersion.isEmpty ? '…' : _currentVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _phase == _UpdatePhase.error ? colorScheme.error : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 8),
                Text(
                  _progress > 0 ? '${(_progress * 100).toStringAsFixed(0)}%' : '准备下载…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ] else if (canRetry) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _downloadAndInstall,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_phase == _UpdatePhase.error ? '重试更新' : '立即更新'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('以后再说'),
                      ),
                    ),
                    Container(width: 1, height: 14, color: colorScheme.outlineVariant),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          unawaited(Store.put(StoreKey.yunshangIgnoredVersion, release.tag));
                          Navigator.of(context).pop();
                        },
                        child: const Text('忽略此版本'),
                      ),
                    ),
                  ],
                ),
              ] else if (isReady) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _canInstall ? _install : _openInstallSettings,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_canInstall ? '继续安装' : '去允许安装'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('以后再说'),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: release.notesUrl.isEmpty
                    ? null
                    : () => launchUrlString(release.notesUrl, mode: LaunchMode.externalApplication),
                child: const Text('更新说明'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
