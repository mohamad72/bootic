import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../application/live_tryon_bridge.dart';
import '../domain/garment.dart';

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
  bool _autoPlacement = false;
  LivePlacement? _posePlacement;
  StreamSubscription<LivePlacement>? _placementSubscription;
  StreamSubscription<String>? _errorSubscription;
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
    setState(() {
      _garmentId = garment?.id;
      _error = null;
    });
    if (!_running) return;
    try {
      await _bridge.setGarment(_photoPath(garment));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _start(Garment? garment) async {
    if (_busy || _running || !Platform.isAndroid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _bridge.start();
      if (!mounted) {
        await _bridge.stop();
        return;
      }
      setState(() => _running = true);
      await _bridge.setMirror(_mirror);
      await _bridge.setGarment(_photoPath(garment));
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
    final available =
        ref
            .watch(catalogProvider)
            .value
            ?.where(
              (g) =>
                  !g.isDraft &&
                  g.isActive &&
                  !g.archived &&
                  g.stock > 0 &&
                  g.photos['front'] != null,
            )
            .toList() ??
        const <Garment>[];
    final selected = available.where((g) => g.id == _garmentId).firstOrNull;
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
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
            onChanged: (id) =>
                _selectGarment(available.where((g) => g.id == id).firstOrNull),
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
