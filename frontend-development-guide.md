# Dental Clinic App — Flutter Frontend Development Guide

> **Stack:** Flutter 3.24+ · Dart 3.5+ · Riverpod 2 · Dio · GoRouter · Hive · flutter_secure_storage
>
> **Targets:** Android phone (5–6.5") and Android tablet (8–12")
>
> **Access model:** Doctor & Staff only. No patient-facing screens.
>
> **Backend alignment:** All API calls match `backend-development-guide.md`. Base URL: `https://api.yourclinic.com/api/v1`

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Dependencies](#2-dependencies)
3. [App Configuration](#3-app-configuration)
4. [Design System & Theme](#4-design-system--theme)
5. [Responsive Layout System](#5-responsive-layout-system)
6. [Navigation (GoRouter)](#6-navigation-gorouter)
7. [API Layer (Dio)](#7-api-layer-dio)
8. [State Management (Riverpod)](#8-state-management-riverpod)
9. [Authentication & Session](#9-authentication--session)
10. [Modules](#10-modules)
    - [10.1 PIN Login](#101-pin-login)
    - [10.2 Dashboard](#102-dashboard)
    - [10.3 Patient Management](#103-patient-management)
    - [10.4 Appointment Calendar](#104-appointment-calendar)
    - [10.5 Visit, Notes & Photos](#105-visit-notes--photos)
    - [10.6 Prescription PDF Viewer](#106-prescription-pdf-viewer)
    - [10.7 Admin Panel](#107-admin-panel)
11. [Offline Support (Hive)](#11-offline-support-hive)
12. [Error Handling & User Feedback](#12-error-handling--user-feedback)
13. [Security](#13-security)
14. [Testing](#14-testing)
15. [Build & Release](#15-build--release)

---

## 1. Project Structure

Feature-first structure — each feature is self-contained with its own data, domain, and presentation layers.

```
lib/
├── main.dart                        # App entry point, ProviderScope, runApp
├── app.dart                         # MaterialApp.router + GoRouter + Theme
│
├── core/                            # App-wide shared code
│   ├── api/
│   │   ├── api_client.dart          # Dio instance + interceptors
│   │   ├── api_endpoints.dart       # All endpoint constants
│   │   └── api_response.dart        # Generic ApiResponse<T> wrapper
│   ├── auth/
│   │   ├── auth_notifier.dart       # AuthState Riverpod notifier
│   │   ├── auth_repository.dart     # Login, refresh, logout calls
│   │   └── token_storage.dart       # flutter_secure_storage wrapper
│   ├── config/
│   │   └── app_config.dart          # Base URL, timeouts, feature flags
│   ├── router/
│   │   └── app_router.dart          # GoRouter + route guards
│   ├── theme/
│   │   ├── app_theme.dart           # ThemeData (light + dark)
│   │   ├── app_colors.dart          # Color palette constants
│   │   ├── app_text_styles.dart     # Typography scale
│   │   └── app_spacing.dart         # Spacing + border radius constants
│   ├── widgets/                     # Shared reusable widgets
│   │   ├── app_scaffold.dart        # Responsive scaffold (phone/tablet)
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── app_badge.dart           # Status badge (Scheduled/Completed etc.)
│   │   ├── app_card.dart
│   │   ├── app_empty_state.dart
│   │   ├── app_error_widget.dart
│   │   ├── app_loading.dart
│   │   ├── confirm_dialog.dart
│   │   └── snack_service.dart       # Global toast/snackbar
│   ├── models/                      # Shared domain models (from backend schemas)
│   │   ├── user.dart
│   │   └── pagination.dart
│   └── utils/
│       ├── date_formatter.dart
│       ├── validators.dart
│       └── debouncer.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   │   └── auth_models.dart     # LoginRequest, TokenResponse
│   │   └── presentation/
│   │       ├── pin_login_screen.dart
│   │       └── widgets/
│   │           ├── user_selector.dart
│   │           └── pin_pad.dart
│   │
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── dashboard_repository.dart
│   │   ├── domain/
│   │   │   └── dashboard_models.dart
│   │   └── presentation/
│   │       ├── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── stat_card.dart
│   │           └── appointment_list_tile.dart
│   │
│   ├── patients/
│   │   ├── data/
│   │   │   └── patient_repository.dart
│   │   ├── domain/
│   │   │   └── patient_models.dart
│   │   └── presentation/
│   │       ├── patient_list_screen.dart
│   │       ├── patient_detail_screen.dart
│   │       ├── patient_form_screen.dart
│   │       └── widgets/
│   │           ├── patient_card.dart
│   │           └── patient_search_bar.dart
│   │
│   ├── appointments/
│   │   ├── data/
│   │   │   └── appointment_repository.dart
│   │   ├── domain/
│   │   │   └── appointment_models.dart
│   │   └── presentation/
│   │       ├── appointment_calendar_screen.dart
│   │       ├── appointment_form_screen.dart
│   │       └── widgets/
│   │           ├── day_view.dart
│   │           ├── week_view.dart
│   │           ├── appointment_slot.dart
│   │           └── appointment_detail_sheet.dart
│   │
│   ├── visits/
│   │   ├── data/
│   │   │   └── visit_repository.dart
│   │   ├── domain/
│   │   │   └── visit_models.dart
│   │   └── presentation/
│   │       ├── visit_form_screen.dart
│   │       ├── visit_detail_screen.dart
│   │       └── widgets/
│   │           ├── visit_timeline_card.dart
│   │           ├── photo_grid.dart
│   │           ├── photo_viewer.dart
│   │           └── treatment_picker.dart
│   │
│   ├── prescriptions/
│   │   ├── data/
│   │   │   └── prescription_repository.dart
│   │   └── presentation/
│   │       └── prescription_viewer_screen.dart
│   │
│   └── admin/
│       ├── data/
│       │   └── admin_repository.dart
│       ├── domain/
│       │   └── admin_models.dart
│       └── presentation/
│           ├── admin_panel_screen.dart
│           └── widgets/
│               ├── staff_list_tile.dart
│               ├── staff_form_sheet.dart
│               ├── master_list_section.dart
│               └── activity_log_tile.dart
│
└── l10n/                            # Localisation (optional, future)
    └── app_en.arb
```

> **Rule:** Features never import from other feature directories. All cross-feature dependencies go through `core/`. This keeps features isolated and independently testable.

---

## 2. Dependencies

```yaml
# pubspec.yaml
name: dental_clinic
description: Dental clinic management app for doctors and staff
publish_to: none

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.7

  # HTTP / API
  dio: ^5.7.0
  pretty_dio_logger: ^1.4.0      # Dev only — remove in production builds

  # Secure storage (JWT tokens)
  flutter_secure_storage: ^9.2.2

  # Local cache (offline reads)
  hive_flutter: ^1.1.0
  hive: ^2.2.3

  # Image handling
  image_picker: ^1.1.2
  flutter_image_compress: ^2.3.0
  cached_network_image: ^3.4.1

  # PDF viewer
  syncfusion_flutter_pdfviewer: ^26.2.14

  # UI components
  table_calendar: ^3.1.2          # Appointment calendar
  shimmer: ^3.0.0                 # Loading skeletons

  # Utilities
  intl: ^0.19.0
  path_provider: ^2.1.4
  uuid: ^4.4.2
  equatable: ^2.0.5
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.13
  riverpod_generator: ^2.4.3
  freezed: ^2.5.7
  json_serializable: ^6.8.0

  # Testing
  mocktail: ^1.0.4
  flutter_lints: ^4.0.0

  # Analysis
  very_good_analysis: ^6.0.0
```

Run code generation after adding models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. App Configuration

```dart
// lib/core/config/app_config.dart
class AppConfig {
  AppConfig._();

  // Change this per environment — use flutter_dotenv or --dart-define for CI
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.yourclinic.com/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout  = Duration(seconds: 120); // photo uploads

  static const int autoLogoutMinutes = 10;   // Idle timeout
  static const int presignedUrlMinutes = 15; // Matches backend S3 expiry

  static const int maxPhotosPerVisit = 10;
  static const int maxPhotoSizeKb = 1500;

  // Feature flags (sync with backend INVENTORY_ADDON_ENABLED)
  static const bool inventoryAddonEnabled = bool.fromEnvironment(
    'INVENTORY_ADDON',
    defaultValue: false,
  );
}
```

**Build with environment variables:**

```bash
# Development
flutter run --dart-define=BASE_URL=https://api.yourclinic.com/api/v1

# Production APK
flutter build apk --release \
  --dart-define=BASE_URL=https://api.yourclinic.com/api/v1

# Production App Bundle
flutter build appbundle --release \
  --dart-define=BASE_URL=https://api.yourclinic.com/api/v1
```

---

## 4. Design System & Theme

A consistent design system prevents ad-hoc styling scattered across widgets. All colors, typography, and spacing are defined in one place.

### Colors

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgPrimary   = Color(0xFF0F1117);
  static const Color bgSurface   = Color(0xFF1A1D27);
  static const Color bgSurface2  = Color(0xFF22263A);
  static const Color bgCard      = Color(0xFF1E2235);

  // Borders
  static const Color border      = Color(0xFF2E3350);

  // Accents
  static const Color accent      = Color(0xFF5B8DEE);
  static const Color accentLight = Color(0xFF93C5FD);
  static const Color purple      = Color(0xFFA78BFA);

  // Semantic colors
  static const Color success     = Color(0xFF3ECF8E);
  static const Color warning     = Color(0xFFF5C842);
  static const Color error       = Color(0xFFE55353);
  static const Color orange      = Color(0xFFF0954A);

  // Text
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted   = Color(0xFF8892A4);
  static const Color textDisabled= Color(0xFF4A5568);

  // Status badge colors — matches backend AppointmentStatus FSM
  static Color statusColor(String status) => switch (status.toLowerCase()) {
    'scheduled'   => accent,
    'in_progress' => warning,
    'completed'   => success,
    'cancelled'   => error,
    'no_show'     => textDisabled,
    _             => textMuted,
  };

  static Color statusBgColor(String status) => switch (status.toLowerCase()) {
    'scheduled'   => accent.withOpacity(0.15),
    'in_progress' => warning.withOpacity(0.15),
    'completed'   => success.withOpacity(0.15),
    'cancelled'   => error.withOpacity(0.15),
    'no_show'     => textDisabled.withOpacity(0.15),
    _             => textMuted.withOpacity(0.15),
  };
}
```

### Typography

```dart
// lib/core/theme/app_text_styles.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.2,
  );
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
  );
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.6,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textMuted, height: 1.5,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, letterSpacing: 0.5,
  );
  static const TextStyle mono = TextStyle(
    fontFamily: 'JetBrains Mono', fontSize: 13,
    color: AppColors.accentLight,
  );
}
```

### Spacing

```dart
// lib/core/theme/app_spacing.dart
class AppSpacing {
  AppSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  static const double cardPadding = 20;
  static const double pagePadding = 20;
  static const double sectionGap  = 32;
}
```

### Theme

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTextStyles.fontFamily,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.purple,
      surface: AppColors.bgSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.titleLarge,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSurface2,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border, thickness: 1, space: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSurface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.bgSurface,
      selectedIconTheme: IconThemeData(color: AppColors.accent),
      unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
      selectedLabelTextStyle: TextStyle(color: AppColors.accent, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
    ),
  );
}
```

---

## 5. Responsive Layout System

```dart
// lib/core/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Breakpoint: phone < 600dp, tablet >= 600dp
class ScreenSize {
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;
}

/// Navigation destinations shared between BottomNav (phone) and Rail (tablet)
class _NavDestination {
  const _NavDestination(this.label, this.icon, this.selectedIcon, this.route);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

const _destinations = [
  _NavDestination('Dashboard', Icons.grid_view_outlined, Icons.grid_view_rounded, '/dashboard'),
  _NavDestination('Patients',  Icons.people_outline,     Icons.people_rounded,     '/patients'),
  _NavDestination('Calendar',  Icons.calendar_month_outlined, Icons.calendar_month_rounded, '/appointments'),
  _NavDestination('Admin',     Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded, '/admin'),
];

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, required this.currentIndex});

  final Widget body;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return ScreenSize.isTablet(context)
        ? _TabletScaffold(body: body, currentIndex: currentIndex)
        : _PhoneScaffold(body: body, currentIndex: currentIndex);
  }

  void _onTap(BuildContext context, int index) =>
      context.go(_destinations[index].route);
}

class _PhoneScaffold extends StatelessWidget {
  const _PhoneScaffold({required this.body, required this.currentIndex});
  final Widget body;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_destinations[i].route),
        items: _destinations.map((d) => BottomNavigationBarItem(
          icon: Icon(d.icon),
          activeIcon: Icon(d.selectedIcon),
          label: d.label,
        )).toList(),
      ),
    );
  }
}

class _TabletScaffold extends StatelessWidget {
  const _TabletScaffold({required this.body, required this.currentIndex});
  final Widget body;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => context.go(_destinations[i].route),
            extended: MediaQuery.sizeOf(context).width >= 900, // Show labels if wide enough
            destinations: _destinations.map((d) => NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: Text(d.label),
            )).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
```

### Master-Detail Pattern (Tablet)

```dart
// Wrap patient list + detail in a master-detail split on tablet
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.detailPlaceholder,
  });
  final Widget master;
  final Widget? detail;
  final Widget? detailPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (!ScreenSize.isTablet(context)) return master;
    return Row(
      children: [
        SizedBox(width: 360, child: master),
        const VerticalDivider(width: 1),
        Expanded(child: detail ?? detailPlaceholder ?? const _NoSelectionPlaceholder()),
      ],
    );
  }
}

class _NoSelectionPlaceholder extends StatelessWidget {
  const _NoSelectionPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app_outlined, size: 48, color: AppColors.textDisabled),
        SizedBox(height: 12),
        Text('Select an item', style: TextStyle(color: AppColors.textMuted)),
      ],
    ),
  );
}
```

---

## 6. Navigation (GoRouter)

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn  = authState.isAuthenticated;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn  &&  isLoginPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login',       builder: (_, __) => const PinLoginScreen()),
      GoRoute(path: '/dashboard',   builder: (_, __) => const DashboardScreen()),

      GoRoute(
        path: '/patients',
        builder: (_, __) => const PatientListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => PatientDetailScreen(patientId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'visits/new',
                builder: (_, state) => VisitFormScreen(patientId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'visits/:visitId',
                builder: (_, state) => VisitDetailScreen(visitId: state.pathParameters['visitId']!),
              ),
            ],
          ),
          GoRoute(path: 'new', builder: (_, __) => const PatientFormScreen()),
        ],
      ),

      GoRoute(
        path: '/appointments',
        builder: (_, __) => const AppointmentCalendarScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const AppointmentFormScreen()),
        ],
      ),

      GoRoute(
        path: '/admin',
        redirect: (context, state) {
          // Guard admin route at the router level too
          // actual role check is in the screen via Riverpod
          return null;
        },
        builder: (_, __) => const AdminPanelScreen(),
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
```

---

## 7. API Layer (Dio)

### Endpoint Constants

```dart
// lib/core/api/api_endpoints.dart
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String authUsers   = '/auth/users';
  static const String authLogin   = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout  = '/auth/logout';

  // Patients
  static const String patients     = '/patients';
  static String patient(String id) => '/patients/$id';
  static String patientVisits(String id) => '/patients/$id/visits';

  // Appointments
  static const String appointments     = '/appointments';
  static String appointment(String id) => '/appointments/$id';

  // Visits
  static const String visits          = '/visits';
  static String visit(String id)      => '/visits/$id';
  static String visitPhotos(String id) => '/visits/$id/photos';
  static String visitPhoto(String visitId, String photoId) =>
      '/visits/$visitId/photos/$photoId';
  static String prescription(String visitId) => '/visits/$visitId/prescription';

  // Dashboard
  static const String dashboardSummary = '/dashboard/summary';

  // Staff
  static const String staff             = '/staff';
  static String staffMember(String id) => '/staff/$id';
  static String staffResetPin(String id) => '/staff/$id/reset-pin';
  static const String activityLogs      = '/activity-logs';

  // Masters
  static const String treatments  = '/treatments';
  static const String medications = '/medications';
  static String treatment(String id)  => '/treatments/$id';
  static String medication(String id) => '/medications/$id';

  // Health
  static const String health = '/health';
}
```

### Api Response Wrapper

```dart
// lib/core/api/api_response.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'api_response.freezed.dart';

@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success(T data) = ApiSuccess<T>;
  const factory ApiResponse.error(AppError error) = ApiError<T>;
}

class AppError {
  const AppError({
    required this.errorCode,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String errorCode;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isUnauthorized  => statusCode == 401;
  bool get isForbidden     => statusCode == 403;
  bool get isNotFound      => statusCode == 404;
  bool get isConflict      => statusCode == 409;
  bool get isRateLimited   => statusCode == 429;
  bool get isServerError   => (statusCode ?? 0) >= 500;

  @override
  String toString() => 'AppError($errorCode: $message)';
}
```

### Dio Client with Interceptors

```dart
// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/app_config.dart';
import '../auth/token_storage.dart';

part 'api_client.g.dart';

@riverpod
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    _AuthInterceptor(ref),
    _ErrorInterceptor(),
    _RetryInterceptor(dio),
    // Only in debug mode:
    // if (kDebugMode) PrettyDioLogger(),
  ]);

  return dio;
}

/// Attaches JWT to every request. Refreshes token on 401.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);
  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final refreshed = await _ref.read(authNotifierProvider.notifier).refreshToken();
      if (refreshed) {
        // Retry the original request with the new token
        final newToken = await TokenStorage.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        try {
          final dio = _ref.read(apiClientProvider);
          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (_) {}
      }
      // Refresh failed — force logout
      _ref.read(authNotifierProvider.notifier).logout();
    }
    handler.next(err);
  }
}

/// Normalises all Dio errors into AppError
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    AppError appError;

    if (response != null) {
      final data = response.data;
      appError = AppError(
        statusCode: response.statusCode,
        errorCode: data?['error_code'] ?? 'HTTP_ERROR',
        message: data?['message'] ?? _defaultMessage(response.statusCode ?? 0),
        details: data?['details'],
      );
    } else if (err.type == DioExceptionType.connectionTimeout ||
               err.type == DioExceptionType.receiveTimeout) {
      appError = const AppError(
        errorCode: 'TIMEOUT',
        message: 'Request timed out. Please check your connection.',
      );
    } else if (err.type == DioExceptionType.connectionError) {
      appError = const AppError(
        errorCode: 'NO_CONNECTION',
        message: 'No internet connection.',
      );
    } else {
      appError = AppError(
        errorCode: 'UNKNOWN',
        message: err.message ?? 'An unexpected error occurred.',
      );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appError,
        type: err.type,
        response: err.response,
      ),
    );
  }

  String _defaultMessage(int code) => switch (code) {
    400 => 'Bad request.',
    401 => 'Session expired. Please log in again.',
    403 => 'You do not have permission to do this.',
    404 => 'The requested resource was not found.',
    409 => 'Conflict: this operation cannot be completed.',
    422 => 'Validation failed. Please check your input.',
    429 => 'Too many requests. Please slow down.',
    _   => 'Server error. Please try again.',
  };
}

/// Retries failed requests once on 5xx errors
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode ?? 0;
    if (status >= 500 && err.requestOptions.extra['_retried'] != true) {
      await Future.delayed(const Duration(seconds: 2));
      err.requestOptions.extra['_retried'] = true;
      try {
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        // Fall through to original error
      }
    }
    handler.next(err);
  }
}
```

### Base Repository Pattern

```dart
// All repositories extend this to get consistent error handling
abstract class BaseRepository {
  BaseRepository(this.dio);
  final Dio dio;

  Future<ApiResponse<T>> safeCall<T>({
    required Future<Response> Function() call,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await call();
      return ApiResponse.success(fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      final error = e.error;
      if (error is AppError) return ApiResponse.error(error);
      return ApiResponse.error(AppError(errorCode: 'UNKNOWN', message: e.message ?? 'Error'));
    }
  }
}
```

---

## 8. State Management (Riverpod)

Use **Riverpod 2 with code generation** (`riverpod_annotation`). One notifier per feature. Never put business logic in widgets.

### Provider Conventions

```dart
// Naming conventions:
// - Data providers: patientListProvider, appointmentProvider(id)
// - Notifiers (with actions): patientFormNotifierProvider
// - Derived/computed: todayAppointmentsProvider

// ✅ Correct: Notifier for a list with loading/error state
@riverpod
class PatientListNotifier extends _$PatientListNotifier {
  @override
  Future<PaginatedResponse<Patient>> build() async {
    return ref.read(patientRepositoryProvider).listPatients();
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(patientRepositoryProvider).listPatients(search: query),
    );
  }

  Future<void> refresh() => ref.refresh(patientListNotifierProvider.future);
}

// ✅ Correct: Simple async provider for static data
@riverpod
Future<List<Treatment>> treatmentMaster(Ref ref) =>
    ref.read(masterRepositoryProvider).listTreatments();

// ✅ Correct: Family provider for parameterised data
@riverpod
Future<Patient> patientDetail(Ref ref, String patientId) =>
    ref.read(patientRepositoryProvider).getPatient(patientId);
```

### AsyncValue Pattern in Widgets

```dart
// Always handle all three states: loading, error, data
Consumer(
  builder: (context, ref, _) {
    final state = ref.watch(patientListNotifierProvider);
    return state.when(
      loading: () => const AppLoadingList(),
      error: (err, _) => AppErrorWidget(
        message: err is AppError ? err.message : 'Failed to load patients',
        onRetry: () => ref.invalidate(patientListNotifierProvider),
      ),
      data: (response) => PatientListView(patients: response.items),
    );
  },
)
```

---

## 9. Authentication & Session

### Token Storage

```dart
// lib/core/auth/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessKey  = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessKey,  value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken()  => _storage.read(key: _accessKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }
}
```

### Auth Notifier

```dart
// lib/core/auth/auth_notifier.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.freezed.dart';
part 'auth_notifier.g.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(false) bool isAuthenticated,
    @Default(false) bool isLoading,
    UserProfile? user,
    String? errorMessage,
  }) = _AuthState;
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _scheduleAutoLogout();
    return const AuthState();
  }

  /// Called on app launch — checks if a valid token exists
  Future<void> checkSession() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return;
    // Decode JWT claims (without network call)
    final claims = _decodeJwtClaims(token);
    if (claims == null || _isExpired(claims)) {
      await refreshToken();
      return;
    }
    state = state.copyWith(
      isAuthenticated: true,
      user: UserProfile.fromClaims(claims),
    );
  }

  Future<bool> login(String userId, String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref.read(authRepositoryProvider).login(userId, pin);
    return result.when(
      success: (tokens) async {
        await TokenStorage.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final claims = _decodeJwtClaims(tokens.accessToken);
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: claims != null ? UserProfile.fromClaims(claims) : null,
        );
        _resetAutoLogoutTimer();
        return true;
      },
      error: (err) {
        state = state.copyWith(isLoading: false, errorMessage: err.message);
        return false;
      },
    );
  }

  Future<bool> refreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) { await logout(); return false; }
    final result = await ref.read(authRepositoryProvider).refresh(refreshToken);
    return result.when(
      success: (tokens) async {
        await TokenStorage.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        return true;
      },
      error: (_) async { await logout(); return false; },
    );
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    _autoLogoutTimer?.cancel();
    state = const AuthState();
  }

  // ── Auto-logout on idle ───────────────────────────────────────────
  Timer? _autoLogoutTimer;

  void resetActivityTimer() {
    _autoLogoutTimer?.cancel();
    _scheduleAutoLogout();
  }

  void _scheduleAutoLogout() {
    if (!state.isAuthenticated) return;
    _autoLogoutTimer = Timer(
      Duration(minutes: AppConfig.autoLogoutMinutes),
      () => logout(),
    );
  }

  // Helpers
  Map<String, dynamic>? _decodeJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  bool _isExpired(Map<String, dynamic> claims) {
    final exp = claims['exp'];
    if (exp == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
  }
}
```

**Reset the idle timer on any user interaction:**

```dart
// Wrap MaterialApp with a GestureDetector
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap:         () => ref.read(authNotifierProvider.notifier).resetActivityTimer(),
  onPanDown:     (_) => ref.read(authNotifierProvider.notifier).resetActivityTimer(),
  onScaleStart:  (_) => ref.read(authNotifierProvider.notifier).resetActivityTimer(),
  child: MaterialApp.router(...),
)
```

---

## 10. Modules

### 10.1 PIN Login

**Flow:** User taps their profile card → enters PIN on pad → calls `POST /auth/login`

```dart
// lib/features/auth/presentation/pin_login_screen.dart
@riverpod
class PinLoginNotifier extends _$PinLoginNotifier {
  @override
  PinLoginState build() => const PinLoginState();

