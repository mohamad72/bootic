import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../domain/garment.dart';
import '../domain/persian.dart';
import 'common.dart';
import 'live_tryon_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _tab == 0
        ? AppBar(
            title: Text(ref.watch(storeNameProvider).value ?? 'بوتیک من'),
            actions: [
              IconButton(
                tooltip: 'قفل برنامه',
                onPressed: () => ref.read(accessProvider.notifier).lock(),
                icon: const Icon(Icons.lock_outline),
              ),
            ],
          )
        : null,
    body: _tab == 0
        ? _operatorView()
        : const SafeArea(bottom: false, child: LiveTryonScreen()),
    floatingActionButton: _tab == 0
        ? FloatingActionButton.extended(
            key: const Key('add-garment'),
            onPressed: () => context.push('/garment/new'),
            icon: const Icon(Icons.add),
            label: const Text('افزودن لباس'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) {
        if (_tab != index) setState(() => _tab = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.checkroom_outlined),
          selectedIcon: Icon(Icons.checkroom),
          label: 'اپراتور',
        ),
        NavigationDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: 'مشتری',
        ),
      ],
    ),
  );

  Widget _operatorView() => ref
      .watch(catalogProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(catalogProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(catalogProvider);
            await ref.read(catalogProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Text('لباس‌ها', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('هنوز لباسی ثبت نشده است.')),
                ),
              for (final garment in items) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/garment/${garment.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 80,
                              child: GarmentPhoto(
                                path: garment.photos['front'],
                                height: 100,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  garment.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${faNumber(garment.effectivePrice)} تومان',
                                ),
                                Text(_status(garment)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      );

  String _status(Garment garment) {
    if (garment.isDraft) return 'پیش‌نویس';
    if (!garment.isActive || garment.archived) return 'غیرفعال';
    if (garment.stock == 0) return 'ناموجود';
    return '${faNumber(garment.stock)} عدد موجود';
  }
}
