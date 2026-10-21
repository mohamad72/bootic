enum FieldType {
  text('متن کوتاه'),
  longText('متن بلند'),
  integer('عدد صحیح'),
  decimal('عدد اعشاری'),
  boolean('بله یا خیر'),
  singleSelect('انتخاب تکی'),
  multiSelect('انتخاب چندتایی'),
  date('تاریخ'),
  year('سال میلادی'),
  yearRange('بازه سال'),
  numberRange('بازه عدد'),
  color('کد رنگ'),
  score('امتیاز صفر تا یک'),
  tags('برچسب‌ها');

  const FieldType(this.label);
  final String label;
}

class FieldDefinition {
  const FieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = false,
    this.enabled = true,
  });
  final String key, label;
  final FieldType type;
  final List<String> options;
  final bool required, enabled;

  FieldDefinition copyWith({String? label, bool? enabled}) => FieldDefinition(
    key: key,
    label: label ?? this.label,
    type: type,
    options: options,
    required: required,
    enabled: enabled ?? this.enabled,
  );

  String? validate(Object? value) {
    if (value == null || value == '' || (value is List && value.isEmpty)) {
      return required ? 'این مشخصه ضروری است' : null;
    }
    final valid = switch (type) {
      FieldType.text => value is String && value.length <= 500,
      FieldType.longText => value is String && value.length <= 4000,
      FieldType.integer => value is int,
      FieldType.decimal => value is num && value.isFinite,
      FieldType.boolean => value is bool,
      FieldType.singleSelect => value is String && options.contains(value),
      FieldType.multiSelect =>
        value is List && value.length <= 100 && value.every(options.contains),
      FieldType.date => value is String && _validDate(value),
      FieldType.year => value is int && value >= 1900 && value <= 2200,
      FieldType.yearRange => _validRange(value, years: true),
      FieldType.numberRange => _validRange(value),
      FieldType.color =>
        value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value),
      FieldType.score =>
        value is num && value.isFinite && value >= 0 && value <= 1,
      FieldType.tags =>
        value is List &&
            value.length <= 20 &&
            value.every(
              (v) => v is String && v.trim().isNotEmpty && v.length <= 80,
            ),
    };
    return valid ? null : 'مقدار ${type.label} معتبر وارد کنید';
  }

  static bool _validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  static bool _validRange(Object? value, {bool years = false}) =>
      value is List &&
      value.length == 2 &&
      value.every(
        (v) =>
            v is num &&
            v.isFinite &&
            (!years || (v is int && v >= 1900 && v <= 2200)),
      ) &&
      (value[0] as num) <= (value[1] as num);

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'options': options,
    'required': required,
    'enabled': enabled,
  };
  factory FieldDefinition.fromJson(Map<String, dynamic> j) => FieldDefinition(
    key: j['key'] as String,
    label: j['label'] as String,
    type: FieldType.values.byName(j['type'] as String),
    options: List<String>.from(j['options'] as List),
    required: j['required'] as bool,
    enabled: j['enabled'] as bool,
  );
}

const baseFields = [
  FieldDefinition(key: 'primaryColor', label: 'رنگ اصلی', type: FieldType.text),
  FieldDefinition(
    key: 'material',
    label: 'جنس پارچه (طبق برچسب یا نظر متصدی)',
    type: FieldType.text,
  ),
  FieldDefinition(
    key: 'styles',
    label: 'استایل',
    type: FieldType.multiSelect,
    options: ['روزمره', 'رسمی', 'اسپرت', 'مجلسی', 'مینیمال'],
  ),
  FieldDefinition(
    key: 'fit',
    label: 'فرم لباس',
    type: FieldType.singleSelect,
    options: ['آزاد', 'معمولی', 'جذب'],
  ),
  FieldDefinition(
    key: 'pattern',
    label: 'طرح پارچه',
    type: FieldType.singleSelect,
    options: ['ساده', 'راه‌راه', 'چهارخانه', 'گل‌دار', 'طرح‌دار'],
  ),
  FieldDefinition(
    key: 'season',
    label: 'فصل',
    type: FieldType.multiSelect,
    options: ['بهار', 'تابستان', 'پاییز', 'زمستان', 'چهارفصل'],
  ),
  FieldDefinition(key: 'occasions', label: 'مناسب برای', type: FieldType.tags),
  FieldDefinition(
    key: 'notes',
    label: 'یادداشت متصدی',
    type: FieldType.longText,
  ),
];
