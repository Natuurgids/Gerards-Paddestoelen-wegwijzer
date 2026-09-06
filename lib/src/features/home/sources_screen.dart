import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safety_notice.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  late final Future<List<_ReferenceSource>> _sources = _loadSources();

  static const _nsr = _ReferenceSource(
    id: 'nsr-dutch-species-register',
    title: 'Checklist Dutch Species Register - Nederlands Soortenregister',
    version: '2026',
    url: 'https://www.gbif.org/dataset/4dd32523-a3a3-43b7-84df-4cda02f15cf7',
    license: 'CC BY 4.0',
    citation:
        'Creuwels J, Pieterse S (2026). Checklist Dutch Species Register - Nederlands Soortenregister. Naturalis Biodiversity Center. https://doi.org/10.15468/rjdpzy',
    retrievedAt: '2026-09-04',
  );

  Future<List<_ReferenceSource>> _loadSources() async {
    final raw = await rootBundle.loadString('assets/data/species_catalog.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final result = <_ReferenceSource>[];
    for (final rawSource in decoded['sources'] as List<dynamic>? ?? const []) {
      final source = rawSource as Map<String, dynamic>;
      result.add(_ReferenceSource.fromJson(source));
    }
    if (!result.any((source) => source.id == _nsr.id)) result.add(_nsr);
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sourcesTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<_ReferenceSource>>(
                future: _sources,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(l10n.sourcesLoadError));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 840
                          ? 28.0
                          : 14.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          24,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.forest,
                                          AppTheme.forestDark,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.menu_book_outlined,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            l10n.sourcesIntro,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  height: 1.45,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ...snapshot.data!.map(
                                    (source) => _SourceCard(source: source),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final _ReferenceSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final license = source.license?.trim();
    final hasLicense = license != null && license.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppTheme.creamStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    color: AppTheme.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.library_books_outlined,
                    color: AppTheme.forest,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    source.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (source.version != null && source.version!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MetadataPill(
                icon: Icons.history_outlined,
                label: '${l10n.sourcesVersion}: ${source.version}',
              ),
            ],
            const SizedBox(height: 12),
            _MetadataPill(
              icon: hasLicense
                  ? Icons.verified_user_outlined
                  : Icons.info_outline,
              label: hasLicense
                  ? '${l10n.sourcesLicense}: $license'
                  : l10n.sourcesNoReuseLicense,
            ),
            if (source.citation != null && source.citation!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                source.citation!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                source.url,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.forest,
                ),
              ),
            ),
            if (source.retrievedAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${l10n.sourcesRetrieved}: ${source.retrievedAt}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.moss.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.forest),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceSource {
  const _ReferenceSource({
    required this.id,
    required this.title,
    required this.url,
    required this.retrievedAt,
    this.version,
    this.license,
    this.citation,
  });

  factory _ReferenceSource.fromJson(Map<String, dynamic> json) =>
      _ReferenceSource(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        version: json['version']?.toString(),
        url: json['url']?.toString() ?? '',
        license: json['license']?.toString(),
        citation: json['citation']?.toString(),
        retrievedAt: json['retrieved_at']?.toString() ?? '',
      );

  final String id;
  final String title;
  final String? version;
  final String url;
  final String? license;
  final String? citation;
  final String retrievedAt;
}
