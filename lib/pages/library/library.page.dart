import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/album/album.provider.dart';
import 'package:immich_mobile/providers/partner.provider.dart';
import 'package:immich_mobile/providers/search/people.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/widgets/album/album_thumbnail_card.dart';
import 'package:immich_mobile/widgets/common/immich_app_bar.dart';
import 'package:immich_mobile/widgets/common/user_avatar.dart';
import 'package:immich_mobile/widgets/map/map_thumbnail.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../models/albums/album_search.model.dart';
import '../../widgets/common/search_field.dart';

@RoutePage()
class LibraryPage extends HookConsumerWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final filterMode = useState(QuickFilterMode.all);
    final debounceTimer = useRef<Timer?>(null);
    final searchFocusNode = useFocusNode();
    context.locale;

    onSearch(String searchTerm, QuickFilterMode mode) {
      debounceTimer.value?.cancel();
      debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
        ref.read(albumProvider.notifier).searchAlbums(searchTerm, mode);
      });
    }
    // final trashEnabled =
    //     ref.watch(serverInfoProvider.select((v) => v.serverFeatures.trash));
    clearSearch() {
      filterMode.value = QuickFilterMode.all;
      searchController.clear();
      onSearch('', QuickFilterMode.all);
    }

    return Scaffold(
      appBar: const ImmichAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.colorScheme.onSurface.withAlpha(0),
                  width: 0,
                ),
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    context.colorScheme.primary.withValues(alpha: 0.075),
                    context.colorScheme.primary.withValues(alpha: 0.09),
                    context.colorScheme.primary.withValues(alpha: 0.075),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: const GradientRotation(0.5 * pi),
                ),
              ),
              child: SearchField(
                autofocus: false,
                contentPadding: const EdgeInsets.all(16),
                hintText: 'search_albums'.tr(),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: clearSearch,
                      )
                    : null,
                controller: searchController,
                onChanged: (_) =>
                    onSearch(searchController.text, filterMode.value),
                focusNode: searchFocusNode,
                onTapOutside: (_) => searchFocusNode.unfocus(),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RecentCollectionCard(),
                FamilyCollectionCard(),
                TravelCollectionCard(),
                TravelCollectionCard(),
                TravelCollectionCard(),
                LocalAlbumsCollectionCard(),
              ],
            ),
            const SizedBox(height: 12),
            // const QuickAccessButtons(),
            const SizedBox(
              height: 32,
            ),
          ],
        ),
      ),
    );
  }
}
class RecentCollectionCard extends ConsumerWidget {
  const RecentCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(getAllPeopleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(const PeopleCollectionRoute()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      context.colorScheme.primary.withAlpha(30),
                      context.colorScheme.primary.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: people.widgetWhen(
                  onLoading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onData: (people) {
                    return GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(12),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: people.take(4).map((person) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(
                            getFaceThumbnailUrl(person.id),
                            headers: ApiService.getRequestHeaders(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Recents'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '285 items'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class FamilyCollectionCard extends ConsumerWidget {
  const FamilyCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(getAllPeopleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(const PeopleCollectionRoute()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      context.colorScheme.primary.withAlpha(30),
                      context.colorScheme.primary.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: people.widgetWhen(
                  onLoading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onData: (people) {
                    return GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(12),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: people.take(4).map((person) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(
                            getFaceThumbnailUrl(person.id),
                            headers: ApiService.getRequestHeaders(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Family'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class TravelCollectionCard extends ConsumerWidget {
  const TravelCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(getAllPeopleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(const PeopleCollectionRoute()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      context.colorScheme.primary.withAlpha(30),
                      context.colorScheme.primary.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: people.widgetWhen(
                  onLoading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onData: (people) {
                    return GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(12),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: people.take(4).map((person) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(
                            getFaceThumbnailUrl(person.id),
                            headers: ApiService.getRequestHeaders(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Travel'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class QuickAccessButtons extends ConsumerWidget {
  const QuickAccessButtons({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partners = ref.watch(partnerSharedWithProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: context.colorScheme.onSurface.withAlpha(10),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primary.withAlpha(10),
            context.colorScheme.primary.withAlpha(15),
            context.colorScheme.primary.withAlpha(20),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(partners.isEmpty ? 20 : 0),
                bottomRight: Radius.circular(partners.isEmpty ? 20 : 0),
              ),
            ),
            leading: const Icon(
              Icons.folder_outlined,
              size: 26,
            ),
            title: Text(
              'folders'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => context.pushRoute(FolderRoute()),
          ),
          ListTile(
            leading: const Icon(
              Icons.lock_outline_rounded,
              size: 26,
            ),
            title: Text(
              'locked_folder'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => context.pushRoute(const LockedRoute()),
          ),
          ListTile(
            leading: const Icon(
              Icons.group_outlined,
              size: 26,
            ),
            title: Text(
              'partners'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => context.pushRoute(const PartnerRoute()),
          ),
          PartnerList(partners: partners),
        ],
      ),
    );
  }
}

class PartnerList extends ConsumerWidget {
  const PartnerList({super.key, required this.partners});

  final List<UserDto> partners;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partners.length,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final partner = partners[index];
        final isLastItem = index == partners.length - 1;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(isLastItem ? 20 : 0),
              bottomRight: Radius.circular(isLastItem ? 20 : 0),
            ),
          ),
          contentPadding: const EdgeInsets.only(
            left: 12.0,
            right: 18.0,
          ),
          leading: userAvatar(context, partner, radius: 16),
          title: const Text(
            "partner_list_user_photos",
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ).tr(
            namedArgs: {
              'user': partner.name,
            },
          ),
          onTap: () => context.pushRoute(
            (PartnerDetailRoute(partner: partner)),
          ),
        );
      },
    );
  }
}

class PeopleCollectionCard extends ConsumerWidget {
  const PeopleCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(getAllPeopleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(const PeopleCollectionRoute()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      context.colorScheme.primary.withAlpha(30),
                      context.colorScheme.primary.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: people.widgetWhen(
                  onLoading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onData: (people) {
                    return GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(12),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: people.take(4).map((person) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(
                            getFaceThumbnailUrl(person.id),
                            headers: ApiService.getRequestHeaders(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'people'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LocalAlbumsCollectionCard extends HookConsumerWidget {
  const LocalAlbumsCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(localAlbumsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(
            const LocalAlbumsRoute(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: size,
                width: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.primary.withAlpha(30),
                        context.colorScheme.primary.withAlpha(25),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(12),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: albums.take(4).map((album) {
                      return AlbumThumbnailCard(
                        album: album,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'on_this_device'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlacesCollectionCard extends StatelessWidget {
  const PlacesCollectionCard({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () => context.pushRoute(
            PlacesCollectionRoute(
              currentLocation: null,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: size,
                width: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    color:
                        context.colorScheme.secondaryContainer.withAlpha(100),
                  ),
                  child: IgnorePointer(
                    child: MapThumbnail(
                      zoom: 8,
                      centre: const LatLng(
                        21.44950,
                        -157.91959,
                      ),
                      showAttribution: false,
                      themeMode: context.isDarkTheme
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'places'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.icon(
        onPressed: onPressed,
        label: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            label,
            style: TextStyle(
              color: context.colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
        ),
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          backgroundColor: context.colorScheme.surfaceContainerLow,
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(25)),
            side: BorderSide(
              color: context.colorScheme.onSurface.withAlpha(10),
              width: 1,
            ),
          ),
        ),
        icon: Icon(
          icon,
          color: context.primaryColor,
        ),
      ),
    );
  }
}
