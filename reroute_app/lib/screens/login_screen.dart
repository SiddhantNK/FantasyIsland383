import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String _role = 'dispatcher';
  String _vehicleId = 'V01';
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      if (_isSignUp) {
        await AuthService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          role: _role,
          vehicleId: _vehicleId,
        );
        if (!mounted) return;
        if (AuthService.isLoggedIn) {
          // The auth state stream switches to the app after successful signup.
          setState(() => _message = 'Account created. You are signed in.');
        } else {
          setState(() {
            _message = 'Account created. Check your email to confirm, then sign in.';
            _isSignUp = false;
          });
        }
      } else {
        await AuthService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'Unable to authenticate. Check your connection and try again.';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 52, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('ReRoute', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(_isSignUp ? 'Create your account' : 'Sign in to your account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: _isSignUp
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        if ((value ?? '').length < 8) return 'Use at least 8 characters';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                          DropdownMenuItem(value: 'driver', child: Text('Driver')),
                        ],
                        onChanged: (value) => setState(() => _role = value ?? 'dispatcher'),
                      ),
                      if (_role == 'driver') ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _vehicleId,
                          decoration: const InputDecoration(labelText: 'Assigned vehicle'),
                          items: ['V01', 'V02', 'V03'].map((id) =>
                            DropdownMenuItem(value: id, child: Text(id))).toList(),
                          onChanged: (value) => setState(() => _vehicleId = value ?? 'V01'),
                        ),
                      ],
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: TextStyle(
                        color: _messageIsError ? AppTheme.rose : AppTheme.emerald,
                      )),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() {
                        _isSignUp = !_isSignUp;
                        _message = null;
                        _messageIsError = false;
                      }),
                      child: Text(_isSignUp
                          ? 'Already registered? Sign in'
                          : 'New to ReRoute? Create an account'),
                    ),
                    if (!_isSignUp)
                      TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = 'Enter your email above first.';
        _messageIsError = true;
      });
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() {
        _message = 'Password reset email sent if that account exists.';
        _messageIsError = false;
      });
    } on AuthException catch (error) {
      if (mounted) setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    }
  }
}
