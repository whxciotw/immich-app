import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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

class _YunshangUpdateDialogState extends State<YunshangUpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.prompt;
  double _progress = 0;
  String _message = '';
  File? _apk;

  @override
  void initState() {
    super.initState();
    if (widget.autoDownload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_downloadAndInstall());
        }
      });
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
      _message = '已打开系统设置，允许后请回到这里完成安装。';
    });
    final canInstall = await YunshangUpdateService.canInstallPackages();
    if (canInstall && mounted) {
      unawaited(_install());
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('发现新版本'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新版本：${release.versionName}', style: theme.textTheme.bodyMedium),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_message, style: theme.textTheme.bodySmall),
            ],
            if (_phase == _UpdatePhase.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
          ],
        ),
      ),
      actions: [
        if (_phase != _UpdatePhase.downloading) ...[
          TextButton(
            onPressed: () {
              unawaited(Store.put(StoreKey.yunshangIgnoredVersion, release.tag));
              Navigator.of(context).pop();
            },
            child: const Text('忽略此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('以后再说'),
          ),
          if (_phase == _UpdatePhase.prompt || _phase == _UpdatePhase.error)
            FilledButton(
              onPressed: _downloadAndInstall,
              child: const Text('立即更新'),
            ),
          if (_phase == _UpdatePhase.ready)
            FilledButton(
              onPressed: _openInstallSettings,
              child: const Text('去允许安装'),
            ),
        ],
        TextButton(
          onPressed: release.notesUrl.isEmpty
              ? null
              : () => launchUrlString(release.notesUrl, mode: LaunchMode.externalApplication),
          child: const Text('更新说明'),
        ),
      ],
    );
  }

}
