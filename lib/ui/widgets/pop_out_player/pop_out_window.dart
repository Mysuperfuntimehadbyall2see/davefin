import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../../util/platform_detection.dart';

/// The smallest the app window may be outside the pop-out. main.dart sets it
/// at launch, and the pop-out puts it back on the way out.
const appMinimumWindowSize = Size(800, 500);

/// The smallest the pop-out may be resized to: room for the transport row.
const popOutMinimumSize = Size(256, 144);

/// The window operations the pop-out needs, so tests can stand in for the
/// OS window.
abstract interface class PopOutWindowHost {
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<bool> isFullScreen();
  Future<void> setFullScreen(bool value);
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<bool> isAlwaysOnTop();
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setTitleBarHidden(bool hidden);
  Future<void> setMinimumSize(Size size);

  /// Locks resizing to [ratio], or lets it go when [ratio] is not positive.
  Future<void> setAspectRatio(double ratio);

  /// The usable area of the display the window is on, or null when unknown.
  Future<Rect?> workAreaFor(Rect bounds);
}

class WindowManagerPopOutHost implements PopOutWindowHost {
  const WindowManagerPopOutHost();

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> unmaximize() => windowManager.unmaximize();

  @override
  Future<bool> isAlwaysOnTop() => windowManager.isAlwaysOnTop();

  @override
  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);

  @override
  Future<void> setTitleBarHidden(bool hidden) => windowManager.setTitleBarStyle(
    hidden ? TitleBarStyle.hidden : TitleBarStyle.normal,
    // macOS would otherwise keep the traffic lights over the video.
    windowButtonVisibility: !hidden,
  );

  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  // Linux only lifts the lock for a negative ratio; the others for anything
  // not positive.
  @override
  Future<void> setAspectRatio(double ratio) =>
      windowManager.setAspectRatio(ratio > 0 ? ratio : -1);

  @override
  Future<Rect?> workAreaFor(Rect bounds) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      Rect areaOf(Display d) =>
          (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
      for (final display in displays) {
        final area = areaOf(display);
        if (area.contains(bounds.center)) return area;
      }
      return areaOf(await screenRetriever.getPrimaryDisplay());
    } catch (_) {
      return null;
    }
  }
}

/// Where the pop-out opens: a quarter of the display's width, between 320 and
/// 640 wide, in [aspectRatio], in the bottom right corner. Without a known
/// work area it shrinks in place from [current]'s top left.
@visibleForTesting
Rect popOutBoundsFor({
  required Rect? workArea,
  required Rect current,
  double aspectRatio = 16 / 9,
  double margin = 24,
}) {
  final width = workArea == null
      ? 480.0
      : (workArea.width / 4).clamp(320.0, 640.0).toDouble();
  final size = Size(width, width / aspectRatio);
  if (workArea == null) return current.topLeft & size;
  return Offset(
        workArea.right - margin - size.width,
        workArea.bottom - margin - size.height,
      ) &
      size;
}

/// What the window looked like before it popped out, to put back after.
@immutable
class _WindowState {
  final Rect bounds;
  final bool fullScreen;
  final bool maximized;
  final bool alwaysOnTop;

  const _WindowState({
    required this.bounds,
    required this.fullScreen,
    required this.maximized,
    required this.alwaysOnTop,
  });
}

/// Turns the app window into the pop-out player and back. The video can't
/// leave the engine that decodes it - mpv's texture, the native HDR window
/// and AetherEngine's view all belong to this window - so rather than open a
/// second window that would have to show a copy, this one becomes the small,
/// borderless, always-on-top window, and grows back into the app when the
/// viewer returns.
class PopOutWindow {
  PopOutWindow(this._host);

  static final instance = PopOutWindow(const WindowManagerPopOutHost());

  final PopOutWindowHost _host;

  /// Whether the window is the pop-out right now.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  _WindowState? _saved;

  /// Enter and exit take a few round trips to the window each, and a second
  /// press while one runs would save the half-changed window as the one to
  /// go back to. Each waits for the one before.
  Future<void> _pending = Future.value();

  /// Desktop only: phones and tablets have the system's picture-in-picture,
  /// and web has the browser's.
  static bool get isSupported => PlatformDetection.isDesktop;

  /// The windowed bounds the app goes back to, while popped out. The app
  /// saves this rather than the pop-out's own for its next launch.
  Rect? get restoreBounds => _saved?.bounds;

  Future<void> enter({double aspectRatio = 16 / 9}) =>
      _queue(() => _enter(aspectRatio));

  Future<void> exit() => _queue(_exit);

  Future<void> _queue(Future<void> Function() step) {
    final next = _pending.then((_) => step());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _enter(double aspectRatio) async {
    if (_saved != null) return;
    final fullScreen = await _host.isFullScreen();
    if (fullScreen) await _host.setFullScreen(false);
    final maximized = await _host.isMaximized();
    if (maximized) await _host.unmaximize();
    final saved = _WindowState(
      bounds: await _host.getBounds(),
      fullScreen: fullScreen,
      maximized: maximized,
      alwaysOnTop: await _host.isAlwaysOnTop(),
    );
    _saved = saved;
    active.value = true;
    final target = popOutBoundsFor(
      workArea: await _host.workAreaFor(saved.bounds),
      current: saved.bounds,
      aspectRatio: aspectRatio,
    );
    await _host.setTitleBarHidden(true);
    await _host.setMinimumSize(popOutMinimumSize);
    await _host.setBounds(target);
    await _host.setAspectRatio(aspectRatio);
    await _host.setAlwaysOnTop(true);
  }

  Future<void> _exit() async {
    final saved = _saved;
    if (saved == null) return;
    await _host.setAlwaysOnTop(saved.alwaysOnTop);
    await _host.setAspectRatio(0);
    await _host.setBounds(saved.bounds);
    await _host.setMinimumSize(appMinimumWindowSize);
    await _host.setTitleBarHidden(false);
    if (saved.maximized) await _host.maximize();
    if (saved.fullScreen) await _host.setFullScreen(true);
    _saved = null;
    active.value = false;
  }
}
