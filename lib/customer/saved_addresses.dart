import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'theme.dart';
import 'checkout_ui.dart';
import 'data.dart' show isPincodeServiceable;
import 'confirm_details_screen.dart';
import 'package:phonehub/app_text.dart';

class SavedAddress {
  final String id, label, line, pincode;

  const SavedAddress(
      {required this.id,
        required this.label,
        required this.line,
        required this.pincode});
}

// ---------------------------------------------------------------------------
// Address validation (used by the Add / Edit address sheet and the list screen)
// ---------------------------------------------------------------------------
const int kMaxSavedAddresses = 10;
const int _kMinAddressLine = 8;
const int _kMaxAddressLine = 200;

/// Trims and collapses repeated spaces / new lines into single spaces.
String _cleanAddressLine(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Same address = same text (ignoring case / spacing) + same pincode.
String _addressKey(String line, String pin) =>
    '${_cleanAddressLine(line).toLowerCase()}|${pin.trim()}';

String? _validateAddressLine(String? v) {
  final s = _cleanAddressLine(v ?? '');
  if (s.isEmpty) return 'Enter your full address';
  if (s.length < _kMinAddressLine) {
    return 'Address is too short (minimum $_kMinAddressLine characters)';
  }
  if (s.length > _kMaxAddressLine) {
    return 'Address is too long (maximum $_kMaxAddressLine characters)';
  }
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(s)) {
    return 'Address must include the street / area name, not only numbers';
  }
  if (RegExp(r"[^\p{L}\p{M}\p{N}\s,.\-/#()&'+:]", unicode: true).hasMatch(s)) {
    return 'Remove special symbols from the address';
  }
  if (RegExp(r'(.)\1{5,}').hasMatch(s)) return 'Enter a real address';
  return null;
}

String? _validatePincode(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter your pincode';
  if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter a 6-digit pincode';
  if (s.startsWith('0')) return 'Pincode cannot start with 0';
  if (!isPincodeServiceable(s)) return 'Sorry, we do not deliver to $s yet';
  return null;
}

/// Addresses live here for the whole app session (no database needed).
final ValueNotifier<List<SavedAddress>> savedAddresses =
ValueNotifier<List<SavedAddress>>([]);
final ValueNotifier<String> defaultAddressId = ValueNotifier<String>('');

CollectionReference<Map<String, dynamic>>? get _addressCollection {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('addresses');
}

Future<void> loadSavedAddresses() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    savedAddresses.value = [];
    defaultAddressId.value = '';
    return;
  }
  final snapshot = await _addressCollection!.get();
  savedAddresses.value = snapshot.docs.map((doc) {
    final data = doc.data();
    return SavedAddress(
        id: doc.id,
        label: (data['label'] ?? 'Home').toString(),
        line: (data['line'] ?? '').toString(),
        pincode: (data['pincode'] ?? '').toString());
  }).toList();
  final userDoc =
  await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final savedDefault = (userDoc.data()?['defaultAddressId'] ?? '').toString();
  defaultAddressId.value = savedAddresses.value.any((a) => a.id == savedDefault)
      ? savedDefault
      : (savedAddresses.value.isEmpty ? '' : savedAddresses.value.first.id);
}

Future<void> _persistDefaultAddress(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'defaultAddressId': id, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true));
}

/// Saved Addresses.
/// - Normal mode (from Profile / Cart): list, set default, delete and add.
/// - [selectMode] (from Buy now): "Step 1 of 3 - Select delivery address".
///   Pick an address and tap "Deliver Here" to go to Confirm details.
class SavedAddressesScreen extends StatefulWidget {
  final bool selectMode;
  final String? couponCode;

  const SavedAddressesScreen(
      {super.key, this.selectMode = false, this.couponCode});

