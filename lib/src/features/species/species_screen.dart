import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';
import '../../widgets/species_image.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key, required this.locale, required this.speciesId});

  final Locale locale;
  final int speciesId;

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
    _future = SpeciesRepository().detail(
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

  String _label(String key) {
    const values = {
      'nl': {
        'habitat': 'Habitat',
        'lookalikes': 'Gelijkende soorten',
        'status': 'Veiligheidsreferentie',
        'missing': 'Afbeelding nog niet beschikbaar',
        'measurements': 'Afmetingen',
        'season': 'Seizoen',
        'cap_diameter': 'Hoeddiameter',
        'stem_height': 'Steelhoogte',
        'stem_diameter': 'Steeldiameter',
        'notFound': 'Soort niet gevonden',
      },
      'en': {
        'habitat': 'Habitat',
        'lookalikes': 'Lookalikes',
        'status': 'Safety reference',
        'missing': 'Image not available yet',
        'measurements': 'Measurements',
        'season': 'Season',
        'cap_diameter': 'Cap diameter',
        'stem_height': 'Stem height',
        'stem_diameter': 'Stem diameter',
        'notFound': 'Species not found',
      },
      'de': {
        'habitat': 'Lebensraum',
        'lookalikes': 'Verwechslungsarten',
        'status': 'Sicherheitsreferenz',
        'missing': 'Bild noch nicht verfügbar',
        'measurements': 'Maße',
        'season': 'Saison',
        'cap_diameter': 'Hutdurchmesser',
        'stem_height': 'Stielhöhe',
        'stem_diameter': 'Stieldurchmesser',
        'notFound': 'Art nicht gefunden',
      },
    };
    return (values[widget.locale.languageCode] ?? values['en']!)[key] ?? key;
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

  String _monthName(int month) {
    const nl = ['', 'jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    const en = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const de = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final values = widget.locale.languageCode == 'nl'
        ? nl
        : widget.locale.languageCode == 'de'
            ? de
            : en;
    return values[month];
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

  String _safetyReference(SpeciesDetail species) {
    final language = widget.locale.languageCode;
    if (species.toxicityLevel == 'deadly') {
      return language == 'nl'
          ? 'Bekend als potentieel dodelijk giftig. Niet consumeren. Gebruik de app nooit als basis voor consumptie.'
          : language == 'de'
              ? 'Als potenziell tödlich giftig bekannt. Nicht verzehren. Die App darf niemals Grundlage für den Verzehr sein.'
              : 'Known as potentially deadly poisonous. Do not consume. Never use the app as a basis for consumption.';
    }
    if (species.toxicityLevel == 'poisonous') {
      return language == 'nl'
          ? 'Bekend als giftig. Niet consumeren. Gebruik de app nooit als basis voor consumptie.'
          : language == 'de'
              ? 'Als giftig bekannt. Nicht verzehren. Die App darf niemals Grundlage für den Verzehr sein.'
              : 'Known as poisonous. Do not consume. Never use the app as a basis for consumption.';
    }
    return language == 'nl'
        ? 'Deze app geeft geen oordeel dat consumptie veilig is. Laat identificatie en eventuele eetbaarheid altijd door een gekwalificeerde lokale deskundige controleren.'
        : language == 'de'
            ? 'Diese App bestätigt niemals, dass ein Verzehr sicher ist. Bestimmung und mögliche Essbarkeit müssen immer von einer qualifizierten örtlichen Fachperson geprüft werden.'
            : 'This app never confirms that consumption is safe. Identification and any possible edibility must always be verified by a qualified local expert.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<SpeciesDetail?>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final species = snapshot.data;
                  if (species == null) {
                    return Center(child: Text(_label('notFound')));
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

                  return ListView(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _controller,
                              itemCount: images.length,
                              onPageChanged: (value) => setState(() => _page = value),
                              itemBuilder: (_, index) => SpeciesImageView(
                                path: images[index].path,
                                missingLabel: _label('missing'),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(species.commonName, style: Theme.of(context).textTheme.headlineMedium),
                            Text(
                              species.scientificName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 16),
                            Text(species.description ?? species.summary ?? ''),
                            if (species.measurements.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(_label('measurements'), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              ...species.measurements.map(
                                (measurement) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('${_label(measurement.code)}: ${_measurement(measurement)}'),
                                ),
                              ),
                            ],
                            if (species.season.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(_label('season'), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              ...seasonByRegion.entries.map((entry) {
                                final note = _regionNote(entry.key);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_regionName(entry.key), style: Theme.of(context).textTheme.labelLarge),
                                      if (note != null && note.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                                          child: Text(note, style: Theme.of(context).textTheme.bodySmall),
                                        ),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: entry.value
                                            .map(
                                              (month) => Chip(
                                                label: Text(_monthName(month.month)),
                                                avatar: Icon(
                                                  month.likelihood >= 3 ? Icons.circle : Icons.circle_outlined,
                                                  size: month.likelihood >= 3 ? 14 : month.likelihood == 2 ? 11 : 8,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 20),
                            Text(_label('habitat'), style: Theme.of(context).textTheme.titleMedium),
                            Text(species.habitat ?? '-'),
                            const SizedBox(height: 16),
                            Text(_label('lookalikes'), style: Theme.of(context).textTheme.titleMedium),
                            Text(species.lookalikes ?? '-'),
                            const SizedBox(height: 16),
                            Text(_label('status'), style: Theme.of(context).textTheme.titleMedium),
                            Text(_safetyReference(species)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafetyNotice(locale: widget.locale),
          ],
        ),
      ),
    );
  }
}
