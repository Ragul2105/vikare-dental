import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/cache/hive_cache.dart';
import '../../../core/models/pagination.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
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
    final cached = HiveCache.getString(cacheKey);
    if (search.isEmpty && page == 1 && cached != null) {
      return PaginatedResponse<Patient>.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
        Patient.fromJson,
      );
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
    final state = ref.watch(patientListProvider);
    final page = ref.watch(patientPageProvider);
    return AppScaffold(
      currentIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patients/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Patient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Patient Records',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _debouncer.run(() {
                      ref.read(patientSearchProvider.notifier).state = value
                          .trim();
                      ref.read(patientPageProvider.notifier).state = 1;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search_rounded),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                FilledButton.icon(
                  onPressed: () => context.push('/patients/new'),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('New Patient'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _PatientTableHeader(),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(patientListProvider.future),
                child: state.when(
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
                      itemCount: response.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _PatientRow(
                        patient: response.items[index],
                        onTap: () => context.push(
                          '/patients/${response.items[index].id}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            state.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (response) => _PaginationRow(
                currentPage: page,
                totalPages: response.totalPages,
                total: response.total,
                visibleCount: response.items.length,
                onPrevious: response.hasPreviousPage
                    ? () => ref.read(patientPageProvider.notifier).state =
                          page - 1
                    : null,
                onNext: response.hasNextPage
                    ? () => ref.read(patientPageProvider.notifier).state =
                          page + 1
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientTableHeader extends StatelessWidget {
  const _PatientTableHeader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text('PATIENT ID')),
        Expanded(flex: 3, child: Text('PATIENT NAME')),
        Expanded(flex: 3, child: Text('DOCTOR NAME')),
        Expanded(flex: 2, child: Text('LAST VISIT DATE')),
      ],
    ),
  );
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});
  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDF1F6)),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A153047),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      patient.patientUid,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accentDeep,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      [
                        patient.gender,
                        if (patient.age != null) '${patient.age} yrs',
                      ].whereType<String>().join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  patient.doctorName ?? '—',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  patient.lastVisitDate == null
                      ? 'No visits yet'
                      : DateFormatter.shortDate(patient.lastVisitDate!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.currentPage,
    required this.totalPages,
    required this.total,
    required this.visibleCount,
    this.onPrevious,
    this.onNext,
  });
  final int currentPage;
  final int totalPages;
  final int total;
  final int visibleCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Text('$visibleCount of $total patients'),
        const Spacer(),
        OutlinedButton(onPressed: onPrevious, child: const Text('Prev')),
        const SizedBox(width: 10),
        Text('$currentPage / ${totalPages == 0 ? 1 : totalPages}'),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: onNext, child: const Text('Next')),
      ],
    ),
  );
}
