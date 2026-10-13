import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';

/// Wishlist – loads the signed-in customer's saved phone IDs from Firestore.
/// Existing layout and card styling are preserved.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in to view your wishlist.';
        });
        return;
      }

      // The customer data initializer loads products and the user's wishlist
      // from users/{uid}. It also keeps the existing ValueNotifier in sync.
      await initializeCustomerData();
      if (!mounted) return;
      setState(() => _loading = false);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'permission-denied'
            ? 'Access denied. Please check your Firestore Rules.'
            : 'Could not load your wishlist. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your wishlist. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadWishlist,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : ValueListenableBuilder<Set<String>>(
        valueListenable: wishlist,
        builder: (context, ids, _) {
          final saved = phones.where((p) => ids.contains(p.id)).toList();

          if (saved.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      size: 80, color: AppColors.muted),
                  SizedBox(height: 10),
                  Text('Your wishlist is empty',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Tap the heart on any phone to save it here',
                      style: TextStyle(color: AppColors.muted)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${saved.length} saved ${saved.length == 1 ? 'phone' : 'phones'}',
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: saved.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 252,
                  ),
                  itemBuilder: (_, i) => PhoneCard(phone: saved[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
