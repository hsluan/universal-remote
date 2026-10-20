import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small IR LED that flashes whenever [pulse] changes and glows while [active].
class IrPulse extends StatelessWidget {
  const IrPulse({super.key, required this.pulse, this.active = false, this.size = 10});

  /// Increment to trigger one flash (e.g. a sent-command counter).
  final int pulse;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(pulse),
      tween: Tween(begin: pulse == 0 ? 0 : 1, end: 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, flash, _) {
        final glow = active ? 1.0 : flash;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(AppColors.ledOff, AppColors.ledOn, glow),
            boxShadow: glow > 0.05
                ? [BoxShadow(color: AppColors.ledGlow.withValues(alpha: 0.4 * glow), blurRadius: 10, spreadRadius: 2)]
                : null,
          ),
        );
      },
    );
  }
}
