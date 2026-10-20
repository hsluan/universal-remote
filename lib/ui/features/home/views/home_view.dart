import 'package:flutter/material.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../core/theme/ac_style.dart';
import '../../../core/theme/app_colors.dart';
import '../../ac_pairing/views/ac_pairing_view.dart';
import '../../ac_remote/views/ac_remote_view.dart';
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

  Future<void> _addAc() async {
    final device = await Navigator.of(context).push<AcDevice>(
      MaterialPageRoute(builder: (_) => AcPairingView(viewModel: widget.dependencies.createPairingViewModel())),
    );
    await _vm.refresh();
    if (device != null && mounted) await _openRemote(device);
  }

  Future<void> _openRemote(AcDevice device) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AcRemoteView(viewModel: widget.dependencies.createRemoteViewModel(device))),
    );
    await _vm.refresh();
  }

  void _openDiagnostics() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DiagnosticsView(viewModel: widget.dependencies.createDiagnosticsViewModel())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final devices = _vm.devices;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text('My remotes'),
            actions: [
              PopupMenuButton<void>(
                itemBuilder: (context) => [
                  PopupMenuItem(onTap: _openDiagnostics, child: const Text('IR diagnostics')),
                ],
              ),
            ],
          ),
          floatingActionButton: devices.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addAc,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add AC'),
                ),
          body: SafeArea(
            child: _vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (_vm.hasEmitter == false) const _NoIrBanner(),
                      if (devices.isEmpty)
                        _EmptyState(onFind: _addAc)
                      else ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                          child: Text(
                            'AIR CONDITIONERS',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        for (final device in devices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AcCard(
                              device: device,
                              sending: _vm.isSending(device),
                              onOpen: () => _openRemote(device),
                              onPower: () => _vm.togglePower(device),
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
              'No IR blaster found on this phone. You can look around, but commands will not reach the AC.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onFind});

  final VoidCallback onFind;

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
            child: const Icon(Icons.ac_unit_rounded, size: 64, color: AppColors.modeCool),
          ),
          const SizedBox(height: 24),
          const Text(
            'Control your air conditioner',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick the brand, or let auto search try every code. It takes about a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: onFind,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Find my AC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcCard extends StatelessWidget {
  const _AcCard({required this.device, required this.sending, required this.onOpen, required this.onPower});

  final AcDevice device;
  final bool sending;
  final VoidCallback onOpen;
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    final state = device.state;
    final on = state.isPowerOn;
    final color = on ? state.mode.color : AppColors.textMuted;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: on ? color.withValues(alpha: 0.5) : AppColors.surfaceBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(on ? state.mode.icon : Icons.ac_unit_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [if (device.room != null) device.room!, state.summary].join(' · '),
                      style: TextStyle(fontSize: 13, color: on ? AppColors.textSecondary : AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: on ? 'Turn off' : 'Turn on',
                iconSize: 28,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: (on ? AppColors.powerOn : AppColors.surfaceLight).withValues(alpha: on ? 0.15 : 1),
                  foregroundColor: on ? AppColors.powerOn : AppColors.textSecondary,
                ),
                onPressed: sending ? null : onPower,
                icon: sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.power_settings_new_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
