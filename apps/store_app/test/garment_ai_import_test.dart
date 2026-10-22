import 'package:flutter_test/flutter_test.dart';
import '../tool/check_ai_import.dart';

void main() {
  test(
    'AI import validates, populates and persists the complete form safely',
    () {
      expect(runAiImportChecks(), greaterThanOrEqualTo(40));
    },
  );
}
