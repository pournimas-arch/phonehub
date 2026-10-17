import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The admin of the app.
class AdminAccount {
  final String uid;
  final String name;
  final String email;
  final String phone;
  const AdminAccount({required this.uid, required this.name, required this.email, required this.phone});
}

/// Admin sign-in using Firebase Authentication + Cloud Firestore.
///
/// - Login / register go through Firebase Auth.
/// - Forgot password uses a 6 digit OTP sent by email. The OTP is created,
///   stored, checked and used by Cloud Functions (never inside the app).
/// - Customers, delivery partners and the admin share one Firebase Auth
///   project, so the admin is marked in Firestore: `admins/{uid}`.
/// - Only ONE admin can exist: registering writes `meta/admin`, and the
///   Firestore rules refuse a second one.
/// - Nothing (email, password, code) is hardcoded.
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  static const _kRemember = 'admin_remember_email';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Default region is us-central1. If you deploy your functions to another
  // region (e.g. Mumbai), use: FirebaseFunctions.instanceFor(region: 'asia-south1')
  final FirebaseFunctions _fn = FirebaseFunctions.instance;

  SharedPreferences? _prefs;
  bool? _adminExists; // null = not checked yet

  /// The signed-in admin (null when logged out).
  AdminAccount? current;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ---- Remember me (saves only the email) ----------------------------------

  String? get rememberedEmail => _prefs?.getString(_kRemember);

  Future<void> setRememberedEmail(String? email) async {
    await init();
    if (email == null || email.isEmpty) {
      await _prefs!.remove(_kRemember);
    } else {
      await _prefs!.setString(_kRemember, email);
    }
  }

  // ---- Does the one admin exist yet? ---------------------------------------

  bool get adminKnown => _adminExists != null;
  bool get hasAdmin => _adminExists ?? false;

  /// True only when we are sure no admin has registered yet.
  bool get canRegister => _adminExists == false;

  Future<bool> refreshAdminExists() async {
    try {
      final d = await _db.doc('meta/admin').get();
      _adminExists = d.exists;
    } catch (_) {
      // offline / rules problem: stay "unknown"
    }
    return hasAdmin;
  }

  // ---- Session restore (used by the splash screen) -------------------------

  /// Opens the app straight into the dashboard when the admin chose
  /// "Remember me" and is still signed in. Otherwise signs out.
  Future<bool> restoreSession() async {
    await init();
    await refreshAdminExists();
    final user = _auth.currentUser;
    if (user == null) return false;
    if (rememberedEmail == null) {
      await _auth.signOut();
      return false;
    }
    try {
      final acct = await _loadAdmin(user);
      if (acct == null) {
        await _auth.signOut();
        return false;
      }
      current = acct;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AdminAccount?> _loadAdmin(User user) async {
    final doc = await _db.doc('admins/${user.uid}').get();
    if (!doc.exists) return null;
    final d = doc.data() ?? {};
    return AdminAccount(
      uid: user.uid,
      name: (d['name'] ?? user.displayName ?? '') as String,
      email: (d['email'] ?? user.email ?? '') as String,
      phone: (d['phone'] ?? '') as String,
    );
  }

  // ---- Register (only the first time) --------------------------------------

  /// Returns an error message, or null when the admin account was created.
  Future<String?> register({required String name, required String email, required String phone, required String password}) async {
    UserCredential? cred;
    try {
      final meta = await _db.doc('meta/admin').get();
      if (meta.exists) {
        _adminExists = true;
        return 'An admin account already exists. Please login.';
      }

      cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user!;

      final batch = _db.batch();
      batch.set(_db.doc('meta/admin'), {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
      batch.set(_db.doc('admins/${user.uid}'), {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await user.updateDisplayName(name.trim());

      _adminExists = true;
      current = AdminAccount(uid: user.uid, name: name.trim(), email: email.trim(), phone: phone.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } on FirebaseException catch (e) {
      // Admin record could not be saved: remove the Auth user we just made.
      try {
        await cred?.user?.delete();
      } catch (_) {}
      return e.code == 'permission-denied' ? 'An admin account already exists. Please login.' : (e.message ?? 'Something went wrong. Please try again');
    } catch (_) {
      try {
        await cred?.user?.delete();
      } catch (_) {}
      return 'Something went wrong. Please try again';
    }
  }

  // ---- Login ---------------------------------------------------------------

  /// Returns an error message, or null when login worked.
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final acct = await _loadAdmin(cred.user!);
      if (acct == null) {
        await _auth.signOut();
        return 'This account is not an admin account';
      }
      current = acct;
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      return e.message ?? 'Something went wrong. Please try again';
    } catch (_) {
      return 'Something went wrong. Please try again';
    }
  }

  /// Call this from the admin "Logout" button.
  Future<void> logout() async {
    current = null;
    await _auth.signOut();
  }

  // ---- Forgot password (OTP) -----------------------------------------------
  //
  // These three methods call Cloud Functions with the same names:
  //   sendAdminPasswordOtp, verifyAdminPasswordOtp, resetAdminPasswordWithOtp
  // Each returns an error message, or null on success.

  /// Step 1: the server emails a 6 digit OTP to the admin.
  Future<String?> sendPasswordOtp(String email) =>
      _callFn('sendAdminPasswordOtp', {'email': email.trim()});

  /// Step 2: the server checks the OTP the admin typed.
  Future<String?> verifyPasswordOtp(String email, String otp) =>
      _callFn('verifyAdminPasswordOtp', {'email': email.trim(), 'otp': otp.trim()});

  /// Step 3: the server checks the OTP again and sets the new password.
  Future<String?> resetPasswordWithOtp({required String email, required String otp, required String newPassword}) =>
      _callFn('resetAdminPasswordWithOtp', {'email': email.trim(), 'otp': otp.trim(), 'newPassword': newPassword});

  Future<String?> _callFn(String name, Map<String, dynamic> data) async {
    try {
      await _fn.httpsCallable(name).call(data);
      return null;
    } on FirebaseFunctionsException catch (e) {
      // The server sends readable messages (wrong OTP, expired, too many tries...).
      switch (e.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return 'No internet connection';
        case 'not-found':
          return 'Service not available. Please contact support';
        case 'internal':
        case 'unknown':
          return e.message == null || e.message == 'INTERNAL' ? 'Something went wrong. Please try again' : e.message;
        default:
          return e.message ?? 'Something went wrong. Please try again';
      }
    } catch (_) {
      return 'Something went wrong. Please try again';
    }
  }

  /// OLD link based reset (not used by the app any more, kept in case you
  /// need it). Firebase emails a reset link.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Something went wrong. Please try again';
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password';
      case 'email-already-in-use':
        return 'This email is already registered. Use another email or login.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'No internet connection';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return e.message ?? 'Something went wrong. Please try again';
    }
  }
}