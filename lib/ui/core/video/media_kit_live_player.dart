import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'live_video_player.dart';

/// [LiveVideoPlayer] on media_kit (libmpv), tuned for camera streams: mpv's
/// low-latency profile, RTSP over TCP (no lost UDP packets on Wi-Fi), no demuxer
/// cache, and hardware decoding.
class MediaKitLivePlayer implements LiveVideoPlayer {
  MediaKitLivePlayer()
      : _player = Player(
          configuration: const PlayerConfiguration(
            protocolWhitelist: ['rtsp', 'udp', 'rtp', 'tcp', 'tls', 'data', 'file', 'http', 'https', 'crypto'],
          ),
        ) {
    _controller = VideoController(_player);
    _subscriptions = [
      _player.stream.width.listen((width) {
        if ((width ?? 0) > 0) {
          _state.value = LiveVideoState(LiveVideoPhase.playing, width: width, height: _player.state.height);
        }
      }),
      _player.stream.error.listen((error) {
        _state.value = LiveVideoState(LiveVideoPhase.failed, error: error);
      }),
    ];
  }

  final Player _player;
  late final VideoController _controller;
  late final List<StreamSubscription<Object?>> _subscriptions;
  final ValueNotifier<LiveVideoState> _state = ValueNotifier(LiveVideoState.idle);

  @override
  ValueListenable<LiveVideoState> get state => _state;

  @override
  Future<void> open(Uri uri) async {
    _state.value = const LiveVideoState(LiveVideoPhase.connecting);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('profile', 'low-latency');
      await platform.setProperty('rtsp-transport', 'tcp');
      await platform.setProperty('cache', 'no');
    }
    await _player.open(Media(uri.toString()));
  }

  @override
  Widget buildView() => Video(controller: _controller, controls: NoVideoControls, fill: Colors.black);

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _state.dispose();
    await _player.dispose();
  }
}