  void selectUser(UserSummary user) =>
      state = state.copyWith(selectedUser: user, pin: '', error: null);

  void appendDigit(String digit) {
    if (state.pin.length >= 8) return;
    state = state.copyWith(pin: state.pin + digit, error: null);
  }

  void deleteDigit() {
    if (state.pin.isEmpty) return;
    state = state.copyWith(pin: state.pin.substring(0, state.pin.length - 1));
  }

  Future<void> submit() async {
    if (state.selectedUser == null || state.pin.length < 4) return;
    state = state.copyWith(isLoading: true);
    final success = await ref.read(authNotifierProvider.notifier).login(
      state.selectedUser!.id,
      state.pin,
    );
    if (!success) {
      final error = ref.read(authNotifierProvider).errorMessage ?? 'Incorrect PIN';
      state = state.copyWith(isLoading: false, pin: '', error: error);
    }
  }
}
```

```dart
// PIN Pad widget — minimalist 3×4 grid
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onDelete});
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        ...'123456789'.split('').map((d) => _PinButton(label: d, onTap: () => onDigit(d))),
        const SizedBox.shrink(),
        _PinButton(label: '0', onTap: () => onDigit('0')),
        _PinButton(icon: Icons.backspace_outlined, onTap: onDelete),
      ],
    );
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface2,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(label!, style: AppTextStyles.displayMedium)
          : Icon(icon, color: AppColors.textMuted),
    ),
  );
}
```

---

### 10.2 Dashboard

**API:** `GET /dashboard/summary`

```dart
// lib/features/dashboard/presentation/dashboard_screen.dart
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final user  = ref.watch(authNotifierProvider).user;

    return AppScaffold(
      currentIndex: 0,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good ${_greeting()}, ${user?.name ?? ''}',
                       style: AppTextStyles.titleMedium),
                  Text(DateFormatter.fullDate(DateTime.now()),
                       style: AppTextStyles.bodyMedium),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_outlined),
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ],
            ),
            state.when(
              loading: () => const SliverFillRemaining(child: AppLoadingList()),
              error:   (e, _) => SliverFillRemaining(
                child: AppErrorWidget(
                  message: e is AppError ? e.message : 'Failed to load dashboard',
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
              ),
              data: (summary) => SliverList(
                delegate: SliverChildListDelegate([
                  // Stat cards row
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(children: [
                      Expanded(child: StatCard(label: "Today's Appointments",
                          value: '${summary.appointmentsToday}', icon: Icons.calendar_today_outlined,
                          color: AppColors.accent)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(label: 'Total Patients',
                          value: '${summary.totalPatients}', icon: Icons.people_outline,
                          color: AppColors.success)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(label: 'Staff',
                          value: '${summary.totalStaff}', icon: Icons.badge_outlined,
                          color: AppColors.purple)),
                    ]),
                  ),
                  // Today's appointments list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text("Today's Schedule", style: AppTextStyles.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (summary.appointments.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      message: 'No appointments today',
                    )
                  else
                    ...summary.appointments.map(
                      (appt) => AppointmentListTile(appointment: appt),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
```

---

### 10.3 Patient Management

**APIs:**
- `GET /patients?search=&page=&page_size=` → paginated list
- `POST /patients` → create
- `GET /patients/{id}` → detail
- `PATCH /patients/{id}` → update
- `DELETE /patients/{id}?reason=` → soft delete (admin only)

```dart
// lib/features/patients/data/patient_repository.dart
class PatientRepository extends BaseRepository {
  PatientRepository(super.dio);

  Future<ApiResponse<PaginatedResponse<Patient>>> listPatients({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => safeCall(
    call: () => dio.get(
      ApiEndpoints.patients,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'page_size': pageSize,
      },
    ),
    fromJson: (json) => PaginatedResponse.fromJson(
      json, (item) => Patient.fromJson(item as Map<String, dynamic>),
    ),
  );

  Future<ApiResponse<Patient>> createPatient(PatientCreate data) => safeCall(
    call: () => dio.post(ApiEndpoints.patients, data: data.toJson()),
    fromJson: Patient.fromJson,
  );

  Future<ApiResponse<Patient>> updatePatient(String id, PatientUpdate data) => safeCall(
    call: () => dio.patch(ApiEndpoints.patient(id), data: data.toJson()),
    fromJson: Patient.fromJson,
  );

  Future<ApiResponse<void>> deletePatient(String id, String reason) => safeCall(
    call: () => dio.delete(
      ApiEndpoints.patient(id),
      queryParameters: {'reason': reason},
    ),
    fromJson: (_) {},
  );
}
```

```dart
// Patient List — search with debounce
@riverpod
class PatientListNotifier extends _$PatientListNotifier {
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));

  @override
  Future<PaginatedResponse<Patient>> build() =>
      ref.read(patientRepositoryProvider).listPatients().then(_unwrap);

  void onSearchChanged(String query) =>
      _debouncer.run(() => _fetch(search: query));

  Future<void> _fetch({String? search}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(patientRepositoryProvider)
              .listPatients(search: search)
              .then(_unwrap),
    );
  }

  T _unwrap<T>(ApiResponse<T> result) => result.when(
    success: (data) => data,
    error: (err) => throw err,
  );
}
```

---

### 10.4 Appointment Calendar

**APIs:**
- `GET /appointments?date=YYYY-MM-DD&range=day|week`
- `POST /appointments`
- `PATCH /appointments/{id}`

```dart
// Day / Week calendar built with table_calendar
class AppointmentCalendarScreen extends ConsumerStatefulWidget {
  const AppointmentCalendarScreen({super.key});

  @override
  ConsumerState<AppointmentCalendarScreen> createState() =>
      _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState
    extends ConsumerState<AppointmentCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsForDayProvider(_focusedDay));

    return AppScaffold(
      currentIndex: 2,
      body: Column(
        children: [
          // Calendar header
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            onFormatChanged: (f) => setState(() => _format = f),
            onDaySelected: (selected, focused) =>
                setState(() => _focusedDay = focused),
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: AppColors.textPrimary),
              weekendTextStyle: TextStyle(color: AppColors.textMuted),
              selectedDecoration: BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.bgSurface2, shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: false,
              titleTextStyle: AppTextStyles.titleMedium,
            ),
          ),
          const Divider(),
          // Appointments for selected day
          Expanded(
            child: appointments.when(
              loading: () => const AppLoadingList(),
              error: (e, _) => AppErrorWidget(
                message: 'Failed to load appointments',
                onRetry: () => ref.invalidate(appointmentsForDayProvider(_focusedDay)),
              ),
              data: (list) => list.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      message: 'No appointments on this day',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: list.length,
                      itemBuilder: (_, i) => AppointmentSlot(
                        appointment: list[i],
                        onTap: () => _showDetail(context, list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/appointments/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  void _showDetail(BuildContext context, Appointment appt) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        builder: (_) => AppointmentDetailSheet(appointment: appt),
      );
}
```

**Conflict handling — show 409 inline:**

```dart
Future<void> _submitAppointment(WidgetRef ref, AppointmentCreate data) async {
  final result = await ref.read(appointmentRepositoryProvider).create(data);
  result.when(
    success: (_) => context.pop(),
    error: (err) {
      if (err.isConflict) {
        SnackService.showError(
          context,
          'Time slot is already taken. Please choose a different time.',
        );
      } else {
        SnackService.showError(context, err.message);
      }
    },
  );
}
```

---

### 10.5 Visit, Notes & Photos

**APIs:**
- `POST /visits` — create visit
- `GET /visits/{id}` — get visit with photos
- `PATCH /visits/{id}` — update notes/diagnosis
- `POST /visits/{id}/photos` — upload photos (multipart, up to 10)
- `DELETE /visits/{id}/photos/{photo_id}` — remove photo

```dart
// lib/features/visits/data/visit_repository.dart
class VisitRepository extends BaseRepository {
  VisitRepository(super.dio);

  Future<ApiResponse<Visit>> createVisit(VisitCreate data) => safeCall(
    call: () => dio.post(ApiEndpoints.visits, data: data.toJson()),
    fromJson: Visit.fromJson,
  );

  /// Upload one or more photos to a visit
  Future<ApiResponse<List<VisitPhoto>>> uploadPhotos({
    required String visitId,
    required List<XFile> files,
    List<String?> captions = const [],
  }) async {
    try {
      final formData = FormData();
      for (int i = 0; i < files.length; i++) {
        final compressed = await _compressImage(files[i]);
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(
            compressed,
            filename: '${visitId}_photo_$i.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ));
        if (i < captions.length && captions[i] != null) {
          formData.fields.add(MapEntry('captions', captions[i]!));
        }
      }
      final response = await dio.post(
        ApiEndpoints.visitPhotos(visitId),
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: AppConfig.uploadTimeout,
        ),
      );
      final list = (response.data as List)
          .map((e) => VisitPhoto.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(list);
    } on DioException catch (e) {
      final err = e.error;
      if (err is AppError) return ApiResponse.error(err);
      return ApiResponse.error(AppError(errorCode: 'UPLOAD_FAILED', message: 'Upload failed'));
    }
  }

  Future<Uint8List> _compressImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  Future<ApiResponse<void>> deletePhoto(String visitId, String photoId) => safeCall(
    call: () => dio.delete(ApiEndpoints.visitPhoto(visitId, photoId)),
    fromJson: (_) {},
  );
}
```

```dart
// Visit Form — notes + photo attachment UI
class VisitFormScreen extends ConsumerStatefulWidget {
  const VisitFormScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  final _notesCtrl     = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _picker        = ImagePicker();
  final List<XFile> _selectedPhotos = [];
  final List<TextEditingController> _captionCtrls = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Visit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visit date
            _SectionLabel('Visit Date'),
            // ... date picker

            // Diagnosis
            _SectionLabel('Diagnosis'),
            AppTextField(controller: _diagnosisCtrl, hint: 'Enter diagnosis'),
            const SizedBox(height: AppSpacing.md),

            // Notes
            _SectionLabel('Notes'),
            AppTextField(
              controller: _notesCtrl,
              hint: 'Describe what happened during the visit...',
              maxLines: 6,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Treatments picker
            _SectionLabel('Treatments'),
            TreatmentPicker(onChanged: (ids) => setState(() => _selectedTreatments = ids)),
            const SizedBox(height: AppSpacing.lg),

            // Photos section
            _SectionLabel('Photos (${_selectedPhotos.length}/${AppConfig.maxPhotosPerVisit})'),
            _PhotoAttachmentSection(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: _SaveBar(onSave: _submit),
    );
  }

  Widget _PhotoAttachmentSection() {
    return Column(
      children: [
        // Add photo buttons
        Row(
          children: [
            _AddPhotoButton(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(width: AppSpacing.sm),
            _AddPhotoButton(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Preview grid
        if (_selectedPhotos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _selectedPhotos.length,
            itemBuilder: (_, i) => _PhotoPreviewTile(
              file: _selectedPhotos[i],
              captionController: _captionCtrls[i],
              onRemove: () => setState(() {
                _selectedPhotos.removeAt(i);
                _captionCtrls.removeAt(i);
              }),
            ),
          ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_selectedPhotos.length >= AppConfig.maxPhotosPerVisit) {
      SnackService.showWarning(context, 'Maximum ${AppConfig.maxPhotosPerVisit} photos per visit');
      return;
    }
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1920,
    );
    if (file == null) return;
    setState(() {
      _selectedPhotos.add(file);
      _captionCtrls.add(TextEditingController());
    });
  }

  Future<void> _submit() async {
    // 1. Create the visit
    final visitData = VisitCreate(
      patientId: widget.patientId,
      visitDate: _selectedDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
      treatmentIds: _selectedTreatments,
    );
    final visitResult = await ref.read(visitRepositoryProvider).createVisit(visitData);
    final visit = visitResult.when(success: (v) => v, error: (e) {
      SnackService.showError(context, e.message); return null;
    });
    if (visit == null) return;

    // 2. Upload photos if any
    if (_selectedPhotos.isNotEmpty) {
      final captions = _captionCtrls.map((c) => c.text.trim().isEmpty ? null : c.text.trim()).toList();
      final photoResult = await ref.read(visitRepositoryProvider).uploadPhotos(
        visitId: visit.id,
        files: _selectedPhotos,
        captions: captions,
      );
      photoResult.whenOrNull(
        error: (e) => SnackService.showWarning(context,
            'Visit saved, but some photos failed to upload: ${e.message}'),
      );
    }

    SnackService.showSuccess(context, 'Visit saved successfully');
    if (mounted) context.pop();
  }
}
```

**Visit Detail with photo timeline:**

```dart
// Photo grid with tap-to-fullscreen
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, required this.visitId});
  final List<VisitPhoto> photos;
  final String visitId;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _openViewer(context, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: CachedNetworkImage(
            imageUrl: photos[i].photoUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.bgSurface2),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.bgSurface2,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) =>
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PhotoViewer(photos: photos, initialIndex: initialIndex),
      ));
}

// Full screen swipeable photo viewer
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, required this.initialIndex});
  final List<VisitPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _currentIndex;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _ctrl = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _sharePhoto(widget.photos[_currentIndex]),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: widget.photos[i].photoUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
      bottomNavigationBar: widget.photos[_currentIndex].caption?.isNotEmpty == true
          ? Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                widget.photos[_currentIndex].caption!,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }
}
```

---

### 10.6 Prescription PDF Viewer

**API:** `POST /visits/{id}/prescription` → returns `{ pdf_url }` (presigned S3 URL, 15-min expiry)

```dart
// lib/features/prescriptions/presentation/prescription_viewer_screen.dart
class PrescriptionViewerScreen extends ConsumerWidget {
  const PrescriptionViewerScreen({super.key, required this.visitId});
  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriptionProvider(visitId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(state.valueOrNull?.pdfUrl),
          ),
          IconButton(
            icon: const Icon(Icons.whatsapp),
            onPressed: () => _sendWhatsApp(context, ref),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorWidget(message: 'Failed to load prescription'),
        data: (prescription) => SfPdfViewer.network(
          prescription.pdfUrl,
          enableDoubleTapZooming: true,
        ),
      ),
      floatingActionButton: state.hasValue
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _generate(context, ref),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate PDF'),
              backgroundColor: AppColors.accent,
            ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(prescriptionRepositoryProvider).generate(visitId);
    result.when(
      success: (_) => ref.invalidate(prescriptionProvider(visitId)),
      error: (e) => SnackService.showError(context, e.message),
    );
  }
}
```

---

### 10.7 Admin Panel

**Access:** Admin role only. Enforce in the widget with a role guard.

```dart
// lib/features/admin/presentation/admin_panel_screen.dart
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    // Role guard at the UI level (backend also enforces this)
    if (user?.role != 'admin') {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.textDisabled),
              SizedBox(height: 12),
              Text('Admin access required', style: AppTextStyles.titleMedium),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      currentIndex: 3,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _AdminSection(
            title: 'Staff Management',
            child: StaffListSection(),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _AdminSection(
            title: 'Treatment Master',
            child: MasterListSection(type: MasterType.treatment),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _AdminSection(
            title: 'Medication Master',
            child: MasterListSection(type: MasterType.medication),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _AdminSection(
            title: 'Activity Log',
            child: ActivityLogSection(),
          ),
        ],
      ),
    );
  }
}
```

**PIN Reset sheet:**

```dart
void _showPinResetSheet(BuildContext context, WidgetRef ref, Staff staff) {
  final pinCtrl    = TextEditingController();
  final confirmCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset PIN — ${staff.name}', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: pinCtrl, hint: 'New PIN (4–8 digits)',
              keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: confirmCtrl, hint: 'Confirm new PIN',
              keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Reset PIN',
            onPressed: () async {
              if (pinCtrl.text != confirmCtrl.text) {
                SnackService.showError(ctx, 'PINs do not match'); return;
              }
              final result = await ref.read(adminRepositoryProvider)
                  .resetPin(staff.id, pinCtrl.text);
              result.when(
                success: (_) { Navigator.pop(ctx); SnackService.showSuccess(context, 'PIN reset successfully'); },
                error: (e) => SnackService.showError(ctx, e.message),
              );
            },
          ),
        ],
      ),
    ),
  );
}
```

---

## 11. Offline Support (Hive)

Cache patient list and today's appointments for offline read. Never use stale cache for writes.

```dart
// lib/core/cache/hive_cache.dart
import 'package:hive_flutter/hive_flutter.dart';

