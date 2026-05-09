import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  /// Called when sign-in succeeds AND the user is on the allowlist.
  final VoidCallback onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserCredential? credential =
          await _authService.signInWithGoogle();

      if (credential == null) {
        // User cancelled sign-in
        setState(() => _isLoading = false);
        return;
      }

      final email = credential.user?.email;
      if (email == null) {
        await _authService.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to retrieve email from your account.';
        });
        return;
      }

      // Check allowlist
      final allowed = await _authService.isAllowlisted(email);
      if (allowed) {
        widget.onLoginSuccess();
      } else {
        await _authService.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Access denied. Your account is not on the approved list.\n'
              'Please contact the administrator to request access.';
        });
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('Sign-in error: $e');
      }
      setState(() {
        _isLoading = false;
        // Remove "Exception: " prefix from error message
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected sign-in error: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'An unexpected error occurred. Please try again or contact support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange, Colors.deepOrange],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon / title area
                  const Icon(
                    Icons.sports_golf,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Frisbee Scoring',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),

                // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Sign-in button
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: const Icon(Icons.login, size: 24),
                          label: const Text(
                            'Sign in with Google',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
