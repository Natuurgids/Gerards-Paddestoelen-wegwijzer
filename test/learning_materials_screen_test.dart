import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_materials_service.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package_installer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/training/learning_materials_screen.dart';

void main() {
  Widget localizedApp(Widget home) => MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  testWidgets('unowned offering shows no fake purchase or price action', (
    tester,
  ) async {
    final service = _FakeMaterialsService(
      material: _material(entitled: false),
      purchasesConfigured: false,
      deliveryConfigured: false,
    );

    await tester.pumpWidget(
      localizedApp(
        LearningMaterialsScreen(
          locale: const Locale('nl'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boleten & poriën'), findsOneWidget);
    expect(find.text('Niet in bezit'), findsOneWidget);
    expect(find.textContaining('Aankopen zijn in deze build nog niet gekoppeld'), findsOneWidget);
    expect(find.text('Downloaden'), findsNothing);
    expect(find.text('Openen'), findsNothing);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('entitled offering can download when remote version is known', (
    tester,
  ) async {
    final service = _FakeMaterialsService(
      material: _material(entitled: true),
      purchasesConfigured: false,
      deliveryConfigured: true,
      remoteVersions: const {'boletes-pores': 2},
    );

    await tester.pumpWidget(
      localizedApp(
        LearningMaterialsScreen(
          locale: const Locale('nl'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In bezit'), findsOneWidget);
    expect(find.text('Downloaden'), findsOneWidget);

    await tester.tap(find.text('Downloaden'));
    await tester.pumpAndSettle();

    expect(service.installCalls, ['boletes-pores']);
    expect(find.text('Geïnstalleerd'), findsOneWidget);
    expect(find.text('Openen'), findsOneWidget);
  });

  testWidgets('installed offering stays open when remote catalogue fails', (
    tester,
  ) async {
    final service = _FakeMaterialsService(
      material: _material(
        entitled: true,
        installedVersion: 1,
        lessonIds: const {1000},
      ),
      purchasesConfigured: false,
      deliveryConfigured: true,
      throwRemote: true,
    );

    await tester.pumpWidget(
      localizedApp(
        LearningMaterialsScreen(
          locale: const Locale('nl'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Geïnstalleerd'), findsOneWidget);
    expect(find.text('Openen'), findsOneWidget);
    expect(
      find.textContaining('Online update-informatie is nu niet beschikbaar'),
      findsOneWidget,
    );
  });

  testWidgets('legacy installed state offers repair instead of open', (
    tester,
  ) async {
    final service = _FakeMaterialsService(
      material: _material(entitled: true, installedVersion: 1),
      purchasesConfigured: false,
      deliveryConfigured: true,
      remoteVersions: const {'boletes-pores': 1},
    );

    await tester.pumpWidget(
      localizedApp(
        LearningMaterialsScreen(
          locale: const Locale('nl'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Installatie moet worden hersteld'), findsOneWidget);
    expect(find.text('Herstellen'), findsOneWidget);
    expect(find.text('Openen'), findsNothing);
  });
}

const _offering = LearningOffering(
  packageKey: 'boletes-pores',
  courseKey: 'specialist-boletes-pores',
  entitlementKey: 'learning.specialist.boletes-pores',
  productKey: 'learning_pack_boletes_pores',
  groupKey: 'specializations',
  sortOrder: 110,
  texts: {
    'nl': LearningOfferingText(
      title: 'Boleten & poriën',
      summary: 'Verdieping in poriën en andere kenmerken.',
    ),
    'en': LearningOfferingText(
      title: 'Boletes & pores',
      summary: 'Specialist pore and character training.',
    ),
    'de': LearningOfferingText(
      title: 'Röhrlinge & Poren',
      summary: 'Vertiefung zu Poren und weiteren Merkmalen.',
    ),
  },
);

LearningMaterialLocalState _material({
  required bool entitled,
  int? installedVersion,
  Set<int> lessonIds = const {},
}) =>
    LearningMaterialLocalState(
      offering: _offering,
      entitlementGranted: entitled,
      installed: installedVersion == null
          ? null
          : InstalledLearningPackageState(
              packageKey: _offering.packageKey,
              contentVersion: installedVersion,
              installedAt: DateTime.utc(2026, 9, 5, 12),
            ),
      lessonIds: Set<int>.unmodifiable(lessonIds),
    );

class _FakeMaterialsService implements LearningMaterialsService {
  _FakeMaterialsService({
    required LearningMaterialLocalState material,
    required this.purchasesConfigured,
    required this.deliveryConfigured,
    this.remoteVersions = const {},
    this.throwRemote = false,
  }) : _material = material;

  LearningMaterialLocalState _material;

  @override
  final bool purchasesConfigured;

  @override
  final bool deliveryConfigured;

  final Map<String, int> remoteVersions;
  final bool throwRemote;
  final List<String> installCalls = [];

  @override
  Future<LearningMaterialsLocalSnapshot> loadLocal() async =>
      LearningMaterialsLocalSnapshot(
        materials: [_material],
        purchasesConfigured: purchasesConfigured,
        deliveryConfigured: deliveryConfigured,
      );

  @override
  Future<Map<String, int>> loadRemoteVersions(
    Iterable<LearningOffering> offerings,
  ) async {
    if (throwRemote) throw StateError('offline');
    return remoteVersions;
  }

  @override
  Future<LearningPackageInstallResult> install(String packageKey) async {
    installCalls.add(packageKey);
    final remoteVersion = remoteVersions[packageKey] ?? 1;
    _material = LearningMaterialLocalState(
      offering: _material.offering,
      entitlementGranted: true,
      installed: InstalledLearningPackageState(
        packageKey: packageKey,
        contentVersion: remoteVersion,
        installedAt: DateTime.utc(2026, 9, 5, 13),
      ),
      lessonIds: const {1000},
    );
    return LearningPackageInstallResult(
      outcome: LearningPackageInstallOutcome.installed,
      packageKey: packageKey,
      contentVersion: remoteVersion,
    );
  }
}
