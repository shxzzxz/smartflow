// 顶层分层 import 边界守护测试。
//
// 约束目标：
// - domain 不依赖 application / infrastructure / feature / app / Flutter UI / Drift / Riverpod。
// - application 可依赖 domain 和 core，不依赖 infrastructure / feature / app。
// - infrastructure 可依赖 application、domain、core，不依赖 feature / app。
// - feature 和 widget 可引用稳定领域值类型，但不直接依赖 domain service / port / infrastructure。
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

    test('feature/widget 不直接依赖领域实现或 infrastructure', () {
      final violations = <_Violation>[];

      for (final rootPath in ['lib/feature', 'lib/widget']) {
        for (final file in _dartFiles(rootPath)) {
          for (final importPath in _importPaths(file)) {
            final target = _libPathForImport(file, importPath);
            if (target == null) continue;
            final dependsOnDomainImplementation = RegExp(
              r'^domain/[^/]+/(service|port)/',
            ).hasMatch(target);
            if (target.startsWith('infrastructure/') ||
                dependsOnDomainImplementation) {
              violations.add(
                _Violation(file, importPath, 'UI 层不能直接依赖领域实现或基础设施'),
              );
            }
          }
        }
      }
      _assertClean(violations);
    });

    test('feature/widget 通过信贷 application facade 访问信贷实现', () {
      final violations = <_Violation>[];
      const forbiddenRoots = <String>[
        'domain/credit/service/',
        'domain/credit/port/',
        'infrastructure/credit/',
      ];
      const allowedApplicationFacades = <String>{
        'application/credit/credit_command_api.dart',
        'application/credit/credit_query_api.dart',
      };

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
            if (target.startsWith('application/credit/') &&
                !allowedApplicationFacades.contains(target)) {
              violations.add(
                _Violation(file, importPath, 'UI 层访问信贷 application 必须经 facade'),
              );
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

    test('ledger domain 不编码账户画像身份', () {
      final violations = <_Violation>[];
      final profileIdentity = RegExp(
        r'''(?:ledger|credit)\.(?:fund|reimbursement|receivable|payable|credit|loan)''',
      );
      for (final file in _dartFiles('lib/domain/ledger')) {
        final content = file.readAsStringSync();
        for (final match in profileIdentity.allMatches(content)) {
          violations.add(
            _Violation(file, match.group(0)!, 'ledger domain 不能识别账户画像 key'),
          );
        }
      }
      _assertClean(violations);
    });

    test('credit application 不直接依赖 ledger application', () {
      final violations = <_Violation>[];
      for (final file in _dartFiles('lib/application/credit')) {
        for (final importPath in _importPaths(file)) {
          final target = _libPathForImport(file, importPath);
          if (target != null && target.startsWith('application/ledger/')) {
            violations.add(
              _Violation(
                file,
                importPath,
                'credit application 必须通过 credit domain port 访问 ledger',
              ),
            );
          }
        }
      }
      _assertClean(violations);
    });

    test('application facade 不转导 domain service 或 port', () {
      final violations = <_Violation>[];
      for (final file in _dartFiles('lib/application')) {
        if (!file.path.endsWith('_api.dart')) continue;
        for (final exportPath in _exportPaths(file)) {
          final target = _libPathForImport(file, exportPath);
          if (target == null) continue;
          if (RegExp(r'^domain/[^/]+/(service|port)/').hasMatch(target)) {
            violations.add(
              _Violation(
                file,
                exportPath,
                'application facade 不能转导 domain service 或 port',
              ),
            );
          }
        }
      }
      _assertClean(violations);
    });

    test('feature provider 不直接读取 repository provider', () {
      final violations = <_Violation>[];
      final repositoryProviderPattern = RegExp(
        r'\b[A-Za-z0-9_]+RepositoryProvider\b',
      );
      for (final file in _dartFiles('lib/feature')) {
        if (!file.path.replaceAll('\\', '/').contains('/provider/')) continue;
        final content = file.readAsStringSync();
        for (final match in repositoryProviderPattern.allMatches(content)) {
          violations.add(
            _Violation(
              file,
              match.group(0)!,
              'feature provider 必须通过 application query 获取业务事实',
            ),
          );
        }
      }
      _assertClean(violations);
    });

    test('合同指标 query 不依赖实际还款事实', () {
      final file = File(
        'lib/application/credit/installment/query/contract_metrics_query.dart',
      );
      final violations = <_Violation>[];
      for (final importPath in _importPaths(file)) {
        final target = _libPathForImport(file, importPath);
        if (target == 'domain/credit/port/repayment_repository.dart' ||
            target == 'domain/credit/entity/repayment.dart') {
          violations.add(_Violation(file, importPath, '合同指标只依赖合同与计划现金流'));
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
  final normalized = File(resolved).absolute.path.replaceAll('\\', '/');
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

Iterable<String> _exportPaths(File file) sync* {
  final pattern = RegExp(r'''^\s*export\s+['"]([^'"]+)['"]''');
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
