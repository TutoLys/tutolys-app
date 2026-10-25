import 'dart:convert';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/sync/asset_kind.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/data/sync/content_sync.dart';
import 'package:tutolys_app/data/sync/drift_image_resolver.dart';

import 'content_sync_test.dart' show FakeContentServer;

/// A real 1x1 PNG, so the bytes are a picture Flutter could decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Map<String, Object?> exercise(
  String id, {
  List<Object?> assets = const [],
  int rank = 0,
}) => {
  'schema_version': 1,
  'exercise_id': id,
  'version': 1,
  'engine_key': 'mcq',
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'MATH',
  'grade': 1,
  'rank': rank,
  'locale': 'fr-CA',
  'prompt': {'text': 'Lequel ?', 'audio_ref': null, 'image_ref': 'img_a'},
  'config': {
    'options': [
      {'id': 'a', 'label': 'chat', 'image_ref': 'img_a'},
      {'id': 'b', 'label': 'chien'},
    ],
    'correct': 'a',
  },
  'assets': assets,
};

Map<String, Object?> picture(String ref, String url, Uint8List bytes) => {
  'ref': ref,
  'url': url,
  'sha256': bytesSha256(bytes),
};

void main() {
  group('telling pictures from audio in assets[]', () {
    test('media_type decides when the backend sends it', () {
      expect(
        assetKindOf({'url': '/x.bin', 'media_type': 'image/webp'}),
        AssetKind.image,
      );
      expect(
        assetKindOf({'url': '/x.png', 'media_type': 'audio/wav'}),
        AssetKind.audio,
      );
    });

    test('otherwise the URL\'s extension, query string ignored', () {
      expect(assetKindOf({'url': '/media/a/cat.WEBP?v=2'}), AssetKind.image);
      expect(imageMediaTypeOf({'url': '/media/a/cat.jpg'}), 'image/jpeg');
      expect(assetKindOf({'url': '/media/a/q0_audio.wav'}), AssetKind.audio);
    });

    test('SVG is not a picture the app can draw from bytes', () {
      expect(imageMediaTypeOf({'url': '/media/a/cat.svg'}), isNull);
      expect(imageMediaTypeOf({'media_type': 'image/svg+xml'}), isNull);
    });
  });

  group('ContentSync and pictures', () {
    late LocalDatabase db;
    late FakeContentServer server;
    late ContentSync sync;

    setUp(() {
      db = LocalDatabase.memory();
      server = FakeContentServer();
      sync = ContentSync(
        db: db,
        api: server,
        accessToken: () => 'token',
        clock: () => DateTime.utc(2026, 10, 25),
      );
    });
    tearDown(() => db.close());

    test('a picture lands in asset_cache, verified, never in audio', () async {
      const url = '/media/exercise_images/cat.png';
      server.audio[url] = _png;
      server.content['ex1'] = exercise(
        'ex1',
        assets: [picture('img_a', url, _png)],
      );

      await sync.sync();

      final row = (await db.select(db.assetCacheTable).get()).single;
      expect(row.sha256, bytesSha256(_png));
      expect(row.mediaType, 'image/png');
      expect(row.sizeBytes, _png.length);
      expect(await db.select(db.audioCacheTable).get(), isEmpty);
    });

    test('a picture whose bytes don\'t match its sha256 is refused', () async {
      const url = '/media/exercise_images/cat.png';
      server.audio[url] = _png;
      server.content['ex1'] = exercise(
        'ex1',
        assets: [
          {'ref': 'img_a', 'url': url, 'sha256': 'a' * 64},
        ],
      );

      final report = await sync.sync();

      expect(report.isOk, isTrue, reason: 'the exercise itself still syncs');
      expect(await db.select(db.assetCacheTable).get(), isEmpty);
    });

    test('two lessons sharing a picture keep one copy, fetched once', () async {
      const url = '/media/exercise_images/cat.png';
      server.audio[url] = _png;
      server.content['ex1'] = exercise(
        'ex1',
        assets: [picture('img_a', url, _png)],
      );
      server.content['ex2'] = exercise(
        'ex2',
        rank: 1,
        assets: [picture('img_a', url, _png)],
      );

      await sync.sync();

      expect(await db.select(db.assetCacheTable).get(), hasLength(1));
      expect(server.audioRequestedUrls, [url]);
    });

    test('a picture no lesson uses any more is removed, and counted', () async {
      final dog = Uint8List.fromList([..._png, 0]);
      server.audio['/cat.png'] = _png;
      server.audio['/dog.png'] = dog;
      server.content['ex1'] = exercise(
        'ex1',
        assets: [picture('img_a', '/cat.png', _png)],
      );
      server.content['ex2'] = exercise(
        'ex2',
        rank: 1,
        assets: [picture('img_a', '/dog.png', dog)],
      );
      await sync.sync();
      expect(await db.select(db.assetCacheTable).get(), hasLength(2));

      server.content.remove('ex2');
      await sync.sync();

      final left = await db.select(db.assetCacheTable).get();
      expect(left.single.sha256, bytesSha256(_png));
      expect(await sync.imagesRemovedTotal(), 1);
    });

    test('DriftImageResolver turns an image_ref into its bytes', () async {
      const url = '/media/exercise_images/cat.png';
      server.audio[url] = _png;
      server.content['ex1'] = exercise(
        'ex1',
        assets: [picture('img_a', url, _png)],
      );
      await sync.sync();

      final resolver = DriftImageResolver(db);
      expect(await resolver.bytesFor(exerciseId: 'ex1', ref: 'img_a'), _png);
      expect(await resolver.bytesFor(exerciseId: 'ex1', ref: 'nope'), isNull);
      expect(await resolver.bytesFor(exerciseId: 'gone', ref: 'img_a'), isNull);
    });
  });

  group('ContentImage', () {
    Widget host(ImageResolver? resolver) {
      const image = ContentImage(
        exerciseId: 'ex1',
        ref: 'img_a',
        fallback: Text('chat'),
        semanticLabel: 'chat',
      );
      return MaterialApp(
        home: resolver == null
            ? image
            : ImageResolverScope(resolver: resolver, child: image),
      );
    }

    testWidgets('no resolver above it: the fallback', (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pump();
      expect(find.text('chat'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('not synced yet: the fallback', (tester) async {
      await tester.pumpWidget(host(InMemoryImageResolver()));
      await tester.pump();
      expect(find.text('chat'), findsOneWidget);
    });

    testWidgets('synced: the picture, named for screen readers', (
      tester,
    ) async {
      final resolver = InMemoryImageResolver()..put('ex1', 'img_a', _png);
      await tester.pumpWidget(host(resolver));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('chat'), findsOneWidget);
    });
  });
}
