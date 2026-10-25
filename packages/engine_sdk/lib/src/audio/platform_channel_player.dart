import 'package:flutter/foundation.dart';

import 'channel_audio_coordinator.dart';
import 'web_audio_backend_stub.dart'
    if (dart.library.js_interop) 'web_audio_backend_js.dart';
import 'web_audio_player.dart';

/// The right [ChannelPlayer] for this platform: decoded Web Audio in a
/// browser (ADR 0043), audioplayers from a file everywhere else.
ChannelPlayer platformChannelPlayer() => kIsWeb
    ? WebAudioChannelPlayer(createWebAudioBackend())
    : AudioplayersChannelPlayer();
