import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:poly_cript/services/audio_mixer.dart';

Uint8List _pcm(int sampleCount, int value) {
  final bytes = Uint8List(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    bytes[i * 2] = value & 0xFF;
    bytes[i * 2 + 1] = (value >> 8) & 0xFF;
  }
  return bytes;
}

int _sampleAt(Uint8List bytes, int index) {
  final value = (bytes[index * 2] & 0xFF) | ((bytes[index * 2 + 1] & 0xFF) << 8);
  return value >= 0x8000 ? value - 0x10000 : value;
}

void main() {
  group('resampleSystemAudio', () {
    test('downsamples 48 kHz chunks to 16 kHz', () async {
      final input = _pcm(2400, 1234);
      final output = await resampleSystemAudio(Stream.value(input)).toList();

      expect(output, hasLength(1));
      expect(output.first.length ~/ 2, 800);
      for (var i = 0; i < 800; i++) {
        expect(_sampleAt(output.first, i), 1234);
      }
    });

    test('downsamples 44.1 kHz chunks to 16 kHz', () async {
      final input = _pcm(2205, -500);
      final output = await resampleSystemAudio(Stream.value(input)).toList();

      expect(output, hasLength(1));
      expect(output.first.length ~/ 2, 800);
      for (var i = 0; i < 800; i++) {
        expect(_sampleAt(output.first, i), -500);
      }
    });

    test('passes through chunks already at 16 kHz', () async {
      final input = _pcm(800, 42);
      final output = await resampleSystemAudio(Stream.value(input)).toList();

      expect(output, hasLength(1));
      expect(output.first, same(input));
    });
  });
}
