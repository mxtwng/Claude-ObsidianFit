/// YAML frontmatter <-> Dart map codec for ObsidianFit notes.
///
/// Parsing uses `package:yaml`. Encoding is hand-written so the output matches
/// the style of `schemas/*.md` exactly:
///   * plain scalars stay unquoted (`type: strength`, `fitness/gym`)
///   * anything with spaces, colons, brackets, or a leading digit is
///     double-quoted (`"Push Day A"`, `"18:00"`, `"[[Route.gpx]]"`)
///   * [DateTime] values are emitted as unquoted `yyyy-MM-dd`
///   * lists are emitted block-style, indented two spaces
library;

import 'package:yaml/yaml.dart';

import '../models/ModelUtils.dart';

class FrontMatterException implements Exception {
  const FrontMatterException(this.message);

  final String message;

  @override
  String toString() => 'FrontMatterException: $message';
}

/// Result of splitting a note into frontmatter and body.
class FrontMatterDocument {
  const FrontMatterDocument({
    required this.frontmatter,
    required this.body,
    required this.hadFrontmatter,
  });

  final Map<String, Object?> frontmatter;

  /// Everything after the closing `---`, without leading blank lines.
  final String body;
  final bool hadFrontmatter;
}

class FrontMatterCodec {
  const FrontMatterCodec._();

  /// Splits [source] into frontmatter map and body. A note with no leading
  /// `---` block yields an empty map and the full text as body.
  ///
  /// Throws [FrontMatterException] on malformed YAML or a non-map root.
  static FrontMatterDocument parse(String source) {
    var text = source.replaceAll('\r\n', '\n');
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final lines = text.split('\n');
    if (lines.first.trim() != '---') {
      return FrontMatterDocument(
        frontmatter: const {},
        body: text,
        hadFrontmatter: false,
      );
    }

    var end = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        end = i;
        break;
      }
    }
    if (end == -1) {
      return FrontMatterDocument(
        frontmatter: const {},
        body: text,
        hadFrontmatter: false,
      );
    }

    final yamlText = lines.sublist(1, end).join('\n');
    Object? parsed;
    try {
      parsed = yamlText.trim().isEmpty ? null : loadYaml(yamlText);
    } on YamlException catch (e) {
      throw FrontMatterException(e.message);
    }
    if (parsed != null && parsed is! Map) {
      throw const FrontMatterException('Frontmatter root must be a mapping.');
    }

    final fm = parsed == null
        ? <String, Object?>{}
        : (_plain(parsed) as Map<String, Object?>);
    final body = lines.sublist(end + 1).join('\n').replaceFirst(
          RegExp(r'^\n+'),
          '',
        );
    return FrontMatterDocument(
      frontmatter: fm,
      body: body,
      hadFrontmatter: true,
    );
  }

  /// Renders [frontmatter] + [body] as a complete note ending in one newline.
  static String encode(Map<String, Object?> frontmatter, String body) {
    final b = StringBuffer('---\n');
    _writeMap(b, frontmatter, 0);
    b.write('---\n');
    final cleaned = body.replaceFirst(RegExp(r'^\n+'), '').trimRight();
    if (cleaned.isNotEmpty) {
      b.write('\n');
      b.write(cleaned);
      b.write('\n');
    }
    return b.toString();
  }

  // ---- internals ----------------------------------------------------------

  /// Converts YamlMap/YamlList trees into plain Dart collections.
  static Object? _plain(Object? v) {
    if (v is YamlMap) {
      return <String, Object?>{
        for (final e in v.entries) e.key.toString(): _plain(e.value),
      };
    }
    if (v is YamlList) {
      return <Object?>[for (final e in v) _plain(e)];
    }
    return v;
  }

  static void _writeMap(StringBuffer b, Map<Object?, Object?> map, int indent) {
    final pad = ' ' * indent;
    for (final e in map.entries) {
      final key = _string(e.key.toString());
      final v = e.value;
      if (v is Map) {
        if (v.isEmpty) {
          b.write('$pad$key: {}\n');
        } else {
          b.write('$pad$key:\n');
          _writeMap(b, v, indent + 2);
        }
      } else if (v is Iterable) {
        if (v.isEmpty) {
          b.write('$pad$key: []\n');
        } else {
          b.write('$pad$key:\n');
          for (final item in v) {
            b.write('$pad  - ${_scalar(item)}\n');
          }
        }
      } else {
        b.write('$pad$key: ${_scalar(v)}\n');
      }
    }
  }

  static String _scalar(Object? v) {
    if (v == null) return 'null';
    if (v is DateTime) {
      final dateOnly = v.hour == 0 &&
          v.minute == 0 &&
          v.second == 0 &&
          v.millisecond == 0 &&
          v.microsecond == 0;
      return dateOnly ? formatIsoDate(v) : v.toIso8601String();
    }
    if (v is bool) return v ? 'true' : 'false';
    if (v is int) return v.toString();
    if (v is double) {
      return v.isFinite ? formatDecimal(v) : _string(v.toString());
    }
    return _string(v.toString());
  }

  static final RegExp _plainSafe = RegExp(r'^[A-Za-z_][A-Za-z0-9_./-]*$');
  static const Set<String> _reserved = {
    'true',
    'false',
    'null',
    'yes',
    'no',
    'on',
    'off',
    'y',
    'n',
  };

  static String _string(String s) {
    if (_plainSafe.hasMatch(s) && !_reserved.contains(s.toLowerCase())) {
      return s;
    }
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }
}
