import 'package:flutter/services.dart';

class ExternalDisplay {
  const ExternalDisplay({required this.id, required this.name});

  final int id;
  final String name;

  factory ExternalDisplay.fromMap(Map<Object?, Object?> map) => ExternalDisplay(
    id: (map['id'] as num).toInt(),
    name: map['name'] as String? ?? 'نمایشگر خارجی',
  );
}

class LivePlacement {
  const LivePlacement({
    required this.visible,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  final bool visible;
  final double centerX, centerY, width, height;

  factory LivePlacement.fromMap(Map<Object?, Object?> map) => LivePlacement(
    visible: map['visible'] == true,
    centerX: (map['centerX'] as num?)?.toDouble() ?? 0.5,
    centerY: (map['centerY'] as num?)?.toDouble() ?? 0.5,
    width: (map['width'] as num?)?.toDouble() ?? 0.5,
    height: (map['height'] as num?)?.toDouble() ?? 0.5,
  );
}

class LiveTryonBridge {
  const LiveTryonBridge();

  static const _channel = MethodChannel('ir.bootic.store_app/live_tryon');
  static const _events = EventChannel('ir.bootic.store_app/live_tryon_events');
  static final Stream<dynamic> _nativeEvents = _events.receiveBroadcastStream();

  Stream<LivePlacement> get placements => _nativeEvents
      .where((value) => value is Map && value['type'] == 'placement')
      .map(
        (value) =>
            LivePlacement.fromMap((value as Map).cast<Object?, Object?>()),
      );

  Stream<String> get errors => _nativeEvents
      .where((value) => value is Map && value['type'] == 'error')
      .map(
        (value) =>
            (value as Map)['message'] as String? ?? 'تشخیص بدن متوقف شد.',
      );

  Stream<bool> get gestureVotes => _nativeEvents
      .where((value) => value is Map && value['type'] == 'gestureVote')
      .map((value) => (value as Map)['liked'] == true);

  Stream<String> get gestureErrors => _nativeEvents
      .where((value) => value is Map && value['type'] == 'gestureError')
      .map(
        (value) =>
            (value as Map)['message'] as String? ?? 'تشخیص علامت دست متوقف شد.',
      );

  Future<bool> start() async {
    final state = await _channel.invokeMapMethod<String, dynamic>('start');
    return state?['front'] as bool? ?? true;
  }

  Future<bool> setCameraFacing(bool front) async {
    final state = await _channel.invokeMapMethod<String, dynamic>(
      'setCameraFacing',
      {'front': front},
    );
    return state?['front'] as bool? ?? front;
  }

  /// Native returns the duration used by the animation, keeping the garment
  /// timer and both displays on the same two-second loading cycle.
  Future<Duration> setSceneEffect(String effect) async {
    final milliseconds = await _channel.invokeMethod<int>('setSceneEffect', {
      'effect': effect,
    });
    if (milliseconds == null) throw StateError('مدت افکت دریافت نشد');
    return Duration(milliseconds: milliseconds);
  }

  Future<void> setVotingEnabled(bool enabled) async =>
      _channel.invokeMethod<void>('setVotingEnabled', {'enabled': enabled});

  Future<void> removeGarmentBackground(String path) async =>
      _channel.invokeMethod<void>('removeGarmentBackground', {'path': path});

  Future<void> stop() async => _channel.invokeMethod<void>('stop');

  Future<List<ExternalDisplay>> listDisplays() async {
    final raw = await _channel.invokeListMethod<Object?>('listDisplays');
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => ExternalDisplay.fromMap(item.cast<Object?, Object?>()))
        .toList();
  }

  Future<void> attachDisplay(int id) async =>
      _channel.invokeMethod<void>('attachDisplay', {'id': id});

  Future<void> detachDisplay() async =>
      _channel.invokeMethod<void>('detachDisplay');

  Future<void> setGarment(String? path) async =>
      _channel.invokeMethod<void>('setGarment', {'path': path});

  Future<void> setPrice(String text) async =>
      _channel.invokeMethod<void>('setPrice', {'text': text});

  Future<void> setFeedback(String text) async =>
      _channel.invokeMethod<void>('setFeedback', {'text': text});

  Future<void> setGestureControl(bool enabled) async =>
      _channel.invokeMethod<void>('setGestureControl', {'enabled': enabled});

  Future<void> setPlacement({
    required double centerX,
    required double centerY,
    required double width,
    required double height,
  }) async => _channel.invokeMethod<void>('setPlacement', {
    'centerX': centerX,
    'centerY': centerY,
    'width': width,
    'height': height,
  });

  Future<void> setMirror(bool mirror) async =>
      _channel.invokeMethod<void>('setMirror', {'mirror': mirror});

  Future<void> setAutoPlacement(bool enabled) async =>
      _channel.invokeMethod<void>('setAutoPlacement', {'enabled': enabled});

  Future<String?> captureGarment() async =>
      _channel.invokeMethod<String>('captureGarment');
}
