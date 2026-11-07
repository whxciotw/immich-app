import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/string_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';

@RoutePage()
class PeopleCollectionPage extends ConsumerStatefulWidget {
  const PeopleCollectionPage({super.key});

  @override
  ConsumerState<PeopleCollectionPage> createState() => _PeopleCollectionPageState();
}

class _PeopleCollectionPageState extends ConsumerState<PeopleCollectionPage> {
  final FocusNode _formFocus = FocusNode();
  String? _search;
  bool _showHidden = false;

  @override
  void dispose() {
    _formFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(Store.people.all(includeHidden: _showHidden));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final isPortrait = context.orientation == Orientation.portrait;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: _search == null,
            title: _search != null
                ? SearchField(
                    focusNode: _formFocus,
                    onTapOutside: (_) => _formFocus.unfocus(),
                    onChanged: (value) => setState(() => _search = value),
                    filled: true,
                    hintText: context.t.filter_people,
                    autofocus: true,
                  )
                : Text(context.t.people),
            actions: [
              IconButton(
                icon: Icon(_search != null ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() => _search = _search == null ? '' : null);
                },
              ),
              IconButton(
                tooltip: _showHidden ? '隐藏已隐藏的人物' : '显示已隐藏的人物',
                icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _showHidden = !_showHidden),
              ),
            ],
          ),
          body: SafeArea(
            child: people.when(
              data: (people) {
                final List<Person> filtered;
                if (_search != null) {
                  filtered = people.where((person) {
                    return person.name.toLowerCase().removeDiacritics().contains(
                      _search!.toLowerCase().removeDiacritics(),
                    );
                  }).toList();
                } else {
                  filtered = people;
                }
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 6 : 3,
                    childAspectRatio: 0.85,
                    mainAxisSpacing: isPortrait && isTablet ? 36 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];

                    return Column(
                      key: ValueKey(person.id),
                      children: [
                        GestureDetector(
                          onTap: () {
                            unawaited(context.pushRoute(PersonRoute(person: person)));
                          },
                          child: Material(
                            shape: const CircleBorder(side: BorderSide.none),
                            elevation: 3,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  key: ValueKey(person.id),
                                  maxRadius: isTablet ? 100 / 2 : 96 / 2,
                                  backgroundImage: RemoteImageProvider(
                                    url: getFaceThumbnailUrl(person.id, updatedAt: person.updatedAt),
                                  ),
                                ),
                                if (person.isHidden)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: context.colorScheme.surfaceContainer,
                                      child: Icon(
                                        Icons.visibility_off,
                                        size: 16,
                                        color: context.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => showNameEditModal(context, person),
                          child: person.name.isEmpty
                              ? Text(
                                  context.t.add_a_name,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: context.colorScheme.primary,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    person.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
              error: (error, stack) => const Text("error"),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        );
      },
    );
  }
}
