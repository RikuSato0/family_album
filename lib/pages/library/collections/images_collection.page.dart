import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:immich_mobile/providers/search/paginated_search.provider.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/interfaces/person_api.interface.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';

@RoutePage()
class ImagesCollectionPage extends HookConsumerWidget {
  const ImagesCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);

    // 🎯 Create images-only search filter
    final imagesFilter = SearchFilter(
      people: <Person>{},
      location: SearchLocationFilter(),
      camera: SearchCameraFilter(),
      date: SearchDateFilter(),
      display: SearchDisplayFilters(
        isNotInAlbum: false,
        isArchive: false,
        isFavorite: false,
      ),
      mediaType: AssetType.image, // 🎯 Filter for images only!
    );

    // Initialize search on first build
    useEffect(() {
      Future.microtask(() {
        // Clear any existing search results and start fresh
        ref.read(paginatedSearchProvider.notifier).clear();
        ref.read(paginatedSearchProvider.notifier).search(imagesFilter);
      });
      return null;
    }, []);

    // 🎯 Get images-only render list from search
    final imagesRenderList = ref.watch(paginatedSearchRenderListProvider);
    final searchResult = ref.watch(paginatedSearchProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isSearching.value,
        title: isSearching.value
            ? SearchField(
                focusNode: searchFocusNode,
                controller: searchController,
                onTapOutside: (_) => searchFocusNode.unfocus(),
                onChanged: (value) {
                  // Implement search functionality within images
                  if (value.isNotEmpty) {
                    final searchFilter = imagesFilter.copyWith(context: value);
                    ref.read(paginatedSearchProvider.notifier).clear();
                    ref.read(paginatedSearchProvider.notifier).search(searchFilter);
                  } else {
                    ref.read(paginatedSearchProvider.notifier).clear();
                    ref.read(paginatedSearchProvider.notifier).search(imagesFilter);
                  }
                },
                filled: true,
                hintText: 'search_images'.tr(),
                autofocus: true,
              )
            : Text('images'.tr()),
        actions: [
          IconButton(
            icon: Icon(isSearching.value ? Icons.close : Icons.search),
            onPressed: () {
              isSearching.value = !isSearching.value;
              if (!isSearching.value) {
                searchController.clear();
                // Reset to show all images
                ref.read(paginatedSearchProvider.notifier).clear();
                ref.read(paginatedSearchProvider.notifier).search(imagesFilter);
              }
            },
          ),
        ],
      ),
      body: imagesRenderList.when(
        data: (renderList) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info with real image count
                Text(
                  '${'images_description'.tr()} • ${searchResult.assets.length} ${tr('items')}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 16),
                // Real Immich images grid (images only)
                Expanded(
                  child: searchResult.assets.isNotEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            // 🎯 FORCE FULL SYNC: Clear all data and re-download from server
                            try {
                              print("🔄 Starting force full sync for images...");
                              await ref.read(assetProvider.notifier).getAllAsset(clear: true);
                              print("✅ Full sync completed");
                              
                              // Refresh the search after sync
                              ref.read(paginatedSearchProvider.notifier).clear();
                              await ref.read(paginatedSearchProvider.notifier).search(imagesFilter);
                            } catch (e) {
                              print("❌ Sync failed: $e");
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sync failed: $e')),
                                );
                              }
                            }
                          },
                          child: GridView.builder(
                            itemCount: searchResult.assets.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              final asset = searchResult.assets[index];
                              return GestureDetector(
                                onTap: () {
                                  // 🎯 Set current asset and navigate to gallery viewer with images-only timeline!
                                  ref.read(currentAssetProvider.notifier).set(asset);
                                  
                                  context.pushRoute(
                                    GalleryViewerRoute(
                                      renderList: renderList, // 🎯 This contains ONLY images!
                                      initialIndex: index, // 🎯 Direct index since it's already filtered
                                      heroOffset: 0,
                                      showStack: false,
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: getThumbnailUrlForRemoteId(asset.remoteId!),
                                    httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: const CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.error),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'no_images_yet'.tr(),
                                style: context.textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'pull_to_refresh_sync'.tr(),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'error_loading_images'.tr(),
                style: context.textTheme.bodyLarge?.copyWith(color: Colors.red[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'pull_to_refresh_try_again'.tr(),
                style: context.textTheme.bodySmall?.copyWith(color: Colors.red[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

