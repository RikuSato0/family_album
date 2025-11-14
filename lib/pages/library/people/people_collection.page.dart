import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/search/people.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:immich_mobile/widgets/search/person_name_edit_form.dart';

@RoutePage()
class PeopleCollectionPage extends HookConsumerWidget {
  const PeopleCollectionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(getAllPeopleProvider);
    final headers = ApiService.getRequestHeaders();
    final formFocus = useFocusNode();
    final ValueNotifier<String?> search = useState(null);

    showNameEditModel(
      String personId,
      String personName,
    ) {
      return showDialog(
        context: context,
        builder: (BuildContext context) {
          return PersonNameEditForm(personId: personId, personName: personName);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final isPortrait = context.orientation == Orientation.portrait;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: search.value == null,
            title: search.value != null
                ? SearchField(
                    focusNode: formFocus,
                    onTapOutside: (_) => formFocus.unfocus(),
                    onChanged: (value) => search.value = value,
                    filled: true,
                    hintText: 'search_family_members'.tr(),
                    autofocus: true,
                  )
                : Text('family'.tr()),
            actions: [
              IconButton(
                icon: Icon(search.value != null ? Icons.close : Icons.search),
                onPressed: () {
                  search.value = search.value == null ? '' : null;
                },
              ),
            ],
          ),
          body: people.when(
            data: (people) {
              var filteredPeople = people;
              if (search.value != null) {
                filteredPeople = people.where((person) {
                  return person.name
                      .toLowerCase()
                      .contains(search.value!.toLowerCase());
                }).toList();
              }
              
              return RefreshIndicator(
                onRefresh: () async {
                  try {
                    print("🔄 Refreshing people data...");
                    ref.invalidate(getAllPeopleProvider);
                    await ref.read(getAllPeopleProvider.future);
                    print("✅ People data refreshed");
                  } catch (e) {
                    print("❌ People refresh failed: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Refresh failed: $e')),
                      );
                    }
                  }
                },
                child: filteredPeople.isNotEmpty
                    ? GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 6 : 3,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: isPortrait && isTablet ? 36 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        itemCount: filteredPeople.length,
                        itemBuilder: (context, index) {
                          final person = filteredPeople[index];

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  context.pushRoute(
                                    PersonResultRoute(
                                      personId: person.id,
                                      personName: person.name,
                                    ),
                                  );
                                },
                                child: Material(
                                  shape: const CircleBorder(side: BorderSide.none),
                                  elevation: 3,
                                  child: CircleAvatar(
                                    maxRadius: isTablet ? 120 / 2 : 96 / 2,
                                    backgroundImage: NetworkImage(
                                      getFaceThumbnailUrl(person.id),
                                      headers: headers,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => showNameEditModel(person.id, person.name),
                                child: person.name.isEmpty
                                    ? Text(
                                        'add_a_name'.tr(),
                                        style: context.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: context.colorScheme.primary,
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                        child: Text(
                                          person.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      )
                    : 
                    ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.face_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  search.value != null ? 'no_family_members_found'.tr() : 'no_family_members_yet'.tr(),
                                  style: context.textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (search.value == null) ...[
                                  Text(
                                    'face_detection_message'.tr(),
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
                          ),
                        ],
                      ),
              );
            },
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'error_loading_people'.tr(),
                    style: context.textTheme.bodyLarge?.copyWith(color: Colors.red[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'pull_to_refresh_try_again'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(color: Colors.red[500]),
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}
