import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/domain/garment.dart';
import 'package:store_app/domain/persian.dart';
import 'package:store_app/domain/field_definition.dart';
import 'package:store_app/domain/local_access.dart';

void main() {
  test(
    'local entry accepts Persian and Arabic digits but rejects wrong codes',
    () {
      expect(LocalAccess.accepts('۲۲۲۲۲'), isTrue);
      expect(LocalAccess.accepts('٢٢٢٢٢'), isTrue);
      expect(LocalAccess.accepts('22222'), isTrue);
      expect(LocalAccess.accepts('2222'), isFalse);
      expect(LocalAccess.accepts('12345'), isFalse);
    },
  );
  test('search unifies Arabic letters and Persian spacing', () {
    expect(searchKey('  پيراهن كتان‌ آبی '), 'پیراهن کتان آبی');
    expect(parseWhole('۴٬۸۹۰٬۰۰۰'), 4890000);
    expect(parseWhole('۱.۵'), isNull);
    expect(faNumber(1234000), '۱٬۲۳۴٬۰۰۰');
  });
  test(
    'commercial validation rejects impossible amounts and preserves unknown measurements',
    () {
      final g = Garment.create(id: 'g', name: 'مانتو');
      expect(g.measurements, isEmpty);
      expect(
        g.copyWith(price: -1).validate(),
        contains('قیمت نمی‌تواند منفی باشد'),
      );
      expect(g.copyWith(price: 100, discountPrice: 100).validate(), isNotEmpty);
      expect(g.copyWith(stock: -1).validate(), isNotEmpty);
      expect(
        g.copyWith(price: 100, discountPrice: 80, stock: 2).validate(),
        isEmpty,
      );
      expect(g.tryOnEligible, isFalse);
    },
  );
  test(
    'garment JSON survives a round trip without dropping local metadata or photo angles',
    () {
      final g = Garment.create(id: 'g', name: 'کت').copyWith(
        price: 2500000,
        metadata: {'material': 'کتان', 'custom.a': true},
        photos: {'front': 'g/front.jpg'},
        measurements: {'chest': 420},
      );
      final restored = Garment.fromJson(g.toJson());
      expect(restored.price, 2500000);
      expect(restored.metadata['custom.a'], true);
      expect(restored.photos['front'], 'g/front.jpg');
      expect(restored.measurements['chest'], 420);
    },
  );
  test(
    'typed custom fields reject invalid values and allow unknown optional values',
    () {
      const integer = FieldDefinition(
        key: 'a',
        label: 'تعداد',
        type: FieldType.integer,
      );
      expect(integer.validate('three'), isNotNull);
      expect(integer.validate(3), isNull);
      expect(integer.validate(null), isNull);
      const select = FieldDefinition(
        key: 'b',
        label: 'رنگ',
        type: FieldType.singleSelect,
        options: ['آبی'],
      );
      expect(select.validate('قرمز'), isNotNull);
      expect(select.validate('آبی'), isNull);
      const range = FieldDefinition(
        key: 'c',
        label: 'بازه',
        type: FieldType.numberRange,
      );
      expect(range.validate([20, 10]), isNotNull);
      expect(range.validate([10, 20]), isNull);
    },
  );
}
