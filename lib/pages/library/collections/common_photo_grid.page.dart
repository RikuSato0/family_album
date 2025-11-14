import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';

@RoutePage()
class PhotoGridPage extends HookConsumerWidget {
  const PhotoGridPage({
    super.key,
    required this.title,
    required this.photoUrls,
    this.subtitle,
    this.isVideoGrid = false,
  });

  final String title;
  final List<String> photoUrls;
  final String? subtitle;
  final bool isVideoGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);
    final filteredPhotos = useState<List<String>>(photoUrls);
    final selectedItems = useState<Set<int>>({});
    final isSelectionMode = useState(false);

    void filterPhotos(String query) {
      if (query.isEmpty) {
        filteredPhotos.value = photoUrls;
      } else {
        // In a real app, you'd filter based on actual metadata
        // For now, we'll just show all photos when searching
        filteredPhotos.value = photoUrls;
      }
    }

    void toggleSelection(int index) {
      final newSelection = Set<int>.from(selectedItems.value);
      if (newSelection.contains(index)) {
        newSelection.remove(index);
      } else {
        newSelection.add(index);
      }
      selectedItems.value = newSelection;

      if (newSelection.isEmpty) {
        isSelectionMode.value = false;
      }
    }

    void clearSelection() {
      selectedItems.value = {};
      isSelectionMode.value = false;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isSearching.value && !isSelectionMode.value,
        leading: isSelectionMode.value
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: clearSelection,
              )
            : null,
        title: isSearching.value
            ? SearchField(
                focusNode: searchFocusNode,
                controller: searchController,
                onTapOutside: (_) => searchFocusNode.unfocus(),
                onChanged: filterPhotos,
                filled: true,
                hintText: 'search_photos'.tr(),
                autofocus: true,
              )
            : isSelectionMode.value
                ? Text('${selectedItems.value.length} ${'selected'.tr()}')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w400),
                        ),
                    ],
                  ),
        actions: [
          if (!isSelectionMode.value)
            IconButton(
              icon: Icon(isSearching.value ? Icons.close : Icons.search),
              onPressed: () {
                isSearching.value = !isSearching.value;
                if (!isSearching.value) {
                  searchController.clear();
                  filterPhotos('');
                }
              },
            ),
          if (isSelectionMode.value)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'select_all':
                    selectedItems.value = Set.from(
                      List.generate(filteredPhotos.value.length, (i) => i),
                    );
                    break;
                  case 'share':
                    // Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Share ${selectedItems.value.length} items')),
                    );
                    break;
                  case 'delete':
                    // Implement delete functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Delete ${selectedItems.value.length} items')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select_all',
                  child: Text('select_all'.tr()),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('share'.tr()),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('delete'.tr()),
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final crossAxisCount = isTablet ? 6 : 3;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemCount: filteredPhotos.value.length,
            itemBuilder: (context, index) {
              final isSelected = selectedItems.value.contains(index);

              return GestureDetector(
                onTap: () {
                  if (isSelectionMode.value) {
                    toggleSelection(index);
                  } else {
                    // Navigate to photo viewer
                ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('View photo at index $index')),
                    );
                  }
                },
                onLongPress: () {
                  if (!isSelectionMode.value) {
                    isSelectionMode.value = true;
                    toggleSelection(index);
                  }
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: context.colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: filteredPhotos.value[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                    // Video indicator
                    if (isVideoGrid)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    // Selection indicator
                    if (isSelectionMode.value)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.colorScheme.primary
                                : Colors.white.withAlpha(180),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