  IconData _icon(String label) {
    switch (label) {
      case 'Work':
        return Icons.work_outline_rounded;
      case 'Other':
        return Icons.place_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  Future<void> _openAddSheet(BuildContext context) async {
    if (savedAddresses.value.length >= kMaxSavedAddresses) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You can save up to $kMaxSavedAddresses addresses. Delete one to add a new address.')));
      return;
    }
    final location = await Navigator.push<_PickedAddress>(context,
        MaterialPageRoute(builder: (_) => const _AddressLocationScreen()));
    if (!context.mounted || location == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _AddAddressSheet(
          makeDefault: selectMode,
          initialLine: location.address,
          initialPincode: location.pincode),
    );
  }

  void _openEditSheet(BuildContext context, SavedAddress address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _AddAddressSheet(existingAddress: address),
    );
  }

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _loadingAddresses = true;
  String? _loadError;

  bool get selectMode => widget.selectMode;

  String? get couponCode => widget.couponCode;

  @override
  void initState() {
    super.initState();
    loadSavedAddresses().then((_) {
      if (mounted)
        setState(() {
          _loadingAddresses = false;
          _loadError = null;
        });
    }).catchError((Object e) {
      if (mounted)
        setState(() {
          _loadingAddresses = false;
          _loadError = e.toString();
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAddresses)
      return const CheckoutBackground(
          child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: CircularProgressIndicator())));
    if (_loadError != null) {
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Could not load saved addresses.'),
                    const SizedBox(height: 8),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loadingAddresses = true;
                            _loadError = null;
                          });
                          loadSavedAddresses().then((_) {
                            if (mounted)
                              setState(() => _loadingAddresses = false);
                          }).catchError((Object e) {
                            if (mounted)
                              setState(() {
                                _loadingAddresses = false;
                                _loadError = e.toString();
                              });
                          });
                        },
                        child: const Text('Retry'))
                  ]))));
    }
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [

              CheckoutHeader(
                title:
                selectMode ? 'Select delivery address' : 'Saved Addresses',
                step: selectMode ? 'Step 1 of 3' : null,
              ),
              if (selectMode)
                const CheckoutStepper(current: 0)
              else
                const SizedBox(height: 14),
              Expanded(
                child: ValueListenableBuilder<List<SavedAddress>>(
                  valueListenable: savedAddresses,
                  builder: (context, list, _) {
                    return ValueListenableBuilder<String>(
                      valueListenable: defaultAddressId,
                      builder: (context, defId, _) =>
                          _body(context, list, defId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<List<SavedAddress>>(
          valueListenable: savedAddresses,
          builder: (context, list, _) {
            return ValueListenableBuilder<String>(
              valueListenable: defaultAddressId,
              builder: (context, defId, _) => _bottom(context, list, defId),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<SavedAddress> list, String defId) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDCE8FF), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: const Icon(Icons.location_off_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text('No saved addresses',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppText.body,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Add an address for faster checkout',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: AppText.small),
              ),
            ),
            if (selectMode) ...[
              const SizedBox(height: 16),
              // Small add button: opens the "Add new address" screen.
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => widget._openAddSheet(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Add address',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: AppText.small)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectMode
                          ? 'Where should we deliver?'
                          : 'Your delivery addresses',
                      style: const TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      list.isEmpty
                          ? 'Add an address for a smoother checkout'
                          : '${list.length} saved ${list.length == 1 ? 'address' : 'addresses'}',
                      style: const TextStyle(
                          fontSize: AppText.small, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (list.isNotEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCE8FF)),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      size: 17, color: AppColors.primary),
                ),
            ],
          ),
        ),
        if (selectMode) ...[
          GestureDetector(
            onTap: () => widget._openAddSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: glassDeco(radius: 18),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Add a new address',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.body,
                              color: AppColors.primary))),
                  Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (final a in list) ...[
          _card(a, a.id == defId, list),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _card(SavedAddress a, bool isDefault, List<SavedAddress> list) {
    return GestureDetector(
      onTap: () {
        defaultAddressId.value = a.id;
        _persistDefaultAddress(a.id).catchError((_) {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: glassDeco(
            radius: 22,
            borderColor: isDefault ? AppColors.primary : null,
            borderWidth: isDefault ? 1.6 : 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectMode) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: Icon(
                    isDefault
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isDefault ? AppColors.primary : AppColors.muted,
                    size: 22),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(widget._icon(a.label),
                  color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.body,
                              color: AppColors.text)),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(selectMode ? 'Selected' : 'Default',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: AppText.caption,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${a.line} - ${a.pincode}',
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: AppText.small,
                          height: 1.35)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text('Delivery by ${deliveryDateText(3)}',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: AppText.small,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () => widget._openEditSheet(context, a),
                  child: Container(
                    margin: const EdgeInsets.only(left: 4, bottom: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_outlined,
                        color: AppColors.primary, size: 17),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete address?'),
                        content: const Text(
                            'This address will be removed from your saved addresses.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final collection = _addressCollection;
                    if (collection == null) return;
                    try {
                      await collection.doc(a.id).delete();
                      final next = savedAddresses.value
                          .where((e) => e.id != a.id)
                          .toList();
                      savedAddresses.value = next;
                      if (defaultAddressId.value == a.id) {
                        defaultAddressId.value =
                        next.isEmpty ? '' : next.first.id;
                        await _persistDefaultAddress(defaultAddressId.value);
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Could not delete address: $error')));
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger, size: 17),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context, List<SavedAddress> list, String defId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: checkoutBottomBarDeco(),
      child: SafeArea(
        top: false,
        child: selectMode
            ? GradientButton(
          onTap: list.isEmpty
              ? null
              : () {
            final a = list.firstWhere((e) => e.id == defId,
                orElse: () => list.first);
            if (!isPincodeServiceable(a.pincode)) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Sorry, we do not deliver to pincode ${a.pincode} yet. Please choose or edit the address.')));
              return;
            }
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ConfirmDetailsScreen(
                        address: a, couponCode: couponCode)));
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Deliver Here'),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded)
            ],
          ),
        )
            : GradientButton(
          onTap: () => widget._openAddSheet(context),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded),
              SizedBox(width: 6),
              Text('Add New Address')
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final bool makeDefault;
  final SavedAddress? existingAddress;
  final String initialLine;
  final String initialPincode;

  const _AddAddressSheet(
      {this.makeDefault = false,
        this.existingAddress,
        this.initialLine = '',
        this.initialPincode = ''});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _line = TextEditingController();
  final _pin = TextEditingController();
  String label = 'Home';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final address = widget.existingAddress;
    if (address != null) {
      label = address.label;
      _line.text = address.line;
      _pin.text = address.pincode;
    } else {
      _line.text = widget.initialLine;
      _pin.text = widget.initialPincode;
    }
  }

  @override
  void dispose() {
    _line.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;
    final cleanLine = _cleanAddressLine(_line.text);
    final cleanPin = _pin.text.trim();
    final existing = widget.existingAddress;
    // Max addresses (only when adding a new one).
    if (existing == null && savedAddresses.value.length >= kMaxSavedAddresses) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You can save up to $kMaxSavedAddresses addresses. Delete one to add a new address.')));
      return;
    }
    // Duplicate address (same text + pincode already saved).
    final key = _addressKey(cleanLine, cleanPin);
    final duplicate = savedAddresses.value
        .any((a) => a.id != existing?.id && _addressKey(a.line, a.pincode) == key);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This address is already saved.')));
      return;
    }
    // Nothing changed while editing -> no need to write.
    if (existing != null &&
        existing.label == label &&
        _addressKey(existing.line, existing.pincode) == key) {
      Navigator.pop(context);
      return;
    }
    final collection = _addressCollection;
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save an address.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final values = <String, dynamic>{
        'label': label,
        'line': cleanLine,
        'pincode': cleanPin,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      String savedId;
      if (existing != null) {
        await collection.doc(existing.id).update(values);
        savedId = existing.id;
      } else {
        values['createdAt'] = FieldValue.serverTimestamp();
        final doc = await collection.add(values);
        savedId = doc.id;
      }
      final saved = SavedAddress(
          id: savedId,
          label: label,
          line: cleanLine,
          pincode: cleanPin);
      final updated = [
        ...savedAddresses.value.where((item) => item.id != savedId),
        saved
      ];
      savedAddresses.value = updated;
      if (widget.makeDefault || defaultAddressId.value.isEmpty) {
        defaultAddressId.value = saved.id;
        await _persistDefaultAddress(saved.id);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        final code = error is FirebaseException ? error.code : '';
        final message = code == 'permission-denied'
            ? 'This address could not be saved. Please sign in again or contact PhoneHub support.'
            : (code == 'unavailable' || code == 'network-request-failed')
            ? 'No internet connection. Please try again.'
            : 'Could not save address. Please try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    filled: true,
    fillColor: checkoutFieldFill,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckoutSectionTitle(widget.existingAddress == null
                ? 'Add New Address'
                : 'Edit Address'),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final l in const ['Home', 'Work', 'Other']) ...[
                  GestureDetector(
                    onTap: () => setState(() => label = l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: label == l ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: label == l
                                ? AppColors.primary
                                : const Color(0xFFDCE8FF)),
                        boxShadow: label == l
                            ? [
                          BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                            : null,
                      ),
                      child: Text(l,
                          style: TextStyle(
                              color: label == l ? Colors.white : AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: AppText.small)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _line,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [LengthLimitingTextInputFormatter(_kMaxAddressLine)],
              decoration: _deco('House no, street, area, city'),
              validator: _validateAddressLine,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _deco('Pincode').copyWith(counterText: ''),
              validator: _validatePincode,
            ),
            const SizedBox(height: 16),
            GradientButton(
                onTap: _saving ? null : _save,
                child: Text(_saving
                    ? 'Saving...'
                    : (widget.existingAddress == null
                    ? 'Save Address'
                    : 'Update Address'))),
          ],
        ),
      ),
    );
  }
}

class _PickedAddress {
  final String address;
  final String pincode;

  const _PickedAddress(this.address, this.pincode);
}

/// Map-first address selection flow similar to common shopping apps.
/// Requires google_maps_flutter, geolocator and geocoding packages plus a Maps API key.
class _AddressLocationScreen extends StatefulWidget {
  const _AddressLocationScreen();

  @override
  State<_AddressLocationScreen> createState() => _AddressLocationScreenState();
}

class _AddressLocationScreenState extends State<_AddressLocationScreen> {
  // geocoding 5.x exposes these APIs through a Geocoding instance.
  final Geocoding _geocoding = Geocoding();
  static const LatLng _defaultLocation =
  LatLng(18.5204, 73.8567); // Pune fallback
  GoogleMapController? _mapController;
  LatLng _position = _defaultLocation;
  final TextEditingController _search = TextEditingController();
  String _address = 'Pune, Maharashtra, India';
  String _pincode = '';
  bool _loadingLocation = false;
  bool _resolvingAddress = false;
  // Prevent slower geocoding responses from overwriting a newer map selection.
  int _geocodingRequestId = 0;

  @override
  void initState() {
    super.initState();
    _resolveAddress(_position);
  }

  @override
  void dispose() {
    _search.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng point) async {
    if (!mounted) return;
    final requestId = ++_geocodingRequestId;
    setState(() => _resolvingAddress = true);
    try {
      final marks = await _geocoding.placemarkFromCoordinates(
          point.latitude, point.longitude);
      // Map movement can trigger several requests; only the latest selection wins.
      if (!mounted || requestId != _geocodingRequestId) return;
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = <String?>[
          m.name,
          m.street,
          m.subLocality,
          m.locality,
          m.subAdministrativeArea,
          m.administrativeArea,
          m.postalCode,
          m.country
        ]
            .where((v) => v != null && v.trim().isNotEmpty)
            .map((v) => v!.trim())
            .toList();
        final unique = <String>[];
        for (final part in parts) {
          if (!unique.contains(part)) unique.add(part);
        }
        setState(() {
          _address = unique.join(', ');
          _pincode = m.postalCode ?? '';
        });
      }
    } catch (_) {
      if (!mounted || requestId != _geocodingRequestId) return;
      setState(() {
        _address =
        'Selected map location (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
        _pincode = '';
      });
    } finally {
      if (mounted && requestId == _geocodingRequestId) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  Future<void> _moveTo(LatLng point) async {
    if (!mounted) return;
    setState(() => _position = point);
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
    if (!mounted) return;
    await _resolveAddress(point);
  }

  Future<void> _useCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted)
          _message(
              'Please turn on Location in your phone settings, then tap Use my current location again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted)
          _message(
              'Location permission is permanently denied. Allow location for PhoneHub in app settings, then try again.');
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted)
          _message(
              'Allow location permission to use your current location. You can also search or move the map pin.');
        return;
      }

      // Prefer a fresh GPS/network fix; timeout prevents the screen staying busy indefinitely.
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      await _moveTo(LatLng(current.latitude, current.longitude));
    } catch (_) {
      if (mounted)
        _message(
            'Could not get your current location. Check GPS and app location permission, then try again.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _searchLocation() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    try {
      final results = await _geocoding.locationFromAddress(query);
      if (results.isEmpty) {
        _message('Location not found. Try a nearby area or landmark.');
        return;
      }
      await _moveTo(LatLng(results.first.latitude, results.first.longitude));
    } catch (_) {
      _message('Could not find that place. Check the spelling and try again.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  void _confirmLocation() {
    if (_resolvingAddress || _address.trim().isEmpty) {
      _message('Please wait while we identify this location.');
      return;
    }
    Navigator.pop(context, _PickedAddress(_address, _pincode));
  }

  @override
  Widget build(BuildContext context) {
    // Same gradient + soft circles background as the Home screen.
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          elevation: 0,
          title: const Text('Add new address',
              style: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w700)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchLocation(),
              decoration: InputDecoration(
                hintText: 'Search by area, name, street',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _searchLocation),
                filled: true,
                fillColor: const Color(0xFFF4F8FF),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDCE8FF))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDCE8FF))),
              ),
            ),
          ),
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              GoogleMap(
                initialCameraPosition:
                const CameraPosition(target: _defaultLocation, zoom: 13),
                onMapCreated: (controller) => _mapController = controller,
                onCameraMove: (camera) => _position = camera.target,
                onCameraIdle: () => _resolveAddress(_position),
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                markers: const {},
              ),
              const IgnorePointer(
                  child: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(Icons.location_pin,
                          color: Color(0xFF2452B8), size: 48))),
              Positioned(
                top: 18,
                child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Place pin on the exact location',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: AppText.small))),
              ),

              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingLocation ? null : _useCurrentLocation,
                    icon: _loadingLocation
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _loadingLocation
                          ? 'Getting location...'
                          : 'Use my current location',
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: Color(0xFFDCE8FF)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3))
            ]),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Deliver To',
                  style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDCE8FF)),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_pin_circle_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                _resolvingAddress
                                    ? 'Finding address...'
                                    : _address,
                                style: const TextStyle(
                                    fontSize: AppText.small,
                                    height: 1.35,
                                    color: AppColors.text))),
                        TextButton(
                            onPressed: () => _message(
                                'Move the map or search for another location.'),
                            child: const Text('Change')),
                      ])),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resolvingAddress ? null : _confirmLocation,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    child: const Text('Add address details',
                        style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.subtitle)),
                  )),
            ]),
          ),
        ]),
      ),
    );
  }
}