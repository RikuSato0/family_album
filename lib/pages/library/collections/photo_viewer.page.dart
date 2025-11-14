import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:immich_mobile/providers/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';

@RoutePage()
class ImagesCollectionPage extends HookConsumerWidget {
  const ImagesCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);

    // 🎯 Real images data from Immich (filter timeline for images only)
    final currentUser = ref.watch(currentUserProvider);
    final allAssets = ref.watch(singleUserTimelineProvider(currentUser?.id ?? ''));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isSearching.value,
        title: isSearching.value
            ? SearchField(
                focusNode: searchFocusNode,
                controller: searchController,
                onTapOutside: (_) => searchFocusNode.unfocus(),
                onChanged: (value) {
                  // Implement search functionality
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
              }
            },
          ),
        ],
      ),
      body: allAssets.when(
        data: (renderList) {
          // 🎯 Filter for image assets only (exclude videos)
          final List<Asset> imageAssets = [];
          for (int i = 0; i < renderList.totalAssets; i++) {
            final asset = renderList.loadAsset(i);
            if (asset.type == AssetType.image) {
              imageAssets.add(asset);
            }
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info with real image count
                Text(
                  '${'images_description'.tr()} • ${imageAssets.length} ${tr('items')}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 16),
                // Real Immich images grid (images only)
                Expanded(
                  child: imageAssets.isNotEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            // 🎯 FORCE FULL SYNC: Clear all data and re-download from server
                            try {
                              print("🔄 Starting force full sync for images...");
                              await ref.read(assetProvider.notifier).getAllAsset(clear: true);
                              print("✅ Full sync completed");
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
                            itemCount: imageAssets.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              final asset = imageAssets[index];
                              return GestureDetector(
                                onTap: () {
                                  // 🎯 Set current asset and navigate to gallery viewer
                                  ref.read(currentAssetProvider.notifier).set(asset);
                                  
                                  // Find the correct index in the original renderList
                                  int originalIndex = 0;
                                  for (int i = 0; i < renderList.totalAssets; i++) {
                                    final originalAsset = renderList.loadAsset(i);
                                    if (originalAsset.remoteId == asset.remoteId) {
                                      originalIndex = i;
                                      break;
                                    }
                                  }
                                  
                                  context.pushRoute(
                                    GalleryViewerRoute(
                                      renderList: renderList,
                                      initialIndex: originalIndex,
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
            ],
          ),
        ),
      ),
    );
  }
}
