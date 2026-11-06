import 'package:flutter/material.dart';

/// أيقونات التصنيفات (تُحفظ في قاعدة البيانات كرقم ترتيب في هذه القائمة).
const categoryIcons = <IconData>[
  Icons.restaurant,
  Icons.local_grocery_store,
  Icons.local_gas_station,
  Icons.receipt_long,
  Icons.shopping_bag,
  Icons.local_hospital,
  Icons.movie,
  Icons.school,
  Icons.atm,
  Icons.category,
  Icons.payments,
  Icons.call_received,
  Icons.savings,
  Icons.home,
  Icons.directions_car,
  Icons.flight,
  Icons.child_care,
  Icons.pets,
  Icons.phone_android,
  Icons.wifi,
  Icons.checkroom,
  Icons.fitness_center,
  Icons.volunteer_activism,
  Icons.card_giftcard,
  Icons.coffee,
  Icons.build,
  Icons.account_balance,
  Icons.work,
];

int iconIndex(IconData i) => categoryIcons.indexOf(i);

IconData iconAt(int i) =>
    i >= 0 && i < categoryIcons.length ? categoryIcons[i] : Icons.category;