class HiveCache {
  static late Box<String> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>('app_cache');
  }

  static Future<void> put(String key, String jsonValue) =>
      _box.put(key, jsonValue);

  static String? get(String key) => _box.get(key);

  static Future<void> clear(String key) => _box.delete(key);
}
```

```dart
// Cache patient list, read from cache on network failure
@riverpod
class PatientListNotifier extends _$PatientListNotifier {
  static const _cacheKey = 'patient_list';

  @override
  Future<PaginatedResponse<Patient>> build() async {
    try {
      final result = await ref.read(patientRepositoryProvider).listPatients();
      return result.when(
        success: (data) {
          // Save to cache
          HiveCache.put(_cacheKey, jsonEncode(data.toJson()));
          return data;
        },
        error: (e) => throw e,
      );
    } catch (_) {
      // Fall back to cached data
      final cached = HiveCache.get(_cacheKey);
      if (cached != null) {
        return PaginatedResponse.fromJson(jsonDecode(cached), Patient.fromJson);
      }
      rethrow;
    }
  }
}
```

---

## 12. Error Handling & User Feedback

### Snack Service (Global toasts)

```dart
// lib/core/widgets/snack_service.dart
class SnackService {
  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, AppColors.success, Icons.check_circle_outline);

  static void showError(BuildContext context, String message) =>
      _show(context, message, AppColors.error, Icons.error_outline);

  static void showWarning(BuildContext context, String message) =>
      _show(context, message, AppColors.warning, Icons.warning_amber_outlined);

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textPrimary))),
        ]),
        backgroundColor: AppColors.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        duration: const Duration(seconds: 4),
      ));
  }
}
```

### Specific Error Handling

| Backend Error Code | UI Behaviour |
|---|---|
| `APPOINTMENT_CONFLICT` | Inline error on appointment form, highlight time field |
| `VALIDATION_ERROR` | Show field-level errors from `details` |
| `TIMEOUT` | Show retry button |
| `NO_CONNECTION` | Show offline banner, use cached data |
| `401 Unauthorized` | Auto-redirect to `/login` via auth interceptor |
| `403 Forbidden` | Show "Access denied" message in place |
| `429 Too Many Requests` | Show "Slow down" message, disable button briefly |
| `500+` | Show "Something went wrong" with retry |

```dart
// App Error Widget with retry
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 56, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Try Again', onPressed: onRetry!, variant: ButtonVariant.outlined),
          ],
        ],
      ),
    ),
  );
}
```

---

## 13. Security

### flutter_secure_storage

```dart
// Always use AndroidOptions with encryptedSharedPreferences
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

