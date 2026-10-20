import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/diagnostics_view_model.dart';

class DiagnosticsView extends StatefulWidget {
  const DiagnosticsView({super.key, required this.viewModel});

  final DiagnosticsViewModel viewModel;

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  final _addressController = TextEditingController(text: '04');
  final _commandController = TextEditingController(text: '08');

  @override
  void initState() {
    super.initState();
    widget.viewModel.checkHardware();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final status = vm.status;
        final hasEmitter = status?.hasEmitter ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('IR Hardware Diagnostics'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Re-scan Hardware',
                onPressed: vm.isLoading ? null : vm.checkHardware,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Simulated IR LED Indicator
                _buildLedIndicator(vm.isTransmitting),
                const SizedBox(height: 20),

                // Hardware Status Card
                _buildStatusCard(vm, status, hasEmitter),
                const SizedBox(height: 16),

                // Quick Test Presets Card
                _buildPresetsCard(vm, hasEmitter),
                const SizedBox(height: 16),

                // Custom NEC Signal Generator
                _buildCustomNecCard(vm, hasEmitter),
                const SizedBox(height: 16),

                // Activity Logs
                _buildLogsCard(vm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLedIndicator(bool isTransmitting) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTransmitting ? AppColors.ledOn : AppColors.surfaceBorder,
          width: isTransmitting ? 2 : 1,
        ),
        boxShadow: isTransmitting
            ? [
                BoxShadow(
                  color: AppColors.ledGlow,
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTransmitting ? AppColors.ledOn : AppColors.ledOff,
              boxShadow: isTransmitting
                  ? [
                      const BoxShadow(
                        color: AppColors.ledOn,
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isTransmitting ? 'TRANSMITTING IR BURST...' : 'IR BLASTER IDLE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isTransmitting ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(DiagnosticsViewModel vm, dynamic status, bool hasEmitter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasEmitter ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: hasEmitter ? AppColors.success : AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasEmitter ? 'Consumer IR Emitter Active' : 'No IR Emitter Detected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (vm.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasEmitter
                  ? 'Redmi 4X ConsumerIrManager API is bound and ready to emit modulated pulses.'
                  : 'Your device does not report a consumer IR emitter or you are running on an emulator.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (hasEmitter && status != null && status.frequencies.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.surfaceBorder),
              const Text(
                'Supported Carrier Frequencies:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final range in status.frequencies)
                    Chip(
                      label: Text(range.toString()),
                      backgroundColor: AppColors.surfaceLight,
                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      side: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsCard(DiagnosticsViewModel vm, bool hasEmitter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Verification Presets (NEC 38 kHz)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Point the top edge of your Redmi 4X toward the target appliance:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.tv, size: 18),
                    label: const Text('Samsung TV Power'),
                    onPressed: (!hasEmitter || vm.isTransmitting)
                        ? null
                        : () => vm.transmitSamsungPower(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.tv, size: 18),
                    label: const Text('LG TV Power'),
                    onPressed: (!hasEmitter || vm.isTransmitting)
                        ? null
                        : () => vm.transmitLgPower(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNecCard(DiagnosticsViewModel vm, bool hasEmitter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom NEC Code Generator',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Transmit custom 8-bit Address & Command (hex format, e.g. 04 and 08):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Addr (Hex)',
                      prefixText: '0x',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      labelText: 'Cmd (Hex)',
                      prefixText: '0x',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (!hasEmitter || vm.isTransmitting)
                      ? null
                      : () {
                          final addr = int.tryParse(_addressController.text.trim(), radix: 16);
                          final cmd = int.tryParse(_commandController.text.trim(), radix: 16);
                          if (addr != null && cmd != null) {
                            vm.transmitCustomNec(address: addr, command: cmd);
                          }
                        },
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard(DiagnosticsViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hardware & Signal Logs',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (vm.logs.isNotEmpty)
                  TextButton(
                    onPressed: vm.clearLogs,
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: vm.logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No events recorded yet.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: vm.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            vm.logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
