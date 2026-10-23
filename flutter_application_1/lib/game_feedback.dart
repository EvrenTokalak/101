part of 'game.dart';

/// Shared audio and haptics; gameplay and rendering do not own playback.
extension _GameFeedback on _GameScreenState {
  void _playInteractionFeedback({
    bool strong = false,
    bool haptic = true,
    bool placement = false,
    _GameSound sound = _GameSound.place,
  }) {
    if (_gameSettings.sound) {
      final now = _soundClock.elapsedMicroseconds;
      final minimumGap = sound == _GameSound.warning
          ? 350000
          : sound == _GameSound.pick
          ? 55000
          : 80000;
      final shouldPlay =
          now - (_lastSoundMicros[sound] ?? -minimumGap) >= minimumGap;
      if (shouldPlay) _lastSoundMicros[sound] = now;
      final Source source = switch (sound) {
        _GameSound.pick => AssetSource('sounds/tile_pick.wav'),
        _GameSound.place => AssetSource('sounds/tile_place.wav'),
        _GameSound.arrange => AssetSource('sounds/tile_arrange.wav'),
        _GameSound.warning => BytesSource(_buildWarningWav()),
      };
      if (shouldPlay) {
        final serial = ++_soundSerial;
        unawaited(() async {
          try {
            await _soundPlayer.stop();
            if (!mounted || serial != _soundSerial) return;
            await _soundPlayer.play(
              source,
              volume: sound == _GameSound.warning
                  ? 0.72
                  : strong
                  ? 0.78
                  : 0.62,
              mode: PlayerMode.lowLatency,
            );
          } catch (_) {
            // Ses desteği olmayan test ortamlarında oyun akışını sürdür.
          }
        }());
      }
    }
    final now = _soundClock.elapsedMicroseconds;
    if (haptic &&
        _gameSettings.vibration &&
        now - _lastHapticMicros >= (placement ? 60000 : 150000)) {
      _lastHapticMicros = now;
      final feedback = strong || sound == _GameSound.warning
          ? HapticFeedback.mediumImpact()
          : placement
          ? HapticFeedback.lightImpact()
          : HapticFeedback.selectionClick();
      unawaited(feedback.catchError((Object _) {}));
    }
  }

  void _playApplause() {
    if (!_gameSettings.sound) return;
    final serial = ++_soundSerial;
    unawaited(() async {
      try {
        await _soundPlayer.stop();
        if (!mounted || serial != _soundSerial) return;
        await _soundPlayer.play(
          BytesSource(_buildApplauseWav()),
          volume: 0.88,
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {
        // Ses çıkışı olmayan test ortamlarında kutlama görseli devam eder.
      }
    }());
  }
}

Uint8List? _applauseWavCache;

Uint8List _buildApplauseWav() {
  final cached = _applauseWavCache;
  if (cached != null) return cached;
  const sampleRate = 16000;
  const seconds = 1.35;
  final sampleCount = (sampleRate * seconds).round();
  final pcmBytes = sampleCount * 2;
  final data = ByteData(44 + pcmBytes);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcmBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcmBytes, Endian.little);

  final random = Random(101);
  const clapStarts = <double>[0.02, 0.12, 0.25, 0.39, 0.55, 0.72, 0.90, 1.08];
  for (var index = 0; index < sampleCount; index++) {
    final time = index / sampleRate;
    var sample = (random.nextDouble() * 2 - 1) * 0.025;
    for (final start in clapStarts) {
      final elapsed = time - start;
      if (elapsed >= 0 && elapsed < 0.12) {
        final envelope = exp(-elapsed * 33) * (1 - elapsed / 0.12);
        final noise = random.nextDouble() * 2 - 1;
        sample += noise * envelope * 0.72;
      }
    }
    final crowdEnvelope = sin(min(1, time / seconds) * pi);
    sample += (random.nextDouble() * 2 - 1) * crowdEnvelope * 0.06;
    data.setInt16(
      44 + index * 2,
      (sample.clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return _applauseWavCache = data.buffer.asUint8List();
}

Uint8List? _warningWavCache;

/// A quiet descending cue, generated once without adding an audio asset.
Uint8List _buildWarningWav() {
  if (_warningWavCache case final cached?) return cached;
  const rate = 16000, count = 1920;
  final bytes = ByteData(44 + count * 2);
  void text(int start, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(start + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    final envelope = sin(pi * i / count) * .35;
    final phase = 2 * pi * (330 * t - 450 * t * t);
    bytes.setInt16(
      44 + i * 2,
      (sin(phase) * envelope * 32767).round(),
      Endian.little,
    );
  }
  return _warningWavCache = bytes.buffer.asUint8List();
}
