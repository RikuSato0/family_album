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
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

Future<Uint8List> loadCircularImage(String imageUrl,
    {double size = 100.0, double borderWidth = 4.0}) async {
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode != 200) {
    throw Exception("Failed to load image");
  }

  final codec = await ui.instantiateImageCodec(response.bodyBytes,
      targetWidth: size.toInt(), targetHeight: size.toInt());
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();
  final borderPaint = ui.Paint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = borderWidth;

  final center = Offset(size / 2, size / 2);
  final radius = size / 2;

  final rect = Rect.fromLTWH(0, 0, size, size);

  canvas.clipPath(Path()..addOval(rect));

  paint.isAntiAlias = true;
  canvas.drawImage(image, Offset.zero, paint);

  canvas.drawCircle(center, radius - borderWidth / 2, borderPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

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
        photoUrls: List.generate(
            142, (i) => 'https://picsum.photos/300/300?random=$i'),
      ),
      PlaceCluster(
        id: '2',
        name: 'Mexico',
        location: const LatLng(23.6345, -102.5528),
        photoCount: 86,
        thumbnailUrl: 'https://picsum.photos/200/200?random=mexico',
        photoUrls: List.generate(
            86, (i) => 'https://picsum.photos/300/300?random=${i + 142}'),
      ),
      PlaceCluster(
        id: '3',
        name: 'Colombia',
        location: const LatLng(4.5709, -74.2973),
        photoCount: 57,
        thumbnailUrl: 'https://picsum.photos/200/200?random=colombia',
        photoUrls: List.generate(
            57, (i) => 'https://picsum.photos/300/300?random=${i + 228}'),
      ),
    ];

    void onMapCreated(MaplibreMapController controller) {
      mapController.value = controller;
      _addClusterMarkers(controller, placeClusters);
    }

    double _calculateDistance(LatLng point1, LatLng point2) {
      final double lat1Rad = point1.latitude * (3.14159 / 180);
      final double lat2Rad = point2.latitude * (3.14159 / 180);
      final double deltaLat =
          (point2.latitude - point1.latitude) * (3.14159 / 180);
      final double deltaLng =
          (point2.longitude - point1.longitude) * (3.14159 / 180);

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
    for (final cluster in clusters) {
      try {
        final bytes = await loadCircularImage(
          cluster.thumbnailUrl,
          size: 160,
          borderWidth: 4,
        );
        final iconName = 'cluster_${cluster.id}';

        await controller.addImage(iconName, bytes);

        await controller.addSymbol(
          SymbolOptions(
            geometry: cluster.location,
            iconImage: iconName,
            iconSize: 1,
            iconAnchor: 'center',
          ),
        );
      } catch (e) {
        debugPrint('Failed to load marker image: $e');
      }
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
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.pushRoute(
                          PhotoGridRoute(
                            title: cluster.name,
                            photoUrls: cluster.photoUrls,
                            subtitle: '${cluster.photoCount} photos',
                          ),
                        );
                      },
                      child: Text('view_all'.tr()),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Photos grid preview (show first 12 photos)
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: cluster.photoUrls.length > 12
                      ? 12
                      : cluster.photoUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        context.pushRoute(
                          PhotoGridRoute(
                            title: cluster.name,
                            photoUrls: cluster.photoUrls,
                            subtitle: '${cluster.photoCount} photos',
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: cluster.photoUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                            ),
                            // Show "+" overlay on last visible item if there are more photos
                            if (index == 11 && cluster.photoUrls.length > 12)
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(150),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      Text(
                                        '+${cluster.photoUrls.length - 12}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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
