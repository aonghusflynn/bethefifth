import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to user provider to route when authenticated
    ref.listen<AsyncValue<dynamic>>(userProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        context.go('/games');
      }
    });

    return Scaffold(
      backgroundColor: BtfColors.ink,
      body: Stack(
        children: [
          // Glowing pitch lights abstract design
          Positioned(
            top: -150,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BtfColors.lime.withOpacity(0.12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BtfColors.flood.withOpacity(0.08),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  
                  // Decorative Logo Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(BtfSpace.x4),
                      decoration: BoxDecoration(
                        color: BtfColors.ink2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BtfColors.lime.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BtfColors.lime.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 56,
                        color: BtfColors.lime,
                      ),
                    ),
                  ),
                  const SizedBox(height: BtfSpace.x5),
                  
                  // Brand Headline
                  Text(
                    'BeTheFifth',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: BtfColors.paper,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: BtfSpace.x2),
                  
                  Text(
                    'Find your open match. Manage the roster.\nNever be short again.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: BtfColors.muted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 4),
                  
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
                      ),
                    )
                  else ...[
                    // Premium Pitch Lime CTA for main registration/login
                    FilledButton.icon(
                      onPressed: () => _handleSignIn(ref.read(authServiceProvider).signInWithGoogle),
                      style: FilledButton.styleFrom(
                        backgroundColor: BtfColors.lime,
                        foregroundColor: BtfColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: BtfSpace.x4),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(
                        'Continue with Google',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: BtfColors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: BtfSpace.x3),
                    
                    OutlinedButton.icon(
                      onPressed: () => _handleSignIn(ref.read(authServiceProvider).signInWithApple),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BtfColors.paper,
                        side: BorderSide(color: BtfColors.paper.withOpacity(0.15)),
                        padding: const EdgeInsets.symmetric(vertical: BtfSpace.x4),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.apple, size: 20),
                      label: Text(
                        'Continue with Apple',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: BtfColors.paper,
                        ),
                      ),
                    ),
                    const SizedBox(height: BtfSpace.x4),
                    
                    // Quick Developer Bypass
                    TextButton(
                      onPressed: _handleMockBypass,
                      child: Text(
                        'Developer Mock Bypass (Dublin MVP)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: BtfColors.lime.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignIn(Future<dynamic> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      await signInMethod();
      ref.invalidate(userProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auth error: ${e.toString()}'),
            backgroundColor: BtfColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMockBypass() async {
    setState(() => _isLoading = true);
    // Directly inject a developer token in ApiService and bypass auth
    final apiService = ref.read(apiServiceProvider);
    apiService.setAuthToken('mock-token-dublin-player');

    try {
      // Only register if this mock user doesn't exist yet — mirrors the
      // real auto-registration handshake in UserNotifier.build().
      try {
        await apiService.getMe();
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await apiService.register({
            'email': 'dublin.player@example.com',
            'display_name': 'Dublin Baller',
            'photo_url': null,
          });
        } else {
          rethrow;
        }
      }

      ref.invalidate(userProvider);
      
      if (mounted) {
        context.go('/games');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mock Bypass failed: ${e.toString()}'),
            backgroundColor: BtfColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
