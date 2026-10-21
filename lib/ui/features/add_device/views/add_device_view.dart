import 'package:flutter/material.dart';

import '../../../../domain/devices/device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/device_kind_style.dart';
import '../../../devices/device_module.dart';
import '../setup_guides.dart';

/// Step 1 of adding a device: what kind of thing. Pops with the added [Device].
class AddDeviceView extends StatelessWidget {
  const AddDeviceView({super.key, required this.modules});

  final DeviceModules modules;

  Future<void> _openKind(BuildContext context, DeviceKind kind) async {
    final device = await Navigator.of(context).push<Device>(
      MaterialPageRoute(builder: (_) => AddDeviceKindView(kind: kind, modules: modules)),
    );
    if (device != null && context.mounted) Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a device')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text('What do you want to control?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // A fixed height with headroom for large system font sizes.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 128,
              ),
              children: [
                for (final kind in DeviceKind.values)
                  _KindTile(
                    kind: kind,
                    support: _supportOf(modules.addOptionsFor(kind)),
                    onTap: () => _openKind(context, kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How far the app supports a kind of device today.
enum _Support { direct, shortcut, guideOnly }

_Support _supportOf(List<AddDeviceOption> options) {
  if (options.any((o) => o.controlsDirectly)) return _Support.direct;
  return options.isEmpty ? _Support.guideOnly : _Support.shortcut;
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind, required this.support, required this.onTap});

  final DeviceKind kind;
  final _Support support;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(kind.icon, color: support == _Support.direct ? AppColors.primary : AppColors.textMuted, size: 30),
              const Spacer(),
              Text(
                kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                switch (support) {
                  _Support.direct => 'Ready to add',
                  _Support.shortcut => "Via the maker's app",
                  _Support.guideOnly => 'How to set it up',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: support == _Support.direct ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 2: the ways to add one kind of device, and what to buy when it needs add-on hardware.
class AddDeviceKindView extends StatelessWidget {
  const AddDeviceKindView({super.key, required this.kind, required this.modules});

  final DeviceKind kind;
  final DeviceModules modules;

  Future<void> _start(BuildContext context, AddDeviceOption option) async {
    final device = await option.start(context);
    if (device != null && context.mounted) Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    final options = modules.addOptionsFor(kind);
    final guide = setupGuides[kind];
    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (options.isNotEmpty) ...[
              const _Caption('Add it'),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(option: option, onTap: () => _start(context, option)),
                ),
              const SizedBox(height: 12),
            ],
            if (guide != null) _GuideCard(guide: guide),
            if (options.isEmpty && guide == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'Not supported yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.onTap});

  final AddDeviceOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(option.icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(option.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final SetupGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text('What you need', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(guide.intro, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          for (final point in guide.points) ...[
            const Divider(height: 24, color: AppColors.surfaceBorder),
            Row(
              children: [
                Expanded(
                  child: Text(point.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (point.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      point.tag!,
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(point.detail, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }
}
