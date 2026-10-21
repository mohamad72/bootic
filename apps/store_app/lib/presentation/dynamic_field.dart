import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../domain/field_definition.dart';
import '../domain/persian.dart';

class DynamicField extends StatelessWidget {
  const DynamicField({
    required this.definition,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final FieldDefinition definition;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  Object? _parse(String raw) {
    final v = asciiDigits(raw.trim());
    if (v.isEmpty) return null;
    switch (definition.type) {
      case FieldType.integer:
      case FieldType.year:
        return int.tryParse(v) ?? raw;
      case FieldType.decimal:
      case FieldType.score:
        return double.tryParse(v.replaceAll('٫', '.')) ?? raw;
      case FieldType.numberRange:
      case FieldType.yearRange:
        final parts = v.split(RegExp('[,،]'));
        if (parts.length != 2) return raw;
        return parts.map((s) => num.tryParse(s.trim()) ?? s).toList();
      case FieldType.tags:
        return raw
            .split(RegExp('[,،]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      case FieldType.date:
        final parts = v.split('/').map(int.tryParse).toList();
        if (parts.length != 3 || parts.any((n) => n == null)) return raw;
        try {
          return Jalali(
            parts[0]!,
            parts[1]!,
            parts[2]!,
          ).toDateTime().toIso8601String().substring(0, 10);
        } catch (_) {
          return raw;
        }
      default:
        return raw.trim();
    }
  }

  String _display() {
    if (value == null) return '';
    if (definition.type == FieldType.date && value is String) {
      final date = DateTime.tryParse(value as String);
      if (date != null) {
        try {
          final j = Jalali.fromDateTime(date);
          return faDigits('${j.year}/${j.month}/${j.day}');
        } catch (_) {
          // Keep unsupported stored dates visible so they can be corrected.
        }
      }
    }
    if (value is List) return (value as List).join('، ');
    if (value is num) return faDigits(value!);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final f = definition;
    if (f.type == FieldType.boolean) {
      return DropdownButtonFormField<bool>(
        initialValue: value is bool ? value as bool : null,
        decoration: InputDecoration(labelText: f.label),
        items: const [
          DropdownMenuItem(value: true, child: Text('بله')),
          DropdownMenuItem(value: false, child: Text('خیر')),
        ],
        onChanged: onChanged,
        validator: f.validate,
      );
    }
    if (f.type == FieldType.singleSelect) {
      return DropdownButtonFormField<String>(
        initialValue: f.options.contains(value) ? value as String : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: f.label),
        items: f.options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
        validator: f.validate,
      );
    }
    if (f.type == FieldType.multiSelect) {
      final selected = value is List
          ? List<String>.from(value as List)
          : <String>[];
      return FormField<Object?>(
        initialValue: value,
        validator: (_) => f.validate(value),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: f.options
                  .map(
                    (o) => FilterChip(
                      label: Text(o),
                      selected: selected.contains(o),
                      onSelected: (yes) {
                        final next = {...selected};
                        if (yes) {
                          next.add(o);
                        } else {
                          next.remove(o);
                        }
                        onChanged(next.toList());
                        state.didChange(next.toList());
                      },
                    ),
                  )
                  .toList(),
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    final hint = switch (f.type) {
      FieldType.tags => 'برچسب‌ها را با ویرگول جدا کنید',
      FieldType.numberRange ||
      FieldType.yearRange => 'حداقل، حداکثر؛ برای مثال ۱۰، ۲۰',
      FieldType.date => 'تاریخ شمسی؛ برای مثال ۱۴۰۵/۰۷/۲۹',
      FieldType.color => 'برای مثال #6554C0',
      FieldType.score => 'بین صفر و یک',
      FieldType.year => 'سال میلادی؛ برای مثال ۲۰۲۶',
      _ => null,
    };
    return TextFormField(
      initialValue: _display(),
      maxLines: f.type == FieldType.longText ? 3 : 1,
      decoration: InputDecoration(
        labelText: f.label,
        helperText: hint,
        helperMaxLines: 2,
      ),
      keyboardType:
          [
            FieldType.integer,
            FieldType.year,
            FieldType.decimal,
            FieldType.score,
          ].contains(f.type)
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      onChanged: (v) => onChanged(_parse(v)),
      validator: (v) {
        final parsed = _parse(v ?? '');
        final error = f.validate(parsed);
        if (error != null) return error;
        if (f.type == FieldType.date && parsed is String) {
          final date = DateTime.tryParse(parsed);
          if (date != null) {
            try {
              Jalali.fromDateTime(date);
            } catch (_) {
              return 'مقدار تاریخ معتبر وارد کنید';
            }
          }
        }
        return null;
      },
    );
  }
}
