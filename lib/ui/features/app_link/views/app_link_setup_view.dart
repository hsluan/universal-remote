import 'package:flutter/material.dart';

import '../../../../domain/devices/device.dart';
import '../../../../domain/devices/vendor_apps.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/device_kind_style.dart';
import '../view_models/app_link_setup_view_model.dart';

/// Links a device to its maker's app. Pops with the saved [Device].
class AppLinkSetupView extends StatefulWidget {
  const AppLinkSetupView({super.key, required this.viewModel});

  final AppLinkSetupViewModel viewModel;

  @override
  State<AppLinkSetupView> createState() => _AppLinkSetupViewState();
}

class _AppLinkSetupViewState extends State<AppLinkSetupView> {
  final _nameController = TextEditingController();
  bool _saving = false;

  AppLinkSetupViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_syncName);
    _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_syncName);
    _vm.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Mirrors the suggested name into the field when the app selection changes it.
  void _syncName() {
    if (_nameController.text != _vm.name) {
      _nameController.value = TextEditingValue(
        text: _vm.name,
        selection: TextSelection.collapsed(offset: _vm.name.length),
      );
    }
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
        return Scaffold(
          appBar: AppBar(title: Text('${_vm.kind.label} shortcut')),
          body: SafeArea(
            child: _vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      const Text(
                        "Which app controls it?",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Some devices only answer their maker's app. The card on the home screen opens that app, "
                        'so everything stays in one place.',
                        style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      for (final app in _vm.apps)
                        _AppTile(
                          app: app,
                          installed: _vm.isInstalled(app),
                          selected: _vm.selected == app,
                          onSelect: () => _vm.select(app),
                          onInstall: () => _vm.install(app),
                        ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameController,
                        onChanged: _vm.setName,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final room in AppLinkSetupViewModel.roomSuggestions)
                            ChoiceChip(
                              label: Text(room),
                              selected: _vm.room == room,
                              onSelected: (selected) => _vm.setRoom(selected ? room : null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _vm.canSave && !_saving ? _save : null,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Add shortcut', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.installed,
    required this.selected,
    required this.onSelect,
    required this.onInstall,
  });

  final VendorApp app;
  final bool installed;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.selection : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.surfaceBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        installed ? 'Installed' : 'Not installed on this phone',
                        style: TextStyle(fontSize: 12, color: installed ? AppColors.success : AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!installed) TextButton(onPressed: onInstall, child: const Text('Get it')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
