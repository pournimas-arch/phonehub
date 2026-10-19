import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'widgets.dart';
import 'theme.dart';
import 'my_cart.dart';
import 'data.dart';
import 'phone_mockup.dart';
import 'saved_addresses.dart';
import 'checkout_ui.dart';
import 'package:phonehub/app_text.dart';

// ---------- Shared styling (same as Saved Addresses screen) ----------

const _line = Color(0xFFDCE8FF);
const _star = Color(0xFFF59E0B);
const _subText = Color(0xFF55657F); // darker than AppColors.muted for better contrast on cards

// ---------- Review text validation (logic only, no UI) ----------

const int _kReviewMin = 5; // the text is optional, but if written it must be meaningful
const int _kReviewMax = 500;

String _cleanReviewText(String v) => v
    .trim()
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n');

/// Returns an error message, or null when the review text is fine (empty is allowed).
String? _validateReviewText(String raw) {
  final s = _cleanReviewText(raw);
  if (s.isEmpty) return null;
  if (s.length < _kReviewMin) return 'Write at least $_kReviewMin characters, or leave it empty';
  if (s.length > _kReviewMax) return 'A review can be at most $_kReviewMax characters';

  final letters = RegExp(r'\p{L}', unicode: true).allMatches(s).length;
  if (letters == 0) return 'Your review must contain words';
  if (RegExp(r'(.)\1{5,}').hasMatch(s)) return 'Please write a real review';
  final visible = s.replaceAll(RegExp(r'\s'), '').length;
  if (visible > 0 && letters / visible < 0.5) {
    return 'Your review has too many symbols or numbers';
  }
  // Reviews are public: no links or phone numbers (spam / privacy).
  if (RegExp(r'(https?:|www\.|\.com\b)', caseSensitive: false).hasMatch(s)) {
    return 'Please remove links from your review';
  }
  if (RegExp(r'(\+?\d[\s-]?){10,}').hasMatch(s)) {
    return 'Please remove phone numbers from your review';
  }
  return null;
}

/// Section title with the blue accent bar (same as Home).
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionTitle(this.title, {this.action});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.subtitle, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (action != null) Text(action!, style: const TextStyle(color: AppColors.primary, fontSize: AppText.small, fontWeight: FontWeight.w700)),
    ],
  );
}

/// One customer review (built from a real Firestore review, see ProductReview in data.dart).
class _Rev {
  final String name;
  final int stars;
  final String date;
  final String text;
  final bool verified;
  const _Rev(this.name, this.stars, this.date, this.text, {this.verified = false});
}

/// Screen 4 – Product Detail
/// Image gallery (tap to zoom), price with MRP strike-through and % off, offers, EMI plans,
/// storage / condition chips, battery health, quality check, delivery check (pincode prefilled
/// from your default address), specifications, what's in the box, ratings & reviews,
/// similar phones, Verified Device, 6-month seller warranty, 7-day return, Add to Cart / Buy Now.
class ProductDetailScreen extends StatefulWidget {
  final Phone phone;
  const ProductDetailScreen({super.key, required this.phone});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _conditionInfo = {
    'Like New': 'No visible scratches. Looks and works like a new phone.',
    'Good': 'Light signs of use. Fully working with minor marks on the body.',
    'Fair': 'Visible scratches or dents. Fully working and priced lower.',
  };

  // Real customer reviews of this phone (Firestore `reviews`), kept live.
  StreamSubscription<List<ProductReview>>? _revSub;
  List<ProductReview> _revs = const <ProductReview>[];

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  List<_Rev> get _reviews => [
    for (final r in _revs) _Rev(r.userName, r.stars, '${_mon[r.date.month - 1]} ${r.date.year}', r.text, verified: r.verified),
  ];
  double get _avg => _revs.isEmpty ? 0 : _revs.fold<int>(0, (s, r) => s + r.stars) / _revs.length;
  String get _avgText => _avg.toStringAsFixed(1);
  double _pct(int star) => _revs.isEmpty ? 0 : _revs.where((r) => r.stars == star).length / _revs.length;
  ProductReview? get _myReview {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    for (final r in _revs) {
      if (r.userId == uid) return r;
    }
    return null;
  }

