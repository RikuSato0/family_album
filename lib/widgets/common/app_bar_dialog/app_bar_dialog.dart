import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/models/backup/backup_state.model.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/backup/backup.provider.dart';
import 'package:immich_mobile/providers/backup/manual_upload.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/providers/websocket.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/bytes_units.dart';
import 'package:immich_mobile/widgets/common/app_bar_dialog/app_bar_profile_info.dart';
import 'package:immich_mobile/widgets/common/app_bar_dialog/app_bar_server_info.dart';
import 'package:immich_mobile/widgets/common/confirm_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ImmichAppBarDialog extends HookConsumerWidget {
  const ImmichAppBarDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    BackUpState backupState = ref.watch(backupProvider);
    final theme = context.themeData;
    bool isHorizontal = !context.isMobile;
    final horizontalPadding = isHorizontal ? 100.0 : 20.0;
    final user = ref.watch(currentUserProvider);
    final isLoggingOut = useState(false);

    useEffect(
      () {
        ref.read(backupProvider.notifier).updateDiskInfo();
        ref.read(currentUserProvider.notifier).refresh();
        return null;
      },
      [],
    );

    Widget buildHeader() {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Close button row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // App Title
            Text(
              'Family Hub',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1), // Purple color matching the image
              ),
            ),
            const SizedBox(height: 32),
            // Profile Avatar with Online Status
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: user?.profileImagePath != null
                      ? ClipOval(
                          child: Image.network(
                            user!.profileImagePath!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to initials if image fails to load
                              return Center(
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name
                                              .substring(0, 1)
                                              .toUpperCase() +
                                          (user.name.split(' ').length > 1
                                              ? user.name
                                                  .split(' ')[1]
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '')
                                      : 'U',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            user?.name != null && user!.name.isNotEmpty
                                ? user!.name.substring(0, 1).toUpperCase() +
                                    (user!.name.split(' ').length > 1
                                        ? user!.name
                                            .split(' ')[1]
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : '')
                                : 'SJ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981), // Green online indicator
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildUserInfo() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Full Name Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFDDD6FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.name ?? 'Sarah Johnson',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Email Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.email_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'sarah.johnson@email.com',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget buildLogOutButton() {
      return Container(
        margin: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoggingOut.value
                ? null
                : () async {
                    if (isLoggingOut.value) {
                      return;
                    }

                    showDialog(
                      context: context,
                      builder: (BuildContext ctx) {
                        return ConfirmDialog(
                          title: "app_bar_signout_dialog_title",
                          content: "app_bar_signout_dialog_content",
                          ok: "yes",
                          onOk: () async {
                            isLoggingOut.value = true;
                            await ref
                                .read(authProvider.notifier)
                                .logout()
                                .whenComplete(() => isLoggingOut.value = false);

                            ref.read(manualUploadProvider.notifier).cancelBackup();
                            ref.read(backupProvider.notifier).cancelBackup();
                            ref.read(assetProvider.notifier).clearAllAssets();
                            ref.read(websocketProvider.notifier).disconnect();
                            context.replaceRoute(const LoginRoute());
                          },
                        );
                      },
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Color(0xFFEF4444), // Red color matching the image
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoggingOut.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(Icons.logout_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildBottomDots() {
      return Container(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      );
    }

    return Dismissible(
      behavior: HitTestBehavior.translucent,
      direction: DismissDirection.down,
      onDismissed: (_) => context.pop(),
      key: const Key('family_hub_dialog'),
      child: Dialog(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.only(
          top: isHorizontal ? 20 : 60,
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: isHorizontal ? 20 : 120,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildHeader(),
                buildUserInfo(),
                const SizedBox(height: 24),
                buildLogOutButton(),
                buildBottomDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
