import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

/// Layout by screen: on a computer (wide window) the main screens are
/// horizontal; on a phone they stay vertical.
class Responsive {
  Responsive._();

  static const double wideBreakpoint = 900;

  static bool isWide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= wideBreakpoint && size.height >= 480;
  }
}

/// Screens designed for a phone (forms, settings, detail screens): on a
/// wide window they are shown as a centred column instead of stretched.
class NarrowOnWide extends StatelessWidget {
  const NarrowOnWide({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth + 40) return child;

    return ColoredBox(
      color: VestaTheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: Material(elevation: 4, child: child),
          ),
        ),
      ),
    );
  }
}
