import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// أيقونات التصنيفات (تُحفظ في قاعدة البيانات كرقم ترتيب في هذه القائمة).
/// لا تغيّر ترتيب العناصر حتى لا تتغير أيقونات التصنيفات المحفوظة.
const categoryIcons = <IconData>[
  Icons.restaurant_rounded, // 0 طعام
  CupertinoIcons.cart_fill, // 1 بقالة
  Icons.local_gas_station_rounded, // 2 وقود
  CupertinoIcons.doc_text_fill, // 3 فواتير
  CupertinoIcons.bag_fill, // 4 تسوق
  CupertinoIcons.heart_fill, // 5 صحة
  CupertinoIcons.film_fill, // 6 ترفيه
  CupertinoIcons.book_fill, // 7 تعليم
  CupertinoIcons.money_dollar_circle_fill, // 8 سحب نقدي
  CupertinoIcons.square_grid_2x2_fill, // 9 أخرى
  CupertinoIcons.briefcase_fill, // 10 راتب
  CupertinoIcons.arrow_down_circle_fill, // 11 تحويل وارد
  Icons.savings_rounded, // 12 دخل آخر
  CupertinoIcons.house_fill, // 13
  CupertinoIcons.car_fill, // 14
  CupertinoIcons.airplane, // 15
  Icons.child_care_rounded, // 16
  CupertinoIcons.paw_solid, // 17
  CupertinoIcons.device_phone_portrait, // 18
  CupertinoIcons.wifi, // 19
  Icons.checkroom_rounded, // 20
  CupertinoIcons.sportscourt_fill, // 21
  CupertinoIcons.hand_raised_fill, // 22
  CupertinoIcons.gift_fill, // 23
  Icons.coffee_rounded, // 24
  CupertinoIcons.hammer_fill, // 25
  Icons.account_balance_rounded, // 26
  CupertinoIcons.briefcase, // 27
];

int iconIndex(IconData i) => categoryIcons.indexOf(i);

IconData iconAt(int i) => i >= 0 && i < categoryIcons.length
    ? categoryIcons[i]
    : CupertinoIcons.square_grid_2x2_fill;
