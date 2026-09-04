import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/conservation_status_repository.dart';

typedef ConservationStatusLoader = Future<String?> Function(int speciesId);
typedef ConservationRecordsLoader = Future<List<ConservationStatusRecord>> Function(
  int speciesId,
);

class ConservationWarning extends StatelessWidget {
  const ConservationWarning({
    super.key,
    required this.speciesId,
    this.compact = false,
    this.statusLoader,
    this.recordsLoader,
  });

  final int speciesId;
  final bool compact;
  final ConservationStatusLoader? statusLoader;
  final ConservationRecordsLoader? recordsLoader;

  Future<List<ConservationStatusRecord>> _load() async {
    if (recordsLoader != null) return recordsLoader!(speciesId);
    if (statusLoader != null) {
      final status = await statusLoader!(speciesId);
      if (status == null || status.trim().isEmpty) return const [];
      return [
        ConservationStatusRecord(
          system: 'iucn_red_list',
          scope: 'global',
          jurisdictionCode: '',
          status: status.trim(),
        ),
      ];
    }
    final db = await AppDatabase.instance.database;
    return ConservationStatusRepository.loadStatuses(db, speciesId);
  }

  bool _isIucnConcern(String status) {
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

  bool _isDutchRedListConcern(String status) {
    final normalized = status.trim().toUpperCase().replaceAll('*', '');
    return const {'GE', 'KW', 'BE', 'EB', 'VN'}.contains(normalized);
  }

  bool _shouldShow(ConservationStatusRecord record) {
    if (record.isGlobalIucn) return _isIucnConcern(record.status);
    if (record.isDutchRedList) return _isDutchRedListConcern(record.status);
    return false;
  }

  ({String title, String detail, String compactLabel}) _copy(
    BuildContext context,
    ConservationStatusRecord record,
  ) {
    final status = record.status;
    final language = Localizations.localeOf(context).languageCode;

    if (record.isDutchRedList) {
      switch (language) {
        case 'nl':
          return (
            title: 'Rode Lijst Nederland',
            detail:
                'Nederlandse Rode Lijst: $status. Laat deze soort staan en beschadig of pluk hem niet. De Rode Lijst heeft een signalerende functie voor het natuurbeleid en betekent niet automatisch dat deze soort wettelijk beschermd is.',
            compactLabel: 'NL Rode Lijst $status',
          );
        case 'de':
          return (
            title: 'Niederländische Rote Liste',
            detail:
                'Niederländische Rote Liste: $status. Bitte stehen lassen und nicht beschädigen oder sammeln. Die Rote Liste dient dem Naturschutz und bedeutet nicht automatisch gesetzlichen Artenschutz.',
            compactLabel: 'NL Rote Liste $status',
          );
        default:
          return (
            title: 'Dutch Red List',
            detail:
                'Dutch Red List: $status. Leave this species in place and do not damage or collect it. The Red List is a conservation-policy signal and does not automatically mean legal protection.',
            compactLabel: 'NL Red List $status',
          );
      }
    }

    switch (language) {
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

  Widget _card(BuildContext context, ConservationStatusRecord record) {
    final copy = _copy(context, record);
    final colors = Theme.of(context).colorScheme;
    return Card(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConservationStatusRecord>>(
      future: _load(),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <ConservationStatusRecord>[])
            .where(_shouldShow)
            .toList(growable: false);
        if (records.isEmpty) return const SizedBox.shrink();

        if (compact) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final record in records)
                    Chip(
                      avatar: const Icon(Icons.eco_outlined, size: 18),
                      label: Text(_copy(context, record).compactLabel),
                    ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              for (final record in records) _card(context, record),
            ],
          ),
        );
      },
    );
  }
}
