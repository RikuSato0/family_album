import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/providers/search/search_page_state.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Mock data model for place clusters
class PlaceCluster {
  final String id;
  final String name;
  final LatLng location;
  final int photoCount;
  final String thumbnailUrl;
  final List<String> photoUrls;

  PlaceCluster({
    required this.id,
    required this.name,
    required this.location,
    required this.photoCount,
    required this.thumbnailUrl,
    required this.photoUrls,
  });
}

@RoutePage()
class PlacesCollectionPage extends HookConsumerWidget {
  const PlacesCollectionPage({super.key, this.currentLocation});
  final LatLng? currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);
    final selectedCluster = useState<PlaceCluster?>(null);
    final mapController = useState<MaplibreMapController?>(null);

    // Mock data - replace with actual data from your provider
    final placeClusters = [
      PlaceCluster(
        id: '1',
        name: 'United States of America',
        location: const LatLng(39.8283, -98.5795),
        photoCount: 142,
        thumbnailUrl: 'https://picsum.photos/200/200?random=usa',
        photoUrls: List.generate(142, (i) => 'https://picsum.photos/300/300?random=$i'),
      ),
      PlaceCluster(
        id: '2',
        name: 'Mexico',
        location: const LatLng(23.6345, -102.5528),
        photoCount: 86,
        thumbnailUrl: 'https://picsum.photos/200/200?random=mexico',
        photoUrls: List.generate(86, (i) => 'https://picsum.photos/300/300?random=${i + 142}'),
      ),
      PlaceCluster(
        id: '3',
        name: 'Colombia',
        location: const LatLng(4.5709, -74.2973),
        photoCount: 57,
        thumbnailUrl: 'https://picsum.photos/200/200?random=colombia',
        photoUrls: List.generate(57, (i) => 'https://picsum.photos/300/300?random=${i + 228}'),
      ),
    ];

    void onMapCreated(MaplibreMapController controller) {
      mapController.value = controller;
      _addClusterMarkers(controller, placeClusters);
    }

    double _calculateDistance(LatLng point1, LatLng point2) {
      final double lat1Rad = point1.latitude * (3.14159 / 180);
      final double lat2Rad = point2.latitude * (3.14159 / 180);
      final double deltaLat = (point2.latitude - point1.latitude) * (3.14159 / 180);
      final double deltaLng = (point2.longitude - point1.longitude) * (3.14159 / 180);

      final double a = (deltaLat / 2).abs() + (deltaLng / 2).abs();
      return a; // Simplified distance calculation
    }

    void onMapClick(Point<double> point, LatLng latLng) {
      // Find if the click is near any cluster
      PlaceCluster? tappedCluster;
      const double threshold = 0.5; // Degrees threshold for tap detection
      
      for (final cluster in placeClusters) {
        final distance = _calculateDistance(latLng, cluster.location);
        if (distance < threshold) {
          tappedCluster = cluster;
          break;
        }
      }
      
      if (tappedCluster != null) {
        selectedCluster.value = tappedCluster;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PlacePhotosBottomSheet(cluster: tappedCluster!),
        );
      } else {
        selectedCluster.value = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.maybePop(),
        ),
        title: isSearching.value
            ? SearchField(
                autofocus: true,
                filled: true,
                focusNode: searchFocusNode,
                controller: searchController,
                onChanged: (value) {
                  // Implement search functionality
                },
                onTapOutside: (_) => searchFocusNode.unfocus(),
                hintText: 'filter_places'.tr(),
              )
            : Text(
                'places'.tr(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              isSearching.value ? Icons.close : Icons.search,
              color: Colors.black,
            ),
            onPressed: () {
              isSearching.value = !isSearching.value;
              if (!isSearching.value) {
                searchController.clear();
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: MaplibreMap(
        onMapCreated: onMapCreated,
        initialCameraPosition: CameraPosition(
          target: currentLocation ?? const LatLng(20.0, -100.0),
          zoom: 3.0,
        ),
        onMapClick: onMapClick,
        styleString: context.isDarkTheme
            ? 'https://tiles.openfreemap.org/styles/dark'
            : 'https://tiles.openfreemap.org/styles/bright',
      ),
    );
  }

  void _addClusterMarkers(
    MaplibreMapController controller,
    List<PlaceCluster> clusters,
  ) async {
    // Add circle markers for each cluster
    for (final cluster in clusters) {
      await controller.addCircle(
        CircleOptions(
          geometry: cluster.location,
          circleRadius: 20.0,
          circleColor: '#FFFFFF',
          circleStrokeColor: '#2196F3',
          circleStrokeWidth: 3.0,
        ),
      );
      
      // Add text label with photo count
      await controller.addSymbol(
        SymbolOptions(
          geometry: cluster.location,
          textField: cluster.photoCount.toString(),
          textSize: 12.0,
          textColor: '#2196F3',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
        ),
      );
    }
  }




}

class PlacePhotosBottomSheet extends StatelessWidget {
  final PlaceCluster cluster;

  const PlacePhotosBottomSheet({super.key, required this.cluster});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cluster.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${cluster.photoCount} photos',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Photos grid
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: cluster.photoUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Navigate to search results for this place
                        context.pushRoute(
                          SearchRoute(
                            prefilter: SearchFilter(
                              people: {},
                              location: SearchLocationFilter(
                                city: cluster.name,
                              ),
                              camera: SearchCameraFilter(),
                              date: SearchDateFilter(),
                              display: SearchDisplayFilters(
                                isNotInAlbum: false,
                                isArchive: false,
                                isFavorite: false,
                              ),
                              mediaType: AssetType.other,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: cluster.photoUrls[index],
                          fit: BoxFit.cover,
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}