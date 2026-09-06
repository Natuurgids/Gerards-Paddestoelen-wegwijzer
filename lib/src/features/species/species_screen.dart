import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/resilient_species_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/conservation_warning.dart';
import '../../widgets/safety_notice.dart';
import '../../widgets/species_image.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({
    super.key,
    required this.locale,
    required this.speciesId,
    this.repository,
  });

  final Locale locale;
  final int speciesId;
  final SpeciesRepository? repository;

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final _controller = PageController();
  late Future<SpeciesDetail?> _future;
  List<SeasonRegionOption> _regionOptions = const [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = (widget.repository ?? ResilientSpeciesRepository()).detail(
      widget.speciesId,
      widget.locale.languageCode,
    );
    FieldDataRepository().seasonRegions(widget.locale.languageCode).then(
      (regions) {
        if (mounted) setState(() => _regionOptions = regions);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _measurementLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'cap_diameter':
        return l10n.speciesCapDiameter;
      case 'stem_height':
        return l10n.speciesStemHeight;
      case 'stem_diameter':
        return l10n.speciesStemDiameter;
      default:
        return code;
    }
  }

  String _measurement(SpeciesMeasurement measurement) {
    final min = measurement.minValue;
    final max = measurement.maxValue;
    if (min != null && max != null) {
      return '${_format(min)}–${_format(max)} ${measurement.unit}';
    }
    if (min != null) return '≥ ${_format(min)} ${measurement.unit}';
    if (max != null) return '≤ ${_format(max)} ${measurement.unit}';
    return '-';
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String _monthName(AppLocalizations l10n, int month) {
    switch (month) {
      case 1:
        return l10n.monthJan;
      case 2:
        return l10n.monthFeb;
      case 3:
        return l10n.monthMar;
      case 4:
        return l10n.monthApr;
      case 5:
        return l10n.monthMay;
      case 6:
        return l10n.monthJun;
      case 7:
        return l10n.monthJul;
      case 8:
        return l10n.monthAug;
      case 9:
        return l10n.monthSep;
      case 10:
        return l10n.monthOct;
      case 11:
        return l10n.monthNov;
      case 12:
        return l10n.monthDec;
      default:
        return month.toString();
    }
  }

  String _regionName(String code) {
    for (final region in _regionOptions) {
      if (region.code == code) return region.label;
    }
    return code;
  }

  String? _regionNote(String code) {
    for (final region in _regionOptions) {
      if (region.code == code) return region.note;
    }
    return null;
  }

  Map<String, List<SpeciesSeasonMonth>> _seasonByRegion(
    List<SpeciesSeasonMonth> months,
  ) {
    final result = <String, List<SpeciesSeasonMonth>>{};
    for (final month in months) {
      final code = month.regionCode ?? 'UNSPECIFIED';
      result.putIfAbsent(code, () => []).add(month);
    }
    return result;
  }

  String _safetyReference(AppLocalizations l10n, SpeciesDetail species) {
    if (species.toxicityLevel == 'deadly') return l10n.speciesSafetyDeadly;
    if (species.toxicityLevel == 'poisonous') {
      return l10n.speciesSafetyPoisonous;
    }
    return l10n.speciesSafetyUnknown;
  }

  ShapeBorder get _cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      );

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Card(
        elevation: 0,
        color: AppTheme.creamStrong,
        shape: _cardShape,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.moss.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 20, color: AppTheme.forest),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _identityCard(BuildContext context, SpeciesDetail species) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              species.commonName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              species.scientificName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .88),
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 10),
            ConservationWarning(speciesId: species.id),
            final description = species.description ?? species.summary ?? '',
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                      height: 1.45,
                    ),
              ),
            ],
          ],
        ),
      );

  Widget _gallery(
    BuildContext context,
    AppLocalizations l10n,
    List<SpeciesImage> images,
  ) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) => SpeciesImageView(
                  path: images[index].path,
                  missingLabel: l10n.speciesImageMissing,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${_page + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<SpeciesDetail?>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(l10n.speciesNotFound));
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final species = snapshot.data;
                  if (species == null) {
                    return Center(child: Text(l10n.speciesNotFound));
                  }

                  final images = species.images.isEmpty
                      ? List<SpeciesImage>.generate(
                          5,
                          (index) => SpeciesImage(
                            path: '',
                            angleCode: null,
                            sortOrder: index,
                          ),
                        )
                      : species.images;
                  final seasonByRegion = _seasonByRegion(species.season);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth >= 840 ? 28.0 : 14.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 24),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _gallery(context, l10n, images),
                                  const SizedBox(height: 12),
                                  _identityCard(context, species),
                                  const SizedBox(height: 12),
                                  if (species.measurements.isNotEmpty)
                                    _sectionCard(
                                      context,
                                      icon: Icons.straighten,
                                      title: l10n.speciesMeasurements,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: species.measurements
                                            .map(
                                              (measurement) => Padding(
                                                padding: const EdgeInsets.only(bottom: 7),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _measurementLabel(
                                                          l10n,
                                                          measurement.code,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      _measurement(measurement),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        color: AppTheme.ink,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  if (species.season.isNotEmpty)
                                    _sectionCard(
                                      context,
                                      icon: Icons.calendar_month_outlined,
                                      title: l10n.speciesSeason,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: seasonByRegion.entries.map((entry) {
                                          final note = _regionNote(entry.key);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _regionName(entry.key),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        color: AppTheme.forest,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                                if (note != null && note.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                      top: 2,
                                                      bottom: 7,
                                                    ),
                                                    child: Text(
                                                      note,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: entry.value
                                                      .map(
                                                        (month) => Chip(
                                                          label: Text(
                                                            _monthName(
                                                              l10n,
                                                              month.month,
                                                            ),
                                                          ),
                                                          avatar: Icon(
                                                            month.likelihood >= 3
                                                                ? Icons.circle
                                                                : Icons.circle_outlined,
                                                            size: month.likelihood >= 3
                                                                ? 14
                                                                : month.likelihood == 2
                                                                    ? 11
                                                                    : 8,
                                                            color: AppTheme.forest,
                                                          ),
                                                          side: const BorderSide(
                                                            color: AppTheme.border,
                                                          ),
                                                          backgroundColor: AppTheme.cream,
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  _sectionCard(
                                    context,
                                    icon: Icons.park_outlined,
                                    title: l10n.speciesHabitat,
                                    child: Text(species.habitat ?? '-'),
                                  ),
                                  _sectionCard(
                                    context,
                                    icon: Icons.compare_arrows,
                                    title: l10n.speciesLookalikes,
                                    child: Text(species.lookalikes ?? '-'),
                                  ),
                                  _sectionCard(
                                    context,
                                    icon: Icons.health_and_safety_outlined,
                                    title: l10n.speciesSafetyReference,
                                    child: Text(_safetyReference(l10n, species)),
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
