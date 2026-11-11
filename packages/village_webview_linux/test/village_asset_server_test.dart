import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_webview_linux/village_asset_server.dart';

/// The loopback server any local process could reach (ADR 0126): it must
/// serve the bundle and nothing else.
void main() {
  late Directory root;
  late Directory outside;
  late VillageAssetServer server;
  final client = HttpClient();

  setUp(() async {
    final tmp = await Directory.systemTemp.createTemp('village3d');
    root = await Directory('${tmp.path}/bundle').create();
    outside = await Directory('${tmp.path}/secret').create();
    await File('${root.path}/village.html').writeAsString('<p>ok</p>');
    await Directory('${root.path}/src').create();
    await File('${root.path}/src/main.js').writeAsString('export {};');
    await File('${outside.path}/token.txt').writeAsString('private');
    await Link('${root.path}/escape.txt').create('${outside.path}/token.txt');
    server = await VillageAssetServer.start(root);
  });

  tearDown(() async {
    await server.close();
    await root.parent.delete(recursive: true);
  });

  Future<(int, String, String?)> get(String path, {String method = 'GET'}) async {
    final req = await client.openUrl(
      method,
      server.origin.replace(path: path),
    );
    final res = await req.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    return (res.statusCode, body, res.headers.contentType?.mimeType);
  }

  test('binds loopback only', () {
    expect(server.origin.host, '127.0.0.1');
    expect(server.entry.queryParameters['embed'], '1');
  });

  test('serves the bundle under its token, with its type', () async {
    final (code, body, type) = await get('/${server.token}/village.html');
    expect(code, 200);
    expect(body, '<p>ok</p>');
    expect(type, 'text/html');
    final (jsCode, _, jsType) = await get('/${server.token}/src/main.js');
    expect(jsCode, 200);
    expect(jsType, 'text/javascript');
  });

  test('nothing without the token', () async {
    expect((await get('/village.html')).$1, 404);
    expect((await get('/0000/village.html')).$1, 404);
  });

  test('no way out of the bundle', () async {
    final t = server.token;
    for (final path in [
      '/$t/../secret/token.txt',
      '/$t/%2e%2e/secret/token.txt',
      '/$t//etc/passwd',
      '/$t/escape.txt',
    ]) {
      final (code, body, _) = await get(path);
      expect(code, 404, reason: path);
      expect(body, isNot(contains('private')), reason: path);
    }
  });

  test('read-only', () async {
    expect((await get('/${server.token}/village.html', method: 'POST')).$1, 405);
    expect((await get('/${server.token}/village.html', method: 'PUT')).$1, 405);
  });

  group('from a loader (Android, iOS, macOS: ADR 0127)', () {
    late VillageAssetServer bundled;
    final asked = <String>[];

    setUp(() async {
      asked.clear();
      bundled = await VillageAssetServer.startWith((path) async {
        asked.add(path.join('/'));
        return switch (path.join('/')) {
          'village.html' => '<p>bundle</p>'.codeUnits,
          'models/a.glb' => [1, 2, 3],
          _ => null,
        };
      });
    });

    tearDown(() => bundled.close());

    Future<(int, String, String?)> fetch(String path, {String method = 'GET'}) async {
      final req = await client.openUrl(method, bundled.origin.replace(path: path));
      final res = await req.close();
      final body = await res.transform(const SystemEncoding().decoder).join();
      return (res.statusCode, body, res.headers.contentType?.mimeType);
    }

    test('serves what the loader returns, with its type', () async {
      final t = bundled.token;
      final (code, body, type) = await fetch('/$t/village.html');
      expect((code, body, type), (200, '<p>bundle</p>', 'text/html'));
      final (glb, _, glbType) = await fetch('/$t/models/a.glb');
      expect((glb, glbType), (200, 'model/gltf-binary'));
      expect((await fetch('/$t/missing.js')).$1, 404);
    });

    test('a bad path never reaches the loader', () async {
      final t = bundled.token;
      for (final path in [
        '/village.html',
        '/$t/../village.html',
        '/$t/%2e%2e/village.html',
        '/$t/a%2F..%2Fvillage.html',
        '/$t//village.html',
      ]) {
        expect((await fetch(path)).$1, 404, reason: path);
      }
      expect(asked, isEmpty);
      expect((await fetch('/$t/village.html', method: 'POST')).$1, 405);
      expect(asked, isEmpty);
    });
  });
}
