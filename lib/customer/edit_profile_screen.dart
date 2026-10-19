import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// NEW (validation):
///  * Name: letters only, 2-50 characters, extra spaces collapsed.
///  * Phone: 10-digit Indian mobile (starts with 6-9), +91 / 0 prefix accepted and removed,
///    repeated-digit numbers refused, saved as clean 10 digits.
///  * Email: proper format, max length, and the login email cannot be changed here
///    (the error is shown on the field instead of only after pressing Save).
///  * "No changes" guard, live validation while typing, and input filters.
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

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------
  static const int _maxName = 50;
  static const int _maxEmail = 100;

  static final RegExp _nameChars = RegExp(r"^\p{L}[\p{L} .'-]*$", unicode: true);
  static final RegExp _emailFormat =
  RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

  /// Trims and collapses repeated spaces ("Ravi   Kumar " -> "Ravi Kumar").
  String _cleanName(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Keeps only the digits and removes a +91 / 91 / 0 prefix, so the result is the 10-digit number.
  String _phoneDigits(String v) {
    var d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length == 11 && d.startsWith('0')) {
      d = d.substring(1);
    }
    return d;
  }

  String? _validateName(String? v) {
    final s = _cleanName(v ?? '');
    if (s.isEmpty) return 'Enter your name';
    if (s.length < 2) return 'Name must be at least 2 characters';
    if (s.length > _maxName) return 'Name must be $_maxName characters or fewer';
    if (!_nameChars.hasMatch(s)) return 'Use letters only (no numbers or symbols)';
    return null;
  }

  String? _validatePhone(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Enter your phone number';
    if (RegExp(r'[^0-9+\-() ]').hasMatch(raw)) return 'Phone number can only contain digits';
    final d = _phoneDigits(raw);
    if (d.length != 10) return 'Enter a 10-digit mobile number';
    if (!RegExp(r'^[6-9]').hasMatch(d)) return 'Mobile number must start with 6, 7, 8 or 9';
    if (RegExp(r'^(\d)\1{9}$').hasMatch(d)) return 'Enter a real mobile number';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email';
    if (s.length > _maxEmail) return 'Email must be $_maxEmail characters or fewer';
    if (!_emailFormat.hasMatch(s)) return 'Enter a valid email';
    final login = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
    if (login.isNotEmpty && s.toLowerCase() != login) {
      return 'Your login email cannot be changed here';
    }
    return null;
  }

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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
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

    final name = _cleanName(_name.text);
    final phone = _phoneDigits(_phone.text);

    // Nothing changed -> no need to write to Firestore.
    final current = profile.value;
    if (name == _cleanName(current.name) && phone == _phoneDigits(current.phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

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

  Widget _field(
      String label,
      TextEditingController c,
      IconData icon,
      String? Function(String?) validator, {
        TextInputType? type,
        List<TextInputFormatter>? formatters,
        TextInputAction? action,
      }) {
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
              textInputAction: action,
              inputFormatters: formatters,
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
              _field(
                'Full name',
                _name,
                Icons.person_outline_rounded,
                _validateName,
                action: TextInputAction.next,
                formatters: [
                  LengthLimitingTextInputFormatter(_maxName),
                  FilteringTextInputFormatter.allow(RegExp(r"[\p{L} .'\-]", unicode: true)),
                ],
              ),
              _field(
                'Phone number',
                _phone,
                Icons.phone_outlined,
                _validatePhone,
                type: TextInputType.phone,
                action: TextInputAction.next,
                formatters: [
                  LengthLimitingTextInputFormatter(16),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                ],
              ),
              _field(
                'Email',
                _email,
                Icons.email_outlined,
                _validateEmail,
                type: TextInputType.emailAddress,
                action: TextInputAction.done,
                formatters: [
                  LengthLimitingTextInputFormatter(_maxEmail),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
              ),
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