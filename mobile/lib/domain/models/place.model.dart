/// One row of the "Places" aggregation: a city the user has assets in,
/// together with the administrative hierarchy reported by Immich's reverse
/// geocoder and a representative thumbnail asset for that city.
class PlaceEntry {
  const PlaceEntry({
    required this.country,
    required this.state,
    required this.city,
    required this.thumbnailAssetId,
    required this.assetCount,
  });

  /// Country name from EXIF (may be null if geocoding failed).
  final String? country;

  /// Province / admin1 name from EXIF (may be null).
  final String? state;

  /// Raw city value as stored in EXIF. This is what the timeline filter uses,
  /// so it must be passed unchanged to [PlaceDetailRoute].
  final String city;

  /// Asset id used for the city thumbnail.
  final String thumbnailAssetId;

  /// Number of assets in this city.
  final int assetCount;
}
