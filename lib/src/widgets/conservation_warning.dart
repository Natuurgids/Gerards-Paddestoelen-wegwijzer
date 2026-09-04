import 'package:flutter/material.dart';

import '../data/app_database.dart';

typedef ConservationStatusLoader = Future<String?> Function(int speciesId);

class ConservationWarning extends StatelessWidget {
  const ConservationWarning({
    super.key,
    required this.speciesId,
    this.compact = false,
    this.statusLoader,
  });

  final int speciesId;
  final bool compact;
  final ConservationStatusLoader? statusLoader;

  Future<String?> _load() async {
    if (statusLoader != null) return statusLoader!(speciesId);
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'species',
      columns: const ['conservation_status'],
      where: 'id=?',
      whereArgs: [speciesId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['conservation_status'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool _isConcern(String status) {
    final normalized = status.trim().toUpperCase().replaceAll('_', ' ');
    return const {
      'CR',
      'CRITICALLY ENDANGERED',
      'EN',
      'ENDANGERED',
      'VU',
      'VULNERABLE',
    }.contains(normalized);
  }

  ({String title, String detail, String compactLabel}) _copy(
    BuildContext context,
    String status,
  ) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'nl':
        return (
          title: 'Beschermingswaarschuwing',
          detail:
              'IUCN Rode Lijst: $status. Laat deze soort staan en beschadig of pluk hem niet. Dit is een natuurbehoudstatus en niet automatisch een wettelijke beschermingsstatus.',
          compactLabel: 'IUCN $status',
        );
      case 'de':
        return (
          title: 'Schutzwarnung',
          detail:
              'IUCN Rote Liste: $status. Bitte stehen lassen und nicht beschädigen oder sammeln. Dies ist ein Naturschutzstatus und nicht automatisch ein gesetzlicher Schutzstatus.',
          compactLabel: 'IUCN $status',
        );
      default:
        return (
          title: 'Conservation warning',
          detail:
              'IUCN Red List: $status. Leave this species in place and do not damage or collect it. This is a conservation status and does not automatically mean legal protection.',
          compactLabel: 'IUCN $status',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _load(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || !_isConcern(status)) {
          return const SizedBox.shrink();
        }
        final copy = _copy(context, status);
        if (compact) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.eco_outlined, size: 18),
                label: Text(copy.compactLabel),
              ),
            ),
          );
        }
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: colors.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco_outlined, color: colors.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.detail,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
