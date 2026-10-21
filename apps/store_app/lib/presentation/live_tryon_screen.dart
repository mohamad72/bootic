import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../application/live_tryon_bridge.dart';
import '../domain/garment.dart';
import '../domain/persian.dart';

class LiveTryonScreen extends ConsumerStatefulWidget {
  const LiveTryonScreen({super.key});

  @override
  ConsumerState<LiveTryonScreen> createState() => _LiveTryonScreenState();
}

class _LiveTryonScreenState extends ConsumerState<LiveTryonScreen>
    with WidgetsBindingObserver {
  final _bridge = const LiveTryonBridge();
  bool _running = false;
  bool _busy = false;
  bool _mirror = true;
  bool _autoPlacement = true;
  bool _gestureReady = false;
  bool _votePending = false;
  bool _finished = false;
  String? _voteFeedback;
  final Map<String, bool> _votes = {};
  Timer? _nextTimer;
  LivePlacement? _posePlacement;
  StreamSubscription<LivePlacement>? _placementSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _gestureSubscription;
  StreamSubscription<String>? _gestureErrorSubscription;
  double _centerX = 0.5;
  double _centerY = 0.48;
  double _width = 0.55;
  double _height = 0.55;
  String? _garmentId;
  int? _displayId;
  List<ExternalDisplay> _displays = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placementSubscription = _bridge.placements.listen(
      (placement) {
        if (mounted && _autoPlacement) {
          setState(() => _posePlacement = placement);
        }
      },
      onError: (Object error) {
        if (mounted && _running && _autoPlacement) {
          setState(() => _error = _message(error));
        }
      },
    );
    _errorSubscription = _bridge.errors.listen((message) {
      if (!mounted) return;
      setState(() {
        _autoPlacement = false;
        _posePlacement = null;
        _error = message;
      });
    });
    _gestureSubscription = _bridge.gestureVotes.listen((liked) {
      unawaited(_vote(liked));
    });
    _gestureErrorSubscription = _bridge.gestureErrors.listen((message) {
      if (mounted) {
        setState(() {
          _gestureReady = false;
          _error = message;
        });
      }
    });
    unawaited(_refreshDisplays());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_running && state != AppLifecycleState.resumed) unawaited(_stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _placementSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    final errorSubscription = _errorSubscription;
    if (errorSubscription != null) unawaited(errorSubscription.cancel());
    final gestureSubscription = _gestureSubscription;
    if (gestureSubscription != null) unawaited(gestureSubscription.cancel());
    final gestureErrorSubscription = _gestureErrorSubscription;
    if (gestureErrorSubscription != null) {
      unawaited(gestureErrorSubscription.cancel());
    }
    _nextTimer?.cancel();
    unawaited(_bridge.stop());
    unawaited(_bridge.detachDisplay());
    super.dispose();
  }

  String _message(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'CAMERA_PERMISSION' => 'اجازه دوربین را در تنظیمات گوشی فعال کنید.',
        'CAMERA_UNAVAILABLE' => 'دوربین جلو در دسترس نیست.',
        'DISPLAY_UNAVAILABLE' => 'نمایشگر خارجی در دسترس نیست.',
        'INVALID_GARMENT' => 'عکس این لباس در دسترس نیست.',
        _ => error.message ?? 'راه‌اندازی دوربین یا نمایشگر ممکن نشد.',
      };
    }
    return 'راه‌اندازی دوربین یا نمایشگر ممکن نشد.';
  }

  Future<void> _refreshDisplays() async {
    if (!Platform.isAndroid) return;
    try {
      final displays = await _bridge.listDisplays();
      if (!mounted) return;
      setState(() {
        _displays = displays;
        if (_displayId != null && !displays.any((d) => d.id == _displayId)) {
          _displayId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  String? _photoPath(Garment? garment) {
    final relative = garment?.photos['front'];
    if (relative == null) return null;
    try {
      return ref.read(assetStoreProvider).resolve(relative).path;
    } on ArgumentError {
      return null;
    }
  }

  List<Garment> _eligible(List<Garment>? all) => (all ?? const <Garment>[])
      .where(
        (g) =>
            !g.isDraft &&
            g.isActive &&
            !g.archived &&
            g.stock > 0 &&
            g.photos['front'] != null,
      )
      .toList();

  Future<void> _presentGarment(Garment? garment) async {
    await _bridge.setGarment(_photoPath(garment));
    await _bridge.setPrice(
      garment == null ? '' : '${faNumber(garment.effectivePrice)} تومان',
    );
  }

  Future<void> _sendPlacement() async {
    if (!_running || _autoPlacement) return;
    try {
      await _bridge.setPlacement(
        centerX: _centerX,
        centerY: _centerY,
        width: _width,
        height: _height,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _selectGarment(Garment? garment) async {
    _nextTimer?.cancel();
    setState(() {
      _garmentId = garment?.id;
      _finished = false;
      _votePending = false;
      _voteFeedback = null;
      _error = null;
    });
    if (!_running) return;
    try {
      await _presentGarment(garment);
      await _bridge.setFeedback('');
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _vote(bool liked) async {
    if (!_running || _busy || _votePending || _finished) return;
    final items = _eligible(ref.read(catalogProvider).value);
    final index = items.indexWhere((g) => g.id == _garmentId);
    if (index < 0) return;
    setState(() {
      _votes[items[index].id] = liked;
      _votePending = true;
      _voteFeedback = liked ? 'پسندیده شد' : 'نپسندیدید';
    });
    try {
      await _bridge.setFeedback(_voteFeedback!);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted || !_running) return;
      final current = _eligible(ref.read(catalogProvider).value);
      final currentIndex = current.indexWhere((g) => g.id == _garmentId);
      final next = currentIndex >= 0 && currentIndex + 1 < current.length
          ? current[currentIndex + 1]
          : null;
      setState(() {
        _garmentId = next?.id;
        _votePending = false;
        _voteFeedback = null;
        _finished = next == null;
      });
      try {
        await _presentGarment(next);
        await _bridge.setFeedback(next == null ? 'همه لباس‌ها را دیدید' : '');
      } catch (error) {
        if (mounted) setState(() => _error = _message(error));
      }
    });
  }

  Future<void> _restartSession() async {
    final first = _eligible(ref.read(catalogProvider).value).firstOrNull;
    _votes.clear();
    await _selectGarment(first);
  }

  Future<void> _start(Garment? garment) async {
    if (_busy || _running || !Platform.isAndroid) return;
    garment ??= _eligible(ref.read(catalogProvider).value).firstOrNull;
    if (garment == null) {
      setState(
        () => _error = 'ابتدا یک لباس فعال با عکس روبرو و موجودی ثبت کنید.',
      );
      return;
    }
    _nextTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _garmentId = garment!.id;
      _finished = false;
      _votePending = false;
      _voteFeedback = null;
      _gestureReady = false;
      _votes.clear();
    });
    try {
      await _bridge.start();
      if (!mounted) {
        await _bridge.stop();
        return;
      }
      setState(() => _running = true);
      await _bridge.setMirror(_mirror);
      await _presentGarment(garment);
      await _bridge.setFeedback('');
      if (_autoPlacement) {
        try {
          await _bridge.setAutoPlacement(true);
        } catch (error) {
          setState(() {
            _autoPlacement = false;
            _error = _message(error);
          });
          await _sendPlacement();
        }
      } else {
        await _bridge.setAutoPlacement(false);
        await _sendPlacement();
      }
      try {
        await _bridge.setGestureControl(true);
        if (mounted) setState(() => _gestureReady = true);
      } catch (error) {
        if (mounted) setState(() => _error = _message(error));
      }
    } catch (error) {
      await _bridge.stop();
      if (mounted) {
        setState(() {
          _running = false;
          _error = _message(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!_running && !_busy) return;
    _nextTimer?.cancel();
    try {
      await _bridge.stop();
      await _bridge.detachDisplay();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _displayId = null;
          _posePlacement = null;
          _gestureReady = false;
          _votePending = false;
          _voteFeedback = null;
          _busy = false;
        });
      }
    }
  }

  Future<void> _attach(ExternalDisplay display) async {
    if (!_running || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _bridge.attachDisplay(display.id);
      if (mounted) setState(() => _displayId = display.id);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detach() async {
    try {
      await _bridge.detachDisplay();
      if (mounted) setState(() => _displayId = null);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _toggleAutoPlacement(bool enabled) async {
    if (_busy) return;
    if (!_running) {
      setState(() {
        _autoPlacement = enabled;
        _posePlacement = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _bridge.setAutoPlacement(enabled);
      if (!mounted) return;
      setState(() {
        _autoPlacement = enabled;
        _posePlacement = null;
      });
      if (!enabled) await _sendPlacement();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _eligible(ref.watch(catalogProvider).value);
    final selected = available.where((g) => g.id == _garmentId).firstOrNull;
    final selectedIndex = available.indexWhere((g) => g.id == _garmentId);
    final photo = _photoPath(selected);
    final placement = _autoPlacement
        ? _posePlacement
        : LivePlacement(
            visible: true,
            centerX: _centerX,
            centerY: _centerY,
            width: _width,
            height: _height,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('پیش‌نمایش زنده آزمایشی')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'جای‌گذاری با نقاط بدن یا تنظیم دستی، آزمایشی و تقریبی است؛ کیفیت پرو هنوز روی دستگاه تأیید نشده است.',
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xff10131a)),
                  if (Platform.isAndroid)
                    const AndroidView(
                      viewType: 'ir.bootic.store_app/live_scene',
                    ),
                  if (_running && photo != null && placement?.visible == true)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            Positioned(
                              left:
                                  box.maxWidth *
                                  (placement!.centerX - placement.width / 2),
                              top:
                                  box.maxHeight *
                                  (placement.centerY - placement.height / 2),
                              width: box.maxWidth * placement.width,
                              height: box.maxHeight * placement.height,
                              child: IgnorePointer(
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(
                                    _mirror ? math.pi : 0,
                                  ),
                                  child: Opacity(
                                    opacity: 0.78,
                                    child: Image.file(
                                      File(photo),
                                      fit: BoxFit.fill,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_running && selected != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xdd10131a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            '${faNumber(selected.effectivePrice)} تومان',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_running && _voteFeedback != null)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xdd10131a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _voteFeedback!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_running && _finished)
                    const Center(
                      child: Text(
                        'همه لباس‌ها را دیدید',
                        style: TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ),
                  if (!_running)
                    const Center(
                      child: Text(
                        'دوربین خاموش است',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy
                ? null
                : _running
                ? _stop
                : () => _start(selected),
            icon: Icon(
              _running ? Icons.stop_circle_outlined : Icons.videocam_outlined,
            ),
            label: Text(_running ? 'توقف دوربین' : 'شروع دوربین جلو'),
          ),
          if (_running) ...[
            const SizedBox(height: 12),
            Text(
              _gestureReady
                  ? 'برای رأی، شست را رو به بالا یا پایین جلوی دوربین نگه دارید؛ برای لباس بعدی دست را پایین بیاورید.'
                  : 'تشخیص علامت دست آماده نیست؛ از دکمه‌های زیر استفاده کنید.',
            ),
            if (selectedIndex >= 0)
              Text(
                '${faNumber(selectedIndex + 1)} از ${faNumber(available.length)}: ${selected!.name}',
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _votePending || _finished
                        ? null
                        : () => _vote(true),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: const Text('می‌پسندم'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _votePending || _finished
                        ? null
                        : () => _vote(false),
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    label: const Text('نمی‌پسندم'),
                  ),
                ),
              ],
            ),
            if (_finished)
              OutlinedButton(
                onPressed: _restartSession,
                child: Text(
                  'شروع دوباره؛ ${faNumber(_votes.values.where((liked) => liked).length)} پسندیده',
                ),
              ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey(_garmentId),
            initialValue: selected?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'لباس روی تصویر'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون لباس'),
              ),
              for (final garment in available)
                DropdownMenuItem<String?>(
                  value: garment.id,
                  child: Text(garment.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _votePending
                ? null
                : (id) => _selectGarment(
                    available.where((g) => g.id == id).firstOrNull,
                  ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('نمایش آینه‌ای'),
            value: _mirror,
            onChanged: (value) async {
              setState(() => _mirror = value);
              if (_running) {
                try {
                  await _bridge.setMirror(value);
                } catch (error) {
                  if (mounted) setState(() => _error = _message(error));
                }
              }
            },
          ),
          SwitchListTile(
            title: const Text('جای‌گذاری خودکار آزمایشی'),
            subtitle: const Text(
              'بر اساس شانه و تنه؛ در صورت گم‌شدن بدن، لباس پنهان می‌شود',
            ),
            value: _autoPlacement,
            onChanged: _busy ? null : _toggleAutoPlacement,
          ),
          if (_autoPlacement && _running && placement?.visible != true)
            const Text('بدن در تصویر پیدا نشد؛ روبه‌روی دوربین بایستید.'),
          _slider('جابه‌جایی افقی', _centerX, 0.15, 0.85, (v) => _centerX = v),
          _slider('جابه‌جایی عمودی', _centerY, 0.15, 0.85, (v) => _centerY = v),
          _slider('عرض لباس', _width, 0.2, 0.9, (v) => _width = v),
          _slider('ارتفاع لباس', _height, 0.2, 0.9, (v) => _height = v),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'نمایشگر مستقل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _refreshDisplays,
                icon: const Icon(Icons.refresh),
                label: const Text('جست‌وجو'),
              ),
            ],
          ),
          if (_displays.isEmpty)
            const Text(
              'نمایشگر مستقلی شناسایی نشد. اتصال کابل یا پشتیبانی گوشی را بررسی کنید.',
            ),
          for (final display in _displays)
            ListTile(
              title: Text(display.name),
              subtitle: Text('شناسه نمایشگر: ${display.id}'),
              trailing: _displayId == display.id
                  ? const Icon(Icons.cast_connected)
                  : const Icon(Icons.cast),
              onTap: _running && !_busy ? () => _attach(display) : null,
            ),
          if (_displayId != null)
            OutlinedButton(
              onPressed: _detach,
              child: const Text('قطع نمایشگر'),
            ),
          const SizedBox(height: 12),
          const Text(
            'روی نمایشگر خارجی فقط تصویر مشتری و راهنمای فارسی نمایش داده می‌شود.',
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) assign,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: _autoPlacement
            ? null
            : (next) => setState(() => assign(next)),
        onChangeEnd: _autoPlacement ? null : (_) => unawaited(_sendPlacement()),
      ),
    ],
  );
}
