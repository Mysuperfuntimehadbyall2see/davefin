import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../playback/seek_icons.dart';

/// The pop-out player's chrome over its video: a title row to drag the
/// window by, with dock, back-to-player and stop, and transport along the
/// bottom. It fades out while the pointer is away and the video plays, and
/// keeps the keyboard: space plays and pauses, the arrows seek and Escape
/// goes back to the full player.
class PopOutPlayerControls extends StatefulWidget {
  final Widget video;
  final Widget? progress;
  final String title;
  final String? subtitle;
  final bool isPlaying;
  final int seekBackMs;
  final int seekForwardMs;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onSeekRelative;
  final VoidCallback onReturnToPlayer;
  final VoidCallback onDock;
  final VoidCallback onStop;

  /// Starts moving the window with the pointer. The title bar is hidden, so
  /// the video itself is what the viewer drags.
  final VoidCallback? onStartDrag;

  /// A skip intro or credits button, when the segment asks.
  final Widget? skipSegment;

  const PopOutPlayerControls({
    super.key,
    required this.video,
    required this.title,
    required this.isPlaying,
    required this.seekBackMs,
    required this.seekForwardMs,
    required this.onTogglePlayPause,
    required this.onSeekRelative,
    required this.onReturnToPlayer,
    required this.onDock,
    required this.onStop,
    this.progress,
    this.subtitle,
    this.onStartDrag,
    this.skipSegment,
  });

  static const hideDelay = Duration(seconds: 2);

  @override
  State<PopOutPlayerControls> createState() => _PopOutPlayerControlsState();
}

class _PopOutPlayerControlsState extends State<PopOutPlayerControls> {
  bool _shown = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(PopOutPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _show();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _show() {
    if (!_shown) setState(() => _shown = true);
    _scheduleHide();
  }

  // Paused, the controls stay: there's nothing to watch under them.
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.isPlaying) return;
    _hideTimer = Timer(PopOutPlayerControls.hideDelay, () {
      if (mounted) setState(() => _shown = false);
    });
  }

  void _hideNow() {
    _hideTimer?.cancel();
    if (widget.isPlaying && _shown) setState(() => _shown = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space):
            widget.onTogglePlayPause,
        const SingleActivator(LogicalKeyboardKey.escape):
            widget.onReturnToPlayer,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            widget.onSeekRelative(-widget.seekBackMs),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            widget.onSeekRelative(widget.seekForwardMs),
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: (_) => _show(),
          onExit: (_) => _hideNow(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _show,
                onDoubleTap: widget.onReturnToPlayer,
                onPanStart: widget.onStartDrag == null
                    ? null
                    : (_) => widget.onStartDrag!(),
                child: widget.video,
              ),
              IgnorePointer(
                ignoring: !_shown,
                child: AnimatedOpacity(
                  opacity: _shown ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      _topRow(l10n),
                      const Spacer(),
                      if (widget.skipSegment case final skip?)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: skip,
                          ),
                        ),
                      _bottomRow(l10n),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: widget.onStartDrag == null
                  ? null
                  : (_) => widget.onStartDrag!(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle case final subtitle?)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _button(
            Icons.picture_in_picture_alt_rounded,
            l10n.popOutPlayerDock,
            widget.onDock,
          ),
          _button(
            Icons.open_in_full_rounded,
            l10n.popOutPlayerReturn,
            widget.onReturnToPlayer,
          ),
          _button(Icons.close_rounded, l10n.stop, widget.onStop),
        ],
      ),
    );
  }

  Widget _bottomRow(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?widget.progress,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _button(
                seekBackIcon(widget.seekBackMs),
                l10n.playerTooltipSeekBack,
                () => widget.onSeekRelative(-widget.seekBackMs),
              ),
              _button(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                widget.isPlaying ? l10n.pause : l10n.play,
                widget.onTogglePlayPause,
                size: 32,
              ),
              _button(
                seekForwardIcon(widget.seekForwardMs),
                l10n.playerTooltipSeekForward,
                () => widget.onSeekRelative(widget.seekForwardMs),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    double size = 22,
  }) {
    // Clicks on the chrome must not take focus from the shortcuts above.
    return ExcludeFocus(
      child: IconButton(
        onPressed: () {
          onPressed();
          _show();
        },
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
