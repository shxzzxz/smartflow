// 顶层分层 import 边界守护测试。
//
// 约束目标：
// - domain 不依赖 application / infrastructure / feature / app / data / Flutter UI / Drift / Riverpod。
// - application 可依赖 domain 和 core，不依赖 infrastructure / feature / app / data。
// - infrastructure 可依赖 application、domain、core、data，不依赖 feature / app。
// - feature 和 widget 不直接依赖 domain / infrastructure / data，只通过 application / app provider。
// - ledger domain 不依赖 credit domain。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('顶层分层 import 边界', () {
    test('domain 不依赖外层和技术实现', () {
      final violations = <_Violation>[];
      const forbiddenRoots = <String>[
        'application/',
        'infrastructure/',
        'feature/',
        'app/',
        'data/',
        'widget/',
        'design_system/',
      ];
      const forbiddenPackages = <String>[
        'package:drift/',
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:riverpod_annotation/',
      ];

      for (final file in _dartFiles('lib/domain')) {
        for (final importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target != null) {
            for (final root in forbiddenRoots) {
              if (target.startsWith(root)) {
                violations.add(
                  _Violation(file, importPath, 'domain 不能依赖 $root'),
                );
              }
            }
          }
          for (final package in forbiddenPackages) {
            if (importPath.startsWith(package)) {
              violations.add(
                _Violation(file, importPath, 'domain 不能依赖技术包 $package'),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('application 不依赖外层实现', () {
      final violations = <_Violation>[];
      const forbiddenRoots = <String>[
        'infrastructure/',
        'feature/',
        'app/',
        'data/',
        'widget/',
        'design_system/',
      ];
      const forbiddenPackages = <String>[
        'package:drift/',
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:riverpod_annotation/',
      ];

      for (final file in _dartFiles('lib/application')) {
        for (final importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target != null) {
            for (final root in forbiddenRoots) {
              if (target.startsWith(root)) {
                violations.add(
                  _Violation(file, importPath, 'application 不能依赖 $root'),
                );
              }
            }
          }
          for (final package in forbiddenPackages) {
            if (importPath.startsWith(package)) {
              violations.add(
                _Violation(file, importPath, 'application 不能依赖技术包 $package'),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('infrastructure 不依赖 UI/app 层', () {
      final violations = <_Violation>[];
      const forbiddenRoots = <String>[
        'feature/',
        'app/',
        'widget/',
        'design_system/',
      ];

      for (final file in _dartFiles('lib/infrastructure')) {
        for (final importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target == null) continue;
          for (final root in forbiddenRoots) {
            if (target.startsWith(root)) {
              violations.add(
                _Violation(file, importPath, 'infrastructure 不能依赖 $root'),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('feature/widget 不直接依赖 domain/infrastructure/data', () {
      final violations = <_Violation>[];
      const forbiddenRoots = <String>['domain/', 'infrastructure/', 'data/'];

      for (final rootPath in ['lib/feature', 'lib/widget']) {
        for (final file in _dartFiles(rootPath)) {
          for (final importPath in _importPaths(file)) {
            final target = _libPathForImport(file, importPath);
            if (target == null) continue;
            for (final root in forbiddenRoots) {
              if (target.startsWith(root)) {
                violations.add(
                  _Violation(file, importPath, 'UI 层不能直接依赖 $root'),
                );
              }
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('ledger domain 不依赖 credit domain', () {
      final violations = <_Violation>[];
      for (final file in _dartFiles('lib/domain/ledger')) {
        for (final importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath) ?? importPath;
          if (target.contains('domain/credit/')) {
            violations.add(_Violation(file, importPath, 'ledger 不能依赖 credit'));
          }
        }
      }
      _assertClean(violations);
    });
  });
}

String? _libPathForImport(File file, String importPath) {
  if (importPath.startsWith('dart:')) return null;
  if (importPath.startsWith('package:')) {
    const prefix = 'package:smartflow/';
    if (!importPath.startsWith(prefix)) return null;
    return importPath.substring(prefix.length);
  }

  final resolved = file.parent.uri.resolve(importPath).toFilePath();
  final normalized = resolved.replaceAll('\\', '/');
  final markerIndex = normalized.lastIndexOf('/lib/');
  if (markerIndex < 0) return null;
  return normalized.substring(markerIndex + '/lib/'.length);
}

Iterable<File> _dartFiles(String path) sync* {
  final dir = Directory(path);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;
    yield entity;
  }
}

Iterable<String> _importPaths(File file) sync* {
  final pattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');
  for (final line in file.readAsLinesSync()) {
    final match = pattern.firstMatch(line);
    if (match != null) {
      yield match.group(1)!;
    }
  }
}

class _Violation {
  _Violation(this.file, this.importPath, this.reason);

  final File file;
  final String importPath;
  final String reason;

  @override
  String toString() =>
      '  x ${file.path}\n    import "$importPath"\n    -> $reason';
}

void _assertClean(List<_Violation> violations) {
  if (violations.isEmpty) return;
  final detail = violations.map((_Violation v) => v.toString()).join('\n');
  fail('发现 ${violations.length} 处 import 越界：\n$detail');
}