### Certificate Pinning (Dio)

```dart
// Add to Dio setup — pin your backend's certificate
import 'dart:io';
import 'package:dio/io.dart';

(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // Verify against your known certificate's SHA-256 fingerprint
    const expectedFingerprint = 'AA:BB:CC:DD:...'; // Your cert fingerprint
    return cert.sha256.toLowerCase() == expectedFingerprint.toLowerCase();
  };
  return client;
};
```

### Auto-Logout

- Idle timer resets on every `onTap`, `onPanDown`, `onScaleStart` (GestureDetector wrapping MaterialApp)
- On expiry: `AuthNotifier.logout()` → clears tokens → GoRouter redirects to `/login`
- JWT expiry also triggers logout via `_AuthInterceptor` on the next API call

### No PII in Logs / Crash Reporters

```dart
// If using Firebase Crashlytics, never log patient data
// Good
FirebaseCrashlytics.instance.log('Visit created: visit_id=$visitId');

// Bad — never do this
FirebaseCrashlytics.instance.log('Patient ${patient.name}, mobile: ${patient.mobile}');
```

### Gradle Hardening (`android/app/build.gradle`)

```groovy
android {
  buildTypes {
    release {
      minifyEnabled true
      shrinkResources true
      proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
  }
}
```

---

## 14. Testing

