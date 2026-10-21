import 'package:flutter/material.dart';

import '../../../../domain/cameras/camera_brand.dart';
import '../../../../domain/devices/device.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/camera_setup_view_model.dart';

/// Adds an IP camera. Pops with the saved [Device].
class CameraSetupView extends StatefulWidget {
  const CameraSetupView({super.key, required this.viewModel});

  final CameraSetupViewModel viewModel;

  @override
  State<CameraSetupView> createState() => _CameraSetupViewState();
}

class _CameraSetupViewState extends State<CameraSetupView> {
  CameraSetupViewModel get _vm => widget.viewModel;
  bool _saving = false;

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final device = await _vm.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (device != null) Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return PopScope(
          canPop: _vm.step == CameraSetupStep.brand,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _vm.back();
          },
          child: Scaffold(
            appBar: AppBar(title: Text(_vm.step == CameraSetupStep.brand ? 'Add a camera' : _vm.brand.label)),
            body: SafeArea(
              child: switch (_vm.step) {
                CameraSetupStep.brand => _BrandStep(vm: _vm),
                CameraSetupStep.connect => _ConnectStep(vm: _vm, saving: _saving, onSave: _save),
              },
            ),
          ),
        );
      },
    );
  }
}

class _BrandStep extends StatelessWidget {
  const _BrandStep({required this.vm});

  final CameraSetupViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Which camera?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Live view and pan/tilt over your Wi-Fi, without the maker\'s cloud. Xiaomi cameras have no local '
          'stream: add them as a shortcut to Xiaomi Home instead.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 16),
        for (final brand in CameraBrand.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.videocam_rounded, color: AppColors.primary),
                title: Text(brand.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => vm.chooseBrand(brand),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConnectStep extends StatelessWidget {
  const _ConnectStep({required this.vm, required this.saving, required this.onSave});

  final CameraSetupViewModel vm;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final brand = vm.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HintCard(text: brand.passwordHint),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: vm.searching ? null : vm.search,
          icon: vm.searching
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.wifi_find_rounded),
          label: Text(vm.searching ? 'Searching your Wi-Fi…' : 'Find cameras on my Wi-Fi'),
        ),
        for (final camera in vm.found)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
              vm.host == camera.host ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: AppColors.primary,
            ),
            title: Text(camera.host),
            subtitle: camera.label.isEmpty ? null : Text(camera.label, style: const TextStyle(fontSize: 12)),
            onTap: () => vm.pick(camera),
          ),
        if (vm.searched && !vm.searching && vm.found.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No camera answered the ONVIF search. Some cameras keep ONVIF off: type the address from the '
              "camera's app or your router instead.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 16),
        _Field(
          label: 'Camera address (IP)',
          value: vm.host,
          hint: '192.168.1.20',
          keyboard: TextInputType.url,
          onChanged: vm.setHost,
        ),
        _Field(label: 'User', value: vm.user, onChanged: vm.setUser),
        _Field(label: 'Password', value: vm.password, obscure: true, onChanged: vm.setPassword),
        if (brand == CameraBrand.other)
          _Field(label: 'Stream path', value: vm.customPath, hint: '/live/ch0', onChanged: vm.setCustomPath),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ports', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            children: [
              _Field(label: 'RTSP port', value: '${vm.rtspPort}', keyboard: TextInputType.number, onChanged: vm.setRtspPort),
              _Field(label: 'ONVIF port', value: '${vm.onvifPort}', keyboard: TextInputType.number, onChanged: vm.setOnvifPort),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: vm.canTest ? vm.test : null,
            icon: vm.testStatus == CameraTestStatus.testing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check_rounded),
            label: Text(vm.testStatus == CameraTestStatus.testing ? 'Testing…' : 'Test connection'),
          ),
        ),
        if (vm.testStatus == CameraTestStatus.failed && vm.testMessage != null) ...[
          const SizedBox(height: 12),
          _ResultCard(ok: false, text: vm.testMessage!),
        ],
        if (vm.testStatus == CameraTestStatus.passed) ...[
          const SizedBox(height: 12),
          _ResultCard(
            ok: true,
            text: [
              'Connected',
              if (vm.videoCodec != null) vm.videoCodec!.replaceFirst('H26', 'H.26'),
              vm.hasSubStream ? 'small stream available' : 'one stream',
              vm.ptzSupported ? 'pan/tilt available' : 'no pan/tilt over ONVIF',
            ].join(' · '),
          ),
          const SizedBox(height: 20),
          _Field(label: 'Name', value: vm.name, onChanged: vm.setName),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final room in CameraSetupViewModel.roomSuggestions)
                ChoiceChip(
                  label: Text(room),
                  selected: vm.room == room,
                  onSelected: (selected) => vm.setRoom(selected ? room : null),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: vm.canSave && !saving ? onSave : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save camera', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    );
  }
}

/// A text field that owns its controller and keeps it in sync with [value]
/// (e.g. when a found camera fills in the address).
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.obscure = false,
    this.keyboard,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  late bool _hidden = widget.obscure;

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: !widget.obscure,
        keyboardType: widget.keyboard,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
