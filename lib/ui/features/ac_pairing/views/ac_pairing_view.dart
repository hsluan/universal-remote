import 'package:flutter/material.dart';

import '../../../../domain/models/ac_brand.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ir_pulse.dart';
import '../view_models/ac_pairing_view_model.dart';

/// "Find my AC" wizard. Pops with the saved [AcDevice] when pairing succeeds.
class AcPairingView extends StatefulWidget {
  const AcPairingView({super.key, required this.viewModel});

  final AcPairingViewModel viewModel;

  @override
  State<AcPairingView> createState() => _AcPairingViewState();
}

class _AcPairingViewState extends State<AcPairingView> {
  AcPairingViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return PopScope(
          canPop: _vm.step == PairingStep.brand,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _vm.back();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_title(_vm.step)),
              actions: [
                if (_vm.step == PairingStep.testing || _vm.step == PairingStep.verify)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(child: IrPulse(pulse: _vm.sendCount, active: _vm.isSending)),
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _StepProgress(step: _vm.step),
                  if (_vm.error != null) _ErrorBanner(message: _vm.error!, onClose: _vm.clearError),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(key: ValueKey(_vm.step), child: _buildStep(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _title(PairingStep step) => switch (step) {
        PairingStep.brand => 'Find my AC',
        PairingStep.prepare => 'Get ready',
        PairingStep.testing => 'Testing codes',
        PairingStep.verify => 'Double-check',
        PairingStep.name => 'Name your AC',
        PairingStep.notFound => 'No match yet',
      };

  Widget _buildStep(BuildContext context) {
    if (_vm.isLoading) return const Center(child: CircularProgressIndicator());
    return switch (_vm.step) {
      PairingStep.brand => _BrandStep(vm: _vm),
      PairingStep.prepare => _PrepareStep(vm: _vm),
      PairingStep.testing => _TestingStep(vm: _vm),
      PairingStep.verify => _VerifyStep(vm: _vm),
      PairingStep.name => _NameStep(vm: _vm, onSaved: (device) => Navigator.of(context).pop(device)),
      PairingStep.notFound => _NotFoundStep(vm: _vm),
    };
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final PairingStep step;

  static const _order = [PairingStep.brand, PairingStep.prepare, PairingStep.testing, PairingStep.verify, PairingStep.name];

  @override
  Widget build(BuildContext context) {
    final index = step == PairingStep.notFound ? 2 : _order.indexOf(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < _order.length; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= index ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClose),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Brand step

class _BrandStep extends StatelessWidget {
  const _BrandStep({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final searching = vm.query.trim().isNotEmpty;
    final suggestions = vm.suggestedBrands;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Which brand is your air conditioner?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'The brand name is on the front of the indoor unit or on its remote.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: vm.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search brand',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        _UnknownBrandTile(onTap: vm.chooseUnknownBrand),
        const SizedBox(height: 20),
        if (!searching && suggestions.isNotEmpty) ...[
          const _Caption('Suggested for you'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              for (final brand in suggestions.take(9))
                _BrandTile(brand: brand, paired: vm.isPairedBrand(brand), onTap: () => vm.chooseBrand(brand)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _Caption(searching ? 'Results' : 'All brands'),
        for (final brand in vm.filteredBrands)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: _BrandAvatar(name: brand.name),
            title: Text(brand.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              brand.hasKnownCodes ? '${brand.codeIds.length} known code${brand.codeIds.length == 1 ? '' : 's'}' : 'Tries every code',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => vm.chooseBrand(brand),
          ),
        if (searching && vm.filteredBrands.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Not in the list? Choose "I don\'t know the brand" above: we will try every code.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _UnknownBrandTile extends StatelessWidget {
  const _UnknownBrandTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: AppColors.primary, size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("I don't know the brand", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      'Auto search tries every code until your AC answers.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.brand, required this.paired, required this.onTap});

  final AcBrand brand;
  final bool paired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: paired ? AppColors.success.withValues(alpha: 0.6) : AppColors.surfaceBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BrandAvatar(name: brand.name),
              const SizedBox(height: 8),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (paired)
                const Text('In your home', style: TextStyle(fontSize: 10, color: AppColors.success)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name});

  final String name;

  static const _palette = [
    AppColors.modeCool,
    AppColors.modeHeat,
    AppColors.modeDry,
    AppColors.modeAuto,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
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

// -------------------------------------------------------------- Prepare step

class _PrepareStep extends StatelessWidget {
  const _PrepareStep({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final brand = vm.brand;
    final total = vm.search?.total ?? 0;
    return _StepScaffold(
      icon: Icons.settings_remote_rounded,
      title: brand == null ? 'We will try all $total codes' : "Let's find your ${brand.name} code",
      subtitle: brand != null && brand.hasKnownCodes
          ? 'We start with the ${brand.codeIds.length} code${brand.codeIds.length == 1 ? '' : 's'} known for ${brand.name}, then try the others.'
          : 'Each code sends "Power on · Cool · 25°C". Most ACs beep when they understand it.',
      primary: FilledButton.icon(
        onPressed: vm.startTesting,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start testing'),
      ),
      children: const [
        _Tip(icon: Icons.near_me_rounded, text: 'Stand within 5 m and point the top edge of the phone at the indoor unit.'),
        _Tip(icon: Icons.power_settings_new_rounded, text: 'Turn the AC off first if you can, so you can see it turn on.'),
        _Tip(icon: Icons.hearing_rounded, text: 'Listen for a beep: it means the AC received the code.'),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.35))),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Testing step

class _TestingStep extends StatelessWidget {
  const _TestingStep({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final search = vm.search!;
    final candidate = search.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text(
              'Code ${search.position} of ${search.total}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            const Spacer(),
            if (search.isPreferred && vm.brand != null)
              Flexible(child: _Badge(text: 'Known for ${vm.brand!.name}', color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: search.position / search.total,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLight,
          ),
        ),
        const SizedBox(height: 24),
        _SendingCard(
          label: candidate.label,
          sending: vm.isSending,
          pulse: vm.sendCount,
          onSendAgain: vm.isSending ? null : vm.sendAgain,
        ),
        const SizedBox(height: 24),
        const Text(
          'Did the AC beep or turn on?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.background),
            onPressed: vm.answerYes,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Yes, it responded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: vm.isSending ? null : vm.answerNo,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('No, try the next code'),
          ),
        ),
        const SizedBox(height: 20),
        _AutoModeCard(vm: vm),
        if (vm.canGoBack)
          TextButton.icon(
            onPressed: vm.goBackOne,
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('It answered the previous code'),
          ),
      ],
    );
  }
}

class _SendingCard extends StatelessWidget {
  const _SendingCard({required this.label, required this.sending, required this.pulse, required this.onSendAgain});

  final String label;
  final bool sending;
  final int pulse;
  final VoidCallback? onSendAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sending ? AppColors.ledOn : AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          IrPulse(pulse: pulse, active: sending, size: 18),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            sending ? 'Sending Power on · Cool · 25°C…' : 'Sent Power on · Cool · 25°C',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onSendAgain,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Send again'),
          ),
        ],
      ),
    );
  }
}

class _AutoModeCard extends StatelessWidget {
  const _AutoModeCard({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: vm.autoMode ? AppColors.primary : AppColors.surfaceBorder),
      ),
      child: SwitchListTile(
        value: vm.autoMode,
        onChanged: vm.setAutoMode,
        title: const Text('Auto search', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          vm.autoMode
              ? 'Next code in ${vm.countdown}s. Tap "Yes" as soon as the AC beeps.'
              : 'Hands-free: send the next code every ${vm.autoInterval} seconds.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        secondary: vm.autoMode
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(value: vm.countdown / vm.autoInterval, strokeWidth: 3),
              )
            : const Icon(Icons.autorenew_rounded),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// --------------------------------------------------------------- Verify step

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final match = vm.search!.match!;
    if (!vm.verifySent) {
      return _StepScaffold(
        icon: Icons.verified_rounded,
        title: 'Great, ${match.label} answered!',
        subtitle: "Let's make sure it is really this code: we will send Power off with it.",
        primary: FilledButton.icon(
          onPressed: vm.isSending ? null : vm.sendVerifyOff,
          icon: const Icon(Icons.power_settings_new_rounded),
          label: const Text('Send Power off'),
        ),
        secondary: TextButton(onPressed: vm.verifyYes, child: const Text('Skip check')),
      );
    }
    return _StepScaffold(
      icon: Icons.power_off_rounded,
      title: 'Did the AC turn off?',
      subtitle: 'If it beeped and stopped, this is your code.',
      primary: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.background),
        onPressed: vm.verifyYes,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('Yes, it turned off'),
      ),
      secondary: OutlinedButton(onPressed: vm.verifyNo, child: const Text('No, keep searching')),
      tertiary: TextButton.icon(
        onPressed: vm.isSending ? null : vm.sendVerifyOff,
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Send again'),
      ),
    );
  }
}

// ----------------------------------------------------------------- Name step

class _NameStep extends StatefulWidget {
  const _NameStep({required this.vm, required this.onSaved});

  final AcPairingViewModel vm;
  final ValueChanged<AcDevice> onSaved;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _name = TextEditingController(text: widget.vm.name);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final device = await widget.vm.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (device != null) widget.onSaved(device);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Icon(Icons.celebration_rounded, size: 48, color: AppColors.success),
        const SizedBox(height: 12),
        Text(
          'Found it: ${vm.detectedBrandName}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          onChanged: vm.setName,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        const _Caption('Room (optional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final room in AcPairingViewModel.roomSuggestions)
              ChoiceChip(
                label: Text(room),
                selected: vm.room == room,
                onSelected: (selected) => vm.setRoom(selected ? room : null),
              ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: vm.canSave && !_saving ? _save : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save and open remote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Not found step

class _NotFoundStep extends StatelessWidget {
  const _NotFoundStep({required this.vm});

  final AcPairingViewModel vm;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.search_off_rounded,
      title: 'Your AC did not answer any code',
      subtitle: 'This usually means the phone was too far, or the AC uses a code the app does not have yet.',
      primary: FilledButton.icon(
        onPressed: vm.startTesting,
        icon: const Icon(Icons.replay_rounded),
        label: const Text('Try all codes again'),
      ),
      secondary: TextButton(onPressed: vm.restart, child: const Text('Choose another brand')),
      children: const [
        _Tip(icon: Icons.near_me_rounded, text: 'Move closer (2–3 m) and aim straight at the indoor unit.'),
        _Tip(icon: Icons.volume_up_rounded, text: 'Some ACs beep quietly; watch the indoor unit display too.'),
        _Tip(icon: Icons.settings_remote_rounded, text: 'Check the original remote for a model number, it helps to add your code later.'),
      ],
    );
  }
}

// ------------------------------------------------------------------- Shared

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget primary;
  final Widget? secondary;
  final Widget? tertiary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 44, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        if (children.isNotEmpty) ...[const SizedBox(height: 20), ...children],
        const SizedBox(height: 28),
        SizedBox(height: 56, child: primary),
        if (secondary != null) ...[const SizedBox(height: 10), SizedBox(height: 48, child: secondary)],
        if (tertiary != null) ...[const SizedBox(height: 4), tertiary!],
      ],
    );
  }
}
