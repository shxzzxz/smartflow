import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';

void main() {
  group('BackupService', () {
    late Directory tempDirectory;
    late FakeBackupGateway gateway;
    late BackupService service;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync(
        'smartflow-backup-test-',
      );
      gateway = FakeBackupGateway(_emptySnapshot());
      service = BackupService(
        gateway: gateway,
        packageStore: const FileBackupPackageStore(),
        appVersion: 'test',
      );
    });

    tearDown(() => tempDirectory.delete(recursive: true));

    test('exports and inspects a complete multi-file snapshot', () async {
      final manifest = await service.createBackup(tempDirectory);

      expect(manifest.files.length, BackupTables.all.length + 1);
      expect(
        await File('${tempDirectory.path}/manifest.json').exists(),
        isTrue,
      );
      expect(
        await File('${tempDirectory.path}/ledger/accounts.ndjson').exists(),
        isTrue,
      );
      final inspected = await service.inspect(tempDirectory);
      expect(inspected.manifest.backupId, manifest.backupId);
      expect(
        inspected.manifest.backupSchemaVersion,
        BackupManifest.currentBackupSchemaVersion,
      );
      expect(inspected.manifest.schemaVersion, 61);
      expect(inspected.snapshot.preferences['settings.example'], 'true');
    });

    test('rejects a file after its bytes change', () async {
      await service.createBackup(tempDirectory);
      final file = File('${tempDirectory.path}/ledger/accounts.ndjson');
      await file.writeAsString('{"id":"tampered"}\n');

      expect(
        () => service.inspect(tempDirectory),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test(
      'uses the backup contract instead of the source database version',
      () async {
        final oldDirectory = Directory('${tempDirectory.path}/v60-backup')
          ..createSync();
        final v60Service = BackupService(
          gateway: FakeBackupGateway(_emptySnapshot(), schemaVersion: 60),
          packageStore: const FileBackupPackageStore(),
        );
        await v60Service.createBackup(oldDirectory);
        final v61Gateway = FakeBackupGateway(
          BackupSnapshot(),
          schemaVersion: 61,
        );
        final v61Service = BackupService(
          gateway: v61Gateway,
          packageStore: const FileBackupPackageStore(),
        );

        final inspection = await v61Service.inspect(oldDirectory);
        final diff = await v61Service.restore(oldDirectory);

        expect(
          inspection.manifest.backupSchemaVersion,
          BackupManifest.currentBackupSchemaVersion,
        );
        expect(inspection.manifest.schemaVersion, 60);
        expect(diff.itemFor('preferences').added, 1);
        expect(v61Gateway.replaceCount, 1);
      },
    );

    test('migrates the v9 release backup baseline', () async {
      gateway.snapshot = _emptySnapshot(
        tables: {
          'insured_people': [
            {
              'id': 'person-1',
              'name': '张三',
              'birthDate': '1990-06-15T00:00:00.000',
              'relationship': 'self',
              'gender': 'unknown',
              'note': null,
              'avatarPreset': 'male',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        },
      );
      await service.createBackup(tempDirectory);
      await _removeBackupTable(tempDirectory, 'insured_people');
      await _addBackupTable(tempDirectory, 'insured_people', [
        {
          ...gateway.snapshot.rows('insured_people').single,
          'avatarPreset': 'blue',
        },
      ]);
      for (final table in const [
        'social_insurances',
        'social_contribution_records',
      ]) {
        await _removeBackupTable(tempDirectory, table);
      }
      await _addBackupTable(tempDirectory, 'social_medical_insurances', [
        {
          'id': 'medical-1',
          'insuredPersonId': 'person-1',
          'region': '上海',
          'participantType': 'employee',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ]);
      await _addBackupTable(
        tempDirectory,
        'social_medical_contribution_records',
        [
          {
            'socialMedicalInsuranceId': 'medical-1',
            'yearMonth': '2026-01',
            'contributionBaseMinor': 800000,
          },
        ],
      );
      await _addBackupTable(tempDirectory, 'social_pension_insurances', []);
      await _addBackupTable(
        tempDirectory,
        'social_pension_contribution_records',
        [],
      );
      await _rewriteBackupSchemaVersion(tempDirectory, 9);

      final inspection = await service.inspect(tempDirectory);

      expect(inspection.manifest.backupSchemaVersion, 9);
      expect(
        inspection.snapshot.rows('insured_people').single['avatarPreset'],
        'male',
      );
      final social = inspection.snapshot.rows('social_insurances').single;
      expect(social['insuranceType'], 'medical');
      expect(social['insuredPersonId'], 'person-1');
      final contribution = inspection.snapshot
          .rows('social_contribution_records')
          .single;
      expect(contribution['socialInsuranceId'], 'medical-1');
      expect(
        inspection.snapshot.tables,
        isNot(contains('social_medical_insurances')),
      );
    });

    test('migrates v12 contributions without inventing paid amounts', () async {
      gateway.snapshot = _emptySnapshot(
        tables: {
          'insured_people': [
            {
              'id': 'person-1',
              'name': '示例成员',
              'birthDate': '1990-01-01T00:00:00.000',
              'relationship': 'self',
              'gender': 'unknown',
              'note': null,
              'avatarPreset': 'male',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
          'social_insurances': [
            {
              'id': 'social-1',
              'insuredPersonId': 'person-1',
              'region': '浙江省 / 杭州市',
              'insuranceType': 'medical',
              'participantType': 'employee',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        },
      );
      await service.createBackup(tempDirectory);
      await _removeBackupTable(tempDirectory, 'social_contribution_records');
      await _addBackupTable(tempDirectory, 'social_contribution_records', [
        {
          'socialInsuranceId': 'social-1',
          'yearMonth': '2026-01',
          'contributionBaseMinor': 800000,
        },
        {
          'socialInsuranceId': 'social-1',
          'yearMonth': '2026-02',
          'contributionBaseMinor': 820000,
        },
      ]);
      await _rewriteBackupSchemaVersion(tempDirectory, 12);
      final inspection = await service.inspect(tempDirectory);
      final records = inspection.snapshot
          .rows('social_contribution_records')
          .toList();
      expect(records.map((row) => row['period']), ['2026-01', '2026-02']);
      expect(records.map((row) => row['contributionBaseMinor']), [
        800000,
        820000,
      ]);
      expect(
        records.every((row) => row['contributionAmountMinor'] == null),
        isTrue,
      );
      expect(records.every((row) => !row.containsKey('yearMonth')), isTrue);
      await service.restore(tempDirectory);
      expect(
        gateway.snapshot.rows('social_contribution_records'),
        hasLength(2),
      );
    });

    test(
      'migrates v13 responsibility codes and preserves names and points',
      () async {
        gateway.snapshot = _emptySnapshot(
          tables: {
            'insured_people': [
              {
                'id': 'person-1',
                'name': '示例成员',
                'birthDate': '1990-01-01T00:00:00.000',
                'relationship': 'self',
                'gender': 'unknown',
                'avatarPreset': 'male',
              },
            ],
            'commercial_insurances': [
              {
                'id': 'policy-1',
                'name': '示例寿险',
                'insurerName': '示例保险',
                'category': 'life',
                'coverageStartDate': '2026-01-01T00:00:00.000',
                'coverageEndDate': null,
                'lifetime': true,
                'premiumFrequency': null,
              },
            ],
            'commercial_insurance_insured_people': [
              {
                'commercialInsuranceId': 'policy-1',
                'insuredPersonId': 'person-1',
              },
            ],
          },
        );
        await service.createBackup(tempDirectory);
        const legacyResponsibilities = [
          ('medical', '一般医疗'),
          ('criticalIllness', '重疾医疗'),
          ('accident', '意外身故'),
          ('life', '身故'),
          ('disability', '全残'),
          ('other', '住院津贴'),
        ];
        await _removeBackupTable(tempDirectory, 'coverage_responsibilities');
        await _addBackupTable(tempDirectory, 'coverage_responsibilities', [
          for (var index = 0; index < legacyResponsibilities.length; index++)
            {
              'id': 'responsibility-$index',
              'commercialInsuranceId': 'policy-1',
              'kind': legacyResponsibilities[index].$1,
              'name': legacyResponsibilities[index].$2,
              'sortOrder': index,
            },
        ]);
        const points = [
          {
            'id': 'point-1',
            'responsibilityId': 'responsibility-1',
            'label': '医院范围',
            'value': '二级及以上公立医院普通部',
            'sortOrder': 1,
          },
          {
            'id': 'point-2',
            'responsibilityId': 'responsibility-1',
            'label': '免赔额',
            'value': '0 元',
            'sortOrder': 0,
          },
        ];
        await _removeBackupTable(tempDirectory, 'responsibility_points');
        await _addBackupTable(tempDirectory, 'responsibility_points', points);
        await _rewriteBackupSchemaVersion(tempDirectory, 13);

        final inspection = await service.inspect(tempDirectory);
        final responsibilities = inspection.snapshot
            .rows('coverage_responsibilities')
            .toList();
        expect(responsibilities.map((row) => row['kind']), [
          'medical',
          'other',
          'other',
          'other',
          'disability',
          'other',
        ]);
        expect(
          responsibilities.map((row) => row['name']),
          legacyResponsibilities.map((item) => item.$2),
        );
        expect(responsibilities.map((row) => row['sortOrder']), [
          0,
          1,
          2,
          3,
          4,
          5,
        ]);
        expect(
          responsibilities.every(
            (row) =>
                row.containsKey('description') && row['description'] == null,
          ),
          isTrue,
        );
        expect(inspection.snapshot.rows('responsibility_points'), points);
        expect(
          inspection.snapshot.rows('commercial_insurances').single['category'],
          'life',
        );

        gateway.snapshot = BackupSnapshot();
        await service.restore(tempDirectory);
        expect(
          gateway.snapshot.rows('coverage_responsibilities'),
          responsibilities,
        );
        expect(gateway.snapshot.rows('responsibility_points'), points);
      },
    );

    test(
      'v14 contract information stays unrecorded and other facts survive restore',
      () async {
        gateway.snapshot = _emptySnapshot(
          tables: {
            'insured_people': [
              {
                'id': 'person-1',
                'name': '示例成员',
                'birthDate': '1990-01-01T00:00:00.000',
                'relationship': 'self',
                'gender': 'unknown',
                'avatarPreset': 'male',
              },
            ],
            'commercial_insurances': [
              {
                'id': 'policy-1',
                'name': '保留保单',
                'insurerName': '示例保险',
                'category': 'medical',
                'coverageStartDate': '2026-01-01T00:00:00.000',
                'coverageEndDate': null,
                'lifetime': true,
                'premiumFrequency': null,
                'coverageAmountMinor': 12340000,
                'coverageSummary': '保留保障总结',
              },
            ],
            'commercial_insurance_insured_people': [
              {
                'commercialInsuranceId': 'policy-1',
                'insuredPersonId': 'person-1',
              },
            ],
            'coverage_responsibilities': [
              {
                'id': 'responsibility-1',
                'commercialInsuranceId': 'policy-1',
                'kind': 'medical',
                'name': '一般医疗',
                'description': '保留责任说明',
                'sortOrder': 0,
              },
            ],
            'responsibility_points': [
              {
                'id': 'point-1',
                'responsibilityId': 'responsibility-1',
                'label': '等待期',
                'value': '特别约定15天',
                'sortOrder': 0,
              },
            ],
          },
        );
        await service.createBackup(tempDirectory);
        await _rewriteBackupSchemaVersion(tempDirectory, 14);
        final inspection = await service.inspect(tempDirectory);
        final policy = inspection.snapshot.rows('commercial_insurances').single;
        for (final key in const [
          'policyholderName',
          'beneficiaryDescription',
          'waitingPeriodDescription',
          'exclusionsDescription',
        ]) {
          expect(policy, contains(key));
          expect(policy[key], isNull);
        }
        expect(policy, isNot(contains('preExistingConditionDescription')));
        expect(policy['coverageAmountMinor'], 12340000);
        expect(policy['coverageSummary'], '保留保障总结');
        expect(
          inspection.snapshot
              .rows('coverage_responsibilities')
              .single['description'],
          '保留责任说明',
        );
        expect(
          inspection.snapshot.rows('responsibility_points').single['value'],
          '特别约定15天',
        );
        gateway.snapshot = BackupSnapshot();
        await service.restore(tempDirectory);
        expect(gateway.snapshot.rows('commercial_insurances').single, policy);
        expect(
          gateway.snapshot.rows('responsibility_points').single['value'],
          '特别约定15天',
        );
      },
    );

    const exclusionCases = <(String?, String?, String?)>[
      (null, null, null),
      ('既往症相关约定', null, '既往症相关约定'),
      (null, '指定疾病除外', '指定疾病除外'),
      ('既往症相关约定', '指定疾病除外', '既往症相关约定\n指定疾病除外'),
      ('  同一除外约定  ', '同一除外约定', '同一除外约定'),
      (' \t\r\n ', null, null),
      ('既往症一\n既往症二', '除外一\n除外二', '既往症一\n既往症二\n除外一\n除外二'),
    ];
    for (final (index, values) in exclusionCases.indexed) {
      test(
        'v15 backup merges exclusions into one field (case $index)',
        () async {
          final (legacy, exclusions, expected) = values;
          gateway.snapshot = _emptySnapshot(
            tables: {
              'insured_people': [
                {
                  'id': 'person-1',
                  'name': '示例成员',
                  'birthDate': '1990-01-01T00:00:00.000',
                  'relationship': 'self',
                  'gender': 'unknown',
                  'avatarPreset': 'male',
                },
              ],
              'commercial_insurances': [
                {
                  'id': 'policy-1',
                  'name': '保留保单',
                  'insurerName': '示例保险',
                  'category': 'medical',
                  'coverageStartDate': '2026-01-01T00:00:00.000',
                  'coverageEndDate': null,
                  'lifetime': true,
                  'premiumFrequency': null,
                  'waitingPeriodDescription': '30天',
                  'coverageSummary': '保留保障概要',
                  'preExistingConditionDescription': legacy,
                  'exclusionsDescription': exclusions,
                },
              ],
              'commercial_insurance_insured_people': [
                {
                  'commercialInsuranceId': 'policy-1',
                  'insuredPersonId': 'person-1',
                },
              ],
            },
          );
          await service.createBackup(tempDirectory);
          await _rewriteBackupSchemaVersion(tempDirectory, 15);
          final inspection = await service.inspect(tempDirectory);
          final policy = inspection.snapshot
              .rows('commercial_insurances')
              .single;
          expect(policy, isNot(contains('preExistingConditionDescription')));
          expect(policy['exclusionsDescription'], expected);
          expect(policy['waitingPeriodDescription'], '30天');
          expect(policy['coverageSummary'], '保留保障概要');
          gateway.snapshot = _emptySnapshot();
          await service.restore(tempDirectory);
          expect(gateway.snapshot.rows('commercial_insurances').single, policy);
        },
      );
    }

    test(
      'v15 invalid legacy text fails before replacing existing data',
      () async {
        gateway.snapshot = _emptySnapshot(
          tables: {
            'insured_people': [
              {
                'id': 'person-1',
                'name': '示例成员',
                'birthDate': '1990-01-01T00:00:00.000',
                'relationship': 'self',
                'gender': 'unknown',
                'avatarPreset': 'male',
              },
            ],
            'commercial_insurances': [
              {
                'id': 'policy-1',
                'name': '保留保单',
                'insurerName': '示例保险',
                'category': 'medical',
                'coverageStartDate': '2026-01-01T00:00:00.000',
                'coverageEndDate': null,
                'lifetime': true,
                'premiumFrequency': null,
                'preExistingConditionDescription': 42,
                'exclusionsDescription': null,
              },
            ],
            'commercial_insurance_insured_people': [
              {
                'commercialInsuranceId': 'policy-1',
                'insuredPersonId': 'person-1',
              },
            ],
          },
        );
        await service.createBackup(tempDirectory);
        await _rewriteBackupSchemaVersion(tempDirectory, 15);
        gateway.snapshot = _emptySnapshot();
        await expectLater(
          () => service.restore(tempDirectory),
          throwsA(isA<BackupValidationException>()),
        );
        expect(gateway.snapshot.rows('commercial_insurances'), isEmpty);
      },
    );

    test('v16 member avatars migrate and survive a current backup', () async {
      const cases = <(String, String, String, String)>[
        ('self', 'male', 'blue', 'male'),
        ('self', 'female', 'green', 'female'),
        ('self', 'unknown', 'orange', 'male'),
        ('spouse', 'male', 'pink', 'male'),
        ('spouse', 'female', 'purple', 'female'),
        ('spouse', 'unknown', 'teal', 'male'),
        ('parent', 'male', 'green', 'father'),
        ('parent', 'female', 'orange', 'mother'),
        ('parent', 'unknown', 'pink', 'male'),
        ('child', 'male', 'purple', 'son'),
        ('child', 'female', 'teal', 'daughter'),
        ('child', 'unknown', 'blue', 'male'),
        ('other', 'male', 'orange', 'male'),
        ('other', 'female', 'pink', 'female'),
        ('other', 'unknown', 'purple', 'male'),
        ('parent', 'male', 'sister', 'sister'),
        ('spouse', 'female', 'brother', 'brother'),
      ];
      final legacyPeople = [
        for (final (index, values) in cases.indexed)
          {
            'id': 'member-$index',
            'name': '保留成员$index',
            'birthDate': '1990-06-15T00:00:00.000',
            'relationship': values.$1,
            'gender': values.$2,
            'note': '保留备注',
            'avatarPreset': values.$3,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
      ];
      await service.createBackup(tempDirectory);
      await _removeBackupTable(tempDirectory, 'insured_people');
      await _addBackupTable(tempDirectory, 'insured_people', legacyPeople);
      await _rewriteBackupSchemaVersion(tempDirectory, 16);

      final inspection = await service.inspect(tempDirectory);
      final expectedPeople = [
        for (final (index, person) in legacyPeople.indexed)
          {...person, 'avatarPreset': cases[index].$4},
      ];
      expect(inspection.snapshot.rows('insured_people'), expectedPeople);
      await service.restore(tempDirectory);
      expect(gateway.snapshot.rows('insured_people'), expectedPeople);

      final currentDirectory = Directory('${tempDirectory.path}/current')
        ..createSync();
      await service.createBackup(currentDirectory);
      gateway.snapshot = _emptySnapshot();
      await service.restore(currentDirectory);
      expect(gateway.snapshot.rows('insured_people'), expectedPeople);
    });

    test('v16 invalid avatars fail before replacing existing data', () async {
      const person = {
        'id': 'person-1',
        'name': '保留成员',
        'birthDate': '1990-06-15T00:00:00.000',
        'relationship': 'parent',
        'gender': 'male',
        'avatarPreset': 'sister',
      };
      gateway.snapshot = _emptySnapshot(
        tables: {
          'insured_people': [person],
        },
      );
      await service.createBackup(tempDirectory);
      await _removeBackupTable(tempDirectory, 'insured_people');
      await _addBackupTable(tempDirectory, 'insured_people', [
        {...person, 'avatarPreset': 'missing'},
      ]);
      await _rewriteBackupSchemaVersion(tempDirectory, 16);

      await expectLater(
        () => service.restore(tempDirectory),
        throwsA(isA<BackupValidationException>()),
      );
      expect(gateway.replaceCount, 0);
      expect(gateway.snapshot.rows('insured_people'), [person]);
    });

    test('migrates a v10 backup with an empty reconciliation table', () async {
      await service.createBackup(tempDirectory);
      await _removeBackupTable(
        tempDirectory,
        'account_reconciliation_snapshots',
      );
      await _rewriteBackupSchemaVersion(tempDirectory, 10);

      final inspection = await service.inspect(tempDirectory);

      expect(
        inspection.snapshot.rows('account_reconciliation_snapshots'),
        isEmpty,
      );
    });

    test('rejects obsolete backup format versions', () async {
      await service.createBackup(tempDirectory);
      final manifestFile = File('${tempDirectory.path}/manifest.json');
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      manifest['formatVersion'] = 2;
      await manifestFile.writeAsString(jsonEncode(manifest));

      expect(
        () => service.inspect(tempDirectory),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects backups before the v9 release baseline', () async {
      await service.createBackup(tempDirectory);
      await _rewriteBackupSchemaVersion(tempDirectory, 8);

      expect(
        () => service.inspect(tempDirectory),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.message,
            'message',
            contains('backupSchemaVersion 8'),
          ),
        ),
      );
    });

    test('rejects unsupported backup schema versions', () async {
      await service.createBackup(tempDirectory);
      final manifestFile = File('${tempDirectory.path}/manifest.json');
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      manifest['backupSchemaVersion'] =
          BackupManifest.currentBackupSchemaVersion + 1;
      await manifestFile.writeAsString(jsonEncode(manifest));

      expect(
        () => service.inspect(tempDirectory),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.message,
            'message',
            contains(
              'backupSchemaVersion ${BackupManifest.currentBackupSchemaVersion + 1}',
            ),
          ),
        ),
      );
    });

    test(
      'compares and restores the snapshot, while equal data is a no-op',
      () async {
        final manifest = await service.createBackup(tempDirectory);
        expect((await service.compare(tempDirectory)).isNoop, isTrue);

        final incoming = _emptySnapshot(
          accounts: [
            {
              'id': 'cash',
              'name': '现金',
              'accountType': 'asset',
              'accountSubtype': 'fund',
              'accountProfileKey': 'ledger.fund',
              'groupId': null,
              'parentId': null,
              'balanceMinor': 0,
              'iconKey': null,
              'note': null,
              'sortOrder': 0,
              'isHidden': false,
              'archivedAt': null,
              'systemKey': null,
              'source': 'user',
              'version': 0,
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        );
        final incomingDirectory = Directory('${tempDirectory.path}-incoming')
          ..createSync();
        addTearDown(() => incomingDirectory.delete(recursive: true));
        final incomingService = BackupService(
          gateway: FakeBackupGateway(incoming),
          packageStore: const FileBackupPackageStore(),
        );
        await incomingService.createBackup(incomingDirectory);
        gateway.snapshot = _emptySnapshot();
        final diff = await service.restore(incomingDirectory);
        expect(diff.itemFor('accounts').added, 1);
        expect(gateway.replaceCount, 1);
        expect(manifest.formatVersion, 4);
        expect(
          manifest.backupSchemaVersion,
          BackupManifest.currentBackupSchemaVersion,
        );
      },
    );

    test('backs up and restores user icon assets', () async {
      final assetStore = _MemoryBackupAssetStore({
        'business_icons/manifest.json': Uint8List.fromList(
          utf8.encode('{"schemaVersion":1,"icons":[]}'),
        ),
        'business_icons/icons/account/icon-1.png': Uint8List.fromList([
          1,
          2,
          3,
        ]),
      });
      final assetService = BackupService(
        gateway: gateway,
        packageStore: const FileBackupPackageStore(),
        assets: assetStore,
      );

      final manifest = await assetService.createBackup(tempDirectory);
      final inspection = await assetService.inspect(tempDirectory);

      expect(manifest.assetFiles, hasLength(2));
      expect(inspection.assets['business_icons/icons/account/icon-1.png'], [
        1,
        2,
        3,
      ]);

      assetStore.files = {
        'business_icons/manifest.json': Uint8List.fromList(
          utf8.encode('{"schemaVersion":1,"icons":[]}'),
        ),
      };
      final diff = await assetService.restore(tempDirectory);

      expect(diff.itemFor('business_icons').added, 1);
      expect(
        assetStore.files,
        contains('business_icons/icons/account/icon-1.png'),
      );
      expect(assetStore.restoreCount, 1);
    });

    test(
      'detects asset tampering and keeps format 3 backups readable',
      () async {
        final assetStore = _MemoryBackupAssetStore({
          'business_icons/manifest.json': Uint8List.fromList(
            utf8.encode('{"schemaVersion":1,"icons":[]}'),
          ),
        });
        final assetService = BackupService(
          gateway: gateway,
          packageStore: const FileBackupPackageStore(),
          assets: assetStore,
        );
        await assetService.createBackup(tempDirectory);
        final assetFile = File(
          '${tempDirectory.path}/business_icons/manifest.json',
        );
        await assetFile.writeAsBytes([9, 9, 9]);
        expect(
          () => assetService.inspect(tempDirectory),
          throwsA(isA<BackupValidationException>()),
        );

        await assetService.createBackup(tempDirectory);
        final manifestFile = File('${tempDirectory.path}/manifest.json');
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, Object?>;
        manifest
          ..['formatVersion'] = 3
          ..remove('assetFiles');
        await manifestFile.writeAsString(jsonEncode(manifest));

        final legacy = await assetService.inspect(tempDirectory);
        expect(legacy.manifest.formatVersion, 3);
        expect(legacy.assets, isEmpty);
      },
    );
  });

  test('rejects dangling references and unbalanced account balances', () {
    final snapshot = _emptySnapshot(
      transactions: [
        {
          'id': 'tx',
          'businessPurpose': 'dailyExpense',
          'occurredAt': '2026-01-01T00:00:00.000Z',
          'postedAt': '2026-01-01T00:00:00.000Z',
          'primaryAmountMinor': 100,
          'counterpartyId': null,
          'note': null,
          'parentTransactionId': null,
          'isExcludedFromStats': false,
          'isExcludedFromBudget': false,
          'sourceKind': 'manual',
          'ownerType': null,
          'ownerId': null,
          'ownerRole': null,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      entries: [
        {
          'id': 'entry',
          'transactionId': 'tx',
          'accountId': 'missing',
          'direction': 'debit',
          'amountMinor': 100,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    );

    expect(
      () => BackupService.validateSnapshot(snapshot),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects account parent cycles and counts preference diffs by key', () {
    final cyclic = _emptySnapshot(
      accounts: [
        {'id': 'a', 'groupId': null, 'parentId': 'b', 'balanceMinor': 0},
        {'id': 'b', 'groupId': null, 'parentId': 'a', 'balanceMinor': 0},
      ],
    );
    expect(
      () => BackupService.validateSnapshot(cyclic),
      throwsA(isA<BackupValidationException>()),
    );

    final current = BackupSnapshot(preferences: const {'a': '1', 'b': '2'});
    final incoming = BackupSnapshot(preferences: const {'a': '3', 'c': '4'});
    final diff = BackupDiff.compare(current, incoming);
    final preferences = diff.itemFor('preferences');
    expect(preferences.added, 1);
    expect(preferences.removed, 1);
    expect(preferences.changed, 1);
  });

  test('allows historical import items whose transaction was deleted', () {
    final snapshot = _emptySnapshot();
    final withHistory = snapshot.copyWith(
      tables: {
        ...snapshot.tables,
        'import_batches': [
          {
            'id': 'batch',
            'source': 'yimu',
            'status': 'reverted',
            'importedGroupCount': 1,
            'createdTransactionCount': 1,
            'skippedGroupCount': 0,
            'importedAt': '2026-01-01T00:00:00.000Z',
            'revertedAt': '2026-01-02T00:00:00.000Z',
          },
        ],
        'import_batch_items': [
          {
            'id': 'item',
            'batchId': 'batch',
            'sourceOperationKey': null,
            'sourceOperationFingerprint': 'fingerprint',
            'fingerprintVersion': 1,
            'topLevelTransactionId': 'deleted-transaction',
          },
        ],
      },
    );

    expect(() => BackupService.validateSnapshot(withHistory), returnsNormally);
  });

  test('allows unavailable import mapping and budget targets', () {
    final snapshot = _emptySnapshot(
      tables: {
        'import_entity_mappings': [
          {
            'id': 'mapping',
            'source': 'yimu',
            'entityKind': 'account',
            'sourceEntityKey': 'account:deleted',
            'targetAccountId': 'deleted-account',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'budgets': [
          {
            'id': 'budget',
            'monthKey': 202601,
            'accountId': 'deleted-category',
            'amountMinor': 100,
            'sortOrder': 0,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      },
    );

    expect(() => BackupService.validateSnapshot(snapshot), returnsNormally);
  });
}

class _MemoryBackupAssetStore implements BackupAssetStore {
  _MemoryBackupAssetStore(this.files);

  Map<String, Uint8List> files;
  var restoreCount = 0;

  @override
  Future<Map<String, Uint8List>> exportBackupFiles() async => {
    for (final entry in files.entries)
      entry.key: Uint8List.fromList(entry.value),
  };

  @override
  Future<void> restoreBackupFiles(Map<String, Uint8List> files) async {
    restoreCount++;
    this.files = {
      for (final entry in files.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
  }
}

BackupSnapshot _emptySnapshot({
  Iterable<BackupJson> accounts = const [],
  Iterable<BackupJson> transactions = const [],
  Iterable<BackupJson> entries = const [],
  Map<String, List<BackupJson>>? tables,
}) {
  return BackupSnapshot(
    tables: {
      'accounts': accounts,
      'transactions': transactions,
      'entries': entries,
      ...?tables,
    },
    preferences: const {'settings.example': 'true'},
  );
}

class FakeBackupGateway implements BackupSnapshotGateway {
  FakeBackupGateway(this.snapshot, {this.schemaVersion = 61});

  BackupSnapshot snapshot;
  int replaceCount = 0;

  @override
  final int schemaVersion;

  @override
  Future<BackupSnapshot> readSnapshot() async => snapshot;

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) async {
    replaceCount++;
    this.snapshot = snapshot;
  }
}

Future<void> _rewriteBackupSchemaVersion(
  Directory directory,
  int version,
) async {
  final file = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, Object?>;
  manifest['backupSchemaVersion'] = version;
  await file.writeAsString(jsonEncode(manifest));
}

Future<void> _addBackupTable(
  Directory directory,
  String table,
  List<Map<String, Object?>> rows,
) async {
  final path = '${BackupTables.sectionFor(table)}/$table.ndjson';
  final file = File('${directory.path}/$path');
  file.parent.createSync(recursive: true);
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer.writeln(jsonEncode(row));
  }
  final bytes = utf8.encode(buffer.toString());
  await file.writeAsBytes(bytes);

  final manifestFile = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
  final files = (manifest['requiredFiles'] as List).cast<Map>();
  files.add({
    'path': path,
    'table': table,
    'rowCount': rows.length,
    'byteCount': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  });
  await manifestFile.writeAsString(jsonEncode(manifest));
}

Future<void> _removeBackupTable(Directory directory, String table) async {
  final file = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final files = (manifest['requiredFiles'] as List).cast<Map>();
  Map? removed;
  files.removeWhere((entry) {
    if (entry['table'] != table) return false;
    removed = entry;
    return true;
  });
  if (removed == null) {
    throw StateError('Backup table $table was not found.');
  }
  final path = removed!['path'] as String;
  await File('${directory.path}/$path').delete();
  await file.writeAsString(jsonEncode(manifest));
}
