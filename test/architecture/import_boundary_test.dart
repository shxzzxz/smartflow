// 业务域 import 边界守护测试。
//
// 强制约束（参见 docs/08.1 业务域划分与账务核心独立性）：
//
// 1. 账务核心（domain/accounting）不得 import 其它业务域；
// 2. 其它业务域只能 import accounting 的对外面：
//      accounting_api.dart；
//    不得 import 内部目录：entities / enums / services / repositories / ledger；
// 3. 兄弟业务域之间不得互相 import；
// 4. data/<域> 遵循同样规则；
// 5. domain/ 不得 import features / app / data（依赖反转：domain 是最内核）；
// 6. core/ 不得依赖任何业务层。
//
// 违反任意一条 → 该 case 失败，CI 阻断。
//
// 新增业务域时：把名字追加到 `_businessDomains`；其它逻辑自动生效。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> _businessDomains = <String>[
  'accounting',
  'credit',
  'budgeting',
  'analytics',
];

const String _kernel = 'accounting';

const String _accountingApi = 'domain/accounting/accounting_api.dart';

void main() {
  group('业务域 import 边界', () {
    test('账务核心 domain 不 import 其它业务域', () {
      final List<_Violation> violations = <_Violation>[];
      for (final File file in _dartFiles('lib/domain/$_kernel')) {
        for (final String importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath) ?? importPath;
          for (final String other in _businessDomains) {
            if (other == _kernel) continue;
            if (target.contains('domain/$other/')) {
              violations.add(
                _Violation(file, importPath, '账务核心不能依赖业务域 "$other"'),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('账务核心 data 不 import 其它业务域 data', () {
      final List<_Violation> violations = <_Violation>[];
      for (final File file in _dartFiles('lib/data/$_kernel')) {
        for (final String importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath) ?? importPath;
          for (final String other in _businessDomains) {
            if (other == _kernel) continue;
            if (target.contains('data/$other/')) {
              violations.add(
                _Violation(
                  file,
                  importPath,
                  '账务核心 data 不能依赖业务域 "$other" 的 data',
                ),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('其它业务域 domain 只 import accounting_api.dart', () {
      final List<_Violation> violations = <_Violation>[];
      for (final String bc in _businessDomains) {
        if (bc == _kernel) continue;
        for (final File file in _dartFiles('lib/domain/$bc')) {
          for (final String importPath in _importPaths(file)) {
            final target = _libPathForImport(file, importPath);
            if (target == null || !target.contains('domain/$_kernel/')) {
              continue;
            }
            if (target != _accountingApi) {
              violations.add(
                _Violation(
                  file,
                  importPath,
                  '业务域 "$bc" 只能通过 accounting_api.dart 使用账务核心',
                ),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('兄弟业务域 domain 之间不互相 import', () {
      final List<_Violation> violations = <_Violation>[];
      for (final String bc in _businessDomains) {
        if (bc == _kernel) continue;
        for (final File file in _dartFiles('lib/domain/$bc')) {
          for (final String importPath in _importPaths(file)) {
            final target = _libPathForImport(file, importPath) ?? importPath;
            for (final String other in _businessDomains) {
              if (other == _kernel || other == bc) continue;
              if (target.contains('domain/$other/')) {
                violations.add(
                  _Violation(
                    file,
                    importPath,
                    '业务域 "$bc" 不能 import 兄弟业务域 "$other"',
                  ),
                );
              }
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('兄弟业务域 data 之间不互相 import', () {
      final List<_Violation> violations = <_Violation>[];
      for (final String bc in _businessDomains) {
        if (bc == _kernel) continue;
        for (final File file in _dartFiles('lib/data/$bc')) {
          for (final String importPath in _importPaths(file)) {
            final target = _libPathForImport(file, importPath) ?? importPath;
            for (final String other in _businessDomains) {
              if (other == _kernel || other == bc) continue;
              if (target.contains('data/$other/')) {
                violations.add(
                  _Violation(
                    file,
                    importPath,
                    '业务域 "$bc" data 不能 import 兄弟业务域 "$other" 的 data',
                  ),
                );
              }
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('domain/ 不依赖外层（features / app / data）', () {
      const List<String> forbiddenRoots = <String>[
        'features/',
        'app/',
        'data/',
        'widgets/',
        'design_system/',
      ];
      final List<_Violation> violations = <_Violation>[];
      for (final File file in _dartFiles('lib/domain')) {
        for (final String importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target == null) continue;
          for (final String root in forbiddenRoots) {
            if (target.startsWith(root)) {
              violations.add(
                _Violation(file, importPath, 'domain/ 不能反向依赖外层 "$root"'),
              );
              break;
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('core/ 不依赖任何业务层', () {
      const List<String> forbiddenRoots = <String>[
        'domain/',
        'data/',
        'features/',
        'app/',
        'widgets/',
        'design_system/',
      ];
      final List<_Violation> violations = <_Violation>[];
      for (final File file in _dartFiles('lib/core')) {
        for (final String importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target == null) continue;
          for (final String root in forbiddenRoots) {
            if (target.startsWith(root)) {
              violations.add(
                _Violation(file, importPath, 'core/ 不能依赖业务层 "$root"'),
              );
              break;
            }
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

/// 收集目录下所有 .dart 源文件（跳过生成代码）。
Iterable<File> _dartFiles(String path) sync* {
  final Directory dir = Directory(path);
  if (!dir.existsSync()) return;
  for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;
    yield entity;
  }
}

/// 提取文件所有 import 语句中的 URI。
Iterable<String> _importPaths(File file) sync* {
  final RegExp pattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');
  for (final String line in file.readAsLinesSync()) {
    final RegExpMatch? match = pattern.firstMatch(line);
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
      '  ✗ ${file.path}\n    import "$importPath"\n    → $reason';
}

void _assertClean(List<_Violation> violations) {
  if (violations.isEmpty) return;
  final String detail = violations
      .map((_Violation v) => v.toString())
      .join('\n');
  fail('发现 ${violations.length} 处业务域 import 越界：\n$detail');
}
