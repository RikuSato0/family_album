import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';

@RoutePage()
class VideosCollectionPage extends HookConsumerWidget {
  const VideosCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);

    // Mock videos data - replace with actual provider
    final List<String> videoThumbnails = List.generate(
      438,
      (index) => 'https://picsum.photos/300/300?random=vid$index',
    );

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Text(
              '${'videos_description'.tr()} • ${videoThumbnails.length} ${'items'.tr()}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            // Direct video thumbnail grid
            Expanded(
              child: GridView.builder(
                itemCount: videoThumbnails.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          videoThumbnails[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
