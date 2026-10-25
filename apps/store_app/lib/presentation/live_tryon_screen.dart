import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../application/live_tryon_bridge.dart';
import '../domain/garment.dart';
import '../domain/garment_render_metadata.dart';
import '../domain/garment_model_metadata.dart';
import '../domain/persian.dart';
import '../domain/pose_diagnostics.dart';
import 'tryon_debug_overlay.dart';
import 'boundary_debug_overlay.dart';

/// Customer mode: opening the tab opens the front camera immediately.
class LiveTryonScreen extends ConsumerStatefulWidget {
  const LiveTryonScreen({super.key});

  @override
  ConsumerState<LiveTryonScreen> createState() => _LiveTryonScreenState();
}

class _LiveTryonScreenState extends ConsumerState<LiveTryonScreen>
    with WidgetsBindingObserver {
  final _bridge = const LiveTryonBridge();
  StreamSubscription<LivePlacement>? _placementSubscription;
  StreamSubscription<PoseDebugSnapshot>? _debugSubscription;
  bool _debugEnabled = false;
  bool _boundaryEnabled = false;
  bool _boundaryGhost = true;
  bool _debugGhost = false;
  bool _debugDetails = false;
  PoseDebugSnapshot? _poseDebug;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _gestureSubscription;
  StreamSubscription<String>? _gestureErrorSubscription;
  Timer? _detectionTimer;
  Timer? _nextTimer;
  int _session = 0;
  int _detectionRun = 0;

  bool _frontCamera = true;
  bool _switchingCamera = false;
  bool _running = false;
  bool _busy = false;
  bool _personFound = false;
  bool _detecting = false;
  bool _garmentReady = false;
  bool _gestureReady = false;
  bool _votePending = false;
  bool _changingGarment = false;
  bool _finished = false;
  String? _garmentId;
  String? _voteFeedback;
  String? _error;
  LivePlacement? _placement;
  final Map<String, bool> _votes = {};
  bool get _diagnosticsEnabled => _debugEnabled || _boundaryEnabled;
  bool get _diagnosticGhost =>
      (_debugEnabled && _debugGhost) || (_boundaryEnabled && _boundaryGhost);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _debugSubscription = _bridge.poseDiagnostics.listen((snapshot) {
      if (mounted && _diagnosticsEnabled) setState(() => _poseDebug = snapshot);
    }, onError: _showError);
    _placementSubscription = _bridge.placements.listen(
      _onPlacement,
      onError: (Object error) => _showError(error),
    );
    _errorSubscription = _bridge.errors.listen(_showError, onError: _showError);
    _gestureSubscription = _bridge.gestureVotes.listen((liked) {
      unawaited(_vote(liked));
    }, onError: _showError);
    _gestureErrorSubscription = _bridge.gestureErrors.listen((message) {
      if (mounted) setState(() => _gestureReady = false);
    }, onError: _showError);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_running && !_busy) unawaited(_start());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session++;
    _detectionTimer?.cancel();
    _nextTimer?.cancel();
    if (_debugSubscription != null) unawaited(_debugSubscription!.cancel());
    if (_placementSubscription != null) {
      unawaited(_placementSubscription!.cancel());
    }
    if (_errorSubscription != null) unawaited(_errorSubscription!.cancel());
    if (_gestureSubscription != null) unawaited(_gestureSubscription!.cancel());
    if (_gestureErrorSubscription != null) {
      unawaited(_gestureErrorSubscription!.cancel());
    }
    unawaited(_bridge.stop().catchError((Object _) {}));
    unawaited(_bridge.detachDisplay().catchError((Object _) {}));
    super.dispose();
  }

  String _message(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'CAMERA_DENIED' || 'CAMERA_PERMISSION' => 'اجازه دوربین را فعال کنید.',
        'CAMERA_UNAVAILABLE' => 'دوربین انتخاب‌شده در دسترس نیست.',
        'POSE_UNAVAILABLE' => 'تشخیص بدن روی این گوشی آماده نشد.',
        _ => error.message ?? 'دوربین آماده نشد.',
      };
    }
    return error is String ? error : 'دوربین آماده نشد.';
  }

  void _showError(Object error) {
    if (mounted) setState(() => _error = _message(error));
  }

  List<Garment> _eligible(List<Garment>? all) =>
      (all ?? const <Garment>[]).where((g) => g.tryOnEligible).toList();

  String? _photoPath(Garment? garment) {
    if (garment == null) return null;
    final relative = garment.photos['front_source'];
    if (relative == null) return null;
    try {
      return ref.read(assetStoreProvider).resolve(relative).path;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _syncVoting() => _bridge.setVotingEnabled(
    mounted &&
        _running &&
        _personFound &&
        _garmentReady &&
        !_busy &&
        !_switchingCamera &&
        !_votePending &&
        !_changingGarment &&
        !_boundaryEnabled &&
        !_finished,
  );

  Future<void> _presentGarment(Garment? garment) async {
    final session = _session;
    if (mounted) setState(() => _garmentReady = false);
    await _bridge.setVotingEnabled(false);
    final model = GarmentModelMetadata.isModel(garment?.tryOnJson ?? '')
        ? GarmentModelMetadata.parse(garment!.tryOnJson)
        : null;
    final render = model != null
        ? model.photoMetadata()
        : GarmentRenderMetadata.parse(garment?.tryOnJson ?? '');
    final photo = _photoPath(garment);
    if (garment != null && (render == null || photo == null)) {
      await _bridge.setGarment(null);
      throw StateError(
        'JSON معتبر یا عکس اصلی این لباس موجود نیست؛ مشخصات و عکس روبرو را در فرم لباس تکمیل کنید.',
      );
    }
    if (!mounted || session != _session || !_running) return;
    await _bridge.setGarment(photo, renderMetadata: render?.toNativeMap());
    await _bridge.setGarmentGhost(_diagnosticGhost);
    await _bridge.setPrice(
      garment?.effectivePrice == null
          ? ''
          : '${faNumber(garment!.effectivePrice!)} تومان',
    );
    if (!mounted || session != _session || !_running) return;
    setState(() => _garmentReady = garment != null);
    await _syncVoting();
  }

  Future<void> _clearEffect() async {
    await _bridge.setSceneEffect('none');
  }

  void _onPlacement(LivePlacement placement) {
    if (!mounted || !_running) return;
    setState(() => _placement = placement);
    if (!placement.visible || _personFound || _detecting || _switchingCamera)
      return;
    unawaited(_detectPerson());
  }

  Future<void> _detectPerson() async {
    final session = _session;
    final detection = ++_detectionRun;
    // Acquisition is immediate. The glow is decorative, not a requirement for
    // 1.2 seconds of uninterrupted tracking before preparing the first garment.
    setState(() {
      _detecting = true;
      _personFound = true;
    });
    try {
      final duration = await _bridge.setSceneEffect('detection');
      if (!mounted || session != _session || detection != _detectionRun) return;
      _detectionTimer = Timer(duration, () {
        if (!mounted ||
            !_running ||
            session != _session ||
            detection != _detectionRun)
          return;
        setState(() => _detecting = false);
        unawaited(_clearEffect().catchError(_showError));
      });
      unawaited(_showFirstGarment());
    } catch (error) {
      if (mounted && session == _session && detection == _detectionRun) {
        setState(() => _detecting = false);
        _showError(error);
        // An animation failure must not prevent trying on clothes.
        unawaited(_showFirstGarment());
      }
    }
  }

  Future<void> _showFirstGarment() async {
    final session = _session;
    try {
      final catalog = await ref.read(catalogProvider.future);
      if (!mounted || !_running || !_personFound || session != _session) return;
      final first = _eligible(catalog).firstOrNull;
      setState(() => _garmentId = first?.id);
      await _presentGarment(first);
      if (mounted && session == _session && first == null) {
        setState(
          () => _error = 'لباس آماده‌ای نیست؛ از بخش اپراتور لباس ثبت کنید.',
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted && _running && session == _session) {
        try {
          await _syncVoting();
        } catch (error) {
          _showError(error);
        }
      }
    }
  }

  Future<void> _start() async {
    if (!Platform.isAndroid || _busy || _running) return;
    final session = ++_session;
    _detectionRun++;
    setState(() {
      _busy = true;
      _error = null;
      _personFound = false;
      _detecting = false;
      _placement = null;
      _poseDebug = null;
      _garmentId = null;
      _finished = false;
      _votePending = false;
      _changingGarment = false;
      _gestureReady = false;
      _garmentReady = false;
      _voteFeedback = null;
      _votes.clear();
    });
    try {
      final front = await _bridge.start();
      if (!mounted || session != _session) return;
      setState(() {
        _running = true;
        _frontCamera = front;
      });
      await _presentGarment(null);
      if (!mounted || session != _session) return;
      await _bridge.setFeedback('');
      await _bridge.setAutoPlacement(true);
      await _bridge.setPoseDebugEnabled(_diagnosticsEnabled);
      if (!mounted || session != _session) return;
      try {
        await _bridge.setGestureControl(true);
        if (mounted && session == _session) {
          setState(() => _gestureReady = true);
        }
      } catch (_) {
        // Touch buttons remain available when hand tracking cannot start.
      }
      try {
        final displays = await _bridge.listDisplays();
        if (mounted && session == _session && _running && displays.isNotEmpty) {
          await _bridge.attachDisplay(displays.first.id);
        }
      } catch (_) {
        // The phone camera continues when an external display is unavailable.
      }
    } catch (error) {
      if (mounted && session == _session) {
        await _bridge.stop();
        if (!mounted || session != _session) return;
        setState(() {
          _running = false;
          _error = _message(error);
        });
      }
    } finally {
      if (mounted && session == _session) {
        setState(() => _busy = false);
        try {
          await _syncVoting();
        } catch (error) {
          _showError(error);
        }
      }
    }
  }

  Future<void> _stop() async {
    _detectionRun++;
    _detectionTimer?.cancel();
    _nextTimer?.cancel();
    if (!_running && !_busy) return;
    _session++;
    try {
      await _bridge.stop();
      await _bridge.detachDisplay();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _busy = false;
          _placement = null;
          _poseDebug = null;
          _personFound = false;
          _detecting = false;
          _gestureReady = false;
          _garmentReady = false;
          _votePending = false;
          _changingGarment = false;
        });
      }
    }
  }

  Future<void> _vote(bool liked) async {
    if (_boundaryEnabled ||
        !_running ||
        !_personFound ||
        !_garmentReady ||
        _garmentId == null ||
        _busy ||
        _switchingCamera ||
        _votePending ||
        _finished) {
      return;
    }
    final items = _eligible(ref.read(catalogProvider).value);
    final index = items.indexWhere((g) => g.id == _garmentId);
    if (index < 0) return;
    final session = _session;
    final hasNext = index + 1 < items.length;
    // A late glow timer must never clear the next garment's loading effect.
    _detectionRun++;
    _detectionTimer?.cancel();
    setState(() {
      _detecting = false;
      _votes[items[index].id] = liked;
      _votePending = true;
      _changingGarment = hasNext;
      _voteFeedback = liked ? 'پسندیدید' : 'نپسندیدید';
    });
    try {
      await _bridge.setVotingEnabled(false);
      await _clearEffect();
      await _bridge.setFeedback(_voteFeedback!);
      // Loading starts before the countdown; the native animation is the source
      // of the duration, so Flutter cannot accidentally show the next item early.
      final delay = hasNext
          ? await _bridge.setSceneEffect('loading')
          : const Duration(milliseconds: 900);
      if (!mounted || !_running || session != _session) return;
      _nextTimer?.cancel();
      _nextTimer = Timer(delay, () => unawaited(_advanceGarment(session)));
    } catch (error) {
      if (mounted && session == _session) {
        try {
          await _clearEffect();
        } catch (_) {}
        if (!mounted || session != _session) return;
        setState(() {
          _votePending = false;
          _changingGarment = false;
        });
        _showError(error);
        try {
          await _syncVoting();
        } catch (error) {
          _showError(error);
        }
      }
    }
  }

  Future<void> _advanceGarment(int session) async {
    if (!mounted || !_running || session != _session) return;
    final current = _eligible(ref.read(catalogProvider).value);
    final currentIndex = current.indexWhere((g) => g.id == _garmentId);
    final next = currentIndex >= 0 && currentIndex + 1 < current.length
        ? current[currentIndex + 1]
        : null;
    setState(() {
      _garmentId = next?.id;
      _voteFeedback = null;
      _finished = next == null;
    });
    try {
      // Both old and new clothes stay hidden while the new image is prepared.
      await _presentGarment(next);
      if (!mounted || !_running || session != _session) return;
      await _bridge.setFeedback(next == null ? 'همه لباس‌ها را دیدید' : '');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted && _running && session == _session) {
        try {
          await _clearEffect();
          if (mounted && _running && session == _session) {
            setState(() {
              _votePending = false;
              _changingGarment = false;
            });
            await _syncVoting();
          }
        } catch (error) {
          _showError(error);
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    if (!_running || _busy || _switchingCamera || _votePending) return;
    final session = _session;
    final requested = !_frontCamera;
    _detectionRun++;
    _detectionTimer?.cancel();
    setState(() {
      _switchingCamera = true;
      _detecting = false;
      _placement = null;
      _poseDebug = null;
      _error = null;
    });
    try {
      await _bridge.setVotingEnabled(false);
      await _clearEffect();
      final actualFront = await _bridge.setCameraFacing(requested);
      if (!mounted || session != _session) return;
      setState(() => _frontCamera = actualFront);
    } catch (error) {
      if (!mounted || session != _session) return;
      if (error is! PlatformException || error.code != 'CAMERA_UNAVAILABLE') {
        await _stop();
      }
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _switchingCamera = false);
        if (_running &&
            session == _session &&
            _garmentId != null &&
            !_finished) {
          try {
            await _syncVoting();
          } catch (error) {
            _showError(error);
          }
        }
      }
    }
  }

  Future<void> _setDiagnosticMode({
    required bool debug,
    required bool boundaries,
  }) async {
    try {
      await _bridge.setPoseDebugEnabled(debug || boundaries);
      if (mounted) {
        setState(() {
          _debugEnabled = debug;
          _boundaryEnabled = boundaries;
          _poseDebug = null;
        });
      }
      await _bridge.setGarmentGhost(_diagnosticGhost);
      await _syncVoting();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleDebug() =>
      _setDiagnosticMode(debug: !_debugEnabled, boundaries: false);
  Future<void> _toggleBoundaries() =>
      _setDiagnosticMode(debug: false, boundaries: !_boundaryEnabled);

  Future<void> _restart() async {
    _votes.clear();
    setState(() {
      _finished = false;
      _votePending = false;
      _changingGarment = false;
      _voteFeedback = null;
    });
    await _showFirstGarment();
    try {
      await _bridge.setFeedback('');
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _eligible(ref.watch(catalogProvider).value);
    final selected = available.where((g) => g.id == _garmentId).firstOrNull;
    final placement = _placement;
    final visible =
        _running &&
        _personFound &&
        !_changingGarment &&
        _garmentReady &&
        placement?.visible == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xff10131a)),
        if (Platform.isAndroid)
          AndroidView(
            viewType: 'ir.bootic.store_app/live_scene',
            onPlatformViewCreated: (_) => unawaited(_start()),
          ),
        if (_debugEnabled)
          Positioned.fill(
            child: TryonDebugOverlay(
              snapshot: _poseDebug,
              placement: placement,
              garment: selected == null
                  ? 'بدون لباس'
                  : '${selected.name} (${selected.id})',
              stage: _changingGarment
                  ? 'تعویض لباس'
                  : !_personFound
                  ? 'انتظار بدن'
                  : !_garmentReady
                  ? 'آماده‌سازی مدل لباس'
                  : 'لباس آماده',
              ghost: _debugGhost,
              expanded: _debugDetails,
              onToggleDetails: () =>
                  setState(() => _debugDetails = !_debugDetails),
              onGhostChanged: (value) {
                setState(() => _debugGhost = value);
                unawaited(
                  _bridge
                      .setGarmentGhost(_debugEnabled && value)
                      .catchError(_showError),
                );
              },
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: IconButton.filledTonal(
            tooltip: _debugEnabled
                ? 'خاموش کردن دیباگ'
                : 'روشن کردن دیباگ تشخیص بدن',
            isSelected: _debugEnabled,
            onPressed: _running || _debugEnabled ? _toggleDebug : null,
            icon: const Icon(Icons.bug_report_outlined),
            selectedIcon: const Icon(Icons.bug_report),
          ),
        ),
        Positioned(
          top: 12,
          left: 68,
          child: IconButton.filledTonal(
            tooltip: _boundaryEnabled
                ? 'بستن مرز بدن و خم لباس'
                : 'نمایش مرز بدن و خم لباس',
            isSelected: _boundaryEnabled,
            onPressed: _running || _boundaryEnabled ? _toggleBoundaries : null,
            icon: const Icon(Icons.polyline_outlined),
            selectedIcon: const Icon(Icons.polyline),
          ),
        ),
        if (_boundaryEnabled)
          Positioned(
            top: 12,
            left: 124,
            child: IconButton.filledTonal(
              tooltip: _frontCamera
                  ? 'استفاده از دوربین عقب'
                  : 'استفاده از دوربین جلو',
              onPressed: _running && !_busy && !_switchingCamera
                  ? _switchCamera
                  : null,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ),
        if (!_boundaryEnabled &&
            visible &&
            selected != null &&
            selected.effectivePrice != null)
          Positioned(
            top: 16,
            right: 16,
            child: _badge(
              selected.effectivePrice == null
                  ? 'قیمت مشخص نشده'
                  : '${faNumber(selected.effectivePrice!)} تومان',
              18,
            ),
          ),
        if (!_boundaryEnabled)
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _voteFeedback != null
                  ? _badge(_voteFeedback!, 23)
                  : _finished
                  ? _badge('همه لباس‌ها را دیدید', 20)
                  : const SizedBox.shrink(key: ValueKey('clear')),
            ),
          ),
        if (!_boundaryEnabled)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    _badge(_error!, 14),
                    const SizedBox(height: 8),
                  ],
                  if (_running && !_personFound && !_detecting)
                    _badge('روبه‌روی دوربین بایستید', 16),
                  if (_running && _personFound && placement?.visible != true)
                    _badge('کمی عقب بروید تا دوباره دیده شوید', 15),
                  if (!_running && _error != null)
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.videocam),
                      label: Text(
                        _busy ? 'دوربین در حال باز شدن است' : 'تلاش دوباره',
                      ),
                    ),
                  if (!_running && _error == null)
                    Platform.isAndroid
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _badge(
                            'دوربین زنده روی نسخه اندروید در دسترس است',
                            16,
                          ),
                  if (_running &&
                      _personFound &&
                      !_finished &&
                      selected != null) ...[
                    const SizedBox(height: 8),
                    _badge(selected.name, 16),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                !_garmentReady ||
                                    _busy ||
                                    _votePending ||
                                    _switchingCamera
                                ? null
                                : () => _vote(true),
                            icon: const Icon(Icons.thumb_up_alt_outlined),
                            label: const Text('لایک'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed:
                                !_garmentReady ||
                                    _busy ||
                                    _votePending ||
                                    _switchingCamera
                                ? null
                                : () => _vote(false),
                            icon: const Icon(Icons.thumb_down_alt_outlined),
                            label: const Text('دیسلایک'),
                          ),
                        ),
                      ],
                    ),
                    if (_gestureReady)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'شست بالا یا پایین؛ بعد از ثبت، دست را پایین بیاورید',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                  if (_running) ...[
                    const SizedBox(height: 8),
                    IconButton.filledTonal(
                      tooltip: _frontCamera
                          ? 'استفاده از دوربین عقب'
                          : 'استفاده از دوربین جلو',
                      onPressed: _busy || _switchingCamera || _votePending
                          ? null
                          : _switchCamera,
                      icon: _switchingCamera
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cameraswitch_outlined),
                    ),
                  ],
                  if (_running && _finished)
                    FilledButton(
                      onPressed: _restart,
                      child: const Text('شروع دوباره'),
                    ),
                ],
              ),
            ),
          ),
        if (_boundaryEnabled)
          Positioned.fill(
            child: BoundaryDebugOverlay(
              snapshot: _poseDebug,
              ghost: _boundaryGhost,
              onGhostChanged: (value) {
                setState(() => _boundaryGhost = value);
                unawaited(
                  _bridge
                      .setGarmentGhost(_diagnosticGhost)
                      .catchError(_showError),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _badge(String label, double fontSize, [IconData? icon]) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xdd10131a),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.greenAccent),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
