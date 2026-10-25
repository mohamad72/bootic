import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../app/providers.dart';
import '../application/live_tryon_bridge.dart';
import '../domain/garment.dart';
import '../domain/field_definition.dart';
import '../domain/garment_ai_import.dart';
import '../domain/garment_ai_prompt.dart';
import '../domain/garment_render_metadata.dart';
import '../domain/garment_model_metadata.dart';
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
  final _renderJson = TextEditingController(),
      _aiResponse = TextEditingController();
  String? _aiError;
  bool _aiBusy = false, _categoryKnown = false;
  int _importGeneration = 0;
  String _audience = '';
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
      if (widget.id != null) {
        _price.text = item.price == null ? '' : faDigits(item.price!);
        _stock.text = item.stock == null ? '' : faDigits(item.stock!);
      }
      _discount.text = item.discountPrice == null
          ? ''
          : faDigits(item.discountPrice!);
      _collection.text = item.collection;
      _sku.text = item.sku;
      _barcode.text = item.barcode;
      _chest.text = item.measurements['chest']?.toString() ?? '';
      _length.text = item.measurements['length']?.toString() ?? '';
      _renderJson.text = item.tryOnJson;
      _aiResponse.text = item.aiImportJson;
      _audience = garmentAudiences.containsKey(item.audience)
          ? item.audience
          : '';
      _category = item.category;
      _categoryKnown = widget.id != null;
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
      _renderJson,
      _aiResponse,
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

  String? _whole(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return parseWhole(value) == null ? 'عدد صحیح وارد کنید' : null;
  }

  int? _optionalWhole(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return parseWhole(value);
  }

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
            final price = _optionalWhole(_price.text),
                stock = _optionalWhole(_stock.text);
            final discount = _discount.text.trim().isEmpty
                ? null
                : parseWhole(_discount.text);
            if ((_price.text.trim().isNotEmpty && price == null) ||
                (_stock.text.trim().isNotEmpty && stock == null) ||
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
              clearPrice: price == null,
              stock: stock,
              clearStock: stock == null,
              discountPrice: discount,
              clearDiscount: discount == null,
              collection: _collection.text.trim(),
              sku: _sku.text.trim(),
              barcode: asciiDigits(_barcode.text.trim()),
              category: _category,
              audience: _audience,
              isActive: _active,
              isDraft: draft ?? _item!.isDraft,
              tryOnJson: _renderJson.text,
              aiImportJson: _aiResponse.text,
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

  Future<(int, int)> _referenceSize(String relative) async {
    final file = ref.read(assetStoreProvider).resolve(relative);
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    try {
      final image = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (image.width, image.height);
      } finally {
        image.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  List<FieldDefinition> _aiFields() =>
      (ref.read(fieldsProvider).asData?.value ?? <FieldDefinition>[])
          .where((f) => f.enabled && !_excluded.contains(f.key))
          .toList();

  Future<void> _copyAiPrompt() async {
    final reference = _photos['front_source'];
    if (reference == null) {
      showNotice(context, 'ابتدا عکس اصلی روبرو را انتخاب کنید');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final (width, height) = await _referenceSize(reference);
      if (!mounted || _photos['front_source'] != reference) return;
      final prompt = GarmentAiPrompt.build(
        photoId: p.basename(reference),
        width: width,
        height: height,
        fields: _aiFields(),
        knownValues: {
          'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
          'category': _categoryKnown ? _category : null,
          'audience': _audience.isEmpty ? null : _audience,
          'price': parseWhole(_price.text),
          'discountPrice': parseWhole(_discount.text),
          'stock': parseWhole(_stock.text),
          'isActive': _active,
          'collection': _collection.text.trim().isEmpty
              ? null
              : _collection.text.trim(),
          'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
          'barcode': _barcode.text.trim().isEmpty
              ? null
              : asciiDigits(_barcode.text.trim()),
          'metadata': {for (final f in _aiFields()) f.key: _metadata[f.key]},
          'measurements_mm': {
            'chest': double.tryParse(
              asciiDigits(_chest.text).replaceAll('٫', '.'),
            ),
            'length': double.tryParse(
              asciiDigits(_length.text).replaceAll('٫', '.'),
            ),
          },
        },
      );
      await Clipboard.setData(ClipboardData(text: prompt));
      if (mounted)
        showNotice(
          context,
          'پرامپت کپی شد؛ آن را همراه عکس مرجع به هوش مصنوعی بدهید',
        );
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _shareReference() async {
    final reference = _photos['front_source'];
    if (reference == null) return;
    try {
      await const LiveTryonBridge().shareGarmentReference(
        ref.read(assetStoreProvider).resolve(reference).path,
      );
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    }
  }

  Future<void> _applyAiResponse() async {
    final reference = _photos['front_source'];
    if (reference == null) {
      showNotice(context, 'ابتدا عکس اصلی روبرو را انتخاب کنید');
      return;
    }
    _timer?.cancel();
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    try {
      await _tail;
      if (!mounted) return;
      final text = _aiResponse.text;
      final (width, height) = await _referenceSize(reference);
      if (!mounted || _photos['front_source'] != reference) return;
      final response = GarmentAiImport.parse(
        text,
        photoId: p.basename(reference),
        width: width,
        height: height,
        fields: _aiFields(),
      );
      // Snapshot the latest manual edits. Unknown AI values leave controllers alone.
      final current = _item!.copyWith(
        name: _name.text.trim().isEmpty ? 'پیش‌نویس لباس' : _name.text.trim(),
        category: _category,
        audience: _audience,
        price: parseWhole(_price.text),
        clearPrice: _price.text.trim().isEmpty,
        stock: parseWhole(_stock.text),
        clearStock: _stock.text.trim().isEmpty,
        discountPrice: parseWhole(_discount.text),
        clearDiscount: _discount.text.trim().isEmpty,
        collection: _collection.text,
        sku: _sku.text,
        barcode: _barcode.text,
        isActive: _active,
        metadata: _metadata,
        photos: _photos,
        measurements: {
          ..._item!.measurements,
          if (_measurement(_chest.text) == null &&
              _chest.text.trim().isNotEmpty)
            'chest': double.parse(
              asciiDigits(_chest.text).replaceAll('٫', '.'),
            ),
          if (_measurement(_length.text) == null &&
              _length.text.trim().isNotEmpty)
            'length': double.parse(
              asciiDigits(_length.text).replaceAll('٫', '.'),
            ),
        },
      );
      final imported = response.applyTo(current);
      // Everything above must validate before a single form value changes.
      final values = response.values;
      for (final entry in <String, TextEditingController>{
        'name': _name,
        'collection': _collection,
        'sku': _sku,
        'barcode': _barcode,
        'price': _price,
        'discountPrice': _discount,
        'stock': _stock,
      }.entries) {
        if (values[entry.key] != null)
          entry.value.text = values[entry.key].toString();
      }
      _category = imported.category;
      if (values['category'] != null) _categoryKnown = true;
      _audience = imported.audience;
      _active = imported.isActive;
      _metadata
        ..clear()
        ..addAll(imported.metadata);
      final measurements = values['measurements_mm'] as Map;
      if (measurements['chest'] != null)
        _chest.text = measurements['chest'].toString();
      if (measurements['length'] != null)
        _length.text = measurements['length'].toString();
      _renderJson.text = response.renderJson;
      _aiResponse.text = response.sourceJson;
      _item = _item!.copyWith(isDraft: true);
      _importGeneration++;
      _changed();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _persist(draft: true, quiet: true);
      if (mounted)
        showNotice(
          context,
          'پاسخ اعمال شد؛ مشخصات را بررسی کنید و سپس ثبت در کاتالوگ را بزنید',
        );
    } on FormatException catch (e) {
      if (mounted) setState(() => _aiError = e.message);
    } catch (e) {
      if (mounted) setState(() => _aiError = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _aiBusy = false);
        if (_dirty) _scheduleAutosave();
      }
    }
  }

  Future<void> _pickPhoto(String angle, {bool camera = false}) async {
    if (_photoBusy || _aiBusy) return;
    setState(() => _photoBusy = true);
    String? temporaryCapture;
    final captureRoot = p.normalize(
      p.join(ref.read(assetStoreProvider).root.path, 'capture-temp'),
    );
    try {
      // Best-effort save must not prevent repairing a missing photo/JSON pair.
      _timer?.cancel();
      await _persist(quiet: true);
      if (!mounted) return;
      final String? sourcePath;
      if (camera) {
        temporaryCapture = await const LiveTryonBridge().captureGarment();
        sourcePath = temporaryCapture;
      } else {
        sourcePath = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
        ))?.path;
      }
      if (sourcePath == null || !mounted) return;
      final store = ref.read(assetStoreProvider);
      // One untrimmed, orientation-normalized original. No segmentation service.
      final original = await store.importPhoto(sourcePath);
      if (!mounted) return;
      _photos[angle] = original;
      if (angle == 'front') {
        _photos['front_source'] = original;
        _renderJson.clear();
        _aiResponse.clear();
        _aiError = null;
        _item = _item!.copyWith(isDraft: true);
      }
      _changed();
      await _persist(quiet: true);
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    } finally {
      if (temporaryCapture != null) {
        final candidate = p.normalize(temporaryCapture);
        if (p.isWithin(captureRoot, candidate)) {
          try {
            await File(candidate).delete();
          } on FileSystemException {
            // Cleanup can retry on the next capture; the imported copy is safe.
          }
        }
      }
      if (mounted) {
        setState(() => _photoBusy = false);
        if (_dirty) _scheduleAutosave();
      }
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
                    onPressed:
                        _busy || _photoBusy || _aiBusy || !fields.hasValue
                        ? null
                        : () => _finish(true),
                    child: const Text('ذخیره پیش‌نویس'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _busy || _photoBusy || _aiBusy || !fields.hasValue
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
                        key: ValueKey('category-$_importGeneration'),
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
                          _categoryKnown = true;
                          _changed();
                        },
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('audience-$_importGeneration'),
                        initialValue: _audience,
                        decoration: const InputDecoration(
                          labelText: 'گروه لباس',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('نامشخص'),
                          ),
                          for (final e in garmentAudiences.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) {
                          _audience = v ?? '';
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
                        'عکس اصلی حفظ می‌شود. برای پرو زنده، مرز لباس و یقه فقط از JSON خوانده می‌شود. تعویض عکس روبرو به JSON تازه نیاز دارد.',
                      ),
                      if (_photoBusy) ...[
                        const LinearProgressIndicator(),
                        const Text('در حال آماده‌سازی عکس اصلی…'),
                      ],
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
                                OutlinedButton.icon(
                                  onPressed: _photoBusy
                                      ? null
                                      : () =>
                                            _pickPhoto(angle.key, camera: true),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('عکس با دوربین'),
                                ),
                                if (_photos[angle.key] != null)
                                  TextButton(
                                    onPressed: _photoBusy
                                        ? null
                                        : () {
                                            _photos.remove(angle.key);
                                            if (angle.key == 'front') {
                                              _photos.remove('front_source');
                                              _renderJson.clear();
                                              _aiResponse.clear();
                                              _aiError = null;
                                              _item = _item!.copyWith(
                                                isDraft: true,
                                              );
                                            }
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
                    title: 'دریافت مشخصات از هوش مصنوعی',
                    children: [
                      const Text(
                        '۱. عکس روبرو را انتخاب کنید. ۲. پرامپت را کپی کنید و همراه همان عکس مرجع به هوش مصنوعی بدهید. ۳. JSON خروجی را اینجا بچسبانید و اعمال کنید. ارسال خودکار انجام نمی‌شود.',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('copy-ai-prompt'),
                            onPressed: _aiBusy || _photoBusy
                                ? null
                                : _copyAiPrompt,
                            icon: const Icon(Icons.copy),
                            label: const Text('کپی سیستم پرامپت'),
                          ),
                          if (Platform.isAndroid &&
                              _photos['front_source'] != null)
                            OutlinedButton.icon(
                              onPressed: _photoBusy || _aiBusy
                                  ? null
                                  : _shareReference,
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('اشتراک عکس مرجع'),
                            ),
                        ],
                      ),
                      const Text(
                        'قیمت، موجودی و اندازهٔ واقعی از عکس حدس زده نمی‌شوند. مقدار نامعلوم اطلاعات دستی شما را پاک نمی‌کند.',
                      ),
                      TextFormField(
                        key: const Key('garment-ai-response'),
                        controller: _aiResponse,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: GarmentRenderMetadata.maxCharacters,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: 'پاسخ کامل هوش مصنوعی (JSON)',
                          alignLabelWithHint: true,
                          counterText: '',
                          errorText: _aiError,
                          errorMaxLines: 5,
                        ),
                        onChanged: (_) {
                          setState(() => _aiError = null);
                          _changed();
                        },
                      ),
                      FilledButton.icon(
                        key: const Key('apply-ai-response'),
                        onPressed: _aiBusy || _photoBusy
                            ? null
                            : _applyAiResponse,
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text('اعمال JSON و پرکردن فرم'),
                      ),
                      if (_aiBusy) const LinearProgressIndicator(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'اطلاعات پرو زنده',
                    children: [
                      const Text(
                        'این JSON با اعمال پاسخ هوش مصنوعی پر می‌شود و برای ثبت نهایی ضروری است. برای ویرایش دستی نیز می‌توانید JSON پرو را اینجا تغییر دهید؛ پیش‌نویس بدون آن قابل ذخیره است.',
                      ),
                      TextFormField(
                        key: const Key('garment-render-json'),
                        controller: _renderJson,
                        textDirection: TextDirection.ltr,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: GarmentRenderMetadata.maxCharacters,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'مشخصات لباس (JSON)',
                          alignLabelWithHint: true,
                          counterText: '',
                          hintText:
                              '{"schema_version":"bootic.garment-metadata/0.1", ...}',
                          errorMaxLines: 4,
                        ),
                        validator: (value) {
                          try {
                            if (GarmentModelMetadata.isModel(value ?? '')) {
                              GarmentModelMetadata.parse(
                                value!,
                              ).photoMetadata();
                            } else {
                              GarmentRenderMetadata.parse(value ?? '');
                            }
                            return null;
                          } on FormatException catch (e) {
                            return e.message;
                          }
                        },
                        onChanged: (_) => _changed(),
                      ),
                      if (_renderJson.text.trim().isNotEmpty &&
                          _photos['front_source'] == null)
                        const Text(
                          'برای لباس‌های قدیمی، عکس اصلی روبرو را یک بار دوباره انتخاب کنید تا مختصات JSON روی همان عکس اعمال شود.',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'مشخصات لباس',
                    children: [
                      const Text(
                        'پس از اعمال پاسخ، مشخصات تشخیص‌داده‌شده پر می‌شوند؛ می‌توانید آن‌ها را بررسی و ویرایش کنید.',
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
                                key: ValueKey(
                                  '${field.key}-$_importGeneration',
                                ),
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
