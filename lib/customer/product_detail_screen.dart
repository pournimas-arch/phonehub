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

// ---------- Shared styling (same as Home screen) ----------

const LinearGradient _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
);

const _fieldFill = Color(0xFFEAF1FF);
const _line = Color(0xFFDCE7FB);
const _star = Color(0xFFF59E0B);
const _subText = Color(0xFF55657F); // darker than AppColors.muted for better contrast on cards

// Soft frosted white: light enough to blend with the blue gradient,
// solid enough that text stays easy to read.
final Color _glass = Colors.white.withValues(alpha: 0.30);
final Color _glassSoft = Colors.white.withValues(alpha: 0.22);
final Color _glassBorder = Colors.white.withValues(alpha: 0.65);

/// Card used all over the Home screen (slightly softer shadow now).
BoxDecoration _homeCardDecoration({double radius = 18}) => BoxDecoration(
  color: _glass,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _glassBorder, width: 1.2),
  boxShadow: [BoxShadow(color: const Color(0xFF2A4BA8).withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5))],
);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
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
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (action != null) Text(action!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );
}

/// Screen 4 – Product Detail (3h)
/// Image gallery, price with MRP strike-through and % off, EMI, storage / condition chips,
/// battery health, quality check, delivery check, specifications, what's in the box,
/// ratings & reviews, similar phones, Verified Device, 6-month seller warranty,
/// 7-day return, Add to Cart / Buy Now.
class ProductDetailScreen extends StatefulWidget {
  final Phone phone;
  const ProductDetailScreen({super.key, required this.phone});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const storages = ['64 GB', '128 GB', '256 GB'];
  static const conditions = ['Like New', 'Good', 'Fair'];
  static const _conditionInfo = {
    'Like New': 'No visible scratches. Looks and works like a new phone.',
    'Good': 'Light signs of use. Fully working with minor marks on the body.',
    'Fair': 'Visible scratches or dents. Fully working and priced lower.',
  };
  static const _checks = ['Display', 'Camera', 'Battery', 'Speakers & mic', 'Network & Wi-Fi', 'Sensors', 'Charging port', 'Buttons'];
  static const _inBox = ['Phone', 'Original charger', 'Cable', 'Fresh box', 'Warranty card'];

  late String storage = widget.phone.storage;
  late String condition = widget.phone.condition;

  // Replace with your real product link base when the website / deep link is ready.
  static const _shareBase = 'https://phonehub.app/phone/';

