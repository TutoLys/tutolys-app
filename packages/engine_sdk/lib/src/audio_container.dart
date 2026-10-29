import 'dart:typed_data';

/// What a clip's bytes are, read from their first bytes rather than from a
/// name or a declared type (backend work order A1, 2026-10-29).
///
/// Lesson audio moved from WAV to AAC in MP4 (`.m4a`), and a device keeps
/// both: clips cached before the switch are WAV, new ones are M4A. iOS,
/// macOS and Android pick a decoder from the file's extension, so the temp
/// file must be named for what its bytes really are.
typedef AudioContainer = ({String extension, String mimeType});

const _wav = (extension: 'wav', mimeType: 'audio/wav');
const _m4a = (extension: 'm4a', mimeType: 'audio/mp4');
const _ogg = (extension: 'ogg', mimeType: 'audio/ogg');
const _mp3 = (extension: 'mp3', mimeType: 'audio/mpeg');

AudioContainer audioContainerOf(Uint8List b) {
  bool at(int offset, String ascii) {
    if (b.length < offset + ascii.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (b[offset + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (at(0, 'RIFF') && at(8, 'WAVE')) return _wav;
  if (at(4, 'ftyp')) return _m4a;
  if (at(0, 'OggS')) return _ogg;
  if (at(0, 'ID3') || (b.length > 1 && b[0] == 0xFF && b[1] & 0xE0 == 0xE0)) {
    return _mp3;
  }
  // Unknown: WAV was the only format before the switch.
  return _wav;
}
