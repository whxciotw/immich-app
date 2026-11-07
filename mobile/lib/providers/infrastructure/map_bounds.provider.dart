import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Initial map view derived from the user's geotagged photos.
class LibraryMapView {
  const LibraryMapView({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

/// Computes a robust "where are my photos" view: the 5th-95th percentile
/// bounding box of geotagged assets, padded a bit, with a zoom that roughly
/// fits a phone-sized viewport.
///
/// Returns null when there are no geotagged assets.
LibraryMapView? computeLibraryMapView(List<({double latitude, double longitude})> locations) {
  if (locations.isEmpty) {
    return null;
  }

  final latitudes = locations.map((location) => location.latitude).toList()..sort();
  final longitudes = locations.map((location) => location.longitude).toList()..sort();

  final minLat = _percentile(latitudes, 0.05);
  final maxLat = _percentile(latitudes, 0.95);
  final minLon = _percentile(longitudes, 0.05);
  final maxLon = _percentile(longitudes, 0.95);

  final centerLat = ((minLat + maxLat) / 2).clamp(-85.0, 85.0).toDouble();
  final centerLon = (minLon + maxLon) / 2;

  final latSpan = (maxLat - minLat).abs();
  // Longitude degrees shrink with latitude; approximate with cos(lat).
  final lonSpan = (maxLon - minLon).abs() * cos(centerLat * pi / 180);
  final span = max(latSpan, lonSpan);

  // A single point / very tight cluster: show a city-level view.
  const double minSpan = 0.002;
  const double viewportFactor = 506; // 360px viewport * 360 / (256 * 1.0)
  final paddedSpan = max(span * 1.6, minSpan);
  final zoom = (log(viewportFactor / paddedSpan) / ln2).clamp(1.0, 14.0).toDouble();

  return LibraryMapView(center: LatLng(centerLat, centerLon), zoom: zoom);
}

double _percentile(List<double> sorted, double fraction) {
  if (sorted.isEmpty) {
    return 0;
  }
  final index = ((sorted.length - 1) * fraction).round().clamp(0, sorted.length - 1).toInt();
  return sorted[index];
}

final libraryMapViewProvider = FutureProvider<LibraryMapView?>((ref) async {
  final db = ref.watch(driftProvider);
  final locations = await db.remoteAssetRepository.getGeotaggedLocations();
  return computeLibraryMapView(locations);
});
