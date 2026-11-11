import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Serves the bundled 3D village to the WebView over loopback HTTP, because
/// WebKit won't load ES modules from `file://` (ADR 0126). From a directory
/// on disk (Linux, Windows) or, through [startWith], from any loader: on
/// Android the assets live inside the APK, not on disk (ADR 0127).
///
/// Hardened for a server any local process could reach:
/// - bound to 127.0.0.1 on a random port;
/// - every path sits under a random 128-bit token, so another page or app
///   on this machine can't fetch from it without being handed the URL;
/// - GET and HEAD only; a path that is absolute, has `..`, a backslash or
///   an empty segment is refused before it touches the disk, and the
///   resolved file must stay inside [root];
/// - `nosniff`, no caching, and a content type from a fixed list.
/// Reads one bundle file by its path segments (already checked: no `..`,
/// no empty segment). Null when there is no such file.
typedef VillageAssetLoader = Future<List<int>?> Function(List<String> path);

class VillageAssetServer {
  VillageAssetServer._(this._server, this.root, this._load, this.token);

  /// Serves [root] from disk; the resolved file must stay inside it.
  static Future<VillageAssetServer> start(Directory root) =>
      _start(Directory(root.resolveSymbolicLinksSync()), null);

  /// Serves whatever [load] returns: the app's asset bundle on Android,
  /// iOS and macOS, where the scene isn't a directory the app can name.
  static Future<VillageAssetServer> startWith(VillageAssetLoader load) =>
      _start(null, load);

  static Future<VillageAssetServer> _start(
    Directory? root,
    VillageAssetLoader? load,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final rng = Random.secure();
    final token = List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final s = VillageAssetServer._(server, root, load, token);
    server.listen(s._serve);
    return s;
  }

  final HttpServer _server;

  /// The bundle on disk, or null when served through a loader.
  final Directory? root;
  final VillageAssetLoader? _load;
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
    final readable = request.method == 'GET' || request.method == 'HEAD';
    final rest = readable ? _segments(request) : null;
    final bytes = rest == null ? null : await _read(rest);
    if (bytes == null) {
      response.statusCode = readable
          ? HttpStatus.notFound
          : HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    final ext = rest!.last.split('.').last.toLowerCase();
    response.headers.contentType = ContentType.parse(
      _types[ext] ?? 'application/octet-stream',
    );
    response.contentLength = bytes.length;
    if (request.method != 'HEAD') response.add(bytes);
    await response.close();
  }

  /// The checked path under the token, or null.
  List<String>? _segments(HttpRequest request) {
    final segments = request.uri.pathSegments;
    if (segments.length < 2 || segments.first != token) return null;
    final rest = segments.sublist(1);
    final raw = request.uri.path;
    if (raw.contains(r'\') || raw.contains('//')) return null;
    if (rest.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    if (rest.any((s) => s.contains('/') || s.contains(r'\'))) return null;
    return rest;
  }

  Future<List<int>?> _read(List<String> rest) async {
    final load = _load;
    if (load != null) {
      try {
        return await load(rest);
      } catch (_) {
        return null;
      }
    }
    final file = _resolve(rest);
    return file?.readAsBytes();
  }

  File? _resolve(List<String> rest) {
    final root = this.root!;
    final file = File([root.path, ...rest].join(Platform.pathSeparator));
    if (!file.existsSync()) return null;
    final real = file.resolveSymbolicLinksSync();
    if (!real.startsWith('${root.path}${Platform.pathSeparator}')) return null;
    return File(real);
  }

  Future<void> close() => _server.close(force: true);
}
