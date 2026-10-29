import 'dart:typed_data';

import 'package:engine_sdk/src/audio_container.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend work order A1: the temp file is named for what its bytes are.
void main() {
  Uint8List bytes(List<int> head) =>
      Uint8List.fromList([...head, ...List.filled(16, 0)]);
  List<int> ascii(String s) => s.codeUnits;

  test('WAV clips cached before the switch stay .wav', () {
    final c = audioContainerOf(
      bytes([...ascii('RIFF'), 0, 0, 0, 0, ...ascii('WAVE')]),
    );
    expect(c, (extension: 'wav', mimeType: 'audio/wav'));
  });

  test('AAC in MP4 (the new lesson audio) is .m4a', () {
    final c = audioContainerOf(
      bytes([0, 0, 0, 0x20, ...ascii('ftypM4A ')]),
    );
    expect(c, (extension: 'm4a', mimeType: 'audio/mp4'));
  });

  test('Ogg and MP3 are recognised too', () {
    expect(audioContainerOf(bytes(ascii('OggS'))).extension, 'ogg');
    expect(audioContainerOf(bytes(ascii('ID3'))).extension, 'mp3');
    expect(audioContainerOf(bytes([0xFF, 0xFB])).extension, 'mp3');
  });

  test('anything else, or too short, falls back to WAV', () {
    expect(audioContainerOf(Uint8List(0)).extension, 'wav');
    expect(audioContainerOf(bytes([1, 2, 3])).extension, 'wav');
  });
}
