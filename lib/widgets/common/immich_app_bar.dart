import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/models/backup/backup_state.model.dart';
import 'package:immich_mobile/models/server_info/server_info.model.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/backup/backup.provider.dart';
import 'package:immich_mobile/providers/backup/manual_upload.provider.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/app_bar_dialog/app_bar_dialog.dart';
import 'package:immich_mobile/widgets/common/user_circle_avatar.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

final selectedImageProvider = StateProvider<File?>((ref) => null);

class ImmichAppBar extends ConsumerWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  final List<Widget>? actions;
  final bool showUploadButton;
  final bool showProfileButton;
  final bool showRefreshButton;
  final String? title;

  const ImmichAppBar({
    super.key,
    this.actions,
    this.showUploadButton = true,
    this.title,
    this.showProfileButton = true,
    this.showRefreshButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BackUpState backupState = ref.watch(backupProvider);
    final bool isEnableAutoBackup =
        backupState.backgroundBackup || backupState.autoBackup;
    final ServerInfo serverInfoState = ref.watch(serverInfoProvider);
    final user = ref.watch(currentUserProvider);
    final isDarkTheme = context.isDarkTheme;
    const widgetSize = 30.0;
    final manualUploadState = ref.watch(manualUploadProvider);

    buildProfileIndicator() {
      return InkWell(
        onTap: () => showDialog(
          context: context,
          useRootNavigator: false,
          builder: (ctx) => const ImmichAppBarDialog(),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Badge(
          label: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(widgetSize / 2),
            ),
            child: const Icon(
              Icons.info,
              color: Color.fromARGB(255, 243, 188, 106),
              size: widgetSize / 2,
            ),
          ),
          backgroundColor: Colors.transparent,
          alignment: Alignment.bottomRight,
          isLabelVisible: serverInfoState.isVersionMismatch ||
              ((user?.isAdmin ?? false) &&
                  serverInfoState.isNewReleaseAvailable),
          offset: const Offset(-2, -12),
          child: user == null
              ? const Icon(
                  Icons.face_outlined,
                  size: widgetSize,
                )
              : UserCircleAvatar(
                  radius: 17,
                  size: 31,
                  user: user,
                ),
        ),
      );
    }

    getBackupBadgeIcon() {
      final iconColor = isDarkTheme ? Colors.white : Colors.black;

      if (isEnableAutoBackup) {
        if (backupState.backupProgress == BackUpProgressEnum.inProgress) {
          return Container(
            padding: const EdgeInsets.all(3.5),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              semanticsLabel: 'backup_controller_page_backup'.tr(),
            ),
          );
        } else if (backupState.backupProgress !=
                BackUpProgressEnum.inBackground &&
            backupState.backupProgress != BackUpProgressEnum.manualInProgress) {
          return Icon(
            Icons.check_outlined,
            size: 9,
            color: iconColor,
            semanticLabel: 'backup_controller_page_backup'.tr(),
          );
        }
      }

      if (!isEnableAutoBackup) {
        return Icon(
          Icons.cloud_off_rounded,
          size: 9,
          color: iconColor,
          semanticLabel: 'backup_controller_page_backup'.tr(),
        );
      }
    }

    buildUpload() {
      final badgeBackground = context.colorScheme.surfaceContainer;
      final isUploading = manualUploadState.progressInPercentage > 0;
      final uploadProgress = manualUploadState.progressInPercentage;

      return InkWell(
        onTap: isUploading ? null : () async {
          try {
            // 🎯 REAL IMMICH SERVER INTEGRATION WITH PHOTOMANAGER
            print("🚀 Starting real photo upload to Immich server...");
            
            // Step 1: Request permission
            final PermissionState permission = await PhotoManager.requestPermissionExtend();
            if (!permission.isAuth) {
              if (context.mounted) {
                ImmichToast.show(
                  context: context,
                  msg: 'permission_required'.tr(),
                  toastType: ToastType.error,
                  gravity: ToastGravity.TOP,
                );
              }
              return;
            }

            // Step 2: Get recent photos from device gallery
            final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
              type: RequestType.image,
              onlyAll: true, // Get the "All Photos" album
            );

            if (albums.isEmpty) {
              if (context.mounted) {
                ImmichToast.show(
                  context: context,
                  msg: 'no_photos_found'.tr(),
                  toastType: ToastType.error,
                  gravity: ToastGravity.TOP,
                );
              }
              return;
            }

            // Step 3: Get recent photos from the main album
            final AssetPathEntity mainAlbum = albums.first;
            final List<AssetEntity> recentPhotos = await mainAlbum.getAssetListRange(
              start: 0,
              end: 20, // Get 20 most recent photos
            );

            if (recentPhotos.isEmpty) {
              if (context.mounted) {
                ImmichToast.show(
                  context: context,
                  msg: 'no_photos_to_upload'.tr(),
                  toastType: ToastType.error,
                  gravity: ToastGravity.TOP,
                );
              }
              return;
            }

            // Step 4: Show selection dialog
            if (!context.mounted) return;
            
            final AssetEntity? selectedAssetEntity = await showDialog<AssetEntity>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: Text('select_photo_to_upload'.tr()),
                  content: Container(
                    width: double.maxFinite,
                    height: 400,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: recentPhotos.length,
                      itemBuilder: (context, index) {
                        final AssetEntity asset = recentPhotos[index];
                        return GestureDetector(
                          onTap: () => Navigator.of(dialogContext).pop(asset),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AssetEntityImage(
                                asset,
                                fit: BoxFit.cover,
                                thumbnailSize: const ThumbnailSize.square(200),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text('cancel'.tr()),
                    ),
                  ],
                );
              },
            );

            if (selectedAssetEntity == null) {
              print("❌ User cancelled photo selection");
              return;
            }

            print("📷 Selected photo: ${selectedAssetEntity.title}");

            // Step 5: Convert AssetEntity to Asset using the proper method
            final Asset? selectedAsset = AssetMediaRepository.toAsset(selectedAssetEntity);
            
            if (selectedAsset == null) {
              if (context.mounted) {
                ImmichToast.show(
                  context: context,
                  msg: 'could_not_process_image'.tr(),
                  toastType: ToastType.error,
                  gravity: ToastGravity.TOP,
                );
              }
              print("❌ Could not convert AssetEntity to Asset");
              return;
            }

            // Step 6: Upload to Immich server using manual upload provider
            print("📤 Uploading asset to Immich server: ${selectedAsset.fileName}");
            
            if (context.mounted) {
              // Show upload starting notification
              ImmichToast.show(
                context: context,
                msg: 'upload_to_family_hub'.tr(),
                toastType: ToastType.info,
                gravity: ToastGravity.TOP,
              );
              
              // Start the upload using the real manual upload provider
              final success = await ref
                  .read(manualUploadProvider.notifier)
                  .uploadAssets(context, [selectedAsset]);
              
              // Wait a moment for upload process to complete fully
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Reset upload state to re-enable button
              ref.read(manualUploadProvider.notifier).cancelBackup();
              
              if (success && context.mounted) {
                // Show success notification
                ImmichToast.show(
                  context: context,
                  msg: 'upload_success'.tr(),
                  toastType: ToastType.success,
                  gravity: ToastGravity.TOP,
                );
                
                // Refresh assets to show the new upload
                ref.read(assetProvider.notifier).getAllAsset();
              } else if (context.mounted) {
                // Show error notification
                ImmichToast.show(
                  context: context,
                  msg: 'upload_failed'.tr(),
                  toastType: ToastType.error,
                  gravity: ToastGravity.TOP,
                );
              }
            }
            
          } catch (e) {
            print("❌ Upload error: $e");
            
            // Reset upload state to re-enable button even after error
            ref.read(manualUploadProvider.notifier).cancelBackup();
            
            if (context.mounted) {
              ImmichToast.show(
                context: context,
                msg: 'upload_failed'.tr(),
                toastType: ToastType.error,
                gravity: ToastGravity.TOP,
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Badge(
          label: Container(
            width: widgetSize / 2,
            height: widgetSize / 2,
            decoration: BoxDecoration(
              color: badgeBackground,
              border: Border.all(
                color: context.colorScheme.outline.withOpacity(.3),
              ),
              borderRadius: BorderRadius.circular(widgetSize / 2),
            ),
            child: isUploading
                ? CircularProgressIndicator(
                    strokeWidth: 1.5,
                    value: uploadProgress / 100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.primaryColor,
                    ),
                  )
                : const Icon(Icons.cloud_upload, size: 12),
          ),
          backgroundColor: Colors.transparent,
          alignment: Alignment.bottomRight,
          isLabelVisible: true,
          offset: const Offset(-2, -12),
          child: Icon(
            isUploading ? Icons.upload_file : Icons.upload_rounded,
            size: widgetSize,
            color: isUploading ? Colors.orange : context.primaryColor,
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: context.themeData.appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(5),
        ),
      ),
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Builder(
        builder: (BuildContext context) {
          return Row(
            children: [
              Builder(
                builder: (context) {
                  return title != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            title!,
                            style: context.textTheme.titleLarge,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: SvgPicture.asset(
                            context.isDarkTheme
                                ? 'assets/immich-logo-inline-dark.svg'
                                : 'assets/immich-logo-inline-light.svg',
                            height: 40,
                          ),
                        );
                },
              ),
            ],
          );
        },
      ),
      actions: [
        if (actions != null)
          ...actions!.map(
            (action) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: action,
            ),
          ),
        if (kDebugMode)
          if (showRefreshButton)
            IconButton(
              onPressed: () => ref.read(backgroundSyncProvider).sync(),
              icon: const Icon(Icons.sync),
            ),
        if (showUploadButton)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: buildUpload(),
          ),
        if (showProfileButton)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: buildProfileIndicator(),
          ),
      ],
    );
  }
}
