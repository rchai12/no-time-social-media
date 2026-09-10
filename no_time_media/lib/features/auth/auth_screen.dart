import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();
  final _signUpConfirm = TextEditingController();

  bool _obscureSignIn = true;
  bool _obscureSignUp = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _error;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  void dispose() {
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    _signUpConfirm.dispose();
    super.dispose();
  }

  Future<void> _afterAuthSuccess() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {
      // RevenueCat may be unconfigured in local/dev builds.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    await _run(() async {
      await _auth.signInWithPassword(
        email: _signInEmail.text.trim(),
        password: _signInPassword.text,
      );
      await _afterAuthSuccess();
    });
  }

  Future<void> _signUp() async {
    await _run(() async {
      if (_signUpPassword.text.length < 8) {
        throw AuthException('Password must be at least 8 characters');
      }
      if (_signUpPassword.text != _signUpConfirm.text) {
        throw AuthException('Passwords do not match');
      }
      await _auth.signUp(
        email: _signUpEmail.text.trim(),
        password: _signUpPassword.text,
      );
      await _afterAuthSuccess();
    });
  }

  Future<void> _resetPassword() async {
    await _run(() async {
      final email = _signInEmail.text.trim();
      if (email.isEmpty) {
        throw AuthException('Enter your email to reset your password');
      }
      await _auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('No Time Media'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sign In'),
              Tab(text: 'Sign Up'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_error != null)
                  Material(
                    color: Colors.red.shade700,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SignInForm(
                        emailController: _signInEmail,
                        passwordController: _signInPassword,
                        obscure: _obscureSignIn,
                        onToggleObscure: () {
                          setState(() => _obscureSignIn = !_obscureSignIn);
                        },
                        onSignIn: _busy ? null : _signIn,
                        onForgotPassword: _busy ? null : _resetPassword,
                      ),
                      _SignUpForm(
                        emailController: _signUpEmail,
                        passwordController: _signUpPassword,
                        confirmController: _signUpConfirm,
                        obscurePassword: _obscureSignUp,
                        obscureConfirm: _obscureConfirm,
                        onTogglePassword: () {
                          setState(() => _obscureSignUp = !_obscureSignUp);
                        },
                        onToggleConfirm: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                        onSignUp: _busy ? null : _signUp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSignIn,
    required this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSignIn;
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onSignIn,
          child: const Text('Sign In'),
        ),
        TextButton(
          onPressed: onForgotPassword,
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSignUp,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback? onSignUp;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password (min 8 characters)',
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: onTogglePassword,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: confirmController,
          obscureText: obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: onToggleConfirm,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onSignUp,
          child: const Text('Create Account'),
        ),
      ],
    );
  }
}
