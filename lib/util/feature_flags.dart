/// Compile-time switches for features still being proven out. Each one can be
/// turned off for a build with `--dart-define=<NAME>=false`.
abstract final class FeatureFlags {
  /// The pop-out player: the playing video in a small, resizable,
  /// always-on-top window on desktop, and the browser's picture-in-picture on
  /// web.
  static const popOutPlayer = bool.fromEnvironment(
    'POP_OUT_PLAYER',
    defaultValue: true,
  );
}
