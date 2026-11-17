import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/pop_out_player/pop_out_window.dart';

/// An OS window in memory, recording the calls made to it in order.
class _FakeWindow implements PopOutWindowHost {
  Rect bounds = const Rect.fromLTWH(100, 100, 1280, 720);
  bool fullScreen;
  bool maximized;
  bool alwaysOnTop;
  bool titleBarHidden = false;
  Size minimumSize = appMinimumWindowSize;
  double aspectRatio = 0;
  Rect? workArea;
  final calls = <String>[];

  _FakeWindow({
    this.fullScreen = false,
    this.maximized = false,
    this.alwaysOnTop = false,
    this.workArea = const Rect.fromLTWH(0, 0, 1920, 1040),
  });

  @override
  Future<Rect> getBounds() async => bounds;

  @override
  Future<void> setBounds(Rect value) async {
    calls.add('setBounds');
    bounds = value;
  }

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    calls.add('setFullScreen($value)');
    fullScreen = value;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximized = true;
  }

  @override
  Future<void> unmaximize() async {
    calls.add('unmaximize');
    maximized = false;
  }

  @override
  Future<bool> isAlwaysOnTop() async => alwaysOnTop;

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    calls.add('setAlwaysOnTop($value)');
    alwaysOnTop = value;
  }

  @override
  Future<void> setTitleBarHidden(bool hidden) async {
    calls.add('setTitleBarHidden($hidden)');
    titleBarHidden = hidden;
  }

  @override
  Future<void> setMinimumSize(Size size) async {
    calls.add('setMinimumSize');
    minimumSize = size;
  }

  @override
  Future<void> setAspectRatio(double ratio) async {
    calls.add('setAspectRatio');
    aspectRatio = ratio;
  }

  @override
  Future<Rect?> workAreaFor(Rect bounds) async => workArea;
}