### Widget Test Example

```dart
// test/features/auth/pin_pad_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dental_clinic/features/auth/presentation/widgets/pin_pad.dart';

void main() {
  testWidgets('PinPad calls onDigit with correct value', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPad(
            onDigit: (d) => tapped = d,
            onDelete: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('5'));
    expect(tapped, '5');
  });

  testWidgets('PinPad calls onDelete when backspace tapped', (tester) async {
    bool deleteCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPad(
            onDigit: (_) {},
            onDelete: () => deleteCalled = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    expect(deleteCalled, isTrue);
  });
}
```

### Repository Unit Test (with Mocktail)

```dart
// test/features/patients/patient_repository_test.dart
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late PatientRepository repo;

  setUp(() {
    mockDio = MockDio();
    repo = PatientRepository(mockDio);
  });

  test('listPatients returns success with parsed patients', () async {
    when(() => mockDio.get(
      any(), queryParameters: any(named: 'queryParameters'),
    )).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: {
        'items': [{'id': 'uuid-1', 'name': 'John', 'patient_uid': 'PAT-000001', ...}],
        'total': 1, 'page': 1, 'page_size': 20,
      },
    ));

    final result = await repo.listPatients();
    expect(result, isA<ApiSuccess>());
    result.when(
      success: (data) => expect(data.items.first.name, 'John'),
      error: (_) => fail('Expected success'),
    );
  });

  test('listPatients returns error on 404', () async {
    when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          error: const AppError(errorCode: 'NOT_FOUND', message: 'Not found', statusCode: 404),
        ));

    final result = await repo.listPatients();
    expect(result, isA<ApiError>());
  });
}
```

