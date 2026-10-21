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

  Future<void> start() async => _channel.invokeMethod<void>('start');

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
