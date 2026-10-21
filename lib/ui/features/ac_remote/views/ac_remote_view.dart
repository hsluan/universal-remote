import 'package:flutter/material.dart';

import '../../../../domain/models/ac_state.dart';
import '../../../core/theme/ac_style.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ir_pulse.dart';
import '../../../core/widgets/rename_dialog.dart';
import '../view_models/ac_remote_view_model.dart';
import 'widgets/temperature_dial.dart';

class AcRemoteView extends StatefulWidget {
  const AcRemoteView({super.key, required this.viewModel});

  final AcRemoteViewModel viewModel;

  @override
  State<AcRemoteView> createState() => _AcRemoteViewState();
}

class _AcRemoteViewState extends State<AcRemoteView> {
  String? _shownError;

  AcRemoteViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    final error = _vm.error;
    if (error == null || error == _shownError || !mounted) {
      _shownError = error;
      return;
    }
    _shownError = error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error),
        action: SnackBarAction(label: 'Retry', onPressed: _vm.resend),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final state = _vm.state;
        final caps = _vm.capabilities;
        final device = _vm.device;
        final on = state.isPowerOn;

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name),
                Text(
                  [device.brandName, if (device.room != null) device.room!].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                ),
              ],
            ),
            actions: [
              Center(child: IrPulse(pulse: _vm.sentCount, active: _vm.isSending)),
              PopupMenuButton<_MenuAction>(
                onSelected: _onMenu,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _MenuAction.resend, child: Text('Send again')),
                  PopupMenuItem(value: _MenuAction.rename, child: Text('Rename')),
                  PopupMenuItem(value: _MenuAction.delete, child: Text('Remove this AC')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TemperatureDial(
                  state: state,
                  minTemperature: caps.minTemperature,
                  maxTemperature: caps.maxTemperature,
                  onIncrease: _vm.canIncrease ? _vm.increaseTemperature : null,
                  onDecrease: _vm.canDecrease ? _vm.decreaseTemperature : null,
                ),
                const SizedBox(height: 12),
                _PowerButton(isOn: on, onPressed: _vm.togglePower),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: on ? 1 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !on,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionLabel('Mode'),
                        _ModeSelector(
                          modes: [for (final m in AcMode.values) if (caps.modes.contains(m)) m],
                          selected: state.mode,
                          onSelected: _vm.setMode,
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel('Fan speed'),
                        SegmentedButton<AcFanSpeed>(
                          showSelectedIcon: false,
                          segments: [
                            for (final speed in AcFanSpeed.values)
                              if (caps.fanSpeeds.contains(speed))
                                ButtonSegment(value: speed, label: Text(speed.label)),
                          ],
                          selected: {state.fanSpeed},
                          onSelectionChanged: (s) => _vm.setFanSpeed(s.first),
                        ),
                        if (caps.swingVertical || caps.swingHorizontal || caps.turbo) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel('Airflow'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (caps.swingVertical)
                                _ToggleChip(
                                  icon: Icons.swap_vert_rounded,
                                  label: 'Swing up/down',
                                  selected: state.swingVertical,
                                  onTap: _vm.toggleSwingVertical,
                                ),
                              if (caps.swingHorizontal)
                                _ToggleChip(
                                  icon: Icons.swap_horiz_rounded,
                                  label: 'Swing left/right',
                                  selected: state.swingHorizontal,
                                  onTap: _vm.toggleSwingHorizontal,
                                ),
                              if (caps.turbo)
                                _ToggleChip(
                                  icon: Icons.bolt_rounded,
                                  label: 'Turbo',
                                  selected: state.turbo,
                                  onTap: _vm.toggleTurbo,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Point the top of the phone at the AC. It usually beeps when it receives a command.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.resend:
        await _vm.resend();
      case _MenuAction.rename:
        final name = await showRenameDialog(context, current: _vm.device.name);
        if (name != null) await _vm.rename(name);
      case _MenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove ${_vm.device.name}?'),
            content: const Text('You can add it again any time with Find my AC.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _vm.delete();
          if (mounted) Navigator.of(context).pop();
        }
    }
  }
}

enum _MenuAction { resend, rename, delete }

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isOn ? AppColors.powerOff : AppColors.powerOn;
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.power_settings_new_rounded, size: 26),
        label: Text(isOn ? 'Turn off' : 'Turn on'),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.modes, required this.selected, required this.onSelected});

  final List<AcMode> modes;
  final AcMode selected;
  final ValueChanged<AcMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in modes)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _ModeTile(mode: mode, selected: mode == selected, onTap: () => onSelected(mode)),
            ),
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.selected, required this.onTap});

  final AcMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mode.color;
    return Semantics(
      selected: selected,
      button: true,
      label: '${mode.label} mode',
      child: Material(
        color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color : AppColors.surfaceBorder, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(mode.icon, color: selected ? color : AppColors.textSecondary),
                const SizedBox(height: 4),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? AppColors.background : AppColors.textSecondary),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.background : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.surfaceBorder),
      onSelected: (_) => onTap(),
    );
  }
}
