import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:immich_mobile/widgets/common/immich_logo.dart';
import 'package:immich_mobile/widgets/common/immich_title_text.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/forms/login/server_endpoint_input.dart';
import 'package:immich_mobile/entities/store.entity.dart' as immichStore;
import 'package:immich_mobile/domain/models/store.model.dart';

@RoutePage()
class ServerConfigPage extends HookConsumerWidget {
  const ServerConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immichUrlController = useTextEditingController();
    final nextcloudUrlController = useTextEditingController();
    final immichUrlFocusNode = useFocusNode();
    final nextcloudUrlFocusNode = useFocusNode();
    final nextcloudUserController = useTextEditingController();
    final nextcloudPasswordController = useTextEditingController();
    final nextcloudUserFocusNode = useFocusNode();
    final nextcloudPasswordFocusNode = useFocusNode();
    final isLoading = useState<bool>(false);
    final isConnected = useState<bool>(false);
    final serverInfo = ref.watch(serverInfoProvider);

    String? validateImmichUrl(String? url) {
      if (url == null || url.isEmpty) {
        return 'Server URL is required'.tr();
      }
      final parsedUrl = Uri.tryParse(sanitizeUrl(url));
      if (parsedUrl == null ||
          !parsedUrl.isAbsolute ||
          !parsedUrl.scheme.startsWith("http") ||
          parsedUrl.host.isEmpty) {
        return 'Please enter a valid server URL'.tr();
      }
      return null;
    }

    String? validateNextcloudUrl(String? url) {
      if (url == null || url.isEmpty) {
        return null; // Optional
      }
      final parsedUrl = Uri.tryParse(sanitizeUrl(url));
      if (parsedUrl == null ||
          !parsedUrl.isAbsolute ||
          !parsedUrl.scheme.startsWith("http") ||
          parsedUrl.host.isEmpty) {
        return 'Please enter a valid server URL'.tr();
      }
      return null;
    }

    Future<void> testConnection() async {
      final validationError = validateImmichUrl(immichUrlController.text);
      if (validationError != null) {
        ImmichToast.show(
          context: context,
          msg: validationError,
          toastType: ToastType.error,
        );
        return;
      }
      try {
        isLoading.value = true;
        isConnected.value = false;
        final sanitizedUrl = sanitizeUrl(immichUrlController.text);
        final serverUrl = punycodeEncodeUrl(sanitizedUrl);
        await ref.read(authProvider.notifier).validateServerUrl(serverUrl);
        await ref.read(serverInfoProvider.notifier).getServerInfo();
        isConnected.value = true;
        ImmichToast.show(
          context: context,
          msg: 'Successfully connected to server!'.tr(),
          toastType: ToastType.success,
        );
      } catch (e) {
        isConnected.value = false;
        ImmichToast.show(
          context: context,
          msg: 'Failed to connect to server. Please check your URL and try again.'.tr(),
          toastType: ToastType.error,
        );
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      // Use StoreKey.serverEndpoint for Immich and StoreKey.localEndpoint for Nextcloud
      final savedImmichUrl = immichStore.Store.tryGet(StoreKey.serverEndpoint) ?? getServerUrl();
      final savedNextcloudUrl = immichStore.Store.tryGet(StoreKey.localEndpoint);
      final savedNextcloudUser = immichStore.Store.tryGet(StoreKey.nextcloudUser);
      final savedNextcloudPassword = immichStore.Store.tryGet(StoreKey.nextcloudPassword);
      if (savedImmichUrl != null && savedImmichUrl.isNotEmpty) {
        immichUrlController.text = savedImmichUrl;
        testConnection();
      }
      if (savedNextcloudUrl != null && savedNextcloudUrl.isNotEmpty) {
        nextcloudUrlController.text = savedNextcloudUrl;
      }
      if (savedNextcloudUser != null && savedNextcloudUser.isNotEmpty) {
        nextcloudUserController.text = savedNextcloudUser;
      }
      if (savedNextcloudPassword != null && savedNextcloudPassword.isNotEmpty) {
        nextcloudPasswordController.text = savedNextcloudPassword;
      }
      return null;
    }, []);

    void continueToLogin() {
      if (!isConnected.value) {
        ImmichToast.show(
          context: context,
          msg: 'Please connect to a server first'.tr(),
          toastType: ToastType.error,
        );
        return;
      }
      // Save both URLs and Nextcloud credentials
      immichStore.Store.put(StoreKey.serverEndpoint, immichUrlController.text);
      immichStore.Store.put(StoreKey.localEndpoint, nextcloudUrlController.text);
      immichStore.Store.put(StoreKey.nextcloudUser, nextcloudUserController.text);
      immichStore.Store.put(StoreKey.nextcloudPassword, nextcloudPasswordController.text);
      context.pushRoute(const LoginRoute());
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ImmichLogo(heroTag: 'logo'),
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: ImmichTitleText(),
                    ),
                    Text(
                      'Connect to your server'.tr(),
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                // Server Configuration Form
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Immich URL
                    ServerEndpointInput(
                      controller: immichUrlController,
                      focusNode: immichUrlFocusNode,
                      onSubmit: testConnection,
                    ),
                    const SizedBox(height: 16),
                    // Nextcloud URL
                    TextFormField(
                      controller: nextcloudUrlController,
                      focusNode: nextcloudUrlFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Nextcloud Server URL',
                        border: const OutlineInputBorder(),
                        hintText: 'https://nextcloud.example.com',
                        errorMaxLines: 4,
                      ),
                      validator: validateNextcloudUrl,
                      autovalidateMode: AutovalidateMode.always,
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => nextcloudUserFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    // Nextcloud Username
                    TextFormField(
                      controller: nextcloudUserController,
                      focusNode: nextcloudUserFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Nextcloud Username',
                        border: const OutlineInputBorder(),
                        hintText: 'user',
                        errorMaxLines: 2,
                      ),
                      keyboardType: TextInputType.text,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => nextcloudPasswordFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    // Nextcloud Password
                    TextFormField(
                      controller: nextcloudPasswordController,
                      focusNode: nextcloudPasswordFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Nextcloud Password',
                        border: const OutlineInputBorder(),
                        hintText: '••••••••',
                        errorMaxLines: 2,
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isLoading.value ? null : testConnection,
                        icon: isLoading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find_rounded),
                        label: Text(
                          isLoading.value
                              ? 'Testing...'.tr()
                              : 'Test Connection'.tr(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colorScheme.primary,
                          foregroundColor: context.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isConnected.value) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.isDarkTheme
                              ? Colors.green.shade900.withOpacity(0.2)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connected to server!'.tr(),
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (serverInfo.serverVersion != null)
                                    Text(
                                      'Server version: ${serverInfo.serverVersion}'.tr(
                                        args: [serverInfo.serverVersion.toString()],
                                      ),
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isConnected.value ? continueToLogin : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colorScheme.primary,
                          foregroundColor: context.colorScheme.onPrimary,
                        ),
                        child: Text('Continue to Login'.tr()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter your Immich server URL (e.g., http://192.168.1.100:2283 or https://immich.yourdomain.com)'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 