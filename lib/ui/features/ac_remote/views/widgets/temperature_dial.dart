import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../domain/models/ac_state.dart';
import '../../../../core/theme/ac_style.dart';
import '../../../../core/theme/app_colors.dart';

/// Circular temperature readout with -/+ buttons, tinted by the AC mode.
class TemperatureDial extends StatelessWidget {
  const TemperatureDial({
    super.key,
    required this.state,
    required this.minTemperature,
    required this.maxTemperature,
    required this.onIncrease,
    required this.onDecrease,
  });

  final AcState state;
  final int minTemperature;
  final int maxTemperature;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    final on = state.isPowerOn;
    final showTemperature = on && state.mode.usesTemperature;
    final color = on ? state.mode.color : AppColors.textMuted;
    final range = (maxTemperature - minTemperature).clamp(1, 100);
    final progress = showTemperature ? (state.temperature - minTemperature) / range : 0.0;

    return Row(
      children: [
        _StepButton(icon: Icons.remove_rounded, tooltip: 'Cooler', onPressed: showTemperature ? onDecrease : null),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _DialPainter(progress: value, color: color, active: showTemperature),
                child: child,
              ),
              child: Padding(
                // Keep the readout inside the ring.
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          !on ? 'OFF' : (showTemperature ? '${state.temperature}°' : '--'),
                          style: TextStyle(
                            fontSize: on ? 64 : 44,
                            fontWeight: FontWeight.w300,
                            color: on ? AppColors.textPrimary : AppColors.textMuted,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(on ? state.mode.icon : Icons.power_settings_new_rounded, size: 18, color: color),
                    const SizedBox(height: 2),
                    Text(
                      on ? (state.mode.usesTemperature ? state.mode.label : 'Fan only') : 'Tap power to start',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, tooltip: 'Warmer', onPressed: showTemperature ? onIncrease : null),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      iconSize: 30,
      style: IconButton.styleFrom(
        minimumSize: const Size(60, 60),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textMuted,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress, required this.color, required this.active});

  final double progress;
  final Color color;
  final bool active;

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 8);

    final track = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _start, _sweep, false, track);

    if (!active) return;

    final sweep = _sweep * progress.clamp(0.0, 1.0);
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withValues(alpha: 0.35), color],
        transform: const GradientRotation(0),
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _start, math.max(sweep, 0.001), false, arc);

    final angle = _start + sweep;
    final radius = arcRect.width / 2;
    final knob = arcRect.center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    canvas.drawCircle(knob, stroke * 0.9, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(knob, stroke * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.progress != progress || old.color != color || old.active != active;
}
