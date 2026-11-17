import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/pop_out_player/pop_out_player_controls.dart';

class _Calls {
  int playPause = 0;
  int returned = 0;
  int docked = 0;
  int stopped = 0;
  int dragged = 0;
  final seeks = <int>[];
}

Widget _harness(_Calls calls, {bool isPlaying = true, String? subtitle}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SizedBox(
      width: 480,
      height: 270,
      child: PopOutPlayerControls(
        video: const ColoredBox(key: Key('video'), color: Colors.black),
        title: 'The Show',
        subtitle: subtitle,
        isPlaying: isPlaying,
        seekBackMs: 10000,
        seekForwardMs: 30000,
        onTogglePlayPause: () => calls.playPause++,
        onSeekRelative: calls.seeks.add,
        onReturnToPlayer: () => calls.returned++,
        onDock: () => calls.docked++,
        onStop: () => calls.stopped++,
        onStartDrag: () => calls.dragged++,
      ),
    ),
  );
}

double _chromeOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('The Show'),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('shows the title and the transport', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls, subtitle: 'S1:E2 - Pilot'));

    expect(find.text('The Show'), findsOneWidget);
    expect(find.text('S1:E2 - Pilot'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Return to full player'), findsOneWidget);
    expect(find.byTooltip('Dock in app window'), findsOneWidget);
  });

  testWidgets('each button reaches its callback', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));

    await tester.tap(find.byTooltip('Pause'));
    await tester.tap(find.byTooltip('Return to full player'));
    await tester.tap(find.byTooltip('Dock in app window'));
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(calls.playPause, 1);
    expect(calls.returned, 1);
    expect(calls.docked, 1);
    expect(calls.stopped, 1);
  });

  testWidgets('seek buttons use the configured lengths', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    final l10n = AppLocalizations.of(tester.element(find.text('The Show')));

    await tester.tap(find.byTooltip(l10n.playerTooltipSeekBack));
    await tester.tap(find.byTooltip(l10n.playerTooltipSeekForward));
    await tester.pump();

    expect(calls.seeks, [-10000, 30000]);
  });

  testWidgets('the keyboard drives playback', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    expect(calls.playPause, 1);
    expect(calls.seeks, [-10000, 30000]);
    expect(calls.returned, 1);
  });

  testWidgets('double clicking the video goes back to the full player', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));

    final video = tester.getCenter(find.byKey(const Key('video')));
    await tester.tapAt(video);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(video);
    await tester.pumpAndSettle();

    expect(calls.returned, 1);
  });

  testWidgets('dragging the video moves the window', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));

    await tester.drag(find.byKey(const Key('video')), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(calls.dragged, 1);
  });

  testWidgets('the chrome fades while playing and comes back on hover', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    expect(_chromeOpacity(tester), 1);

    await tester.pump(PopOutPlayerControls.hideDelay);
    await tester.pumpAndSettle();
    expect(_chromeOpacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('video'))));
    await tester.pump();
    expect(_chromeOpacity(tester), 1);

    // Let the hide timer run out so the test leaves nothing pending.
    await tester.pump(PopOutPlayerControls.hideDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('paused, the chrome stays up', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls, isPlaying: false));

    await tester.pump(PopOutPlayerControls.hideDelay * 2);
    await tester.pumpAndSettle();

    expect(_chromeOpacity(tester), 1);
    expect(find.byTooltip('Play'), findsOneWidget);
  });
}
