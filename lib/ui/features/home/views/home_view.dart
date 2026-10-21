import 'package:flutter/material.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/devices/device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/device_kind_style.dart';
import '../../../core/widgets/rename_dialog.dart';
import '../../../devices/device_module.dart';
import '../../add_device/views/add_device_view.dart';
import '../../diagnostics/views/diagnostics_view.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _vm = widget.dependencies.createHomeViewModel();
  String? _shownError;

  DeviceModules get _modules => widget.dependencies.deviceModules;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onViewModelChanged);
    _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    final error = _vm.error;
    if (error != null && error != _shownError && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
    _shownError = error;
  }

  Future<void> _addDevice() async {
    final device = await Navigator.of(context).push<Device>(
      MaterialPageRoute(builder: (_) => AddDeviceView(modules: _modules)),
    );
    await _vm.refresh();
    if (device != null && mounted && (_modules.moduleFor(device)?.opensWhenAdded ?? false)) await _open(device);
  }

  Future<void> _open(Device device) async {
    final module = _modules.moduleFor(device);
    if (module == null) return;
    await module.open(context, device);
    await _vm.refresh();
  }

  void _openDiagnostics() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DiagnosticsView(viewModel: widget.dependencies.createDiagnosticsViewModel())),
    );
  }

  Future<void> _showActions(Device device) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700))),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, _CardAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Remove'),
              onTap: () => Navigator.pop(context, _CardAction.remove),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _CardAction.rename:
        final name = await showRenameDialog(context, current: device.name);
        if (name != null) await _vm.rename(device, name);
      case _CardAction.remove:
        await _vm.remove(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final sections = _vm.sections;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text('My home'),
            actions: [
              PopupMenuButton<void>(
                itemBuilder: (context) => [
                  PopupMenuItem(onTap: _openDiagnostics, child: const Text('IR diagnostics')),
                ],
              ),
            ],
          ),
          floatingActionButton: sections.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add device'),
                ),
          body: SafeArea(
            child: _vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (_vm.hasEmitter == false && _vm.hasIrDevices) const _NoIrBanner(),
                      if (sections.isEmpty)
                        _EmptyState(onAdd: _addDevice)
                      else
                        for (final (kind, devices) in sections) ...[
                          _SectionHeader(kind.pluralLabel),
                          for (final device in devices)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DeviceCard(
                                device: device,
                                info: _modules.moduleFor(device)!.cardInfo(device),
                                canToggle: _vm.canToggle(device),
                                sending: _vm.isSending(device),
                                onOpen: () => _open(device),
                                onToggle: () => _vm.togglePower(device),
                                onLongPress: () => _showActions(device),
                              ),
                            ),
                        ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

enum _CardAction { rename, remove }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }
}

class _NoIrBanner extends StatelessWidget {
  const _NoIrBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors_off_rounded, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No IR blaster found on this phone: IR devices cannot be controlled from it. '
              "Shortcuts to makers' apps still work.",
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.modeCool.withValues(alpha: 0.35), AppColors.modeCool.withValues(alpha: 0.02)],
              ),
            ),
            child: const Icon(Icons.home_rounded, size: 64, color: AppColors.modeCool),
          ),
          const SizedBox(height: 24),
          const Text(
            'Control everything at home',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Air conditioners with an IR remote work right away. Devices that only their maker's app "
            'controls can be added as shortcuts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.info,
    required this.canToggle,
    required this.sending,
    required this.onOpen,
    required this.onToggle,
    required this.onLongPress,
  });

  final Device device;
  final DeviceCardInfo info;
  final bool canToggle;
  final bool sending;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final on = info.isOn ?? false;
    final color = info.accent;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: on ? color.withValues(alpha: 0.5) : AppColors.surfaceBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(info.icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [if (device.room != null) device.room!, info.summary].join(' · '),
                      style: TextStyle(fontSize: 13, color: on ? AppColors.textSecondary : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (canToggle)
                IconButton(
                  tooltip: on ? 'Turn off' : 'Turn on',
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    backgroundColor: (on ? AppColors.powerOn : AppColors.surfaceLight).withValues(alpha: on ? 0.15 : 1),
                    foregroundColor: on ? AppColors.powerOn : AppColors.textSecondary,
                  ),
                  onPressed: sending ? null : onToggle,
                  icon: sending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.power_settings_new_rounded),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
