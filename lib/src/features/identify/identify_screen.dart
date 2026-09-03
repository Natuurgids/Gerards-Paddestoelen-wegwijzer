import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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
  bool _seasonMonthMissing = false;

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

  String? _measurementError(
    AppLocalizations l10n,
    MeasurementInputStatus? status,
  ) {
    if (status == MeasurementInputStatus.invalidNumber) {
      return l10n.identifyInvalidNumber;
    }
    if (status == MeasurementInputStatus.nonPositive) {
      return l10n.identifyNonPositive;
    }
    return null;
  }

  String? _seasonMonthError(AppLocalizations l10n) =>
      _seasonMonthMissing ? l10n.identifyObservationMonthRequired : null;

  Future<void> _identify() async {
    final cap = parseMeasurementInput(_capController.text);
    final stem = parseMeasurementInput(_stemController.text);
    final stemDiameter = parseMeasurementInput(_stemDiameterController.text);
    final seasonMonthMissing =
        _seasonRegion != null && _observationMonth == null;

    setState(() {
      _capError = cap.isValid ? null : cap.status;
      _stemError = stem.isValid ? null : stem.status;
      _stemDiameterError = stemDiameter.isValid ? null : stemDiameter.status;
      _seasonMonthMissing = seasonMonthMissing;
    });
    if (!cap.isValid ||
        !stem.isValid ||
        !stemDiameter.isValid ||
        seasonMonthMissing) {
      return;
    }

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

  String _monthName(AppLocalizations l10n, int month) {
    final values = [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ];
    return values[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.identifyTitle)),
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
                      Text(l10n.identifyIntro),
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
                                      () => _selected.remove(items.first.traitId),
                                    ),
                                    child: Text(l10n.identifyClear),
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
                                l10n.identifyFieldData,
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
                                  labelText: l10n.identifyCapDiameter,
                                  errorText: _measurementError(l10n, _capError),
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
                                  labelText: l10n.identifyStemHeight,
                                  errorText: _measurementError(l10n, _stemError),
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
                                  labelText: l10n.identifyStemDiameter,
                                  errorText:
                                      _measurementError(l10n, _stemDiameterError),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String?>(
                                        key: ValueKey(_seasonRegion),
                                        initialValue: _seasonRegion,
                                        decoration: InputDecoration(
                                          labelText: l10n.identifySeasonReference,
                                        ),
                                        items: [
                                          DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(l10n.identifyDoNotUse),
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
                                                  _seasonMonthMissing = false;
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
                                            labelText:
                                                l10n.identifyObservationMonth,
                                            errorText: _seasonMonthError(l10n),
                                          ),
                                          items: List.generate(
                                            12,
                                            (index) => DropdownMenuItem(
                                              value: index + 1,
                                              child: Text(
                                                _monthName(l10n, index + 1),
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) => setState(() {
                                            _observationMonth = value;
                                            _seasonMonthMissing = false;
                                          }),
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
                        label: Text(l10n.identifyShowCandidates),
                      ),
                      if (_results != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          l10n.identifyResults,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_results!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l10n.identifyNoMatches),
                          ),
                        ..._results!.map((result) {
                          final morphology = result.requested == 0
                              ? l10n.identifyNoMorphology
                              : '${result.matched}/${result.requested} ${l10n.identifyTraits}';
                          final field = result.fieldRequested == 0
                              ? ''
                              : ' · ${result.fieldMatched}/${result.fieldRequested} ${l10n.identifyField}';
                          return ListTile(
                            title: Text(result.species.commonName),
                            subtitle: Text(
                              '${result.species.scientificName} · ${l10n.identifyMatchScore} ${(result.score * 100).round()}% · $morphology$field',
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
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
