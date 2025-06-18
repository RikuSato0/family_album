import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/backup/backup.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/oauth.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/provider_utils.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:immich_mobile/utils/version_compatibility.dart';
import 'package:immich_mobile/widgets/common/immich_logo.dart';
import 'package:immich_mobile/widgets/common/immich_title_text.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/forms/login/email_input.dart';
import 'package:immich_mobile/widgets/forms/login/loading_icon.dart';
import 'package:immich_mobile/widgets/forms/login/login_button.dart';
import 'package:immich_mobile/widgets/forms/login/o_auth_login_button.dart';
import 'package:immich_mobile/widgets/forms/login/password_input.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class LoginForm extends HookConsumerWidget {
  LoginForm({super.key});

  final log = Logger('LoginForm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController =
        useTextEditingController.fromValue(TextEditingValue.empty);
    final passwordController =
        useTextEditingController.fromValue(TextEditingValue.empty);
    final emailFocusNode = useFocusNode();
    final passwordFocusNode = useFocusNode();
    final isLoading = useState<bool>(false);
    final isLoadingServer = useState<bool>(false);
    final isOauthEnable = useState<bool>(false);
    final isPasswordLoginEnable = useState<bool>(false);
    final oAuthButtonLabel = useState<String>('OAuth');
    final logoAnimationController = useAnimationController(
      duration: const Duration(seconds: 60),
    )..repeat();
    final serverInfo = ref.watch(serverInfoProvider);
    final warningMessage = useState<String?>(null);
    final loginFormKey = GlobalKey<FormState>();
    final hasApiEndpoint = useState<bool>(false);

    checkVersionMismatch() async {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final appVersion = packageInfo.version;
        final appMajorVersion = int.parse(appVersion.split('.')[0]);
        final appMinorVersion = int.parse(appVersion.split('.')[1]);
        final serverMajorVersion = serverInfo.serverVersion.major;
        final serverMinorVersion = serverInfo.serverVersion.minor;

        warningMessage.value = getVersionCompatibilityMessage(
          appMajorVersion,
          appMinorVersion,
          serverMajorVersion,
          serverMinorVersion,
        );
      } catch (error) {
        warningMessage.value = 'Error checking version compatibility';
      }
    }

    /// Check if API endpoint is configured and get server auth settings
    Future<void> checkApiEndpointAndGetServerInfo() async {
      final serverUrl = getServerUrl();

      if (serverUrl == null || serverUrl.isEmpty) {
        hasApiEndpoint.value = false;
        return;
      }

      try {
        isLoadingServer.value = true;
        hasApiEndpoint.value = true;

        // Fetch and load server config and features
        await ref.read(serverInfoProvider.notifier).getServerInfo();

        final serverInfo = ref.read(serverInfoProvider);
        final features = serverInfo.serverFeatures;
        final config = serverInfo.serverConfig;

        isOauthEnable.value = features.oauthEnabled;
        isPasswordLoginEnable.value = features.passwordLogin;
        oAuthButtonLabel.value = config.oauthButtonText.isNotEmpty
            ? config.oauthButtonText
            : 'OAuth';
      } on ApiException catch (e) {
        ImmichToast.show(
          context: context,
          msg: e.message ?? 'login_form_api_exception'.tr(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
        isOauthEnable.value = false;
        isPasswordLoginEnable.value = true;
      } on HandshakeException {
        ImmichToast.show(
          context: context,
          msg: 'login_form_handshake_exception'.tr(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
        isOauthEnable.value = false;
        isPasswordLoginEnable.value = true;
      } catch (e) {
        ImmichToast.show(
          context: context,
          msg: 'login_form_server_error'.tr(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
        isOauthEnable.value = false;
        isPasswordLoginEnable.value = true;
      } finally {
        isLoadingServer.value = false;
      }
    }

    useEffect(
      () {
        checkApiEndpointAndGetServerInfo();
        return null;
      },
      [],
    );

    populateTestLoginInfo() {
      emailController.text = 'demo@immich.app';
      passwordController.text = 'demo';
    }

    populateTestLoginInfo1() {
      emailController.text = 'testuser@email.com';
      passwordController.text = 'password';
    }

    login() async {
      if (!hasApiEndpoint.value) {
        ImmichToast.show(
          context: context,
          msg: 'Please configure API endpoint in settings first',
          toastType: ToastType.error,
        );
        return;
      }

      TextInput.finishAutofillContext();

      isLoading.value = true;

      // Invalidate all api repository provider instance to take into account new access token
      invalidateAllApiRepositoryProviders(ref);

      try {
        final result = await ref.read(authProvider.notifier).login(
              emailController.text,
              passwordController.text,
            );

        if (result.shouldChangePassword && !result.isAdmin) {
          context.pushRoute(const ChangePasswordRoute());
        } else {
          context.replaceRoute(const TabControllerRoute());
        }
      } catch (error) {
        ImmichToast.show(
          context: context,
          msg: "login_form_failed_login".tr(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
      } finally {
        isLoading.value = false;
      }
    }

    String generateRandomString(int length) {
      const chars =
          'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
      final random = Random.secure();
      return String.fromCharCodes(
        Iterable.generate(
          length,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
    }

    List<int> randomBytes(int length) {
      final random = Random.secure();
      return List<int>.generate(length, (i) => random.nextInt(256));
    }

    /// Per specification, the code verifier must be 43-128 characters long
    /// and consist of characters [A-Z, a-z, 0-9, "-", ".", "_", "~"]
    String randomCodeVerifier() {
      return base64Url.encode(randomBytes(42));
    }

    Future<String> generatePKCECodeChallenge(String codeVerifier) async {
      var bytes = utf8.encode(codeVerifier);
      var digest = sha256.convert(bytes);
      return base64Url.encode(digest.bytes).replaceAll('=', '');
    }

    oAuthLogin() async {
      if (!hasApiEndpoint.value) {
        ImmichToast.show(
          context: context,
          msg: 'Please configure API endpoint in settings first',
          toastType: ToastType.error,
        );
        return;
      }

      var oAuthService = ref.watch(oAuthServiceProvider);
      String? oAuthServerUrl;

      final state = generateRandomString(32);
      final codeVerifier = randomCodeVerifier();
      final codeChallenge = await generatePKCECodeChallenge(codeVerifier);

      final serverUrl = getServerUrl();
      if (serverUrl == null) {
        ImmichToast.show(
          context: context,
          msg: 'Please configure API endpoint in settings first',
          toastType: ToastType.error,
        );
        return;
      }

      try {
        oAuthServerUrl = await oAuthService.getOAuthServerUrl(
          sanitizeUrl(serverUrl),
          state,
          codeChallenge,
        );

        isLoading.value = true;

        // Invalidate all api repository provider instance to take into account new access token
        invalidateAllApiRepositoryProviders(ref);
      } catch (error, stack) {
        log.severe('Error getting OAuth server Url: $error', stack);

        ImmichToast.show(
          context: context,
          msg: "login_form_failed_get_oauth_server_config".tr(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
        isLoading.value = false;
        return;
      }

      try {
        final loginResponseDto = await oAuthService.oAuthLogin(
          oAuthServerUrl!,
          state,
          codeVerifier,
        );

        if (loginResponseDto == null) {
          return;
        }

        log.info(
          "Finished OAuth login with response: ${loginResponseDto.userEmail}",
        );

        final isSuccess = await ref.watch(authProvider.notifier).saveAuthInfo(
              accessToken: loginResponseDto.accessToken,
            );

        if (isSuccess) {
          isLoading.value = false;
          final permission = ref.watch(galleryPermissionNotifier);
          if (permission.isGranted || permission.isLimited) {
            ref.watch(backupProvider.notifier).resumeBackup();
          }
          context.replaceRoute(const TabControllerRoute());
        }
      } catch (error, stack) {
        log.severe('Error logging in with OAuth: $error', stack);

        ImmichToast.show(
          context: context,
          msg: error.toString(),
          toastType: ToastType.error,
          gravity: ToastGravity.TOP,
        );
      } finally {
        isLoading.value = false;
      }
    }

    buildVersionCompatWarning() {
      checkVersionMismatch();

      if (warningMessage.value == null) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                context.isDarkTheme ? Colors.red.shade700 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  context.isDarkTheme ? Colors.red.shade900 : Colors.red[200]!,
            ),
          ),
          child: Text(
            warningMessage.value!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    buildApiNotConfiguredWarning() {
      if (hasApiEndpoint.value) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.isDarkTheme
                ? Colors.orange.shade800
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.isDarkTheme
                  ? Colors.orange.shade600
                  : Colors.orange.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange.shade700,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'API endpoint not configured',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Please configure your server API endpoint in settings to continue',
                style: TextStyle(
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.pushRoute(const SettingsRoute()),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    buildLogin() {
      return AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildVersionCompatWarning(),
            buildApiNotConfiguredWarning(),
            if (hasApiEndpoint.value) ...[
              // Text(
              //   sanitizeUrl(getServerUrl() ?? ''),
              //   style: context.textTheme.displaySmall,
              //   textAlign: TextAlign.center,
              // ),
              const SizedBox(height: 18),
              EmailInput(
                controller: emailController,
                focusNode: emailFocusNode,
                onSubmit: passwordFocusNode.requestFocus,
              ),
              const SizedBox(height: 8),
              PasswordInput(
                controller: passwordController,
                focusNode: passwordFocusNode,
                onSubmit: login,
              ),
              const SizedBox(height: 18),
            ],

            // Note: This used to have an AnimatedSwitcher, but was removed
            // because of https://github.com/flutter/flutter/issues/120874
            if (isLoadingServer.value)
              const LoadingIcon()
            else if (isLoading.value)
              const LoadingIcon()
            else if (hasApiEndpoint.value)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPasswordLoginEnable.value)
                    LoginButton(onPressed: login),
                  if (isOauthEnable.value) ...[
                    if (isPasswordLoginEnable.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                        ),
                        child: Divider(
                          color:
                              context.isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ),
                    OAuthLoginButton(
                      serverEndpointController: TextEditingController(
                        text: getServerUrl() ?? '',
                      ),
                      buttonLabel: oAuthButtonLabel.value,
                      isLoading: isLoading,
                      onPressed: oAuthLogin,
                    ),
                  ],
                  if (!isOauthEnable.value && !isPasswordLoginEnable.value)
                    Center(
                      child: const Text('login_disabled').tr(),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: constraints.maxHeight / 5,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onDoubleTap: () => populateTestLoginInfo(),
                              onLongPress: () => populateTestLoginInfo1(),
                              child: RotationTransition(
                                turns: logoAnimationController,
                                child: const ImmichLogo(
                                  heroTag: 'logo',
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0, bottom: 16),
                              child: ImmichTitleText(),
                            ),
                          ],
                        ),

                        // Note: This used to have an AnimatedSwitcher, but was removed
                        // because of https://github.com/flutter/flutter/issues/120874
                        Form(
                          key: loginFormKey,
                          child: buildLogin(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Settings button in top right corner
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: context.isDarkTheme
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => context.pushRoute(const SettingsRoute()),
                icon: Icon(
                  Icons.settings_rounded,
                  color: context.isDarkTheme ? Colors.white : Colors.black,
                ),
                tooltip: 'Settings',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
