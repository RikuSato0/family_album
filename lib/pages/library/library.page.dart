import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
import 'package:immich_mobile/providers/timeline.provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/providers/search/search_page_state.provider.dart';

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

    clearSearch() {
      filterMode.value = QuickFilterMode.all;
      searchController.clear();
      onSearch('', QuickFilterMode.all);
    }

    return Scaffold(
      appBar: ImmichAppBar(
        title: "photos".tr(),
        showProfileButton: false,
        showUploadButton: true,
        showRefreshButton: false,
      ),
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
                hintText: 'Search'.tr(),
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
                FavoritesCollectionCard(),
                ImagesCollectionCard(),
                VideosCollectionCard(),
                PlacesCollectionCard(),
              ],
            ),
            const SizedBox(height: 12),
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
    // 🎯 Get real recent photos data from Immich
    final currentUser = ref.watch(currentUserProvider);
    final recentAssets = ref.watch(singleUserTimelineProvider(currentUser?.id ?? ''));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () {
            // Navigate to recent photos
            context.pushRoute(const RecentCollectionRoute());
          },
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
                      Colors.blue.withAlpha(30),
                      Colors.blue.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // 🎯 Real thumbnail from most recent asset (instead of static image)
                      recentAssets.when(
                        data: (renderList) {
                          if (renderList.totalAssets > 0) {
                            final mostRecentAsset = renderList.loadAsset(0);
                            return CachedNetworkImage(
                              imageUrl: getThumbnailUrlForRemoteId(mostRecentAsset.remoteId!),
                              httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/recent.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/recent.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Fallback to static image if no assets
                          return Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/library/recent.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/recent.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/recent.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.access_time_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'recent'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count from Immich (instead of hardcoded "285 items")
                  recentAssets.when(
                    data: (renderList) => '${renderList.totalAssets} ${tr('items')}',
                    loading: () => '0 ${tr('items')}',
                    error: (_, __) => '0 ${tr('items')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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
    // 🎯 Get real people data from Immich
    final peopleData = ref.watch(getAllPeopleProvider);
    
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
                      Colors.pink.withAlpha(30),
                      Colors.pink.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // 🎯 Real face thumbnail from first person (instead of static image)
                      peopleData.when(
                        data: (people) {
                          if (people.isNotEmpty) {
                            final firstPerson = people.first;
                            return CachedNetworkImage(
                              imageUrl: getFaceThumbnailUrl(firstPerson.id),
                              httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/family.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/family.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Fallback to static image if no people
                          return Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/library/family.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/family.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/family.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.family_restroom_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'family'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count of people from Immich (instead of hardcoded "112 items")
                  peopleData.when(
                    data: (people) => '${people.length} ${tr('items')}',
                    loading: () => '0 ${tr('items')}',
                    error: (_, __) => '0 ${tr('items')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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

class FavoritesCollectionCard extends ConsumerWidget {
  const FavoritesCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎯 Get real favorites data from Immich
    final favoriteAssets = ref.watch(favoriteTimelineProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () {
            // Navigate to favorites
            context.pushRoute(const FavoritesCollectionRoute());
          },
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
                      Colors.red.withAlpha(30),
                      Colors.red.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // 🎯 Real thumbnail from first favorite (instead of static image)
                      favoriteAssets.when(
                        data: (renderList) {
                          if (renderList.totalAssets > 0) {
                            final firstFavorite = renderList.loadAsset(0);
                            return CachedNetworkImage(
                              imageUrl: getThumbnailUrlForRemoteId(firstFavorite.remoteId!),
                              httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/favorites.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/favorites.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Fallback to static image if no favorites
                          return Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/library/favorites.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/favorites.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/favorites.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'favorites'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count from Immich (instead of hardcoded "67 items")
                  favoriteAssets.when(
                    data: (renderList) => '${renderList.totalAssets} ${tr('items')}',
                    loading: () => '0 ${tr('items')}',
                    error: (_, __) => '0 ${tr('items')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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

class ImagesCollectionCard extends ConsumerWidget {
  const ImagesCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎯 Get all timeline data and filter for images
    final currentUser = ref.watch(currentUserProvider);
    final allAssets = ref.watch(singleUserTimelineProvider(currentUser?.id ?? ''));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () {
            // Navigate to images only
            context.pushRoute(const ImagesCollectionRoute());
          },
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
                      Colors.green.withAlpha(30),
                      Colors.green.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // 🎯 Real thumbnail from first image (instead of static image)
                      allAssets.when(
                        data: (renderList) {
                          // Find first image (non-video) asset
                          Asset? firstImage;
                          for (int i = 0; i < renderList.totalAssets; i++) {
                            final asset = renderList.loadAsset(i);
                            if (asset.type == AssetType.image) {
                              firstImage = asset;
                              break;
                            }
                          }
                          
                          if (firstImage != null) {
                            return CachedNetworkImage(
                              imageUrl: getThumbnailUrlForRemoteId(firstImage.remoteId!),
                              httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/images.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/images.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Fallback to static image if no images
                          return Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/library/images.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/images.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/images.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.image_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'images'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count of images from Immich (filter out videos)
                  allAssets.when(
                    data: (renderList) {
                      int imageCount = 0;
                      for (int i = 0; i < renderList.totalAssets; i++) {
                        final asset = renderList.loadAsset(i);
                        if (asset.type == AssetType.image) {
                          imageCount++;
                        }
                      }
                      return '$imageCount ${tr('items')}';
                    },
                    loading: () => '0 ${tr('items')}',
                    error: (_, __) => '0 ${tr('items')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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

class VideosCollectionCard extends ConsumerWidget {
  const VideosCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎯 Real videos data from Immich
    final videoAssets = ref.watch(allVideosTimelineProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final widthFactor = isTablet ? 0.25 : 0.5;
        final size = context.width * widthFactor - 20.0;

        return GestureDetector(
          onTap: () {
            // Navigate to videos only
            context.pushRoute(const VideosCollectionRoute());
          },
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
                      Colors.purple.withAlpha(30),
                      Colors.purple.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // 🎯 Real thumbnail from first video (instead of static image)
                      videoAssets.when(
                        data: (renderList) {
                          if (renderList.totalAssets > 0) {
                            final firstVideo = renderList.loadAsset(0);
                            return CachedNetworkImage(
                              imageUrl: getThumbnailUrlForRemoteId(firstVideo.remoteId!),
                              httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/videos.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/library/videos.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Fallback to static image if no videos
                          return Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/library/videos.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/videos.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        error: (_, __) => Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/library/videos.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'videos'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count from Immich (instead of hardcoded "438 items")
                  videoAssets.when(
                    data: (renderList) => '${renderList.totalAssets} ${tr('items')}',
                    loading: () => '0 ${tr('items')}',
                    error: (_, __) => '0 ${tr('items')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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

class PlacesCollectionCard extends ConsumerWidget {
  const PlacesCollectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎯 Get real places data from Immich
    final placesData = ref.watch(getAllPlacesProvider);
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
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withAlpha(30),
                      Colors.orange.withAlpha(25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background image
                      Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/library/places.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(0),
                              Colors.black.withAlpha(50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon overlay
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'places'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  // 🎯 Real count of places from Immich (instead of hardcoded "23 cities")
                  placesData.when(
                    data: (places) => '${places.length} ${tr('cities')}',
                    loading: () => '0 ${tr('cities')}',
                    error: (_, __) => '0 ${tr('cities')}',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
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
