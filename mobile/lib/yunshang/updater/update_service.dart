import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_config.dart';
import 'update_models.dart';

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

class YunshangUpdateService {
  static final http.Client _client = http.Client();
  static const MethodChannel _channel = MethodChannel(kYunshangInstallerChannel);

  static Future<YunshangRelease?> fetchLatest() async {
    try {
      final response = await _client
          .get(
            Uri.parse(kYunshangLatestJsonUrl),
            headers: const {'Accept': 'application/json', 'User-Agent': kYunshangUpdateUserAgent},
          )
          .timeout(kYunshangHttpTimeout);
      if (response.statusCode != 200) {
        return null;
      }
      return YunshangRelease.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {
      // Update checks are best effort: no network / rate limit / bad JSON are
      // all handled by silently skipping the check.
      return null;
    }
  }

  static Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<String?> deviceAbi() async {
    try {
      return await _channel.invokeMethod<String>('getAbi');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } catch (_) {}
  }

  static Future<void> install(File apk) async {
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }

  static Future<File?> download(
    YunshangRelease release,
    YunshangReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = kYunshangHttpTimeout;
    File? target;
    try {
      final request = await client.getUrl(Uri.parse(asset.url));
      request.headers.set(HttpHeaders.userAgentHeader, kYunshangUpdateUserAgent);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final directory = await getTemporaryDirectory();
      target = File('${directory.path}/yunshang-update-${release.versionCode}.apk');
      if (await target.exists()) {
        await target.delete();
      }

      final sink = target.openWrite();
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      var received = 0;
      final total = response.contentLength;

      await for (final chunk in response) {
        received += chunk.length;
        hasher.add(chunk);
        sink.add(chunk);
        onProgress(received, total);
      }

      await sink.flush();
      await sink.close();
      hasher.close();

      final digest = digestSink.value?.toString().toLowerCase();
      if (digest != asset.sha256) {
        await target.delete();
        target = null;
        return null;
      }
      return target;
    } catch (_) {
      if (target != null && await target.exists()) {
        await target.delete();
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
