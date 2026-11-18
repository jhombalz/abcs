import 'package:audioplayers/audioplayers.dart';

/// Created lazily after the player opts in. A failed cue never blocks gameplay.
class GameSounds {
  AudioPlayer? _player;
  bool _disposed = false;
  int _generation = 0;

  Future<void> play(String cue) async {
    if (_disposed) return;
    final generation = ++_generation;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      if (_disposed || generation != _generation) return;
      await player.play(AssetSource('audio/$cue.wav'), volume: 0.45);
    } catch (_) {
      // Browser autoplay/device audio restrictions must not interrupt a match.
    }
  }

  Future<void> mute() async {
    _generation++;
    try {
      await _player?.stop();
    } catch (_) {
      /* Audio is optional. */
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _player?.dispose();
  }
}
