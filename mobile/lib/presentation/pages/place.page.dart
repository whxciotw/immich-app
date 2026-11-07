import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/place.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/pages/common/large_leading_tile.dart';
import 'package:immich_mobile/presentation/pages/place_grouping.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/presentation/widgets/map/map_utils.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:immich_mobile/widgets/map/map_thumbnail.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

@RoutePage()
class PlacePage extends HookConsumerWidget {
  const PlacePage({super.key, this.currentLocation});

  final LatLng? currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useState<String?>(null);
    final places = ref.watch(placesProvider);

    final tree = useMemoized(() {
      final data = places.valueOrNull;
      return data == null ? const <PlaceCountryNode>[] : buildPlaceTree(data);
    }, [places.valueOrNull]);

    final expanded = useState<Set<String>>(<String>{});
    final initialized = useRef(false);

    useEffect(() {
      if (initialized.value || tree.isEmpty) {
        return null;
      }
      initialized.value = true;
      // Default: expand the country level only, keep provinces collapsed.
      expanded.value = {for (final country in tree) country.key};
      return null;
    }, [tree]);

    final allKeys = useMemoized(() => allPlaceGroupKeys(tree), [tree]);
    final allExpanded = allKeys.isNotEmpty && expanded.value.containsAll(allKeys);

    void toggleExpandAll() {
      expanded.value = allExpanded ? <String>{} : {...allKeys};
    }

    void toggleGroup(String key) {
      final next = Set<String>.from(expanded.value);
      if (!next.remove(key)) {
        next.add(key);
      }
      expanded.value = next;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _PlaceSliverAppBar(
            search: search.value,
            onSearchChanged: (value) => search.value = value,
            onToggleSearch: () => search.value = search.value == null ? '' : null,
            showExpandToggle: search.value == null && tree.isNotEmpty,
            allExpanded: allExpanded,
            onToggleExpandAll: toggleExpandAll,
          ),
          if (search.value == null) _Map(currentLocation: currentLocation),
          _PlaceList(
            places: places,
            tree: tree,
            search: search.value,
            expanded: expanded.value,
            onToggleGroup: toggleGroup,
          ),
        ],
      ),
    );
  }
}

class _PlaceSliverAppBar extends HookWidget {
  const _PlaceSliverAppBar({
    required this.search,
    required this.onSearchChanged,
    required this.onToggleSearch,
    required this.showExpandToggle,
    required this.allExpanded,
    required this.onToggleExpandAll,
  });

  final String? search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;
  final bool showExpandToggle;
  final bool allExpanded;
  final VoidCallback onToggleExpandAll;

  @override
  Widget build(BuildContext context) {
    final searchFocusNode = useFocusNode();

    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: false,
      backgroundColor: context.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
      automaticallyImplyLeading: search == null,
      centerTitle: true,
      title: search != null
          ? SearchField(
              focusNode: searchFocusNode,
              onTapOutside: (_) => searchFocusNode.unfocus(),
              onChanged: onSearchChanged,
              filled: true,
              hintText: context.t.filter_places,
              autofocus: true,
            )
          : Text(context.t.places),
      actions: [
        if (showExpandToggle)
          IconButton(
            icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more),
            tooltip: allExpanded ? '全部折叠' : '全部展开',
            onPressed: onToggleExpandAll,
          ),
        IconButton(
          icon: Icon(search != null ? Icons.close : Icons.search),
          onPressed: onToggleSearch,
        ),
      ],
    );
  }
}

class _Map extends HookWidget {
  const _Map({this.currentLocation});

  final LatLng? currentLocation;

  @override
  Widget build(BuildContext context) {
    // Prefer the location passed in (e.g. from the asset viewer). Otherwise do a
    // cheap, permission-free lookup so the preview shows where the user actually
    // is instead of a hard-coded placeholder city. This never prompts.
    final centre = useState<LatLng?>(currentLocation);
    final resolved = useState(currentLocation != null);

    useEffect(() {
      if (currentLocation != null) {
        return null;
      }

      var cancelled = false;
      unawaited(
        MapUtils.getLastKnownPosition().then((position) {
          if (cancelled) {
            return;
          }
          centre.value = position;
          resolved.value = true;
        }),
      );

      return () => cancelled = true;
    }, const []);

    final location = centre.value;
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          width: context.width,
          // While resolving, render an empty box instead of a misleading city.
          child: resolved.value
              ? MapThumbnail(
                  onTap: (_, _) => context.pushRoute(MapRoute(initialLocation: location)),
                  zoom: location == null ? 1 : 8,
                  centre: location ?? const LatLng(0, 0),
                  showAttribution: false,
                  themeMode: context.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PlaceList extends StatelessWidget {
  const _PlaceList({
    required this.places,
    required this.tree,
    required this.search,
    required this.expanded,
    required this.onToggleGroup,
  });

  final AsyncValue<List<PlaceEntry>> places;
  final List<PlaceCountryNode> tree;
  final String? search;
  final Set<String> expanded;
  final ValueChanged<String> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    if (places.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()),
        ),
      );
    }

    if (places.hasError) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Error loading places: ${places.error}',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ),
      );
    }

    if (search != null) {
      final matches = searchPlaceCities(tree, search!);
      if (matches.isEmpty) {
        return const SliverToBoxAdapter(
          child: Center(
            child: Padding(padding: EdgeInsets.all(20.0), child: Text('没有匹配的地点')),
          ),
        );
      }
      return SliverList.builder(
        itemCount: matches.length,
        itemBuilder: (context, index) => _PlaceTile(city: matches[index], depth: 0),
      );
    }

    if (tree.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(padding: EdgeInsets.all(20.0), child: Text('没有地点数据')),
        ),
      );
    }

    final nodes = flattenPlaceTree(tree, expanded);
    return SliverList.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return switch (node) {
          PlaceCountryListNode(:final country) => _PlaceGroupTile(
            depth: 0,
            expanded: expanded.contains(country.key),
            label: country.label,
            subtitle: '${country.cityCount} 个城市 · ${country.assetCount} 张',
            onTap: () => onToggleGroup(country.key),
            bold: true,
          ),
          PlaceStateListNode(:final state) => _PlaceGroupTile(
            depth: 1,
            expanded: expanded.contains(state.key),
            label: state.label,
            subtitle: '${state.cityCount} 个城市 · ${state.assetCount} 张',
            onTap: () => onToggleGroup(state.key),
          ),
          PlaceCityListNode(:final city, :final depth) => _PlaceTile(city: city, depth: depth),
        };
      },
    );
  }
}

class _PlaceGroupTile extends StatelessWidget {
  const _PlaceGroupTile({
    required this.depth,
    required this.expanded,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.bold = false,
  });

  final int depth;
  final bool expanded;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + depth * 20.0, 10.0, 16.0, 10.0),
        child: Row(
          children: [
            Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.titleMedium?.copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(subtitle, style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.city, required this.depth});

  final PlaceCityNode city;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.0 + depth * 20.0),
      child: LargeLeadingTile(
        onTap: () => context.pushRoute(PlaceDetailRoute(place: city.rawCity)),
        title: Text(city.label, style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text('${city.assetCount} 张照片', style: context.textTheme.bodySmall),
        leading: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Thumbnail.remote(remoteId: city.thumbnailAssetId, fit: BoxFit.cover, thumbhash: ""),
          ),
        ),
      ),
    );
  }
}
