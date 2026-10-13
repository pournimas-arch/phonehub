import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'checkout_ui.dart';
import 'confirm_details_screen.dart';

class SavedAddress {
  final String id, label, line, pincode;
  const SavedAddress({required this.id, required this.label, required this.line, required this.pincode});
}

/// Addresses live here for the whole app session (no database needed).
final ValueNotifier<List<SavedAddress>> savedAddresses = ValueNotifier<List<SavedAddress>>([]);
final ValueNotifier<String> defaultAddressId = ValueNotifier<String>('');

CollectionReference<Map<String, dynamic>>? get _addressCollection {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('addresses');
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
    return SavedAddress(id: doc.id, label: (data['label'] ?? 'Home').toString(), line: (data['line'] ?? '').toString(), pincode: (data['pincode'] ?? '').toString());
  }).toList();
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final savedDefault = (userDoc.data()?['defaultAddressId'] ?? '').toString();
  defaultAddressId.value = savedAddresses.value.any((a) => a.id == savedDefault) ? savedDefault : (savedAddresses.value.isEmpty ? '' : savedAddresses.value.first.id);
}

Future<void> _persistDefaultAddress(String id) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'defaultAddressId': id, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
}

/// Saved Addresses.
/// - Normal mode (from Profile / Cart): list, set default, delete and add.
/// - [selectMode] (from Buy now): "Step 1 of 3 - Select delivery address".
///   Pick an address and tap "Deliver Here" to go to Confirm details.
class SavedAddressesScreen extends StatefulWidget {
  final bool selectMode;
  final String? couponCode;
  const SavedAddressesScreen({super.key, this.selectMode = false, this.couponCode});

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

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _AddAddressSheet(makeDefault: selectMode),
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
      if (mounted) setState(() { _loadingAddresses = false; _loadError = null; });
    }).catchError((Object e) {
      if (mounted) setState(() { _loadingAddresses = false; _loadError = e.toString(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAddresses) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loadError != null) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Could not load saved addresses.'),
        const SizedBox(height: 8), Text(_loadError!, textAlign: TextAlign.center),
        const SizedBox(height: 12), ElevatedButton(onPressed: () {
          setState(() { _loadingAddresses = true; _loadError = null; });
          loadSavedAddresses().then((_) { if (mounted) setState(() => _loadingAddresses = false); }).catchError((Object e) { if (mounted) setState(() { _loadingAddresses = false; _loadError = e.toString(); }); });
        }, child: const Text('Retry'))
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
                title: selectMode ? 'Select delivery address' : 'Saved Addresses',
                step: selectMode ? 'Step 1 of 3' : null,
              ),
              if (selectMode) const CheckoutStepper(current: 0) else const SizedBox(height: 14),
              Expanded(
                child: ValueListenableBuilder<List<SavedAddress>>(
                  valueListenable: savedAddresses,
                  builder: (context, list, _) {
                    return ValueListenableBuilder<String>(
                      valueListenable: defaultAddressId,
                      builder: (context, defId, _) => _body(context, list, defId),
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
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.location_off_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text('No saved addresses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Add an address for faster checkout', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
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
                  Expanded(child: Text('Add a new address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary))),
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
      onTap: () { defaultAddressId.value = a.id; _persistDefaultAddress(a.id).catchError((_) {}); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: glassDeco(radius: 22, borderColor: isDefault ? AppColors.primary : null, borderWidth: isDefault ? 1.6 : 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectMode) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: Icon(isDefault ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isDefault ? AppColors.primary : AppColors.muted, size: 22),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(widget._icon(a.label), color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.text)),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(selectMode ? 'Selected' : 'Default', style: const TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${a.line} - ${a.pincode}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text('Delivery by ${deliveryDateText(3)}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                final next = list.where((e) => e.id != a.id).toList();
                savedAddresses.value = next;
                final collection = _addressCollection;
                if (collection != null) collection.doc(a.id).delete().catchError((_) {});
                if (defaultAddressId.value == a.id) {
                  defaultAddressId.value = next.isEmpty ? '' : next.first.id;
                  _persistDefaultAddress(defaultAddressId.value).catchError((_) {});
                }
              },
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
              ),
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
            final a = list.firstWhere((e) => e.id == defId, orElse: () => list.first);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmDetailsScreen(address: a, couponCode: couponCode)));
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Deliver Here'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded)],
          ),
        )
            : GradientButton(
          onTap: () => widget._openAddSheet(context),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.add_rounded), SizedBox(width: 6), Text('Add New Address')],
          ),
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final bool makeDefault;
  const _AddAddressSheet({this.makeDefault = false});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _line = TextEditingController();
  final _pin = TextEditingController();
  String label = 'Home';

  @override
  void dispose() {
    _line.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final a = SavedAddress(id: 'a${DateTime.now().millisecondsSinceEpoch}', label: label, line: _line.text.trim(), pincode: _pin.text.trim());
    final collection = _addressCollection;
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to save an address.')));
      return;
    }
    collection.add({
      'label': a.label,
      'line': a.line,
      'pincode': a.pincode,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).then((doc) async {
      final saved = SavedAddress(id: doc.id, label: a.label, line: a.line, pincode: a.pincode);
      savedAddresses.value = [...savedAddresses.value, saved];
      if (widget.makeDefault || defaultAddressId.value.isEmpty) {
        defaultAddressId.value = saved.id;
        await _persistDefaultAddress(saved.id);
      }
      if (mounted) Navigator.pop(context);
    }).catchError((Object error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save address: $error')));
    });
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    filled: true,
    fillColor: checkoutFieldFill,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CheckoutSectionTitle('Add New Address'),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final l in const ['Home', 'Work', 'Other']) ...[
                  GestureDetector(
                    onTap: () => setState(() => label = l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: label == l ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: label == l ? AppColors.primary : const Color(0xFFDCE8FF)),
                        boxShadow: label == l ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Text(l, style: TextStyle(color: label == l ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
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
              decoration: _deco('House no, street, area, city'),
              validator: (v) => (v == null || v.trim().length < 8) ? 'Enter your full address' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _deco('Pincode').copyWith(counterText: ''),
              validator: (v) => (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())) ? 'Enter a 6-digit pincode' : null,
            ),
            const SizedBox(height: 16),
            GradientButton(onTap: _save, child: const Text('Save Address')),
          ],
        ),
      ),
    );
  }
}