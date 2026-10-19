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

  /// Size this photo will take inside the Firestore product document (base64 text),
  /// worked out without building the whole data URI. Used to check the 1 MiB document limit.
  int get storedBytes => 'data:$contentType;base64,'.length + ((bytes.lengthInBytes + 2) ~/ 3) * 4;
}

/// Picks local product photos. No Firebase Storage is used.
class PhoneImageService {
  PhoneImageService._();

  static final ImagePicker _picker = ImagePicker();

  static const int maxPhotos = 6;

  // Photos are saved inside the Firestore product document (limit 1 MiB for the whole
  // document), so they are shrunk harder than before: 1000 px on the long side, quality 60.
  // A normal phone photo is then roughly 80 to 160 KB.
  static const double _maxSide = 1000;
  static const int _quality = 60;

  /// Largest single photo accepted AFTER resizing (was 10 MB). The form also checks that all
  /// photos together stay under its total limit.
  static const int maxPhotoBytes = 350 * 1024;

  /// A short message about the last pick (photos skipped because they were too large, an
  /// unsupported type, or because only some fit under the photo limit). Null when everything
  /// was fine. The form can show it after picking.
  static String? lastNotice;

  static String _kb(int bytes) => '${(bytes / 1024).round()} KB';

  /// Works out the real file type from the first bytes (the file name can be wrong or missing).
  /// Returns 'jpg', 'png', 'webp' or null when it is not a supported photo.
  static String? detectExtension(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'png';
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && // RIFF
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) { // WEBP
      return 'webp';
    }
    return null;
  }

  static Future<PickedPhoto> _readPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected photo is empty. Please choose another photo.');
    }
    final ext = detectExtension(bytes);
    if (ext == null) {
      throw StateError('This file type is not supported. Please use a JPG, PNG or WEBP photo.');
    }
    if (bytes.lengthInBytes > maxPhotoBytes) {
      throw StateError(
        'This photo is still ${_kb(bytes.lengthInBytes)} after resizing. Each photo must be ${_kb(maxPhotoBytes)} or smaller. Choose a smaller photo or take a new one.',
      );
    }
    return PickedPhoto(bytes, ext);
  }

  /// Select multiple photos from the gallery.
  ///
  /// Photos that can not be used are skipped and explained in [lastNotice]. If NONE of the
  /// selected photos can be used, a [StateError] with the reason is thrown.
  static Future<List<PickedPhoto>> pickFromGallery({required int remaining}) async {
    lastNotice = null;
    if (remaining <= 0) return const <PickedPhoto>[];
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (files.isEmpty) return const <PickedPhoto>[];

      final photos = <PickedPhoto>[];
      final problems = <String>[];
      for (final file in files.take(remaining)) {
        try {
          photos.add(await _readPhoto(file));
        } on StateError catch (e) {
          problems.add(e.message.toString());
        }
      }

      if (photos.isEmpty && problems.isNotEmpty) {
        throw StateError(problems.first);
      }

      final notes = <String>[];
      if (files.length > remaining) {
        notes.add('Only $remaining photo${remaining == 1 ? '' : 's'} could be added (limit $maxPhotos per phone).');
      }
      if (problems.isNotEmpty) {
        notes.add('${problems.length} photo${problems.length == 1 ? ' was' : 's were'} skipped: ${problems.first}');
      }
      lastNotice = notes.isEmpty ? null : notes.join(' ');
      return photos;
    } on StateError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('PhoneHub gallery selection failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Take a photo with the camera. Returns null if cancelled.
  static Future<PickedPhoto?> pickFromCamera() async {
    lastNotice = null;
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
      debugPrint('PhoneHub camera selection failed: $error\n$stackTrace');
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
      throw StateError('Each product photo must be ${_kb(maxPhotoBytes)} or smaller.');
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