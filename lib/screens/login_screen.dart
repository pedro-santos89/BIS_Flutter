import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers.dart';
import '../l10n.dart';

/// Admin login screen. Authenticates users via [DatabaseHelper] and sets
/// session state through [AuthProvider]. Navigates to the admin panel on success.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Mutable state for [LoginScreen].
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Guards against duplicate submissions while an auth request is in-flight.
  bool _isSubmitting = false;

  /// Inline error message shown after a failed login attempt.
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form, authenticates against the DB, and either navigates
  /// to `/admin` or displays an error message.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final user = await DatabaseHelper.instance.authenticateUser(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (user != null) {
        context.read<AuthProvider>().login(
          _usernameController.text.trim(),
          isAdmin: user.isAdmin,
        );
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        setState(() => _error = AppLocalizations.of(context).tr('invalidCredentials'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tr('adminLogin')),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: AppLocalizations.of(context).tr('home'),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).tr('adminLogin'),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('username'),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? AppLocalizations.of(context).tr('required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('password'),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? AppLocalizations.of(context).tr('required') : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context).tr('logIn')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
