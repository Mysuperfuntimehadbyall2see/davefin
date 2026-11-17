/// What this build calls itself to the operating system and where it looks
/// for its own updates. Davefin is a side-by-side fork of Moonfin, so these
/// are the only identity values that differ from upstream.
///
/// What the app says to a Jellyfin or Emby server - the client name, the
/// device name, the Moonbase plugin's endpoints - is deliberately not here:
/// the same servers serve Moonfin and Davefin unchanged.
abstract final class AppBranding {
  static const appName = 'Davefin';

  /// The URL scheme this build registers with the OS. Moonfin owns
  /// `moonfin://`; a second app claiming it would steal Moonfin's links.
  static const deepLinkScheme = 'davefin';

  /// Schemes a link may arrive in. `moonfin://` links pasted from a Moonfin
  /// user or produced by the server plugin (watch party invites) still open
  /// here.
  static const acceptedDeepLinkSchemes = {deepLinkScheme, 'moonfin'};

  /// The GitHub repository whose releases the update check reads.
  static const releasesRepository = 'Mysuperfuntimehadbyall2see/davefin';

  /// Where this build's source lives, for the About screen. Davefin is GPL
  /// like Moonfin, so its binaries point at their own source.
  static const sourceCodeUrl = 'https://github.com/$releasesRepository';
}
