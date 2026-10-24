import 'package:flutter/services.dart';

/// Where the phone's clock since it started stands: which start of the
/// phone it counts from, and how long ago that was, asleep or not.
typedef BootTime = ({int boot, Duration sinceBoot});

/// What the App Lock needs from the phone, through the app's own Android
/// code: the recent apps, which show the app's last screen, a clock, and
/// putting the app away.
class DeviceService {
  static const _channel = MethodChannel('com.k.todo/device');

  /// Keeps the app's last screen out of the recent apps while [hidden],
  /// where anyone could see it without unlocking the app.
  Future<void> hideFromRecents(bool hidden) =>
      _channel.invokeMethod<void>('hideFromRecents', hidden);

  /// How long the phone has been on, counting the time it's slept, which
  /// turning its clock back can't change.
  Future<Duration> sinceBoot() async => Duration(
      milliseconds: (await _channel.invokeMethod<int>('elapsedRealtime'))!);

  /// The same, and which start of the phone it counts from: a restart starts
  /// it again, from another [BootTime.boot].
  Future<BootTime> bootTime() async {
    final time = (await _channel.invokeMapMethod<String, int>('bootTime'))!;
    return (
      boot: time['boot']!,
      sinceBoot: Duration(milliseconds: time['sinceBoot']!),
    );
  }

  /// Puts the app away, as Home does, with its pages as they are, where Back
  /// would close them.
  Future<void> moveToBack() => _channel.invokeMethod<void>('moveToBack');
}
