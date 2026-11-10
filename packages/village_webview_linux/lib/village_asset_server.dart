import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Serves the bundled 3D village to the WebView over loopback HTTP, because
/// WebKit won't load ES modules from `file://` (ADR 0126).
///
/// Hardened for a server any local process could reach:
/// - bound to 127.0.0.1 on a random port;
/// - every path sits under a random 128-bit token, so another page or app
///   on this machine can't fetch from it without being handed the URL;
/// - GET and HEAD only; a path that is absolute, has `..`, a backslash or
///   an empty segment is refused before it touches the disk, and the
///   resolved file must stay inside [root];
/// - `nosniff`, no caching, and a content type from a fixed list.
class VillageAssetServer {
  VillageAssetServer._(this._server, this.root, this.token);

  static Future<VillageAssetServer> start(Directory root) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final rng = Random.secure();
    final token = List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final s = VillageAssetServer._(
      server,
      Directory(root.resolveSymbolicLinksSync()),
      token,
    );
    server.listen(s._serve);
    return s;
  }

  final HttpServer _server;
  final Directory root;
  final String token;

  /// The scene's own origin: what its `postMessage` checks against.
  Uri get origin => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// The entry page, in embed mode.
  Uri get entry => origin.replace(
    path: '/$token/village.html',
    queryParameters: {'embed': '1'},
  );

  static const _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json',
    'glb': 'model/gltf-binary',
    'webp': 'image/webp',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'svg': 'image/svg+xml',
    'ttf': 'font/ttf',
    'woff2': 'font/woff2',
  };

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Cache-Control', 'no-store');
    final file = _resolve(request);
    if (file == null) {
      response.statusCode = request.method == 'GET' || request.method == 'HEAD'
          ? HttpStatus.notFound
          : HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    response.headers.contentType = ContentType.parse(
      _types[ext] ?? 'application/octet-stream',
    );
    response.contentLength = await file.length();
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }
    await response.addStream(file.openRead());
    await response.close();
  }

  File? _resolve(HttpRequest request) {
    if (request.method != 'GET' && request.method != 'HEAD') return null;
    final segments = request.uri.pathSegments;
    if (segments.length < 2 || segments.first != token) return null;
    final rest = segments.sublist(1);
    final raw = request.uri.path;
    if (raw.contains(r'\') || raw.contains('//')) return null;
    if (rest.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    final file = File([root.path, ...rest].join(Platform.pathSeparator));
    if (!file.existsSync()) return null;
    final real = file.resolveSymbolicLinksSync();
    if (!real.startsWith('${root.path}${Platform.pathSeparator}')) return null;
    return File(real);
  }

  Future<void> close() => _server.close(force: true);
}
