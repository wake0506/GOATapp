import 'package:flutter/material.dart';

import '../../../widgets/goat_page_header.dart';

class TrainingPageHeader extends StatelessWidget {
  const TrainingPageHeader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(4, 8, 4, 2),
    child: GoatPageHeader(title: '训 练 记 录'),
  );
}
