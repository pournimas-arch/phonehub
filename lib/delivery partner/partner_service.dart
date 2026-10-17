import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'orders_data.dart';

/// The signed-in delivery partner (record created by the admin in `partners/{email}`).
class PartnerProfile {
  final String id, name, phone, vehicle, email;
  final double rating;

  const PartnerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.email,
    required this.rating,
  });

  String get initial =>
      name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();

  String get firstName =>
      name.trim().isEmpty ? 'Partner' : name.trim().split(' ').first;
}

/// Delivery partner login with Firebase Authentication + Firestore.
///
/// How a partner gets access:
///  1. Admin creates `partners/{lowercase-email}`.
///  2. Partner activates an account or signs in with that email.
///  3. The first valid login links the Firebase UID to the partner record.
///  4. Only orders assigned to that partner email are shown.
class PartnerService {
  PartnerService._();

  static final PartnerService instance = PartnerService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PartnerProfile? current;

  /// Live copy of `partners/{email}` (vehicle, bank, online status, etc.).
  final ValueNotifier<Map<String, dynamic>> data =
  ValueNotifier<Map<String, dynamic>>({});

  /// Live copy of `partners/{email}/docs` (Licence / Aadhaar / RC status).
  final ValueNotifier<Map<String, Map<String, dynamic>>> docs =
  ValueNotifier<Map<String, Map<String, dynamic>>>({});

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _docsSub;

  static const Set<String> _editablePartnerFields = {
    'vehicleNo',
    'vehicleModel',
    'vehicleType',
    'fuelType',
    'bankHolder',
    'bankName',
    'bankAccount',
    'bankIfsc',
  };

  static const Set<String> _documentKeys = {
    'licence',
    'aadhaar',
    'rc',
  };

  void _startProfile(String id) {
    _stopProfile();

    _profileSub = _db.doc('partners/$id').snapshots().listen(
          (snapshot) {
        data.value = snapshot.data() ?? <String, dynamic>{};
      },
      onError: (Object error) {
        debugPrint('PhoneHub partner profile listener: $error');
      },
    );

    _docsSub = _db.collection('partners/$id/docs').snapshots().listen(
          (snapshot) {
        docs.value = {
          for (final document in snapshot.docs) document.id: document.data(),
        };
      },
      onError: (Object error) {
        debugPrint('PhoneHub partner documents listener: $error');
      },
    );
  }

  void _stopProfile() {
    _profileSub?.cancel();
    _docsSub?.cancel();
    _profileSub = null;
    _docsSub = null;
    data.value = <String, dynamic>{};
    docs.value = <String, Map<String, dynamic>>{};
  }

  /// Saves only the vehicle and bank fields editable by the partner.
  /// Returns null on success, otherwise a user-friendly message.
  ///
  /// Firestore Rules must allow these same field names for a linked partner.
  Future<String?> saveFields(Map<String, dynamic> fields) async {
    final partner = current;
    if (partner == null || _auth.currentUser == null) {
      return 'Please log in again';
    }

    if (fields.isEmpty || fields.keys.any((key) => !_editablePartnerFields.contains(key))) {
      return 'These details cannot be changed from the partner account.';
    }

    final cleaned = <String, dynamic>{};
    for (final entry in fields.entries) {
      if (entry.value is! String) {
        return 'Please enter valid details and try again.';
      }

      final value = (entry.value as String).trim();
      if (value.length > 120) {
        return 'Please keep each field within 120 characters.';
      }
      cleaned[entry.key] = value;
    }

    // Basic server-independent validation. The UI also performs validation;
    // keeping checks here prevents other callers from bypassing it.
    final account = cleaned['bankAccount'];
    if (account is String &&
        account.isNotEmpty &&
        !RegExp(r'^[0-9]{6,20}$').hasMatch(account)) {
      return 'Enter a valid bank account number.';
    }

    final ifsc = cleaned['bankIfsc'];
    if (ifsc is String &&
        ifsc.isNotEmpty &&
        !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc.toUpperCase())) {
      return 'Enter a valid IFSC code.';
    }

    final vehicleNo = cleaned['vehicleNo'];
    if (vehicleNo is String && vehicleNo.length > 20) {
      return 'Enter a valid vehicle number.';
    }

