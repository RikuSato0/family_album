import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/constants/locales.dart';
import 'package:immich_mobile/services/localization.service.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:openapi/api.dart';
import 'dart:io';

final Store = StoreService.I;

// Keep minimal enum for router compatibility
enum SettingSection {
  main('Settings', Icons.settings, 'Main Settings');

  final String title;
  final String subtitle;
  final IconData icon;

  const SettingSection(this.title, this.icon, this.subtitle);
}

@RoutePage()
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;
    final languageTextController = useTextEditingController(
      text: locales.keys.firstWhere(
        (countryName) => locales[countryName] == currentLocale,
      ),
    );
    final apiUrlController = useTextEditingController();
    final selectedLocale = useState<Locale>(currentLocale);
    final isLoadingApi = useState<bool>(false);
    final apiConnectionStatus = useState<String?>(null);

    // Load saved API URL on init
    useEffect(() {
      final savedUrl = getServerUrl();
      if (savedUrl != null) {
        apiUrlController.text = savedUrl;
      }
      return null;
    }, []);

    String? _validateApiInput(String? url) {
      if (url == null || url.isEmpty) {
        return 'login_form_server_empty'.tr();
      }

      if ((!url.startsWith("https://") && !url.startsWith("http://"))) {
        return 'login_form_server_error_invalid_url'.tr();
      }

      return null;
    }

    Future<void> testAndSaveApiUrl() async {
      if (_validateApiInput(apiUrlController.text) != null) {
        ImmichToast.show(
          context: context,
          msg: _validateApiInput(apiUrlController.text)!,
          toastType: ToastType.error,
        );
        return;
      }

      final sanitizeServerUrl = sanitizeUrl(apiUrlController.text);
      final serverUrl = punycodeEncodeUrl(sanitizeServerUrl);

      if (serverUrl.isEmpty) {
        ImmichToast.show(
          context: context,
          msg: "login_form_server_empty".tr(),
          toastType: ToastType.error,
        );
        return;
      }

      try {
        isLoadingApi.value = true;
        apiConnectionStatus.value = null;

        // Test the connection first (same as login form)
        final endpoint =
            await ref.read(authProvider.notifier).validateServerUrl(serverUrl);

        // Fetch and load server config and features
        await ref.read(serverInfoProvider.notifier).getServerInfo();

        final serverInfo = ref.read(serverInfoProvider);

        // Save the URL to persistent storage after successful test
        Store.put(StoreKey.serverEndpoint, serverUrl);

        apiConnectionStatus.value =
            "Connected successfully to ${serverInfo.serverVersion.toString()}";

        ImmichToast.show(
          context: context,
          msg: 'API endpoint saved and tested successfully',
          toastType: ToastType.info,
        );
      } on ApiException catch (e) {
        apiConnectionStatus.value =
            "Connection failed: ${e.message ?? 'API Exception'}";
        ImmichToast.show(
          context: context,
          msg: e.message ?? 'login_form_api_exception'.tr(),
          toastType: ToastType.error,
        );
      } on HandshakeException {
        apiConnectionStatus.value = "Connection failed: SSL Handshake error";
        ImmichToast.show(
          context: context,
          msg: 'login_form_handshake_exception'.tr(),
          toastType: ToastType.error,
        );
      } catch (e) {
        apiConnectionStatus.value = "Connection failed: ${e.toString()}";
        ImmichToast.show(
          context: context,
          msg: 'login_form_server_error'.tr(),
          toastType: ToastType.error,
        );
      } finally {
        isLoadingApi.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('settings').tr(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Settings Section
            Card(
              elevation: 0,
              color: context.colorScheme.surfaceContainer,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(12)),
                            color: context.isDarkTheme
                                ? Colors.black26
                                : Colors.white.withAlpha(100),
                          ),
                          padding: const EdgeInsets.all(12.0),
                          child:
                              Icon(Icons.language, color: context.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'setting_languages_title',
                              style: context.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.primaryColor,
                              ),
                            ).tr(),
                            Text(
                              'setting_languages_subtitle',
                              style: context.textTheme.labelMedium,
                            ).tr(),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return DropdownMenu(
                          width: constraints.maxWidth,
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.only(left: 16),
                          ),
                          menuStyle: MenuStyle(
                            shape: WidgetStatePropertyAll<OutlinedBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            backgroundColor: WidgetStatePropertyAll<Color>(
                              context.colorScheme.surfaceContainer,
                            ),
                          ),
                          menuHeight: context.height * 0.5,
                          hintText: "Languages",
                          label: const Text('Languages'),
                          dropdownMenuEntries: locales.keys
                              .map(
                                (countryName) => DropdownMenuEntry(
                                  value: locales[countryName],
                                  label: countryName,
                                ),
                              )
                              .toList(),
                          controller: languageTextController,
                          onSelected: (value) {
                            if (value != null) {
                              selectedLocale.value = value;
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedLocale.value == currentLocale
                            ? null
                            : () {
                                context.setLocale(selectedLocale.value);
                                loadTranslations();
                              },
                        child: const Text('setting_languages_apply').tr(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // API Endpoint Settings Section
            // Card(
            //   elevation: 0,
            //   color: context.colorScheme.surfaceContainer,
            //   shape: const RoundedRectangleBorder(
            //     borderRadius: BorderRadius.all(Radius.circular(16)),
            //   ),
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           children: [
            //             Container(
            //               decoration: BoxDecoration(
            //                 borderRadius:
            //                     const BorderRadius.all(Radius.circular(12)),
            //                 color: context.isDarkTheme
            //                     ? Colors.black26
            //                     : Colors.white.withAlpha(100),
            //               ),
            //               padding: const EdgeInsets.all(12.0),
            //               child: Icon(Icons.api, color: context.primaryColor),
            //             ),
            //             const SizedBox(width: 12),
            //             Column(
            //               crossAxisAlignment: CrossAxisAlignment.start,
            //               children: [
            //                 Text(
            //                   'API Endpoint',
            //                   style: context.textTheme.titleMedium!.copyWith(
            //                     fontWeight: FontWeight.w600,
            //                     color: context.primaryColor,
            //                   ),
            //                 ),
            //                 Text(
            //                   'Configure server API endpoint',
            //                   style: context.textTheme.labelMedium,
            //                 ),
            //               ],
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 16),
            //         TextFormField(
            //           controller: apiUrlController,
            //           decoration: InputDecoration(
            //             labelText: 'login_form_endpoint_url'.tr(),
            //             border: OutlineInputBorder(
            //               borderRadius: BorderRadius.circular(12),
            //             ),
            //             hintText: 'login_form_endpoint_hint'.tr(),
            //             errorMaxLines: 4,
            //           ),
            //           validator: _validateApiInput,
            //           autovalidateMode: AutovalidateMode.onUserInteraction,
            //           keyboardType: TextInputType.url,
            //           autocorrect: false,
            //           textInputAction: TextInputAction.done,
            //           onFieldSubmitted: (_) => testAndSaveApiUrl(),
            //         ),
            //         const SizedBox(height: 12),
            //         SizedBox(
            //           width: double.infinity,
            //           child: ElevatedButton.icon(
            //             onPressed:
            //                 isLoadingApi.value ? null : testAndSaveApiUrl,
            //             icon: isLoadingApi.value
            //                 ? const SizedBox(
            //                     height: 16,
            //                     width: 16,
            //                     child:
            //                         CircularProgressIndicator(strokeWidth: 2),
            //                   )
            //                 : const Icon(Icons.save),
            //             label: Text(isLoadingApi.value
            //                 ? 'Testing...'
            //                 : 'Test & Save API Endpoint'),
            //           ),
            //         ),
            //         if (apiConnectionStatus.value != null) ...[
            //           const SizedBox(height: 12),
            //           Container(
            //             width: double.infinity,
            //             padding: const EdgeInsets.all(12),
            //             decoration: BoxDecoration(
            //               color:
            //                   apiConnectionStatus.value!.startsWith('Connected')
            //                       ? (context.isDarkTheme
            //                           ? Colors.green.shade800
            //                           : Colors.green.shade100)
            //                       : (context.isDarkTheme
            //                           ? Colors.red.shade800
            //                           : Colors.red.shade100),
            //               borderRadius: BorderRadius.circular(8),
            //               border: Border.all(
            //                 color: apiConnectionStatus.value!
            //                         .startsWith('Connected')
            //                     ? (context.isDarkTheme
            //                         ? Colors.green.shade600
            //                         : Colors.green.shade300)
            //                     : (context.isDarkTheme
            //                         ? Colors.red.shade600
            //                         : Colors.red.shade300),
            //               ),
            //             ),
            //             child: Row(
            //               children: [
            //                 Icon(
            //                   apiConnectionStatus.value!.startsWith('Connected')
            //                       ? Icons.check_circle
            //                       : Icons.error,
            //                   color: apiConnectionStatus.value!
            //                           .startsWith('Connected')
            //                       ? Colors.green.shade700
            //                       : Colors.red.shade700,
            //                   size: 20,
            //                 ),
            //                 const SizedBox(width: 8),
            //                 Expanded(
            //                   child: Text(
            //                     apiConnectionStatus.value!,
            //                     style: TextStyle(
            //                       color: apiConnectionStatus.value!
            //                               .startsWith('Connected')
            //                           ? Colors.green.shade700
            //                           : Colors.red.shade700,
            //                       fontWeight: FontWeight.w500,
            //                     ),
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ],
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

// Router compatibility - redirects to main settings
@RoutePage()
class SettingsSubPage extends StatelessWidget {
  const SettingsSubPage(this.section, {super.key});

  final SettingSection section;

  @override
  Widget build(BuildContext context) {
    // Redirect to main settings page
    return const SettingsPage();
  }
}
