import 'dart:async';
import 'dart:typed_data';

/// Mixes multiple raw 16-bit mono PCM streams (same sample rate) into a single
/// stream suitable for the Gemini Live realtime input.
///
/// A single source is passed through untouched to keep latency low. With two or
/// more sources, samples are summed and clamped on a fixed frame cadence, so
/// system audio and microphone input can be transcribed together.
class PcmMixer {
  PcmMixer({
    this.sampleRate = 16000,
    this.frameDuration = const Duration(milliseconds: 100),
  });

  /// Sample rate shared by every source, in Hz.
  final int sampleRate;

  /// How often a mixed frame is emitted.
  final Duration frameDuration;

  /// Mixes [sources] into one PCM byte stream.
  Stream<Uint8List> mixStreams(List<Stream<Uint8List>> sources) {
    if (sources.isEmpty) return Stream<Uint8List>.empty();
    if (sources.length == 1) return sources.first;

    late StreamController<Uint8List> controller;
    final buffers = List<List<int>>.generate(sources.length, (_) => <int>[]);
    final subscriptions = <StreamSubscription<Uint8List>>[];
    Timer? timer;

    final frameSamples =
        (sampleRate * frameDuration.inMilliseconds / 1000).round();
    final frameBytes = frameSamples * 2;
    final maxBufferBytes = sampleRate * 2 * 5;

    void flush() {
      var hasData = false;
      for (final buffer in buffers) {
        if (buffer.length >= 2) {
          hasData = true;
          break;
        }
      }
      if (!hasData) return;

      final output = List<int>.filled(frameBytes, 0);
      for (final buffer in buffers) {
        final availableSamples = buffer.length ~/ 2;
        final take =
            availableSamples < frameSamples ? availableSamples : frameSamples;
        for (var i = 0; i < take; i++) {
          final sample = _readInt16(buffer, i * 2);
          final mixed = _readInt16(output, i * 2) + sample;
          _writeInt16(output, i * 2, mixed);
        }
        if (take > 0) {
          buffer.removeRange(0, take * 2);
        }
      }

      if (!controller.isClosed) {
        controller.add(Uint8List.fromList(output));
      }
    }

    void onData(int index, Uint8List data) {
      final buffer = buffers[index];
      buffer.addAll(data);
      if (buffer.length > maxBufferBytes) {
        buffer.removeRange(0, buffer.length - maxBufferBytes);
      }
    }

    controller = StreamController<Uint8List>(
      onListen: () {
        for (var i = 0; i < sources.length; i++) {
          subscriptions.add(
            sources[i].listen(
              (data) => onData(i, data),
              onError: controller.addError,
              cancelOnError: false,
            ),
          );
        }
        timer = Timer.periodic(frameDuration, (_) => flush());
      },
      onCancel: () async {
        timer?.cancel();
        timer = null;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  int _readInt16(List<int> bytes, int offset) {
    final value = (bytes[offset] & 0xFF) | ((bytes[offset + 1] & 0xFF) << 8);
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  void _writeInt16(List<int> bytes, int offset, int value) {
    final clamped = value < -32768 ? -32768 : (value > 32767 ? 32767 : value);
    bytes[offset] = clamped & 0xFF;
    bytes[offset + 1] = (clamped >> 8) & 0xFF;
  }
}
