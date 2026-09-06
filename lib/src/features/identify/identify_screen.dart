import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/resilient_identification_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/conservation_warning.dart';
import '../../widgets/safety_notice.dart';
import '../species/species_screen.dart';
import 'determination_option_visual.dart';
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
    _repo = widget.repository ?? ResilientIdentificationRepository();
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

  void _retryChoices() =>
      setState(() => _choices = _repo.choices(widget.locale.languageCode));

  String? _measurementError(
    AppLocalizations l,
    MeasurementInputStatus? status,
  ) =>
      status == MeasurementInputStatus.invalidNumber
          ? l.identifyInvalidNumber
          : status == MeasurementInputStatus.nonPositive
              ? l.identifyNonPositive
              : null;

  Future<void> _identify() async {
    final cap = parseMeasurementInput(_capController.text);
    final stem = parseMeasurementInput(_stemController.text);
    final diameter = parseMeasurementInput(_stemDiameterController.text);
    final missingMonth = _seasonRegion != null && _observationMonth == null;
    setState(() {
      _capError = cap.isValid ? null : cap.status;
      _stemError = stem.isValid ? null : stem.status;
      _stemDiameterError = diameter.isValid ? null : diameter.status;
      _seasonMonthMissing = missingMonth;
    });
    if (!cap.isValid || !stem.isValid || !diameter.isValid || missingMonth) {
      return;
    }
    final results = await _repo.identify(
      widget.locale.languageCode,
      _selected,
      observationMonth: _seasonRegion == null ? null : _observationMonth,
      seasonRegionCode: _seasonRegion,
      capDiameterCm: cap.value,
      stemHeightCm: stem.value,
      stemDiameterCm: diameter.value,
    );
    if (mounted) setState(() => _results = results);
  }

  String _monthName(AppLocalizations l, int month) => [
        l.monthJan,
        l.monthFeb,
        l.monthMar,
        l.monthApr,
        l.monthMay,
        l.monthJun,
        l.monthJul,
        l.monthAug,
        l.monthSep,
        l.monthOct,
        l.monthNov,
        l.monthDec,
      ][month - 1];

  ShapeBorder get _cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      );

  Widget _introPanel(BuildContext context, AppLocalizations l) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.travel_explore, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.identifyTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.identifyIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .88),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _traitCard(
    BuildContext context,
    AppLocalizations l,
    List<TraitChoice> items,
  ) {
    final selected = _selected[items.first.traitId];
    return Card(
      elevation: 0,
      color: AppTheme.creamStrong,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.moss.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    size: 19,
                    color: AppTheme.forest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items.first.traitLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.moss.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.forest,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              key: ValueKey('trait-grid-${items.first.traitId}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 156,
                mainAxisExtent: 140,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final choice = items[index];
                final isSelected = selected == choice.optionId;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(
                    () => _selected[choice.traitId] = choice.optionId,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.forest : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? AppTheme.moss.withValues(alpha: .13)
                          : AppTheme.cream,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DeterminationOptionVisual(
                          traitCode: choice.traitCode,
                          optionId: choice.optionId,
                          optionLabel: choice.optionLabel,
                          size: 64,
                        ),
                        const SizedBox(height: 5),
                        Flexible(
                          child: Text(
                            choice.optionLabel,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppTheme.ink,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppTheme.forest,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (selected != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _selected.remove(items.first.traitId)),
                  icon: const Icon(Icons.clear),
                  label: Text(l.identifyClear),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fieldDataCard(AppLocalizations l) => Card(
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
                    child: const Icon(
                      Icons.straighten,
                      size: 20,
                      color: AppTheme.forest,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.identifyFieldData,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _capController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_capError != null) setState(() => _capError = null);
                },
                decoration: InputDecoration(
                  labelText: l.identifyCapDiameter,
                  errorText: _measurementError(l, _capError),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _stemController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_stemError != null) setState(() => _stemError = null);
                },
                decoration: InputDecoration(
                  labelText: l.identifyStemHeight,
                  errorText: _measurementError(l, _stemError),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _stemDiameterController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_stemDiameterError != null) {
                    setState(() => _stemDiameterError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: l.identifyStemDiameter,
                  errorText: _measurementError(l, _stemDiameterError),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<SeasonRegionOption>>(
                future: _regions,
                builder: (context, snapshot) {
                  final regions =
                      snapshot.data ?? const <SeasonRegionOption>[];
                  final selected = regions
                      .where((region) => region.code == _seasonRegion)
                      .firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String?>(
                        key: ValueKey(_seasonRegion),
                        initialValue: _seasonRegion,
                        decoration: InputDecoration(
                          labelText: l.identifySeasonReference,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l.identifyDoNotUse),
                          ),
                          ...regions.map(
                            (region) => DropdownMenuItem<String?>(
                              value: region.code,
                              child: Text(region.label),
                            ),
                          ),
                        ],
                        onChanged: snapshot.hasData
                            ? (value) => setState(() {
                                  _seasonRegion = value;
                                  _seasonMonthMissing = false;
                                  if (value == null) _observationMonth = null;
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
                            labelText: l.identifyObservationMonth,
                            errorText: _seasonMonthMissing
                                ? l.identifyObservationMonthRequired
                                : null,
                          ),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(_monthName(l, index + 1)),
                            ),
                          ),
                          onChanged: (value) => setState(() {
                            _observationMonth = value;
                            _seasonMonthMissing = false;
                          }),
                        ),
                        if (selected != null && selected.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            selected.note,
                            style: Theme.of(context).textTheme.bodySmall,
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
      );

  List<Widget> _resultWidgets(AppLocalizations l) {
    if (_results == null) return const [];
    return [
      const SizedBox(height: 20),
      Row(
        children: [
          const Icon(Icons.manage_search, color: AppTheme.forest),
          const SizedBox(width: 8),
          Text(
            l.identifyResults,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_results!.isEmpty)
        Card(
          elevation: 0,
          color: AppTheme.creamStrong,
          shape: _cardShape,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.identifyNoMatches),
          ),
        ),
      ..._results!.map((result) {
        final morphology = result.requested == 0
            ? l.identifyNoMorphology
            : '${result.matched}/${result.requested} ${l.identifyTraits}';
        final field = result.fieldRequested == 0
            ? ''
            : ' · ${result.fieldMatched}/${result.fieldRequested} ${l.identifyField}';
        return Card(
          elevation: 0,
          color: AppTheme.creamStrong,
          shape: _cardShape,
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SpeciesScreen(
                  locale: widget.locale,
                  speciesId: result.species.id,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.moss.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: AppTheme.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.species.commonName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${result.species.scientificName} · ${l.identifyMatchScore} ${(result.score * 100).round()}% · $morphology$field',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        ConservationWarning(
                          speciesId: result.species.id,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.chevron_right, color: AppTheme.forest),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.identifyTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<TraitChoice>>(
                future: _choices,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: IconButton(
                        onPressed: _retryChoices,
                        icon: const Icon(Icons.refresh),
                        iconSize: 40,
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final groups = <int, List<TraitChoice>>{};
                  for (final choice
                      in snapshot.data ?? const <TraitChoice>[]) {
                    groups.putIfAbsent(choice.traitId, () => []).add(choice);
                  }
                  final list = groups.values.toList(growable: false);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 900
                          ? 32.0
                          : 16.0;
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              16,
                              horizontalPadding,
                              12,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 980),
                                  child: _introPanel(context, l),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 980),
                                    child: _traitCard(context, l, list[index]),
                                  ),
                                ),
                                childCount: list.length,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              0,
                              horizontalPadding,
                              16,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate.fixed([
                                Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 980),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _fieldDataCard(l),
                                        SizedBox(
                                          height: 48,
                                          child: FilledButton.icon(
                                            onPressed: _identify,
                                            icon: const Icon(Icons.filter_alt),
                                            label: Text(
                                              l.identifyShowCandidates,
                                            ),
                                          ),
                                        ),
                                        ..._resultWidgets(l),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
