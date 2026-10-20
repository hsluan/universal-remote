import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/pairing/ac_code_search.dart';

void main() {
  final registry = createStandardAcRegistry();

  group('AcEncoderRegistry', () {
    test('ids are unique and resolvable', () {
      final ids = registry.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(registry.require(id).id, id);
      }
      expect(registry.find('nope'), isNull);
    });

    test('candidates put the brand codes first, then every other code once', () {
      final candidates = registry.candidatesFor(['gree_ybofb', 'gree_yaw1f', 'unknown']);
      expect(candidates.take(2).map((e) => e.id), ['gree_ybofb', 'gree_yaw1f']);
      expect(candidates.length, registry.all.length);
      expect(candidates.map((e) => e.id).toSet().length, candidates.length);
    });
  });

  group('AcCodeSearch', () {
    AcCodeSearch create() {
      final candidates = registry.candidatesFor(['daikin']);
      return AcCodeSearch(candidates: candidates, preferredCount: 1);
    }

    test('walks candidates until exhausted', () {
      final search = create();
      expect(search.position, 1);
      expect(search.isPreferred, isTrue);
      search.reject();
      expect(search.position, 2);
      expect(search.isPreferred, isFalse);
      for (var i = 1; i < search.total; i++) {
        search.reject();
      }
      expect(search.isExhausted, isTrue);
      expect(() => search.current, throwsStateError);
    });

    test('accept, rejectMatch and back', () {
      final search = create()..reject();
      final second = search.current;
      search.accept();
      expect(search.match, second);
      search.rejectMatch();
      expect(search.match, isNull);
      expect(search.position, 3);
      search.back();
      expect(search.current, second);
      search.restart();
      expect(search.position, 1);
    });
  });
}
