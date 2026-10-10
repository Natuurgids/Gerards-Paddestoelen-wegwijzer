import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/features/identify/determination_key.dart';

void main() {
  final book = DeterminationKeyBook(
    jsonDecode(File('assets/data/determination_keys.json').readAsStringSync()) as Map<String, dynamic>,
    jsonDecode(File('assets/data/species_catalog.json').readAsStringSync()) as Map<String, dynamic>);
  List<int> pathTo(String name) {
    final queue = Queue<(String, List<int>)>()..add((book.start, []));
    final seen = <String>{};
    while (queue.isNotEmpty) {
      final (id, path) = queue.removeFirst();
      if (!seen.add(id)) continue;
      if (book.endpoints[id]?.name == name) return path;
      final q = book.questions[id];
      if (q != null) {
        for (var i = 0; i < q.choices.length; i++) {
          queue.add((q.choices[i].target, [...path, i]));
        }
      }
    }
    throw StateError('No source path to $name');
  }
  test('the full source graph has 1066 questions, all destinations and photos exist', () {
    expect(book.questions.length, 1066);
    final seen = <String>{}, todo = [book.start];
    while (todo.isNotEmpty) {
      final id = todo.removeLast();
      if (!seen.add(id)) continue;
      final q = book.questions[id];
      if (q != null) {
        expect(q.choices.length, 2);
        for (final c in q.choices) {
          expect(File(c.image).existsSync(), isTrue, reason: c.image);
          expect(c.text.trim(), isNotEmpty);
          expect(c.page, inInclusiveRange(0, 45));
          todo.add(c.target);
        }
      } else { expect(book.endpoints.containsKey(id), isTrue); }
    }
    expect(seen.containsAll(book.questions.keys), isTrue);
  });
  for (final name in ['Boletus edulis', 'Lactarius deliciosus', 'Amanita muscaria', 'Hydnum repandum', 'Phallus impudicus']) {
    test('source-directed route reaches $name without a morphology profile', () {
      final session = DeterminationKeySession(book);
      for (final choice in pathTo(name)) { session.choose(choice); }
      expect(session.question, isNull);
      expect(session.endpoint!.name, name);
      expect(session.endpoint!.kind, 'species');
      expect(book.resolve(session.endpoint!), isNotNull);
      expect(session.steps, isNotEmpty);
    });
  }
  test('rewinding an earlier answer removes downstream route and species result', () {
    final s = DeterminationKeySession(book);
    for (final c in pathTo('Lactarius deliciosus')) { s.choose(c); }
    s.revisit(1);
    expect(s.endpoint, isNull);
    expect(s.current, 'veldguide-i/1/1');
    expect(s.steps.length, 1);
    s.choose(0);
    expect(s.current, 'veldguide-i/2/1');
    s.back();
    expect(s.current, 'veldguide-i/1/1');
    s.reset();
    expect(s.current, 'entry');
    expect(s.steps, isEmpty);
  });
  test('explicit cross references enter the cited couplet, not couplet 1', () {
    expect(book.questions['veldguide-ii/4/3']!.choices.first.target, 'veldguide-ii/5/11');
    expect(book.questions['veldguide-ii/10/35']!.choices.first.target, 'veldguide-ii/9/41');
  });
  test('groups and the incomplete printed source line cannot become a species', () {
    final groups = book.endpoints.values.where((e) => e.kind == 'group');
    expect(groups.length, greaterThan(100));
    for (final e in groups) { expect(book.resolve(e), isNull); }
    final gap = book.endpoints['veldguide-i/5/37/a']!;
    expect(gap.kind, 'source_gap');
    expect(book.resolve(gap), isNull);
  });
  test('exact national checklist linkage covers hundreds of key endpoints', () {
    final names = book.endpoints.values.where((e) => book.resolve(e) != null)
      .map((e) => e.name).toSet();
    expect(names.length, greaterThan(700));
    final broad = KeyEndpoint({'id':'x','name':'Boletus edulis','kind':'group',
      'detail':'Broad group','source':'entry','page':0});
    expect(book.resolve(broad), isNull);
  });
  test('invalid choice cannot mutate the path', () {
    final s = DeterminationKeySession(book);
    expect(() => s.choose(7), throwsStateError);
    expect(s.current, 'entry');
    expect(s.steps, isEmpty);
  });
}
