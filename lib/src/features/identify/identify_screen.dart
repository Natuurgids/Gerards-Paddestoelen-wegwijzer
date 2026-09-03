import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';
import '../species/species_screen.dart';
import 'measurement_input.dart';

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({
    super.key,
    required this.locale,
    this.repository,
    this.fieldDataRepository,
  });

  final Locale locale;
  final IdentificationRepository? repository;
  final FieldDataRepository? fieldDataRepository;

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  late final IdentificationRepository _repo;
  late final FieldDataRepository _fieldRepo;
  final _capController = TextEditingController();
  final _stemController = TextEditingController();
  final _stemDiameterController = TextEditingController();
  late Future<List<TraitChoice>> _choices;
  late Future<List<SeasonRegionOption>> _regions;
  final Map<int, int> _selected = {};
  List<IdentificationCandidate>? _results;
  String? _seasonRegion;
  int? _observationMonth;
  MeasurementInputStatus? _capError;
  MeasurementInputStatus? _stemError;
  MeasurementInputStatus? _stemDiameterError;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? IdentificationRepository();
    _fieldRepo = widget.fieldDataRepository ?? FieldDataRepository();
    _choices = _repo.choices(widget.locale.languageCode);
    _regions = _fieldRepo.seasonRegions(widget.locale.languageCode);
  }

  @override
  void dispose() {
    _capController.dispose();
    _stemController.dispose();
    _stemDiameterController.dispose();
    super.dispose();
  }

  String t(String nl, String en, String de) =>
      widget.locale.languageCode == 'nl'
          ? nl
          : widget.locale.languageCode == 'de'
              ? de
              : en;

  String? _measurementError(MeasurementInputStatus? status) {
    if (status == MeasurementInputStatus.invalidNumber) {
      return t(
        'Vul een geldig getal in.',
        'Enter a valid number.',
        'Gib eine gültige Zahl ein.',
      );
    }
    if (status == MeasurementInputStatus.nonPositive) {
      return t(
        'Gebruik een waarde groter dan 0.',
        'Use a value greater than 0.',
        'Verwende einen Wert größer als 0.',
      );
    }
    return null;
  }

  Future<void> _identify() async {
    final cap = parseMeasurementInput(_capController.text);
    final stem = parseMeasurementInput(_stemController.text);
    final stemDiameter = parseMeasurementInput(_stemDiameterController.text);

    setState(() {
      _capError = cap.isValid ? null : cap.status;
      _stemError = stem.isValid ? null : stem.status;
      _stemDiameterError = stemDiameter.isValid ? null : stemDiameter.status;
    });
    if (!cap.isValid || !stem.isValid || !stemDiameter.isValid) return;

    final result = await _repo.identify(
      widget.locale.languageCode,
      _selected,
      observationMonth: _seasonRegion == null ? null : _observationMonth,
      seasonRegionCode: _seasonRegion,
      capDiameterCm: cap.value,
      stemHeightCm: stem.value,
      stemDiameterCm: stemDiameter.value,
    );
    if (mounted) setState(() => _results = result);
  }

  String _monthName(int month) {
    const nl = [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const de = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    final values = widget.locale.languageCode == 'nl'
        ? nl
        : widget.locale.languageCode == 'de'
            ? de
            : en;
    return values[month - 1];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Determineren', 'Identify', 'Bestimmen'))),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<TraitChoice>>(
                  future: _choices,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final groups = <int, List<TraitChoice>>{};
                    for (final choice in snapshot.data!) {
                      groups.putIfAbsent(choice.traitId, () => []).add(choice);
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          t(
                            'Kies alleen kenmerken die je zeker ziet. Metingen en seizoen zijn optionele aanvullende aanwijzingen.',
                            'Select only characteristics you can observe confidently. Measurements and season are optional supporting evidence.',
                            'Wähle nur Merkmale, die du sicher beobachten kannst. Maße und Saison sind optionale Zusatzhinweise.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...groups.values.map(
                          (items) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    items.first.traitLabel,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  RadioGroup<int>(
                                    groupValue: _selected[items.first.traitId],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() =>
                                          _selected[items.first.traitId] = value);
                                    },
                                    child: Column(
                                      children: items
                                          .map(
                                            (choice) => RadioListTile<int>(
                                              title: Text(choice.optionLabel),
                                              value: choice.optionId,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  if (_selected.containsKey(items.first.traitId))
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _selected
                                            .remove(items.first.traitId),
                                      ),
                                      child: Text(
                                        t('Overslaan', 'Clear', 'Löschen'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(
                                    'Aanvullende veldgegevens',
                                    'Supporting field data',
                                    'Zusätzliche Felddaten',
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _capController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) {
                                    if (_capError != null) {
                                      setState(() => _capError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: t(
                                      'Hoeddiameter (cm)',
                                      'Cap diameter (cm)',
                                      'Hutdurchmesser (cm)',
                                    ),
                                    errorText: _measurementError(_capError),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _stemController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) {
                                    if (_stemError != null) {
                                      setState(() => _stemError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: t(
                                      'Steelhoogte (cm)',
                                      'Stem height (cm)',
                                      'Stielhöhe (cm)',
                                    ),
                                    errorText: _measurementError(_stemError),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _stemDiameterController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) {
                                    if (_stemDiameterError != null) {
                                      setState(() => _stemDiameterError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: t(
                                      'Steeldiameter (cm)',
                                      'Stem diameter (cm)',
                                      'Stieldurchmesser (cm)',
                                    ),
                                    errorText:
                                        _measurementError(_stemDiameterError),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<SeasonRegionOption>>(
                                  future: _regions,
                                  builder: (context, regionSnapshot) {
                                    final regions = regionSnapshot.data ??
                                        const <SeasonRegionOption>[];
                                    final selectedRegion = regions
                                        .where((r) => r.code == _seasonRegion)
                                        .firstOrNull;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DropdownButtonFormField<String?>(
                                          key: ValueKey(_seasonRegion),
                                          initialValue: _seasonRegion,
                                          decoration: InputDecoration(
                                            labelText: t(
                                              'Seizoensreferentie',
                                              'Season reference',
                                              'Saisonreferenz',
                                            ),
                                          ),
                                          items: [
                                            DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text(
                                                t(
                                                  'Niet gebruiken',
                                                  'Do not use',
                                                  'Nicht verwenden',
                                                ),
                                              ),
                                            ),
                                            ...regions.map(
                                              (region) =>
                                                  DropdownMenuItem<String?>(
                                                value: region.code,
                                                child: Text(region.label),
                                              ),
                                            ),
                                          ],
                                          onChanged: regionSnapshot.hasData
                                              ? (value) => setState(() {
                                                    _seasonRegion = value;
                                                    if (value == null) {
                                                      _observationMonth = null;
                                                    }
                                                  })
                                              : null,
                                        ),
                                        if (_seasonRegion != null) ...[
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<int>(
                                            key: ValueKey(
                                              '$_seasonRegion-$_observationMonth',
                                            ),
                                            initialValue: _observationMonth,
                                            decoration: InputDecoration(
                                              labelText: t(
                                                'Waarnemingsmaand',
                                                'Observation month',
                                                'Beobachtungsmonat',
                                              ),
                                            ),
                                            items: List.generate(
                                              12,
                                              (index) => DropdownMenuItem(
                                                value: index + 1,
                                                child: Text(
                                                  _monthName(index + 1),
                                                ),
                                              ),
                                            ),
                                            onChanged: (value) => setState(
                                              () => _observationMonth = value,
                                            ),
                                          ),
                                          if (selectedRegion != null &&
                                              selectedRegion.note.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              selectedRegion.note,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _identify,
                          icon: const Icon(Icons.filter_alt),
                          label: Text(
                            t(
                              'Toon kandidaten',
                              'Show candidates',
                              'Kandidaten anzeigen',
                            ),
                          ),
                        ),
                        if (_results != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            t('Resultaten', 'Results', 'Ergebnisse'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_results!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                t(
                                  'Geen overeenkomsten. Pas kenmerken of veldgegevens aan.',
                                  'No matches. Adjust the selected traits or field data.',
                                  'Keine Treffer. Passe Merkmale oder Felddaten an.',
                                ),
                              ),
                            ),
                          ..._results!.map((result) {
                            final morphology = result.requested == 0
                                ? t(
                                    'geen morfologie',
                                    'no morphology',
                                    'keine Morphologie',
                                  )
                                : '${result.matched}/${result.requested} ${t('kenmerken', 'traits', 'Merkmale')}';
                            final field = result.fieldRequested == 0
                                ? ''
                                : ' · ${result.fieldMatched}/${result.fieldRequested} ${t('veld', 'field', 'Feld')}';
                            final scoreLabel = t(
                              'matchscore',
                              'match score',
                              'Übereinstimmungswert',
                            );
                            return ListTile(
                              title: Text(result.species.commonName),
                              subtitle: Text(
                                '${result.species.scientificName} · $scoreLabel ${(result.score * 100).round()}% · $morphology$field',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SpeciesScreen(
                                    locale: widget.locale,
                                    speciesId: result.species.id,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
