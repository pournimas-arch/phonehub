import 'package:flutter/material.dart';

class Product {
  final String id, name, brand, condition, storage, color, category;
  final int price;
  final IconData icon;
  const Product({
    required this.id, required this.name, required this.brand,
    required this.price, required this.condition, required this.storage,
    required this.color, required this.category, required this.icon,
  });
}

const demoProducts = <Product>[
  Product(id:'iphone13', name:'iPhone 13', brand:'Apple', price:28999, condition:'Very Good', storage:'128 GB', color:'Midnight', category:'Apple', icon:Icons.phone_iphone),
  Product(id:'s22', name:'Samsung Galaxy S22', brand:'Samsung', price:21999, condition:'Good', storage:'128 GB', color:'Black', category:'Samsung', icon:Icons.smartphone),
  Product(id:'oneplus11r', name:'OnePlus 11R', brand:'OnePlus', price:24999, condition:'Very Good', storage:'256 GB', color:'Green', category:'OnePlus', icon:Icons.smartphone),
  Product(id:'iphone12', name:'iPhone 12', brand:'Apple', price:19999, condition:'Good', storage:'64 GB', color:'Blue', category:'Apple', icon:Icons.phone_iphone),
];

String formatPrice(int price) {
  final value = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) buffer.write(',');
    buffer.write(value[i]);
  }
  return '₹$buffer';
}
