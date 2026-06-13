import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class DentalClinicApp extends ConsumerWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => ref.read(authControllerProvider.notifier).touch(),
      onPanDown: (_) => ref.read(authControllerProvider.notifier).touch(),
      onScaleStart: (_) => ref.read(authControllerProvider.notifier).touch(),
      child: MaterialApp.router(
        title: 'Dental Clinic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
