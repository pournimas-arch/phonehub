import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/Admin/phone_extras.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/Admin/phone_image_service.dart';
import 'package:phonehub/Admin/phone_shared_widgets.dart';

// ===========================================================================
// Add / edit phone
// ===========================================================================

/// One photo in the form: an already saved image or a newly picked file, plus its label.
class _FormImage {
  final String? url;
  final PickedPhoto? photo;
  String label; // Front view / Back view / In the box / Other
  _FormImage.saved(this.url, this.label) : photo = null;
  _FormImage.picked(this.photo, this.label) : url = null;
  bool get isSaved => url != null;
}

/// Bottom sheet to add / edit one extra variant (storage + condition + price + stock).
class _VariantSheet extends StatefulWidget {
  final PhoneVariant? initial;
  final Set<String> taken; // 'storage|condition' combinations already used
  const _VariantSheet({this.initial, required this.taken});

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final _form = GlobalKey<FormState>();
  late String storage = widget.initial?.storage ?? storages.first;
  late String condition = widget.initial?.condition ?? conditions.first;
  late final _price = TextEditingController(text: widget.initial?.price.toString() ?? '');
  late final _mrp = TextEditingController(text: widget.initial?.mrp.toString() ?? '');
  late final _stock = TextEditingController(text: widget.initial?.stock.toString() ?? '1');

