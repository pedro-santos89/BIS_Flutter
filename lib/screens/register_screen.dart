import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models.dart';
import '../l10n.dart';

/// Registration form for regular (annual) members.
/// Collects name, optional email, communication consent, and annual-fee status,
/// then inserts a [Member] via [DatabaseHelper] and navigates to the success screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Mutable state for [RegisterScreen].
class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  /// Whether the member consents to receiving communications.
  bool _communication = false;

  /// Whether the member has paid the annual fee.
  bool _annualFee = false;

  /// Guards against duplicate submissions.
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final member = Member(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        communication: _communication,
        annualFee: _annualFee,
      );

      final created = await DatabaseHelper.instance.insertMember(member);

      if (!mounted) return;

      // Navigate to success screen, passing the assigned member number.
      Navigator.pushReplacementNamed(
        context,
        '/registration-success',
        arguments: {
          'name': created.name,
          'memberNumber': created.memberNumber,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tr('memberRegistration')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              '/register-daily',
            ),
            child: Text(
              AppLocalizations.of(context).tr('dailyMemberRegistrationLink'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).tr('memberRegistration'),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('name'),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? AppLocalizations.of(context).tr('nameRequired') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('emailOptional'),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text(
                      AppLocalizations.of(context).tr('communicationCheckbox'),
                    ),
                    value: _communication,
                    onChanged: (v) => setState(() => _communication = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: Text(AppLocalizations.of(context).tr('annualFeePaid')),
                    value: _annualFee,
                    onChanged: (v) => setState(() => _annualFee = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
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
                        : Text(AppLocalizations.of(context).tr('register')),
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

/// Registration form for daily (one-time) members.
/// Collects name and optional notes, inserts a [DailyMember] via
/// [DatabaseHelper], and navigates to the daily success screen.
class RegisterDailyScreen extends StatefulWidget {
  const RegisterDailyScreen({super.key});

  @override
  State<RegisterDailyScreen> createState() => _RegisterDailyScreenState();
}

/// Mutable state for [RegisterDailyScreen].
class _RegisterDailyScreenState extends State<RegisterDailyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  /// Guards against duplicate submissions.
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final member = DailyMember(
        name: _nameController.text.trim(),
        notes: _notesController.text.trim(),
      );

      final created = await DatabaseHelper.instance.insertDailyMember(member);

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/daily-registration-success',
        arguments: {
          'name': created.name,
          'dailyMemberNumber': created.dailyMemberNumber,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tr('dailyMemberRegistration')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              '/register',
            ),
            child: Text(
              AppLocalizations.of(context).tr('memberRegistrationLink'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).tr('dailyMemberRegistration'),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('name'),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? AppLocalizations.of(context).tr('nameRequired') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).tr('notesOptional'),
                      prefixIcon: const Icon(Icons.note),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
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
                        : Text(AppLocalizations.of(context).tr('register')),
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

/// Success screen shown after a regular member registration.
/// Expects route arguments `name` (String) and `memberNumber` (int?).
class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final name = args?['name'] ?? '';
    final memberNumber = args?['memberNumber'];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).tr('registrationComplete'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).trArgs('congratsName', {'name': name}),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (memberNumber != null)
                Text(
                  AppLocalizations.of(context).trArgs('yourMemberNumber', {'number': '$memberNumber'}),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                ),
                child: Text(AppLocalizations.of(context).tr('backToHome')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success screen shown after a daily member registration.
/// Expects route arguments `name` (String) and `dailyMemberNumber` (int?).
class DailyRegistrationSuccessScreen extends StatelessWidget {
  const DailyRegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final name = args?['name'] ?? '';
    final dailyNumber = args?['dailyMemberNumber'];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).tr('registrationComplete'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).trArgs('welcomeName', {'name': name}),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (dailyNumber != null)
                Text(
                  AppLocalizations.of(context).trArgs('yourDailyMemberNumber', {'number': '$dailyNumber'}),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                ),
                child: Text(AppLocalizations.of(context).tr('backToHome')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
