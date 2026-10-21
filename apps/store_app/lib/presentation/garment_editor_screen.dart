import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../app/providers.dart';
import '../domain/garment.dart';
import '../domain/persian.dart';
import 'common.dart';
import 'dynamic_field.dart';

class GarmentEditorScreen extends ConsumerStatefulWidget {
  const GarmentEditorScreen({this.id, super.key});
  final String? id;
  @override
  ConsumerState<GarmentEditorScreen> createState() =>
      _GarmentEditorScreenState();
}

class _GarmentEditorScreenState extends ConsumerState<GarmentEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _price = TextEditingController(),
      _discount = TextEditingController();
  final _stock = TextEditingController(),
      _collection = TextEditingController(),
      _sku = TextEditingController(),
      _barcode = TextEditingController();
  final _chest = TextEditingController(), _length = TextEditingController();
  Garment? _item;
  String? _loadError;
  String _category = 'top';
  String _saveMessage = 'تغییرات معتبر به‌صورت خودکار ذخیره می‌شوند';
  bool _active = true, _dirty = false, _busy = false, _photoBusy = false;
  int _generation = 0;
  final Map<String, Object?> _metadata = {};
  final Map<String, String> _photos = {};
  final Set<String> _excluded = {};
  Timer? _timer;
  Future<bool> _tail = Future.value(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = widget.id == null
          ? Garment.create(id: const Uuid().v4(), name: '')
          : await ref.read(repositoryProvider).get(widget.id!);
      if (item == null) throw ArgumentError('این لباس پیدا نشد');
      if (!mounted) return;
      _name.text = item.name;
      _price.text = faDigits(item.price);
      _stock.text = faDigits(item.stock);
      _discount.text = item.discountPrice == null
          ? ''
          : faDigits(item.discountPrice!);
      _collection.text = item.collection;
      _sku.text = item.sku;
      _barcode.text = item.barcode;
      _chest.text = item.measurements['chest']?.toString() ?? '';
      _length.text = item.measurements['length']?.toString() ?? '';
      _category = item.category;
      _active = item.isActive;
      _metadata.addAll(item.metadata);
      _photos.addAll(item.photos);
      _excluded.addAll(item.excludedFields);
      setState(() => _item = item);
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _name,
      _price,
      _discount,
      _stock,
      _collection,
      _sku,
      _barcode,
      _chest,
      _length,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    _generation++;
    setState(() {
      _dirty = true;
      _saveMessage = 'تغییرات ذخیره‌نشده';
    });
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 900),
      () => _persist(quiet: true),
    );
  }

  String? _whole(String? value) =>
      parseWhole(value ?? '') == null ? 'عدد صحیح وارد کنید' : null;
  String? _measurement(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(asciiDigits(value).replaceAll('٫', '.'));
    return number == null || !number.isFinite || number <= 0 || number > 10000
        ? 'اندازه معتبر به میلی‌متر وارد کنید'
        : null;
  }

  Future<bool> _persist({bool? draft, bool quiet = false}) {
    _timer?.cancel();
    _tail = _tail
        .then((_) async {
          try {
            if (!mounted || _item == null) return false;
            final form = _form.currentState;
            if (form == null || !ref.read(fieldsProvider).hasValue) {
              return false;
            }
            if (!form.validate()) return false;
            final price = parseWhole(_price.text),
                stock = parseWhole(_stock.text);
            final discount = _discount.text.trim().isEmpty
                ? null
                : parseWhole(_discount.text);
            if (price == null ||
                stock == null ||
                (_discount.text.trim().isNotEmpty && discount == null) ||
                _measurement(_chest.text) != null ||
                _measurement(_length.text) != null) {
              setState(
                () => _saveMessage = 'ورودی‌های نامعتبر هنوز ذخیره نشده‌اند',
              );
              return false;
            }
            final generation = _generation;
            final measures = <String, double>{};
            if (_chest.text.trim().isNotEmpty) {
              measures['chest'] = double.parse(
                asciiDigits(_chest.text).replaceAll('٫', '.'),
              );
            }
            if (_length.text.trim().isNotEmpty) {
              measures['length'] = double.parse(
                asciiDigits(_length.text).replaceAll('٫', '.'),
              );
            }
            final snapshot = _item!.copyWith(
              name: _name.text.trim().isEmpty && (draft ?? _item!.isDraft)
                  ? 'پیش‌نویس لباس'
                  : _name.text.trim(),
              price: price,
              stock: stock,
              discountPrice: discount,
              clearDiscount: discount == null,
              collection: _collection.text.trim(),
              sku: _sku.text.trim(),
              barcode: asciiDigits(_barcode.text.trim()),
              category: _category,
              isActive: _active,
              isDraft: draft ?? _item!.isDraft,
              metadata: Map.of(_metadata),
              photos: Map.of(_photos),
              measurements: measures,
              excludedFields: Set.of(_excluded),
            );
            setState(() {
              _busy = true;
              _saveMessage = 'در حال ذخیره…';
            });
            try {
              final saved = await ref
                  .read(repositoryProvider)
                  .save(snapshot, _item!.localRevision);
              if (!mounted) return true;
              _item = saved;
              ref.invalidate(catalogProvider);
              setState(() {
                _dirty = generation != _generation;
                _saveMessage = _dirty
                    ? 'تغییرات تازه در انتظار ذخیره'
                    : 'روی دستگاه ذخیره شد';
              });
              return true;
            } catch (e) {
              if (mounted) {
                setState(() => _saveMessage = friendlyError(e));
                if (!quiet) showNotice(context, friendlyError(e));
              }
              return false;
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          } catch (e) {
            if (mounted) {
              setState(() => _saveMessage = friendlyError(e));
              if (!quiet) showNotice(context, friendlyError(e));
            }
            return false;
          }
        })
        .catchError((Object e) {
          if (mounted) setState(() => _saveMessage = friendlyError(e));
          return false;
        });
    return _tail;
  }

  Future<void> _finish(bool draft) async {
    FocusScope.of(context).unfocus();
    await _saveLatestAndExit(draft: draft);
  }

  Future<void> _saveLatestAndExit({bool? draft}) async {
    while (mounted) {
      if (!await _persist(draft: draft)) return;
      if (!_dirty) {
        if (mounted) context.go('/');
        return;
      }
    }
  }

  Future<void> _leave() async {
    if (!_dirty) {
      context.go('/');
      return;
    }
    _timer?.cancel();
    final action = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغییرات ذخیره‌نشده'),
        content: const Text('قبل از خروج، تغییرات را ذخیره می‌کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'stay'),
            child: const Text('ادامه ویرایش'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('خروج بدون ذخیره'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: const Text('ذخیره و خروج'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') {
      await _tail;
      if (mounted) context.go('/');
      return;
    }
    if (action == 'save') {
      await _saveLatestAndExit();
    } else if (_dirty) {
      _scheduleAutosave();
    }
  }

  Future<void> _pickPhoto(String angle) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      // Persist the form before leaving the activity for the native photo picker.
      if (!await _persist(quiet: true)) return;
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final path = await ref.read(assetStoreProvider).importPhoto(picked.path);
      if (!mounted) return;
      _photos[angle] = path;
      _changed();
      await _persist(quiet: true);
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ویرایش لباس')),
        body: Center(child: Text(_loadError!)),
      );
    }
    if (_item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final fields = ref.watch(fieldsProvider);
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'بازگشت',
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.id == null ? 'لباس جدید' : 'ویرایش لباس'),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('save-draft'),
                    onPressed: _busy || _photoBusy || !fields.hasValue
                        ? null
                        : () => _finish(true),
                    child: const Text('ذخیره پیش‌نویس'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || _photoBusy || !fields.hasValue
                        ? null
                        : () => _finish(false),
                    child: const Text('ثبت در کاتالوگ'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: fields.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              ErrorRetry(onRetry: () => ref.invalidate(fieldsProvider)),
          data: (definitions) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _saveMessage,
                    style: TextStyle(
                      color: _dirty
                          ? const Color(0xff8a5700)
                          : const Color(0xff157347),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'اطلاعات لباس',
                    children: [
                      TextFormField(
                        key: const Key('garment-name'),
                        controller: _name,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'نام لباس',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'دسته لباس',
                        ),
                        items: garmentCategories.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          _category = v!;
                          _changed();
                        },
                      ),
                      TextFormField(
                        controller: _collection,
                        decoration: const InputDecoration(
                          labelText: 'مجموعه (اختیاری)',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        key: const Key('garment-price'),
                        controller: _price,
                        decoration: const InputDecoration(
                          labelText: 'قیمت (تومان)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _whole,
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        controller: _discount,
                        decoration: const InputDecoration(
                          labelText: 'قیمت با تخفیف (اختیاری، تومان)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? null : _whole(v),
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        controller: _stock,
                        decoration: const InputDecoration(labelText: 'موجودی'),
                        keyboardType: TextInputType.number,
                        validator: _whole,
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        controller: _sku,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'کد کالا (اختیاری)',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        controller: _barcode,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'بارکد (اختیاری)',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('فعال در ویترین مشتری'),
                        value: _active,
                        onChanged: (v) {
                          _active = v;
                          _changed();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'عکس‌های لباس',
                    children: [
                      const Text(
                        'لباس را روی زمینه ساده، با نور یکنواخت و بدون حضور مشتری عکاسی کنید. چهار نمای روبرو، پشت، چپ و راست را از گالری انتخاب کنید. برای کاتالوگ عکس روبرو ضروری است.',
                      ),
                      const Text(
                        'کیفیت‌سنجی خودکار و اندازه‌گیری از عکس هنوز فعال نیست؛ عکس‌ها را خودتان بررسی کنید.',
                      ),
                      for (final angle in photoAngles.entries)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              angle.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_photos[angle.key] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GarmentPhoto(
                                  path: _photos[angle.key],
                                  height: 190,
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _photoBusy
                                      ? null
                                      : () => _pickPhoto(angle.key),
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: Text(
                                    _photos[angle.key] == null
                                        ? 'انتخاب عکس'
                                        : 'تعویض عکس',
                                  ),
                                ),
                                if (_photos[angle.key] != null)
                                  TextButton(
                                    onPressed: () {
                                      _photos.remove(angle.key);
                                      _changed();
                                    },
                                    child: const Text('برداشتن عکس'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'مشخصات لباس',
                    children: [
                      const Text(
                        'اطلاعات این بخش توسط شما ثبت می‌شوند؛ تحلیل هوش مصنوعی هنوز متصل نیست.',
                      ),
                      for (final field in definitions.where(
                        (f) => f.enabled || _metadata.containsKey(f.key),
                      ))
                        if (!field.enabled)
                          Text(
                            '${field.label}: ${_metadata[field.key]} (مشخصه غیرفعال)',
                          )
                        else if (_excluded.contains(field.key))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(field.label),
                            subtitle: const Text('از این لباس کنار گذاشته شده'),
                            trailing: IconButton(
                              tooltip: 'برگرداندن مشخصه',
                              icon: const Icon(Icons.restore),
                              onPressed: () {
                                _excluded.remove(field.key);
                                _changed();
                              },
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DynamicField(
                                key: ValueKey(field.key),
                                definition: field,
                                value: _metadata[field.key],
                                onChanged: (v) {
                                  _metadata[field.key] = v;
                                  _changed();
                                },
                              ),
                              if (!field.required)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(
                                    onPressed: () {
                                      _excluded.add(field.key);
                                      _changed();
                                    },
                                    child: const Text(
                                      'کنار گذاشتن از این لباس',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'اندازه‌های دستی',
                    children: [
                      const Text(
                        'فقط اندازه واقعی را وارد کنید. فیلد خالی یعنی نامشخص؛ اندازه‌ها از تصویر حدس زده نمی‌شوند.',
                      ),
                      TextFormField(
                        controller: _chest,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'عرض سینه لباس (میلی‌متر)',
                        ),
                        validator: _measurement,
                        onChanged: (_) => _changed(),
                      ),
                      TextFormField(
                        controller: _length,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'قد لباس (میلی‌متر)',
                        ),
                        validator: _measurement,
                        onChanged: (_) => _changed(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
