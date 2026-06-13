import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/cache/hive_cache.dart';
import '../../../core/models/pagination.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';

final patientSearchProvider = StateProvider<String>((ref) => '');
final patientPageProvider = StateProvider<int>((ref) => 1);

final patientListProvider = FutureProvider<PaginatedResponse<Patient>>((
  ref,
) async {
  const cacheKey = 'patient_list_page_1';
  final search = ref.watch(patientSearchProvider);
  final page = ref.watch(patientPageProvider);

  try {
    final result = await ref
        .read(patientRepositoryProvider)
        .listPatients(search: search, page: page);
    return result.when(
      success: (response) {
        if (search.isEmpty && page == 1) {
          HiveCache.putString(
            cacheKey,
            jsonEncode(response.toJson((item) => item.toJson())),
          );
        }
        return response;
      },
      error: (error) => throw error,
    );
  } catch (_) {
    if (search.isEmpty && page == 1) {
      final cached = HiveCache.getString(cacheKey);
      if (cached != null) {
        return PaginatedResponse<Patient>.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
          Patient.fromJson,
        );
      }
    }
    rethrow;
  }
});

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(patientListProvider);
    final page = ref.watch(patientPageProvider);

    return AppScaffold(
      currentIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patients/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Patient'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                AppSpacing.pagePadding,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patients',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Search by patient name, UID, or mobile number.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search patients...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    onChanged: (value) {
                      _debouncer.run(() {
                        ref.read(patientSearchProvider.notifier).state = value
                            .trim();
                        ref.read(patientPageProvider.notifier).state = 1;
                      });
                    },
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(patientSearchProvider.notifier).state =
                                  '';
                              ref.read(patientPageProvider.notifier).state = 1;
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(patientListProvider),
                child: patientsState.when(
                  loading: () => const AppLoadingList(),
                  error: (error, _) => AppErrorView(
                    message: error is AppError
                        ? error.message
                        : 'Failed to load patients.',
                    onRetry: () => ref.invalidate(patientListProvider),
                  ),
                  data: (response) {
                    if (response.items.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.people_alt_outlined,
                        message: 'No patients found.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        0,
                        AppSpacing.pagePadding,
                        AppSpacing.xxl,
                      ),
                      itemCount: response.items.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        if (index == response.items.length) {
                          return _PaginationRow(
                            currentPage: page,
                            totalPages: response.totalPages,
                            onPrevious: response.hasPreviousPage
                                ? () =>
                                      ref
                                              .read(
                                                patientPageProvider.notifier,
                                              )
                                              .state =
                                          page - 1
                                : null,
                            onNext: response.hasNextPage
                                ? () =>
                                      ref
                                              .read(
                                                patientPageProvider.notifier,
                                              )
                                              .state =
                                          page + 1
                                : null,
                          );
                        }

                        final patient = response.items[index];
                        return AppCard(
                          onTap: () => context.push('/patients/${patient.id}'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.surfaceAccent,
                                foregroundColor: AppColors.accentDeep,
                                child: Text(
                                  patient.name.isEmpty
                                      ? '?'
                                      : patient.name.characters.first
                                            .toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      '${patient.patientUid}  •  ${patient.mobile}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    if (patient.gender != null ||
                                        patient.age != null) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        [
                                          patient.gender,
                                          if (patient.age != null)
                                            '${patient.age} yrs',
                                        ].whereType<String>().join(' • '),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 380;

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Page $currentPage of $totalPages',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPrevious,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
            const Spacer(),
            Text('Page $currentPage of $totalPages'),
            const Spacer(),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
            ),
          ],
        );
      },
    );
  }
}
