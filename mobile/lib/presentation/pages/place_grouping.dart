import 'package:immich_mobile/domain/models/place.model.dart';

const String kUnknownCountry = '未知国家/地区';

/// Separator used by the yunshang geodata ("province · city", "country · city").
const String _separator = ' · ';

class PlaceCityNode {
  const PlaceCityNode({
    required this.key,
    required this.label,
    required this.rawCity,
    required this.thumbnailAssetId,
    required this.assetCount,
  });

  final String key;
  final String label;
  final String rawCity;
  final String thumbnailAssetId;
  final int assetCount;
}

class PlaceStateNode {
  const PlaceStateNode({required this.key, required this.label, required this.cities});

  final String key;
  final String label;
  final List<PlaceCityNode> cities;

  int get assetCount => cities.fold(0, (sum, city) => sum + city.assetCount);
  int get cityCount => cities.length;
}

class PlaceCountryNode {
  const PlaceCountryNode({
    required this.key,
    required this.label,
    required this.states,
    required this.directCities,
  });

  final String key;
  final String label;
  final List<PlaceStateNode> states;

  /// Cities without a province (municipalities, Hong Kong/Macau, some foreign
  /// countries) shown directly under the country.
  final List<PlaceCityNode> directCities;

  int get assetCount =>
      directCities.fold(0, (sum, city) => sum + city.assetCount) +
      states.fold(0, (sum, state) => sum + state.assetCount);

  int get cityCount => directCities.length + states.fold(0, (sum, state) => sum + state.cityCount);
}

sealed class PlaceListNode {
  const PlaceListNode();
}

final class PlaceCountryListNode extends PlaceListNode {
  const PlaceCountryListNode(this.country);

  final PlaceCountryNode country;
}

final class PlaceStateListNode extends PlaceListNode {
  const PlaceStateListNode(this.countryKey, this.state);

  final String countryKey;
  final PlaceStateNode state;
}

final class PlaceCityListNode extends PlaceListNode {
  const PlaceCityListNode(this.city, this.depth);

  final PlaceCityNode city;
  final int depth;
}

class _CountryBuilder {
  _CountryBuilder(this.label);

  final String label;
  final Map<String, _StateBuilder> states = {};
  final List<PlaceCityNode> directCities = [];
}

class _StateBuilder {
  _StateBuilder(this.label);

  final String label;
  final List<PlaceCityNode> cities = [];
}

/// Builds the country -> province -> city tree from the flat database rows.
///
/// The yunshang geodata writes the parent into the `city` column
/// ("云南 · 香格里拉市", "泰国 · 曼谷"), so the hierarchy is derived from the
/// `country` / `state` columns and, when missing, from that embedded prefix.
List<PlaceCountryNode> buildPlaceTree(List<PlaceEntry> entries) {
  final countries = <String, _CountryBuilder>{};

  for (final entry in entries) {
    final normalized = _normalize(entry);
    final country = countries.putIfAbsent(normalized.country, () => _CountryBuilder(normalized.country));

    final city = PlaceCityNode(
      key: '${normalized.country}|${normalized.state ?? ''}|${entry.city}',
      label: normalized.cityLabel,
      rawCity: entry.city,
      thumbnailAssetId: entry.thumbnailAssetId,
      assetCount: entry.assetCount,
    );

    final state = normalized.state;
    if (state == null) {
      country.directCities.add(city);
    } else {
      country.states.putIfAbsent(state, () => _StateBuilder(state)).cities.add(city);
    }
  }

  final result = countries.values.map((country) {
    final states = country.states.values.map((state) {
      final cities = [...state.cities]..sort((a, b) => _compareLabel(a.label, b.label));
      return PlaceStateNode(
        key: 's:${country.label}|${state.label}',
        label: state.label,
        cities: cities,
      );
    }).toList()
      ..sort((a, b) => _compareLabel(a.label, b.label));

    final directCities = [...country.directCities]..sort((a, b) => _compareLabel(a.label, b.label));

    return PlaceCountryNode(
      key: 'c:${country.label}',
      label: country.label,
      states: states,
      directCities: directCities,
    );
  }).toList()
    ..sort((a, b) => _compareLabel(a.label, b.label));

  return result;
}

Set<String> allPlaceGroupKeys(List<PlaceCountryNode> tree) {
  final keys = <String>{};
  for (final country in tree) {
    keys.add(country.key);
    for (final state in country.states) {
      keys.add(state.key);
    }
  }
  return keys;
}

List<PlaceListNode> flattenPlaceTree(List<PlaceCountryNode> tree, Set<String> expanded) {
  final nodes = <PlaceListNode>[];

  for (final country in tree) {
    nodes.add(PlaceCountryListNode(country));
    if (!expanded.contains(country.key)) {
      continue;
    }

    for (final state in country.states) {
      nodes.add(PlaceStateListNode(country.key, state));
      if (expanded.contains(state.key)) {
        for (final city in state.cities) {
          nodes.add(PlaceCityListNode(city, 2));
        }
      }
    }

    for (final city in country.directCities) {
      nodes.add(PlaceCityListNode(city, 1));
    }
  }

  return nodes;
}

/// Flat list used while the search field is active.
List<PlaceCityNode> searchPlaceCities(List<PlaceCountryNode> tree, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return _allCities(tree);
  }

  final matches = <PlaceCityNode>[];
  for (final country in tree) {
    final countryMatches = country.label.toLowerCase().contains(needle);
    for (final state in country.states) {
      final stateMatches = countryMatches || state.label.toLowerCase().contains(needle);
      for (final city in state.cities) {
        if (stateMatches || _cityMatches(city, needle)) {
          matches.add(city);
        }
      }
    }
    for (final city in country.directCities) {
      if (countryMatches || _cityMatches(city, needle)) {
        matches.add(city);
      }
    }
  }
  return matches;
}

List<PlaceCityNode> _allCities(List<PlaceCountryNode> tree) {
  final cities = <PlaceCityNode>[];
  for (final country in tree) {
    cities.addAll(country.directCities);
    for (final state in country.states) {
      cities.addAll(state.cities);
    }
  }
  return cities;
}

bool _cityMatches(PlaceCityNode city, String needle) {
  return city.label.toLowerCase().contains(needle) || city.rawCity.toLowerCase().contains(needle);
}

({String country, String? state, String cityLabel}) _normalize(PlaceEntry entry) {
  var country = (entry.country ?? '').trim();
  if (country.isEmpty) {
    country = kUnknownCountry;
  }

  var state = (entry.state ?? '').trim();
  String? normalizedState = state.isEmpty ? null : state;

  final rawCity = entry.city.trim();
  var cityLabel = rawCity;

  final separatorIndex = rawCity.indexOf(_separator);
  if (separatorIndex > 0) {
    final parent = rawCity.substring(0, separatorIndex).trim();
    final rest = rawCity.substring(separatorIndex + _separator.length).trim();
    if (rest.isNotEmpty) {
      cityLabel = rest;
      if (parent == country) {
        // Overseas style "country · city": there is no useful province level.
        normalizedState = null;
      } else if (normalizedState == null) {
        // Province embedded into the city string and no state column value.
        normalizedState = parent;
      }
    }
  }

  if (normalizedState == country || normalizedState == cityLabel || normalizedState == rawCity) {
    normalizedState = null;
  }

  return (country: country, state: normalizedState, cityLabel: cityLabel);
}

int _compareLabel(String a, String b) {
  final aUnknown = a == kUnknownCountry;
  final bUnknown = b == kUnknownCountry;
  if (aUnknown != bUnknown) {
    return aUnknown ? 1 : -1;
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}
