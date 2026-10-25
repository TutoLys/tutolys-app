import 'package:dio/dio.dart';

/// One taggable curriculum leaf, as the backend serves it — flat, no
/// parent/child linkage (A7's thin slice; a tree-shaped response is a later
/// extension, not built ahead of a screen that would use it).
class CurriculumLeaf {
  const CurriculumLeaf({
    required this.id,
    required this.labelFr,
    required this.labelEn,
    required this.stableKey,
    this.docOrder,
    this.strandKey,
    this.strandLabelFr,
    this.strandLabelEn,
    this.areaLabelFr,
    this.areaLabelEn,
    this.areaOrdinal,
  });

  factory CurriculumLeaf.fromJson(Map<String, Object?> json) {
    final strand = json['strand'] as Map<String, Object?>?;
    final area = json['area'] as Map<String, Object?>?;
    return CurriculumLeaf(
      id: json['id'] as String,
      labelFr: json['label_fr'] as String,
      labelEn: json['label_en'] as String? ?? '',
      stableKey: json['stable_key'] as String,
      docOrder: json['doc_order'] as int?,
      strandKey: strand?['key'] as String?,
      strandLabelFr: strand?['label_fr'] as String?,
      strandLabelEn: strand?['label_en'] as String?,
      areaLabelFr: area?['label_fr'] as String?,
      areaLabelEn: area?['label_en'] as String?,
      areaOrdinal: area?['ordinal'] as int?,
    );
  }

  final String id;
  final String labelFr;
  final String labelEn;
  final String stableKey;

  /// Where the leaf sits in its subject's document (backend ADR 0044).
  /// Strictly increasing through a response, but not an index: interior
  /// nodes count too. Null from a backend older than that.
  final int? docOrder;

  /// The leaf's strand and learning area, with their labels as the
  /// document writes them. Null from an older backend, or for a leaf whose
  /// parent was archived; the app then falls back to its own table.
  final String? strandKey;
  final String? strandLabelFr;
  final String? strandLabelEn;
  final String? areaLabelFr;
  final String? areaLabelEn;
  final int? areaOrdinal;
}

sealed class CurriculumTreeResult {
  const CurriculumTreeResult();
}

class CurriculumTreeFetched extends CurriculumTreeResult {
  const CurriculumTreeFetched(this.leaves);
  final List<CurriculumLeaf> leaves;
}

class CurriculumTreeOffline extends CurriculumTreeResult {
  const CurriculumTreeOffline();
}

class CurriculumTreeUnauthorized extends CurriculumTreeResult {
  const CurriculumTreeUnauthorized();
}

class CurriculumTreeFailed extends CurriculumTreeResult {
  const CurriculumTreeFailed(this.detail);
  final String detail;
}

/// Reads the curriculum tree the backend serves to a paired device —
/// GET /api/v1/curriculum/tree?subject=MATH, scoped server-side to this
/// kid's own grade (ADR 0007: grade is never a request parameter here).
class CurriculumApi {
  CurriculumApi({required this.dio});

  final Dio dio;

  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/curriculum/tree',
        queryParameters: {'subject': subject},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data!;
      final leaves = ((body['nodes'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(CurriculumLeaf.fromJson)
          .toList(growable: false);

      return CurriculumTreeFetched(leaves);
    } on DioException catch (error) {
      if (_isOffline(error)) return const CurriculumTreeOffline();
      if (error.response?.statusCode == 401) {
        return const CurriculumTreeUnauthorized();
      }
      return CurriculumTreeFailed(
        error.message ?? 'curriculum tree fetch failed',
      );
    }
  }

  /// `dart:io` is unavailable on web, so this reads the Dio type rather than
  /// catching `SocketException`. Mirrors `ContentApi`'s own check.
  bool _isOffline(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
  }
}
