import '../../domain/import/import_models.dart';
import '../../domain/import/port/import_source_parser.dart';

/// Resolves source parsers without teaching the import workflow about any
/// concrete external product.
class ImportParserRegistry {
  ImportParserRegistry(Iterable<ImportSourceParser> parsers)
    : _parsers = _index(parsers);

  final Map<ImportSource, ImportSourceParser> _parsers;

  ImportSourceParser parserFor(ImportSource source) {
    final parser = _parsers[source];
    if (parser == null) {
      throw StateError('No import parser registered for ${source.name}.');
    }
    return parser;
  }

  static Map<ImportSource, ImportSourceParser> _index(
    Iterable<ImportSourceParser> parsers,
  ) {
    final result = <ImportSource, ImportSourceParser>{};
    for (final parser in parsers) {
      if (result.containsKey(parser.source)) {
        throw ArgumentError.value(
          parser.source,
          'parsers',
          'Only one parser can be registered for an import source.',
        );
      }
      result[parser.source] = parser;
    }
    return Map.unmodifiable(result);
  }
}
