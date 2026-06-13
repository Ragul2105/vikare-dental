import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_panel_screen.dart';
import '../../features/appointments/presentation/appointment_calendar_screen.dart';
import '../../features/appointments/presentation/appointment_form_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';
import '../../features/patients/presentation/patient_list_screen.dart';
import '../../features/prescriptions/presentation/prescription_viewer_screen.dart';
import '../../features/visits/presentation/visit_detail_screen.dart';
import '../../features/visits/presentation/visit_form_screen.dart';
import '../auth/auth_controller.dart';
import '../theme/app_spacing.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLogin = location == '/login';

      if (!authState.initialized && !isSplash) {
        return '/splash';
      }

      if (!authState.initialized) {
        return null;
      }

      if (!authState.isAuthenticated) {
        return isLogin ? null : '/login';
      }

      if (isLogin || isSplash) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PinLoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => const PatientListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const PatientFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                PatientDetailScreen(patientId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    PatientFormScreen(patientId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'visits/new',
                builder: (context, state) =>
                    VisitFormScreen(patientId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'visits/:visitId',
                builder: (context, state) => VisitDetailScreen(
                  patientId: state.pathParameters['id']!,
                  visitId: state.pathParameters['visitId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => VisitFormScreen(
                      patientId: state.pathParameters['id']!,
                      visitId: state.pathParameters['visitId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'prescription',
                    builder: (context, state) => PrescriptionViewerScreen(
                      visitId: state.pathParameters['visitId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const AppointmentCalendarScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AppointmentFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => AppointmentFormScreen(
              appointmentId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Page not found: ${state.error}'),
        ),
      ),
    ),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
