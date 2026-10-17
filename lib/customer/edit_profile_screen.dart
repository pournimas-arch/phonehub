import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'checkout_ui.dart' show CheckoutBackground;
import 'data.dart';
import 'package:phonehub/app_text.dart';

/// Edit Profile – name, phone and email. Saving updates the whole app
/// (home greeting, profile card) and the sign-in account.
///
/// FIXED: name and phone were not kept.
///  * The screen now reads the real `users/{uid}` document when it opens (old accounts may
///    keep the name under `fullName`, or may have no profile document at all).
///  * Saving no longer sends the protected `role` field on an existing profile (the Firestore
///    rules refuse any write that touches `role`). It updates only name / fullName / phone, or
///    creates the profile document when it is missing.
///  * The app-wide profile is changed only AFTER Firestore has accepted the write, so the
///    screen can no longer show a saved value that was never stored.
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

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Keeps the avatar letter in sync while typing.
    _name.addListener(() => setState(() {}));
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String _pick(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// Fills the fields from the real saved profile (never overwrites what the person already typed).
  Future<void> _loadSavedProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    Map<String, dynamic> d = <String, dynamic>{};
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      d = snap.data() ?? <String, dynamic>{};
    } catch (_) {
      // Offline or blocked: the Auth account details below are still used.
    }
    if (!mounted) return;

    final name = _pick([d['name'], d['fullName'], d['displayName'], profile.value.name, user.displayName]);
    final phone = _pick([d['phone'], d['phoneNumber'], d['mobile'], profile.value.phone, user.phoneNumber]);
    final email = _pick([user.email, d['email'], profile.value.email]);

    if (_name.text.trim().isEmpty && name.isNotEmpty) _name.text = name;
    if (_phone.text.trim().isEmpty && phone.isNotEmpty) _phone.text = phone;
    if (_email.text.trim().isEmpty && email.isNotEmpty) _email.text = email;
  }

  /// Writes the profile. Update when the document exists, create it when it does not.
  Future<void> _persist(User user, String name, String phone, String email) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      final d = snap.data() ?? <String, dynamic>{};
      await ref.update({
        'name': name,
        'fullName': name,
        'phone': phone,
        // Old profiles may have no email / uid saved; add them (harmless fields).
        if (_pick([d['email']]).isEmpty) 'email': email,
        if (_pick([d['uid']]).isEmpty) 'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'uid': user.uid,
        'name': name,
        'fullName': name,
        'phone': phone,
        'email': email,
        'role': 'customer',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    // Keep the sign-in account name in step (best effort).
    try {
      if ((user.displayName ?? '').trim() != name) await user.updateDisplayName(name);
    } catch (_) {}
  }

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

    final name = _name.text.trim();
    final phone = _phone.text.trim();

    setState(() => _saving = true);
    try {
      await _persist(user, name, phone, newEmail);
      // Only now (Firestore accepted it) the whole app shows the new details.
      profile.value = UserProfile(name: name, phone: phone, email: newEmail);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'permission-denied':
          message = 'Your profile could not be saved. Please sign in again or contact PhoneHub support.';
          break;
        case 'unavailable':
        case 'network-request-failed':
          message = 'No internet connection. Please try again.';
          break;
        default:
          message = 'Could not update profile. Please try again.';
      }
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