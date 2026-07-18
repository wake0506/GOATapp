import 'package:flutter/material.dart';

abstract final class GoatHeaderTypography {
  static const pageTitle = TextStyle(
    color: Color(0xFF25292D),
    fontWeight: FontWeight.w200,
    letterSpacing: 4,
    fontSize: 18,
  );
}

class GoatPageHeader extends StatelessWidget {
  const GoatPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: GoatHeaderTypography.pageTitle);
}
