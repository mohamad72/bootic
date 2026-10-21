import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/providers.dart';
import '../domain/garment.dart';
import '../domain/persian.dart';
import 'common.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tab = 0;
  String _query = '';
  String? _category;
  bool _availableOnly = false;
  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(['بوتیک من', 'کاتالوگ لباس‌ها', 'تنظیمات'][_tab]),
        actions: [
          IconButton(
            tooltip: 'قفل برنامه',
            onPressed: () => ref.read(accessProvider.notifier).lock(),
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            label: 'کاتالوگ',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'تنظیمات'),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              key: const Key('add-garment'),
              onPressed: () => context.push('/garment/new'),
              icon: const Icon(Icons.add),
              label: const Text('افزودن لباس'),
            )
          : null,
      body: SafeArea(
        child: _tab == 2
            ? const SettingsScreen()
            : catalog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    ErrorRetry(onRetry: () => ref.invalidate(catalogProvider)),
                data: (items) => _tab == 0 ? _home(items) : _catalog(items),
              ),
      ),
    );
  }

  Widget _home(List<Garment> items) => RefreshIndicator(
    onRefresh: () async {
      ref.invalidate(catalogProvider);
      await ref.read(catalogProvider.future);
    },
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xff6554c0), Color(0xff483b8c)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xffa7f3e8),
                size: 32,
              ),
              const SizedBox(height: 20),
              Text(
                ref.watch(storeNameProvider).value ?? 'بوتیک من',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'برای هر سلیقه، یک انتخاب تازه',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('add-garment'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff483b8c),
                ),
                onPressed: () => context.push('/garment/new'),
                icon: const Icon(Icons.add),
                label: const Text('افزودن لباس جدید'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat('همه لباس‌ها', items.length, Icons.checkroom),
            _stat(
              'پیش‌نویس',
              items.where((g) => g.isDraft).length,
              Icons.edit_note,
            ),
            _stat(
              'موجود',
              items
                  .where((g) => g.stock > 0 && g.isActive && !g.isDraft)
                  .length,
              Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionCard(
          title: 'ویترین مشتری',
          children: [
            const Text(
              'لباس‌ها را همراه قیمت به مشتری نشان دهید و پسندیده‌های این جلسه را مرور کنید.',
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/customer'),
              icon: const Icon(Icons.storefront),
              label: const Text('شروع نمایش کاتالوگ'),
            ),
            const Text(
              'پرو زنده و تشخیص ژست هنوز در دسترس نیست.',
              style: TextStyle(color: Color(0xff8a5700)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'تازه‌های بوتیک',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _tab = 1),
              child: const Text('دیدن همه'),
            ),
          ],
        ),
        if (items.isEmpty)
          _empty(
            'اولین لباس بوتیکت را ثبت کن',
            'نام، قیمت و عکس لباس‌ها اینجا در دسترس خواهند بود.',
          ),
        for (final item in items.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _item(item),
          ),
        const SizedBox(height: 12),
        const Text(
          'ذخیره روی دستگاه • بدون نیاز به اینترنت',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff596579)),
        ),
      ],
    ),
  );

  Widget _stat(String label, int number, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xff6554c0)),
          const SizedBox(height: 12),
          Text(
            faNumber(number),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(label),
        ],
      ),
    ),
  );

  Widget _catalog(List<Garment> items) {
    final filtered = items
        .where(
          (g) =>
              searchKey(
                '${g.name} ${g.sku} ${g.barcode} ${g.collection}',
              ).contains(searchKey(_query)) &&
              (_category == null || g.category == _category) &&
              (!_availableOnly || (g.stock > 0 && g.isActive && !g.isDraft)),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'جست‌وجوی نام، کد یا مجموعه',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('همه'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final e in garmentCategories.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _category == e.key,
                onSelected: (_) => setState(() => _category = e.key),
              ),
            FilterChip(
              label: const Text('فقط موجود'),
              selected: _availableOnly,
              onSelected: (v) => setState(() => _availableOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('${faNumber(filtered.length)} لباس'),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _empty(
            'لباسی پیدا نشد',
            'فیلترها را تغییر دهید یا لباس تازه‌ای اضافه کنید.',
          ),
        for (final item in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _item(item),
          ),
      ],
    );
  }

  Widget _item(Garment g) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/garment/${g.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 84,
                child: GarmentPhoto(path: g.photos['front'], height: 104),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(garmentCategories[g.category]!),
                  const SizedBox(height: 8),
                  Text(
                    '${faNumber(g.effectivePrice)} تومان',
                    style: const TextStyle(color: Color(0xff6554c0)),
                  ),
                  Text(
                    g.isDraft
                        ? 'پیش‌نویس'
                        : !g.isActive
                        ? 'غیرفعال'
                        : g.stock == 0
                        ? 'ناموجود'
                        : '${faNumber(g.stock)} عدد موجود',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _empty(String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const Icon(
          Icons.checkroom_outlined,
          size: 48,
          color: Color(0xff6554c0),
        ),
        const SizedBox(height: 16),
        Text(title),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
      ],
    ),
  );
}
