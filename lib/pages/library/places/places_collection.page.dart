import 'dart:math';
import 'package:http/http.dart' as http;

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
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/interfaces/person_api.interface.dart';
import 'package:immich_mobile/providers/timeline.provider.dart';
import 'package:immich_mobile/services/asset.service.dart';
import 'package:immich_mobile/services/search.service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:immich_mobile/providers/map/map_marker.provider.dart';
import 'package:immich_mobile/providers/map/map_state.provider.dart';
import 'package:immich_mobile/models/map/map_marker.model.dart';
import 'package:immich_mobile/extensions/maplibrecontroller_extensions.dart';

// Places collection page using real Immich data

@RoutePage()
class PlacesCollectionPage extends HookConsumerWidget {
  const PlacesCollectionPage({super.key, this.currentLocation});
  final dynamic currentLocation; // Changed from LatLng to dynamic for simplicity

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final isSearching = useState(false);
    final showMapView = useState(false);

    // 🎯 Get real places data from Immich
    final placesData = ref.watch(getAllPlacesProvider);
    
    // 🔍 Debug: Log places data to understand the issue
    useEffect(() {
      placesData.whenData((places) {
        print("🗺️ DEBUG: Places data loaded");
        print("📊 Places count: ${places.length}");
        if (places.isNotEmpty) {
          print("📍 First place: ${places.first.label}");
          print("🆔 First place ID: ${places.first.id}");
        } else {
          print("❌ No places found - this explains why you see 0 items");
          print("🔧 This means your photos don't have city EXIF data, or haven't been processed yet");
        }
      });
      return null;
    }, [placesData]);
    
