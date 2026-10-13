import 'package:flutter/material.dart';
import 'package:phonehub/customer/help_support.dart';
import 'package:phonehub/customer/saved_addresses.dart';
import 'package:phonehub/customer/wishlist.dart';
import 'coupons_screen.dart';


/// Opens the screen for a Profile menu row (by its label).
void openProfileItem(BuildContext context, String label) {
  Widget? page;
  switch (label) {
    case 'Wishlist':
      page = const WishlistScreen();
      break;
    case 'Saved Addresses':
      page = const SavedAddressesScreen();
      break;
    case 'Coupons & Offers':
      page = const CouponsScreen();
      break;
    case 'Help & Support':
      page = const HelpSupportScreen();
      break;
  }
  if (page == null) return;
  final screen = page;
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
