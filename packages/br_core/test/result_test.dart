import 'package:br_core/br_core.dart';
import 'package:test/test.dart';

void main() {
  group('Result<T,E>', () {
    test('Success.when calls success branch', () {
      const r = Success<int, String>(42);
      expect(r.when(success: (v) => v * 2, failure: (_) => 0), 84);
      expect(r.isSuccess, true);
      expect(r.valueOrNull, 42);
    });

    test('Failure.when calls failure branch', () {
      const r = Failure<int, String>('boom');
      expect(r.when(success: (_) => 0, failure: (e) => e.length), 4);
      expect(r.isFailure, true);
      expect(r.errorOrNull, 'boom');
    });

    test('map transforms success only', () {
      const r = Success<int, String>(3);
      expect(r.map((v) => '$v').valueOrNull, '3');
    });

    test('flatMap chains operations', () {
      const r = Success<int, String>(3);
      expect(r.flatMap((v) => Success<int, String>(v * 10)).valueOrNull, 30);
    });
  });

  group('SgFailure', () {
    test('SgBrocPdfFailure is SgBrocFailure is SgFailure', () {
      const f = SgBrocPdfFailure('pdf gen failed');
      expect(f, isA<SgBrocFailure>());
      expect(f, isA<SgFailure>());
      expect(f.message, 'pdf gen failed');
    });
  });
}
