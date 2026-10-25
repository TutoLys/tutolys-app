/// What an `assets[]` entry holds. Audio and pictures share the one array
/// (backend ADR 0021's `{ref, url, sha256}`), so the app has to tell them
/// apart before deciding which cache an entry belongs in.
enum AssetKind { audio, image }

const _imageTypes = {
  'webp': 'image/webp',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
};

/// The asset's `media_type` when the backend sends one; otherwise its URL's
/// extension. Anything else counts as audio, which is all `assets[]` ever
/// held before pictures, so older content keeps behaving exactly as it did.
AssetKind assetKindOf(Map<String, Object?> asset) {
  final type = asset['media_type'];
  if (type is String) {
    return type.startsWith('image/') ? AssetKind.image : AssetKind.audio;
  }
  return imageMediaTypeOf(asset) == null ? AssetKind.audio : AssetKind.image;
}

/// `image/webp` and so on for a picture asset, null for anything else.
/// SVG is deliberately not a picture here: Flutter can't decode it from
/// bytes without a renderer the app doesn't ship.
String? imageMediaTypeOf(Map<String, Object?> asset) {
  final type = asset['media_type'];
  if (type is String) {
    return _imageTypes.containsValue(type) ? type : null;
  }
  final url = asset['url'];
  if (url is! String) return null;
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot == -1) return null;
  return _imageTypes[path.substring(dot + 1).toLowerCase()];
}