  @override
  void dispose() {
    _price.dispose();
    _mrp.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (widget.taken.contains('$storage|$condition')) {
      snack(context, 'This storage and condition already exists');
      return;
    }
    final price = int.parse(_price.text.trim());
    final mrp = int.parse(_mrp.text.trim());
    if (mrp < price) {
      snack(context, 'MRP cannot be lower than the selling price');
      return;
    }
    Navigator.pop(context, PhoneVariant(storage: storage, condition: condition, price: price, mrp: mrp, stock: int.parse(_stock.text.trim())));
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Text(t, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.initial == null ? 'Add variant' : 'Edit variant', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _label('STORAGE'),
                phoneChoiceChips(storages, storage, (v) => setState(() => storage = v)),
                const SizedBox(height: 8),
                _label('CONDITION'),
                phoneChoiceChips(conditions, condition, (v) => setState(() => condition = v)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: phoneFormField('Selling price', _price, type: TextInputType.number, prefix: '₹ ', digitsOnly: true, maxLength: 6, validator: (v) => validatePrice(v, label: 'selling price'))),
                    const SizedBox(width: 12),
                    Expanded(child: phoneFormField('MRP', _mrp, type: TextInputType.number, prefix: '₹ ', digitsOnly: true, maxLength: 6, validator: (v) => validateMrp(v, _price.text))),
                  ],
                ),
                phoneFormField('Stock (units)', _stock, type: TextInputType.number, digitsOnly: true, maxLength: 4, validator: validateStock),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: Text(widget.initial == null ? 'Add variant' : 'Save variant'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / edit phone. Pass [phone] to edit.
class PhoneFormScreen extends StatefulWidget {
  final Phone? phone;
  const PhoneFormScreen({super.key, this.phone});

  @override
  State<PhoneFormScreen> createState() => _PhoneFormScreenState();
}

class _PhoneFormScreenState extends State<PhoneFormScreen> {
  static const _batteryQuick = [100, 95, 90, 85, 80];

  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();

  /// Details of the phone being edited, or sensible defaults for a new phone.
  late final PhoneDetails _d0 = widget.phone?.details ??
      PhoneDetails(
        qualityChecks: List<String>.from(kQualityCheckPresets.take(8)),
        inBox: List<String>.from(kInBoxPresets.take(5)),
      );

  late final _name = TextEditingController(text: widget.phone?.name ?? '');
  late final _price = TextEditingController(text: widget.phone?.price.toString() ?? '');
  late final _mrp = TextEditingController(text: widget.phone?.mrp.toString() ?? '');
  late final _battery = TextEditingController(text: widget.phone?.battery.toString() ?? '');
  late final _stock = TextEditingController(text: widget.phone?.stock.toString() ?? '1');

  // Specifications (shown on the customer's Specifications table)
  late final _display = TextEditingController(text: _d0.display);
  late final _chip = TextEditingController(text: _d0.processor);
  late final _ram = TextEditingController(text: _d0.ram);
  late final _rear = TextEditingController(text: _d0.rearCamera);
  late final _front = TextEditingController(text: _d0.frontCamera);
  late final _mah = TextEditingController(text: _d0.batteryMah);
  late final _os = TextEditingController(text: _d0.os);

  // Warranty / delivery
  late final _warranty = TextEditingController(text: '${_d0.warrantyMonths}');
  late final _return = TextEditingController(text: '${_d0.returnDays}');
  late final _delivery = TextEditingController(text: '${_d0.deliveryDays}');
  late bool _cod = _d0.cod;
  late bool _emi = _d0.noCostEmi;

  late List<String> _checks = List<String>.from(_d0.qualityChecks);
  late List<String> _inBox = List<String>.from(_d0.inBox);
  late final List<PhoneVariant> _variants = _d0.variants.map((v) => v.copy()).toList();

  late String brand = widget.phone?.brand ?? (store.brands.isNotEmpty ? store.brands.first.name : '');
  late String storage = widget.phone?.storage ?? '128 GB';
  late String condition = widget.phone?.condition ?? 'Good';
  late Color c1 = widget.phone != null && widget.phone!.colors.isNotEmpty ? widget.phone!.colors.first : swatches[0];
  late Color c2 = (widget.phone != null && widget.phone!.colors.length > 1) ? widget.phone!.colors[1] : swatches[10];
  late bool _active = widget.phone?.active ?? true;
  late final List<_FormImage> _images = () {
    final src = widget.phone?.images ?? const <String>[];
    final labels = _d0.imageLabels;
    return <_FormImage>[
      for (int i = 0; i < src.length; i++) _FormImage.saved(src[i], (i < labels.length && labels[i].isNotEmpty) ? labels[i] : defaultPhotoLabel(i)),
    ];
  }();
  bool _photoBusy = false;
  bool _saving = false;
  bool _dirty = false;

  bool get editing => widget.phone != null;

  List<TextEditingController> get _allControllers => [_name, _price, _mrp, _battery, _stock, _display, _chip, _ram, _rear, _front, _mah, _os, _warranty, _return, _delivery];

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Keeps the preset order first, then custom items.
  List<String> _ordered(List<String> presets, List<String> selected) => [
    ...presets.where(selected.contains),
    ...selected.where((s) => !presets.contains(s)),
  ];

  /// Clears the form so another phone can be added.
  void _clearForm({bool resetOptions = false}) {
    for (final c in [_name, _price, _mrp, _battery, _display, _chip, _ram, _rear, _front, _mah, _os]) {
      c.clear();
    }
    _stock.text = '1';
    _images.clear();
    _variants.clear();
    if (resetOptions) {
      brand = store.brands.isNotEmpty ? store.brands.first.name : '';
      storage = '128 GB';
      condition = 'Good';
      c1 = swatches[0];
      c2 = swatches[10];
      _active = true;
      _checks = List<String>.from(kQualityCheckPresets.take(8));
      _inBox = List<String>.from(kInBoxPresets.take(5));
      _warranty.text = '6';
      _return.text = '7';
      _delivery.text = '3';
      _cod = true;
      _emi = true;
    }
    _dirty = false;
    _form.currentState?.reset();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    setState(() {});
  }

  PhoneDetails _buildDetails() => PhoneDetails(
    display: cleanText(_display.text),
    processor: cleanText(_chip.text),
    ram: cleanText(_ram.text),
    rearCamera: cleanText(_rear.text),
    frontCamera: cleanText(_front.text),
    batteryMah: cleanText(_mah.text),
    os: cleanText(_os.text),
    qualityChecks: _ordered(kQualityCheckPresets, _checks),
    inBox: _ordered(kInBoxPresets, _inBox),
    imageLabels: [for (final im in _images) im.label],
    variants: _variants.map((v) => v.copy()).toList(),
    warrantyMonths: int.tryParse(_warranty.text.trim()) ?? 0,
    returnDays: int.tryParse(_return.text.trim()) ?? 0,
    deliveryDays: int.tryParse(_delivery.text.trim()) ?? 3,
    cod: _cod,
    noCostEmi: _emi,
  );

  /// Size of all photos as they will be stored inside the product document.
  int get _photosBytes => _images.fold<int>(0, (sum, im) => sum + (im.isSaved ? storedImageBytes(im.url!) : im.photo!.storedBytes));

  Future<void> _save({bool another = false}) async {
    if (_saving || _photoBusy) return;
    if (!_form.currentState!.validate()) {
      snack(context, 'Please fix the highlighted fields');
      return;
    }
    if (brand.isEmpty) {
      snack(context, 'Add a brand first (More > Brands), then add the phone');
      return;
    }
    if (!store.brands.any((b) => b.name == brand)) {
      snack(context, 'The brand "$brand" no longer exists. Choose another brand (or add it in More > Brands).');
      return;
    }
    final price = int.tryParse(_price.text.trim());
    final mrp = int.tryParse(_mrp.text.trim());
    if (price == null || mrp == null) {
      snack(context, 'Please enter the selling price and MRP');
      return;
    }
    if (mrp < price) {
      snack(context, 'MRP cannot be lower than the selling price');
      return;
    }
    if (_variants.any((v) => v.storage == storage && v.condition == condition)) {
      snack(context, 'An extra variant already uses $storage • $condition. Change it or remove that variant.');
      return;
    }
    if (_variants.length > kMaxVariants) {
      snack(context, 'You can add up to $kMaxVariants extra variants');
      return;
    }

    // photos are saved inside the product, so all of them together must stay small
    final photoError = validatePhotoTotal(_photosBytes);
    if (photoError != null) {
      snack(context, photoError);
      return;
    }

    final nameTxt = cleanText(_name.text);
    final id = editing ? widget.phone!.id : store.nextPhoneId();

    // warn if the same phone already exists
    final dup = store.phones.any((x) => x.id != id && x.name.trim().toLowerCase() == nameTxt.toLowerCase() && x.storage == storage && x.condition == condition);
    if (dup) {
      final ok = await confirmDialog(context, 'Similar phone exists', 'A phone with the same name, storage and condition is already in your catalogue. Save anyway?', yes: 'Save anyway');
      if (!ok || !mounted) return;
    }

    // same colour twice gives a flat colour, ask once
    if (c1 == c2) {
      final ok = await confirmDialog(context, 'Same colour twice', 'The main colour and the second colour are the same, so the phone card will look flat. Save anyway?', yes: 'Save anyway');
      if (!ok || !mounted) return;
    }

    // the same photo label on more than one photo (except "Other") is probably a mistake
    final seenLabels = <String>{};
    String? repeatedLabel;
    for (final im in _images) {
      if (im.label != 'Other' && !seenLabels.add(im.label)) {
        repeatedLabel = im.label;
        break;
      }
    }
    if (repeatedLabel != null) {
      final ok = await confirmDialog(context, 'Repeated photo label', 'More than one photo is labelled "$repeatedLabel". Tap the dark bar on a photo to change its label. Save anyway?', yes: 'Save anyway');
      if (!ok || !mounted) return;
    }

    final battery = int.tryParse(_battery.text.trim());
    final stockN = int.tryParse(_stock.text.trim());
    if (battery == null || stockN == null) {
      snack(context, 'Please enter the battery health and the stock');
      return;
    }
    setState(() => _saving = true);

    try {
      final allImages = <String>[for (final im in _images) im.isSaved ? im.url! : im.photo!.toDataUri()];
      final details = _buildDetails();
      String? error;
      if (editing) {
        final p = widget.phone!;
        // keep the old values so they can be put back if saving fails
        final oldName = p.name, oldBrand = p.brand, oldStorage = p.storage, oldCondition = p.condition;
        final oldPrice = p.price, oldMrp = p.mrp, oldBattery = p.battery, oldStock = p.stock;
        final oldColors = p.colors, oldImages = p.images, oldDetails = p.details, oldActive = p.active;
        p
          ..name = nameTxt
          ..brand = brand
          ..storage = storage
          ..condition = condition
          ..price = price
          ..mrp = mrp
          ..battery = battery
          ..stock = stockN
          ..colors = [c1, c2]
          ..images = allImages
          ..details = details
          ..active = _active;
        error = await store.saveEditedPhone(p);
        if (error != null) {
          p
            ..name = oldName
            ..brand = oldBrand
            ..storage = oldStorage
            ..condition = oldCondition
            ..price = oldPrice
            ..mrp = oldMrp
            ..battery = oldBattery
            ..stock = oldStock
            ..colors = oldColors
            ..images = oldImages
            ..details = oldDetails
            ..active = oldActive;
          store.changed();
        } else if (mounted) {
          snack(context, '${p.name} updated');
        }
      } else {
        final np = Phone(
          id: id,
          name: nameTxt,
          brand: brand,
          storage: storage,
          condition: condition,
          price: price,
          mrp: mrp,
          battery: battery,
          rating: 0.0, // ratings come from customer reviews, not from the admin
          colors: [c1, c2],
          stock: stockN,
          images: allImages,
          details: details,
        );
        np.active = _active;
        error = await store.addPhone(np, reportToStore: false);
        if (error == null && mounted) snack(context, '$nameTxt added');
      }
      if (error != null) {
        // saving failed: stay on this screen with everything still filled in
        if (mounted) snack(context, error);
        return;
      }
      _dirty = false;
      if (!mounted) return;
      if (another && !editing) {
        _clearForm();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) snack(context, 'Could not save product. Please check the form and try again.');
      debugPrint('PhoneHub product save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhotos() async {
    if (_photoBusy || _saving) return;
    final remaining = PhoneImageService.maxPhotos - _images.length;
    if (remaining <= 0) {
      snack(context, 'You can add up to ${PhoneImageService.maxPhotos} photos per phone');
      return;
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Add product photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: AC.primary), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheetContext, 'gallery')),
            ListTile(leading: const Icon(Icons.photo_camera_outlined, color: AC.primary), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheetContext, 'camera')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final picked = <PickedPhoto>[];
      String? notice;
      if (source == 'gallery') {
        picked.addAll(await PhoneImageService.pickFromGallery(remaining: remaining));
        notice = PhoneImageService.lastNotice;
      } else {
        final one = await PhoneImageService.pickFromCamera();
        if (one != null) picked.add(one);
      }
      if (!mounted) return;

      // skip a photo that is already added, and any photo that would push the total size over the limit
      var total = _photosBytes;
      var duplicates = 0;
      var tooBig = 0;
      final added = <PickedPhoto>[];
      for (final ph in picked) {
        final same = _images.any((im) => !im.isSaved && listEquals(im.photo!.bytes, ph.bytes)) || added.any((x) => listEquals(x.bytes, ph.bytes));
        if (same) {
          duplicates++;
          continue;
        }
        if (total + ph.storedBytes > kMaxPhotoTotalBytes) {
          tooBig++;
          continue;
        }
        total += ph.storedBytes;
        added.add(ph);
      }
      if (added.isNotEmpty) {
        _markDirty();
        setState(() {
          for (final ph in added) {
            _images.add(_FormImage.picked(ph, defaultPhotoLabel(_images.length)));
          }
        });
      }
      final notes = <String>[
        if (notice != null) notice,
        if (duplicates > 0) '$duplicates photo${duplicates == 1 ? ' was' : 's were'} already added.',
        if (tooBig > 0) '$tooBig photo${tooBig == 1 ? ' was' : 's were'} not added: all photos together can be only ${formatKb(kMaxPhotoTotalBytes)}.',
      ];
      if (notes.isNotEmpty && mounted) snack(context, notes.join(' '));
    } on StateError catch (e) {
      // our own readable messages (empty photo, wrong type, photo too large)
      if (mounted) snack(context, e.message.toString());
    } catch (e) {
      if (mounted) snack(context, 'Could not select photo. Check camera/gallery permission and try again.');
      debugPrint('PhoneHub photo selection failed: $e');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _removeImage(_FormImage im) {
    _markDirty();
    setState(() => _images.remove(im));
  }

  void _makeCover(_FormImage im) {
    if (_images.isEmpty || identical(_images.first, im)) return;
    _markDirty();
    setState(() {
      _images.remove(im);
      _images.insert(0, im);
    });
    snack(context, 'Cover photo changed');
  }

  /// Tap the label bar on a photo to switch Front view -> Back view -> In the box -> Other.
  void _cycleLabel(_FormImage im) {
    _markDirty();
    final i = kPhotoLabels.indexOf(im.label);
    setState(() => im.label = kPhotoLabels[(i + 1) % kPhotoLabels.length]);
  }

  void _bumpStock(int d) {
    final n = (int.tryParse(_stock.text.trim()) ?? 0) + d;
    _stock.text = '${n < 0 ? 0 : (n > kMaxStock ? kMaxStock : n)}';
  }

  Future<void> _openVariant({int? index}) async {
    if (index == null && _variants.length >= kMaxVariants) {
      snack(context, 'You can add up to $kMaxVariants extra variants');
      return;
    }
    final taken = <String>{
      '$storage|$condition',
      for (int i = 0; i < _variants.length; i++)
        if (i != index) '${_variants[i].storage}|${_variants[i].condition}',
    };
    final result = await showModalBottomSheet<PhoneVariant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VariantSheet(initial: index == null ? null : _variants[index], taken: taken),
    );
    if (result == null || !mounted) return;
    _markDirty();
    setState(() {
      if (index == null) {
        _variants.add(result);
      } else {
        _variants[index] = result;
      }
    });
  }

  // ------------------------------------------------------------------ UI helpers

  Widget _imgWidget(_FormImage im) => im.isSaved
      ? PhoneProductImage(source: im.url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AC.primary.withValues(alpha: 0.08), child: const Icon(Icons.broken_image_outlined, color: AC.muted)))
      : Image.memory(im.photo!.bytes, fit: BoxFit.cover);

  /// Card with an icon + title header.
  Widget _section(IconData icon, String title, Widget child, {String? hint}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AC.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1)))),
            if (hint != null) Text(hint, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  );

  Widget _note(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), height: 1.35)),
  );

  Widget _choices(List<String> items, String value, ValueChanged<String> onPick) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final x in items)
        ChoiceChip(
          label: Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: x == value ? Colors.white : AC.text)),
          selected: x == value,
          showCheckmark: false,
          selectedColor: AC.primary,
          backgroundColor: AC.bg,
          side: BorderSide(color: x == value ? AC.primary : AC.border),
          onSelected: (_) {
            _markDirty();
            setState(() => onPick(x));
          },
        ),
    ],
  );

  /// Tick-able chips (several can be on) plus "+ Add" for a custom item.
  Widget _multiChips(List<String> presets, List<String> selected, {required String addTitle, required String addLabel, required int maxItems}) {
    final all = [...presets, ...selected.where((s) => !presets.contains(s))];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final x in all)
          FilterChip(
            label: Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: selected.contains(x) ? Colors.white : AC.text)),
            selected: selected.contains(x),
            showCheckmark: true,
            checkmarkColor: Colors.white,
            selectedColor: AC.primary,
            backgroundColor: AC.bg,
            side: BorderSide(color: selected.contains(x) ? AC.primary : AC.border),
            onSelected: (on) {
              _markDirty();
              setState(() => on ? selected.add(x) : selected.remove(x));
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 16, color: AC.primary),
          label: const Text('Add', style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w800, color: AC.primary)),
          backgroundColor: AC.primary.withValues(alpha: 0.06),
          side: BorderSide(color: AC.primary.withValues(alpha: 0.35)),
          onPressed: () async {
            if (selected.length >= maxItems) {
              snack(context, 'You can add up to $maxItems items here');
              return;
            }
            final t = await askTextDialog(context, addTitle, addLabel, existing: selected);
            if (t == null || !mounted) return;
            // typing the name of a ready-made chip just ticks that chip
            final preset = presets.where((x) => x.toLowerCase() == t.toLowerCase()).toList();
            _markDirty();
            setState(() => selected.add(preset.isEmpty ? t : preset.first));
          },
        ),
      ],
    );
  }

  Widget _switchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: (AppText.small - 1), color: AC.muted)),
          ],
        ),
      ),
      Switch(
        value: value,
        activeColor: AC.success,
        onChanged: (v) {
          _markDirty();
          setState(() => onChanged(v));
        },
      ),
    ],
  );

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AC.primary)),
  );

  Widget _swatchPicker(String title, Color current, ValueChanged<Color> onPick) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(title),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in swatches)
            GestureDetector(
              onTap: () {
                _markDirty();
                setState(() => onPick(s));
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: s == current ? AC.accent : Colors.transparent, width: 3)),
                child: s == current ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
              ),
            ),
        ],
      ),
    ],
  );

  /// Live preview of how the phone will look in the list.
  Widget _preview() => ListenableBuilder(
    listenable: Listenable.merge([_name, _price, _mrp]),
    builder: (_, __) {
      final price = int.tryParse(_price.text.trim());
      final mrp = int.tryParse(_mrp.text.trim());
      final off = (price != null && mrp != null && mrp > price) ? (((mrp - price) / mrp) * 100).round() : 0;
      final nameTxt = _name.text.trim();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
              child: _images.isNotEmpty ? _imgWidget(_images.first) : Icon(Icons.smartphone_rounded, size: 40, color: Colors.white.withValues(alpha: 0.95)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PREVIEW', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(nameTxt.isEmpty ? 'Phone name' : nameTxt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: AppText.body, fontWeight: FontWeight.w900)),
                  Text('${brand.isEmpty ? 'Brand' : brand} • $storage • $condition', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(price == null ? '₹ --' : inr(price), style: const TextStyle(color: Colors.white, fontSize: AppText.subtitle, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      if (mrp != null && off > 0) Text(inr(mrp), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 6),
                      if (off > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text('$off% OFF', style: const TextStyle(color: AC.success, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _photoTile(_FormImage im) {
    final isCover = identical(_images.first, im);
    return Container(
      width: 92,
      height: 104,
      margin: const EdgeInsets.only(left: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isCover ? AC.primary : AC.border, width: isCover ? 2 : 1)),
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(onTap: () => _makeCover(im), child: _imgWidget(im)),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.58),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: () => _removeImage(im), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, color: Colors.white, size: 16))),
          ),
        ),
        if (isCover) const Positioned(left: 4, top: 4, child: _CoverTag()),
        // label bar: tap to change what this photo shows (Front / Back / In the box / Other)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _cycleLabel(im),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              color: Colors.black.withValues(alpha: 0.62),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(im.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 3),
                  const Icon(Icons.swap_vert_rounded, size: 11, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _photosSection() => _section(
    Icons.photo_library_rounded,
    'Photos',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              InkWell(
                onTap: _photoBusy || _saving ? null : _addPhotos,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 92,
                  decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.primary.withValues(alpha: 0.35))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_photoBusy ? Icons.hourglass_top_rounded : Icons.add_a_photo_rounded, color: AC.primary),
                    const SizedBox(height: 6),
                    Text(_photoBusy ? 'Please wait' : 'Add photo', style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700)),
                    Text('${_images.length}/${PhoneImageService.maxPhotos}', style: const TextStyle(fontSize: 10, color: AC.muted)),
                  ]),
                ),
              ),
              for (final im in List<_FormImage>.from(_images)) _photoTile(im),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Photo size: ${formatKb(_photosBytes)} of ${formatKb(kMaxPhotoTotalBytes)}',
          style: TextStyle(color: _photosBytes > kMaxPhotoTotalBytes ? AC.danger : AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a photo to make it the cover. Tap the dark bar on a photo to set its label (Front view, Back view, In the box). Customers see these labels in the gallery.',
          style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), height: 1.35),
        ),
      ],
    ),
    hint: 'Optional',
  );

  Widget _brandSection() {
    if (store.brands.isEmpty && brand.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AC.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.accent.withValues(alpha: 0.4))),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AC.accent),
            SizedBox(width: 10),
            Expanded(child: Text('No brands yet. Go to More > Brands, add a brand (for example Apple or Samsung), then come back to add the phone.', style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w600, height: 1.35))),
          ],
        ),
      );
    }
    return _section(
      Icons.apartment_rounded,
      'Basic details',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          phoneFormField('Phone name', _name, maxLength: kMaxPhoneNameLength, validator: validatePhoneName),
          _label('BRAND'),
          _choices([
            ...store.brands.map((b) => b.name),
            if (brand.isNotEmpty && !store.brands.any((b) => b.name == brand)) brand,
          ], brand, (v) => brand = v),
        ],
      ),
    );
  }

  Widget _priceHint() => ListenableBuilder(
    listenable: Listenable.merge([_price, _mrp]),
    builder: (_, __) {
      final price = int.tryParse(_price.text.trim());
      final mrp = int.tryParse(_mrp.text.trim());
      if (price == null || mrp == null || mrp <= 0) return const SizedBox.shrink();
      if (mrp < price) {
        return phonePill('MRP is lower than selling price', AC.danger, icon: Icons.error_outline_rounded);
      }
      final off = (((mrp - price) / mrp) * 100).round();
      return phonePill('Customers see $off% OFF • save ${inr(mrp - price)}', AC.success, icon: Icons.local_offer_rounded);
    },
  );

  Widget _batterySection() => ListenableBuilder(
    listenable: _battery,
    builder: (_, __) {
      final v = (int.tryParse(_battery.text.trim()) ?? 100).clamp(1, 100);
      final Color bc = v >= 85 ? AC.success : (v >= 70 ? AC.warning : AC.danger);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          phoneFormField('Battery health %', _battery, type: TextInputType.number, digitsOnly: true, maxLength: 3, validator: (x) => validateNumber(x, min: 1, max: 100)),
          Row(
            children: [
              Icon(Icons.battery_charging_full_rounded, size: 18, color: bc),
              Expanded(
                child: Slider(
                  value: v.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '$v%',
                  activeColor: bc,
                  onChanged: (x) => _battery.text = '${x.round()}',
                ),
              ),
              Text('$v%', style: TextStyle(fontWeight: FontWeight.w900, color: bc)),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final q in _batteryQuick)
                ActionChip(
                  label: Text('$q%', style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700)),
                  backgroundColor: AC.bg,
                  side: BorderSide(color: AC.border),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _battery.text = '$q',
                ),
            ],
          ),
        ],
      );
    },
  );

  Widget _variantTile(int i) {
    final v = _variants[i];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openVariant(index: i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${v.storage} • ${v.condition}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small)),
                  const SizedBox(height: 2),
                  Text('${inr(v.price)}  (MRP ${inr(v.mrp)})  •  ${v.stock} in stock', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AC.danger, size: 20),
              tooltip: 'Remove variant',
              onPressed: () {
                _markDirty();
                setState(() => _variants.removeAt(i));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantsSection() => _section(
    Icons.layers_rounded,
    'Other variants',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note('The storage, condition and price above are the default variant ($storage • $condition). Add other combinations here, each with its own price and stock. Customers can then pick them on the product page.'),
        for (int i = 0; i < _variants.length; i++) _variantTile(i),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openVariant(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add variant'),
          ),
        ),
      ],
    ),
    hint: 'Optional',
  );

  Widget _techSpecsSection() => _section(
    Icons.memory_rounded,
    'Specifications',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note('Shown in the Specifications table on the customer product page. Leave a field blank to hide that row.'),
        phoneFormField('Display (e.g. 6.1" OLED, 120 Hz)', _display, maxLength: kMaxSpecLength, validator: (v) => validateSpec(v, needDigit: true)),
        phoneFormField('Processor (e.g. Snapdragon 888)', _chip, maxLength: kMaxSpecLength, validator: validateSpec),
        phoneFormField('RAM (e.g. 8 GB)', _ram, maxLength: kMaxSpecLength, validator: (v) => validateSpec(v, needDigit: true)),
        phoneFormField('Rear camera (e.g. 50 MP + 8 MP)', _rear, maxLength: kMaxSpecLength, validator: (v) => validateSpec(v, needDigit: true)),
        phoneFormField('Front camera (e.g. 16 MP)', _front, maxLength: kMaxSpecLength, validator: (v) => validateSpec(v, needDigit: true)),
        phoneFormField('Battery capacity (e.g. 5000 mAh)', _mah, maxLength: kMaxSpecLength, validator: (v) => validateSpec(v, needDigit: true)),
        phoneFormField('Operating system (e.g. Android 13)', _os, maxLength: kMaxSpecLength, validator: validateSpec),
      ],
    ),
    hint: 'Optional',
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirmDialog(context, 'Discard changes?', 'You have unsaved changes. If you go back they will be lost.', yes: 'Discard', danger: true);
        if (ok && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          editing ? 'Edit phone' : 'Add phone',
          actions: [
            if (!editing)
              TextButton(
                onPressed: _dirty
                    ? () async {
                  final ok = await confirmDialog(context, 'Reset form?', 'All entered details will be cleared.', yes: 'Reset', danger: true);
                  if (ok) _clearForm(resetOptions: true);
                }
                    : null,
                child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            const SizedBox(width: 6),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))]),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (!editing) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving || _photoBusy ? null : () => _save(another: true),
                      child: const Text('Save & add another', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving || _photoBusy ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(editing ? 'Save changes' : 'Add phone'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _preview(),
              _photosSection(),
              _brandSection(),
              _section(
                Icons.sd_storage_rounded,
                'Storage, condition & battery',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('STORAGE'),
                    _choices(storages, storage, (v) => storage = v),
                    const SizedBox(height: 14),
                    _label('CONDITION'),
                    _choices(conditions, condition, (v) => condition = v),
                    const SizedBox(height: 14),
                    _batterySection(),
                  ],
                ),
              ),
              _section(
                Icons.sell_rounded,
                'Pricing',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: phoneFormField('Selling price', _price, type: TextInputType.number, prefix: '₹ ', digitsOnly: true, maxLength: 6, validator: (v) => validatePrice(v, label: 'selling price'))),
                        const SizedBox(width: 12),
                        Expanded(child: phoneFormField('MRP', _mrp, type: TextInputType.number, prefix: '₹ ', digitsOnly: true, maxLength: 6, validator: (v) => validateMrp(v, _price.text))),
                      ],
                    ),
                    _priceHint(),
                  ],
                ),
              ),
              _section(
                Icons.inventory_2_rounded,
                'Stock',
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 4), child: _roundBtn(Icons.remove_rounded, () => _bumpStock(-1))),
                    const SizedBox(width: 10),
                    Expanded(child: phoneFormField('Stock (units)', _stock, type: TextInputType.number, digitsOnly: true, maxLength: 4, validator: validateStock)),
                    const SizedBox(width: 10),
                    Padding(padding: const EdgeInsets.only(top: 4), child: _roundBtn(Icons.add_rounded, () => _bumpStock(1))),
                  ],
                ),
              ),
              _variantsSection(),
              _techSpecsSection(),
              _section(
                Icons.fact_check_rounded,
                'Quality check',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _note('Tick the checks this phone passed. Customers see "${_checks.length}-point quality check" with these items.'),
                    _multiChips(kQualityCheckPresets, _checks, addTitle: 'Add quality check', addLabel: 'Check name', maxItems: kMaxQualityChecks),
                  ],
                ),
                hint: '${_checks.length} selected',
              ),
              _section(
                Icons.inventory_rounded,
                "What's in the box",
                _multiChips(kInBoxPresets, _inBox, addTitle: 'Add box item', addLabel: 'Item name', maxItems: kMaxBoxItems),
                hint: '${_inBox.length} selected',
              ),
              _section(
                Icons.verified_user_rounded,
                'Warranty, return & delivery',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: phoneFormField('Warranty (months)', _warranty, type: TextInputType.number, digitsOnly: true, maxLength: 2, validator: (v) => validateNumber(v, min: 0, max: 60))),
                        const SizedBox(width: 12),
                        Expanded(child: phoneFormField('Return (days)', _return, type: TextInputType.number, digitsOnly: true, maxLength: 2, validator: (v) => validateNumber(v, min: 0, max: 30))),
                      ],
                    ),
                    phoneFormField('Delivery time (days)', _delivery, type: TextInputType.number, digitsOnly: true, maxLength: 2, validator: (v) => validateNumber(v, min: 1, max: 15)),
                    const SizedBox(height: 4),
                    _switchRow('Cash on delivery', _cod ? 'Customers can pay when it arrives' : 'Online payment only', _cod, (v) => _cod = v),
                    _switchRow('No-cost EMI', _emi ? 'EMI offer is shown to customers' : 'EMI offer is hidden', _emi, (v) => _emi = v),
                  ],
                ),
              ),
              _section(
                Icons.palette_rounded,
                'Colours',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _swatchPicker('MAIN COLOUR', c1, (c) => c1 = c),
                    const SizedBox(height: 14),
                    _swatchPicker('SECOND COLOUR', c2, (c) => c2 = c),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        _markDirty();
                        setState(() {
                          final t = c1;
                          c1 = c2;
                          c2 = t;
                        });
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Swap colours'),
                    ),
                  ],
                ),
              ),
              _section(
                Icons.visibility_rounded,
                'Visibility',
                _switchRow('Visible to customers', _active ? 'Customers can see and buy this phone' : 'Hidden in the customer app', _active, (v) => _active = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverTag extends StatelessWidget {
  const _CoverTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(5)),
    child: const Text('COVER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
  );
}