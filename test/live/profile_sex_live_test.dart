// Live check against a running dev-stack: the app's own ProfileApi and
// picker filter, fed by the backend's real /me/profile values.
//
// Skipped unless E2E_TOKENS is set. Produce it with
//   E2E_TOKENS_OUT=/tmp/x.json python3 ../dev-stack/scripts/e2e_profile.py
//   E2E_TOKENS=/tmp/x.json flutter test test/live/
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/profile_api.dart';
import 'package:tutolys_app/features/profile/avatars.dart';

void main() {
  final path = Platform.environment['E2E_TOKENS'];
  final tokens = path == null
      ? null
      : jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('real /me/profile sex drives the picker and the default', () async {
    final api = ProfileApi(dio: Dio(BaseOptions(baseUrl: tokens!['base'] as String)));

    final girl = await api.fetchProfile(accessToken: tokens['girl'] as String);
    final boy = await api.fetchProfile(accessToken: tokens['boy'] as String);
    expect(girl?.sex, KidSex.girl);
    expect(boy?.sex, KidSex.boy);

    List<String> offered(KidSex s) => [
          for (final a in AvatarState(selected: '', unlocked: const {}, sex: s).offered)
            if (a.unlock is AvatarFree) a.key,
        ];
    expect(offered(girl!.sex), [
      'kid_wavy', 'kid_glasses', 'kid_hijab', 'kid_braids', //
      'camper_girl', 'explorer_girl',
    ]);
    expect(offered(boy!.sex), [
      'kid_curly', 'kid_freckles', 'camper_boy', 'explorer_boy',
    ]);
    expect(defaultAvatarFor(boy.sex), 'kid_curly');
    expect(defaultAvatarFor(girl.sex), 'kid_wavy');
  }, skip: tokens == null ? 'needs E2E_TOKENS (a running dev-stack)' : false);
}
