import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/local_access.dart';
import 'common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login(bool newStore) async {
    if (!_form.currentState!.validate() || _busy) return;
    if (!LocalAccess.accepts(_code.text)) {
      setState(() => _error = 'کد ورود درست نیست');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (newStore) {
        await ref
            .read(repositoryProvider)
            .saveSetting('storeName', _name.text.trim());
        ref.invalidate(storeNameProvider);
      }
      if (mounted) ref.read(accessProvider.notifier).unlock(_code.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ref
          .watch(storeNameProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                ErrorRetry(onRetry: () => ref.invalidate(storeNameProvider)),
            data: (storeName) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.checkroom_rounded,
                          size: 68,
                          color: Color(0xff6554c0),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'بوتیک',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          storeName.isEmpty
                              ? 'کاتالوگ فروشگاهت، همیشه همراهت'
                              : 'خوش آمدید به $storeName',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (storeName.isEmpty) ...[
                          TextFormField(
                            key: const Key('store-name'),
                            controller: _name,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'نام بوتیک',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'نام بوتیک را وارد کنید'
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: const Key('access-code'),
                          controller: _code,
                          obscureText: true,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'کد ورود',
                            errorText: _error,
                          ),
                          onFieldSubmitted: (_) => _login(storeName.isEmpty),
                          validator: (v) => v == null || v.isEmpty
                              ? 'کد ورود را وارد کنید'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('login-button'),
                          onPressed: _busy
                              ? null
                              : () => _login(storeName.isEmpty),
                          child: Text(
                            _busy
                                ? 'در حال ذخیره…'
                                : storeName.isEmpty
                                ? 'ثبت بوتیک و ورود'
                                : 'ورود به بوتیک',
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'نسخه محلی • کد ورود: ۲۲۲۲۲\nاطلاعات روی همین دستگاه ذخیره می‌شوند.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xff596579)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    ),
  );
}