  late String storage = widget.phone.storage;
  late String condition = widget.phone.condition;

  final _pager = PageController();
  final _scroll = ScrollController();
  final _pin = TextEditingController();
  final Set<int> _helpful = {};
  bool _scrolled = false; // true once the image header has scrolled away
  int page = 0;
  String? deliveryMsg;
  bool deliveryOk = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _revSub = reviewsFor(widget.phone.id).listen(
          (list) {
        if (mounted) setState(() => _revs = list);
      },
      onError: (Object _) {},
    );
    // Prefill the pincode from the customer's default saved address (if any).
    final defId = defaultAddressId.value;
    for (final a in savedAddresses.value) {
      if (a.id == defId) {
        _pin.text = a.pincode;
        _evaluatePin();
        break;
      }
    }
  }

  void _onScroll() {
    final gone = _scroll.hasClients && _scroll.offset > _heroH - 100;
    if (gone != _scrolled) setState(() => _scrolled = gone);
  }

  @override
  void dispose() {
    _revSub?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _pager.dispose();
    _pin.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  void _evaluatePin() {
    final pin = _pin.text.trim();
    if (RegExp(r'^\d{6}$').hasMatch(pin) && !isPincodeServiceable(pin)) {
      deliveryOk = false;
      deliveryMsg = 'Sorry, we do not deliver to $pin yet';
    } else if (RegExp(r'^\d{6}$').hasMatch(pin)) {
      deliveryOk = true;
      deliveryMsg = widget.phone.deliveryDays > 0
          ? 'Estimated delivery by ${_fmtDate(DateTime.now().add(Duration(days: widget.phone.deliveryDays)))} to $pin. Availability is confirmed at checkout.'
          : 'We deliver to $pin. The delivery date is confirmed at checkout.';
    } else {
      deliveryOk = false;
      deliveryMsg = 'Enter a valid 6-digit pincode';
    }
  }

  void _checkPin() {
    FocusScope.of(context).unfocus();
    setState(_evaluatePin);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  /// Why this phone cannot be added now (sold out / limit reached), or null when it can.
  String? _cartError(Phone p) {
    final i = cart.value.indexWhere((e) => e.phone.id == p.id && e.storage == storage && e.condition == condition);
    return cartAdditionError(p, currentQty: i >= 0 ? cart.value[i].qty : 0);
  }

  void _buyNow(Phone p) {
    final inCart = cart.value.any((e) => e.phone.id == p.id && e.storage == storage && e.condition == condition);
    if (!inCart) {
      final err = _cartError(p);
      if (err != null) {
        _toast(err);
        return;
      }
      addToCart(p, storage, condition);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen(selectMode: true)));
  }

  // ---------- Share (opens the phone's own share sheet: WhatsApp, Gmail, Messages, Bluetooth...) ----------

  Future<void> _shareProduct(Phone p) async {
    final message = 'Check out ${p.name} ($storage, $condition) on PhoneHub for ${rupee(p.price)}';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: p.name, title: p.name, sharePositionOrigin: origin),
      );
    } catch (e) {
      // Fallback if the platform share sheet cannot open (for example the app was only hot-reloaded
      // after adding share_plus - stop the app and run it again).
      debugPrint('Share failed: $e');
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      _toast('Share failed (${e.runtimeType}) - text copied instead');
    }
  }

  // ---------- Bottom sheets / viewer ----------

  static const _sheetShape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)));

  void _openEmiSheet(Phone p) {
    int selected = 6;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CheckoutSectionTitle('EMI plans'),
              const SizedBox(height: 6),
              Text('Pay ${rupee(p.price)} in easy monthly instalments', style: const TextStyle(color: AppColors.muted, fontSize: AppText.small)),
              const SizedBox(height: 14),
              for (final n in const [3, 6, 9]) ...[
                GestureDetector(
                  onTap: () => setSheet(() => selected = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: glassDeco(radius: 18, borderColor: selected == n ? AppColors.primary : null, borderWidth: selected == n ? 1.6 : 1),
                    child: Row(
                      children: [
                        Icon(selected == n ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected == n ? AppColors.primary : AppColors.muted, size: 22),
                        const SizedBox(width: 10),
                        Text('$n months', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text)),
                        if (n == 6) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: const Text('No-cost', style: TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                          ),
                        ],
                        const Spacer(),
                        Text('${rupee((p.price / n).round())}/mo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Text('Final EMI options are confirmed at checkout.', style: TextStyle(color: AppColors.muted, fontSize: AppText.small)),
              const SizedBox(height: 14),
              GradientButton(
                onTap: () {
                  Navigator.pop(ctx);
                  _buyNow(p);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('Continue'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _ReviewsSheet(reviews: _reviews, helpful: _helpful, rating: _avgText),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _writeReview(Phone p) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _WriteReviewSheet(phone: p, existing: _myReview),
    );
    if (done == true && mounted) _toast('Thanks! Your review is saved.');
  }

  void _openViewer(Phone p, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _GalleryViewer(phone: p, initial: index)),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _toast('$code copied. Paste it in your cart.');
  }

  // ---------- Small reusable pieces ----------

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Widget? custom}) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.all(8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: custom ?? Icon(icon, color: AppColors.text, size: 19),
    ),
  );

  Widget _title(String t, {String? action}) => _SectionTitle(t, action: action);

  /// Glass card with consistent padding (same style as the Saved Addresses cards).
  Widget _card({required Widget child, double radius = 20, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
    width: double.infinity,
    padding: padding,
    decoration: glassDeco(radius: radius),
    child: child,
  );

  /// Card header: small tinted icon tile + title + optional trailing widget.
  Widget _cardHeader(IconData icon, String title, {Widget? trailing}) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text))),
      if (trailing != null) trailing,
    ],
  );

  Widget _miniChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );

  /// Pill chips: same look as the Home / Work / Other chips on the address sheet.
  /// [fixed] = the value was set by the admin: it is only shown, the customer cannot change it.
  Widget _pills(List<String> options, String current, ValueChanged<String> onPick, {bool fixed = false}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        final on = o == current;
        return GestureDetector(
          onTap: fixed ? null : () => setState(() => onPick(o)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: on ? AppColors.primary : _line),
              boxShadow: on ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (on) ...[
                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(o, style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.text)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _iconRow(IconData icon, Widget child, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: child),
        if (trailing != null) trailing,
      ],
    ),
  );

  // ---------- Offers ----------

  Widget _offerRow(Coupon c) {
    final tag = c.percent > 0 ? '${c.percent}% off' : (c.flat > 0 ? '₹${c.flat} off' : (c.freeDelivery ? 'Free delivery' : 'Offer'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_offer_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('${c.code} • $tag', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _copyCode(c.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: AppText.small, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Image gallery (swipe: front, back, in the box) ----------
  static const double _heroH = 360;

  Widget _stage(Phone p, Widget child, double top) => Container(
    decoration: const BoxDecoration(gradient: brandGradient),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(top: -20, right: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.10))),
        Positioned(bottom: -30, left: -20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.08))),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)])),
        ),
        Padding(
          padding: EdgeInsets.only(top: top, bottom: 52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(height: 10),
              Container(
                width: 110,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12)],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _glassPill(String text, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(text, style: const TextStyle(color: Colors.white, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  /// A real photo the admin added, shown whole (not cropped) with no card behind it.
  Widget _photoStage(String src, double ph) => SizedBox(
    width: MediaQuery.of(context).size.width - 64,
    height: ph + 20,
    child: PhoneCutout(source: src),
  );

  Widget _gallery(Phone p) {
    final labels = phoneGalleryLabels(p);
    final top = MediaQuery.of(context).padding.top + kToolbarHeight;
    final ph = (_heroH - top - 52 - 24).clamp(170.0, 280.0).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pager,
          itemCount: labels.length,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) {
            final content = p.imageUrls.isNotEmpty
                ? _stage(p, _photoStage(p.imageUrls[i], ph), top)
                : (i == 2 ? _stage(p, PhoneBoxMockup(phone: p, height: ph * 0.85), top) : _stage(p, PhoneMockup(phone: p, height: ph, back: i == 1), top));
            return GestureDetector(onTap: () => _openViewer(p, i), child: content);
          },
        ),
        Positioned(left: 16, bottom: 38, child: _glassPill(labels[page])),
        Positioned(right: 16, bottom: 38, child: _glassPill('${page + 1} / ${labels.length}', icon: Icons.zoom_out_map_rounded)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 42,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < labels.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: i == page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(8)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Compact bar that fades in once the image header has scrolled away,
  /// so Back / Share / Wishlist are always reachable.
  Widget _stickyBar(Phone p) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [BoxShadow(color: const Color(0xFF1B2A5C).withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(width: 56, height: 56, child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context))),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Text(rupee(p.price), style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
            SizedBox(width: 56, height: 56, child: _circleBtn(Icons.ios_share_rounded, () => _shareProduct(p), custom: const _ShareIcon(size: 20, color: AppColors.text))),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(width: 40, height: 40, child: FittedBox(fit: BoxFit.contain, child: WishHeart(id: p.id))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingBar(int star, double pct) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text('$star', style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700)),
        const SizedBox(width: 3),
        const Icon(Icons.star_rounded, size: 12, color: _star),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: const Color(0xFFE3ECFB), valueColor: const AlwaysStoppedAnimation(_star)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 32, child: Text('${(pct * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(color: _subText, fontSize: AppText.caption))),
      ],
    ),
  );

  void _toggleHelpful(int i) {
    setState(() {
      if (!_helpful.remove(i)) _helpful.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.phone;
    final lowStock = lowStockLabel(p); // real stock, only when 1 to 5 units are left
    final revList = _reviews;
    final emi = (p.price / 6).round();
    final specs = p.specRows.isNotEmpty ? p.specRows : <(String, String)>[('Brand', p.brand), ('Battery health', '${p.battery}%')];
    final checks = p.qualityChecks;
    final inBox = p.inBox;
    final similar = [
      ...phones.where((x) => x.id != p.id && x.brand == p.brand),
      ...phones.where((x) => x.id != p.id && x.brand != p.brand),
    ].take(5).toList();
    final offers = coupons.where((c) => c.minOrder <= p.price).take(3).toList();
    // 20 outer padding x2, 14 card padding x2, 10 gap
    final halfWidth = ((MediaQuery.of(context).size.width - 40 - 28 - 10) / 2).floorToDouble();
    final batteryLabel = p.battery >= 90 ? 'Excellent' : (p.battery >= 80 ? 'Good' : 'Average');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scrolled ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: CheckoutBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverAppBar(
                    pinned: false,
                    expandedHeight: _heroH,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    leading: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                    actions: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: _circleBtn(Icons.ios_share_rounded, () => _shareProduct(p), custom: const _ShareIcon(size: 20, color: AppColors.text)),
                      ),
                      // Same 40 px circle as the back and share buttons (heart is scaled to fit the box)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: SizedBox(width: 40, height: 40, child: FittedBox(fit: BoxFit.contain, child: WishHeart(id: p.id))),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.none,
                      background: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                        child: _gallery(p),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Compact page label following PhoneHub's light-blue section-heading style.
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_android_rounded, size: 15, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('PRODUCT DETAILS', style: TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Brand, stock, rating
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
                                child: Text(p.brand, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: AppText.small)),
                              ),
                              if (lowStock != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                                  child: Text(lowStock, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.small)),
                                ),
                              ],
                              const Spacer(),
                              if (_revs.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(9)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_avgText, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: AppText.small)),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.star_rounded, color: Colors.white, size: 13),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('${_revs.length} ${_revs.length == 1 ? 'rating' : 'ratings'}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                              ] else
                                const Text('No ratings yet', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('${p.name} • $storage', style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3, height: 1.2)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ConditionChip(condition),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              const Text('Verified by PhoneHub', style: TextStyle(color: AppColors.muted, fontSize: AppText.small, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Price card
                          _card(
                            radius: 22,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Special price', style: TextStyle(color: AppColors.success, fontSize: AppText.small, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(rupee(p.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.1)),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(rupee(p.mrp), style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: AppText.small)),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                        child: Text('${p.off}% OFF', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: AppText.caption)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text('You save ${rupee(p.mrp - p.price)} • Inclusive of all taxes', style: const TextStyle(color: AppColors.success, fontSize: AppText.small, fontWeight: FontWeight.w700)),
                                if (p.noCostEmi) ...[
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => _openEmiSheet(p),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text('No-cost EMI from ${rupee(emi)}/mo for 6 months', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: AppText.small))),
                                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _miniChip(Icons.local_shipping_outlined, deliveryFor(p.price) == 0 ? 'Free delivery' : 'Delivery ${rupee(deliveryFor(p.price))}', AppColors.primary),
                                    if (p.cashOnDelivery) _miniChip(Icons.currency_rupee_rounded, 'Cash on delivery', AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Available offers (coupons that work on this phone's price)
                          if (offers.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _card(
                              radius: 22,
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _cardHeader(Icons.local_offer_outlined, 'Available offers'),
                                  const SizedBox(height: 6),
                                  for (int i = 0; i < offers.length; i++) ...[
                                    if (i != 0) const Divider(height: 1, color: _line),
                                    _offerRow(offers[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          // Variant selection in one card
                          _card(
                            radius: 22,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _title('Storage'),
                                const SizedBox(height: 10),
                                _pills(storage.isEmpty ? const <String>[] : [storage], storage, (v) => storage = v, fixed: true),
                                const SizedBox(height: 16),
                                const Divider(height: 1, color: _line),
                                const SizedBox(height: 16),
                                _title('Condition'),
                                const SizedBox(height: 10),
                                _pills(condition.isEmpty ? const <String>[] : [condition], condition, (v) => condition = v, fixed: true),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(color: checkoutFieldFill, borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_conditionInfo[condition] ?? '', style: const TextStyle(color: AppColors.text, fontSize: AppText.small, height: 1.35))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Battery
                          _card(
                            radius: 22,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.battery_charging_full_rounded, color: AppColors.success, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(child: Text('Battery Health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text))),
                                    Text('${p.battery}%', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: AppText.subtitle)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(value: p.battery / 100, minHeight: 8, backgroundColor: const Color(0xFFE3ECFB), valueColor: const AlwaysStoppedAnimation(AppColors.success)),
                                ),
                                const SizedBox(height: 8),
                                Text('$batteryLabel battery condition • tested by PhoneHub', style: const TextStyle(color: _subText, fontSize: AppText.small)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Trust badges
                          Row(
                            children: [
                              const Expanded(child: _Badge(Icons.verified_rounded, 'Verified\nDevice', AppColors.primary)),
                              if (p.warrantyMonths > 0) ...[
                                const SizedBox(width: 10),
                                Expanded(child: _Badge(Icons.shield_rounded, '${p.warrantyMonths}-Month Seller\nWarranty', AppColors.success)),
                              ],
                              if (p.returnDays > 0) ...[
                                const SizedBox(width: 10),
                                Expanded(child: _Badge(Icons.replay_circle_filled_rounded, '${p.returnDays}-Day\nReturn', AppColors.accent)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Quality check (admin ticks the checks per phone)
                          if (checks.isNotEmpty) ...[
                            _card(
                              radius: 22,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _cardHeader(
                                    Icons.fact_check_outlined,
                                    '${checks.length} quality checks',
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Passed', style: TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final c in checks)
                                        SizedBox(
                                          width: halfWidth,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text(c, style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w600, color: AppColors.text))),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Delivery (pincode check + details in one card)
                          _card(
                            radius: 22,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardHeader(Icons.local_shipping_outlined, 'Delivery & seller'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pin,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        maxLength: 6,
                                        style: const TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600),
                                        onSubmitted: (_) => _checkPin(),
                                        decoration: InputDecoration(
                                          hintText: 'Enter 6-digit pincode',
                                          hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                                          counterText: '',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                          filled: true,
                                          fillColor: checkoutFieldFill,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 46,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(80, 46),
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 3,
                                          shadowColor: AppColors.primary.withValues(alpha: 0.30),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: _checkPin,
                                        child: const Text('Check', style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                                // Quick pick from the customer's saved addresses
                                ValueListenableBuilder<List<SavedAddress>>(
                                  valueListenable: savedAddresses,
                                  builder: (context, list, _) {
                                    if (list.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final a in list)
                                            GestureDetector(
                                              onTap: () {
                                                _pin.text = a.pincode;
                                                _checkPin();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(a.label == 'Work' ? Icons.work_outline_rounded : (a.label == 'Other' ? Icons.place_outlined : Icons.home_outlined), size: 13, color: AppColors.primary),
                                                    const SizedBox(width: 5),
                                                    Text('${a.label} • ${a.pincode}', style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (deliveryMsg != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(deliveryOk ? Icons.check_circle_rounded : Icons.error_rounded, size: 14, color: deliveryOk ? AppColors.success : AppColors.danger),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(deliveryMsg!, style: TextStyle(color: deliveryOk ? AppColors.success : AppColors.danger, fontSize: AppText.small, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                const Divider(height: 1, color: _line),
                                _iconRow(
                                  Icons.local_shipping_outlined,
                                  Text(
                                    deliveryOk && deliveryMsg != null
                                        ? deliveryMsg!
                                        : (p.deliveryDays > 0 ? 'Delivery by ${_fmtDate(DateTime.now().add(Duration(days: p.deliveryDays)))}' : 'Delivery date is confirmed at checkout'),
                                    style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w600, color: AppColors.text),
                                  ),
                                ),
                                const Divider(height: 1, color: _line),
                                _iconRow(
                                  Icons.storefront_outlined,
                                  Text('Seller: PhoneHub Verified Seller\n${_revs.isEmpty ? '' : '$_avgText ★  •  '}Quality checked device', style: const TextStyle(fontSize: AppText.small, height: 1.4, color: AppColors.text)),
                                  trailing: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Specifications
                          _title('Specifications'),
                          const SizedBox(height: 10),
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: glassDeco(radius: 22),
                            child: Column(
                              children: [
                                for (int i = 0; i < specs.length; i++) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 4, child: Text(specs[i].$1, style: const TextStyle(color: _subText, fontSize: AppText.small))),
                                        Expanded(flex: 6, child: Text(specs[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.small, color: AppColors.text))),
                                      ],
                                    ),
                                  ),
                                  if (i != specs.length - 1) const Divider(height: 1, indent: 14, endIndent: 14, color: _line),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // What's in the box (admin list per phone)
                          if (inBox.isNotEmpty) ...[
                            _title("What's in the box"),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final b in inBox)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                                        const SizedBox(width: 5),
                                        Text(b, style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],
                          // Ratings & reviews (real reviews from customers)
                          _title('Ratings & reviews'),
                          const SizedBox(height: 10),
                          if (revList.isEmpty)
                            _card(
                              radius: 22,
                              child: const Row(
                                children: [
                                  Icon(Icons.rate_review_outlined, color: AppColors.primary, size: 26),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text('No reviews yet. Reviews from customers who bought this phone will appear here.', style: TextStyle(color: _subText, fontSize: AppText.small, height: 1.4)),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            _card(
                              radius: 22,
                              child: Row(
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_avgText, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.1)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          for (int s = 1; s <= 5; s++)
                                            Icon(_avg >= s ? Icons.star_rounded : (_avg >= s - 0.5 ? Icons.star_half_rounded : Icons.star_border_rounded), size: 13, color: _star),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${revList.length} ${revList.length == 1 ? 'review' : 'reviews'}', style: const TextStyle(color: _subText, fontSize: AppText.caption)),
                                    ],
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        for (final s in const [5, 4, 3, 2, 1]) _ratingBar(s, _pct(s)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (int i = 0; i < revList.length && i < 2; i++)
                              _ReviewCard(rev: revList[i], helpful: _helpful.contains(i), onHelpful: () => _toggleHelpful(i)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: _line, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _openReviews,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('See all ${revList.length} ${revList.length == 1 ? 'review' : 'reviews'}', style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Only customers who received this phone can review it.
                          if (hasPurchased(p.id)) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: _line, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _writeReview(p),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 16),
                                    const SizedBox(width: 6),
                                    Text(_myReview == null ? 'Write a review' : 'Edit your review', style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Similar phones
                          if (similar.isNotEmpty) ...[
                            _title('You may also like'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 252,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: similar.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (_, i) => SizedBox(width: 170, child: PhoneCard(phone: similar[i])),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Compact bar that appears after the image header scrolls away
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_scrolled,
                  child: AnimatedOpacity(
                    opacity: _scrolled ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: _stickyBar(p),
                  ),
                ),
              ),
            ],
          ),
          // Bottom bar (same decoration as the Saved Addresses bottom bar)
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: checkoutBottomBarDeco(),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final err = _cartError(p);
                        if (err != null) {
                          _toast(err);
                          return;
                        }
                        addToCart(p, storage, condition);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('${p.name} added to cart'),
                            action: SnackBarAction(
                              label: 'VIEW',
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen(showBack: true))),
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.add_shopping_cart_rounded, size: 21),
                    ),
                  ),
                  if (p.noCostEmi) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _openEmiSheet(p),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Buy with EMI', style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800)),
                              Text('From ${rupee(emi)}/m', style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      onTap: () => _buyNow(p),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: brandGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Buy now', style: TextStyle(color: Colors.white, fontSize: AppText.small, fontWeight: FontWeight.w900)),
                            Text('at ${rupee(p.price)}', style: const TextStyle(color: Colors.white70, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Reviews ----------

class _ReviewCard extends StatelessWidget {
  final _Rev rev;
  final bool helpful;
  final VoidCallback onHelpful;
  const _ReviewCard({required this.rev, required this.helpful, required this.onHelpful});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: glassDeco(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(rev.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: AppText.body))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rev.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (rev.verified) ...[
                          const Icon(Icons.verified_rounded, size: 11, color: AppColors.success),
                          const SizedBox(width: 3),
                        ],
                        Text(rev.verified ? 'Verified buyer • ${rev.date}' : rev.date, style: const TextStyle(color: _subText, fontSize: AppText.caption)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: rev.stars >= 4 ? AppColors.success : _star, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${rev.stars}', style: const TextStyle(color: Colors.white, fontSize: AppText.small, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 2),
                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(rev.text, style: const TextStyle(color: AppColors.text, fontSize: AppText.small, height: 1.5)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onHelpful,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: helpful ? AppColors.primary : checkoutFieldFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(helpful ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 13, color: helpful ? Colors.white : AppColors.primary),
                  const SizedBox(width: 5),
                  Text('Helpful', style: TextStyle(color: helpful ? Colors.white : AppColors.primary, fontSize: AppText.small, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "See all reviews" sheet with a star filter.
class _ReviewsSheet extends StatefulWidget {
  final List<_Rev> reviews;
  final Set<int> helpful;
  final Object rating;
  const _ReviewsSheet({required this.reviews, required this.helpful, required this.rating});

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  int _filter = 0; // 0 = all, otherwise the star count

  @override
  Widget build(BuildContext context) {
    final indices = [
      for (int i = 0; i < widget.reviews.length; i++)
        if (_filter == 0 || widget.reviews[i].stars == _filter) i,
    ];
    const filters = [0, 5, 4, 3, 2, 1];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CheckoutSectionTitle('Ratings & reviews'),
            const SizedBox(height: 4),
            Text('${widget.rating} average • ${indices.length} shown', style: const TextStyle(color: AppColors.muted, fontSize: AppText.small)),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final on = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: on ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: on ? AppColors.primary : _line),
                        boxShadow: on ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Text(f == 0 ? 'All' : '$f ★', style: TextStyle(color: on ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: AppText.body)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: indices.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _line, width: 1.5),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
                      ),
                      child: const Icon(Icons.rate_review_outlined, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 18),
                    const Text('No reviews for this rating', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.subtitle, color: AppColors.text)),
                    const SizedBox(height: 4),
                    const Text('Try a different filter', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              )
                  : ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final i in indices)
                    _ReviewCard(
                      rev: widget.reviews[i],
                      helpful: widget.helpful.contains(i),
                      onHelpful: () => setState(() {
                        if (!widget.helpful.remove(i)) widget.helpful.add(i);
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet where a customer who received the phone writes (or edits) his review.
class _WriteReviewSheet extends StatefulWidget {
  final Phone phone;
  final ProductReview? existing;
  const _WriteReviewSheet({required this.phone, this.existing});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  late int _stars = widget.existing?.stars ?? 0;
  late final TextEditingController _text = TextEditingController(text: widget.existing?.text ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_stars < 1 || _stars > 5) {
      setState(() => _error = 'Please tap a star to rate this phone');
      return;
    }
    FocusScope.of(context).unfocus();
    final textError = _validateReviewText(_text.text);
    if (textError != null) {
      setState(() => _error = textError);
      return;
    }
    final cleanText = _cleanReviewText(_text.text);

    // Editing a review without changing anything: nothing to save.
    final old = widget.existing;
    if (old != null && old.stars == _stars && _cleanReviewText(old.text) == cleanText) {
      setState(() => _error = 'You have not changed your review');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await submitReview(phone: widget.phone, stars: _stars, text: cleanText);
      if (mounted) Navigator.pop(context, true);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your review. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Write a review' : 'Edit your review', style: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(widget.phone.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      _stars = i;
                      _error = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(i <= _stars ? Icons.star_rounded : Icons.star_border_rounded, size: 34, color: i <= _stars ? _star : AppColors.muted.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(fontSize: AppText.small, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tell others about the phone (optional)',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                filled: true,
                fillColor: checkoutFieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: AppText.small, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            GradientButton(
              height: 48,
              onTap: _saving ? () {} : _save,
              child: Text(_saving ? 'Saving...' : 'Submit review', style: const TextStyle(fontSize: AppText.small)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Full-screen image viewer (pinch to zoom, swipe between views) ----------

class _GalleryViewer extends StatefulWidget {
  final Phone phone;
  final int initial;
  const _GalleryViewer({required this.phone, required this.initial});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final List<String> _labels = phoneGalleryLabels(widget.phone);
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.55;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _labels.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: widget.phone.imageUrls.isNotEmpty
                    ? SizedBox.expand(child: PhonePhoto(source: widget.phone.imageUrls[i], fit: BoxFit.contain))
                    : (i == 2
                    ? PhoneBoxMockup(phone: widget.phone, height: h * 0.8)
                    : PhoneMockup(phone: widget.phone, height: h, back: i == 1)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${widget.phone.name} • ${_labels[_page]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: AppText.body, fontWeight: FontWeight.w800))),
                  Text('${_page + 1} / ${_labels.length}', style: const TextStyle(color: Colors.white70, fontSize: AppText.small, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _labels.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(color: i == _page ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(8)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Pinch to zoom • swipe for more views', style: TextStyle(color: Colors.white70, fontSize: AppText.small)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Badge(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: glassDeco(radius: 22),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// Share icon: open box with a curved forward arrow (like the common mobile-app share icon).
class _ShareIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _ShareIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _SharePainter(color)));
}

class _SharePainter extends CustomPainter {
  final Color color;
  const _SharePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Open box (gap at the top right where the arrow comes out)
    final box = Path()
      ..moveTo(9.5, 5.5)
      ..lineTo(6, 5.5)
      ..quadraticBezierTo(3.5, 5.5, 3.5, 8)
      ..lineTo(3.5, 18)
      ..quadraticBezierTo(3.5, 20.5, 6, 20.5)
      ..lineTo(16, 20.5)
      ..quadraticBezierTo(18.5, 20.5, 18.5, 18)
      ..lineTo(18.5, 15);
    canvas.drawPath(box, stroke);

    // Curved arrow shaft
    final shaft = Path()
      ..moveTo(8, 16.5)
      ..cubicTo(8.4, 12, 11, 9.6, 15.5, 9.6);
    canvas.drawPath(shaft, stroke);

    // Arrow head
    final head = Path()
      ..moveTo(14.8, 4.6)
      ..lineTo(22.2, 9.6)
      ..lineTo(14.8, 14.6)
      ..close();
    canvas.drawPath(head, fill);
  }

  @override
  bool shouldRepaint(covariant _SharePainter old) => old.color != color;
}