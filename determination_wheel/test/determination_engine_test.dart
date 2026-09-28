import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/main.dart';

void main() {
  group('source-grounded candidate filtering', () {
    test('pink spores + free gills + no visible velum retains Pluteus', () {
      final answers = <int, String>{
        5: 'Glad',
        6: 'Vrij',
        7: 'Geen zichtbaar',
        9: 'Roze',
        17: 'Dood hout',
      };
      final remaining = candidates.where((c) => c.matches(answers)).map((c) => c.name).toList();
      expect(remaining, contains('Hertenzwammen · Pluteus'));
    });

    test('white spores exclude Pluteus with an explicit spore-colour reason', () {
      final answers = <int, String>{9: 'Wit / crème'};
      final pluteus = candidates.firstWhere((c) => c.name.contains('Pluteus'));
      expect(pluteus.matches(answers), isFalse);
      expect(pluteus.conflict(answers), contains('sporenkleur'));
      expect(pluteus.conflict(answers), contains('Roze'));
    });

    test('unknown observation never excludes a candidate', () {
      final answers = <int, String>{6: 'Onzeker', 7: 'Onzeker', 9: 'Onzeker', 17: 'Onzeker'};
      expect(candidates.where((c) => c.matches(answers)).length, candidates.length);
    });

    test('dead wood conflicts with source profile for Hebeloma', () {
      final answers = <int, String>{17: 'Dood hout'};
      final hebeloma = candidates.firstWhere((c) => c.name.contains('Hebeloma'));
      expect(hebeloma.matches(answers), isFalse);
      expect(hebeloma.conflict(answers), contains('substraat'));
    });

    test('milk observation does not itself eliminate Russulaceae candidate', () {
      final answers = <int, String>{9: 'Wit / crème', 17: 'Bodem / strooisel', 22: 'Melksap aanwezig'};
      final russulaceae = candidates.firstWhere((c) => c.name.startsWith('Russulaceae'));
      expect(russulaceae.matches(answers), isTrue);
    });
  });
}
