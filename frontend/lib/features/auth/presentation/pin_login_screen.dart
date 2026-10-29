import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/auth_repository.dart';
import 'widgets/pin_pad.dart';

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
  String _role = 'admin';
  UserSummary? _selectedUser;
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.errorMessage != null && mounted) {
        SnackService.showError(context, next.errorMessage!);
      }
    });

    final usersState = ref.watch(authUsersProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FEFF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: AppColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Clinic Server Online',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final logoSize = (constraints.maxHeight * 0.55)
                    .clamp(220.0, 430.0)
                    .toDouble();
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, compact ? 74 : 36, 24, 24),
                  child: compact
                      ? Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildAccess(
                              usersState,
                              authState,
                              compact: true,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: Image.asset(
                                  'assets/images/vikare-logo.jpeg',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildAccess(
                                usersState,
                                authState,
                                compact: false,
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccess(
    AsyncValue<List<UserSummary>> usersState,
    AuthState authState, {
    required bool compact,
  }) {
    return Container(
      width: compact ? 480 : 500,
      padding: EdgeInsets.all(compact ? 28 : 40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB8C5C9)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: usersState.when(
        loading: () => const SizedBox(height: 560, child: AppLoading()),
        error: (error, _) => SizedBox(
          height: 560,
          child: AppErrorView(
            message: error is AppError
                ? error.message
                : 'Failed to load clinic users.',
            onRetry: () => ref.invalidate(authUsersProvider),
          ),
        ),
        data: (users) {
          final roleUsers = users.where((item) => item.role == _role).toList();
          final selected = roleUsers.any((item) => item.id == _selectedUser?.id)
              ? _selectedUser
              : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/vikare-logo.jpeg',
                width: 62,
                height: 62,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 6),
              Text(
                'Vikare Dental Clinic',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    _RoleTab(
                      label: 'Admin',
                      selected: _role == 'admin',
                      onTap: () => _setRole('admin'),
                    ),
                    _RoleTab(
                      label: 'Staffs',
                      selected: _role == 'staff',
                      onTap: () => _setRole('staff'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Username',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Select username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: roleUsers
                    .map(
                      (user) => DropdownMenuItem(
                        value: user.id,
                        child: Text(user.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() {
                  _selectedUser = roleUsers
                      .where((item) => item.id == id)
                      .firstOrNull;
                  _pin = '';
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter 4-Digit Security PIN',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: filled ? AppColors.accent : Colors.white,
                      border: Border.all(
                        color: filled
                            ? AppColors.accent
                            : const Color(0xFFB8C5C9),
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 290,
                height: 238,
                child: PinPad(
                  onDigit: (digit) {
                    if (_pin.length < 4) {
                      setState(() => _pin += digit);
                    }
                  },
                  onDelete: () {
                    if (_pin.isNotEmpty) {
                      setState(() => _pin = _pin.substring(0, _pin.length - 1));
                    }
                  },
                ),
              ),
              const SizedBox(height: 26),
              AppButton(
                label: authState.isLoading ? 'Logging in...' : 'Login',
                icon: Icons.login_rounded,
                isLoading: authState.isLoading,
                onPressed: selected != null && _pin.length == 4
                    ? _submit
                    : null,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {},
                child: const Text('Forgot PIN or Reset PIN?'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _setRole(String role) {
    setState(() {
      _role = role;
      _selectedUser = null;
      _pin = '';
    });
  }

  Future<void> _submit() async {
    final selected = _selectedUser;
    if (selected == null || _pin.length != 4) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(selected.id, _pin);
    if (!success && mounted) setState(() => _pin = '');
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