    try {
      await _db.doc('partners/${partner.id}').update({
        ...cleaned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (error) {
      debugPrint('PhoneHub save partner fields: ${error.code}');
      if (error.code == 'permission-denied') {
        return 'Not allowed to save these details. Please contact the admin.';
      }
      if (error.code == 'unavailable' || error.code == 'network-request-failed') {
        return 'No internet connection. Please try again.';
      }
      return 'Could not save. Please try again.';
    } catch (error) {
      debugPrint('PhoneHub save partner fields failed: $error');
      return 'Could not save. Please try again.';
    }
  }

  /// Uploads a data URI for a known document key. New submissions always start
  /// as Pending; a partner cannot choose Verified/Rejected or provide a reason.
  ///
  /// Note: Firestore documents have a 1 MiB size limit. Large images should be
  /// uploaded to Firebase Storage and only their download URL saved here.
  Future<String?> uploadDocument(String key, String dataUri) async {
    final partner = current;
    if (partner == null || _auth.currentUser == null) {
      return 'Please log in again';
    }

    if (!_documentKeys.contains(key)) {
      return 'Unknown document type. Please select Licence, Aadhaar or RC.';
    }

    final uri = dataUri.trim();
    if (!uri.startsWith('data:image/')) {
      return 'Please select a valid image.';
    }
    if (uri.length > 650000) {
      return 'Photo is too large. Please take a smaller photo.';
    }

    try {
      final docRef = _db.doc('partners/${partner.id}/docs/$key');
      final existing = await docRef.get();

      // A verified document must not be overwritten by a partner.
      if (existing.exists &&
          (existing.data()?['status'] ?? 'Pending') == 'Verified') {
        return 'This document is already verified. Contact the admin if it needs to be changed.';
      }

      // FIX: the Firestore rule for partners/{id}/docs/{key} only accepts the
      // keys image, status, reason, updatedAt and createdAt. The old code
      // wrote "uploadedAt", so every upload was refused (permission-denied).
      // createdAt is kept from the first upload; updatedAt changes each time.
      final firstUpload = existing.data()?['createdAt'];
      await docRef.set({
        'image': uri,
        'status': 'Pending',
        'reason': '',
        'createdAt': firstUpload ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (error) {
      debugPrint('PhoneHub upload partner document: ${error.code}');
      if (error.code == 'permission-denied') {
        return 'Upload was not permitted. Please contact the admin or try a smaller photo.';
      }
      if (error.code == 'unavailable' || error.code == 'network-request-failed') {
        return 'No internet connection. Please try again.';
      }
      return 'Could not upload. Please try again.';
    } catch (error) {
      debugPrint('PhoneHub upload partner document failed: $error');
      return 'Could not upload. Please try again.';
    }
  }

  /// Returns an error message, or null when login worked.
  Future<String?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return 'Enter your email and password.';
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        await _auth.signOut();
        return 'Could not sign in. Please try again.';
      }

      final error = await _claim(user);
      if (error != null) {
        await _auth.signOut();
        return error;
      }
      return null;
    } on FirebaseAuthException catch (error) {
      return _msg(error);
    } on FirebaseException catch (error) {
      await _auth.signOut();
      debugPrint('PhoneHub partner login Firestore error: ${error.code}');
      return error.code == 'permission-denied'
          ? 'Could not access the partner account. Please contact the admin.'
          : 'Something went wrong. Please try again.';
    } catch (error) {
      debugPrint('PhoneHub partner login failed: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  /// First-time activation for the email registered by the admin.
  Future<String?> activate(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.length < 6) {
      return normalizedEmail.isEmpty
          ? 'Enter your registered email address.'
          : 'Password must contain at least 6 characters.';
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        await _auth.signOut();
        return 'Could not activate the account. Please try again.';
      }

      final error = await _claim(user);
      if (error != null) {
        // Do not leave a newly created but unlinked login signed in.
        try {
          await user.delete();
        } catch (deleteError) {
          debugPrint('PhoneHub cleanup of unlinked account failed: $deleteError');
        }
        await _auth.signOut();
        return error;
      }
      return null;
    } on FirebaseAuthException catch (error) {
      return error.code == 'email-already-in-use'
          ? 'This email already has a login. Use "Login" instead.'
          : _msg(error);
    } on FirebaseException catch (error) {
      debugPrint('PhoneHub partner activation Firestore error: ${error.code}');
      try {
        await credential?.user?.delete();
      } catch (_) {}
      await _auth.signOut();
      return error.code == 'permission-denied'
          ? 'Could not link this account. Please contact the admin.'
          : 'Could not activate the account. Please try again.';
    } catch (error) {
      debugPrint('PhoneHub partner activation failed: $error');
      try {
        await credential?.user?.delete();
      } catch (_) {}
      await _auth.signOut();
      return 'Something went wrong. Please try again.';
    }
  }

  /// Links the Firebase Auth UID to the admin-created partner document.
  Future<String?> _claim(User user) async {
    final id = (user.email ?? '').trim().toLowerCase();
    if (id.isEmpty) return 'This account has no email address.';

    final ref = _db.doc('partners/$id');
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      return 'This email is not registered as a delivery partner. Ask the admin to add you.';
    }

    final partnerData = snapshot.data() ?? <String, dynamic>{};
    if ((partnerData['isActive'] ?? partnerData['active'] ?? true) != true) {
      return 'Your partner account is disabled by the admin.';
    }

    final linkedUid = (partnerData['uid'] ?? '').toString().trim();
    if (linkedUid.isEmpty) {
      // The matching Firestore rule must permit a one-time UID claim only.
      await ref.update({
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (linkedUid != user.uid) {
      return 'This partner account is linked to another login.';
    }

    final rating = partnerData['rating'];
    current = PartnerProfile(
      id: id,
      name: (partnerData['name'] ?? '').toString(),
      phone: (partnerData['phone'] ?? '').toString(),
      vehicle: (partnerData['vehicle'] ?? partnerData['vehicleModel'] ?? '')
          .toString(),
      email: id,
      // Real rating saved on partners/{email}; 0 until one exists
      // (no made-up 5.0 any more).
      rating: rating is num && rating > 0 ? rating.toDouble() : 0.0,
    );

    startDeliveryListener(id);
    _startProfile(id);
    return null;
  }

  /// Online / Offline switch on the profile screen.
  ///
  /// Errors are logged and rethrown so the calling screen can restore its
  /// previous switch value and show an error message instead of treating a
  /// failed Firestore update as successful.
  Future<void> setOnline(bool online) async {
    final partner = current;
    if (partner == null || _auth.currentUser == null) {
      throw StateError('Please log in again.');
    }

    try {
      await _db.doc('partners/${partner.id}').update({
        'online': online,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      debugPrint('PhoneHub partner online status failed: ${error.code}');
      rethrow;
    } catch (error) {
      debugPrint('PhoneHub partner online status failed: $error');
      rethrow;
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return 'Enter your email address.';

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
      return null;
    } on FirebaseAuthException catch (error) {
      return _msg(error);
    } catch (error) {
      debugPrint('PhoneHub partner password reset failed: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> logout() async {
    stopDeliveryListener();
    _stopProfile();
    current = null;
    await _auth.signOut();
  }

  String _msg(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}