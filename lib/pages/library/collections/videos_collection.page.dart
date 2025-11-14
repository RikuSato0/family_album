import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:immich_mobile/providers/timeline.provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:http/http.dart' as http;


@RoutePage()
class VideosCollectionPage extends HookConsumerWidget {
  const VideosCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);

    // 🎯 Real videos data from Immich
    final videoAssets = ref.watch(allVideosTimelineProvider);

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
                hintText: 'search_videos'.tr(),
                autofocus: true,
              )
            : Text('videos'.tr()),
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
      body: videoAssets.when(
        data: (renderList) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info with real count
              Text(
                '${'videos_description'.tr()} • ${renderList.totalAssets} ${tr('items')}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const SizedBox(height: 16),
              // Real Immich videos grid with pull-to-refresh always available
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // 🎯 FORCE FULL SYNC: Clear all data and re-download from server
                    try {
                      print("🔄 Starting force full sync for videos...");
                      print("📊 Checking current video count before sync...");
                      final currentVideos = ref.read(allVideosTimelineProvider);
                      currentVideos.whenData((data) => print("📊 Current videos in local DB: ${data.totalAssets}"));
                      
                      await ref.read(assetProvider.notifier).getAllAsset(clear: true);
                      print("✅ Full sync completed");
                      
                      // Wait a moment for database to update
                      await Future.delayed(const Duration(milliseconds: 1000));
                      
                      // Invalidate the provider to refresh UI with new data
                      ref.invalidate(allVideosTimelineProvider);
                      
                      // Check count after sync
                      await Future.delayed(const Duration(milliseconds: 500));
                      final newVideos = ref.read(allVideosTimelineProvider);
                      newVideos.whenData((data) => print("📊 Videos after sync: ${data.totalAssets}"));
                      
                    } catch (e) {
                      print("❌ Sync failed: $e");
                      print("❌ Stack trace: ${e.toString()}");
                      // Show error to user
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sync failed: $e')),
                        );
                      }
                    }
                  },
                  child: renderList.totalAssets > 0
                      ? GridView.builder(
                          itemCount: renderList.totalAssets,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final asset = renderList.loadAsset(index);
                            final thumbnailUrl = getThumbnailUrlForRemoteId(asset.remoteId!);
                            
                            // 🎯 Debug logging for video data
                            print("🎬 Loading video $index:");
                            print("  - Asset ID: ${asset.remoteId}");
                            print("  - Asset type: ${asset.type}");
                            print("  - Thumbnail URL: $thumbnailUrl");
                            
                            return GestureDetector(
                              onTap: () {
                                print("🎬 Tapped video: ${asset.remoteId}");
                                print("🎬 Asset details:");
                                print("  - Type: ${asset.type}");
                                print("  - IsLocal: ${asset.isLocal}");
                                print("  - fileName: ${asset.fileName}");
                                
                                
                                // Debug: Check video URL that will be generated
                                final serverEndpoint = Store.get(StoreKey.serverEndpoint);
                                final testVideoUrl = '$serverEndpoint/assets/${asset.remoteId}/video/playback';
                                print("🎬 Video URL will be: $testVideoUrl");
                                
                                // 🔍 Test video URL accessibility
                                _testVideoUrl(testVideoUrl);
                                
                                // 🎯 Set current asset and navigate to video viewer
                                ref.read(currentAssetProvider.notifier).set(asset);
                                
                                // Navigate to GalleryViewerRoute with proper video context
                                context.pushRoute(
                                  GalleryViewerRoute(
                                    renderList: renderList,
                                    initialIndex: index,
                                    heroOffset: 0,
                                    showStack: false,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: thumbnailUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        httpHeaders: ApiService.getRequestHeaders(), // 🔑 Authentication headers!
                                        placeholder: (context, url) {
                                          print("🔄 Loading thumbnail: $url");
                                          return Container(
                                            color: Colors.blue[50],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorWidget: (context, url, error) {
                                          print("❌ Video thumbnail failed to load:");
                                          print("  - URL: $url");
                                          print("  - Error: $error");
                                          return Container(
                                            color: Colors.red[100],
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error, color: Colors.red[600], size: 32),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Video\nThumbnail\nFailed',
                                                  style: TextStyle(
                                                    color: Colors.red[600],
                                                    fontSize: 10,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Play button overlay to indicate it's a video
                                    const Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white70,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'no_videos_yet'.tr(),
                                    style: context.textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Pull down to refresh and sync from server',
                                    style: context.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      // 🎯 FORCE FULL SYNC: Clear all data and re-download from server
                                      try {
                                        print("🔄 Starting force full sync for videos...");
                                        print("📊 Checking current video count before sync...");
                                        final currentVideos = ref.read(allVideosTimelineProvider);
                                        currentVideos.whenData((data) => print("📊 Current videos in local DB: ${data.totalAssets}"));
                                        
                                        // Show loading state
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('🔄 Syncing with server...')),
                                        );
                                        
                                        await ref.read(assetProvider.notifier).getAllAsset(clear: true);
                                        print("✅ Full sync completed");
                                        
                                        // Wait a moment for database to update
                                        await Future.delayed(const Duration(milliseconds: 1000));
                                        
                                        // Invalidate the provider to refresh UI with new data
                                        ref.invalidate(allVideosTimelineProvider);
                                        
                                        // Check count after sync
                                        await Future.delayed(const Duration(milliseconds: 500));
                                        final newVideos = ref.read(allVideosTimelineProvider);
                                        newVideos.whenData((data) => print("📊 Videos after sync: ${data.totalAssets}"));
                                        
                                        // Show success message
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('✅ Sync completed')),
                                          );
                                        }
                                        
                                      } catch (e) {
                                        print("❌ Sync failed: $e");
                                        print("❌ Stack trace: ${e.toString()}");
                                        // Show error to user
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('❌ Sync failed: $e')),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Sync Now'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                'error_loading_videos'.tr(),
                style: context.textTheme.bodyLarge?.copyWith(color: Colors.red[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 🔍 Test video URL accessibility
  void _testVideoUrl(String videoUrl) async {
    try {
      print("🔍 Testing video URL: $videoUrl");
      final response = await http.head(
        Uri.parse(videoUrl),
        headers: ApiService.getRequestHeaders(),
      );
      
      print("🔍 Video URL test result:");
      print("  - Status Code: ${response.statusCode}");
      print("  - Headers: ${response.headers}");
      
      if (response.statusCode == 200) {
        print("✅ Video URL is accessible!");
        final contentType = response.headers['content-type'];
        final contentLength = response.headers['content-length'];
        print("  - Content-Type: $contentType");
        print("  - Content-Length: $contentLength");
      } else {
        print("❌ Video URL failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Video URL test error: $e");
    }
  }
}
