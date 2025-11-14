import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/models/search/search_curated_content.model.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/interfaces/person_api.interface.dart';
import 'package:immich_mobile/services/search.service.dart';

final getPreviewPlacesProvider =
    FutureProvider.autoDispose<List<SearchCuratedContent>>((ref) async {
  final SearchService searchService = ref.watch(searchServiceProvider);

  final exploreData = await searchService.getExploreData();

  if (exploreData == null) {
    return [];
  }

  final locations =
      exploreData.firstWhere((data) => data.fieldName == "exifInfo.city").items;

  final curatedContent = locations
      .map(
        (l) => SearchCuratedContent(
          label: l.value,
          id: l.data.id,
        ),
      )
      .toList();

  return curatedContent;
});

final getAllPlacesProvider =
    FutureProvider.autoDispose<List<SearchCuratedContent>>((ref) async {
  final SearchService searchService = ref.watch(searchServiceProvider);

  print("🔍 DEBUG getAllPlacesProvider: Starting to fetch places...");
  
  final assetPlaces = await searchService.getAllPlaces();

  print("📡 DEBUG getAllPlacesProvider: API returned ${assetPlaces?.length ?? 0} assets");

  if (assetPlaces == null) {
    print("❌ DEBUG getAllPlacesProvider: API returned null");
    return [];
  }

  if (assetPlaces.isEmpty) {
    print("❌ DEBUG getAllPlacesProvider: API returned empty list");
    print("💡 This means:");
    print("   1. Your photos don't have city EXIF data");
    print("   2. Photos haven't been processed for location metadata yet");  
    print("   3. Try uploading photos with GPS/location data");
    return [];
  }

  // 🔧 Filter out assets with no city data and handle null cities safely
  final validAssets = assetPlaces.where((data) => 
    data.exifInfo != null && 
    data.exifInfo!.city != null && 
    data.exifInfo!.city!.isNotEmpty
  ).toList();

  print("🏙️ DEBUG: ${validAssets.length} assets have valid city data out of ${assetPlaces.length} total");
  
  // 📊 Debug: Show why assets were filtered out
  if (validAssets.length < assetPlaces.length) {
    print("🔍 DEBUG: Why some assets were filtered out:");
    for (var asset in assetPlaces.take(5)) {
      final hasExif = asset.exifInfo != null;
      final hasCity = hasExif && asset.exifInfo!.city != null;
      final cityNotEmpty = hasCity && asset.exifInfo!.city!.isNotEmpty;
      print("📍 ${asset.originalFileName}: ExifInfo=$hasExif, City=$hasCity, CityNotEmpty=$cityNotEmpty");
      if (hasExif && asset.exifInfo!.city != null) {
        print("   City value: '${asset.exifInfo!.city}'");
      }
    }
  }

  final curatedContent = validAssets
      .map(
        (data) => SearchCuratedContent(
          label: data.exifInfo!.city!, // Now safe because we filtered for non-null cities
          id: data.id,
        ),
      )
      .toList();

  print("✅ DEBUG getAllPlacesProvider: Created ${curatedContent.length} curated places");
  for (var place in curatedContent.take(3)) {
    print("📍 Place: ${place.label} (ID: ${place.id})");
  }

  return curatedContent;
});

// 🎯 Provider to get assets for a specific city/place
final getAssetsByCityProvider = FutureProvider.family<List<Asset>, String>((ref, cityName) async {
  final SearchService searchService = ref.watch(searchServiceProvider);

  // Create a search filter for the specific city
  final searchFilter = SearchFilter(
    people: <Person>{},
    location: SearchLocationFilter(city: cityName),
    camera: SearchCameraFilter(),
    date: SearchDateFilter(),
    display: SearchDisplayFilters(
      isNotInAlbum: false,
      isArchive: false,
      isFavorite: false,
    ),
    mediaType: AssetType.other, // Get all media types
  );

  // Search for assets in this city
  final searchResult = await searchService.search(searchFilter, 1);
  
  return searchResult?.assets ?? [];
});
