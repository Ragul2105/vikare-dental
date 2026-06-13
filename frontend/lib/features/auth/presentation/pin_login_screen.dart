import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/auth_repository.dart';
import 'widgets/pin_pad.dart';
import 'widgets/user_selector.dart';

final authUsersProvider = FutureProvider<List<UserSummary>>((ref) async {
  final result = await AuthRepository(
    ref.read(publicApiClientProvider),
  ).listUsers();
  return result.unwrap();
});

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  UserSummary? _selectedUser;
  String _pin = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.errorMessage != null && mounted) {
        setState(() => _error = next.errorMessage);
        SnackService.showError(context, next.errorMessage!);
      }
    });

    final usersState = ref.watch(authUsersProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F1E5), Color(0xFFE8F0EA), Color(0xFFDCEAE8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 720;
              final pagePadding = isCompact ? AppSpacing.md : AppSpacing.xl;
              final minHeight = (constraints.maxHeight - (pagePadding * 2))
                  .clamp(0.0, double.infinity)
                  .toDouble();

              final accessPanel = usersState.when(
                loading: () => const AppLoading(),
                error: (error, _) => AppErrorView(
                  message: error is AppError
                      ? error.message
                      : 'Failed to load staff profiles.',
                  onRetry: () => ref.invalidate(authUsersProvider),
                ),
                data: (users) => _LoginAccessCard(
                  users: users,
                  selectedUser: _selectedUser,
                  pinLength: _pin.length,
                  isLoading: authState.isLoading,
                  compact: isCompact,
                  onSelect: (user) {
                    setState(() {
                      _selectedUser = user;
                      _pin = '';
                      _error = null;
                    });
                  },
                  onDigit: _appendDigit,
                  onDelete: _deleteDigit,
                  onSubmit: _canSubmit ? _submit : null,
                ),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? 520 : 860,
                      ),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LoginIntroCard(
                                  selectedUser: _selectedUser,
                                  pinLength: _pin.length,
                                  error: _error,
                                  compact: true,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                accessPanel,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _LoginIntroCard(
                                    selectedUser: _selectedUser,
                                    pinLength: _pin.length,
                                    error: _error,
                                    compact: false,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(child: accessPanel),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _canSubmit => _selectedUser != null && _pin.length >= 4;

  void _appendDigit(String digit) {
    if (_pin.length >= 8) {
      return;
    }

    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _deleteDigit() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final selectedUser = _selectedUser;
    if (selectedUser == null || _pin.length < 4) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(selectedUser.id, _pin);
    if (!success && mounted) {
      setState(() {
        _pin = '';
      });
    }
  }
}

class _LoginIntroCard extends StatelessWidget {
  const _LoginIntroCard({
    required this.selectedUser,
    required this.pinLength,
    required this.compact,
    this.error,
  });

  final UserSummary? selectedUser;
  final int pinLength;
  final bool compact;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.accentDeep,
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dental Clinic',
              style:
                  (compact
                          ? Theme.of(context).textTheme.displayMedium
                          : Theme.of(context).textTheme.displayLarge)
                      ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              compact
                  ? 'Patient intake, appointments, visit notes, prescriptions, and administration in one clinic workspace.'
                  : 'Fast patient intake, appointment tracking, visit notes, prescriptions, and clinic administration in one tablet-first workspace.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedUser == null
                        ? 'Waiting for profile selection'
                        : 'Signing in as ${selectedUser!.name}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    pinLength == 0
                        ? 'Enter a 4 to 8 digit PIN to continue.'
                        : '$pinLength digit${pinLength == 1 ? '' : 's'} entered',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFFD7D1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginAccessCard extends StatelessWidget {
  const _LoginAccessCard({
    required this.users,
    required this.selectedUser,
    required this.pinLength,
    required this.isLoading,
    required this.compact,
    required this.onSelect,
    required this.onDigit,
    required this.onDelete,
    this.onSubmit,
  });

  final List<UserSummary> users;
  final UserSummary? selectedUser;
  final int pinLength;
  final bool isLoading;
  final bool compact;
  final ValueChanged<UserSummary> onSelect;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final keypadHeight = compact ? 264.0 : 320.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select profile',
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap your staff profile, then enter your clinic PIN.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            UserSelector(
              users: users,
              selectedUser: selectedUser,
              onSelect: onSelect,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PinPreview(pinLength: pinLength),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: keypadHeight,
              child: PinPad(
                onDigit: onDigit,
                onDelete: onDelete,
                onSubmit: onSubmit,
                canSubmit: onSubmit != null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: isLoading ? 'Signing in...' : 'Unlock Clinic',
              icon: Icons.arrow_forward_rounded,
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({required this.pinLength});

  final int pinLength;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: List<Widget>.generate(8, (index) {
        final filled = index < pinLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.surfaceMuted,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
