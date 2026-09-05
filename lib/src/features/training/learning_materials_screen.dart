import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/app_database.dart';
import '../../data/learning_commerce.dart';
import '../../data/learning_materials_service.dart';
import '../../data/learning_package_installer.dart';
import '../../data/training_data_repository.dart';
import '../../widgets/safety_notice.dart';
import 'training_screen.dart';

class LearningMaterialsScreen extends StatefulWidget {
  const LearningMaterialsScreen({
    super.key,
    required this.locale,
    this.service,
  });

  final Locale locale;
  final LearningMaterialsService? service;

  @override
  State<LearningMaterialsScreen> createState() => _LearningMaterialsScreenState();
}

class _LearningMaterialsScreenState extends State<LearningMaterialsScreen> {
  late final LearningMaterialsService _service;
  LearningMaterialsLocalSnapshot? _local;
  Map<String, int> _remoteVersions = const <String, int>{};
  Map<String, LearningProductQuote> _productQuotes =
      const <String, LearningProductQuote>{};
  Object? _loadError;
  bool _remoteUnavailable = false;
  bool _storeUnavailable = false;
  bool _restoring = false;
  String? _busyPackageKey;
  String? _busyProductKey;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DefaultLearningMaterialsService.standard();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final local = await _service.loadLocal();
      if (!mounted) return;
      setState(() {
        _local = local;
        _loadError = null;
      });
      if (local.deliveryConfigured) {
        unawaited(_refreshRemote(local));
      }
      if (local.purchasesConfigured) {
        unawaited(_refreshCommerce(local));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _refreshRemote(LearningMaterialsLocalSnapshot local) async {
    try {
      final versions = await _service.loadRemoteVersions(
        local.materials.map((item) => item.offering),
      );
      if (!mounted) return;
      setState(() {
        _remoteVersions = versions;
        _remoteUnavailable = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _remoteUnavailable = true);
    }
  }

  Future<void> _refreshCommerce(LearningMaterialsLocalSnapshot local) async {
    try {
      final quotes = await _service.loadProductQuotes(
        local.materials.map((item) => item.offering),
      );
      if (!mounted) return;
      setState(() {
        _productQuotes = quotes;
        _storeUnavailable = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _productQuotes = const <String, LearningProductQuote>{};
        _storeUnavailable = true;
      });
    }
  }

  Future<void> _purchase(LearningMaterialLocalState item) async {
    final productKey = item.offering.productKey;
    if (_busyProductKey != null || item.entitlementGranted) return;
    setState(() => _busyProductKey = productKey);
    final l10n = AppLocalizations.of(context);
    try {
      await _service.purchase(productKey);
      if (mounted) _showMessage(l10n.learningMaterialsPurchaseStarted);
    } on Object {
      if (mounted) _showMessage(l10n.learningMaterialsPurchaseError);
    } finally {
      if (mounted) setState(() => _busyProductKey = null);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final l10n = AppLocalizations.of(context);
    try {
      await _service.restorePurchases();
      if (mounted) await _load();
    } on Object {
      if (mounted) _showMessage(l10n.learningMaterialsRestoreError);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _install(LearningMaterialLocalState item) async {
    if (_busyPackageKey != null) return;
    setState(() => _busyPackageKey = item.offering.packageKey);
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _service.install(item.offering.packageKey);
      if (!mounted) return;
      switch (result.outcome) {
        case LearningPackageInstallOutcome.installed:
        case LearningPackageInstallOutcome.alreadyCurrent:
          await _load();
          break;
        case LearningPackageInstallOutcome.notEntitled:
          _showMessage(l10n.learningMaterialsNotEntitled);
          break;
        case LearningPackageInstallOutcome.notConfigured:
          _showMessage(l10n.learningMaterialsNotConfigured);
          break;
        case LearningPackageInstallOutcome.packageNotFound:
          _showMessage(l10n.learningMaterialsDownloadUnavailable);
          break;
      }
    } on Object {
      if (mounted) _showMessage(l10n.learningMaterialsInstallError);
    } finally {
      if (mounted) setState(() => _busyPackageKey = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _open(LearningMaterialLocalState item) {
    if (!item.canOpen) return;
    final text = item.offering.textFor(widget.locale.languageCode);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingScreen(
          locale: widget.locale,
          title: text.title,
          lessonIds: item.lessonIds,
          repository: TrainingDataRepository(
            databaseProvider: () => AppDatabase.instance.database,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningMaterialsTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent(context, l10n)),
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.learningMaterialsLoadError,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.learningMaterialsRetry),
              ),
            ],
          ),
        ),
      );
    }

    final local = _local;
    if (local == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.learningMaterialsIntro,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (!local.purchasesConfigured) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.learningMaterialsPurchasesUnavailable)),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('learning-materials-restore'),
              onPressed: _restoring ? null : _restorePurchases,
              icon: _restoring
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore),
              label: Text(l10n.learningMaterialsRestorePurchases),
            ),
          ),
        ],
        if (_storeUnavailable) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.learningMaterialsStoreUnavailable)),
                ],
              ),
            ),
          ),
        ],
        if (_remoteUnavailable) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.learningMaterialsRemoteUnavailable)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...local.materials.map((item) => _materialCard(context, l10n, item)),
      ],
    );
  }

  Widget _materialCard(
    BuildContext context,
    AppLocalizations l10n,
    LearningMaterialLocalState item,
  ) {
    final text = item.offering.textFor(widget.locale.languageCode);
    final remoteVersion = _remoteVersions[item.offering.packageKey];
    final quote = _productQuotes[item.offering.productKey];
    final installedVersion = item.installed?.contentVersion;
    final updateAvailable = item.entitlementGranted &&
        item.hasInstalledContent &&
        remoteVersion != null &&
        installedVersion != null &&
        remoteVersion > installedVersion;
    final canDownload = item.entitlementGranted &&
        !item.hasInstalledContent &&
        remoteVersion != null;
    final canRepair = item.entitlementGranted &&
        item.needsOwnershipBackfill &&
        remoteVersion != null;
    final canPurchase = !item.entitlementGranted && quote != null;
    final isInstallBusy = _busyPackageKey == item.offering.packageKey;
    final isPurchaseBusy = _busyProductKey == item.offering.productKey;

    return Card(
      key: ValueKey('learning-material-${item.offering.packageKey}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(text.summary),
            const SizedBox(height: 12),
            Text(
              _statusText(
                l10n,
                item,
                updateAvailable: updateAvailable,
                remoteVersion: remoteVersion,
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (quote != null && !item.entitlementGranted) ...[
              const SizedBox(height: 6),
              Text(
                quote.displayPrice,
                key: ValueKey('learning-material-price-${item.offering.packageKey}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.canOpen)
                  OutlinedButton.icon(
                    onPressed: isInstallBusy ? null : () => _open(item),
                    icon: const Icon(Icons.school_outlined),
                    label: Text(l10n.learningMaterialsOpen),
                  ),
                if (canPurchase)
                  FilledButton.icon(
                    key: ValueKey('learning-material-buy-${item.offering.packageKey}'),
                    onPressed: isPurchaseBusy ? null : () => _purchase(item),
                    icon: isPurchaseBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      '${l10n.learningMaterialsPurchase} · ${quote!.displayPrice}',
                    ),
                  ),
                if (updateAvailable)
                  FilledButton.icon(
                    onPressed: isInstallBusy ? null : () => _install(item),
                    icon: isInstallBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(l10n.learningMaterialsUpdate),
                  )
                else if (canRepair)
                  FilledButton.icon(
                    onPressed: isInstallBusy ? null : () => _install(item),
                    icon: const Icon(Icons.build_outlined),
                    label: Text(l10n.learningMaterialsRepair),
                  )
                else if (canDownload)
                  FilledButton.icon(
                    onPressed: isInstallBusy ? null : () => _install(item),
                    icon: isInstallBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined),
                    label: Text(l10n.learningMaterialsDownload),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(
    AppLocalizations l10n,
    LearningMaterialLocalState item, {
    required bool updateAvailable,
    required int? remoteVersion,
  }) {
    if (!item.entitlementGranted) {
      return item.installed == null
          ? l10n.learningMaterialsNotOwned
          : l10n.learningMaterialsInstalledLocked;
    }
    if (item.needsOwnershipBackfill) {
      return remoteVersion == null
          ? l10n.learningMaterialsDownloadUnavailable
          : l10n.learningMaterialsRepairRequired;
    }
    if (item.hasInstalledContent) {
      return updateAvailable
          ? l10n.learningMaterialsUpdateAvailable
          : l10n.learningMaterialsInstalled;
    }
    return remoteVersion == null
        ? l10n.learningMaterialsDownloadUnavailable
        : l10n.learningMaterialsOwned;
  }
}