void main() {
  group('popOutBoundsFor', () {
    test('a quarter of the work area wide, 16:9, in the bottom right', () {
      final bounds = popOutBoundsFor(
        workArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        current: Rect.zero,
      );
      expect(bounds.size, const Size(480, 270));
      expect(bounds.bottomRight, const Offset(1920 - 24, 1040 - 24));
    });

    test('stays between 320 and 640 wide', () {
      expect(
        popOutBoundsFor(
          workArea: const Rect.fromLTWH(0, 0, 1024, 600),
          current: Rect.zero,
        ).width,
        320,
      );
      expect(
        popOutBoundsFor(
          workArea: const Rect.fromLTWH(0, 0, 5120, 2880),
          current: Rect.zero,
        ).width,
        640,
      );
    });

    test('lands on the display the work area belongs to', () {
      final bounds = popOutBoundsFor(
        workArea: const Rect.fromLTWH(1920, 0, 2560, 1400),
        current: Rect.zero,
      );
      expect(bounds.right, 1920 + 2560 - 24);
    });

    test('follows the aspect ratio it is given', () {
      final bounds = popOutBoundsFor(
        workArea: const Rect.fromLTWH(0, 0, 1920, 1040),
        current: Rect.zero,
        aspectRatio: 4 / 3,
      );
      expect(bounds.height, 360);
    });

    test('shrinks in place without a work area', () {
      final bounds = popOutBoundsFor(
        workArea: null,
        current: const Rect.fromLTWH(50, 60, 1280, 720),
      );
      expect(bounds, const Rect.fromLTWH(50, 60, 480, 270));
    });
  });

  group('PopOutWindow', () {
    test('enter makes a small borderless always-on-top window', () async {
      final window = _FakeWindow();
      final popOut = PopOutWindow(window);

      await popOut.enter();

      expect(popOut.active.value, isTrue);
      expect(window.alwaysOnTop, isTrue);
      expect(window.titleBarHidden, isTrue);
      expect(window.aspectRatio, closeTo(16 / 9, 1e-9));
      expect(window.minimumSize, popOutMinimumSize);
      expect(window.bounds.size, const Size(480, 270));
      expect(popOut.restoreBounds, const Rect.fromLTWH(100, 100, 1280, 720));
      // The minimum comes down before the window shrinks below the old one.
      expect(
        window.calls.indexOf('setMinimumSize'),
        lessThan(window.calls.indexOf('setBounds')),
      );
    });

    test('exit puts the window back the way it was', () async {
      final window = _FakeWindow();
      final popOut = PopOutWindow(window);

      await popOut.enter();
      await popOut.exit();

      expect(popOut.active.value, isFalse);
      expect(popOut.restoreBounds, isNull);
      expect(window.bounds, const Rect.fromLTWH(100, 100, 1280, 720));
      expect(window.alwaysOnTop, isFalse);
      expect(window.titleBarHidden, isFalse);
      expect(window.aspectRatio, 0);
      expect(window.minimumSize, appMinimumWindowSize);
    });

    test('a window pinned on top before stays pinned after', () async {
      final window = _FakeWindow(alwaysOnTop: true);
      final popOut = PopOutWindow(window);

      await popOut.enter();
      await popOut.exit();

      expect(window.alwaysOnTop, isTrue);
    });

    test(
      'a maximized window is restored first and maximized again after',
      () async {
        final window = _FakeWindow(maximized: true);
        final popOut = PopOutWindow(window);

        await popOut.enter();
        expect(window.maximized, isFalse);
        expect(window.calls.first, 'unmaximize');

        await popOut.exit();
        expect(window.maximized, isTrue);
        expect(window.calls.last, 'maximize');
      },
    );

    test('a fullscreen window leaves fullscreen and goes back to it', () async {
      final window = _FakeWindow(fullScreen: true);
      final popOut = PopOutWindow(window);

      await popOut.enter();
      expect(window.fullScreen, isFalse);

      await popOut.exit();
      expect(window.fullScreen, isTrue);
    });

    test('a second enter keeps the bounds saved by the first', () async {
      final window = _FakeWindow();
      final popOut = PopOutWindow(window);

      await popOut.enter();
      final calls = window.calls.length;
      await popOut.enter();

      expect(window.calls.length, calls);
      expect(popOut.restoreBounds, const Rect.fromLTWH(100, 100, 1280, 720));
    });

    test('with no display found it shrinks where it is', () async {
      final window = _FakeWindow(workArea: null);
      await PopOutWindow(window).enter();
      expect(window.bounds, const Rect.fromLTWH(100, 100, 480, 270));
    });

    test('exit without enter leaves the window alone', () async {
      final window = _FakeWindow();
      await PopOutWindow(window).exit();
      expect(window.calls, isEmpty);
    });

    test('presses that overlap run one after the other', () async {
      final window = _FakeWindow();
      final popOut = PopOutWindow(window);

      // Not awaited in between: the exit has to wait for the enter, or it
      // would find nothing saved and leave the window small.
      await Future.wait([popOut.enter(), popOut.exit(), popOut.enter()]);

      expect(popOut.active.value, isTrue);
      expect(popOut.restoreBounds, const Rect.fromLTWH(100, 100, 1280, 720));

      await popOut.exit();
      expect(window.bounds, const Rect.fromLTWH(100, 100, 1280, 720));
    });

    test('a failed step does not wedge the ones after it', () async {
      final window = _ThrowingOnceWindow();
      final popOut = PopOutWindow(window);

      await expectLater(popOut.enter(), throwsStateError);
      await popOut.exit();

      expect(popOut.active.value, isFalse);
      expect(window.bounds, const Rect.fromLTWH(100, 100, 1280, 720));
    });
  });
}

class _ThrowingOnceWindow extends _FakeWindow {
  bool _threw = false;

  @override
  Future<void> setAspectRatio(double ratio) async {
    if (!_threw) {
      _threw = true;
      throw StateError('window went away');
    }
    return super.setAspectRatio(ratio);
  }
}
