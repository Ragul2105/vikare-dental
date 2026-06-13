import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_models.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import 'token_storage.dart';

class AuthState {
  const AuthState({
    this.initialized = false,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  final bool initialized;
  final bool isAuthenticated;
  final bool isLoading;
  final UserProfile? user;
  final String? errorMessage;

  AuthState copyWith({
    bool? initialized,
    bool? isAuthenticated,
    bool? isLoading,
    UserProfile? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(ref);
    unawaited(controller.restoreSession());
    return controller;
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;
  Timer? _idleTimer;

  Future<void> restoreSession() async {
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null) {
      state = state.copyWith(
        initialized: true,
        clearError: true,
        clearUser: true,
      );
      return;
    }

    final claims = _decodeClaims(accessToken);
    if (claims != null && !_isExpired(claims)) {
      state = AuthState(
        initialized: true,
        isAuthenticated: true,
        user: UserProfile.fromClaims(claims),
      );
      _restartIdleTimer();
      return;
    }

    await refreshSession(fromRestore: true);
  }

  Future<bool> login(String userId, String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repository = AuthRepository(_ref.read(publicApiClientProvider));
    final result = await repository.login(userId, pin);

    return result.when(
      success: (tokens) async {
        await _applyTokens(tokens);
        return true;
      },
      error: (error) {
        state = state.copyWith(
          initialized: true,
          isLoading: false,
          errorMessage: error.message,
        );
        return false;
      },
    );
  }

  Future<bool> refreshSession({bool fromRestore = false}) async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      await handleSessionExpired(
        message: fromRestore ? null : 'Session expired. Please log in again.',
      );
      return false;
    }

    final repository = AuthRepository(_ref.read(publicApiClientProvider));
    final result = await repository.refresh(refreshToken);
    return result.when(
      success: (tokens) async {
        await _applyTokens(tokens);
        return true;
      },
      error: (_) async {
        await handleSessionExpired(
          message: fromRestore ? null : 'Session expired. Please log in again.',
        );
        return false;
      },
    );
  }

  Future<void> applyTokenPair(TokenPair tokens) => _applyTokens(tokens);

  Future<void> handleSessionExpired({String? message}) async {
    _idleTimer?.cancel();
    await TokenStorage.clearTokens();
    state = AuthState(initialized: true, errorMessage: message);
  }

  Future<void> logout() async {
    _idleTimer?.cancel();
    await TokenStorage.clearTokens();
    state = const AuthState(initialized: true);
  }

  void touch() {
    if (state.isAuthenticated) {
      _restartIdleTimer();
    }
  }

  Future<void> _applyTokens(TokenPair tokens) async {
    await TokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    final claims = _decodeClaims(tokens.accessToken);
    state = AuthState(
      initialized: true,
      isAuthenticated: claims != null,
      user: claims == null ? null : UserProfile.fromClaims(claims),
    );
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 10), () {
      unawaited(handleSessionExpired(message: 'Logged out due to inactivity.'));
    });
  }

  Map<String, dynamic>? _decodeClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isExpired(Map<String, dynamic> claims) {
    final exp = claims['exp'];
    if (exp is! int) {
      return true;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
    ).isBefore(DateTime.now());
  }
}
