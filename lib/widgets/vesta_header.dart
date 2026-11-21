import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

class VestaHeader extends StatelessWidget {
  final bool isDark;

  const VestaHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final foreground = isDark ? VestaTheme.textPrimary : VestaTheme.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Image.asset(
        'assets/brand/vesta_logo.png',
        width: 230,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            'VESTA',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: foreground,
            ),
          );
        },
      ),
    );
  }
}