  final _pager = PageController();
  final _scroll = ScrollController();
  final _pin = TextEditingController();
  bool _scrolled = false; // true once the image header has scrolled away
  int page = 0;
  String? deliveryMsg;
  bool deliveryOk = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final gone = _scroll.hasClients && _scroll.offset > _heroH - 100;
    if (gone != _scrolled) setState(() => _scrolled = gone);
  }

  @override
  void dispose() {
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

  void _checkPin() {
    FocusScope.of(context).unfocus();
    final pin = _pin.text.trim();
    setState(() {
      if (RegExp(r'^\d{6}$').hasMatch(pin)) {
        deliveryOk = true;
        deliveryMsg = 'Delivery by ${_fmtDate(DateTime.now().add(const Duration(days: 3)))} to $pin. Free above ₹10,000.';
      } else {
        deliveryOk = false;
        deliveryMsg = 'Enter a valid 6-digit pincode';
      }
    });
  }

  // ---------- Share (opens the phone's own share sheet: WhatsApp, Gmail, Messages, Bluetooth...) ----------

  Future<void> _shareProduct(Phone p) async {
    final link = '$_shareBase${p.id}';
    final message = 'Check out ${p.name} ($storage, $condition) on PhoneHub for ${rupee(p.price)}\n$link';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Share failed (${e.runtimeType}) - link copied instead')));
    }
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
        border: Border.all(color: const Color(0xFFDCE8FF)),
        boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: custom ?? Icon(icon, color: AppColors.text, size: 19),
    ),
  );

  Widget _title(String t, {String? action}) => _SectionTitle(t, action: action);

  /// White card with consistent padding.
  Widget _card({required Widget child, double radius = 20, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
    width: double.infinity,
    padding: padding,
    decoration: _homeCardDecoration(radius: radius),
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
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text))),
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
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );

  Widget _pills(List<String> options, String current, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = o == current;
        return GestureDetector(
          onTap: () => setState(() => onPick(o)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.primary.withValues(alpha: 0.12) : _glassSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? AppColors.primary : _glassBorder, width: on ? 1.5 : 1),
              boxShadow: on ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.16), blurRadius: 8, offset: const Offset(0, 3))] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (on) ...[
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 5),
                ],
                Text(o, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? AppColors.primary : AppColors.text)),
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

  Widget _glassPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
  );

  Widget _gallery(Phone p) {
    const labels = ['Front view', 'Back view', 'In the box'];
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
            if (i == 2) return _stage(p, PhoneBoxMockup(phone: p, height: ph * 0.85), top);
            return _stage(p, PhoneMockup(phone: p, height: ph, back: i == 1), top);
          },
        ),
        Positioned(left: 16, bottom: 38, child: _glassPill(labels[page])),
        Positioned(right: 16, bottom: 38, child: _glassPill('${page + 1} / ${labels.length}')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 42,
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
      ],
    );
  }

  Widget _ratingBar(int star, double pct) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text('$star', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
        SizedBox(width: 32, child: Text('${(pct * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(color: _subText, fontSize: 10.5))),
      ],
    ),
  );

  Widget _review(String name, int stars, String date, String text) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: _homeCardDecoration(radius: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.text)),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 11, color: AppColors.success),
                      const SizedBox(width: 3),
                      Text('Verified buyer • $date', style: const TextStyle(color: _subText, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: stars >= 4 ? AppColors.success : _star, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$stars', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: AppColors.text, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.thumb_up_alt_outlined, size: 13, color: AppColors.primary),
              SizedBox(width: 5),
              Text('Helpful', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.phone;
    final left = (int.tryParse(p.id.substring(1)) ?? 3) % 4 + 2; // 2 to 5 units
    final emi = (p.price / 6).round();
    final specs = _specsFor(p);
    final similar = [
      ...phones.where((x) => x.id != p.id && x.brand == p.brand),
      ...phones.where((x) => x.id != p.id && x.brand != p.brand),
    ].take(5).toList();
    // 16 outer padding x2, 14 card padding x2, 10 gap
    final halfWidth = ((MediaQuery.of(context).size.width - 32 - 28 - 10) / 2).floorToDouble();
    final batteryLabel = p.battery >= 90 ? 'Excellent' : (p.battery >= 80 ? 'Good' : 'Average');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scrolled ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              pinned: false,
              expandedHeight: _heroH,
              backgroundColor: AppColors.primary,
              surfaceTintColor: Colors.transparent,
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
              flexibleSpace: FlexibleSpaceBar(background: _gallery(p)),
            ),
            SliverToBoxAdapter(
              child: Container(
                transform: Matrix4.translationValues(0, -24, 0),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(gradient: _bgGradient, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                child: Stack(
                  children: [
                    Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
                    Positioned(top: 900, left: -120, child: _Blob(280, 0.20)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 46, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand, stock, rating
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
                                child: Text(p.brand, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                                child: Text('Only $left left', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(9)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${p.rating}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 11.5)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.star_rounded, color: Colors.white, size: 13),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('128 ratings', style: TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('${p.name} • $storage', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3, height: 1.2)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ConditionChip(condition),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              const Text('Verified by PhoneHub', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Price card
                          _card(
                            radius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Special price', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(rupee(p.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.1)),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(rupee(p.mrp), style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: 12.5)),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                                        child: Text('${p.off}% OFF', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 10.5)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text('You save ${rupee(p.mrp - p.price)} • Inclusive of all taxes', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('EMI starts from ${rupee(emi)}/month for 6 months')),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text('No-cost EMI from ${rupee(emi)}/mo for 6 months', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11.5))),
                                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _miniChip(Icons.local_shipping_outlined, 'Free delivery', AppColors.primary),
                                    _miniChip(Icons.currency_rupee_rounded, 'Cash on delivery', AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Variant selection in one card
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _title('Storage'),
                                const SizedBox(height: 10),
                                _pills(storages, storage, (v) => storage = v),
                                const SizedBox(height: 16),
                                const Divider(height: 1, color: _line),
                                const SizedBox(height: 16),
                                _title('Condition'),
                                const SizedBox(height: 10),
                                _pills(conditions, condition, (v) => condition = v),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_conditionInfo[condition] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 11.5, height: 1.35))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Battery
                          _card(
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
                                    const Expanded(child: Text('Battery Health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text))),
                                    Text('${p.battery}%', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(value: p.battery / 100, minHeight: 8, backgroundColor: const Color(0xFFE3ECFB), valueColor: const AlwaysStoppedAnimation(AppColors.success)),
                                ),
                                const SizedBox(height: 8),
                                Text('$batteryLabel battery condition • tested by PhoneHub', style: const TextStyle(color: _subText, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Trust badges
                          const Row(
                            children: [
                              Expanded(child: _Badge(Icons.verified_rounded, 'Verified\nDevice', AppColors.primary)),
                              SizedBox(width: 10),
                              Expanded(child: _Badge(Icons.shield_rounded, '6-Month Seller\nWarranty', AppColors.success)),
                              SizedBox(width: 10),
                              Expanded(child: _Badge(Icons.replay_circle_filled_rounded, '7-Day\nReturn', AppColors.accent)),
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Quality check
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardHeader(
                                  Icons.fact_check_outlined,
                                  '40-point quality check',
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Passed', style: TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final c in _checks)
                                      SizedBox(
                                        width: halfWidth,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Delivery (pincode check + details in one card)
                          _card(
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
                                        maxLength: 6,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        onSubmitted: (_) => _checkPin(),
                                        decoration: InputDecoration(
                                          hintText: 'Enter 6-digit pincode',
                                          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                          prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                                          counterText: '',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                          filled: true,
                                          fillColor: _fieldFill,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _checkPin,
                                        child: const Text('Check', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                                if (deliveryMsg != null && !deliveryOk) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(deliveryOk ? Icons.check_circle_rounded : Icons.error_rounded, size: 14, color: deliveryOk ? AppColors.success : AppColors.danger),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(deliveryMsg!, style: TextStyle(color: deliveryOk ? AppColors.success : AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                const Divider(height: 1, color: _line),
                                _iconRow(
                                  Icons.local_shipping_outlined,
                                  Text(
                                    deliveryOk && deliveryMsg != null ? deliveryMsg! : 'Delivery by ${_fmtDate(DateTime.now().add(const Duration(days: 3)))}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                                  ),
                                ),
                                const Divider(height: 1, color: _line),
                                _iconRow(
                                  Icons.storefront_outlined,
                                  const Text('Seller: PhoneHub Verified Seller\n4.5 ★  •  Quality checked device', style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.text)),
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
                            decoration: _homeCardDecoration(radius: 20),
                            child: Column(
                              children: [
                                for (int i = 0; i < specs.length; i++) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 4, child: Text(specs[i].$1, style: const TextStyle(color: _subText, fontSize: 11.5))),
                                        Expanded(flex: 6, child: Text(specs[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.text))),
                                      ],
                                    ),
                                  ),
                                  if (i != specs.length - 1) const Divider(height: 1, indent: 14, endIndent: 14, color: _line),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // What's in the box
                          _title("What's in the box"),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final b in _inBox)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: _glassBorder)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                                      const SizedBox(width: 5),
                                      Text(b, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Ratings & reviews
                          _title('Ratings & reviews'),
                          const SizedBox(height: 10),
                          _card(
                            child: Row(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${p.rating}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.1)),
                                    const SizedBox(height: 2),
                                    const Row(children: [Icon(Icons.star_rounded, size: 13, color: _star), Icon(Icons.star_rounded, size: 13, color: _star), Icon(Icons.star_rounded, size: 13, color: _star), Icon(Icons.star_rounded, size: 13, color: _star), Icon(Icons.star_half_rounded, size: 13, color: _star)]),
                                    const SizedBox(height: 4),
                                    const Text('128 reviews', style: TextStyle(color: _subText, fontSize: 10.5)),
                                  ],
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _ratingBar(5, 0.68),
                                      _ratingBar(4, 0.20),
                                      _ratingBar(3, 0.08),
                                      _ratingBar(2, 0.03),
                                      _ratingBar(1, 0.01),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _review('Rohan K.', 5, 'Sep 2026', 'Phone looked exactly like new. Battery easily lasts a full day and the delivery was quick.'),
                          _review('Sneha P.', 4, 'Aug 2026', 'Great value for the price. A tiny mark on the frame, but exactly as described in the listing.'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: _glass,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(behavior: SnackBarBehavior.floating, content: Text('All 128 reviews coming soon')),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('See all 128 reviews', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
        // Rounded bottom bar (same look as the Home navigation bar)
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [BoxShadow(color: const Color(0xFF1B2A5C).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -6))],
          ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
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
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(behavior: SnackBarBehavior.floating, content: Text('EMI starts from ${rupee(emi)}/month for 6 months')),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Buy with EMI', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          Text('From ${rupee(emi)}/m', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: () {
                      addToCart(p, storage, condition);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen(selectMode: true)));
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Buy now', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                          Text('at ${rupee(p.price)}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
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
    );
  }
}

// ---------- Specifications (approximate; edit to match your real listings) ----------

List<(String, String)> _s(String display, String chip, String ram, String rear, String front, String battery, String os) => [
  ('Display', display),
  ('Processor', chip),
  ('RAM', ram),
  ('Rear camera', rear),
  ('Front camera', front),
  ('Battery', battery),
  ('Operating system', os),
];

List<(String, String)> _specsFor(Phone p) {
  switch (p.id) {
    case 'p1':
      return _s('6.1" Super Retina XDR OLED', 'Apple A15 Bionic', '4 GB', '12 MP + 12 MP dual', '12 MP', '3240 mAh', 'iOS');
    case 'p2':
      return _s('6.1" Super Retina XDR OLED', 'Apple A14 Bionic', '4 GB', '12 MP + 12 MP dual', '12 MP', '2815 mAh', 'iOS');
    case 'p3':
      return _s('6.2" Dynamic AMOLED 2X, 120 Hz', 'Exynos 2100', '8 GB', '12 MP + 64 MP + 12 MP', '10 MP', '4000 mAh', 'Android (One UI)');
    case 'p4':
      return _s('6.4" Super AMOLED, 120 Hz', 'Exynos 1380', '8 GB', '50 MP + 12 MP + 5 MP', '32 MP', '5000 mAh', 'Android (One UI)');
    case 'p5':
      return _s('6.74" AMOLED, 120 Hz', 'Snapdragon 8+ Gen 1', '16 GB', '50 MP + 8 MP + 2 MP', '16 MP', '5000 mAh', 'Android (OxygenOS)');
    case 'p6':
      return _s('6.7" AMOLED, 120 Hz', 'Snapdragon 782G', '8 GB', '50 MP + 8 MP + 2 MP', '16 MP', '5000 mAh', 'Android (OxygenOS)');
    case 'p7':
      return _s('6.67" AMOLED, 120 Hz', 'Dimensity 1080', '6 / 8 GB', '50 MP + 8 MP + 2 MP', '16 MP', '5000 mAh', 'Android (MIUI)');
    case 'p8':
      return _s('6.67" AMOLED, 120 Hz', 'Snapdragon 888', '8 GB', '108 MP + 8 MP + 5 MP', '16 MP', '5000 mAh, 120W charging', 'Android (MIUI)');
    case 'p9':
      return _s('6.7" AMOLED, 120 Hz', 'Dimensity 8100', '8 / 12 GB', '50 MP + 8 MP + 2 MP', '16 MP', '4500 / 5000 mAh', 'Android (Realme UI)');
    case 'p10':
      return _s('6.7" curved AMOLED, 120 Hz', 'Dimensity 7050', '8 GB', '100 MP + 2 MP', '16 MP', '5000 mAh', 'Android (Realme UI)');
    default:
      return [('Brand', p.brand), ('Battery health', '${p.battery}%')];
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
      decoration: _homeCardDecoration(radius: 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.text)),
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