import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push notifications (FCM) for the Customer and Delivery apps.
///
/// How it works:
///  1. After a successful login the app calls [register] with the Firestore document of the
///     signed-in person: `users/{uid}` (customer) or `partners/{email}` (delivery partner).
///  2. The device token is saved in that document as `fcmToken`
///     (Firestore Rules already allow this field for both roles).
///  3. Whenever any app writes a document to `notifications/{id}`, the Cloud Function
///     `pushOnNotification` (functions/push.js) finds the token and sends the push.
///  4. On log out the app calls [unregister], so the next person using this phone never
///     receives the previous person's notifications.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  String? _docPath;
  StreamSubscription<String>? _refreshSub;

  /// Call once from main() after Firebase.initializeApp().
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      // iOS: show the banner even while the app is open.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('PhoneHub push init failed: $e');
    }
  }

  /// Asks for permission (Android 13+ / iOS) and saves this phone's token on [docPath].
  /// Never throws: a push problem must not block login.
  Future<void> register(String docPath) async {
    if (kIsWeb) return;
    try {
      _docPath = docPath;
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PhoneHub push: notification permission denied');
        return;
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _save(docPath, token);

      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((t) {
        final path = _docPath;
        if (path != null && t.isNotEmpty) _save(path, t);
      });
    } catch (e) {
      debugPrint('PhoneHub push register failed: $e');
    }
  }

  /// Call BEFORE signing out (the Firestore write needs the signed-in user).
  Future<void> unregister() async {
    if (kIsWeb) return;
    final path = _docPath;
    _docPath = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    try {
      if (path != null) {
        await FirebaseFirestore.instance.doc(path).update({
          'fcmToken': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('PhoneHub push token clear failed: $e');
    }
    try {
      // A new token is created for the next login, so the old one is dead for good.
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('PhoneHub push deleteToken failed: $e');
    }
  }

  Future<void> _save(String docPath, String token) async {
    try {
      await FirebaseFirestore.instance.doc(docPath).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PhoneHub push token save failed: $e');
    }
  }
}