### Integration Test

```dart
// integration_test/login_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dental_clinic/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login flow navigates to dashboard', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Should be on login screen
    expect(find.text('Dental Clinic'), findsOneWidget);

    // Select a user (requires mock or test server)
    await tester.tap(find.text('Dr. Admin'));
    await tester.pumpAndSettle();

    // Enter PIN
    for (final digit in '1234'.split('')) {
      await tester.tap(find.text(digit).last);
      await tester.pumpAndSettle();
    }

    // Should navigate to dashboard
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text("Today's Schedule"), findsOneWidget);
  });
}
```

**Run tests:**

```bash
# Unit + widget tests
flutter test

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration tests (connected device or emulator)
flutter test integration_test/
```

---

## 15. Build & Release

### Android Signing

```properties
# android/key.properties (NEVER commit — add to .gitignore)
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=dental_key
storeFile=/path/to/dental_keystore.jks
```

```groovy
// android/app/build.gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    defaultConfig {
        applicationId "com.yourclinic.dental"
        minSdk 24
        targetSdk 35
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### Build Commands

```bash
# Debug APK (development / testing)
flutter build apk --debug \
  --dart-define=BASE_URL=https://api.yourclinic.com/api/v1

# Release APK (direct install / internal distribution)
flutter build apk --release \
  --dart-define=BASE_URL=https://api.yourclinic.com/api/v1

