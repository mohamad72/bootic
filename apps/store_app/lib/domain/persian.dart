String asciiDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    input = input.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return input;
}

String searchKey(String input) => asciiDigits(input)
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('\u200c', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

int? parseWhole(String input) {
  final normalized = asciiDigits(input).replaceAll(RegExp('[٬, ]'), '').trim();
  if (!RegExp(r'^-?\d+$').hasMatch(normalized)) return null;
  return int.tryParse(normalized);
}

String faDigits(Object value) {
  var text = value.toString();
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll('$i', '۰۱۲۳۴۵۶۷۸۹'[i]);
  }
  return text;
}

String faNumber(int value) => faDigits(
  value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '٬',
  ),
);
