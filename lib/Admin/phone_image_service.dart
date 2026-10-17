import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// A product photo selected from Gallery or Camera.
///
/// Photos are kept as bytes in memory and encoded as a data URI when the
/// product is saved. This avoids Firebase Storage and does not require billing.
class PickedPhoto {
  final Uint8List bytes;
  final String ext;

  const PickedPhoto(this.bytes, this.ext);

  String get contentType {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String toDataUri() => 'data:$contentType;base64,${base64Encode(bytes)}';
}

/// Picks local product photos. No Firebase Storage is used.
class PhoneImageService {
  PhoneImageService._();

  static final ImagePicker _picker = ImagePicker();

  static const int maxPhotos = 6;
  static const double _maxSide = 1600;
  static const int _quality = 80;
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  static String _extensionOf(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static Future<PickedPhoto> _readPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected photo is empty. Please choose another photo.');
    }
    if (bytes.lengthInBytes > maxPhotoBytes) {
      throw StateError('Each product photo must be 10 MB or smaller.');
    }
    return PickedPhoto(bytes, _extensionOf(file));
  }

  /// Select multiple photos from the gallery.
  static Future<List<PickedPhoto>> pickFromGallery({required int remaining}) async {
    if (remaining <= 0) return const <PickedPhoto>[];
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (files.isEmpty) return const <PickedPhoto>[];

      final photos = <PickedPhoto>[];
      for (final file in files.take(remaining)) {
        photos.add(await _readPhoto(file));
      }
      return photos;
    } on StateError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('PhoneHub gallery selection failed: $error\\n$stackTrace');
      rethrow;
    }
  }

  /// Take a photo with the camera. Returns null if cancelled.
  static Future<PickedPhoto?> pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (file == null) return null;
      return await _readPhoto(file);
    } on StateError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('PhoneHub camera selection failed: $error\\n$stackTrace');
      rethrow;
    }
  }

  /// Compatibility method for existing ProductsScreen code.
  ///
  /// Instead of uploading to Firebase Storage, returns a local data URI.
  /// This avoids requiring a Firebase billing account.
  static Future<String> upload(String phoneId, PickedPhoto photo) async {
    if (phoneId.trim().isEmpty) {
      throw ArgumentError.value(
        phoneId,
        'phoneId',
        'Product ID cannot be empty.',
      );
    }
    if (photo.bytes.isEmpty) {
      throw StateError(
        'The selected photo is empty. Please choose another photo.',
      );
    }
    if (photo.bytes.lengthInBytes > maxPhotoBytes) {
      throw StateError('Each product photo must be 10 MB or smaller.');
    }
    return photo.toDataUri();
  }

  /// Compatibility method for existing code that uploads multiple photos.
  /// The returned strings are local data URIs, not hosted download URLs.
  static Future<List<String>> uploadAll(
      String phoneId,
      List<PickedPhoto> photos, {
        void Function(int done, int total)? onProgress,
      }) async {
    final results = <String>[];
    for (var i = 0; i < photos.length; i++) {
      results.add(await upload(phoneId, photos[i]));
      onProgress?.call(i + 1, photos.length);
    }
    return results;
  }

  /// Compatibility method for existing cleanup calls.
  ///
  /// Local data URIs are not stored in Firebase Storage, so there is nothing
  /// to delete remotely. Kept to prevent compile errors in existing screens.
  static Future<void> deleteByUrl(String url) async {
    // Intentionally no-op: this billing-free implementation uses local data.
  }

}
