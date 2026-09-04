import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
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
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(l10n.sourcesIntro),
                      const SizedBox(height: 16),
                      ...snapshot.data!.map(
                        (source) => _SourceCard(source: source),
                      ),
                    ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.title, style: Theme.of(context).textTheme.titleMedium),
            if (source.version != null && source.version!.isNotEmpty)
              Text('${l10n.sourcesVersion}: ${source.version}'),
            const SizedBox(height: 8),
            Text(
              license == null || license.isEmpty
                  ? l10n.sourcesNoReuseLicense
                  : '${l10n.sourcesLicense}: $license',
            ),
            if (source.citation != null && source.citation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(source.citation!),
            ],
            const SizedBox(height: 8),
            SelectableText(source.url),
            if (source.retrievedAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${l10n.sourcesRetrieved}: ${source.retrievedAt}'),
            ],
          ],
        ),
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
