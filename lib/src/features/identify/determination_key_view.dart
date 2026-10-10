import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'determination_key.dart';
import 'photographic_trait_wheel.dart';
import '../species/species_screen.dart';

const _gold = Color(0xfff2d6a0);
class DeterminationKeyView extends StatefulWidget {
  const DeterminationKeyView({super.key, required this.session, required this.locale});
  final DeterminationKeySession session;
  final Locale locale;
  @override
  State<DeterminationKeyView> createState() => _DeterminationKeyViewState();
}
class _DeterminationKeyViewState extends State<DeterminationKeyView> {
  int preview = 0, historyPreview = 0;
  DeterminationKeySession get session => widget.session;
  String text(String nl, String en, String de) =>
    widget.locale.languageCode == 'nl' ? nl : widget.locale.languageCode == 'de' ? de : en;
  String sourceLine(String source, int page) =>
    '${session.book.sources[source]}${page == 0 ? '' : ' · PDF $page'}';
  void change(VoidCallback action) => setState(() {
    action(); preview = 0; historyPreview = session.steps.length;
  });
  void details(KeyQuestion q) => showModalBottomSheet<void>(context: context,
    isScrollControlled: true, showDragHandle: true,
    builder: (context) => SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(q.title, style: Theme.of(context).textTheme.titleLarge),
        ...q.choices.map((c) => Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q.couplet}.${c.id} · ${c.text}'),
            Text(sourceLine(q.source, c.page)),
            TextButton(onPressed: () { Navigator.pop(context); change(() => session.choose(q.choices.indexOf(c))); },
              child: Text(text('Kies dit alternatief', 'Choose this alternative', 'Dieses Merkmal wählen'))),
          ])))),
      ]))));
  Widget photo(String path) => Image.asset(path, fit: BoxFit.cover,
    excludeFromSemantics: true);
  Widget dial(KeyQuestion q) => LayoutBuilder(builder: (context, bounds) {
    final size = math.min(bounds.maxHeight, bounds.maxWidth);
    final history = [...session.steps.map((s) => session.book.questions[s.question]!), q];
    final selectedHistory = historyPreview.clamp(0, history.length - 1);
    return Center(child: SizedBox.square(dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        PhotographicChoiceDial(key: ValueKey('key-choice-${q.id}'),
          count: q.choices.length, selected: preview, inner: .56,
          label: text('Keuzeschijf', 'Choice dial', 'Optionsscheibe'),
          labels: q.choices.map((c) => '${q.couplet}.${c.id}').toList(),
          imageBuilder: (i) => photo(q.choices[i].image),
          onChanged: (i) => setState(() => preview = i)),
        SizedBox.square(dimension: size * .54,
          child: PhotographicChoiceDial(key: const ValueKey('key-route-dial'),
            count: history.length, selected: selectedHistory, inner: .55,
            label: text('Determinatiepad', 'Determination path', 'Bestimmungspfad'),
            labels: List.generate(history.length, (i) => '${i + 1} · ${history[i].title}'),
            imageBuilder: (i) => photo(history[i].choices.first.image),
            onChanged: (i) => setState(() => historyPreview = i))),
        SizedBox.square(dimension: size * .28,
          child: ClipOval(child: Material(color: const Color(0xff203b29),
            child: InkWell(key: const ValueKey('open-key-step'),
              onTap: selectedHistory < session.steps.length
                ? () => change(() => session.revisit(selectedHistory)) : null,
              child: Center(child: Padding(padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                  '${text('Stap', 'Step', 'Schritt')} ${selectedHistory + 1}\n${text('Open', 'Open', 'Öffnen')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _gold, fontWeight: FontWeight.bold))))))))),
        Positioned(top: 0, child: IgnorePointer(child: Icon(Icons.arrow_drop_down,
          color: _gold, size: size * .1))),
        Positioned(top: size * .22, child: const IgnorePointer(child:
          Icon(Icons.arrow_drop_down, color: _gold, size: 22))),
      ])));
  });
  Widget controls(KeyQuestion q) => Column(mainAxisSize: MainAxisSize.min, children: [
    Row(children: [
      IconButton(tooltip: text('Vorige keuze', 'Previous choice', 'Vorige Option'),
        onPressed: () => setState(() => preview = (preview - 1) % q.choices.length),
        icon: const Icon(Icons.chevron_left, color: _gold)),
      Expanded(child: FilledButton(key: const ValueKey('confirm-key-choice'),
        style: FilledButton.styleFrom(backgroundColor: _gold,
          foregroundColor: const Color(0xff203b29)),
        onPressed: () => change(() => session.choose(preview)),
        child: Text(text('Bevestig ${q.couplet}.${q.choices[preview].id}',
          'Confirm ${q.couplet}.${q.choices[preview].id}',
          '${q.couplet}.${q.choices[preview].id} bestätigen')))),
      IconButton(tooltip: text('Volgende keuze', 'Next choice', 'Nächste Option'),
        onPressed: () => setState(() => preview = (preview + 1) % q.choices.length),
        icon: const Icon(Icons.chevron_right, color: _gold)),
    ]),
    Wrap(alignment: WrapAlignment.center, children: [
      TextButton(onPressed: session.steps.isEmpty ? null : () => change(session.back),
        child: Text(text('Terug', 'Back', 'Zurück'), style: const TextStyle(color: _gold))),
      TextButton(onPressed: () => details(q), child: Text(text('Alle voorwaarden',
        'All conditions', 'Alle Bedingungen'), style: const TextStyle(color: _gold))),
      TextButton(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
        content: Text(text('Geen alternatief zeker? Bekijk beide voorwaarden. Ga terug als geen van beide past. Zonder keuze wordt geen soort bepaald.',
          'Unsure? Read both conditions. Go back if neither fits. No species is determined without a choice.',
          'Unsicher? Beide Bedingungen lesen. Zurückgehen, wenn keine passt. Ohne Auswahl wird keine Art bestimmt.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])),
        child: Text(text('Onzeker', 'Unsure', 'Unsicher'), style: const TextStyle(color: _gold))),
    ]),
  ]);
  Widget result(KeyEndpoint endpoint) {
    final species = session.book.resolve(endpoint);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(text('Uitkomst van het determinatiepad', 'Determination path endpoint', 'Ergebnis des Bestimmungspfads'),
        style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(endpoint.name, key: const ValueKey('key-endpoint'),
            style: Theme.of(context).textTheme.headlineSmall),
          if (endpoint.detail != endpoint.name) Text(endpoint.detail),
          Text(sourceLine(endpoint.source, endpoint.page)),
          const SizedBox(height: 12),
          Text(species != null
            ? text('Soort gekoppeld aan de Nederlandse GBIF-checklist.', 'Species linked to the Dutch GBIF checklist.', 'Art mit der niederländischen GBIF-Checkliste verknüpft.')
            : endpoint.kind == 'species'
              ? text('Soortnaam uit de sleutel; nog geen unieke koppeling aan de Nederlandse checklist. Er wordt geen andere soort geraden.',
                'Species named by the key; no unique Dutch checklist link yet. No substitute species is inferred.',
                'Artname aus dem Schlüssel; noch keine eindeutige niederländische Verknüpfung. Keine Ersatzart wird abgeleitet.')
              : text('De sleutel stopt hier bij een groep, vervolgonderzoek of een onvolledige bronregel. Dit is geen bevestigde soort.',
                'The key stops at a group, further examination or an incomplete source. This is not a confirmed species.',
                'Der Schlüssel endet bei einer Gruppe, weiterer Untersuchung oder einer unvollständigen Quelle. Keine bestätigte Art.')),
          if (species != null) ...[
            SelectableText('NL · ${species.recordId}'),
            FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => SpeciesScreen(locale: widget.locale, speciesId: species.id))),
              child: Text(text('Bekijk soort', 'View species', 'Art anzeigen'))),
          ],
          Text(text('De uitkomst volgt je gekozen voorwaarden; dit is geen kansscore.',
            'This endpoint follows your chosen conditions; it is not a probability score.',
            'Dieses Ergebnis folgt den gewählten Bedingungen; kein Wahrscheinlichkeitswert.')),
        ]))),
      ...session.steps.map((s) {
        final q = session.book.questions[s.question]!;
        final c = q.choices[s.choice];
        return Card(child: ListTile(title: Text('${q.couplet}.${c.id} · ${c.text}'),
          subtitle: Text(sourceLine(q.source, c.page)),
          onTap: () => change(() => session.revisit(session.steps.indexOf(s)))));
      }),
      FilledButton(onPressed: () => change(session.back), child: Text(text('Terug', 'Back', 'Zurück'))),
      TextButton(onPressed: () => change(session.reset), child: Text(text('Opnieuw', 'Restart', 'Neu beginnen'),
        style: const TextStyle(color: _gold))),
    ]);
  }
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(image: DecorationImage(
      image: AssetImage('determination_wheel/assets/interface/woodland-background.png'),
      fit: BoxFit.cover)),
    child: ColoredBox(color: const Color(0x88313c25), child: session.endpoint != null
      ? result(session.endpoint!) : LayoutBuilder(builder: (context, bounds) {
        final q = session.question!;
        final condition = Card(color: const Color(0xff203b29),
          child: SingleChildScrollView(padding: const EdgeInsets.all(12),
            child: Text(q.choices[preview].text, key: const ValueKey('key-condition'),
              style: const TextStyle(color: Colors.white, fontSize: 14))));
        final heading = Text('${q.title} · ${q.couplet} · ${text('Stap', 'Step', 'Schritt')} ${session.steps.length + 1}',
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 16));
        final wide = MediaQuery.orientationOf(context) == Orientation.landscape && bounds.maxWidth > bounds.maxHeight * 1.2;
        return Padding(padding: const EdgeInsets.all(8), child: wide
          ? Row(children: [Expanded(child: dial(q)), Expanded(child: Column(children: [
              heading, Expanded(child: condition), controls(q)]))])
          : Column(children: [heading,
              SizedBox(height: bounds.maxHeight * .24, child: condition),
              Expanded(child: dial(q)), controls(q),
              Text(text('Illustraties tonen een kenmerkcontext; lees alle voorwaarden.',
                'Photos show context; read all conditions.', 'Fotos zeigen den Kontext; alle Bedingungen lesen.'),
                textAlign: TextAlign.center, style: const TextStyle(color: _gold, fontSize: 10)),
            ]));
      })));
}
