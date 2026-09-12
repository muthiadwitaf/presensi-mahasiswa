import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_liveness/core/services/liveness_service.dart';

void main() {
  group('LivenessService.decide (threshold decision)', () {
    test('score above threshold is classified real', () {
      final result = LivenessService.decide(0.8);
      expect(result.isReal, isTrue);
      expect(result.rawScore, 0.8);
    });

    test('score below threshold is classified spoof', () {
      final result = LivenessService.decide(0.2);
      expect(result.isReal, isFalse);
    });

    test('score exactly at threshold is classified real (inclusive)', () {
      final result = LivenessService.decide(LivenessService.threshold);
      expect(result.isReal, isTrue);
    });

    test('confidence reflects distance from the decision boundary', () {
      final real = LivenessService.decide(0.9);
      final spoof = LivenessService.decide(0.1);
      expect(real.confidence, closeTo(0.9, 1e-9));
      expect(spoof.confidence, closeTo(0.9, 1e-9));
    });
  });
}
