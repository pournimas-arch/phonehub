import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'checkout_ui.dart' show CheckoutBackground;
import 'data.dart';
import 'package:phonehub/app_text.dart';

/// Edit Profile – name, phone and email. Saving updates the whole app
/// (home greeting, profile card) and the sign-in account.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: profile.value.name);
  late final _phone = TextEditingController(text: profile.value.phone);
  late final _email = TextEditingController(text: profile.value.email);

  @override
  void initState() {
    super.initState();
    // Keeps the avatar letter in sync while typing.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to update your profile.')),
      );
      return;
    }

    final newEmail = _email.text.trim().toLowerCase();
    final oldEmail = (user.email ?? profile.value.email).trim().toLowerCase();
    if (newEmail != oldEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To change your login email, use the account email update flow.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await updateProfile(UserProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: newEmail,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Profile update blocked. Check Firestore Rules for users/{uid}.'
          : 'Could not update profile. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, IconData icon, String? Function(String?) validator, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.body, color: AppColors.text)),
          const SizedBox(height: 6),
          Container(
            decoration: cardDeco(radius: 16),
            child: TextFormField(
              controller: c,
              keyboardType: type,
              validator: validator,
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Same gradient + soft circles background as the Home screen.
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Edit Profile'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _name.text.trim().isEmpty ? 'P' : _name.text.trim()[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _field('Full name', _name, Icons.person_outline_rounded, (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null),
              _field('Phone number', _phone, Icons.phone_outlined, (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Enter a valid phone number' : null, type: TextInputType.phone),
              _field('Email', _email, Icons.email_outlined, (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null, type: TextInputType.emailAddress),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}