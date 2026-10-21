import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';

void showNotice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String friendlyError(Object error) {
  if (error is ArgumentError) return error.message.toString();
  if (error is PlatformException) {
    final message = error.message;
    if (message != null && RegExp(r'[\u0600-\u06ff]').hasMatch(message)) {
      return message;
    }
    return 'دوربین یا فایل انتخابی در دسترس نیست. دوباره تلاش کنید.';
  }
  final text = error.toString();
  if (text.contains('این لباس') || text.contains('سرویس هوش')) return text;
  return 'عملیات انجام نشد. فضای دستگاه را بررسی کنید و دوباره تلاش کنید.';
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          for (final child in children) ...[child, const SizedBox(height: 16)],
        ],
      ),
    ),
  );
}

class GarmentPhoto extends ConsumerWidget {
  const GarmentPhoto({required this.path, this.height = 160, super.key});
  final String? path;
  final double height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(
      height: height,
      color: const Color(0xffeeebf7),
      child: const Center(
        child: Icon(
          Icons.checkroom_rounded,
          size: 52,
          color: Color(0xff6554c0),
        ),
      ),
    );
    if (path == null) return placeholder;
    try {
      return Image.file(
        ref.read(assetStoreProvider).resolve(path!),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, _, _) => SizedBox(
          height: height,
          child: const Center(child: Text('فایل عکس در دسترس نیست')),
        ),
      );
    } catch (_) {
      return placeholder;
    }
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('خواندن اطلاعات ممکن نشد'),
          TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      ),
    ),
  );
}
