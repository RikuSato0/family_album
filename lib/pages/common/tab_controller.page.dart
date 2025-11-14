import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/album/album.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/scroll_notifier.provider.dart';
import 'package:immich_mobile/providers/multiselect.provider.dart';
import 'package:immich_mobile/providers/search/search_input_focus.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/providers/haptic_feedback.provider.dart';
import 'package:immich_mobile/providers/tab.provider.dart';
import 'package:immich_mobile/widgets/common/app_bar_dialog/app_bar_dialog.dart';
import 'package:immich_mobile/widgets/common/user_circle_avatar.dart';

@RoutePage()
class TabControllerPage extends HookConsumerWidget {
  const TabControllerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefreshingAssets = ref.watch(assetProvider);
    final isRefreshingRemoteAlbums = ref.watch(isRefreshingRemoteAlbumProvider);
    final isScreenLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    Widget buildIcon({required Widget icon, required bool isProcessing}) {
      if (!isProcessing) return icon;
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -18,
            child: SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.primaryColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget navIconWrapper(Widget icon) {
      return SizedBox(
        width: 50,
        height: 50,
        child: Center(child: icon),
      );
    }

    void onNavigationSelected(TabsRouter router, int index) {
      ref.read(hapticFeedbackProvider.notifier).selectionClick();

      // If "Settings" tab clicked
      if (index == 2) {
        context.pushRoute(const SettingsRoute());
        return; // Do not change active tab
      }

      // If "Profile" tab clicked
      if (index == 3) {
        showDialog(
          context: context,
          builder: (ctx) => const ImmichAppBarDialog(),
        );
        return; // Do not change active tab
      }

      // Handle actual tab navigation
      if (router.activeIndex == 0 && index == 0) {
        scrollToTopNotifierProvider.scrollToTop();
      }

      if (router.activeIndex == 1 && index == 1) {
        ref.read(searchInputFocusProvider).requestFocus();
      }

      router.setActiveIndex(index);
      ref.read(tabProvider.notifier).state = TabEnum.values[index];
    }

    final navigationDestinations = [
      // NavigationDestination(
      //   label: 'photos'.tr(),
      //   icon: const Icon(
      //     Icons.photo_library_outlined,
      //   ),
      //   selectedIcon: buildIcon(
      //     isProcessing: isRefreshingAssets,
      //     icon: Icon(
      //       Icons.photo_library,
      //       color: context.primaryColor,
      //     ),
      //   ),
      // ),
      // NavigationDestination(
      //   label: 'search'.tr(),
      //   icon: const Icon(
      //     Icons.search_rounded,
      //   ),
      //   selectedIcon: Icon(
      //     Icons.search,
      //     color: context.primaryColor,
      //   ),
      // ),
      // NavigationDestination(
      //   label: 'albums'.tr(),
      //   icon: const Icon(
      //     Icons.photo_album_outlined,
      //   ),
      //   selectedIcon: buildIcon(
      //     isProcessing: isRefreshingRemoteAlbums,
      //     icon: Icon(
      //       Icons.photo_album_rounded,
      //       color: context.primaryColor,
      //     ),
      //   ),
      // ),
      NavigationDestination(
        label: 'photos'.tr(),
        icon: navIconWrapper(
          Image.asset(
            'assets/navigator/photos.png',
            color: Colors.grey,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        selectedIcon: navIconWrapper(
          buildIcon(
            isProcessing: isRefreshingAssets,
            icon: Container(
              // decoration: BoxDecoration(
              //   color: const Color.fromARGB(255, 251, 247, 255),
              //   borderRadius: BorderRadius.circular(20),
              // ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/navigator/photos.png'),
            ),
          ),
        ),
      ),
      NavigationDestination(
        label: 'files'.tr(),
        icon: navIconWrapper(
          Image.asset(
            'assets/navigator/files.png',
            color: Colors.grey,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        selectedIcon: navIconWrapper(
          buildIcon(
            isProcessing: isRefreshingRemoteAlbums,
            icon: Container(
              // decoration: BoxDecoration(
              //   color: const Color.fromARGB(255, 251, 247, 255),
              //   borderRadius: BorderRadius.circular(20),
              // ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/navigator/files.png'),
            ),
          ),
        ),
      ),
      NavigationDestination(
        label: 'settings'.tr(),
        icon: navIconWrapper(
          const Icon(Icons.settings, color: Colors.grey),
        ),
        selectedIcon: navIconWrapper(
          Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 251, 247, 255),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.settings, color: context.primaryColor),
          ),
        ),
      ),
      NavigationDestination(
        label: 'profile'.tr(),
        icon: navIconWrapper(
          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(currentUserProvider);
              return user == null
                  ? const Icon(Icons.person_outline, color: Colors.grey)
                  : UserCircleAvatar(radius: 17, size: 34, user: user);
            },
          ),
        ),
        selectedIcon: navIconWrapper(
          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(currentUserProvider);
              return Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 251, 247, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(4),
                child: user == null
                    ? Icon(Icons.person, color: context.primaryColor)
                    : UserCircleAvatar(radius: 17, size: 34, user: user),
              );
            },
          ),
        ),
      ),
    ];

    Widget bottomNavigationBar(TabsRouter tabsRouter) {
      return NavigationBar(
        selectedIndex: tabsRouter.activeIndex,
        onDestinationSelected: (index) =>
            onNavigationSelected(tabsRouter, index),
        destinations: navigationDestinations,
      );
    }

    Widget navigationRail(TabsRouter tabsRouter) {
      return NavigationRail(
        destinations: navigationDestinations
            .map(
              (e) => NavigationRailDestination(
                icon: e.icon,
                label: Text(e.label),
                selectedIcon: e.selectedIcon,
              ),
            )
            .toList(),
        onDestinationSelected: (index) =>
            onNavigationSelected(tabsRouter, index),
        selectedIndex: tabsRouter.activeIndex,
        labelType: NavigationRailLabelType.all,
        groupAlignment: 0.0,
      );
    }

    final multiselectEnabled = ref.watch(multiselectProvider);
    return AutoTabsRouter(
      routes: [
        const LibraryRoute(),
        const FileBrowserRoute(),
        // const PhotosRoute(),
        // SearchRoute(),
      ],
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (context, child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        final heroedChild = HeroControllerScope(
          controller: HeroController(),
          child: child,
        );
        return PopScope(
          canPop: tabsRouter.activeIndex == 0,
          onPopInvokedWithResult: (didPop, _) =>
              !didPop ? tabsRouter.setActiveIndex(0) : null,
          child: 
          Theme(
            data: Theme.of(context).copyWith(
              navigationBarTheme: const NavigationBarThemeData(
                indicatorColor: Colors.transparent,
                overlayColor: MaterialStatePropertyAll(Colors.transparent),
              ),
              navigationRailTheme: const NavigationRailThemeData(
                indicatorColor: Colors.transparent,
              ),
            ),
            child:
          Scaffold(
            resizeToAvoidBottomInset: false,
            body: isScreenLandscape
                ? Row(
                    children: [
                      navigationRail(tabsRouter),
                      const VerticalDivider(),
                      Expanded(child: heroedChild),
                    ],
                  )
                : heroedChild,
            bottomNavigationBar: multiselectEnabled || isScreenLandscape
                ? null
                : bottomNavigationBar(tabsRouter),
          ),
          ),
        );
      },
    );
  }
}
