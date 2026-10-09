import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../data/api/auth_api.dart';
import '../../data/api/dio_client.dart';

/// Réinitialisation du mot de passe en deux étapes :
/// 1. demande d'un code par e-mail ;
/// 2. confirmation avec l'identifiant, le code et le nouveau mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const String routeName = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _uidController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _uidController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthApi get _api => AuthApi(context.read<DioClient>());

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
    );
  }

  Future<void> _requestCode() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _api.requestPasswordReset(_emailController.text.trim());
      setState(() => _codeSent = true);
      _showInfo('Si un compte correspond à cette adresse, un e-mail a été envoyé.');
    } on ApiException catch (error) {
      _showError(error.firstFieldError() ?? error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_uidController.text.trim().isEmpty ||
        _tokenController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Veuillez renseigner tous les champs.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.confirmPasswordReset(
        uid: _uidController.text.trim(),
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      _showInfo('Mot de passe réinitialisé. Vous pouvez vous connecter.');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      _showError(error.firstFieldError() ?? error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _requestFormKey,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Veuillez saisir votre e-mail.';
                  if (!v.contains('@')) return 'Adresse e-mail invalide.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              ElevatedButton(
                onPressed: _busy ? null : _requestCode,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Envoyer le code'),
              ),
            if (_codeSent) ...[
              const Divider(height: 32),
              const Text(
                'Saisissez l\'identifiant et le code reçus par e-mail, puis votre nouveau mot de passe.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uidController,
                decoration: const InputDecoration(labelText: 'Identifiant (uid)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: 'Code de réinitialisation'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Réinitialiser le mot de passe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
