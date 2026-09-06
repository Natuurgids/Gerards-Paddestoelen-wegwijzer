import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/app_database.dart';
import '../../data/learning_commerce.dart';
import '../../data/learning_materials_service.dart';
import '../../data/learning_package_installer.dart';
import '../../data/training_data_repository.dart';
import '../../theme/app_theme.dart';
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
  StreamSubscription<void>? _entitlementSubscription;
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
    final changeSource = _service is LearningMaterialsEntitlementChangeSource
        ? _service as LearningMaterialsEntitlementChangeSource
        : null;
    if (changeSource != null) {
      _entitlementSubscription = changeSource.entitlementChanges.listen((_) {
        if (mounted) unawaited(_load());
      });
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_entitlementSubscription?.cancel());
    super.dispose();
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
              const Icon(Icons.error_outline, color: AppTheme.forest, size: 40),
              const SizedBox(height: 12),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 840 ? 28.0 : 14.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _introPanel(context, l10n),
                    if (!local.purchasesConfigured) ...[
                      const SizedBox(height: 12),
                      _statusPanel(
                        icon: Icons.storefront_outlined,
                        message: l10n.learningMaterialsPurchasesUnavailable,
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
                      _statusPanel(
                        icon: Icons.storefront_outlined,
                        message: l10n.learningMaterialsStoreUnavailable,
                      ),
                    ],
                    if (_remoteUnavailable) ...[
                      const SizedBox(height: 12),
                      _statusPanel(
                        icon: Icons.cloud_off_outlined,
                        message: l10n.learningMaterialsRemoteUnavailable,
                      ),
                    ],
                    const SizedBox(height: 14),
                    ...local.materials.map(
                      (item) => _materialCard(context, l10n, item),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _introPanel(BuildContext context, AppLocalizations l10n) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.download_for_offline_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.learningMaterialsTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.learningMaterialsIntro,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: .9),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _statusPanel({required IconData icon, required String message}) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppTheme.creamStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.forest),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );

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

    final status = _statusText(
      l10n,
      item,
      updateAvailable: updateAvailable,
      remoteVersion: remoteVersion,
    );

    return Card(
      key: ValueKey('learning-material-${item.offering.packageKey}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppTheme.creamStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F1E5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    item.entitlementGranted
                        ? Icons.school_outlined
                        : Icons.workspace_premium_outlined,
                    color: AppTheme.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(text.summary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F1E5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.forestDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (quote != null && !item.entitlementGranted) ...[
              const SizedBox(height: 10),
              Text(
                quote.displayPrice,
                key: ValueKey('learning-material-price-${item.offering.packageKey}'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
            const SizedBox(height: 14),
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
                      '${l10n.learningMaterialsPurchase} · ${quote.displayPrice}',
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
