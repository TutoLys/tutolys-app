import 'web_audio_backend.dart';

/// Native builds never use Web Audio; audioplayers plays from a file there.
WebAudioBackend createWebAudioBackend() =>
    throw UnsupportedError('Web Audio exists only in a browser.');