    // 🔍 Debug: Also test direct API call with detailed error info
    useEffect(() {
      Future.microtask(() async {
        try {
          print("🧪 DEBUG: Testing direct API call...");
          final searchService = ref.read(searchServiceProvider);
          
          // Test server connection first
          print("🌐 Testing server connection...");
          final serverEndpoint = Store.get(StoreKey.serverEndpoint);
          print("📡 Server endpoint: $serverEndpoint");
          
          // Now test the places API
          final apiResult = await searchService.getAllPlaces();
          print("📡 Direct API result: ${apiResult?.length ?? 0} places");
          
          if (apiResult == null) {
            print("❌ API returned null - likely authentication or endpoint issue");
          } else if (apiResult.isEmpty) {
            print("📦 API returned empty list - no photos with city data found");
            print("💡 Solutions:");
            print("   1. Upload photos taken with a phone (have GPS data)");  
            print("   2. Wait for Immich to process location metadata");
            print("   3. Check if photos have EXIF location data");
          } else {
            print("✅ Found ${apiResult.length} assets with location data");
            int validCities = 0;
            for (var asset in apiResult.take(5)) {
              final hasCity = asset.exifInfo?.city != null && asset.exifInfo!.city!.isNotEmpty;
              if (hasCity) validCities++;
              print("📍 Asset: ${asset.originalFileName}");
              print("   City: ${asset.exifInfo?.city ?? 'No city'}");
              print("   State: ${asset.exifInfo?.state ?? 'No state'}");
              print("   Country: ${asset.exifInfo?.country ?? 'No country'}");
              print("   Has GPS: ${asset.exifInfo?.latitude != null && asset.exifInfo?.longitude != null}");
              print("   Valid for Places: $hasCity");
            }
            print("🏙️ Summary: $validCities out of ${apiResult.length} assets have valid city names");
          }
          
        } catch (e, stack) {
          print("❌ API call failed with error: $e");
          print("📚 Stack trace: $stack");
          
          // Check if it's an authentication error
          if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
            print("🔐 Authentication error - check login status");
          } else if (e.toString().contains('404') || e.toString().contains('Not Found')) {
            print("🔍 Endpoint not found - server may not support /search/cities");
          } else if (e.toString().contains('FormatException')) {
            print("📄 Server returned HTML instead of JSON - endpoint issue");
          }
        }
      });
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
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
                hintText: 'search_places'.tr(),
              )
            : Text('places'.tr()),
        actions: [
          // 🗺️ Toggle between List and Map view
          IconButton(
            icon: Icon(showMapView.value ? Icons.list : Icons.map),
            tooltip: showMapView.value ? 'List View' : 'Map View',
            onPressed: () {
              showMapView.value = !showMapView.value;
            },
          ),
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
            floatingActionButton: showMapView.value 
        ? FloatingActionButton(
            onPressed: () {
              // 🔧 FIXED: Navigate to actual backup page instead of just showing SnackBar
              print("📤 Navigating to backup page...");
              context.pushRoute(const BackupControllerRoute());
            },
            child: Icon(Icons.add_a_photo),
            tooltip: 'Upload Photos',
          )
        : null,
      body: showMapView.value 
        ? _buildMapView(context, ref)
        : placesData.when(
        data: (places) {
          // Filter places if searching
          var filteredPlaces = places;
          if (isSearching.value && searchController.text.isNotEmpty) {
            filteredPlaces = places.where((place) =>
                place.label.toLowerCase().contains(searchController.text.toLowerCase())
            ).toList();
          }

          return filteredPlaces.isNotEmpty
              ? RefreshIndicator(
                  onRefresh: () async {
                    try {
                      print("🔄 Refreshing places data...");
                      // Force full sync and refresh places
                      await ref.read(assetProvider.notifier).getAllAsset(clear: true);
                      ref.invalidate(getAllPlacesProvider);
                      print("✅ Places data refreshed");
                    } catch (e) {
                      print("❌ Places refresh failed: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Refresh failed: $e')),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header info
                        Text(
                          '${'places_description'.tr()} • ${filteredPlaces.length} ${'cities'.tr()}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface.withAlpha(180),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Places list
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredPlaces.length,
                            itemBuilder: (context, index) {
                              final place = filteredPlaces[index];
                              return PlaceCard(
                                place: place,
                                onTap: () {
                                   // Navigate to search page with city filter
                                   context.pushRoute(
                                     SearchRoute(
                                       prefilter: SearchFilter(
                                         people: <Person>{},
                                         location: SearchLocationFilter(city: place.label),
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSearching.value && searchController.text.isNotEmpty 
                            ? 'no_places_found'.tr() 
                            : 'no_places_yet'.tr(),
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isSearching.value) ...[
                        Text(
                          'location_info_in_photos'.tr(),
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'pull_to_refresh'.tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          // 🛠️ Enhanced error debugging
          print("❌ Places API Error Details:");
          print("   Error: $error");
          print("   Stack: $stackTrace");
          
          return RefreshIndicator(
            onRefresh: () async {
              print("🔄 Refreshing places after error...");
              ref.invalidate(getAllPlacesProvider);
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(
                        'error_loading_places'.tr(),
                        style: context.textTheme.bodyLarge?.copyWith(color: Colors.red[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'pull_to_refresh_try_again'.tr(),
                        style: context.textTheme.bodySmall?.copyWith(color: Colors.red[500]),
                      ),
                      const SizedBox(height: 16),
                      // 🔧 Debug info for user
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '🔍 Troubleshooting Tips:',
                              style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Photos need GPS/location data\n• Try uploading new photos with location\n• Check server connection\n• Pull to refresh to retry',
                              style: context.textTheme.bodySmall,
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🗺️ Build Map View showing photo locations as pins
  Widget _buildMapView(BuildContext context, WidgetRef ref) {
    final mapController = useRef<MaplibreMapController?>(null);
    final markers = useRef<List<MapMarker>>([]);
    final mapState = ref.watch(mapStateNotifierProvider);
    final isLoading = useState(false);

    // 🎯 Create markers directly from all assets with GPS coordinates
    Future<List<MapMarker>> createMarkersFromAssets() async {
      try {
        print("🔍 Creating markers from all assets with GPS coordinates...");
        
        // Get all assets using the search service instead of timeline
        final searchService = ref.read(searchServiceProvider);
        final List<MapMarker> photoMarkers = [];
        
        // Get all places to find assets with GPS data
        final allPlacesAssets = await searchService.getAllPlaces();
        
        if (allPlacesAssets == null || allPlacesAssets.isEmpty) {
          print("📦 No assets with location data found");
          return [];
        }
        
        print("📊 Processing ${allPlacesAssets.length} assets with location data for GPS coordinates...");
        
        // Check assets for GPS coordinates
        for (final asset in allPlacesAssets.take(100)) {
          try {
            // Check if asset has GPS coordinates
            if (asset.exifInfo?.latitude != null && 
                asset.exifInfo?.longitude != null &&
                asset.exifInfo!.latitude != 0.0 &&
                asset.exifInfo!.longitude != 0.0) {
              
              final marker = MapMarker(
                latLng: LatLng(
                  asset.exifInfo!.latitude!.toDouble(),
                  asset.exifInfo!.longitude!.toDouble(),
                ),
                assetRemoteId: asset.id,
              );
              photoMarkers.add(marker);
              
              print("📍 Added marker: ${asset.originalFileName} at ${marker.latLng}");
              
              // Limit to 50 markers for performance
              if (photoMarkers.length >= 50) {
                print("⚠️ Limited to 50 markers for performance");
                break;
              }
            }
          } catch (e) {
            // Skip this asset if there's an error loading it
            print("⚠️ Skipping asset due to error: $e");
            continue;
          }
        }
        
        print("✅ Created ${photoMarkers.length} markers from assets with GPS data");
        return photoMarkers;
      } catch (e) {
        print("❌ Error creating markers from assets: $e");
        return [];
      }
    }

    // Load markers when map is created - using proper circle layers like the main map
    void onMapCreated(MaplibreMapController controller) async {
      mapController.value = controller;
      isLoading.value = true;
      
      try {
        print("🗺️ Loading map markers...");
        
        // Create markers from assets with GPS data
        final photoMarkers = await createMarkersFromAssets();
        markers.value = photoMarkers;
        
        if (photoMarkers.isNotEmpty) {
          print("🗺️ Loading ${photoMarkers.length} markers on map...");
          
          // Show where markers are located
          for (var marker in photoMarkers.take(5)) {
            print("📍 Marker at: ${marker.latLng.latitude}, ${marker.latLng.longitude}");
          }
          
          // Create actual photo thumbnail markers
          print("🎯 Creating REAL photo thumbnail markers...");
          
          // Add actual photo thumbnail markers for each location
          for (int i = 0; i < photoMarkers.length; i++) {
            final marker = photoMarkers[i];
            final assetId = marker.assetRemoteId;
            
            try {
              final imageName = 'photo_thumb_$i';
              final thumbnailUrl = getThumbnailUrlForRemoteId(assetId);
              print("📷 Loading REAL thumbnail for marker $i: $thumbnailUrl");
              
              // Load the actual photo thumbnail from network
              final response = await http.get(
                Uri.parse(thumbnailUrl),
                headers: ApiService.getRequestHeaders(),
              );
              
              if (response.statusCode == 200) {
                // Successfully loaded photo - add it as a map image
                await controller.addImage(imageName, response.bodyBytes);
                print("✅ Loaded photo image: $imageName");
                
                // Add the actual photo as a symbol marker
                await controller.addSymbol(
                  SymbolOptions(
                    geometry: marker.latLng,
                    iconImage: imageName, // Use the actual photo!
                    iconSize: 0.3, // Smaller size for photo thumbnails
                    iconAnchor: 'center',
                  ),
                );
                
                // Add a subtle border around the photo
                await controller.addCircle(
                  CircleOptions(
                    geometry: marker.latLng,
                    circleRadius: 20.0, // Border around photo
                    circleColor: 'rgba(255,255,255,0.1)', // Almost transparent
                    circleOpacity: 0.3,
                    circleStrokeWidth: 2.0,
                    circleStrokeColor: '#FFFFFF', // White border
                    circleStrokeOpacity: 0.8,
                  ),
                );
                
                print("✅ Added REAL photo marker ${i + 1} with actual thumbnail!");
              } else {
                throw Exception("Failed to load thumbnail: ${response.statusCode}");
              }
              
            } catch (e) {
              print("❌ Real photo loading failed: $e");
              print("🔄 Using fallback white circle for marker $i");
              
              // Fallback to white circle with photo icon
              try {
                await controller.addCircle(
                  CircleOptions(
                    geometry: marker.latLng,
                    circleRadius: 20.0,
                    circleColor: '#FFFFFF',
                    circleOpacity: 0.9,
                    circleStrokeWidth: 2.0,
                    circleStrokeColor: '#333333',
                    circleStrokeOpacity: 1.0,
                  ),
                );
                
                // Add camera emoji as text on top
                await controller.addSymbol(
                  SymbolOptions(
                    geometry: marker.latLng,
                    textField: '📷',
                    textSize: 16.0,
                    textColor: '#333333',
                  ),
                );
                
                print("✅ Added fallback photo marker ${i + 1}");
              } catch (e2) {
                print("❌ Even fallback failed: $e2");
              }
            }
          }
          
          // Always zoom to show markers (important!)
          await Future.delayed(Duration(milliseconds: 500)); // Wait for layers to load
          
          if (photoMarkers.length == 1) {
            // Single marker - zoom out 50% from previous level
            print("🎯 Zooming to single marker at: ${photoMarkers.first.latLng}");
            await controller.animateCamera(
              CameraUpdate.newLatLngZoom(
                photoMarkers.first.latLng,
                8.0, // 50% more zoomed out (was 12.0, now 8.0)
              ),
            );
          } else if (photoMarkers.length > 1) {
            // Multiple markers - fit bounds with much more padding (50% more zoomed out)
            final lats = photoMarkers.map((m) => m.latLng.latitude).toList();
            final lngs = photoMarkers.map((m) => m.latLng.longitude).toList();
            
            final bounds = LatLngBounds(
              southwest: LatLng(
                lats.reduce((a, b) => a < b ? a : b), 
                lngs.reduce((a, b) => a < b ? a : b)
              ),
              northeast: LatLng(
                lats.reduce((a, b) => a > b ? a : b), 
                lngs.reduce((a, b) => a > b ? a : b)
              ),
            );
            
            print("🎯 Zooming to bounds: ${bounds.southwest} to ${bounds.northeast}");
            await controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, left:200.0, right:200.0, top:200.0, bottom:200.0), // 50% more padding for zoomed out view
            );
          }
          
          print("✅ Map should now show ${photoMarkers.length} markers!");
        } else {
          print("❌ No markers to display - photos might not have GPS coordinates");
        }
        
        print("🗺️ Map loaded with ${photoMarkers.length} photo pins");
      } catch (e) {
        print("❌ Error loading map markers: $e");
      } finally {
        isLoading.value = false;
      }
    }

    // Handle tap on map pins
    void onMapClick(Point<double> point, LatLng coordinates) {
      print("📍 Tapped map at: ${coordinates.latitude}, ${coordinates.longitude}");
    }

    return Stack(
      children: [
        // Map widget
        MaplibreMap(
          onMapCreated: onMapCreated,
          onMapClick: onMapClick,
          initialCameraPosition: CameraPosition(
            target: LatLng(40.0, -40.0), // Better starting position for world view
            zoom: 2.5,
          ),
          styleString: mapState.themeMode == ThemeMode.dark
              ? mapState.darkStyleFetched.value ?? 'https://tiles.openfreemap.org/styles/dark'
              : mapState.lightStyleFetched.value ?? 'https://tiles.openfreemap.org/styles/bright',
        ),
        
        // Loading indicator
        if (isLoading.value)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading photo locations...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Info overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🗺️ ${'places_map_description'.tr()} • ${markers.value.length} pins',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        // Refresh button
        Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () async {
              if (mapController.value != null) {
                isLoading.value = true;
                try {
                  final photoMarkers = await createMarkersFromAssets();
                  markers.value = photoMarkers;
                  if (photoMarkers.isNotEmpty) {
                    await mapController.value!.reloadAllLayersForMarkers(photoMarkers);
                  }
                } finally {
                  isLoading.value = false;
                }
              }
            },
            child: Icon(Icons.refresh),
            tooltip: 'Refresh markers',
          ),
        ),
      ],
    );
  }
}

class PlaceCard extends ConsumerWidget {
  final dynamic place; // SearchCuratedContent
  final VoidCallback onTap;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get assets for this place to show count and thumbnail
    final assetsForPlace = ref.watch(getAssetsByCityProvider(place.label));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: assetsForPlace.when(
                    data: (assets) {
                      if (assets.isNotEmpty) {
                        final firstAsset = assets.first;
                        return CachedNetworkImage(
                          imageUrl: getThumbnailUrlForRemoteId(firstAsset.remoteId!),
                          httpHeaders: ApiService.getRequestHeaders(),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey[500],
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey[500],
                            ),
                          ),
                        );
                      }
                      return Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey[500],
                      );
                    },
                    loading: () => Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey[500],
                    ),
                    error: (_, __) => Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Place info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.label,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assetsForPlace.when(
                        data: (assets) => '${assets.length} ${'items'.tr()}',
                        loading: () => '0 ${'items'.tr()}',
                        error: (_, __) => '0 ${'items'.tr()}',
                      ),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
