import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/constants.dart';
import '../../data/models/profile.dart';
import '../../state/auth_state.dart';

/// Profil du travailleur : informations, préférences, mot de passe, déconnexion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _phoneController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _positionController = TextEditingController();

  String _language = 'fr';
  bool _receivePush = true;
  bool _receiveEmail = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthState>().user;
    if (user != null) {
      _firstController.text = user.firstName;
      _lastController.text = user.lastName;
      _phoneController.text = user.phone;
      _matriculeController.text = user.profile.matricule;
      _positionController.text = user.profile.position;
      _language = user.profile.language.isEmpty ? 'fr' : user.profile.language;
      _receivePush = user.profile.receivePush;
      _receiveEmail = user.profile.receiveEmail;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _phoneController.dispose();
    _matriculeController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthState>().updateProfile({
        'first_name': _firstController.text.trim(),
        'last_name': _lastController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profile': Profile(
          matricule: _matriculeController.text.trim(),
          position: _positionController.text.trim(),
          language: _language,
          phone: _phoneController.text.trim(),
          receivePush: _receivePush,
          receiveEmail: _receiveEmail,
        ).toJson(),
      });
      _showMessage('Profil mis à jour.', success: true);
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (newController.text != confirmController.text) {
      _showMessage('Les deux mots de passe ne correspondent pas.');
      return;
    }
    if (newController.text.length < 8) {
      _showMessage('Le nouveau mot de passe est trop court.');
      return;
    }

    try {
      await context.read<AuthState>().changePassword(
            oldPassword: oldController.text,
            newPassword: newController.text,
          );
      _showMessage('Mot de passe modifié avec succès.', success: true);
    } on ApiException catch (error) {
      _showMessage(error.firstFieldError() ?? error.message);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<AuthState>().logout();
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false)
                            ? user!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(user?.email ?? ''),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(AppConstants.roleLabel(user?.role)),
                      avatar: const Icon(Icons.badge_outlined, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _SectionTitle('Informations'),
            TextFormField(
              controller: _firstController,
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _matriculeController,
              decoration: const InputDecoration(labelText: 'Matricule'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(labelText: 'Poste'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Langue'),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'ar', child: Text('Arabe')),
                DropdownMenuItem(value: 'en', child: Text('Anglais')),
              ],
              onChanged: (value) =>
                  setState(() => _language = value ?? 'fr'),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Préférences de notification'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recevoir les notifications push'),
              value: _receivePush,
              onChanged: (value) => setState(() => _receivePush = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recevoir les e-mails'),
              value: _receiveEmail,
              onChanged: (value) => setState(() => _receiveEmail = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer les modifications'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Changer le mot de passe'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
