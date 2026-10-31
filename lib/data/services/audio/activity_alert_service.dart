import 'package:audioplayers/audioplayers.dart';

/// Plays the looping "target reached" chime until it is explicitly stopped.
///
/// The session controller owns the lifecycle: it starts the alert once when a
/// distance/step target is met, stops it when the user cancels the sound, and
/// always stops it when the session ends or is discarded.
class ActivityAlertService {
  ActivityAlertService();

  static const String _asset = 'sounds/activity_target.wav';

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start() async {
    if (_playing) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(_asset));
      _playing = true;
    } on Exception {
      _playing = false;
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } on Exception {
      // The player may already be released with the app lifecycle.
    }
  }

  Future<void> dispose() async {
    _playing = false;
    try {
      await _player.dispose();
    } on Exception {
      // Nothing else to release.
    }
  }
}
