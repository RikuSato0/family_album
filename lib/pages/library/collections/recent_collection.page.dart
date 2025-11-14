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
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';

@RoutePage()
class RecentCollectionPage extends HookConsumerWidget {
  const RecentCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);

    // 🎯 Real recent photos data from Immich
    final currentUser = ref.watch(currentUserProvider);
    final recentAssets = ref.watch(singleUserTimelineProvider(currentUser?.id ?? ''));

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
                hintText: 'search_recent_photos'.tr(),
                autofocus: true,
              )
            : Text('recent'.tr()),
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
      body: recentAssets.when(
        data: (renderList) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info with real count
              Text(
                '${'recent_photos_description'.tr()} • ${renderList.totalAssets} ${tr('items')}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const SizedBox(height: 16),
              // Real Immich photos grid
              Expanded(
                child: renderList.totalAssets > 0
                    ? RefreshIndicator(
                        onRefresh: () async {
                          // 🎯 FORCE FULL SYNC: Clear all data and re-download from server
                          try {
                            print("🔄 Starting force full sync for recent photos...");
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
                          itemCount: renderList.totalAssets,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final asset = renderList.loadAsset(index);
                            return GestureDetector(
                              onTap: () {
                                // 🎯 Set current asset and navigate to gallery viewer
                                ref.read(currentAssetProvider.notifier).set(asset);
                                context.pushRoute(
                                  GalleryViewerRoute(
                                    renderList: renderList,
                                    initialIndex: index,
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
                              Icons.photo_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_recent_photos'.tr(),
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
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'error_loading_recent_photos'.tr(),
                style: context.textTheme.bodyLarge?.copyWith(color: Colors.red[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
