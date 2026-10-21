import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum LiveVideoPhase { idle, connecting, playing, failed }

class LiveVideoState {
  const LiveVideoState(this.phase, {this.error, this.width, this.height});

  static const LiveVideoState idle = LiveVideoState(LiveVideoPhase.idle);

  final LiveVideoPhase phase;
  final String? error;
  final int? width;
  final int? height;
}

/// A live stream on screen. The app uses media_kit; tests use a fake.
abstract interface class LiveVideoPlayer {
  ValueListenable<LiveVideoState> get state;

  /// Starts playing [uri] (replacing what was playing).
  Future<void> open(Uri uri);

  Widget buildView();

  Future<void> dispose();
}

typedef LiveVideoPlayerFactory = LiveVideoPlayer Function();
