import 'package:flutter/material.dart';

class NabeehColors {
  static const darkNavy   = Color(0xFF181059);
  static const darkBlue   = Color(0xFF21277B);
  static const lightBlue  = Color(0xFF1773CF);
  static const yellow     = Color(0xFFFFD350);
  static const green      = Color(0xFF00AA5B);
  static const gray       = Color(0xFFA4ACB0);
  static const background = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFA4ACB0);
}

const kBlueGradient = LinearGradient(
  colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
  stops: [0.09, 0.30, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);