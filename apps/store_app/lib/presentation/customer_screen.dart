import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/providers.dart';
import '../domain/garment.dart';
import '../domain/local_access.dart';
import '../domain/persian.dart';
import 'common.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});
  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  int _index = 0;
  String? _collection;
  bool _likedOnly = false;
  final Set<String> _liked = {};
  bool _exitDialogOpen = false;
  Future<void> _exit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    String code = '';
    String? error;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('بازگشت متصدی'),
          content: TextField(
            obscureText: true,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            onChanged: (v) => code = v,
            decoration: InputDecoration(labelText: 'کد ورود', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                if (LocalAccess.accepts(code)) {
                  Navigator.pop(c, true);
                } else {
                  update(() => error = 'کد ورود درست نیست');
                }
              },
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    _exitDialogOpen = false;
    if (yes == true && mounted) {
      _liked.clear();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      backgroundColor: const Color(0xff10131a),
      appBar: AppBar(
        backgroundColor: const Color(0xff10131a),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('ویترین بوتیک'),
        actions: [
          IconButton(
            tooltip: 'خروج متصدی',
            onPressed: _exit,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ref
            .watch(catalogProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(catalogProvider),
                  child: const Text('تلاش دوباره'),
                ),
              ),
              data: (all) =>
                  _content(all.where((g) => g.tryOnEligible).toList()),
            ),
      ),
    ),
  );
  Widget _content(List<Garment> all) {
    final collections = all
        .map((g) => g.collection)
        .where((c) => c.isNotEmpty)
        .toSet();
    final items = all
        .where(
          (g) =>
              (_collection == null || g.collection == _collection) &&
              (!_likedOnly || _liked.contains(g.id)),
        )
        .toList();
    final g = _index < items.length ? items[_index] : null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'مرور عکس لباس‌ها؛ این صفحه پرو زنده نیست.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        if (collections.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('همه مجموعه‌ها'),
                selected: _collection == null,
                onSelected: (_) => setState(() {
                  _collection = null;
                  _index = 0;
                  _likedOnly = false;
                  _liked.clear();
                }),
              ),
              for (final c in collections)
                ChoiceChip(
                  label: Text(c),
                  selected: _collection == c,
                  onSelected: (_) => setState(() {
                    _collection = c;
                    _index = 0;
                    _likedOnly = false;
                    _liked.clear();
                  }),
                ),
            ],
          ),
        const SizedBox(height: 20),
        if (g == null) ...[
          const Icon(Icons.checkroom, color: Color(0xffa7f3e8), size: 64),
          const SizedBox(height: 24),
          Text(
            items.isEmpty
                ? 'لباس موجودی برای نمایش نیست'
                : 'همه مدل‌های این مجموعه را دیدید',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 24),
          if (_liked.isNotEmpty && !_likedOnly)
            FilledButton(
              onPressed: () => setState(() {
                _likedOnly = true;
                _index = 0;
              }),
              child: Text('نمایش پسندیده‌ها (${faNumber(_liked.length)})'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() {
              _index = 0;
              _likedOnly = false;
              _liked.clear();
            }),
            child: const Text(
              'شروع دوباره',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GarmentPhoto(
              path: g.photos['front'],
              height: MediaQuery.sizeOf(context).height * 0.45,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            g.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            g.effectivePrice == null
                ? 'قیمت مشخص نشده'
                : '${faNumber(g.effectivePrice!)} تومان',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffa7f3e8), fontSize: 22),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _liked.add(g.id);
                    _index++;
                  }),
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('می‌پسندم'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _index++),
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  label: const Text(
                    'مدل بعدی',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${faNumber(_index + 1)} از ${faNumber(items.length)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'انتخاب‌های این جلسه با خروج پاک می‌شوند. تصویر مشتری ذخیره نمی‌شود.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}
