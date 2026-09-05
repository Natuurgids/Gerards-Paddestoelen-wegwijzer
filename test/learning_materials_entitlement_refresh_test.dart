import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/l10n/app_localizations.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_materials_service.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package_installer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/training/learning_materials_screen.dart';

void main() {
  testWidgets('verified entitlement change refreshes already-open materials UI', (
    tester,
  ) async {
    final service = _ChangingMaterialsService();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LearningMaterialsScreen(
          locale: const Locale('nl'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niet in bezit'), findsOneWidget);
    expect(find.text('Downloaden'), findsNothing);

    service.grantVerifiedEntitlement();
    await tester.pumpAndSettle();

    expect(find.text('In bezit'), findsOneWidget);
    expect(find.text('Downloaden'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await service.close();
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

class _ChangingMaterialsService
    implements LearningMaterialsService, LearningMaterialsEntitlementChangeSource {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _entitled = false;

  @override
  bool get purchasesConfigured => false;

  @override
  bool get deliveryConfigured => true;

  @override
  Stream<void> get entitlementChanges => _changes.stream;

  void grantVerifiedEntitlement() {
    _entitled = true;
    _changes.add(null);
  }

  Future<void> close() => _changes.close();

  @override
  Future<LearningMaterialsLocalSnapshot> loadLocal() async =>
      LearningMaterialsLocalSnapshot(
        materials: [
          LearningMaterialLocalState(
            offering: _offering,
            entitlementGranted: _entitled,
            installed: null,
            lessonIds: const <int>{},
          ),
        ],
        purchasesConfigured: purchasesConfigured,
        deliveryConfigured: deliveryConfigured,
      );

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Iterable<LearningOffering> offerings,
  ) async =>
      const <String, LearningProductQuote>{};

  @override
  Future<void> purchase(String productKey) async =>
      throw StateError('commerce disabled');

  @override
  Future<void> restorePurchases() async =>
      throw StateError('commerce disabled');

  @override
  Future<Map<String, int>> loadRemoteVersions(
    Iterable<LearningOffering> offerings,
  ) async =>
      const {'boletes-pores': 1};

  @override
  Future<LearningPackageInstallResult> install(String packageKey) async =>
      throw StateError('not needed');
}
