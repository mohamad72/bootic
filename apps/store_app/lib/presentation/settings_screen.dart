import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../app/providers.dart';
import '../domain/field_definition.dart';
import 'common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _rename() async {
    final controller = TextEditingController(
      text: ref.read(storeNameProvider).value ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('نام بوتیک'),
        content: TextField(
          controller: controller,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'نام فروشگاه'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(c, controller.text.trim());
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await ref.read(repositoryProvider).saveSetting('storeName', result);
        ref.invalidate(storeNameProvider);
      } catch (e) {
        if (mounted) showNotice(context, friendlyError(e));
      }
    }
    // Dialog route owns its text field until its closing animation has finished.
  }

  Future<void> _addField() async {
    final label = TextEditingController();
    final options = TextEditingController();
    FieldType type = FieldType.text;
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('مشخصه جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'عنوان فارسی'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FieldType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نوع مقدار'),
                  items: FieldType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) => update(() => type = v!),
                ),
                if (type == FieldType.singleSelect ||
                    type == FieldType.multiSelect) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: options,
                    decoration: const InputDecoration(
                      labelText: 'گزینه‌ها با ویرگول جدا شوند',
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(repositoryProvider)
                            .saveField(
                              FieldDefinition(
                                key: 'custom.${const Uuid().v4()}',
                                label: label.text.trim(),
                                type: type,
                                options: options.text
                                    .split(RegExp('[,،]'))
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toSet()
                                    .toList(),
                              ),
                            );
                        ref.invalidate(fieldsProvider);
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        if (c.mounted) {
                          update(() {
                            error = friendlyError(e);
                            busy = false;
                          });
                        }
                      }
                    },
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(FieldDefinition field) async {
    if (field.enabled) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('غیرفعال کردن مشخصه'),
          content: const Text(
            'این مشخصه برای لباس‌های جدید این فروشگاه غیرفعال می‌شود. اطلاعات لباس‌های قبلی باقی می‌ماند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('غیرفعال شود'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .saveField(field.copyWith(enabled: !field.enabled));
      ref.invalidate(fieldsProvider);
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    }
  }

  Future<void> _archived() async {
    try {
      final items =
          (await ref.read(repositoryProvider).list(includeArchived: true))
              .where((g) => g.archived)
              .toList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'آرشیو لباس‌ها',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('آرشیو خالی است'),
                ),
              for (final g in items)
                ListTile(
                  title: Text(g.name),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.pop(c);
                    context.push('/garment/${g.id}');
                  },
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) showNotice(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SectionCard(
        title: 'فروشگاه',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ref.watch(storeNameProvider).value ?? 'بوتیک'),
            subtitle: const Text('تغییر نام فروشگاه'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _rename,
          ),
          const Text(
            'همه اطلاعات و عکس‌های لباس روی همین دستگاه ذخیره می‌شوند. با حذف داده‌های برنامه، این اطلاعات هم حذف خواهند شد.',
          ),
          OutlinedButton.icon(
            onPressed: _archived,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('لباس‌های آرشیوشده'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SectionCard(
        title: 'مشخصات سفارشی لباس',
        children: [
          const Text(
            'مشخصه‌هایی مانند سایز، برند یا کشور تولیدکننده را به فرم لباس اضافه کنید.',
          ),
          ref
              .watch(fieldsProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    ErrorRetry(onRetry: () => ref.invalidate(fieldsProvider)),
                data: (fields) => Column(
                  children: [
                    for (final field in fields.where(
                      (f) => f.key.startsWith('custom.'),
                    ))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(field.label),
                        subtitle: Text(field.type.label),
                        value: field.enabled,
                        onChanged: (_) => _toggle(field),
                      ),
                  ],
                ),
              ),
          OutlinedButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add),
            label: const Text('افزودن مشخصه'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const SectionCard(
        title: 'وضعیت امکانات',
        children: [
          Text('ذخیره‌سازی: محلی روی دستگاه'),
          Text('ورود: کد ثابت نسخه محلی'),
          Text('هوش مصنوعی: هنوز متصل نشده است'),
          Text('پرو زنده و نمایشگر خارجی: هنوز آماده استفاده نیست'),
          Text('عکس مشتری ذخیره یا ارسال نمی‌شود.'),
        ],
      ),
    ],
  );
}
