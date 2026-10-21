class ProcessingUnavailable implements Exception {
  const ProcessingUnavailable();
  @override
  String toString() =>
      'سرویس هوش مصنوعی هنوز متصل نشده است. مشخصات لباس را دستی تکمیل کنید.';
}

/// Deliberately disconnected for this local edition. No keys or HTTP calls.
class ProcessingService {
  Future<void> analyze(String garmentId) async {
    throw const ProcessingUnavailable();
  }
}
