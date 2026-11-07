class YunshangReleaseAsset {
  const YunshangReleaseAsset({required this.url, required this.sha256, this.versionCode});

  final String url;
  final String sha256;

  /// Per-ABI version code. Flutter's `--split-per-abi` adds an ABI-specific
  /// offset to the version code, so the device's own build number must be
  /// compared against the matching asset rather than the universal build.
  final int? versionCode;

  static YunshangReleaseAsset? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final url = json['url']?.toString();
    final sha256 = json['sha256']?.toString().toLowerCase();
    if (url == null || sha256 == null || url.isEmpty || sha256.isEmpty) {
      return null;
    }
    return YunshangReleaseAsset(
      url: url,
      sha256: sha256,
      versionCode: int.tryParse(json['versionCode']?.toString() ?? ''),
    );
  }
}

class YunshangRelease {
  const YunshangRelease({
    required this.versionName,
    required this.versionCode,
    required this.tag,
    required this.notesUrl,
    required this.assets,
  });

  final String versionName;
  final int versionCode;
  final String tag;
  final String notesUrl;
  final Map<String, YunshangReleaseAsset> assets;

  static YunshangRelease? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }

    final versionCode = int.tryParse(json['versionCode']?.toString() ?? '');
    final tag = json['tag']?.toString();
    if (versionCode == null || tag == null || tag.isEmpty) {
      return null;
    }

    final assets = <String, YunshangReleaseAsset>{};
    final rawAssets = json['assets'];
    if (rawAssets is Map) {
      for (final entry in rawAssets.entries) {
        final asset = YunshangReleaseAsset.fromJson(entry.value);
        if (asset != null) {
          assets[entry.key.toString()] = asset;
        }
      }
    }

    return YunshangRelease(
      versionName: json['versionName']?.toString() ?? tag,
      versionCode: versionCode,
      tag: tag,
      notesUrl: json['notesUrl']?.toString() ?? '',
      assets: assets,
    );
  }

  /// Picks the APK matching the device's primary ABI, falling back to the
  /// universal build.
  YunshangReleaseAsset? assetForAbi(String? abi) {
    if (abi != null && assets.containsKey(abi)) {
      return assets[abi];
    }
    // Never cross-fallback to another ABI: a mismatched APK would fail to
    // install. Universal is the only safe fallback.
    return assets['universal'];
  }
}