# Release App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define=BASE_URL=https://api.yourclinic.com/api/v1

# Analyse APK size
flutter build apk --analyze-size
```

### CI/CD (GitHub Actions)

```yaml
# .github/workflows/build.yml
name: Flutter Build & Test

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0', channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test --coverage

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0', channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs

      # Restore signing key from GitHub Secrets
      - name: Decode keystore
        run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/keystore.jks

      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.STORE_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
          echo "storeFile=keystore.jks" >> android/key.properties

      - name: Build App Bundle
        run: flutter build appbundle --release
          --dart-define=BASE_URL=${{ secrets.API_BASE_URL }}

      - uses: actions/upload-artifact@v4
        with:
          name: app-release.aab
          path: build/app/outputs/bundle/release/app-release.aab
```

### Pre-Release Checklist

- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes with ≥ 80% coverage
- [ ] `AppConfig.baseUrl` points to production
- [ ] `kDebugMode` guards removed from production build (`PrettyDioLogger` disabled)
- [ ] Signing keystore password is in GitHub Secrets, not in code
- [ ] Certificate pinning fingerprint matches current production certificate
- [ ] APK size is within acceptable range (`flutter build apk --analyze-size`)
- [ ] Tested on both phone and tablet screen sizes
- [ ] Auto-logout verified at idle timeout
- [ ] All photo upload flows tested on a real device (not just emulator)

---

*Last updated: April 2026 — Dental Clinic App v1.0*
