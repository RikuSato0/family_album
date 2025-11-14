import 'package:auto_route/auto_route.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/url_helper.dart';

class ServerConfigGuard extends AutoRouteGuard {
  ServerConfigGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final serverUrl = getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      resolver.redirect(const ServerConfigRoute());
    } else {
      resolver.next(true);
    }
  }
} 