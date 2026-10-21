import 'package:flutter/material.dart';

import '../../../../domain/cameras/camera_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/video/live_video_player.dart';
import '../view_models/camera_view_model.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.viewModel, this.onOpenMakerApp});

  final CameraViewModel viewModel;

  /// Opens the camera maker's app (recordings, settings); `null` hides the link.
  final VoidCallback? onOpenMakerApp;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraViewModel get _vm => widget.viewModel;

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
        final camera = _vm.camera;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(camera.name),
                Text(
                  [camera.brand.label, if (camera.room != null) camera.room!].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                ),
              ],
            ),
            actions: [
              if (_vm.hasSubStream)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(_vm.highQuality ? 'HD' : 'SD'),
                    selected: _vm.highQuality,
                    tooltip: _vm.highQuality ? 'Full resolution' : 'Small stream (faster on this phone)',
                    onSelected: (_) => _vm.toggleQuality(),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: _VideoArea(vm: _vm)),
                if (_vm.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(_vm.message!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                const SizedBox(height: 20),
                if (_vm.canPan)
                  _PanTiltPad(moving: _vm.moving, onStart: _vm.startMove, onStop: _vm.stopMove)
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Pan/tilt isn't available for this camera over ONVIF.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                if (widget.onOpenMakerApp != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: widget.onOpenMakerApp,
                      icon: const Icon(Icons.launch_rounded, size: 18),
                      label: Text('Recordings and settings: open ${camera.brand.label}'),
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

class _VideoArea extends StatelessWidget {
  const _VideoArea({required this.vm});

  final CameraViewModel vm;

  @override
  Widget build(BuildContext context) {
    final video = vm.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        vm.player.buildView(),
        if (video.phase == LiveVideoPhase.connecting || video.phase == LiveVideoPhase.idle)
          const Center(child: CircularProgressIndicator()),
        if (video.phase == LiveVideoPhase.failed)
          ColoredBox(
            color: Colors.black87,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded, color: AppColors.textMuted, size: 36),
                    const SizedBox(height: 8),
                    const Text("Can't play the stream", style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      video.error ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: vm.retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Four arrows; a camera moves while an arrow is held and stops on release.
class _PanTiltPad extends StatelessWidget {
  const _PanTiltPad({required this.moving, required this.onStart, required this.onStop});

  final PtzDirection? moving;
  final ValueChanged<PtzDirection> onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    Widget arrow(PtzDirection direction, IconData icon, String label) {
      final active = moving == direction;
      return Semantics(
        button: true,
        label: 'Turn $label',
        child: Listener(
          onPointerDown: (_) => onStart(direction),
          onPointerUp: (_) => onStop(),
          onPointerCancel: (_) => onStop(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withValues(alpha: 0.25) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? AppColors.primary : AppColors.surfaceBorder),
            ),
            child: Icon(icon, size: 32, color: active ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text('Hold to turn', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        arrow(PtzDirection.up, Icons.keyboard_arrow_up_rounded, 'up'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            arrow(PtzDirection.left, Icons.keyboard_arrow_left_rounded, 'left'),
            const SizedBox(width: 72),
            arrow(PtzDirection.right, Icons.keyboard_arrow_right_rounded, 'right'),
          ],
        ),
        const SizedBox(height: 8),
        arrow(PtzDirection.down, Icons.keyboard_arrow_down_rounded, 'down'),
      ],
    );
  }
}
