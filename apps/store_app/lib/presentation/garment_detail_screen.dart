import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../app/providers.dart';
import '../application/processing_service.dart';
import '../domain/garment.dart';
import '../domain/persian.dart';
import 'common.dart';

class GarmentDetailScreen extends ConsumerStatefulWidget {
  const GarmentDetailScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<GarmentDetailScreen> createState() =>
      _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends ConsumerState<GarmentDetailScreen> {
  late Future<Garment?> _load;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load = ref.read(repositoryProvider).get(widget.id);
  }

  void _refresh() {
    ref.invalidate(catalogProvider);
    setState(() => _load = ref.read(repositoryProvider).get(widget.id));
  }

  Future<void> _archive(Garment g) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(g.archived ? 'بازگرداندن لباس' : 'آرشیو لباس'),
        content: Text(
          g.archived
              ? 'لباس به کاتالوگ برگردد؟'
              : 'لباس از کاتالوگ کنار گذاشته می‌شود. اطلاعات و عکس‌ها در آرشیو باقی می‌مانند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (g.archived) {
        await ref
            .read(repositoryProvider)
            .save(g.copyWith(archived: false), g.localRevision);
      } else {
        await ref.read(repositoryProvider).archive(g.id, g.localRevision);
      }
      if (mounted) {
        ref.invalidate(catalogProvider);
        context.go('/');
      }
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze(Garment g) async {
    setState(() => _busy = true);
    try {
      await ProcessingService().analyze(g.id);
    } on ProcessingUnavailable catch (e) {
      try {
        await ref
            .read(repositoryProvider)
            .save(g.copyWith(processingStatus: 'unavailable'), g.localRevision);
        if (mounted) _refresh();
      } catch (saveError) {
        if (mounted) showNotice(context, friendlyError(saveError));
      }
      if (mounted) showNotice(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _value(Object? value) => value == null
      ? 'نامشخص'
      : value is bool
      ? (value ? 'بله' : 'خیر')
      : value is List
      ? value.map(_value).join('، ')
      : faDigits(value);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جزئیات لباس')),
    body: FutureBuilder<Garment?>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return ErrorRetry(onRetry: _refresh);
        final g = snapshot.data;
        if (g == null) return const Center(child: Text('لباس پیدا نشد'));
        final j = Jalali.fromDateTime(g.updatedAt.toLocal());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GarmentPhoto(path: g.photos['front'], height: 320),
            ),
            const SizedBox(height: 20),
            Text(
              g.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '${garmentCategories[g.category]} ${g.collection.isEmpty ? '' : '• ${g.collection}'}',
            ),
            const SizedBox(height: 12),
            Text(
              '${faNumber(g.effectivePrice)} تومان',
              style: const TextStyle(fontSize: 24, color: Color(0xff6554c0)),
            ),
            if (g.discountPrice != null)
              Text(
                '${faNumber(g.price)} تومان',
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    g.archived
                        ? 'آرشیوشده'
                        : g.isDraft
                        ? 'پیش‌نویس'
                        : 'ثبت‌شده در کاتالوگ',
                  ),
                ),
                Chip(label: Text('${faNumber(g.stock)} عدد موجود')),
                if (!g.isActive) const Chip(label: Text('غیرفعال')),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await context.push('/garment/${g.id}/edit');
                      if (mounted) _refresh();
                    },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('ویرایش لباس'),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'مشخصات ثبت‌شده',
              children: [
                if (g.sku.isNotEmpty) Text('کد کالا: ${g.sku}'),
                if (g.barcode.isNotEmpty) Text('بارکد: ${faDigits(g.barcode)}'),
                ref
                    .watch(fieldsProvider)
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => ErrorRetry(
                        onRetry: () => ref.invalidate(fieldsProvider),
                      ),
                      data: (fields) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final f in fields.where(
                            (f) =>
                                g.metadata[f.key] != null &&
                                !g.excludedFields.contains(f.key),
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${f.label}: ${_value(g.metadata[f.key])}',
                              ),
                            ),
                          if (g.metadata.values.every((v) => v == null))
                            const Text('هنوز مشخصاتی ثبت نشده است'),
                        ],
                      ),
                    ),
                if (g.measurements['chest'] != null)
                  Text(
                    'عرض سینه: ${faDigits(g.measurements['chest']!)} میلی‌متر (دستی)',
                  ),
                if (g.measurements['length'] != null)
                  Text(
                    'قد لباس: ${faDigits(g.measurements['length']!)} میلی‌متر (دستی)',
                  ),
                Text(
                  'آخرین ویرایش: ${faDigits('${j.year}/${j.month}/${j.day}')}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final angle in photoAngles.entries.where(
              (e) => e.key != 'front' && g.photos[e.key] != null,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(angle.value),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GarmentPhoto(
                        path: g.photos[angle.key],
                        height: 240,
                      ),
                    ),
                  ],
                ),
              ),
            SectionCard(
              title: 'تحلیل و پرو مجازی',
              children: [
                const Text(
                  'این لباس برای پرو زنده آماده نیست. تحلیل تصویر و موتور پرو هنوز متصل نشده‌اند.',
                ),
                if (g.processingStatus == 'unavailable')
                  const Text('آخرین درخواست: سرویس در دسترس نیست'),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _analyze(g),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('درخواست تحلیل هوش مصنوعی'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _busy ? null : () => _archive(g),
              icon: Icon(
                g.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              label: Text(g.archived ? 'بازگرداندن به کاتالوگ' : 'آرشیو لباس'),
            ),
          ],
        );
      },
    ),
  );
}
