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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.eco_outlined,
                  size: 22,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactBadge(
    BuildContext context,
    ConservationStatusRecord record,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.error.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_outlined, size: 17, color: colors.onErrorContainer),
          const SizedBox(width: 6),
          Text(
            _copy(context, record).compactLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final record in records) _compactBadge(context, record),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  for (var index = 0; index < records.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _card(context, records[index]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
