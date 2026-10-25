import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Resolves an `image_ref` to the picture's cached bytes.
///
/// The same shape as [AudioResolver], for the same reason: this package
/// never touches the app's database, so the app supplies a drift-backed
/// implementation and tests supply [InMemoryImageResolver]. The ref matches
/// an entry in the envelope's `assets[]` (`{ref, url, sha256}`), whether it
/// came from `prompt.image_ref` or an option's or item's `image_ref`.
abstract interface class ImageResolver {
  /// The picture's bytes, or null when it isn't synced yet (offline, still
  /// downloading) or the exercise has no such asset.
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  });
}

/// In-memory stand-in for tests, and a safe default: no picture is a
/// legitimate state, and [ContentImage] then shows its fallback.
class InMemoryImageResolver implements ImageResolver {
  InMemoryImageResolver([Map<String, Uint8List>? seed]) : _bytes = {...?seed};

  final Map<String, Uint8List> _bytes;

  void put(String exerciseId, String ref, Uint8List bytes) {
    _bytes['$exerciseId/$ref'] = bytes;
  }

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) async => _bytes['$exerciseId/$ref'];
}

/// Puts an [ImageResolver] and the exercise it resolves for above an
/// engine. An engine's view never sees the exercise id, and assets belong to
/// the whole envelope (every question in a série shares them), so the host
/// binds both once, where it knows the envelope.
class ImageResolverScope extends InheritedWidget {
  const ImageResolverScope({
    required this.resolver,
    required this.exerciseId,
    required super.child,
    super.key,
  });

  final ImageResolver resolver;
  final String exerciseId;

  static ImageResolverScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageResolverScope>();

  @override
  bool updateShouldNotify(ImageResolverScope oldWidget) =>
      resolver != oldWidget.resolver || exerciseId != oldWidget.exerciseId;
}

/// Draws one `image_ref`, or [fallback] while it loads, when it isn't
/// synced, when its bytes don't decode, or when there is no
/// [ImageResolverScope] above it. A picture that hasn't arrived therefore
/// never blanks a tile: pass the item's label (or emoji) as the fallback.
///
/// It imposes no size: it fills its parent's constraints with [fit], so the
/// caller gives it a box (an undecoded image is 0px tall otherwise).
class ContentImage extends StatefulWidget {
  const ContentImage({
    required this.ref,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    super.key,
  });

  final String ref;
  final Widget fallback;
  final BoxFit fit;

  /// The screen-reader name. Usually the item's label, which is why content
  /// keeps a label even when it has a picture.
  final String? semanticLabel;

  @override
  State<ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<ContentImage> {
  ImageResolver? _resolver;
  String? _exerciseId;
  Future<MemoryImage?>? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ImageResolverScope.maybeOf(context);
    if (scope?.resolver != _resolver || scope?.exerciseId != _exerciseId) {
      _resolver = scope?.resolver;
      _exerciseId = scope?.exerciseId;
      _image = _load();
    }
  }

  @override
  void didUpdateWidget(ContentImage old) {
    super.didUpdateWidget(old);
    if (old.ref != widget.ref) _image = _load();
  }

  Future<MemoryImage?> _load() async {
    final resolver = _resolver;
    final exerciseId = _exerciseId;
    if (resolver == null || exerciseId == null) return null;
    final bytes = await resolver.bytesFor(
      exerciseId: exerciseId,
      ref: widget.ref,
    );
    // MemoryImage keys on the bytes' identity, so holding one instance per
    // ref lets the image cache reuse the decode across rebuilds.
    return bytes == null || bytes.isEmpty ? null : MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemoryImage?>(
      future: _image,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) return widget.fallback;
        return Image(
          image: image,
          fit: widget.fit,
          semanticLabel: widget.semanticLabel,
          excludeFromSemantics: widget.semanticLabel == null,
          gaplessPlayback: true,
          // A corrupt or undecodable picture falls back like a missing one.
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
