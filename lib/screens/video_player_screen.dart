import '../widgets/playback_startup_view.dart';
import '../utils/episode_playback_request.dart';
import '../utils/show_shuffle.dart';
import '../models/subtitle_source_priority.dart';
import 'video_player/utils/subtitle_priority_selection.dart';
import 'video_player/player_pip_route.dart';
import 'dart:async';
import '../services/source_selection_diagnostics.dart';
import '../services/player_visibility.dart';
import '../utils/media_kit_init.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_storage.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import '../services/player_display_controls.dart';
import 'package:synchronized/synchronized.dart';

// Removed volume_controller; using media_kit player volume instead
import '../services/storage_service.dart';
import '../services/local_playback_resume_resolver.dart';
import '../services/startup_stream_policy.dart';
import '../services/resume_write_guard.dart';
import '../models/profiles/profile_policy.dart';
import '../services/profiles/profile_policy_guard.dart';
import '../services/skip_segment_service.dart';
import '../services/analytics_service.dart';
import '../services/pip_service.dart';
import '../services/audio_effect_session_service.dart';
import '../services/tvos_decode_remedy.dart';
import '../services/tvos_display_match_service.dart';
import '../services/android_native_downloader.dart';
import '../services/desktop_recording_service.dart';
import '../services/live_recording_service.dart';
import '../services/main_page_bridge.dart';
import '../services/profiles/profile_lock_controller.dart';
import '../services/tracking_source_policy.dart';
import '../services/profiles/profile_runtime.dart';
import '../widgets/recording_limit_dialogs.dart';
import '../services/debrid_service.dart';
import '../services/premiumize_service.dart';
import '../services/alldebrid_service.dart';
import '../utils/platform_util.dart';
import '../utils/player_audio_config.dart';
import '../utils/time_formatters.dart';
import '../utils/series_parser.dart';
import '../utils/movie_parser.dart';
import '../utils/iptv_player_paging.dart';
import '../services/movie_metadata_service.dart';
import '../models/iptv_playlist.dart';
import '../services/stremio_iptv_service.dart';
import '../services/iptv_epg_service.dart';
import '../models/playlist_view_mode.dart';
import '../models/series_playlist.dart';
import '../services/torbox_service.dart';
import '../services/pikpak_api_service.dart';
import '../services/next_episode_service.dart';

import '../widgets/tv_text_field.dart';
import '../widgets/video_output_lease.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

// Video Player Components
import 'video_player/models/playlist_entry.dart';
import 'video_player/services/external_subtitle_payload.dart';
import 'video_player/services/subtitle_track_utils.dart';
import 'video_player/models/gesture_state.dart';
import 'video_player/models/hud_state.dart';
import 'video_player/painters/double_tap_ripple_painter.dart';
import 'video_player/utils/gesture_helpers.dart';
import 'video_player/utils/language_mapping.dart';
import 'video_player/utils/aspect_mode_utils.dart';
import 'video_player/constants/timing_constants.dart';
import 'video_player/widgets/auto_sync_pill.dart';
import 'video_player/widgets/seek_hud.dart';
import 'video_player/widgets/vertical_hud.dart';
import 'video_player/widgets/aspect_ratio_hud.dart';
import 'video_player/widgets/controls.dart';
import 'video_player/widgets/dock_style.dart';
import 'video_player/widgets/tv_controls.dart';
import 'video_player/widgets/aspect_ratio_video.dart';
import 'video_player/widgets/transition_overlay.dart';
import 'video_player/widgets/pikpak_retry_overlay.dart';
import 'video_player/widgets/buffering_indicator.dart';
import 'video_player/widgets/tracks_sheet.dart';
import 'video_player/widgets/external_audio_sheet.dart';
import 'video_player/widgets/player_menu_panel.dart';
import 'video_player/widgets/playlist_sheet.dart';
import 'video_player/widgets/channel_guide.dart';
import 'video_player/widgets/iptv_channel_sheet.dart';
import 'video_player/widgets/iptv_zap_banner.dart';
import 'video_player/widgets/player_guide_style.dart';
import '../widgets/iptv/styles/iptv_style.dart';
import 'video_player/widgets/source_sheet.dart';
import 'video_player/widgets/stremio_tv_guide_sheet.dart';
import 'video_player/models/channel_entry.dart';
import 'video_player/services/network_tuning.dart';
import 'video_player/services/subtitle_settings_service.dart';
import 'video_player/services/media_kit_subtitle_auto_sync.dart';
import 'video_player/services/playback_ui_clock.dart';
import 'video_player/services/skip_segment_ui_controller.dart';
import 'video_player/services/android_renderer_startup_fallback.dart';
import 'video_player/services/iptv_tune_diagnostics.dart';
import 'video_player/services/iptv_live_recovery.dart';
import 'video_player/widgets/subtitle_line_picker_overlay.dart';
import 'video_player/widgets/skip_segment_button.dart';
import 'video_player/widgets/sleep_timer_sheet.dart';
import 'video_player/widgets/sync_stepper_overlay.dart';
import 'video_player/widgets/spotlight_dialog.dart';
import 'video_player/widgets/debrify_tv_banner.dart';
import '../models/stremio_subtitle.dart';
import '../models/stremio_addon.dart';
import '../models/torrent.dart';
import '../models/android_video_renderer_mode.dart';
import '../models/content_display_match_mode.dart';
import '../services/series_source_fetcher.dart';
import '../services/stremio_service.dart';
import '../services/stremio_subtitle_service.dart';
import '../services/trakt/trakt_service.dart';
import '../services/simkl/simkl_service.dart';
import '../services/mdblist/mdblist_models.dart';
import '../services/mdblist/mdblist_scrobble_session.dart';
import '../services/mdblist/mdblist_service.dart';
import 'package:http/http.dart' as http;
import '../utils/episode_progress_merge.dart';
import '../utils/tv_keys.dart';
import '../utils/tv_search_focus_handoff.dart';

// Re-export PlaylistEntry for backward compatibility
export 'video_player/models/playlist_entry.dart';
export 'video_player/models/channel_entry.dart';

class _ManualSourceValidationFailure implements Exception {
  const _ManualSourceValidationFailure();
}

class _SeasonEpisodeSelection {
  final int season;
  final int episode;

  const _SeasonEpisodeSelection({required this.season, required this.episode});
}

class _SubtitleApplyAttempt {
  final int generation;
  final mk.SubtitleTrack requested;
  final mk.SubtitleTrack previous;
  final String source;
  final String? previousStremioId;
  final String? previousExternalPath;
  bool failed = false;
  bool handled = false;
  bool successReturned = false;
  bool persisted = false;
  String? persistedAudioId;
  Completer<void>? persistenceDone;

  _SubtitleApplyAttempt({
    required this.generation,
    required this.requested,
    required this.previous,
    required this.source,
    required this.previousStremioId,
    required this.previousExternalPath,
  });
}

/// One page of a live IPTV category, as the browse provider returns it.
///
/// [offset] is the page's absolute position inside [category] and [total] is
/// how many channels that category holds+ßuÁ‚ùÁT the pair that tells the end of a
/// loaded window apart from the end of the category itself.
class _IptvZapPage {
  final List<IptvChannel> channels;
  final int offset;
  final int total;
  final String? sourceId;
  final String? category;
  final List<String> categories;

  const _IptvZapPage({
    required this.channels,
    required this.offset,
    required this.total,
    required this.sourceId,
    required this.category,
    required this.categories,
  });
}

/// Monotonic ownership gate for asynchronous IPTV replay lookups.
///
/// Starting or cancelling a request makes every older ticket stale, preventing
/// a slow catch-up probe from taking playback back after a newer user action.
class IptvCatchupRequestGate {
  int _generation = 0;
  int? _activeTicket;

  int begin() {
    final ticket = ++_generation;
    _activeTicket = ticket;
    return ticket;
  }

  bool isCurrent(int ticket) =>
      _activeTicket == ticket && _generation == ticket;

  bool complete(int ticket) {
    if (!isCurrent(ticket)) return false;
    _activeTicket = null;
    return true;
  }

  bool cancel() {
    if (_activeTicket == null) return false;
    _generation++;
    _activeTicket = null;
    return true;
  }
}

/// A full-featured video player screen with playlist support and navigation controls.
///
/// Features:
/// - Play/pause controls
/// - Next/Previous episode navigation (when playlist is available)
/// - Gesture controls for seeking, volume, and brightness
/// - Aspect ratio controls
/// - Playback speed controls
/// - Audio and subtitle track selection
/// - Auto-advance to next episode when current episode ends
/// - Resume playback from last position
/// - Series-aware episode ordering and tracking
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  /// Optional separate audio track played alongside [videoUrl] via mpv's
  /// external-audio support (high-res YouTube serves video/audio separately).
  final String? audioUrl;
  final String title;
  final String? subtitle;
  final List<PlaylistEntry>? playlist;
  final int? startIndex;
  final String? rdTorrentId; // For updating playlist poster (RealDebrid)
  final String? torboxTorrentId; // For updating playlist poster (Torbox)
  final String? pikpakCollectionId; // For updating playlist poster (PikPak)
  // Optional: Debrify TV provider to fetch the next playable item (url & title)
  final Future<Map<String, String>?> Function()? requestMagicNext;
  // Optional: Debrify TV channel switcher (firstUrl, firstTitle, channel metadata)
  final Future<Map<String, dynamic>?> Function()? requestNextChannel;
  // Optional: Switch to a specific channel by ID
  final Future<Map<String, dynamic>?> Function(String channelId)?
  requestChannelById;
  // Optional: Channel directory for channel guide
  final List<Map<String, dynamic>>? channelDirectory;
  // Advanced: start each video at a random timestamp
  final bool initialContinuousShuffle;
  final bool startFromRandom;
  final int randomStartMaxPercent;
  // Start video at a specific percentage (0.0 to 1.0)
  final double? startAtPercent;
  // Advanced: hide seekbar (double-tap seek still enabled)
  final bool hideSeekbar;
  // Channel name badge overlay
  final bool showChannelName;
  final String? channelName;
  final int? channelNumber;
  // Show video title in player controls
  final bool showVideoTitle;
  // Hide all bottom options (next, audio, etc.) - back button stays
  final bool hideOptions;
  // Hide back button - use device back gesture or escape key
  final bool hideBackButton;
  // HTTP headers for authenticated streaming (e.g., PikPak, private CDNs)
  final Map<String, String>? httpHeaders;
  // Disable auto-resume - start from the specified startIndex instead of last played
  final bool disableAutoResume;
  // Explicit view mode - if null, auto-detect from filenames
  final PlaylistViewMode? viewMode;
  // Content metadata for fetching external subtitles from Stremio addons
  final String? contentImdbId;
  final String? contentType; // 'movie' or 'series'
  final int? contentSeason;
  final int? contentEpisode;
  final String? contentTitle; // Clean display name (IMDB title)
  final PlaybackResumePolicy resumePolicy;
  // IPTV channel list for in-player channel switching
  final List<IptvChannel>? iptvChannels;
  final int? iptvStartIndex;
  final List<String>? iptvCategories;
  final String? iptvSourceId;
  final String? iptvSourceName;
  final String? iptvSelectedCategory;
  final String? iptvContentType;
  final List<Map<String, dynamic>>? iptvSources;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>)?
  iptvBrowseProvider;
  // Stremio sources for in-player source switching
  final List<Torrent>? stremioSources;
  final int? stremioCurrentSourceIndex;
  final Future<String?> Function(Torrent)? resolveStremioSource;
  // Torrent search source switching: resolves a Torrent to a full playlist
  final Future<List<PlaylistEntry>?> Function(Torrent)? resolveSourceToPlaylist;
  final bool startupFailoverEnabled;
  final String? startupResolverProvider;
  final Future<void> Function(Torrent)? onStremioSourceCommitted;
  final Future<void> Function()? onStartupSourcesExhausted;
  // "Load more sources" backend for the source sheet (series pack/episode
  // searches, or the movie search for bound movie plays)
  final SeriesSourceFetcher? seriesSourceFetcher;
  // Stremio TV channel guide data
  final List<Map<String, dynamic>>? stremioTvChannels;
  final String? stremioTvCurrentChannelId;
  final Future<Map<String, dynamic>?> Function(List<String>)?
  stremioTvGuideDataProvider;
  final Future<Map<String, dynamic>?> Function(String)?
  stremioTvChannelSwitchProvider;
  final Future<Map<String, dynamic>?> Function(String)? stremioTvNextProvider;
  // Trakt scrobble: send playback progress to Trakt when playing from Trakt screen
  final bool traktScrobble;
  // Trakt progress: resume fallback when no local resume exists (0-100)
  final double? traktProgressPercent;
  // Simkl scrobble/progress"È›y¯ßy‘ fully parallel to the Trakt pair above (both
  // trackers can run simultaneously; see the Simkl integration plan).
  final bool simklScrobble;
  final double? simklProgressPercent;
  final bool mdblistScrobble;
  final double? mdblistProgressPercent;

  /// Subtitle tracks known at launch (e.g. YouTube closed captions), surfaced
  /// in the subtitle menu as a pre-loaded provider group. Null for sources
  /// whose subtitles are fetched lazily from Stremio addons by IMDb id.
  final List<StremioSubtitle>? initialSubtitles;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.audioUrl,
    required this.title,
    this.subtitle,
    this.playlist,
    this.startIndex,
    this.rdTorrentId,
    this.torboxTorrentId,
    this.pikpakCollectionId,
    this.requestMagicNext,
    this.requestNextChannel,
    this.requestChannelById,
    this.channelDirectory,
    this.initialContinuousShuffle = false,
    this.startFromRandom = false,
    this.randomStartMaxPercent = 40,
    this.startAtPercent,
    this.hideSeekbar = false,
    this.showChannelName = false,
    this.channelName,
    this.channelNumber,
    this.showVideoTitle = true,
    this.hideOptions = false,
    this.hideBackButton = false,
    this.httpHeaders,
    this.disableAutoResume = false,
    this.viewMode,
    this.contentImdbId,
    this.contentType,
    this.contentSeason,
    this.contentEpisode,
    this.contentTitle,
    this.resumePolicy = PlaybackResumePolicy.sourceSpecific,
    this.iptvChannels,
    this.iptvStartIndex,
    this.iptvCategories,
    this.iptvSourceId,
    this.iptvSourceName,
    this.iptvSelectedCategory,
    this.iptvContentType,
    this.iptvSources,
    this.iptvBrowseProvider,
    this.stremioSources,
    this.stremioCurrentSourceIndex,
    this.resolveStremioSource,
    this.resolveSourceToPlaylist,
    this.startupFailoverEnabled = false,
    this.startupResolverProvider,
    this.onStremioSourceCommitted,
    this.onStartupSourcesExhausted,
    this.seriesSourceFetcher,
    this.stremioTvChannels,
    this.stremioTvCurrentChannelId,
    this.stremioTvGuideDataProvider,
    this.stremioTvChannelSwitchProvider,
    this.stremioTvNextProvider,
    this.traktScrobble = false,
    this.traktProgressPercent,
    this.simklScrobble = false,
    this.simklProgressPercent,
    this.mdblistScrobble = false,
    this.mdblistProgressPercent,
    this.initialSubtitles,
  }) : assert(randomStartMaxPercent >= 0);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  static const MethodChannel _tvReleaseLogChannel = MethodChannel(
    'debrify/tvlog',
  );
  static const MethodChannel _androidPlayerDiagnosticChannel = MethodChannel(
    'debrify/player_diagnostics',
  );

  late mk.Player _player;

  // External IPTV audio uses an isolated libmpv handle. Never load the
  // external network stream into the main video handle via audio-add.
  mk.Player? _externalAudioPlayer;
  int _externalAudioGeneration = 0;
  bool _externalAudioSyncInFlight = false;
  DateTime? _externalAudioLastCorrection;

  // While external IPTV audio is active, the main player must not keep its
  // own live audio decoder/output running. On Android this avoids competing
  // audio resources and unnecessary decoding. The previous main aid value is
  // restored when external audio is removed.
  String? _externalAudioPreviousMainAid;

  // _player is assigned partway through the async _initializePlayer(); if the
  // user backs out before that (or init throws first), dispose() must not
  // touch the unassigned late field (LateInitializationError during pop).
  bool _playerCreated = false;

  /// Audio session announced to system effect apps (Android only). Non-null
  /// only while an OPEN broadcast is outstanding+ßuÁ‚ùÁT see
  /// [_attachAudioEffectSession] / [_releaseAudioEffectSession].
  int? _audioEffectSessionId;
  late mkv.VideoController _videoController;
  AndroidVideoRendererMode _androidVideoRendererMode =
      AndroidVideoRendererMode.automatic;

  /// Apple TV blue-screen ladder (PLAYER_TVOS_10BIT_PLAN.md): watches what
  /// the decoder produced and re-routes high-bit VideoToolbox surfaces the
  /// GLES interop cannot represent. Null everywhere but tvOS.
  TvosDecodeRemedy? _tvosDecodeRemedy;

  /// tvOS manual escape hatch+ßuÁ‚ùÁT forces `hwdec=no` at controller creation.
  /// Preloaded in [_loadPlayerDefaults]; [_createPlayerInstance] is
  /// synchronous and cannot read prefs itself.
  bool _tvosForceSoftwareDecode = false;
  ContentDisplayMatchMode _contentDisplayMatchMode =
      ContentDisplayMatchMode.systemDefault;
  int _tvosDisplayMatchToken = 0;
  Timer? _tvosDisplayMatchTimer;
  String? _lastTvosDisplayMatchSignature;

  /// Audio-output settings (AUDIO_FIDELITY_PLAN.md), preloaded in
  /// [_loadPlayerDefaults] and applied by [_configurePlayerAudio].
  bool _audioPassthroughEnabled = false;
  bool _systemAudioEffectsEnabled = false;
  bool _appleMultichannelEnabled = false;
  int _tvosRouteOutputChannels = 0;
  bool _tvosForceStereoAudio = false;
  bool _tvosLegacyAudioOutput = false;
  int _playerInstanceGeneration = 0;
  bool _playerPresentationInitialized = false;

  // Explicit Android renderers can be rejected by a vendor codec, GPU, or
  // surface implementation. The startup guard is deliberately
  // limited to the first successfully decoded item in this screen: once the
  // output has attached, later network/media failures must not be blamed on the
  // renderer. A confirmed renderer failure recreates the whole player once.
  bool _rendererValidatedForSession = false;
  bool _rendererFallbackInProgress = false;
  int _rendererStartupGuardToken = 0;
  int _rendererStartupValidationGeneration = -1;
  mk.Media? _activeOpenedMedia;
  bool _activeMediaShouldPlay = false;
  bool _activeMediaUserPaused = false;
  final math.Random _random = math.Random();
  SeriesPlaylist? _cachedSeriesPlaylist;
  List<PlaylistEntry>? _activePlaylist;
  late final bool _seriesImdbKnownAtLaunch;
  Future<void>? _episodeMetadataReady;
  late final Future<void> _playerInitializationFuture;
  int _playlistIdentityToken = 0;
  final ValueNotifier<bool> _controlsVisible = ValueNotifier<bool>(true);
  String?
  _currentStreamUrl; // Last resolved stream URL for the active playlist entry

  // Cached IMDB ID for single-file movie playback (when no playlist exists)
  String? _singleFileImdbId;
  bool _singleFileImdbFetched = false;

  // User-selected identity override for addon subtitle lookups in this item.
  String? _manualContentImdbId;
  String? _manualContentType;
  int? _manualContentSeason;
  int? _manualContentEpisode;
  String? _manualSubtitleDisplayLabel;

  // PikPak cold storage retry logic
  bool _isPikPakRetrying = false;
  int _pikPakRetryCount = 0;
  String? _pikPakRetryMessage;
  int _pikPakRetryId =
      0; // Cancellation token: increments on each new video to cancel old retries

  /// Construct playlist item data for the Fix Metadata feature
  Map<String, dynamic>? _constructPlaylistItemData() {
    // Need at least one identifier
    if ((widget.rdTorrentId == null || widget.rdTorrentId!.isEmpty) &&
        (widget.torboxTorrentId == null || widget.torboxTorrentId!.isEmpty) &&
        (widget.pikpakCollectionId == null ||
            widget.pikpakCollectionId!.isEmpty) &&
        (_activePlaylist == null || _activePlaylist!.isEmpty)) {
      return null;
    }

    final data = <String, dynamic>{};

    // Add RealDebrid torrent ID if available
    if (widget.rdTorrentId != null && widget.rdTorrentId!.isNotEmpty) {
      data['rdTorrentId'] = widget.rdTorrentId;
    }

    // Add Torbox torrent ID if available
    if (widget.torboxTorrentId != null && widget.torboxTorrentId!.isNotEmpty) {
      data['torboxTorrentId'] = widget.torboxTorrentId;
    }

    // Add PikPak collection ID if available
    if (widget.pikpakCollectionId != null &&
        widget.pikpakCollectionId!.isNotEmpty) {
      data['pikpakFileId'] = widget.pikpakCollectionId;
    }

    // Add title
    data['title'] = widget.title;

    return data.isNotEmpty ? data : null;
  }

  SeriesPlaylist? get _seriesPlaylist {
    if (_activePlaylist == null || _activePlaylist!.isEmpty) return null;
    if (_cachedSeriesPlaylist == null) {
      try {
        // Determine forceSeries: prefer viewMode, then use contentType from catalog
        bool? forceSeries = widget.viewMode?.toForceSeries();
        if (forceSeries == null && widget.contentType != null) {
          // Use catalog content type: 'series' -> force series, 'movie' -> force not series
          forceSeries = widget.contentType == 'series';
        }

        _cachedSeriesPlaylist = SeriesPlaylist.fromPlaylistEntries(
          _activePlaylist!,
          collectionTitle: widget.title, // Pass video title as fallback
          forceSeries: forceSeries,
        );
      } catch (e) {
        return null;
      }
    }
    return _cachedSeriesPlaylist;
  }

  Timer? _hideTimer;

  // ---- Television transport bar -------------------------------------------
  // The TV bar is a separate widget with real focus; these are the pieces the
  // SCREEN has to own, because raising the bar, restoring focus and deciding
  // whether auto-hide is allowed are all decisions that live with the keys.
  final FocusScopeNode _tvBarScope = FocusScopeNode(debugLabel: 'tvBar');
  final FocusNode _tvPlayPauseFocus = FocusNode(debugLabel: 'tvPlayPause');
  final FocusNode _tvProgressFocus = FocusNode(debugLabel: 'tvProgress');

  /// Focus parks here whenever the bar is down, an overlay closes or a scrub
  /// is cancelled. Without an owned root node the remote goes dead the moment
  /// the focused control is excluded from the tree.
  final FocusNode _tvRootFocus = FocusNode(debugLabel: 'tvPlayerRoot');

  /// True when there is genuinely nothing to seek: a live channel's ordinary
  /// position/duration is just the HLS rolling window. Start Over may expose
  /// its finite archive timeline explicitly. Mirrors the signal the bar uses,
  /// so the keys and the UI can never disagree.
  bool get _tvNoTimeline =>
      (_iptvZapBannerOwnsIdentity && !_iptvStartOverTimelineVisible) ||
      widget.hideSeekbar ||
      _duration <= Duration.zero;

  /// Cinema scrub, matching the native TV player: holding LEFT/RIGHT pauses
  /// playback and previews a destination that OK confirms and BACK cancels.
  /// [_tvScrubTarget] non-null means a scrub is in flight.
  Duration? _tvScrubTarget;

  /// When the last LEFT/RIGHT arrived, so a held key (fast repeats) can be
  /// told from deliberate taps without needing key-up, which the tvOS fork
  /// does not reliably deliver.
  DateTime? _tvLastArrowAt;
  bool _tvScrubWasPlaying = false;
  int _tvScrubRepeats = 0;

  /// Bumped on every transition and on dispose. A confirm carrying a stale
  /// generation is dropped, so a scrub started before a source switch can
  /// never seek the item that replaced it.
  int _tvScrubGeneration = 0;

  /// The generation in force when the current scrub began.
  int _tvScrubStartedAtGeneration = 0;

  // Text subtitles stay in MediaKit's Flutter renderer. Bitmap subtitles are
  // the narrow exception: their decoded image cues cannot enter a text widget,
  // so the selection path temporarily enables mpv's native compositor.
  bool _isSeekingWithSlider = false;
  Duration? _lastSliderSeekPos;

  // Channel badge auto-hide
  // Debrify TV lower-third (replaces the two legacy corner badges).
  bool _showDebrifyBanner = false;
  bool _debrifyBannerFloatingMounted = false;
  Timer? _debrifyBannerTimer;

  // IPTV zap banner (live channels)+ßuÁ‚ùÁT the broadcast lower third.
  //
  // It has two homes. Floating over bare video after a zap, and embedded as
  // the header of the controls dock (they share the bottom strip, so they
  // merge into one panel rather than fight for it). The channel/EPG data
  // below belongs to the playing channel and outlives either presentation.
  bool _showIptvZapBanner = false;
  // Kept in the tree until the fade-out finishes, then dropped+ßuÁ‚ùÁT this screen
  // rebuilds on every position tick, so an invisible banner would keep
  // costing layout.
  bool _iptvZapFloatingMounted = false;
  IptvChannel? _iptvZapChannel;
  EpgNowNext? _iptvZapEpg;
  bool _iptvZapEpgLoading = false;
  // The clock the banner's countdown and elapsed rule read. Ticked once a
  // second only while the banner is up, so the rule advances on screen
  // without costing a rebuild for the rest of the session.
  DateTime _iptvZapClock = DateTime.now();
  Timer? _iptvZapHideTimer;
  Timer? _iptvZapTicker;
  int _iptvZapEpgTicket = 0;

  DoubleTapRipple? _ripple;
  bool _panIgnore = false;
  int _currentIndex = 0;
  Offset? _lastTapLocal;
  bool _isManualEpisodeSelection =
      false; // Track if episode was manually selected
  bool _isAutoAdvancing = false; // Track if episode is auto-advancing
  bool _allowResumeForManualSelection =
      false; // Allow resuming for manual selections with progress
  Timer? _manualSelectionResetTimer; // Timer to reset manual selection flag
  bool _continuousShuffleEnabled = false;
  final List<int> _shuffleBag = [];
  final ShowShuffle _showShuffle = ShowShuffle();
  bool _showShuffleInProgress = false;
  int? _activeShowShuffleGeneration;
  int _showShuffleGeneration = 0;
  int _episodeNavigationGeneration = 0;

  // Channel metadata for Debrify TV flows
  String? _currentChannelName;
  int? _currentChannelNumber;
  String? _currentChannelId;

  // Channel guide state
  bool _showChannelGuide = false;
  bool _showSyncOverlay = false;
  List<ChannelEntry> _channelEntries = [];

  // IPTV channel sheet state
  bool _showIptvChannelSheet = false;
  int _currentIptvIndex = 0;

  // Independent IPTV audio source. This is deliberately separate from
  // widget.audioUrl, which is reserved for launch-time split media such as
  // YouTube. The value here is selected live from the IPTV channel directory.
  String? _externalIptvAudioUrl;
  String? _externalIptvAudioName;
  double _externalIptvAudioSyncSeconds = 0.0;

  /// Phase 0 of the IPTV resilience plan: per-tune debugPrint diagnostics,
  /// same log grammar as the native player's IptvTuneDiagnostics.kt. Inert
  /// for non-IPTV playback (nothing calls onTuneStart there).
  final IptvTuneDiagnostics _iptvDiag = IptvTuneDiagnostics();

  //+ßuÁ‚ùÁ@∫w^~)ﬁt IPTV live recovery (Phases 2/5 of the resilience plan) 5£@5£@5£@5£@∫w^~)ﬁt
  //
  // The ONE owner of live re-opens. Sources: live EOF (mpv completed),
  // stream errors, the stall detector, lifecycle rejoin. See
  // iptv_live_recovery.dart; the native player runs the same machine.

  /// Bottom-center reconnect pill text; null = hidden.
  final ValueNotifier<String?> _iptvReconnectText = ValueNotifier(null);

  /// Wall time we were backgrounded; a live channel resumed after more than
  /// 30s away re-tunes to the live edge instead of resuming stale bytes.
  DateTime? _backgroundedAt;

  late final IptvLiveRecovery _iptvLiveRecovery = IptvLiveRecovery(
    isEligible: _iptvRecoveryEligible,
    performRetune: _performIptvLiveRetune,
    onEpisodeVisible: (_) => _iptvReconnectText.value = 'ReconnectinkßuÁ‚ùÁf',
    onRecovered: () => _iptvReconnectText.value = null,
    onSurrender: (source) {
      _iptvDiag.onRecovery(source, 'surrender');
      _iptvReconnectText.value = 'Stream lost';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${_currentIptvChannel?.name ?? 'This channel'} keeps dropping",
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _iptvLiveRecovery.userRetry('snackbar-retry'),
          ),
        ),
      );
    },
  );

  /// The machine may act only on a LIVE channel with playback wanted and
  /// nobody else in charge: sleep stops outrank reconnects, a backgrounded
  /// app must stay quiet (the resume path re-arms recovery itself).
  bool _iptvRecoveryEligible() {
    if (!mounted || _screenDisposed) return false;
    final channel = _currentIptvChannel;
    if (channel == null || !channel.isLive) return false;
    if (_sleepStopLatched) return false;
    if (_sleepTimerMode == SleepTimerMode.endOfItem) return false;
    if (_pausedByLifecycle) return false;
    // An explicit user pause (including the PiP pause action) means nobody
    // asked for playback ∫w^~)ﬁt a pending retry must not restart the channel
    // (codex round 2, finding 3).
    if (_activeMediaUserPaused) return false;
    return true;
  }

  /// Re-open the current live channel with its full identity (URL + the
  /// channel's own headers+ßuÁ‚ùÁT plan finding P7). A fresh open joins the live
  /// edge. Stremio channels re-run the whole switch so their candidate
  /// ladder stays the owner of which URL plays; [IptvLiveRecovery.expectRetune]
  /// keeps the recovery episode alive across that switch's tune-start.
  void _performIptvLiveRetune(String source, int attempt) {
    final channel = _currentIptvChannel;
    if (channel == null || !channel.isLive) return;
    _cancelPendingIptvCatchup(hideFeedback: false);
    if (_iptvStartOverActive || _iptvStartOverLoading) {
      setState(() {
        _iptvStartOverActive = false;
        _iptvStartOverLoading = false;
        _iptvStartOverTimelineRequested = false;
      });
    }
    _iptvDiag.onRecovery(source, 'retune', 'attempt=$attempt');
    if (StremioIptvService.isStremioChannelUrl(channel.url)) {
      // expectRetune is consumed synchronously by the switch's entry (its
      // ticket + machine bookkeeping run before any await), so no real zap
      // can pick the flag up instead.
      _iptvLiveRecovery.expectRetune = true;
      unawaited(_switchToIptvChannel(_currentIptvIndex, quietRecovery: true));
      return;
    }
    // Direct reopen path. The ticket pins this retune to the channel the
    // machine saw: a real zap bumps it and the stale retune dissolves at
    // the checks below instead of stealing playback back (codex round 2's
    // blocker).
    final ticket = _iptvSwitchTicket;
    unawaited(() async {
      // mpv makes no promise about `stream-record` across an open()+ßuÁ‚ùÁT a
      // running capture must be stopped first, exactly like every other
      // media replacement path (codex round 2, finding 6).
      await _stopRecording(userInitiated: false);
      if (!mounted || ticket != _iptvSwitchTicket) return;
      _iptvDiag.onTuneStart(channel.name, channel.url, isLive: true);
      _iptvLiveRecovery.expectRetune = true;
      _iptvLiveRecovery.onTuneStarted();
      try {
        await _openMedia(
          mk.Media(channel.url, httpHeaders: channel.playbackHeaders),
          play: true,
          liveStream: true,
        );
      } catch (e) {
        debugPrint('Player: IPTV live retune failed to open: $e');
      }
    }());
  }

  List<IptvChannel>? _iptvChannelsOverride;
  IptvGuideContext? _iptvGuideContextOverride;
  final IptvCatchupRequestGate _iptvCatchupRequests = IptvCatchupRequestGate();
  bool _iptvStartOverActive = false;
  bool _iptvStartOverLoading = false;
  bool _iptvStartOverTimelineRequested = false;

  bool get _iptvStartOverTimelineVisible =>
      _iptvStartOverActive &&
      _iptvStartOverTimelineRequested &&
      _duration > Duration.zero;

  void _toggleIptvStartOverTimeline() {
    if (!_iptvStartOverActive) return;
    if (_duration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timeline is still loading')),
      );
      return;
    }
    final reveal = !_iptvStartOverTimelineRequested;
    setState(() => _iptvStartOverTimelineRequested = reveal);
    if (reveal && PlatformUtil.isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _iptvStartOverTimelineVisible) {
          _tvProgressFocus.requestFocus();
        }
      });
    }
    _scheduleAutoHide();
  }

  bool get _canStartOverCurrentIptv {
    final channel = _currentIptvChannel;
    final programme = _iptvZapEpg?.now;
    return channel != null &&
        channel.isLive &&
        programme != null &&
        programme.airsAt(DateTime.now()) &&
        IptvEpgService.isStartOverAvailable(channel, programme);
  }

  VoidCallback? get _iptvLiveEdgeAction =>
      _iptvStartOverActive || _canStartOverCurrentIptv
      ? () => unawaited(_toggleIptvStartOver())
      : null;

  Future<void> _toggleIptvStartOver() async {
    if (_iptvStartOverLoading) return;
    if (_iptvStartOverActive) {
      setState(() {
        _iptvStartOverActive = false;
        _iptvStartOverTimelineRequested = false;
      });
      await _switchToIptvChannel(_currentIptvIndex);
      return;
    }

    final channel = _currentIptvChannel;
    final programme = _iptvZapEpg?.now;
    if (channel == null ||
        programme == null ||
        !programme.airsAt(DateTime.now()) ||
        !IptvEpgService.isStartOverAvailable(channel, programme)) {
      return;
    }

    await _startIptvProgrammeFromBeginning(channel, programme);
  }

  Future<void> _startIptvProgrammeFromBeginning(
    IptvChannel channel,
    EpgProgramme programme,
  ) async {
    final requestTicket = _beginIptvCatchupRequest();
    final switchTicket = _iptvSwitchTicket;
    setState(() => _iptvStartOverLoading = true);
    String? url;
    try {
      url = await IptvEpgService.instance.catchupUrl(channel.url, programme);
    } catch (error) {
      debugPrint('Player: IPTV start-over lookup failed: $error');
    }
    if (!_isCurrentIptvCatchupRequest(requestTicket) ||
        switchTicket != _iptvSwitchTicket ||
        _currentIptvChannel?.url != channel.url) {
      return;
    }
    if (url == null) {
      _iptvCatchupRequests.complete(requestTicket);
      setState(() => _iptvStartOverLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start over is not available')),
      );
      return;
    }

    await _stopRecording(userInitiated: false);
    if (!_isCurrentIptvCatchupRequest(requestTicket) ||
        switchTicket != _iptvSwitchTicket ||
        _currentIptvChannel?.url != channel.url) {
      return;
    }
    _iptvDiag.onTuneStart(channel.name, url, isLive: true);
    _iptvLiveRecovery.onTuneStarted();
    try {
      await _openMedia(
        mk.Media(url, httpHeaders: channel.playbackHeaders),
        play: true,
        liveStream: true,
        beforeOpen: () {
          if (!_isCurrentIptvCatchupRequest(requestTicket) ||
              switchTicket != _iptvSwitchTicket ||
              _currentIptvChannel?.url != channel.url) {
            return false;
          }
          _iptvCatchupRequests.complete(requestTicket);
          setState(() {
            _iptvStartOverLoading = false;
            _iptvStartOverActive = true;
            _iptvStartOverTimelineRequested = false;
          });
          return true;
        },
      );
    } catch (error) {
      debugPrint('Player: IPTV start-over failed to open: $error');
      if (!mounted || switchTicket != _iptvSwitchTicket) return;
      if (!_iptvStartOverActive &&
          !_isCurrentIptvCatchupRequest(requestTicket)) {
        return;
      }
      _cancelPendingIptvCatchup(hideFeedback: false);
      if (_iptvRecoveryEligible()) {
        setState(() {
          _iptvStartOverActive = false;
          _iptvStartOverTimelineRequested = false;
        });
        await _switchToIptvChannel(_currentIptvIndex, quietRecovery: true);
      }
    }
  }

  /// The guide may replace the launch window after a source/category/search
  /// request. Playback always reads this effective list so the selected row,
  /// resume key, title, headers, and later episode navigation stay aligned.
  List<IptvChannel>? get _effectiveIptvChannels =>
      _iptvChannelsOverride ?? widget.iptvChannels;

  /// Live IPTV presents its identity in the bottom zap banner, so the corner
  /// title/channel badges stand down: they said the same thing twice, and the
  /// right-hand one was painted from launch state a zap never refreshed.
  bool get _iptvZapBannerOwnsIdentity => _currentIptvChannel?.isLive == true;

  /// The in-player IPTV guide look, read once at launch (see
  /// [PlayerGuideStyle]). Classic keeps every legacy paint path verbatim.
  PlayerGuideStyle _playerGuideStyle = PlayerGuideStyle.classic;

  // Player dock prefs, read once at launch alongside the guide style.
  PlayerDockStyle _dockStyle = PlayerDockStyle.classic;
  PlayerDockPalette _dockPalette = PlayerDockPalette.ultraviolet;
  PlayerDockSize _dockSize = PlayerDockSize.auto;

  /// The styled dock's measured height. Six host behaviours below assume a
  /// FIXED dock height (the skip button's 160/28, four 72lp gesture bands and
  /// the PikPak overlay's 80); under `two_tier` the dock is variable, so they
  /// read this instead. Seeded to the full viewport height so the very first
  /// frame can only over-protect ∫w^~)ﬁt under-protection is the actual bug.
  /// `classic` never publishes and every consumer keeps its literal.
  final ValueNotifier<double> _dockExtent = ValueNotifier<double>(0);

  /// Measured height of the IPTV info panel, which the dock's vertical budget
  /// must reserve. Starts at the conservative bound and is corrected by the
  /// panel's own reporter on the next frame.
  double _infoPanelHeight = DockLayoutInput.kInfoPanelBound;

  /// 0..1, mirrored for the dock's volume control. mpv takes 0..100.
  double _dockVolume = 1.0;

  /// The panel's STRUCTURAL signature+ßuÁ‚ùÁT which rows exist, not what they say.
  /// Every row is bounded to one line, so content cannot change the height;
  /// only presence can. Recomputed each build, and a change resets the cached
  /// height so a taller panel can never be under-reserved.
  ///
  /// Deliberately excludes `_iptvZapClock`: that ticks every second and would
  /// otherwise reset the cache continuously.
  String get _infoPanelSignature {
    final channel = _iptvZapChannel;
    if (channel == null || !_iptvZapBannerOwnsIdentity) {
      // Debrify TV's flush identity row: presence of plate/title is the
      // whole structure (single bounded row).
      if (_debrifyTvOwnsIdentity) {
        final name = (_currentChannelName ?? widget.channelName)?.trim();
        return [
          'dtv',
          (name?.isNotEmpty ?? false) || _currentChannelNumber != null
              ? 'p'
              : '',
          widget.showVideoTitle ? 't' : '',
        ].join('|');
      }
      return '-';
    }
    final epg = _iptvZapEpg;
    return [
      _playerGuideStyle.name,
      channel.channelNumber != null ? 'n' : '',
      (channel.group?.isNotEmpty ?? false) ? 'g' : '',
      channel.logoUrl != null ? 'l' : '',
      epg?.now != null ? 'w' : '',
      epg?.next != null ? 'x' : '',
      _iptvZapEpgLoading ? 'L' : '',
      _recordingActiveNow ? 'r' : '',
    ].join('|');
  }

  String _lastInfoPanelSignature = '';

  /// Bumped on a panel STRUCTURE change. Separate from the dock generation:
  /// resetting `_infoPanelHeight` alone was not enough ∫w^~)ﬁt if the newly measured
  /// height happened to equal the reporter's cached value it would suppress
  /// the callback and the budget would stay stuck at the 200lp bound.
  int _infoPanelGeneration = 0;

  /// Bumped whenever the dock's geometry inputs change. A measurement
  /// callback captures this and is discarded if it comes back stale, so a
  /// post-frame report from the previous layout cannot overwrite a newer one.
  int _dockGeometryGeneration = 0;

  /// Everything that can change the dock's height without the dock itself
  /// changing: the viewport, the safe-area insets, the text scaler, the
  /// chosen style and size, and the two flags that add or remove whole rows.
  String _dockGeometrySignature(MediaQueryData media) => [
    media.size.width.round(),
    media.size.height.round(),
    media.padding.top.round(),
    media.padding.bottom.round(),
    media.textScaler.scale(100).round(),
    _dockStyle.name,
    _dockSize.name,
    widget.hideOptions,
    widget.hideSeekbar,
  ].join('|');

  String _lastDockGeometrySignature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _iosPipSession = PlayerPipSession.of(context);
    _refreshDockGeometry();
  }

  /// Drops the cached dock geometry whenever anything that can change the
  /// dock's height changes.
  void _refreshDockGeometry() {
    // Rotation, window resize, split-screen, a safe-area change or a font-size
    // change all land here. Any of them can make the cached extent wrong, and
    // a stale extent means a tap near the bottom is judged against the wrong
    // band"È›y¯ßy‘ so drop back to the legacy constants until a fresh measurement
    // arrives, rather than trusting the old number for a frame.
    final signature = _dockGeometrySignature(MediaQuery.of(context));
    if (signature == _lastDockGeometrySignature) return;
    _lastDockGeometrySignature = signature;
    _dockGeometryGeneration++;
    _dockExtent.value = 0;
    _infoPanelGeneration++;
    _infoPanelHeight = DockLayoutInput.kInfoPanelBound;
    _lastInfoPanelSignature = '';
  }

  /// Reserved panel height for this build. Resets to the bound (or 0 when no
  /// panel is mounted) the moment the structure changes.
  double get _reservedInfoPanelHeight {
    final signature = _infoPanelSignature;
    if (signature != _lastInfoPanelSignature) {
      _lastInfoPanelSignature = signature;
      _infoPanelGeneration++;
      _infoPanelHeight = signature == '-' ? 0 : DockLayoutInput.kInfoPanelBound;
    }
    return _infoPanelHeight;
  }

  /// Tokens for [_playerGuideStyle], derived once with it"È›y¯ßy‘ null for classic.
  IptvStyleTokens? _playerGuideTokens;

  // 5£@Å%AQXÅ…ïçΩ…ë•πúÄ°±•âµ¡ÿÅÅÕ—…ïÖ¥µ…ïçΩ…ëÄ§ãßuÁ‚ùÁnù◊üäwù ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç (ÄÄºººÅQ…’îÅΩπçîÅ—°îÅ¡±ÖÂï»Å•ÃÅçΩπô•…µïêÅ—ºÅ…’∏ÅΩ∏ÅÑÅπÖ—•ŸîÄ°±•âµ¡ÿ§ÅâÖç≠ïπêÆù◊üäwùP(ÄÄºººÅ…ïçΩ…ë•πúÅ•ÃÅ’πÖŸÖ•±Öâ±îÅΩ∏Å—°îÅ›ïàÅâÖç≠ïπê∏(ÄÅâΩΩ∞Å}…ïçΩ…ë•πùM’¡¡Ω…—ïêÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}•ÕIïçΩ…ë•πúÄÙÅôÖ±ÕîÏ((ÄÄºººÅ•±ïÕÂÕ—ï¥Å¡Ö—†Å±•âµ¡ÿÅ•ÃÅ›…•—•πúÅ—°îÅÖç—•ŸîÅ…ïçΩ…ë•πúÅ—º∏(ÄÅM—…•πú¸Å}…ïçΩ…ë•πùQïµ¡AÖ—†Ï((ÄÄºººÅ]Ö—ç°ïÃÅôΩ»Å—°îÅÖ¡¿Å±ïÖŸ•πúÅ—°îÅôΩ…ïù…Ω’πê∞ÅΩ∏Åâï°Ö±òÅΩòÅ—›ºÅ©ΩâÃ∏(ÄÄººº(ÄÄºººÅÅQÅ…ïçΩ…ë•πúÅ°ï…îÅ•ÃÅâÖç≠ïêÅâ‰ÅπΩ—°•πúÅâ’–Å—°•ÃÅ›•ëùï–ÇÈ›y¯ßy–Åπº(ÄÄºººÅôΩ…ïù…Ω’πêÅÕï…Ÿ•çîÇÈ›y¯ßy–ÅÕºÅΩπçîÅ—°îÅÖ¡¿Å•ÃÅâÖç≠ù…Ω’πëïêÅ—°îÅ¡…ΩçïÕÃÅçÖ∏Åâî(ÄÄºººÅ≠•±±ïêÅ›•—†Å—°îÅô•±îÅπïŸï»Å¡’â±•Õ°ïê∏Å•π•Õ°•πúÅÖ–Å—°Ö–ÅµΩµïπ–Åµ•……Ω…Ã(ÄÄºººÅ›°Ö–Å—°îÅπÖ—•ŸîÅQXÅ¡±ÖÂï»ÅëΩïÃÅ•∏ÅΩπM—Ω¿∞ÅÖπêÅçΩÕ—ÃÅπΩ—°•πúËÅÑ(ÄÄºººÅâÖç≠ù…Ω’πëïêÅ¡±ÖÂï»Å•Õ∏ù–Å…ïÖë•πúÅâÂ—ïÃ∏Å9%9Å…ïçΩ…ë•πùÃÅ•ùπΩ…îÅÖ±∞ÅΩò(ÄÄºººÅ—°•ÃãßuÁ‚ùÁPÅÕ’…Ÿ•Ÿ•πúÅâÖç≠ù…Ω’πë•πúÅ•ÃÅ—°ï•»Å›°Ω±îÅ…ïÖÕΩ∏Å—ºÅï·•Õ–∏(ÄÄººº(ÄÄºººÅA1e	,Å¡Ö’ÕïÃÅÖ–Å—°îÅÕÖµîÅµΩµïπ–∏ÅQ°ï…îÅ•ÃÅπºÅâÖç≠ù…Ω’πêµÖ’ë•ºÅÕï…Ÿ•çî(ÄÄºººÅΩ»Åµïë•ÑÅπΩ—•ô•çÖ—•Ω∏∞ÅÕºÄâ≠ïï¿Å¡±ÖÂ•πúàÅÖô—ï»Å!ΩµîΩ¡Ω›ï»Å…ïÖ±±‰ÅµïÖπ–(ÄÄºººÅµ¡ÿÅëïçΩë•πúÅŸ•ëïºÅ•π—ºÅÖ∏Å•πŸ•Õ•â±îÅÕ’…ôÖçîÆù◊üäwùPÅôΩ»Å°Ω’…Ã∞ÅΩ∏ÅëïŸ•çïÃ(ÄÄºººÅ›°ï…îÅ—°îÅ’Õï»Åù…Öπ—ïêÅ—°îÅâÖ——ï…‰µΩ¡—•µ•ÈÖ—•Ω∏Åï·ïµ¡—•Ω∏Å…ïçΩ…ë•πúÅÖÕ≠Ã(ÄÄºººÅôΩ»∏ÅA•ç—’…îµ•∏µA•ç—’…îÅ•ÃÅ’πÖôôïç—ïêÅôΩ»Å—°îÅÕÖµîÅ…ïÖÕΩ∏Å…ïçΩ…ë•πúÅ•ÃË(ÄÄºººÅÑÅŸ•Õ•â±îÅA•@ÅÖç—•Ÿ•—‰Å…ï¡Ω…—ÃÅÅ•πÖç—•ŸïÄ∞ÅπïŸï»ÅÅ¡Ö’ÕïëÄ∏(ÄÅ¡¡1•ôïçÂç±ï1•Õ—ïπï»¸Å}±•ôïçÂç±îÏ((ÄÄºººÅQ…’îÅ›°•±îÅ¡±ÖÂâÖç¨Å•ÃÅ¡Ö’ÕïêÅâïçÖ’ÕîÅ—°îÅA@Å±ïô–Å—°îÅôΩ…ïù…Ω’πê∞ÅπΩ–(ÄÄºººÅâïçÖ’ÕîÅ—°îÅ’Õï»ÅÖÕ≠ïêãßuÁ‚ùÁPÅ—°îÅô±ÖúÅ—°Ö–ÅÖ’—°Ω…•ÈïÃÅ—°îÅµÖ—ç°•πú(ÄÄºººÅÖ’—ºµ…ïÕ’µîÅΩ∏Å…ï—’…∏∞ÅÕºÅçΩµ•πúÅâÖç¨Å—ºÅ—°îÅ¡±ÖÂï»Å±ΩΩ≠ÃÅï·Öç—±‰Å±•≠î(ÄÄºººÅ•–ÅÖ±›ÖÂÃÅ°ÖÃÄ°¡±ÖÂ•πú§∏ÅÅ’Õï»ùÃÅΩ›∏Å¡Ö’ÕîÅπïŸï»ÅÕï—ÃÅ•–ÅÖπêÅ•ÃÅπïŸï»(ÄÄºººÅ…ïÕ’µïêÅΩŸï»∏(ÄÅâΩΩ∞Å}¡Ö’Õïë	Â1•ôïçÂç±îÄÙÅôÖ±ÕîÏ((ÄÄºººÅQ°îÅ…ïçΩ…ë•πúÅ9%9ùÃÅçÖ¡—’…îÅΩòÅ—°îÅUII9Q1dÅA1e%9Å±•ŸîÅç°Öππï∞(ÄÄºººÄ°1•ŸïIïçΩ…ë•πùMï…Ÿ•çîÅ—ÖÕ¨Å•ê§∞ÅΩ»Åπ’±∞∏Å%πëï¡ïπëïπ–ÅΩòÅ—°îÅ—ïîùÃ(ÄÄºººÅm}•ÕIïçΩ…ë•πùtËÅÖ∏Åïπù•πîÅçÖ¡—’…îÅâï±ΩπùÃÅ—ºÅ—°îÅÕï…Ÿ•çî∞ÅπΩ–Å—°•Ã(ÄÄºººÅ›•ëùï–∞ÅÕºÅπΩ—°•πúÅ•∏Å—°•ÃÅÕç…ïï∏ùÃÅ±•ôïçÂç±îÅµÖ‰ÅÕ—Ω¿Å•–Å•µ¡±•ç•—±‰∏(ÄÅM—…•πú¸Å}ïπù•πïQÖÕ≠%êÏ((ÄÄºººÅπù•πîµŸÃµ—ïîÅô±ÖúÄ°Mï——•πùÃÆù◊üäwùHÅ%AQXÇÈ›y¯ßyÿÅIïçΩ…ë•πú§∞Å±ΩÖëïêÅÖ–Å¡±ÖÂï»ÅÕï—’¿∏(ÄÅâΩΩ∞Å}ïπù•πï±Öù=∏ÄÙÅôÖ±ÕîÏ((ÄÄºººÅM’¡ï…ÕïëïÃÅÕ—Ö±îÅïπù•πîµÕ—Ö—îÅ…ïô…ïÕ°ïÃÄ°ÈÖ¿Åë’…•πúÅÑÅ≈’ï…‰Å…Ω’πêµ—…•¿§∏(ÄÅ•π–Å}ïπù•πïIïô…ïÕ°Q•ç≠ï–ÄÙÄ¿Ï((ÄÄºººÅQÖ¿ÅΩ∏Åµ¡ÿùÃÅ±ΩúÅÕ—…ïÖ¥Å›°•±îÅÑÅQÅ…ïçΩ…ë•πúÅ•ÃÅÖ…µïê∏ÅÕ—…ïÖ¥µ…ïçΩ…ê(ÄÄºººÅôÖ•±•πúÅ%9M%Åµ¡ÿÄ°•—ÃÅΩ›∏ÅôΩ¡ï∏Å…ïô’Õïê∞Åëïµ’·ï»Å—°Ö–ÅçÖ∏ù–Åë’µ¿§Å•Ã(ÄÄºººÅçΩµ¡±ï—ï±‰Å•πŸ•Õ•â±îÅΩ—°ï…›•ÕîÆù◊üäwùPÅ—°îÅ¡…Ω¡ï…—‰ÅÕï–ÅÕ’ççïïëÃ∞ÅÖ…–ÅÕïïÃÅπº(ÄÄºººÅï……Ω»∞ÅÖπêÅπºÅô•±îÅïŸï»ÅÖ¡¡ïÖ…Ã∏Å=π±‰Åï……Ω…ÃÅÕ’…ôÖçîÅâ‰ÅëïôÖ’±–Ä°—°î(ÄÄºººÅ¡±ÖÂï»ÅçΩπô•úÅ…ï≈’ïÕ—ÃÅï……Ω»µ±ïŸï∞Å±ΩùÃ§∞Å›°•ç†Å•ÃÅï·Öç—±‰Å—°îÅâÖπê(ÄÄºººÅÕ—…ïÖ¥µ…ïçΩ…êÅôÖ•±’…ïÃÅ±ΩúÅ•∏∏(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏Òµ¨πA±ÖÂï…1Ωú¯¸Å}…ïçΩ…ë1ΩùM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏Òµ¨πA±ÖÂï…1Ωú¯¸Å}Õ’â—•—±ï•ÖùπΩÕ—•ç1ΩùM’àÏ(ÄÅ•π–Å}Õ’â—•—±ï•ÖùπΩÕ—•çïπï…Ö—•Ω∏ÄÙÄ¿Ï(ÄÅ}M’â—•—±ï¡¡±Â——ïµ¡–¸Å}Öç—•ŸïM’â—•—±ï¡¡±Â——ïµ¡–Ï(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒM—…•πú¸¯Å}Õ’â—•—±ïMï±ïç—•ΩπΩ……ïç—•Ω∏ÄÙÅYÖ±’ï9Ω—•ô•ï»†(ÄÄÄÅπ’±∞∞(ÄÄ§Ï((ÄÄºººÅIï¡Ö•π—ÃÅ—°îÅIïçΩ…êÅâ’——Ω∏Å›°ï∏ÅÑÅëïÕ≠—Ω¿ÅçÖ¡—’…îÅÕ—Ö…—ÃÅΩ»ÅïπëÃÅâï°•πê(ÄÄºººÅ—°•ÃÅÕç…ïï∏ùÃÅâÖç¨Æù◊üäwùPÅÑÅÕç°ïë’±ïêÅΩπîÅô•…•πúÅΩ∏Å—°îÅç°Öππï∞Åâï•πúÅ›Ö—ç°ïê∞(ÄÄºººÅΩ»ÅÖπ‰ÅçÖ¡—’…îÅÕï±òµïπë•πúÄ°Õ—…ïÖ¥Åë…Ω¿∞ÄŸ†ÅçÖ¿§∏ÅMÖµ¡±•πúÅΩ∏Å…ïâ’•±ê(ÄÄºººÅÖ±ΩπîÅ›Ω’±êÅ±ïÖŸîÅ—°îÅâ’——Ω∏Åç±Ö•µ•πúÅ—ºÅ…ïçΩ…êÅÕΩµï—°•πúÅÖ±…ïÖë‰ÅëïÖê∏(ÄÄººº(ÄÄºººÅQ°•ÃÅÕç…ïï∏Åëï±•âï…Ö—ï±‰Å≠ïï¡ÃÅ9<Å°Öπë±îÅΩ∏ÅÑÅëïÕ≠—Ω¿ÅçÖ¡—’…î∏ÅïÕ≠—Ω¿Å°ÖÃ(ÄÄºººÅπºÅ—ïîÄ°µ¡ÿÅçÖ∏ù–Åµ’‡ÅΩ∏Åµïë•Ö}≠•–ùÃÅ±•âÃ§ÅÖπêÅπºÅπë…Ω•êÅïπù•πîÇÈ›y¯ßy–Å—°îÅ…Ö‹(ÄÄºººÅ!QQ@ÅçΩ¡‰Å•ÃÅ—°îÅΩπ±‰Å…ïçΩ…ëï»Å—°ï…îÆù◊üäwùPÅâ’–Å±•≠îÅ—°îÅïπù•πîÅ•–Åâï±ΩπùÃÅ—º(ÄÄºººÅ—°îÅMIY%∞ÅÕºÅç±ΩÕ•πúÅ—°îÅ¡±ÖÂï»Å±ïÖŸïÃÅ•–Å…’ππ•πúÅÖπêÅπΩ—°•πúÅ°ï…îÅµÖ‰(ÄÄºººÅÕ—Ω¿Å•–Å•µ¡±•ç•—±‰∏Åm}ëïÕ≠—Ω¡Ö¡—’…ïΩ…’……ïπ—tÅÖÕ≠ÃÅ—°îÅÕï…Ÿ•çîÅ•πÕ—ïÖê∞(ÄÄºººÅ›°•ç†Å•ÃÅÖ±ÕºÅ›°Ö–ÅµÖ≠ïÃÅÑÅM!U1HµÕ—Ö…—ïêÅçÖ¡—’…îÅÕ—Ω¡¡Öâ±îÅô…Ω¥Å—°•Ã(ÄÄºººÅÕÖµîÅâ’——Ω∏∏(ÄÅYΩ•ëÖ±±âÖç¨¸Å}ëïÕ≠—Ω¡IïçΩ…ë•πùIïŸ•Õ•Ωπ1•Õ—ïπï»Ï((ÄÄºººÅ	’µ¡ïêÅ›°ïπïŸï»ÅÑÅÕ—Ω¿∞ÅÑÅç°Öππï∞Åç°ÖπùîÅΩ»ÅÑÅ—ïÖ…ëΩ›∏ÅÕ’¡ï…ÕïëïÃÅÖ∏(ÄÄºººÅ•∏µô±•ù°–Åm}Õ—Ö…—IïçΩ…ë•πùt∏ÅQ°Ö–ÅÕ—Ö…–ÅëΩïÃÅÖÕÂπåÅ›Ω…¨Ä°Õ—Ω…ÖùîÅ±ΩΩ≠’¿∞(ÄÄºººÅµ≠ë•»§Åë’…•πúÅ›°•ç†ÅÅ}•ÕIïçΩ…ë•πùÄÅ•ÃÅÕ—•±∞ÅôÖ±Õî∞ÅÕºÅ—°îÅÕ—Ω¿µ•ò¥(ÄÄºººÅ…ïçΩ…ë•πúÅç°ïç≠ÃÅï±Õï›°ï…îÅçÖππΩ–ÅÕïîÅ•–ÏÅ›•—°Ω’–Å—°•ÃÅ—Ω≠ï∏Å—°îÅÖ›Ö•—Ã(ÄÄºººÅçΩ’±êÅ…ïÕ’µîÅÖπêÅÖ…¥Å±•âµ¡ÿÅΩ∏Å—°îÅ9\Åç°Öππï∞Å’πëï»Å—°îÅ=1Åç°Öππï∞ùÃ(ÄÄºººÅô•±ïπÖµî∞ÅΩ»ÅÖ…¥ÅÖ∏ÅÖ±…ïÖë‰µë•Õ¡ΩÕïêÅ¡±ÖÂï»ÅÖπêÅ±ïÖŸîÅ—°îÅô•±îÅ’π—…Öç≠ïê∏(ÄÅ•π–Å}…ïçΩ…ë•πùM—Ö…—ï∏ÄÙÄ¿Ï((ÄÄºººÅIïçΩ…êÅ•ÃÅΩôôï…ïêÅΩπ±‰ÅôΩ»Å±•ŸîÅ%AQXÅΩ∏ÅÑÅ±•âµ¡ÿÅâÖç≠ïπê∏(ÄÅâΩΩ∞Åùï–Å}çÖπIïçΩ…êÄÙ¯Å}…ïçΩ…ë•πùM’¡¡Ω…—ïêÄòòÅ}•¡—ŸiÖ¡	Öππï…=›πÕ%ëïπ—•—‰Ï((ÄÄºººÅ	’µ¡ïêÅ›°ïπïŸï»Å—°îÅù’•ëîÅ…ï¡Ω…—ÃÅÑÅâ…Ω›ÕîÅ—°îÅ’Õï»Åë…ΩŸîÄ°ÑÅçÖ—ïùΩ…‰(ÄÄºººÅ¡•ç¨∞ÅÑÅÕïÖ…ç†∞ÅÑÅÕΩ’…çîÅç°Öπùî§∏Å∏Å•∏µô±•ù°–Å…îµÖπç°Ω»Å—°Ö–Å¡…ïëÖ—ïÃ(ÄÄºººÅ—°îÅç°ÖπùîÅµ’Õ–ÅπΩ–Å±ÖπêËÅ•–Å›Ω’±êÅ…ïÕï–Å—°îÅ…•πúÅÖπêÅ—°îÅ¡ï…Õ•Õ—ïê(ÄÄºººÅçÖ—ïùΩ…‰∞ÅÕ•±ïπ—±‰Å’πëΩ•πúÅ›°Ö–Å—°îÅ’Õï»Å©’Õ–ÅÖÕ≠ïêÅôΩ»∏(ÄÅ•π–Å}•¡—Ÿ’•ëïΩπ—ï·—ïπï…Ö—•Ω∏ÄÙÄ¿Ï((ÄÅŸΩ•êÅ}¡ï…Õ•Õ—%¡—Ÿ’•ëïΩπ—ï·–°%¡—Ÿ’•ëïΩπ—ï·–ÅçΩπ—ï·–§ÅÏ(ÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—Ÿ’•ëïΩπ—ï·—ïπï…Ö—•Ω∏¨¨Ï(ÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëîÄÙÅçΩπ—ï·–§Ï(ÄÅÙ((ÄÄºººÅ5Ö≠îÅ—°îÅù’•ëîùÃÅÕï±ïç—ïêÅçÖ—ïùΩ…‰ÅôΩ±±Ω‹Å—°îÅ¡±ÖÂ•πúÅç°Öππï∞∏(ÄÄººº(ÄÄºººÅQ°îÅπÖ—•ŸîÅ¡±ÖÂï»Å…îµÖπç°Ω…ÃÅ•—ÃÅâ…Ω›Õ•πúÅçΩπ—ï·–Å—ºÅ—°îÅ¡±ÖÂ•πú(ÄÄºººÅç°Öππï∞ùÃÅù…Ω’¿ÅΩ∏ÅïŸï…‰Å—’πîÅÖπêÅïŸï…‰Å¡•ç¨∏Å!ï…îÅ—°îÅçÖ—ïùΩ…‰ÅΩπ±‰(ÄÄºººÅïŸï»ÅµΩŸïêÅ›°ï∏Å—°îÅ’Õï»Åç°ΩÕîÅΩπî∞ÅÕºÅÖô—ï»ÅÈÖ¡¡•πúÆù◊üäwùPÅΩ»ÅÖô—ï»Å¡•ç≠•πú(ÄÄºººÅÑÅç°Öππï∞Åô…Ω¥ÅÑÅë•ôôï…ïπ–ÅçÖ—ïùΩ…‰ÇÈ›y¯ßy–Å…ïΩ¡ïπ•πúÅ—°îÅù’•ëîÅÕ°Ω›ïêÅÑ(ÄÄºººÅçÖ—ïùΩ…‰Å—°Ö–ÅπºÅ±Ωπùï»ÅçΩπ—Ö•πïêÅ›°Ö–Å›ÖÃÅΩ∏ÅÕç…ïï∏∏(ÄÅŸΩ•êÅ}Öπç°Ω…%¡—Ÿ’•ëïÖ—ïùΩ…‰°%¡—Ÿ°Öππï∞Åç°Öππï∞∞ÅÌ=â©ïç–¸ÅçÖ—ïùΩ…•ïÕÙ§ÅÏ(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÄÖç°Öππï∞π•Õ1•Ÿî§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åù…Ω’¿ÄÙÅç°Öππï∞πù…Ω’¿¸π—…•¥†§Ï(ÄÄÄÅ}Ö¡¡±Â%¡—Ÿ’•ëïÖ—ïùΩ…‰†(ÄÄÄÄÄÄ°ù…Ω’¿ÄÙÙÅπ’±∞ÅÒÅù…Ω’¿π•Õµ¡—‰§Ä¸Åπ’±∞ÄËÅù…Ω’¿∞(ÄÄÄÄÄÅçÖ—ïùΩ…•ïÃÅ•ÃÅ1•Õ–Ä¸ÅçÖ—ïùΩ…•ïÃπ›°ï…ïQÂ¡îÒM—…•πú¯†§π—Ω1•Õ–†§ÄËÅπ’±∞∞(ÄÄÄÄ§Ï(ÄÅÙ((ÄÄºººÅAΩ•π–Å—°îÅù’•ëîÅÖ–ÅmçÖ—ïùΩ…ÂtÅŸï…âÖ—•¥∞Å›•—°Ω’–Å•πôï……•πúÅ•–Åô…Ω¥ÅÑ(ÄÄºººÅç°Öππï∞∏ÅÅÈÖ¿Å—°Ö–Åç…ΩÕÕïêÅÑÅçÖ—ïùΩ…‰ÅâΩ’πëÖ…‰Å≠πΩ›ÃÅ—°îÅçÖ—ïùΩ…‰Å•–(ÄÄºººÅ±ÖπëïêÅ•∏Åô…Ω¥Å—°îÅ…ïÕ¡ΩπÕîÇÈ›y¯ßy–Å•πç±’ë•πúÅ—°îÅπ’±∞Å—°îÄâ±∞àΩ’πçÖ—ïùΩ…•Èïê(ÄÄºººÅ›…Ö¿Å±ÖπëÃÅΩ∏∞Å›°•ç†ÅπºÅÕ•πù±îÅç°Öππï∞ùÃÅù…Ω’¿ÅçÖ∏Åï·¡…ïÕÃ∏(ÄÄººº(ÄÄºººÅï±•âï…Ö—ï±‰ÅëΩïÃÅ9=PÅâ’µ¿Åm}•¡—Ÿ’•ëïΩπ—ï·—ïπï…Ö—•ΩπtËÅ—°Ö–ÅçΩ’π—ï»(ÄÄºººÅµïÖπÃÄâ—°îÅ’Õï»Åâ…Ω›Õïêà∞ÅÖπêÅÖ∏Å•∏µô±•ù°–ÅÈÖ¿Å¡…ïôï—ç†Å…ïÖë•πúÅ•–Åµ’Õ–(ÄÄºººÅπΩ–ÅâîÅ•πŸÖ±•ëÖ—ïêÅâ‰Å—°îÅÈÖ¿ùÃÅΩ›∏ÅâΩΩ≠≠ïï¡•πú∏(ÄÅŸΩ•êÅ}Ö¡¡±Â%¡—Ÿ’•ëïÖ—ïùΩ…‰°M—…•πú¸ÅçÖ—ïùΩ…‰∞Å1•Õ–ÒM—…•πú¯¸ÅçÖ—ïùΩ…•ïÃ§ÅÏ(ÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç’……ïπ–ÄÙÅ}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëîÏ(ÄÄÄÅô•πÖ∞Åπï·—Ö—ïùΩ…•ïÃÄÙ(ÄÄÄÄÄÄÄÅçÖ—ïùΩ…•ïÃÄ¸¸(ÄÄÄÄÄÄÄÄ°ç’……ïπ–¸πçÖ—ïùΩ…•ïÃÄ¸¸Å›•ëùï–π•¡—ŸÖ—ïùΩ…•ïÃÄ¸¸ÅçΩπÕ–ÄÒM—…•πú˘mt§Ï(ÄÄÄÅ•òÄ°ç’……ïπ–ÄÑÙÅπ’±∞Äòò(ÄÄÄÄÄÄÄÅç’……ïπ–πÕï±ïç—ïëÖ—ïùΩ…‰ÄÙÙÅçÖ—ïùΩ…‰Äòò(ÄÄÄÄÄÄÄÅ±•Õ—≈’Ö±Ã°πï·—Ö—ïùΩ…•ïÃ∞Åç’……ïπ–πçÖ—ïùΩ…•ïÃ§§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëîÄÙÅ%¡—Ÿ’•ëïΩπ—ï·–†(ÄÄÄÄÄÄÄÅçÖ—ïùΩ…•ïÃËÅπï·—Ö—ïùΩ…•ïÃ∞(ÄÄÄÄÄÄÄÅÕΩ’…çï%êËÅç’……ïπ–¸πÕΩ’…çï%êÄ¸¸Å›•ëùï–π•¡—ŸMΩ’…çï%ê∞(ÄÄÄÄÄÄÄÄººÅMÖµîÅôÖ±±âÖç¨Å—°îÅÕ°ïï–ÅÖ¡¡±•ïÃÅ—ºÅÑÅπÖµï±ïÕÃÅÕΩ’…çî∏(ÄÄÄÄÄÄÄÅÕΩ’…çï9ÖµîËÅç’……ïπ–¸πÕΩ’…çï9ÖµîÄ¸¸Å›•ëùï–π•¡—ŸMΩ’…çï9ÖµîÄ¸¸Äù%AQXú∞(ÄÄÄÄÄÄÄÅÕï±ïç—ïëÖ—ïùΩ…‰ËÅçÖ—ïùΩ…‰∞(ÄÄÄÄÄÄÄÅçΩπ—ïπ—QÂ¡îËÅç’……ïπ–¸πçΩπ—ïπ—QÂ¡îÄ¸¸Å›•ëùï–π•¡—ŸΩπ—ïπ—QÂ¡îÄ¸¸Äù±•Ÿîú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÅŸΩ•êÅ}çÖπçï±Aïπë•πù%¡—ŸÖ—ç°’¿°ÌâΩΩ∞Å°•ëïïïëâÖç¨ÄÙÅ—…’ïÙ§ÅÏ(ÄÄÄÅô•πÖ∞ÅçÖπçï±ïêÄÙÅ}•¡—ŸÖ—ç°’¡Iï≈’ïÕ—ÃπçÖπçï∞†§Ï(ÄÄÄÅ•òÄ°}•¡—ŸM—Ö…—=Ÿï…1ΩÖë•πúÄòòÅµΩ’π—ïê§ÅÏ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}•¡—ŸM—Ö…—=Ÿï…1ΩÖë•πúÄÙÅôÖ±Õî§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ°çÖπçï±ïêÄòòÅ°•ëïïïëâÖç¨ÄòòÅµΩ’π—ïê§ÅÏ(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πµÖÂâï=ò°çΩπ—ï·–§¸π°•ëï’……ïπ—MπÖç≠	Ö»†§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÅ•π–Å}âïù•π%¡—ŸÖ—ç°’¡Iï≈’ïÕ–†§ÅÏ(ÄÄÄÅ}çÖπçï±Aïπë•πù%¡—ŸÖ—ç°’¿†§Ï(ÄÄÄÅ…ï—’…∏Å}•¡—ŸÖ—ç°’¡Iï≈’ïÕ—Ãπâïù•∏†§Ï(ÄÅÙ((ÄÅâΩΩ∞Å}•Õ’……ïπ—%¡—ŸÖ—ç°’¡Iï≈’ïÕ–°•π–Å—•ç≠ï–§ÄÙ¯(ÄÄÄÄÄÅµΩ’π—ïêÄòòÅ}•¡—ŸÖ—ç°’¡Iï≈’ïÕ—Ãπ•Õ’……ïπ–°—•ç≠ï–§Ï((ÄÄººÅM—…ïµ•ºÅÕΩ’…çîÅÕ°ïï–ÅÕ—Ö—î(ÄÅâΩΩ∞Å}Õ°Ω›MΩ’…çïM°ïï–ÄÙÅôÖ±ÕîÏ(ÄÅ•π–Å}ç’……ïπ—MΩ’…çï%πëï‡ÄÙÄ¿Ï(ÄÅ1•Õ–ÒA±ÖÂ±•Õ—π—…‰¯¸Å}¡ïπë•πùMΩ’…çïA±ÖÂ±•Õ–Ï(ÄÄººÅ=Ÿï……•ëïÃÅôΩ»ÅÕΩ’…çïÃÅÖô—ï»ÅM—…ïµ•ºÅQXÅç°Öππï∞ÅÕ›•—ç†(ÄÅ1•Õ–ÒQΩ……ïπ–¯¸Å}Õ—…ïµ•ΩMΩ’…çïÕ=Ÿï……•ëîÏ(ÄÅ’—’…îÒM—…•πú¸¯Å’πç—•Ω∏°QΩ……ïπ–§¸Å}…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çï=Ÿï……•ëîÏ(ÄÄººÅMΩ’…çïÃÅù…Ω›∏Åâ‰Å—°îÅÕ°ïï–ùÃÄâ1ΩÖêÅµΩ…îàÄ°Ö¡¡ïπêµΩπ±‰Åµï…ùîÅΩŸï»(ÄÄººÅ›•ëùï–πÕ—…ïµ•ΩMΩ’…çïÃÏÅ—°îÅôï—ç°ï»ùÃÅô±ÖùÃÅ—…Öç¨Å›°Ö–Å›ÖÃÅÕïÖ…ç°ïê§(ÄÅ1•Õ–ÒQΩ……ïπ–¯¸Å}Ö’ùµïπ—ïëMΩ’…çïÃÏ((ÄÄººÅUπ•ô•ïêÅ¡±ÖÂï»Åµïπ‘Ä°M¡Ω—±•ù°–Å¡Öπï∞§ÅÕ—Ö—î∏ÅQ°îÅÕ’â—•—±îµ•ëïπ—•—‰(ÄÄººÅçΩπ—ï·–Å•ÃÅçÖ¡—’…ïêÅÖ–ÅΩ¡ï∏Å—•µî∞Åï·Öç—±‰Å±•≠îÅ—°îÅΩ±êÅ—…Öç≠ÃÅÕ°ïï–(ÄÄººÅçÖ¡—’…ïêÅ•–Å•∏Å•—ÃÅÅÕ°Ω›ÄÅÖ…ù’µïπ—Ã∏(ÄÅâΩΩ∞Å}Õ°Ω›A±ÖÂï…5ïπ‘ÄÙÅôÖ±ÕîÏ(ÄÅA±ÖÂï…5ïπ’Mïç—•Ω∏Å}¡±ÖÂï…5ïπ’%π•—•Ö±Mïç—•Ω∏ÄÙÅA±ÖÂï…5ïπ’Mïç—•Ω∏πÕ’â—•—±ïÃÏ(ÄÅô•πÖ∞Å±ΩâÖ±-ï‰ÒA±ÖÂï…5ïπ’AÖπï±M—Ö—î¯Å}¡±ÖÂï…5ïπ’-ï‰ÄÙ(ÄÄÄÄÄÅ±ΩâÖ±-ï‰ÒA±ÖÂï…5ïπ’AÖπï±M—Ö—î¯†§Ï(ÄÅM—…•πú¸Å}µïπ’%µëâ%êÏ(ÄÅM—…•πú¸Å}µïπ’Ωπ—ïπ—QÂ¡îÏ(ÄÅ•π–¸Å}µïπ’MïÖÕΩ∏Ï(ÄÅ•π–¸Å}µïπ’¡•ÕΩëîÏ(ÄÅ1•Õ–ÒëëΩπM’â—•—±ïM±Ω–¯¸Å}µïπ’Öç°ïëM±Ω—ÃÏ(ÄÅM—…•πú¸Å}µïπ’Öç°ï-ï‰Ï((ÄÄººÅM—…ïµ•ºÅQXÅù’•ëîÅÕ—Ö—î(ÄÅâΩΩ∞Å}Õ°Ω›M—…ïµ•ΩQŸ’•ëîÄÙÅôÖ±ÕîÏ(ÄÅM—…•πú¸Å}ç’……ïπ—M—…ïµ•ΩQŸ°Öππï±%êÏ(ÄÅ1•Õ–Ò5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯¯¸Å}Õ—…ïµ•ΩQŸ°Öππï±Õ=Ÿï……•ëîÏ(ÄÅâΩΩ∞Å}Õ°Ω›M—…ïµ•ΩQŸ9ï·—1ΩÖë•πúÄÙÅôÖ±ÕîÏ(ÄÅM—…•πú¸Å}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—%µëâ%êÏ(ÄÅM—…•πú¸Å}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—QÂ¡îÏ(ÄÅ•π–¸Å}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—MïÖÕΩ∏Ï(ÄÅ•π–¸Å}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—¡•ÕΩëîÏ(ÄÅM—…•πú¸Å}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—Q•—±îÏ((ÄÄºººÅôôïç—•ŸîÅÕΩ’…çïÃËÅΩŸï……•ëîÅô…Ω¥Åç°Öππï∞ÅÕ›•—ç†∞Å±ΩÖêµµΩ…îµÖ’ùµïπ—ïê(ÄÄºººÅ±•Õ–∞ÅΩ»Å•π•—•Ö∞Å›•ëùï–ÅÕΩ’…çïÃÄ°•∏Å—°Ö–Å¡…•Ω…•—‰ÅΩ…ëï»§∏(ÄÅ1•Õ–ÒQΩ……ïπ–¯¸Åùï–Å}ïôôïç—•ŸïMΩ’…çïÃÄÙ¯(ÄÄÄÄÄÅ}Õ—…ïµ•ΩMΩ’…çïÕ=Ÿï……•ëîÄ¸¸Å}Ö’ùµïπ—ïëMΩ’…çïÃÄ¸¸Å›•ëùï–πÕ—…ïµ•ΩMΩ’…çïÃÏ((ÄÄºººÅôôïç—•ŸîÅÕΩ’…çîÅ…ïÕΩ±Ÿï»ËÅΩŸï……•ëîÅô…Ω¥Åç°Öππï∞ÅÕ›•—ç†∞ÅΩ»Å•π•—•Ö∞Å›•ëùï–Å…ïÕΩ±Ÿï»∏(ÄÅ’—’…îÒM—…•πú¸¯Å’πç—•Ω∏°QΩ……ïπ–§¸Åùï–Å}ïôôïç—•ŸïIïÕΩ±Ÿï»ÄÙ¯(ÄÄÄÄÄÅ}…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çï=Ÿï……•ëîÄ¸¸Å›•ëùï–π…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çîÏ((ÄÅ1•Õ–Ò5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯¯¸Åùï–Å}ïôôïç—•ŸïM—…ïµ•ΩQŸ°Öππï±ÃÄÙ¯(ÄÄÄÄÄÅ}Õ—…ïµ•ΩQŸ°Öππï±Õ=Ÿï……•ëîÄ¸¸Å›•ëùï–πÕ—…ïµ•ΩQŸ°Öππï±ÃÏ((ÄÅM—…•πú¸Åùï–Å}ïôôïç—•ŸïΩπ—ïπ—%µëâ%êÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—%µëâ%êÄ¸¸Å›•ëùï–πçΩπ—ïπ—%µëâ%êÏ(ÄÅM—…•πú¸Åùï–Å}ïôôïç—•ŸïΩπ—ïπ—QÂ¡îÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—QÂ¡îÄ¸¸Å›•ëùï–πçΩπ—ïπ—QÂ¡îÏ(ÄÅ•π–¸Åùï–Å}ïôôïç—•ŸïΩπ—ïπ—MïÖÕΩ∏ÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—MïÖÕΩ∏Ä¸¸Å›•ëùï–πçΩπ—ïπ—MïÖÕΩ∏Ï(ÄÅ•π–¸Åùï–Å}ïôôïç—•ŸïΩπ—ïπ—¡•ÕΩëîÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—¡•ÕΩëîÄ¸¸Å›•ëùï–πçΩπ—ïπ—¡•ÕΩëîÏ(ÄÅM—…•πú¸Åùï–Å}ïôôïç—•ŸïΩπ—ïπ—Q•—±îÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïµ•ΩQŸΩπ—ïπ—Q•—±îÄ¸¸Å›•ëùï–πçΩπ—ïπ—Q•—±îÏ((ÄÄºººÅM—Öâ±îÅÕ°Ω‹Å•ëïπ—•—‰ÅôΩ»Å•∏µÕïÕÕ•Ω∏Åù’•ëîΩ…ïÕ’µîÅ›Ω…¨∏ÅUπ±•≠îÅÕç…Ωââ±î(ÄÄºººÅ•π•—•Ö±•ÈÖ—•Ω∏∞Å—°•ÃÅµÖ‰Å±ïù•—•µÖ—ï±‰ÅÖ¡¡ïÖ»ÅÖô—ï»Å±Ö’πç†Å›°ï∏ÅQY5ÖÈî(ÄÄºººÅïπ…•ç°ïÃÅÑÅ…ï±ïÖÕîµΩπ±‰Å¡±ÖÂ±•Õ–∏(ÄÅM—…•πú¸Åùï–Å}ç’……ïπ—Mï…•ïÕ%µëâ%êÅÏ(ÄÄÄÅô•πÖ∞ÅŸÖ±’îÄÙ(ÄÄÄÄÄÄÄÅ}Õï…•ïÕA±ÖÂ±•Õ–¸π•µëâ%êÄ¸¸(ÄÄÄÄÄÄÄÅ}ÕÂπ—°ï—•ç’•ëïA±ÖÂ±•Õ–¸π•µëâ%êÄ¸¸(ÄÄÄÄÄÄÄÅ}ïôôïç—•ŸïΩπ—ïπ—%µëâ%êÏ(ÄÄÄÅô•πÖ∞Å—…•µµïêÄÙÅŸÖ±’î¸π—…•¥†§Ï(ÄÄÄÅ…ï—’…∏Å—…•µµïêÄÙÙÅπ’±∞ÅÒÅ—…•µµïêπ•Õµ¡—‰Ä¸Åπ’±∞ÄËÅ—…•µµïêÏ(ÄÅÙ((ÄÄººÅΩµµ’π•—‰Å•π—…ºΩΩ’—…ºÅµÖ…≠ï…ÃÅôΩ»Å—°îÅç’……ïπ—±‰Å¡±ÖÂ•πúÅÕï…•ïÃÅï¡•ÕΩëî∏(ÄÄººÅQ°îÅ…ï≈’ïÕ–Å≠ï‰Å•πç±’ëïÃÅ—°îÅÕ—…ïÖ¥Åë’…Ö—•Ω∏ÅâïçÖ’ÕîÅ¡…ΩŸ•ëï…ÃÅµÖ‰Å’ÕîÅ•–(ÄÄººÅ—ºÅë•Õ—•πù’•Õ†Å…ï±ïÖÕïÃ∞ÅÖπêÅ—•µïÕ—Öµ¡ÃÅÖ…îÅÖ±›ÖÂÃÅŸÖ±•ëÖ—ïêÅÖùÖ•πÕ–Å•–∏(ÄÅâΩΩ∞Å}Õ≠•¡Mïùµïπ—Mï——•πùÕ1ΩÖëïêÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}Õ≠•¡Mïùµïπ—ÕπÖâ±ïêÄÙÅôÖ±ÕîÏ(ÄÅM—…•πúÅ}Õ≠•¡Mïùµïπ—A…ΩŸ•ëï…%êÄÙÅM≠•¡Mïùµïπ—A…ΩŸ•ëï…ÃπÖ’—ºÏ(ÄÅM≠•¡Mïùµïπ—A…ΩŸ•ëï»¸Å}Õ≠•¡Mïùµïπ—A…ΩŸ•ëï»Ï(ÄÅM≠•¡Mïùµïπ—ÃÅ}Õ≠•¡Mïùµïπ—ÃÄÙÅM≠•¡Mïùµïπ—Ãπïµ¡—‰Ï(ÄÅM—…•πú¸Å}±ΩÖëïëM≠•¡Mïùµïπ—Õ-ï‰Ï(ÄÅM—…•πú¸Å}±ΩÖë•πùM≠•¡Mïùµïπ—Õ-ï‰Ï(ÄÅ•π–Å}Õ≠•¡Mïùµïπ—Õï—ç°ïπï…Ö—•Ω∏ÄÙÄ¿Ï(ÄÅô•πÖ∞Å5Ö¿ÒM—…•πú∞ÅM≠•¡Mïùµïπ—Ã¯Å}Õ≠•¡Mïùµïπ—ÕÖç°îÄÙÄÒM—…•πú∞ÅM≠•¡Mïùµïπ—Ã˘ÌÙÏ((ÄÄºººÅ]°ï—°ï»Å}¡ΩÕ•—•Ω∏Ω}ë’…Ö—•Ω∏ÅëïÕç…•âîÅ—°îÅ•—ï¥Åç’……ïπ—±‰ÅÕï±ïç—ïê∞Å…Ö—°ï»(ÄÄºººÅ—°Ö∏Å—°îÅΩπîÅâï•πúÅÕ›•—ç°ïêÅÖ›Ö‰Åô…Ω¥∏ÅQ°îÅπÖ—•ŸîÅ¡±ÖÂï»ùÃÅï≈’•ŸÖ±ïπ–Å•Ã(ÄÄºººÅÅ°ÖÕŸï…	ïïπIïÖëÂÄ∏(ÄÄººº(ÄÄºººÅ±ïÖ…ïêÅ›°ï∏ÅÑÅ¡±ÖÂ±•Õ–ÅÕ›•—ç†ÅÕ—Ö…—ÃÅÖπêÅÕï–ÅÖùÖ•∏ÅΩ∏Å—°îÅô•…Õ–Å…ïÖ∞(ÄÄºººÅë’…Ö—•Ω∏ÅôΩ»Å—°îÅ•πçΩµ•πúÅµïë•Ñ∏Å%–ÅçÖππΩ–ÅÕ—•ç¨ËÅµïë•Ö}≠•–ùÃÅÅΩ¡ï∏†•Ä(ÄÄºººÅ¡’Õ°ïÃÅ’…Ö—•Ω∏πÈï…ºÅ—ºÅ—°îÅë’…Ö—•Ω∏ÅÕ—…ïÖ¥Å’πçΩπë•—•ΩπÖ±±‰∞ÅÕºÅÑÅô…ïÕ†(ÄÄºººÅë’…Ö—•Ω∏ÅÖ±›ÖÂÃÅôΩ±±Ω›ÃÇÈ›y¯ßy–ÅïŸï∏Å›°ï∏Å—°îÅπï‹Åï¡•ÕΩëîÅ…’πÃÅï·Öç—±‰ÅÖÃÅ±Ωπú(ÄÄºººÅÖÃÅ—°îÅΩ±êÅΩπî∏(ÄÅâΩΩ∞Å}Õ≠•¡Mïùµïπ—Õ5ïë•ÖIïÖë‰ÄÙÅ—…’îÏ((ÄÄººÅM’â—•—±îÅÕ—Â±îÅÕï——•πùÃ(ÄÅM’â—•—±ïMï——•πùÕÖ—Ñ¸Å}Õ’â—•—±ïMï——•πùÃÏ((ÄÄººÅÖç°ïêÅM—…ïµ•ºÅÖëëΩ∏ÅÕ’â—•—±ïÃÄ°¡ï»µ•—ï¥ÅçÖç°îÅ±•≠îÅπë…Ω•êÅQX§(ÄÅ1•Õ–ÒM—…ïµ•ΩM’â—•—±î¯¸Å}çÖç°ïëM—…ïµ•ΩM’â—•—±ïÃÏ(ÄÄººÅAï»µÖëëΩ∏ÅŸ•ï‹ÅΩòÅ—°îÅÕÖµîÅôï—ç†Ä°ë…•ŸïÃÅ—°îÅÕ°ïï–ùÃÅÖëëΩ∏Åù…Ω’¡Ã§Ï(ÄÄººÅ}çÖç°ïëM—…ïµ•ΩM’â—•—±ïÃÅ•ÃÅ•—ÃÅëïë’¡ïêÅô±Ö–Å¡…Ω©ïç—•Ω∏∏(ÄÅ1•Õ–ÒëëΩπM’â—•—±ïM±Ω–¯¸Å}çÖç°ïëëëΩπM±Ω—ÃÏ(ÄÄººÅM’â—•—±îÅ—…Öç≠ÃÅÕ’¡¡±•ïêÅÖ–Å±Ö’πç†Ä°îπú∏ÅeΩ’Q’âîÅçÖ¡—•ΩπÃ§∞ÅÕ’…ôÖçïêÅÖÃÅÑ(ÄÄººÅ¡…îµ±ΩÖëïêÅ¡…ΩŸ•ëï»Åù…Ω’¿∏ÅΩπ—ïπ–µ•πëï¡ïπëïπ–ËÅπΩ–Å≠ïÂïêÅâ‰Å%5à∞ÅÕºÅ•–(ÄÄººÅÕ’…Ÿ•ŸïÃÅ—°îÅ%5àµùÖ—ïêÅçÖç°îÅ±Ωù•åÅÖπêÅ•ÃÅΩôôï…ïêÅ›°ïπïŸï»ÅπºÅ¡ï»µ•—ï¥(ÄÄººÅÕ±Ω—ÃÅï·•Õ–∏Å	’•±–ÅΩπçîÅ•∏Å•π•—M—Ö—îÅô…Ω¥Å›•ëùï–π•π•—•Ö±M’â—•—±ïÃ∏(ÄÅ1•Õ–ÒëëΩπM’â—•—±ïM±Ω–¯¸Å}•π©ïç—ïëM’â—•—±ïM±Ω—ÃÏ(ÄÅM—…•πú¸Å}çÖç°ïëM’â—•—±ï-ï‰ÏÄººÅΩ…µÖ–ËÄâ•µëâ%êÈÕïÖÕΩ∏Èï¡•ÕΩëîàÅΩ»Äâ•µëâ%êà(ÄÅM—…•πú¸(ÄÅ}Õï±ïç—ïëM—…ïµ•ΩM’â—•—±ï%êÏÄººÅQ…Öç¨ÅÕï±ïç—ïêÅÖëëΩ∏ÅÕ’â—•—±îÅôΩ»ÅU$ÅÕ—Ö—î(ÄÅâΩΩ∞Å}ïµâïëëïëM’â—•—±ï¡¡±•ïêÄÙ(ÄÄÄÄÄÅôÖ±ÕîÏÄººÅQ…Öç¨Å•òÅïµâïëëïêÅÕ’â—•—±îÅ›ÖÃÅÖ’—ºµÕï±ïç—ïê(ÄÅâΩΩ∞Å}’Õï…5Öπ’Ö±±ÂMï±ïç—ïëM’â—•—±îÄÙ(ÄÄÄÄÄÅôÖ±ÕîÏÄººÅQ…Öç¨Å•òÅ’Õï»ÅµÖπ’Ö±±‰ÅÕï±ïç—ïêÅÑÅÕ’â—•—±î(ÄÅâΩΩ∞Å}—…Öç≠A…ïôï…ïπçïÕIïÖëÂΩ…ëëΩπM’â—•—±ïÃÄÙÅôÖ±ÕîÏ(ÄÅô•πÖ∞Å}Õ’â—•—±ïA…•Ω…•—ÂMï±ïç—•ΩπE’ï’îÄÙÅM’â—•—±ïA…•Ω…•—ÂMï±ïç—•ΩπE’ï’î†§Ï(ÄÅ•π–Å}ÖëëΩπM’â—•—±ïï—ç°QΩ≠ï∏ÄÙ(ÄÄÄÄÄÄ¿ÏÄººÅ’Ö…êÅÖùÖ•πÕ–ÅÕ—Ö±îÅÖÕÂπåÅôï—ç°ïÃÅΩ∏ÅçΩπ—ïπ–ÅÕ›•—ç†(ÄÄººÅAÖ—°ÃÅΩòÅ—ïµ¿ÅMIPΩYQPÅô•±ïÃÅ›îùŸîÅ›…•——ï∏ÅôΩ»ÅÖëëΩ∏ÅÕ’â—•—±ïÃ∏Å]îÅ°Öπê(ÄÄººÅ—°ïÕîÅ—ºÅ±•âµ¡ÿÅÖÃÅô•±îÅUI%ÃÅÕºÅ•–ÅÖ’—ºµëï—ïç—ÃÅïπçΩë•πúÄ°	,∞Å	•ú‘∞(ÄÄººÅ]•πëΩ›Ã¥ƒ»’‡∞Åï—å∏§Å•πÕ—ïÖêÅΩòÅΩ’»Å°——¿Åç±•ïπ–Å¡…îµëïçΩë•πúÅÖÃÅUQ¥‡∏(ÄÅô•πÖ∞ÅMï–ÒM—…•πú¯Å}—ïµ¡M’â—•—±ï•±ïÃÄÙÅÌÙÏ(ÄÅM—…•πú¸Å}Öç—•Ÿï·—ï…πÖ±M’â—•—±ïAÖ—†Ï(ÄÅâΩΩ∞Å}Õ’â—•—±ï’—ΩMÂπçπÖâ±ïêÄÙÅôÖ±ÕîÏ(ÄÅ5ïë•Ö-•—M’â—•—±ï’—ΩMÂπå¸Å}Õ’â—•—±ï’—ΩMÂπåÏ(ÄÄººÅQ°îÅ≈’•ï–ÅâΩ——Ω¥µ…•ù°–ÅÖ’—ºµÕÂπåÅÕ’…ôÖçîËÅÑÄ’ÃÅÖππΩ’πçîÅ±•πî∞Å—°ï∏(ÄÄººÅπΩ—°•πúÅ’π—•∞ÅÑÅ…ïÖ∞ÅïŸïπ–ÇÈ›y¯ßy–ÅÕ—Ö—’ÕïÃÅë’…•πúÅ¡ÖÕÕïÃ∞Å›Ω…êµΩπ±‰Å…ïÕ’±—Ã∏(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»Ò’—ΩMÂπçA•±±5Ωëï∞¸¯Å}Ö’—ΩMÂπçA•±∞ÄÙ(ÄÄÄÄÄÅYÖ±’ï9Ω—•ô•ï»Ò’—ΩMÂπçA•±±5Ωëï∞¸¯°π’±∞§Ï(ÄÄººÅQ…’îÅô…Ω¥Å±•Õ—ïπ•πúÅ’π—•∞ÅÑÅŸï…ë•ç–Ω—ï…µ•πÖ∞Å°•ëîËÅ—°îÅïπù•πîÅ•ÃÅ—…Â•πú∏(ÄÅâΩΩ∞Å}Ö’—ΩMÂπç]•πëΩ›ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÅQ•µï»¸Å}Ö’—ΩMÂπçA•±±!Ω±êÏÄººÅ…ïÕ’±–ÅÖ’—ºµ°•ëî(ÄÅQ•µï»¸Å}Ö’—ΩMÂπçA•±±A°ÖÕïQ•µï»ÏÄººÅÖππΩ’πçîÅÖ’—ºµë•Õµ•ÕÃ(ÄÄººÅ1ÖÕ–ÅπΩ∏µπ’±∞ÅµΩëï∞∞Å≠ï¡–ÅÕºÅ—°îÅë•Õµ•ÕÃÅôÖëîÅ°ÖÃÅçΩπ—ïπ–Å—ºÅôÖëîÅΩ’–∏(ÄÅ’—ΩMÂπçA•±±5Ωëï∞¸Å}Ö’—ΩMÂπçA•±±1ÖÕ—M°Ω›∏Ï((ÄÄººÅµïë•Ö}≠•–ÅÕ—Ö—î(ÄÅâΩΩ∞Å}•ÕIïÖë‰ÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}Õ—Ö…—’¡Ö—ïç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÄººÅïâ…•êµë•…ïç–Åô•…Õ–ÅΩ¡ï∏Å≠ïï¡ÃÅ—°îÅ1=%0ÅùÖ—îÄ°—…Öç≠•πúÅÕ’¡¡…ïÕÕ•Ω∏∞(ÄÄººÅ…ïÕ—Ω…îÅÕï≈’ïπç•πú§Åâ’–Å°•ëïÃÅ—°îÅΩŸï…±Ö‰ËÅ—°îÅ¡±ÖÂï»ùÃÅΩ›∏ÅÕ’…ôÖçîÅÖπê(ÄÄººÅâ’ôôï…•πúÅÕ¡•ππï»ÅÕ°Ω‹ÅÖπêÅçΩπ—…Ω±ÃÅçΩµîÅ’¿ÅΩ∏Å—Ö¿Æù◊üäwùPÅ—°îÅ¡…îµ±Öëëï»Å±ΩΩ¨∏(ÄÄººÅQ°îÅΩŸï…±Ö‰ÅÖ¡¡ïÖ…ÃÅΩπ±‰Å›°ï∏ÅôÖ•±ΩŸï»ÅÖç—’Ö±±‰ÅÕ—Ö…—ÃÅ…ï—…Â•πú∏(ÄÅâΩΩ∞Å}Õ—Ö…—’¡Ö—ï=Ÿï…±ÖÂ!•ëëï∏ÄÙÅôÖ±ÕîÏ(ÄÄººÅÅÕΩ’…çîÅï·¡±•ç•—±‰Å¡•ç≠ïêÅô…Ω¥Å—°îÅ•∏µ¡±ÖÂï»ÅÕ°ïï–Å•ÃÅŸÖ±•ëÖ—ïêÅÖÃÅΩπî(ÄÄººÅ•ÕΩ±Ö—ïêÅçÖπë•ëÖ—î∏Å]°•±îÅ—°•ÃÅ•ÃÅ—…’î∞Å…ïπëï…ï»ÅïŸïπ—ÃÅâï±ΩπúÅ—ºÅÖ∏(ÄÄººÅ’π—…’Õ—ïêÅ…ï¡±Öçïµïπ–ÅÖπêÅµ’Õ–ÅπΩ–Å’¡ëÖ—îÅ±ΩçÖ∞ÅçΩµ¡±ï—•Ω∏ÅΩ»ÅÖπ‰Å—…Öç≠ï»∏(ÄÅâΩΩ∞Å}µÖπ’Ö±MΩ’…çïÖ—ïç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Åùï–Å}ŸÖ±•ëÖ—•ΩπÖ—ïç—•ŸîÄÙ¯(ÄÄÄÄÄÅ}Õ—Ö…—’¡Ö—ïç—•ŸîÅÒÅ}µÖπ’Ö±MΩ’…çïÖ—ïç—•ŸîÏ(ÄÅM—…•πúÅ}Õ—Ö…—’¡Ö—ï5ïÕÕÖùîÄÙÄù°ïç≠•πúÅÕ—…ïÖªßuÁ‚ùÁXúÏ(ÄÄººÅ	±Ωç≠ÃÅ—°îÅÖ’—ΩÕÖŸîÅô…Ω¥Åô•±•πúÅÑÅπïÖ»µÈï…ºÅ¡ΩÕ•—•Ω∏ÅΩŸï»ÅÑÅëïï¿Å…ïÕ’µî(ÄÄººÅ¡Ω•π–Å›°•±îÅÑÅ…ï≈’ïÕ—ïêÅ…ïÕ’µîÅÕïï¨Å°ÖÃÅπΩ–Å±Öπëïê∏ÅMïîÅIïÕ’µï]…•—ï’Ö…ê∏(ÄÅô•πÖ∞ÅIïÕ’µï]…•—ï’Ö…êÅ}…ïÕ’µï]…•—ï’Ö…êÄÙÅIïÕ’µï]…•—ï’Ö…ê†§Ï(ÄÄººÅQ°îÄŸÃÅ—•ç¨ÅÖπêÅï·¡±•ç•–ÅU$Åç°ïç≠¡Ω•π—ÃÅçÖ∏Å±ÖπêÅ—Ωùï—°ï»∏ÅMï…•Ö±•ÈîÅ—°î(ÄÄººÅ…ïÖêΩµΩë•ô‰Ω›…•—îÅÕÖŸïÃÅÕºÅÖ∏ÅΩ±ëï»ÅÖ’—ΩÕÖŸîÅçÖππΩ–Åô•π•Õ†ÅÖô—ï»∞ÅÖπê(ÄÄººÅΩŸï…›…•—î∞ÅÑÅπï›ï»Å¡Ö’ÕîÅΩ»ÅÕï——±ïêµÕïï¨Åç°ïç≠¡Ω•π–∏(ÄÅô•πÖ∞Å1Ωç¨Å}…ïÕ’µïMÖŸï1Ωç¨ÄÙÅ1Ωç¨†§Ï(ÄÄººÅ	’µ¡ïêÅ›°ïπïŸï»Å—°îÅµïë•ÑÅ—°îÅ±Öπë•πúÅŸï…•ô•ï»Å•ÃÅ›Ö—ç°•πúÅÕ—Ω¡ÃÅâï•πú(ÄÄººÅç’……ïπ–Ä°•—ï¥Åç°Öπùî∞ÅÕΩ’…çîÅÕ›•—ç†§∏ÅâΩ…—ÃÅ—°îÅŸï…•ô•ï»Å]%Q!=UP(ÄÄººÅ…ï±ïÖÕ•πúÅ—°îÅù’Ö…êÇÈ›y¯ßy–Å—°îÅù’Ö…êÅµ’Õ–ÅÕ’…Ÿ•ŸîÅ—°…Ω’ù†Å—°îÅΩ’—ùΩ•πú(ÄÄººÅç°ïç≠¡Ω•π–ÅÕÖŸî∞Å›°•ç†Å—°îÅŸï…•ô•ï»Åµ’Õ–ÅπΩ–ÅΩ’—±•Ÿî∏(ÄÅ•π–Å}…ïÕ’µïYï…•ôÂ¡Ωç†ÄÙÄ¿Ï(ÄÅâΩΩ∞Å}•ÕA±ÖÂ•πúÄÙÅôÖ±ÕîÏ(ÄÄººÅQ…’îÅ›°•±îÅ—°îÅÖç—•Ÿ•—‰Å•ÃÅÕ°…’π¨Å•π—ºÅÑÅA•ç—’…îµ•∏µA•ç—’…îÅ›•πëΩ‹ÏÅ—°î(ÄÄººÅâ’•±êÅçΩ±±Ö¡ÕïÃÅÖ±∞Å•π—ï…Öç—•ŸîΩëïçΩ…Ö—•ŸîÅç°…ΩµîÅÕºÅΩπ±‰Å—°îÅŸ•ëïºÅÕ°Ω›Ã∏(ÄÅâΩΩ∞Å}•ÕA•¡ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÅ’…Ö—•Ω∏Å}¡ΩÕ•—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÅ’…Ö—•Ω∏Å}ë’…Ö—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÅô•πÖ∞ÅA±ÖÂâÖç≠U•±Ωç≠Ωπ—…Ω±±ï»Å}¡±ÖÂâÖç≠U•±Ωç¨ÄÙ(ÄÄÄÄÄÅA±ÖÂâÖç≠U•±Ωç≠Ωπ—…Ω±±ï»†§Ï(ÄÅô•πÖ∞ÅM≠•¡Mïùµïπ—U•Ωπ—…Ω±±ï»Å}Öç—•ŸïM≠•¡Mïùµïπ—U§ÄÙ(ÄÄÄÄÄÅM≠•¡Mïùµïπ—U•Ωπ—…Ω±±ï»†§Ï(ÄÅâΩΩ∞Å}•ÕQ…ÖπÕ•—•Ωπ•πúÄÙÅôÖ±ÕîÏÄººÅM°Ω‹Åâ±Öç¨ÅÕç…ïï∏Åë’…•πúÅ—…ÖπÕ•—•ΩπÃ((ÄÄºººÅ=πîµÕ°Ω–Åù’Ö…êÅÕï–Å—°îÅµΩµïπ–Å›îÅ¡Ω¿Å—ºÅ°ÖπêÅ—°îÅπï·–Åï¡•ÕΩëîÅâÖç¨Å—ºÅ—°î(ÄÄºººÅ°ΩÕ–ÅôΩ»ÅE’•ç¨ÅA±Ö‰∏ÅπêµΩòµŸ•ëïºÅÖ’—ºµÖëŸÖπçîÄ°}ΩπA±ÖÂâÖç≠πëïê§ÅÖπêÅÑ(ÄÄºººÅµÖπ’Ö∞Å9ï·–Å¡…ïÕÃÅâΩ—†Åô’ππï∞Å•π—ºÅ}°Öπë±ïMï…•ïÕ9ï·—¡•ÕΩëî∞Å›°•ç†ÅÖ›Ö•—ÃÅÑ(ÄÄºººÅπï—›Ω…¨Å±ΩΩ≠’¿ÅÖπêÅ—°ï∏Å¡Ω¡ÃãßuÁ‚ùÁPÅ›•—°Ω’–Å—°•Ã∞Å—°îÅ—›ºÅçÖ∏Å…ÖçîÅÖπêÅ¡Ω¿(ÄÄºººÅ—›•çî∞Åï©ïç—•πúÅ—°îÅ’Õï»ÅΩôòÅ—°îÅ°ΩÕ–ÅÕç…ïï∏Å•πÕ—ïÖêÅΩòÅ¡±ÖÂ•πúÅ—°îÅπï·–∏(ÄÅâΩΩ∞Å}Õï…•ïÕ9ï·—•Õ¡Ö—ç°ïêÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}ç’……ïπ—¡•ÕΩëï5Ö…≠ïëÕ•π•Õ°ïêÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}ç’……ïπ—5ΩŸ•ï5Ö…≠ïëÕ•π•Õ°ïêÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}ç’……ïπ—5ΩŸ•ïIï›Ö—ç°M—Ö…—ïêÄÙÅôÖ±ÕîÏ(ÄÅ•π–Å}µΩŸ•ïΩµ¡±ï—•ΩπQ°…ïÕ°Ω±êÄÙ(ÄÄÄÄÄÅM—Ω…ÖùïMï…Ÿ•çîπëïôÖ’±—1ΩçÖ±Ωµ¡±ï—•ΩπQ°…ïÕ°Ω±êÏ(ÄÅ•π–Å}ï¡•ÕΩëïΩµ¡±ï—•ΩπQ°…ïÕ°Ω±êÄÙ(ÄÄÄÄÄÅM—Ω…ÖùïMï…Ÿ•çîπëïôÖ’±—1ΩçÖ±Ωµ¡±ï—•ΩπQ°…ïÕ°Ω±êÏ(ÄÄººÅ]îÅ…ïπëï»Å’Õ•πúÅÑÅ±Ö…ùîÅ±Ωù•çÖ∞ÅÕ’…ôÖçîÏÅô•–Å•ÃÅçΩπ—…Ω±±ïêÅâ‰Å	Ω·•–(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}¡ΩÕM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}ë’…M’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}¡±ÖÂM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}¡Ö…ÖµÕM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}—…Öç≠M’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}çΩµ¡±ï—ïëM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}â’ôôï…•πùM’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}•¡—Ÿ……Ω…M’àÏ(ÄÅM—…ïÖµM’âÕç…•¡—•Ω∏¸Å}…ïπëï…ï…M—Ö…—’¡……Ω…M’àÏ((ÄÄºººÅI’π—•µîÅ°Ö…ë›Ö…îµëïçΩëï»Å¡…Ωâî∏Åµ¡ÿùÃÅçΩπô•ù’…ïêÅÅ°›ëïåıÖ’—ºµÕÖôïÄÅΩπ±‰(ÄÄºººÅëïÕç…•âïÃÅ›°Ö–Å•–ÅÕ°Ω’±êÅ—…‰ÏÅÅ°›ëïåµç’……ïπ—ÄÅ•ÃÅ—°îÅëïçΩëï»Å—°Ö–ÅÖç—’Ö±±‰(ÄÄºººÅΩ¡ïπïêÅôΩ»Å—°•ÃÅ•—ï¥∏Åïπï…Ö—•ΩπÃÅÖ…îÅÖëŸÖπçïêÅâ‰ÅïŸï…‰ÅÖ¡¿µΩ›πïêÅΩ¡ï∏∞(ÄÄºººÅ›°•±îÅ¡…Ω¡ï…—‰ÅΩâÕï…Ÿï…ÃÅçÖ—ç†ÅÑÅëïçΩëï»ΩΩ’—¡’–Å—…ÖπÕ•—•Ω∏Åµ•êµÕ—…ïÖ¥∏(ÄÅ•π–Å}ëïçΩëï…A…Ωâïïπï…Ö—•Ω∏ÄÙÄ¿Ï(ÄÅ•π–Å}ëïçΩëï…A…ΩâïQΩ≠ï∏ÄÙÄ¿Ï(ÄÅµ¨πY•ëïΩAÖ…ÖµÃ¸Å}ëïçΩëï…A…ΩâïAÖ…ÖµÃÏ(ÄÅQ•µï»¸Å}ëïçΩëï…A…ΩâïQ•µï»Ï(ÄÅM—…•πú¸Å}±ÖÕ—ïçΩëï…•ÖùπΩÕ—•çM•ùπÖ—’…îÏ((ÄÄººÅ	’ôôï…•πúÅ•πë•çÖ—Ω»(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒâΩΩ∞¯Å}Õ°Ω›	’ôôï…•πù%πë•çÖ—Ω»ÄÙÅYÖ±’ï9Ω—•ô•ï»°ôÖ±Õî§Ï(ÄÅQ•µï»¸Å}â’ôôï…•πùïâΩ’πçïQ•µï»Ï((ÄÄººÅïÕ—’…îÅÕ—Ö—î(ÄÅïÕ—’…ï5ΩëîÅ}µΩëîÄÙÅïÕ—’…ï5ΩëîππΩπîÏ(ÄÅ=ôôÕï–Å}ùïÕ—’…ïM—Ö…—AΩÕ•—•Ω∏ÄÙÅ=ôôÕï–πÈï…ºÏ(ÄÅ’…Ö—•Ω∏Å}ùïÕ—’…ïM—Ö…—Y•ëïΩAΩÕ•—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÅëΩ’â±îÅ}ùïÕ—’…ïM—Ö…—YΩ±’µîÄÙÄ¿∏¿Ï(ÄÅëΩ’â±îÅ}ùïÕ—’…ïM—Ö…—	…•ù°—πïÕÃÄÙÄ¿∏¿Ï((ÄÄººÅ!UÅÕ—Ö—î(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒMïï≠!’ëM—Ö—î¸¯Å}Õïï≠!’êÄÙÅYÖ±’ï9Ω—•ô•ï»ÒMïï≠!’ëM—Ö—î¸¯†(ÄÄÄÅπ’±∞∞(ÄÄ§Ï(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒYï…—•çÖ±!’ëM—Ö—î¸¯Å}Ÿï…—•çÖ±!’êÄÙ(ÄÄÄÄÄÅYÖ±’ï9Ω—•ô•ï»ÒYï…—•çÖ±!’ëM—Ö—î¸¯°π’±∞§Ï(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒÕ¡ïç—IÖ—•Ω!’ëM—Ö—î¸¯Å}ÖÕ¡ïç—IÖ—•Ω!’êÄÙ(ÄÄÄÄÄÅYÖ±’ï9Ω—•ô•ï»ÒÕ¡ïç—IÖ—•Ω!’ëM—Ö—î¸¯°π’±∞§Ï((ÄÄººÅÕ¡ïç–ÄºÅÕ¡ïïê(ÄÅÕ¡ïç—5ΩëîÅ}ÖÕ¡ïç—5ΩëîÄÙÅÕ¡ïç—5ΩëîπçΩπ—Ö•∏Ï(ÄÅëΩ’â±îÅ}¡±ÖÂâÖç≠M¡ïïêÄÙÄƒ∏¿Ï((ÄÄººãßuÁ‚ùÁnù◊üäwù ÅM±ïï¿Å—•µï»ãßuÁ‚ùÁnù◊üäwù ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç (ÄÄººÅM—Ω¡ÃÅ¡±ÖÂâÖç¨ÅÖô—ï»ÅÑÅçΩ’π—ëΩ›∏∞ÅΩ»ÅÖ–Å—°îÅïπêÅΩòÅ—°îÅç’……ïπ–Å•—ï¥∏ÅQ°î(ÄÄººÅ›Ö≠ï±Ωç¨ÅÖ±…ïÖë‰ÅôΩ±±Ω›ÃÅ¡±Ö‰ÅÕ—Ö—îÅ°ï…î∞ÅÕºÅ¡Ö’Õ•πúÅ•ÃÅïπΩ’ù†Å—ºÅ±ï–Å—°î(ÄÄººÅÕç…ïï∏ÅÕ±ïï¿Æù◊üäwùPÅ’π±•≠îÅ—°îÅπÖ—•ŸîÅ¡±ÖÂï…Ã∞Å›°•ç†Å¡•∏Å—°îÅÕç…ïï∏ÅΩ∏∏(ÄÅM±ïï¡Q•µï…5ΩëîÅ}Õ±ïï¡Q•µï…5ΩëîÄÙÅM±ïï¡Q•µï…5ΩëîπΩôòÏ((ÄÄºººÅ]°ï∏Å—°îÅÖ…µïêÅçΩ’π—ëΩ›∏Åô•…ïÃ∏ÅQ°îÅ±Öâï∞Å•ÃÅëï…•ŸïêÅô…Ω¥Å—°•ÃÅ…Ö—°ï»(ÄÄºººÅ—°Ö∏Åô…Ω¥Å—°îÅë’…Ö—•Ω∏Å¡•ç≠ïê∞ÅÕºÅ•–ÅçΩ’π—ÃÅëΩ›∏Å•πÕ—ïÖêÅΩòÅ…ïÖë•πúÄàÃ¿(ÄÄºººÅµ•∏àÅ…•ù°–Å’¿Å—ºÅ—°îÅµΩµïπ–Å•–ÅÕ—Ω¡Ã∏(ÄÅÖ—ïQ•µî¸Å}Õ±ïï¡Q•µï…ïÖë±•πîÏ((ÄÄºººÅQ°îÅ¡…ïÕï–ÅΩ…•ù•πÖ±±‰Å¡•ç≠ïê∞ÅÕºÅ—°îÅÕ°ïï–ÅçÖ∏Å≠ïï¿Å•–Åç°ïç≠ïêÅ›°•±îÅ—°î(ÄÄºººÅ…ïµÖ•π•πúÅ—•µîÅ—•ç≠ÃÅÖ›Ö‰Åô…Ω¥Å•–∏(ÄÅ•π–Å}Õ±ïï¡Q•µï……µïë5•π’—ïÃÄÙÄ¿Ï(ÄÅQ•µï»¸Å}Õ±ïï¡Q•µï»Ï((ÄÄºººÅ1Ö—ç°ïêÅô…Ω¥ÅÑÅÕ±ïï¿µ—•µï»ÅÕ—Ω¿Å’π—•∞Å—°îÅ’Õï»Åï·¡±•ç•—±‰ÅÕ—Ö…—ÃÅ¡±ÖÂâÖç¨(ÄÄºººÅÖùÖ•∏∏ÅëŸÖπç•πúÅ•ÃÅÖÕÂπç°…ΩπΩ’ÃÅ°ï…îÄ°…ïÕΩ±ŸîÅ—°îÅUI0∞Å—°ï∏ÅΩ¡ï∏§∞ÅÕºÅÑ(ÄÄºººÅçΩ’π—ëΩ›∏Åï·¡•…•πúÅµ•êµô±•ù°–Å›Ω’±êÅΩ—°ï…›•ÕîÅâîÅ’πëΩπîÅâ‰Å—°îÅï¡•ÕΩëî(ÄÄºººÅ—°Ö–Å›ÖÃÅÖ±…ïÖë‰ÅΩ∏Å•—ÃÅ›Ö‰∏(ÄÅâΩΩ∞Å}Õ±ïï¡M—Ω¡1Ö—ç°ïêÄÙÅôÖ±ÕîÏ((ÄÄººÅA…ïÕÃµÖπêµ°Ω±êÅôΩ»Ä…‡ÅÕ¡ïïê(ÄÅëΩ’â±î¸Å}Õ¡ïïë	ïôΩ…ï!Ω±êÏ(ÄÅô•πÖ∞ÅYÖ±’ï9Ω—•ô•ï»ÒâΩΩ∞¯Å}Õ¡ïïë!Ω±ë!’êÄÙÅYÖ±’ï9Ω—•ô•ï»ÒâΩΩ∞¯°ôÖ±Õî§Ï((ÄÄººÅ=…•ïπ—Ö—•Ω∏(ÄÅâΩΩ∞Å}±ÖπëÕçÖ¡ï1Ωç≠ïêÄÙÅôÖ±ÕîÏ((ÄÄºººÅ]°ï—°ï»Å—°•ÃÅ¡±ÖÂï»ÅÕ°Ω’±êÅ=A8Å’¡…•ù°–Å…Ö—°ï»Å—°Ö∏Å—’…π•πúÅ—°îÅëïŸ•çî(ÄÄºººÅ±ÖπëÕçÖ¡îÅôΩ»Å—°îÅ’Õï»Ä°Mï——•πùÃãßuÁ‚ùÁHÅA±ÖÂâÖç¨ÇÈ›y¯ßyÿÄâ=¡ï∏Å—°îÅ¡±ÖÂï»Å•∏(ÄÄºººÅ¡Ω…—…Ö•–à§∏(ÄÄººº(ÄÄºººÅA°ΩπîµΩπ±‰ÅΩ∏Å¡’…¡ΩÕî∏ÅÅQXÅ°ÖÃÅπºÅ¡Ω…—…Ö•–Å—ºÅΩ¡ï∏Å•∏∞ÅÖπêÅΩ∏ÅëïÕ≠—Ω¿(ÄÄºººÅmMÂÕ—ïµ°…ΩµîπÕï—A…ïôï……ïë=…•ïπ—Ö—•ΩπÕtÅëΩïÃÅπΩ—°•πúÆù◊üäwùPÅâ’–Å°ΩπΩ’…•πúÅ—°î(ÄÄºººÅ¡…ïòÅ—°ï…îÅ›Ω’±êÅÕ—•±∞Åô±•¿Å—°îÅ…Ω—Ö—îÅâ’——Ω∏ùÃÅ±Öâï∞Å—ºÄâ1ÖπëÕçÖ¡îàÅΩŸï»(ÄÄºººÅÑÅ›•πëΩ‹Å—°Ö–Å•ÃÅÖ±…ïÖë‰Å›•ëî∞ÅëïÕç…•â•πúÅÑÅ…Ω—Ö—•Ω∏Å—°Ö–ÅçÖ∏ù–Å°Ö¡¡ï∏∏(ÄÅâΩΩ∞Åùï–Å}Õ—Ö…—Õ%πAΩ…—…Ö•–ÄÙ¯(ÄÄÄÄÄÅA±Ö—ôΩ…µU—•∞π•ÕA°ΩπîÄòòÅM—Ω…ÖùïMï…Ÿ•çîπ¡±ÖÂï…M—Ö…—AΩ…—…Ö•—Öç°ïêÏ((ÄÄººÅIÖ•πâΩ‹Åπï·–ÅÖπ•µÖ—•Ω∏(ÄÅ±Ö—îÅπ•µÖ—•ΩπΩπ—…Ω±±ï»Å}…Ö•πâΩ›Ωπ—…Ω±±ï»Ï(ÄÅ±Ö—îÅπ•µÖ—•Ω∏ÒëΩ’â±î¯Å}…Ö•πâΩ›=¡Öç•—‰Ï(ÄÅâΩΩ∞Å}…Ö•πâΩ›ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÅâΩΩ∞Å}—…ÖπÕ•—•ΩπI’ππ•πúÄÙÅôÖ±ÕîÏ(ÄÅQ•µï»¸Å}—…ÖπÕ•—•ΩπM—Ω¡Q•µï»Ï(ÄÅQ•µï»¸Å}—…ÖπÕ•—•ΩπA°ÖÕïQ•µï»Ï(ÄÅ•π–Å}—…ÖπÕ•—•ΩπA°ÖÕîÄÙÄƒÏÄººÄƒÄÙÅÕ—Ö—•å∞Ä»ÄÙÅ…ïŸïÖ∞(ÄÅÖ—ïQ•µî¸Å}—…ÖπÕ•—•ΩπA°ÖÕî…M—Ö…—ïêÏ((ÄÄººÅIï—…ºÅQXÅÕ—Ö—•åÅ±ΩÖë•πúÅµïÕÕÖùïÃ(ÄÅM—…•πúÅ}—ŸM—Ö—•ç5ïÕÕÖùîÄÙÄõßuÁ‚ùÁnù◊üäwùËÅQU9%9∏∏∏úÏ(ÄÅM—…•πúÅ}—ŸM—Ö—•çM’â—ï·–ÄÙÄúúÏÄººÅMïçΩπêÅ±•πîÅôΩ»ÅŸ•ëïºÅ—•—±î(ÄÅô•πÖ∞Å1•Õ–ÒM—…•πú¯Å}—ŸM—Ö—•ç5ïÕÕÖùïÃÄÙÅl(ÄÄÄÄõßuÁ‚ùÁnù◊üäwùËÅ	UI%9∏∏∏Å)UMPÅ-%%9ú∞(ÄÄÄÄõßuÁ‚ùÁnù◊üäwùËÅIQ%U1Q%9ÅMA1%9L∏∏∏ú∞(ÄÄÄÄÆù◊üäwùˆÈ›y¯ßyÿÅMU55=9%9ÅY%<Å=L∏∏∏ú∞(ÄÄÄÄú÷ç¢T‰ttî‰rÖïU$E$ïdR‚‚‚r¿¢sZ6à–SPîêUSë»ìV–TP“U‘âÀà	∫w^~)ﬁvÈ›y¯ßyﬁà””î’SSë»HS”‘íUT…Àà	∫w^~)ﬁvÈ›y¯ßyﬁà–TìRSë»THVS…Àà	Õh⁄ BRIBING THE SERVERS...',
  ];

  // Dynamic title for Debrify TV (no-playlist) flow
  String _dynamicTitle = '';

  // Trakt scrobble state
  bool _traktScrobbleEnabled = false;
  // The launched item's widget.traktProgressPercent is a first-load-only
  // signal; once spent it must not apply to a later switched-to episode.
  bool _launchTraktPercentSpent = false;
  // Per-episode Trakt cross-device progress ("season_episode""È›y¯ßy“ 0-100), loaded
  // once per series; drives resume for episodes switched to in-session.
  Map<String, double>? _traktEpisodeProgress;
  String? _traktLastScrobbleAction;
  Timer? _traktHeartbeatTimer;
  // Simkl scrobble state+ßuÁ‚ùÁT a fully parallel mirror of the Trakt fields above
  // (independent dedup guard + heartbeat; the two trackers never share state).
  bool _simklScrobbleEnabled = false;
  bool _launchSimklPercentSpent = false;
  // Per-episode Simkl cross-device snapshot ("season_episode" ∫w^~)ﬁv 0-100),
  // refreshed by the launcher and used when switching episodes in-session.
  Map<String, double>? _simklEpisodeProgress;
  Map<String, double>? _mdblistEpisodeProgress;
  String? _episodeTrackerProgressImdbId;
  bool _launchMdblistPercentSpent = false;
  String? _simklLastScrobbleAction;
  Timer? _simklHeartbeatTimer;
  MdblistScrobbleSession? _mdblistSession;
  // Keeps the analytics session alive during long, interaction-free playback.
  Timer? _analyticsHeartbeatTimer;

  Duration? _randomStartOffset(Duration duration) {
    final num clampedPercent = widget.randomStartMaxPercent.clamp(0, 99);
    if (duration <= Duration.zero || clampedPercent <= 0) {
      return null;
    }
    final maxFraction = clampedPercent.toDouble() / 100.0;
    if (maxFraction <= 0) {
      return null;
    }
    final randomFraction = _random.nextDouble() * maxFraction;
    final milliseconds = (duration.inMilliseconds * randomFraction).floor();
    if (milliseconds <= 0) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  Duration? _percentStartOffset(Duration duration) {
    final percent = widget.startAtPercent;
    if (percent == null || percent <= 0 || duration <= Duration.zero) {
      return null;
    }
    final clamped = percent.clamp(0.0, 0.99);
    final ms = (duration.inMilliseconds * clamped).floor();
    return ms > 0 ? Duration(milliseconds: ms) : null;
  }

  @override
  void initState() {
    super.initState();
    _continuousShuffleEnabled = widget.initialContinuousShuffle;
    _activeHttpHeaders = widget.httpHeaders;
    PlayerVisibility.opened(this);
    AnalyticsService.screenView('video_player');
    _startAnalyticsHeartbeat();
    _activePlaylist = widget.playlist
        ?.map((entry) => entry.withDefaultHttpHeaders(widget.httpHeaders))
        .toList();
    _seriesImdbKnownAtLaunch = widget.contentImdbId?.trim().isNotEmpty == true;
    // The dock and the zap banner share the bottom strip, and the dock is
    // raised from several places that never go through _toggleControls
    // (volume keys, pointer wake). Watching the notifier catches all of them.
    _controlsVisible.addListener(_onControlsVisibilityChanged);

    // onPause fires on the transition to AppLifecycleState.paused ∫w^~)ﬁt Android's
    // onStop, i.e. Home or an app switch. Picture-in-Picture keeps the
    // activity visible and reports `inactive` instead, so a PiP'd stream keeps
    // recording AND keeps playing. Deliberately not onInactive: that fires for
    // the notification shade, permission dialogs and the app switcher peek,
    // none of which should stop the video.
    _lifecycle = AppLifecycleListener(
      onPause: () {
        unawaited(_stopRecording(userInitiated: false));
        _pauseForBackground();
      },
      onResume: _resumeFromBackground,
    );

    // Observe, don't sample: see [_desktopRecordingRevisionListener].
    if (DesktopRecordingService.instance.isSupported) {
      void onRevision() {
        if (mounted) setState(() {});
      }

      _desktopRecordingRevisionListener = onRevision;
      DesktopRecordingService.instance.revision.addListener(onRevision);
    }

    // Launch-time subtitles (e.g. YouTube captions): wrap into a single loaded
    // provider group so they appear in the subtitle menu without an addon
    // fetch. Grouped under the first track's source label (e.g. "YouTube").
    final initialSubs = widget.initialSubtitles;
    if (initialSubs != null && initialSubs.isNotEmpty) {
      _injectedSubtitleSlots = [
        AddonSubtitleSlot(
          addonId: 'injected',
          addonName: initialSubs.first.source,
          status: AddonSubtitleStatus.ok,
          subtitles: initialSubs,
        ),
      ];
    }

    // Picture-in-Picture (Android phone and iOS): once native confirms capability,
    // become the active PiP owner and listen so we can collapse chrome inside
    // the tiny window. Auto-enter is armed later, when the video is actually
    // ready (see the player `ready` callback), so pressing Home never shrinks
    // a black/loading frame. Skipped when options are hidden ∫w^~)ﬁt that context
    // deliberately suppresses the PiP button and tap controls.
    if ((Platform.isAndroid || (Platform.isIOS && !PlatformUtil.isTvOS)) &&
        !widget.hideOptions) {
      PipService.resolveSupport().then((ok) {
        if (!mounted || !ok) return;
        PipService.attach(
          this,
          onMode: _onPipModeChanged,
          onAction: _onPipAction,
          onRestore: _restoreIosPipPlayer,
        );
        // Reveal the PiP button now that support is known.
        setState(() {});
        // If the player became ready before native support resolved, arm now.
        if (_isReady) _armPipAutoEnter();
      });
    }

    // Log playlist entries to trace relativePath
    if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
      debugPrint(
        +ßuÁ‚ùÁ}∫w^~)ﬁv VideoPlayerScreen.initState: Initialized with ${_activePlaylist!.length} playlist entries',
      );
      for (int i = 0; i < _activePlaylist!.length && i < 5; i++) {
        final entry = _activePlaylist![i];
        debugPrint(
          '  Entry[$i]: title="${entry.title}", relativePath="${entry.relativePath}"',
        );
      }
    }

    if (widget.channelName != null && widget.channelName!.trim().isNotEmpty) {
      _currentChannelName = widget.channelName;
    }
    _currentChannelNumber = widget.channelNumber;
    _currentIptvIndex = widget.iptvStartIndex ?? 0;
    _currentSourceIndex = widget.stremioCurrentSourceIndex ?? 0;
    _initIptvStremioSources();
    _currentStremioTvChannelId = _findInitialStremioTvChannelId();
    _parseChannelDirectory();
    // The sync offset is per-subtitle and session-scoped, but it lives in a
    // process-wide singleton+ßuÁ‚ùÁT clear it at the start of every player session so
    // a previous video's offset can't leak in (mirrors the TV side's onCreate).
    SubtitleSettingsService.instance.resetSyncOffset();
    _loadSubtitleSettings();
    unawaited(_loadTrackingPolicy());
    unawaited(_loadSkipSegmentSettings());
    unawaited(_loadLocalCompletionThresholds());
    MediaKitInit.ensureInitialized();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The player opens landscape ∫w^~)ﬁt a video wants the long edge ∫w^~)ﬁt unless the
    // user asked it to open upright, in which case the Portrait/Landscape
    // button is how they turn it. Read from the SYNCHRONOUS cache: setting
    // landscape here and correcting it once an async read lands would perform
    // the exact flip the setting exists to prevent.
    _landscapeLocked = !_startsInPortrait;
    SystemChrome.setPreferredOrientations(
      _landscapeLocked
          ? const <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
    // Held for the LOADING phase only+ßuÁ‚ùÁT a slow debrid resolve must not let
    // the screen sleep before the first frame. From the first playing event
    // onward the lock follows play/pause (see _syncWakelock).
    unawaited(PlayerDisplayControls.instance.setWakelock(true));
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.setFullScreen(true);
    }
    // System volume UI not modified

    // Initialize the player asynchronously
    _playerInitializationFuture = _initializePlayer();

    // Init rainbow animation
    _rainbowController = AnimationController(
      vsync: this,
      duration: VideoPlayerTimingConstants.rainbowAnimationDuration,
    );
    _rainbowOpacity = CurvedAnimation(
      parent: _rainbowController,
      curve: Curves.easeInOut,
    );

    // Check if Trakt scrobbling should be enabled for this playback
    _initTraktScrobble();
    _initSimklScrobble();
    _initMdblistScrobble();
  }

  Future<void> _loadSkipSegmentSettings() async {
    final values = await Future.wait<Object>([
      StorageService.getSkipSegmentsEnabled(),
      StorageService.getSkipSegmentProvider(),
    ]);
    if (!mounted) return;

    final enabled = values[0] as bool;
    final storedProvider = values[1] as String;
    final providerId = SkipSegmentProviders.isAvailable(storedProvider)
        ? storedProvider
        : SkipSegmentProviders.auto;

    _skipSegmentProvider?.close();
    _skipSegmentProvider = enabled
        ? SkipSegmentProviders.create(providerId)
        : null;
    _skipSegmentsEnabled = enabled;
    _skipSegmentProviderId = providerId;
    _skipSegmentSettingsLoaded = true;
    _syncSkipSegmentsForCurrentContent();
  }

  Future<void> _loadLocalCompletionThresholds() async {
    final values = await Future.wait<int>([
      StorageService.getMovieCompletionThreshold(),
      StorageService.getEpisodeCompletionThreshold(),
    ]);
    if (!mounted) return;
    _movieCompletionThreshold = values[0];
    _episodeCompletionThreshold = values[1];
    // A seek can cross the default threshold before the preference read
    // finishes. Re-evaluate against the configured value once it arrives.
    _checkAndApplyLocalCompletion();
  }

  bool get _usesLocalCompletionTracking =>
      (_forceLocalCompletionTracking ||
          (!widget.traktScrobble &&
              !widget.simklScrobble &&
              !widget.mdblistScrobble)) &&
      widget.stremioTvChannels == null &&
      _effectiveIptvChannels == null;

  bool _forceLocalCompletionTracking = false;

  Future<void> _loadTrackingPolicy() async {
    final policy = await TrackingSourcePolicy.load();
    if (!mounted) return;
    _forceLocalCompletionTracking = policy.forcesLocalCompletion;
    // A very short item can cross its completion threshold before this async
    // profile read returns. Re-evaluate immediately so This-device mode never
    // misses the forced-local rule merely because scrobbling is also enabled.
    _checkAndApplyLocalCompletion();
  }

  String? get _currentLocalMovieImdbId {
    if (_effectiveContentType != 'movie') return null;
    final imdbId = _effectiveContentImdbId?.trim();
    return imdbId == null || imdbId.isEmpty ? null : imdbId;
  }

  void _resetLocalCompletionState() {
    _currentEpisodeMarkedAsFinished = false;
    _currentMovieMarkedAsFinished = false;
    _currentMovieRewatchStarted = false;
  }

  ({String imdbId, int season, int episode, Duration duration, String key})?
  _currentSkipSegmentRequest() {
    // Two stale-media windows, both of which would judge the incoming item
    // against the outgoing one's clock:
    //
    // * _skipSegmentsMediaReady covers a playlist switch. _loadPlaylistIndex
    //   points _currentIndex at the new episode and only then saves resume and
    //   resolves the stream URL"È›y¯ßy‘ a network round trip for debrid/PikPak
    //   links. Through all of that _position/_duration still describe the
    //   outgoing episode, and that position is usually deep enough to land
    //   inside a segment, so the button flashes on the moment next-episode is
    //   pressed. It also asks the provider for the new episode at the old
    //   episode's duration, which can select or validate the wrong release.
    // * _isTransitioning covers an IPTV zap / source switch, where the key
    //   flips before the incoming stream opens (the same window _saveResume
    //   guards against).
    if (!_skipSegmentSettingsLoaded ||
        !_skipSegmentsEnabled ||
        !_skipSegmentsMediaReady ||
        _isTransitioning ||
        _duration <= Duration.zero) {
      return null;
    }

    final seriesPlaylist = _seriesPlaylist;
    final isSeries =
        _effectiveContentType == 'series' || seriesPlaylist?.isSeries == true;
    if (!isSeries) return null;

    var imdbId = _effectiveContentImdbId?.trim();
    if (imdbId == null || !RegExp(r'^tt\d+$').hasMatch(imdbId)) {
      imdbId = seriesPlaylist?.imdbId?.trim();
    }
    if (imdbId == null || !RegExp(r'^tt\d+$').hasMatch(imdbId)) return null;

    int? season;
    int? episode;
    if (seriesPlaylist?.isSeries == true) {
      final current = _findSeriesEpisodeForCurrentIndex(seriesPlaylist!);
      season = current?.seriesInfo.season;
      episode = current?.seriesInfo.episode;
    }
    season ??= _effectiveContentSeason;
    episode ??= _effectiveContentEpisode;
    if (season == null || episode == null) {
      final parsed = _traktSeasonEpisode();
      season ??= parsed.season;
      episode ??= parsed.episode;
    }
    if (season == null || episode == null || season < 0 || episode < 1) {
      return null;
    }

    final durationSeconds = _duration.inSeconds;
    final key =
        '$_skipSegmentProviderId:$imdbId:$season:$episode:$durationSeconds';
    return (
      imdbId: imdbId,
      season: season,
      episode: episode,
      duration: _duration,
      key: key,
    );
  }

  void _syncSkipSegmentsForCurrentContent() {
    final request = _currentSkipSegmentRequest();
    final provider = _skipSegmentProvider;
    if (request == null || provider == null) return;
    if (_loadedSkipSegmentsKey == request.key ||
        _loadingSkipSegmentsKey == request.key) {
      return;
    }

    if (_skipSegmentsCache.containsKey(request.key)) {
      final cached = _skipSegmentsCache[request.key]!;
      if (mounted) {
        setState(() {
          _skipSegments = cached;
          _loadedSkipSegmentsKey = request.key;
        });
        _syncActiveSkipSegmentUi();
      }
      return;
    }

    final generation = ++_skipSegmentsFetchGeneration;
    _loadingSkipSegmentsKey = request.key;
    provider
        .fetch(
          imdbId: request.imdbId,
          season: request.season,
          episode: request.episode,
          duration: request.duration,
        )
        .then((segments) {
          _skipSegmentsCache[request.key] = segments;
          if (!mounted || generation != _skipSegmentsFetchGeneration) return;
          if (_currentSkipSegmentRequest()?.key != request.key) return;
          setState(() {
            _skipSegments = segments;
            _loadedSkipSegmentsKey = request.key;
          });
          _syncActiveSkipSegmentUi();
        })
        .catchError((Object error) {
          // Missing skip data must never affect playback. Cache the miss for
          // this session so an offline API cannot be retried on every position
          // tick.
          _skipSegmentsCache[request.key] = SkipSegments.empty;
          debugPrint(
            'SkipSegments: ${provider.displayName} fetch failed: $error',
          );
          if (!mounted || generation != _skipSegmentsFetchGeneration) return;
          if (_currentSkipSegmentRequest()?.key != request.key) return;
          setState(() {
            _skipSegments = SkipSegments.empty;
            _loadedSkipSegmentsKey = request.key;
          });
          _syncActiveSkipSegmentUi();
        })
        .whenComplete(() {
          if (_loadingSkipSegmentsKey == request.key) {
            _loadingSkipSegmentsKey = null;
          }
        });
  }

  /// Forget the outgoing item's skip segments when switching playlist entries,
  /// and stop reading its clock until the incoming one opens. The native TV
  /// player does the same in playItem.
  ///
  /// The fetch cache survives on purpose: it's keyed per episode, so going
  /// back to one already looked up is instant.
  void _resetSkipSegmentState() {
    _skipSegmentsFetchGeneration++;
    _loadingSkipSegmentsKey = null;
    _loadedSkipSegmentsKey = null;
    _skipSegments = SkipSegments.empty;
    _skipSegmentsMediaReady = false;
    _activeSkipSegmentUi.clear();
  }

  SkipSegment? get _activeSkipSegment {
    final request = _currentSkipSegmentRequest();
    if (request == null || request.key != _loadedSkipSegmentsKey) return null;
    return _skipSegments.segmentAt(_position);
  }

  void _syncActiveSkipSegmentUi() {
    _activeSkipSegmentUi.update(_activeSkipSegment);
  }

  void _skipActiveSegment() {
    final segment = _activeSkipSegment;
    if (segment == null || !_playerCreated) return;
    final target = _duration > Duration.zero && segment.end > _duration
        ? _duration
        : segment.end;
    _position = target;
    _playbackUiClock.updatePosition(target, immediate: true);
    _syncActiveSkipSegmentUi();
    unawaited(_player.seek(target));
    _traktScrobbleSeek(target);
    _simklScrobbleSeek(target);
    _mdblistScrobbleSeek(target);
    HapticFeedback.selectionClick();
  }

  Future<void> _initTraktScrobble() async {
    if (!widget.traktScrobble) return;
    if (widget.contentImdbId == null) return;
    if (widget.contentType != 'movie' && widget.contentType != 'series') return;
    final policy = await TrackingSourcePolicy.load();
    _traktScrobbleEnabled =
        policy.scrobbles(TrackingSource.trakt) &&
        await TraktService.instance.isAuthenticated();
    if (!mounted) return;
    // If player started playing before auth resolved, scrobble start now
    if (_traktScrobbleEnabled && _isPlaying && _duration > Duration.zero) {
      _traktScrobble('start');
      if (_traktLastScrobbleAction == 'start') {
        _startTraktHeartbeat();
      }
    }
  }

  /// The position trackers and stores may persist: the live position, unless
  /// a requested resume never landed+ßuÁ‚ùÁT then the HELD target. The live value in
  /// that window describes a stream that restarted at the beginning, and
  /// scrobbling it would reset every tracker's REMOTE resume point to ~0:
  /// invisible on this device (local kept the bookmark) but lost on every
  /// other one, since resume takes the furthest of local and tracker.
  Duration get _persistablePosition {
    final heldMs = _resumeWriteGuard.heldTargetIfBlocked(
      _position.inMilliseconds,
    );
    if (heldMs == null) return _position;
    // The target was <80% of the duration AT ARM TIME, but _duration mirrors
    // mpv live and can transiently read short on a fresh remote stream ∫w^~)ﬁt
    // against which the held target could compute as >80% or >100% progress,
    // turning a tracker start/pause into a stop (a watched mark for content
    // playing at 0:00). Same rule as _saveResume's short-duration skip: fall
    // back to the raw position for the few seconds the reading is off. A raw
    // ~0 start-scrobble in that window is the pre-guard behavior, not a new
    // harm.
    final durMs = _duration.inMilliseconds;
    if (durMs <= 0 || heldMs >= (durMs * 0.8).floor()) return _position;
    return Duration(milliseconds: heldMs);
  }

  double _traktProgress() {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return (_persistablePosition.inMilliseconds /
            _duration.inMilliseconds *
            100)
        .clamp(0.0, 100.0);
  }

  /// Resolve season/episode: prefer current playlist entry (tracks auto-advance),
  /// fall back to launch args, then filename parsing.
  ({int? season, int? episode}) _traktSeasonEpisode() {
    // Movies never have season/episode ∫w^~)ﬁt avoid filename false positives (e.g. "5.1" surround)
    if (widget.contentType == 'movie') {
      return (season: null, episode: null);
    }
    // Prefer current playlist entry ∫w^~)ﬁt correct even after auto-advance
    if (_activePlaylist != null &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      final info = SeriesParser.parseFilename(
        _activePlaylist![_currentIndex].title,
      );
      if (info.season != null && info.episode != null) {
        return (season: info.season, episode: info.episode);
      }
    }
    // Fallback: explicit launch args (single-stream series playback)
    if (widget.contentSeason != null && widget.contentEpisode != null) {
      return (season: widget.contentSeason, episode: widget.contentEpisode);
    }
    final info = SeriesParser.parseFilename(widget.title);
    return (season: info.season, episode: info.episode);
  }

  void _traktScrobble(String action) {
    if (_validationGateActive) return;
    if (!_traktScrobbleEnabled || widget.contentImdbId == null) return;
    final imdbId = widget.contentImdbId!;
    final progress = _traktProgress();
    final se = _traktSeasonEpisode();
    // Trakt rejects start/pause when progress > 80%"È›y¯ßy‘ send stop instead
    if ((action == 'start' || action == 'pause') && progress > 80) {
      action = 'stop';
    }
    if (_traktLastScrobbleAction == action) return;
    _traktLastScrobbleAction = action;
    switch (action) {
      case 'start':
        TraktService.instance.scrobbleStart(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        break;
      case 'pause':
        TraktService.instance.scrobblePause(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        break;
      case 'stop':
        TraktService.instance.scrobbleStop(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        break;
    }
  }

  /// Start periodic heartbeat to checkpoint progress to Trakt every 2 minutes.
  void _startTraktHeartbeat() {
    _traktHeartbeatTimer?.cancel();
    _traktHeartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_validationGateActive ||
          !_traktScrobbleEnabled ||
          widget.contentImdbId == null) {
        return;
      }
      if (!_isPlaying || _duration.inMilliseconds <= 0) return;
      final imdbId = widget.contentImdbId!;
      final progress = _traktProgress();
      final se = _traktSeasonEpisode();
      // Trakt rejects start/pause above 80%+ßuÁ‚ùÁT send stop and end heartbeat
      if (progress > 80) {
        _traktLastScrobbleAction = 'stop';
        TraktService.instance.scrobbleStop(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        debugPrint(
          'Trakt: Heartbeat stop at ${progress.toStringAsFixed(1)}% (>80%)',
        );
        _stopTraktHeartbeat();
        return;
      }
      // Force-send start (bypass dedup) to keep session alive and checkpoint progress
      _traktLastScrobbleAction = 'start';
      TraktService.instance.scrobbleStart(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      debugPrint(
        'Trakt: Heartbeat scrobble at ${progress.toStringAsFixed(1)}%',
      );
    });
  }

  void _stopTraktHeartbeat() {
    _traktHeartbeatTimer?.cancel();
    _traktHeartbeatTimer = null;
  }

  /// Periodic analytics ping so a long, interaction-free watch keeps the
  /// analytics session alive. Independent of Trakt (fires regardless of Trakt
  /// auth); only emits while actually playing. No content details are sent.
  void _startAnalyticsHeartbeat() {
    _analyticsHeartbeatTimer?.cancel();
    _analyticsHeartbeatTimer = Timer.periodic(
      AnalyticsService.heartbeatInterval,
      (_) {
        if (_isPlaying) {
          AnalyticsService.playbackHeartbeat('dart');
        }
      },
    );
  }

  /// Send updated progress to Trakt after a user seek (bypasses dedup guard).
  ///
  /// This is also the shared funnel every user-initiated seek passes through
  /// (scrubber, tap/DPAD seek, pan, skip-segment), so it is where the resume
  /// write guard learns the user has taken over the position. Released before
  /// the Trakt-specific early returns below"È›y¯ßy‘ the handover happens whether or
  /// not Trakt is connected.
  void _traktScrobbleSeek(Duration seekTarget) {
    _resumeWriteGuard.noteUserSeek();
    if (_validationGateActive) return;
    if (!_traktScrobbleEnabled || widget.contentImdbId == null) return;
    if (!_isPlaying || _duration.inMilliseconds <= 0) return;
    final imdbId = widget.contentImdbId!;
    final progress =
        (seekTarget.inMilliseconds / _duration.inMilliseconds * 100).clamp(
          0.0,
          100.0,
        );
    final se = _traktSeasonEpisode();
    // Trakt rejects start above 80% ∫w^~)ﬁt send stop instead
    if (progress > 80) {
      _traktLastScrobbleAction = 'stop';
      TraktService.instance.scrobbleStop(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      _stopTraktHeartbeat();
    } else {
      _traktLastScrobbleAction = 'start';
      TraktService.instance.scrobbleStart(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      _startTraktHeartbeat();
    }
  }

  //"È›y¯ßy€ßuÁ‚ùÁ@ Simkl scrobble machine ∫w^~)ﬁt fully parallel mirror of the Trakt one above.
  // Zero shared state: its own enable flag, dedup guard and heartbeat, driven
  // by the same (tracker-agnostic) _traktProgress()/_traktSeasonEpisode()
  // helpers. See the Simkl integration plan.

  Future<void> _initSimklScrobble() async {
    if (!widget.simklScrobble) return;
    if (widget.contentImdbId == null) return;
    if (widget.contentType != 'movie' && widget.contentType != 'series') return;
    final policy = await TrackingSourcePolicy.load();
    _simklScrobbleEnabled =
        policy.scrobbles(TrackingSource.simkl) &&
        await SimklService.instance.isAuthenticated();
    if (!mounted) return;
    // Pause-centric model: do NOT POST Simkl's /scrobble/start. Unlike Trakt,
    // it persists NO resumable position AND deletes the existing /sync/playback
    // entry (verified: returns id:0, wipes the session). We leave the resume
    // point untouched and let the pause-based heartbeat keep it current.
    // BUT still stamp the marker 'start' (no POST)"È›y¯ßy‘ the local action marker
    // must read "playing" so a later user-pause / exit-stop isn't dedup-
    // suppressed at _simklScrobble's guard. Mirrors the Trakt block and the TV
    // launcher's self-healing marker. (Field assignment, NOT _simklScrobble
    // ('start'), which now routes to a pause POST.)
    if (!_validationGateActive &&
        _simklScrobbleEnabled &&
        _isPlaying &&
        _duration > Duration.zero) {
      _simklLastScrobbleAction = 'start';
      _startSimklHeartbeat();
    }
  }

  /// A series whose season/episode can't be resolved must NOT be scrobbled to
  /// Simkl: [SimklService._scrobble] would send the show id in a movie-shaped
  /// body, recording a bogus movie on the account. A movie legitimately has
  /// (null, null), so this only blocks the series case. (Trakt has the same
  /// latent gap; this guard is Simkl-only per the no-touch-Trakt convention.)
  bool _simklSeriesSEUnresolved(({int? season, int? episode}) se) =>
      widget.contentType == 'series' &&
      (se.season == null || se.episode == null);

  void _simklScrobble(String action) {
    if (_validationGateActive) return;
    if (!_simklScrobbleEnabled || widget.contentImdbId == null) return;
    final imdbId = widget.contentImdbId!;
    final progress = _traktProgress();
    final se = _traktSeasonEpisode();
    if (_simklSeriesSEUnresolved(se)) return;
    // Simkl marks watched server-side at+ßuÁ‚ùÁe80% on stop ∫w^~)ﬁt mirror Trakt's rule
    // and finalize instead of keeping a start/pause session alive.
    if ((action == 'start' || action == 'pause') && progress > 80) {
      action = 'stop';
    }
    if (_simklLastScrobbleAction == action) return;
    _simklLastScrobbleAction = action;
    switch (action) {
      // 'start' shares the pause path (no caller passes it in the pause-centric
      // model; play stamps the marker directly). Kept defensive and merged so
      // the two can't silently diverge: NEVER send Simkl's /scrobble/start ∫w^~)ﬁt it
      // persists nothing and wipes the resume point, so a 'start' intent maps to
      // a pause checkpoint.
      case 'start':
      case 'pause':
        SimklService.instance.scrobblePause(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        break;
      case 'stop':
        SimklService.instance.scrobbleStop(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        break;
    }
  }

  /// Periodic Simkl checkpoint ∫w^~)ﬁt comfortably above Simkl's 20-second per-user
  /// scrobble rate lock. Uses /scrobble/pause (NOT /scrobble/start): on Simkl,
  /// start returns id:0 and persists NO resumable position"È›y¯ßy‘ only pause/stop
  /// create the /sync/playback entry that Continue Watching + episode-card
  /// resume read. So the heartbeat pauses to keep a resume point current every
  /// interval; a hard kill (SIGINT/power-off, no graceful stop) then still
  /// resumes from the last checkpoint instead of the episode start.
  void _startSimklHeartbeat() {
    _simklHeartbeatTimer?.cancel();
    _simklHeartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_validationGateActive ||
          !_simklScrobbleEnabled ||
          widget.contentImdbId == null) {
        return;
      }
      if (!_isPlaying || _duration.inMilliseconds <= 0) return;
      final imdbId = widget.contentImdbId!;
      final progress = _traktProgress();
      final se = _traktSeasonEpisode();
      if (_simklSeriesSEUnresolved(se)) return;
      if (progress > 80) {
        _simklLastScrobbleAction = 'stop';
        SimklService.instance.scrobbleStop(
          imdbId,
          progress,
          season: se.season,
          episode: se.episode,
        );
        debugPrint(
          'Simkl: Heartbeat stop at ${progress.toStringAsFixed(1)}% (>80%)',
        );
        _stopSimklHeartbeat();
        return;
      }
      // Force-send pause (direct call, bypasses dedup) to checkpoint a RESUMABLE
      // position. Simkl's /scrobble/start saves nothing (id:0); only pause/stop
      // persist to /sync/playback, so this must be pause to survive a hard kill.
      // Leave the marker 'start' (live), NOT 'pause': stamping 'pause' here would
      // make the user's real pause dedup-suppress at _simklScrobble and strand
      // the true pause position at this (older) heartbeat %.
      _simklLastScrobbleAction = 'start';
      SimklService.instance.scrobblePause(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      debugPrint(
        'Simkl: Heartbeat pause checkpoint at ${progress.toStringAsFixed(1)}%',
      );
    });
  }

  void _stopSimklHeartbeat() {
    _simklHeartbeatTimer?.cancel();
    _simklHeartbeatTimer = null;
  }

  /// Simkl reaction to a user seek. Deliberately TRANSITION-ONLY, unlike
  /// Trakt's seek handler which re-sends start with fresh progress on every
  /// seek: Simkl's docs say not to call /scrobble/start on seek events (plus
  /// a 20s rate lock), so this only acts when the seek changes the effective
  /// action+ßuÁ‚ùÁT crossing the 80% boundary *È›y¯ßy“ stop), or seeking back below it
  /// after a stop *È›y¯ßy“ a new start). The 2-minute heartbeat carries fresh
  /// progress either way.
  void _simklScrobbleSeek(Duration seekTarget) {
    if (_validationGateActive) return;
    if (!_simklScrobbleEnabled || widget.contentImdbId == null) return;
    if (!_isPlaying || _duration.inMilliseconds <= 0) return;
    final imdbId = widget.contentImdbId!;
    final progress =
        (seekTarget.inMilliseconds / _duration.inMilliseconds * 100).clamp(
          0.0,
          100.0,
        );
    final se = _traktSeasonEpisode();
    if (_simklSeriesSEUnresolved(se)) return;
    if (progress > 80 && _simklLastScrobbleAction != 'stop') {
      _simklLastScrobbleAction = 'stop';
      SimklService.instance.scrobbleStop(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      _stopSimklHeartbeat();
    } else if (progress <= 80 && _simklLastScrobbleAction == 'stop') {
      // Seeked back under 80% after a finalize+ßuÁ‚ùÁT re-establish a RESUMABLE
      // session via pause (start would wipe it and persist nothing) and resume
      // the heartbeat.
      _simklLastScrobbleAction = 'pause';
      SimklService.instance.scrobblePause(
        imdbId,
        progress,
        season: se.season,
        episode: se.episode,
      );
      _startSimklHeartbeat();
    }
  }

  MdblistScrobbleTarget? _mdblistTarget() {
    final imdbId = widget.contentImdbId;
    if (imdbId == null || imdbId.isEmpty) return null;
    final ids = MdblistMediaIds(imdb: imdbId);
    if (widget.contentType == 'movie') {
      return MdblistScrobbleTarget.movie(ids);
    }
    if (widget.contentType != 'series') return null;
    final se = _traktSeasonEpisode();
    if (se.season == null || se.episode == null) return null;
    return MdblistScrobbleTarget.episode(
      ids,
      season: se.season!,
      episode: se.episode!,
    );
  }

  Future<void> _initMdblistScrobble() async {
    debugPrint(
      '[MDBListDiag] player init requested=${widget.mdblistScrobble} '
      'flag=$kMdblistEnabled imdb=${widget.contentImdbId} '
      'type=${widget.contentType}',
    );
    if (!widget.mdblistScrobble || !kMdblistEnabled) {
      debugPrint('[MDBListDiag] player init skipped: tracking not requested');
      return;
    }
    final policy = await TrackingSourcePolicy.load();
    if (!policy.scrobbles(TrackingSource.mdblist)) return;
    // Playlist launches resolve their requested/resume episode asynchronously.
    // Before that finishes `_currentIndex` is still zero, so constructing the
    // MDBList target here used to scrobble S1E1 while the player actually
    // opened (for example) S1E8. Wait until `_initializePlayer` publishes the
    // real initial index; its playing-state check below still starts tracking
    // immediately when media became ready during the wait.
    try {
      await _playerInitializationFuture;
    } catch (e) {
      debugPrint('[MDBListDiag] player init skipped: player setup failed $e');
      return;
    }
    if (!mounted) return;
    // The launcher already resolved the effective sync+authentication setting
    // before deciding both remote ownership and local-completion suppression.
    // Re-resolving it here could disagree with that launch snapshot and leave
    // the play tracked nowhere; the session capability below still prevents a
    // stale profile/account from receiving writes.
    final target = _mdblistTarget();
    if (target == null) {
      debugPrint('[MDBListDiag] player init skipped: invalid target metadata');
      return;
    }
    final capability = await MdblistService.instance
        .capturePlaybackCapability();
    if (!mounted) {
      debugPrint('[MDBListDiag] player init abandoned: player unmounted');
      return;
    }
    final session = MdblistScrobbleSession.forService(
      service: MdblistService.instance,
      target: target,
      capability: capability,
    );
    session.updatePosition(_position, _duration);
    _mdblistSession = session;
    debugPrint(
      '[MDBListDiag] player session ready imdb=${target.ids.imdb} '
      'episode=${target.isEpisode} playing=$_isPlaying '
      'positionMs=${_position.inMilliseconds} '
      'durationMs=${_duration.inMilliseconds}',
    );
    if (!_validationGateActive && _isPlaying && _duration > Duration.zero) {
      session.play();
    }
  }

  void _updateMdblistPosition() {
    if (_validationGateActive) return;
    // Held-target substitution, same reason as _traktProgress.
    _mdblistSession?.updatePosition(_persistablePosition, _duration);
  }

  void _mdblistPlay() {
    if (_validationGateActive) return;
    _updateMdblistPosition();
    _mdblistSession?.play();
  }

  void _mdblistPause() {
    if (_validationGateActive) return;
    _updateMdblistPosition();
    _mdblistSession?.pause();
  }

  void _mdblistStop({bool complete = false}) {
    if (_validationGateActive) return;
    _updateMdblistPosition();
    debugPrint(
      '[MDBListDiag] player stop complete=$complete '
      'session=${_mdblistSession != null} '
      'positionMs=${_position.inMilliseconds} '
      'durationMs=${_duration.inMilliseconds}',
    );
    if (complete) {
      _mdblistSession?.complete();
    } else {
      _mdblistSession?.exit();
    }
  }

  void _mdblistScrobbleSeek(Duration target) {
    if (_validationGateActive) return;
    _mdblistSession?.seek(target, _duration);
  }

  void _resumeTrackingAfterValidationGate() {
    if (!mounted || _validationGateActive) return;
    _updateMdblistPosition();
    if (!_isPlaying || _duration <= Duration.zero) return;
    _traktScrobble('start');
    if (_traktLastScrobbleAction == 'start') _startTraktHeartbeat();
    if (_simklScrobbleEnabled) {
      // Simkl uses a local playing marker and pause-based checkpoints; sending
      // its remote "start" would erase the resumable playback entry.
      _simklLastScrobbleAction = 'start';
      _startSimklHeartbeat();
    }
    _mdblistPlay();
  }

  Future<void> _switchMdblistTarget() async {
    if (_validationGateActive) return;
    final target = _mdblistTarget();
    if (target == null) {
      _mdblistSession?.exit();
      return;
    }
    await _mdblistSession?.switchTarget(target);
  }

  /// The current episode's cross-device Trakt progress percent (0-100), or null.
  /// Loaded once per series from the dedicated store (kept apart from the
  /// ms-based resume state) and looked up by the current episode's season/episode.
  void _bindEpisodeTrackerProgressIdentity(String imdbId) {
    if (_episodeTrackerProgressImdbId == imdbId) return;
    _episodeTrackerProgressImdbId = imdbId;
    _traktEpisodeProgress = null;
    _simklEpisodeProgress = null;
    _mdblistEpisodeProgress = null;
  }

  Future<double?> _currentEpisodeTraktPercent({bool forGuide = false}) async {
    final policy = await TrackingSourcePolicy.load();
    if (!forGuide && !policy.progressFrom(TrackingSource.trakt)) return null;
    final imdbId = _currentSeriesImdbId;
    if (imdbId == null) return null;
    _bindEpisodeTrackerProgressIdentity(imdbId);

    // Await BEFORE reading _currentIndex/season/episode below, so that if the
    // user advances to a different episode while this is in flight, we key
    // off the episode that's actually current when the fetch resolves.
    if (_traktEpisodeProgress == null) {
      final loaded = await StorageService.getEpisodeTraktProgress(
        imdbId: imdbId,
      );
      if (_episodeTrackerProgressImdbId != imdbId) return null;
      _traktEpisodeProgress = loaded;
    }

    int? season;
    int? episode;
    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null && seriesPlaylist.isSeries) {
      final playlist = _activePlaylist;
      if (playlist == null ||
          _currentIndex < 0 ||
          _currentIndex >= playlist.length) {
        return null;
      }
      // Must be the CURRENT episode"È›y¯ßy‘ no orElse-to-first fallback, or we'd seek to
      // an unrelated episode's Trakt position on filtered/reordered playlists.
      SeriesEpisode? ep;
      for (final e in seriesPlaylist.allEpisodes) {
        if (e.originalIndex == _currentIndex) {
          ep = e;
          break;
        }
      }
      if (ep == null) return null;
      season = ep.seriesInfo.season;
      episode = ep.seriesInfo.episode;
    } else if (_effectiveContentType == 'series') {
      // Single-file episode (e.g. a direct-link stream)"È›y¯ßy‘ no playlist to derive
      // season/episode from; fall back to the same launch args the local
      // resume-state lookup uses.
      season = _effectiveContentSeason;
      episode = _effectiveContentEpisode;
    }
    if (season == null || episode == null) return null;

    final percent = _traktEpisodeProgress!['${season}_$episode'];
    return forGuide
        ? policy.guideProgressFrom(TrackingSource.trakt, percent)
        : percent;
  }

  /// Current episode's Simkl snapshot percent. This mirrors the Trakt lookup
  /// above but remains independently stored so remote unwatch changes never
  /// mutate local playback history.
  Future<double?> _currentEpisodeSimklPercent({bool forGuide = false}) async {
    final policy = await TrackingSourcePolicy.load();
    if (!forGuide && !policy.progressFrom(TrackingSource.simkl)) return null;
    final imdbId = _currentSeriesImdbId;
    if (imdbId == null) return null;
    _bindEpisodeTrackerProgressIdentity(imdbId);

    // Await before resolving the episode identity for the same race-safety as
    // [_currentEpisodeTraktPercent].
    if (_simklEpisodeProgress == null) {
      final loaded = await StorageService.getEpisodeSimklProgress(
        imdbId: imdbId,
      );
      if (_episodeTrackerProgressImdbId != imdbId) return null;
      _simklEpisodeProgress = loaded;
    }

    int? season;
    int? episode;
    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null && seriesPlaylist.isSeries) {
      final playlist = _activePlaylist;
      if (playlist == null ||
          _currentIndex < 0 ||
          _currentIndex >= playlist.length) {
        return null;
      }
      SeriesEpisode? currentEpisode;
      for (final candidate in seriesPlaylist.allEpisodes) {
        if (candidate.originalIndex == _currentIndex) {
          currentEpisode = candidate;
          break;
        }
      }
      if (currentEpisode == null) return null;
      season = currentEpisode.seriesInfo.season;
      episode = currentEpisode.seriesInfo.episode;
    } else if (_effectiveContentType == 'series') {
      season = _effectiveContentSeason;
      episode = _effectiveContentEpisode;
    }
    if (season == null || episode == null) return null;

    final percent = _simklEpisodeProgress!['${season}_$episode'];
    return forGuide
        ? policy.guideProgressFrom(TrackingSource.simkl, percent)
        : percent;
  }

  Future<double?> _currentEpisodeMdblistPercent({bool forGuide = false}) async {
    final policy = await TrackingSourcePolicy.load();
    if (!forGuide && !policy.progressFrom(TrackingSource.mdblist)) return null;
    final imdbId = _currentSeriesImdbId;
    if (imdbId == null) return null;
    _bindEpisodeTrackerProgressIdentity(imdbId);
    if (_mdblistEpisodeProgress == null) {
      final loaded = await StorageService.getEpisodeMdblistProgress(
        imdbId: imdbId,
      );
      if (_episodeTrackerProgressImdbId != imdbId) return null;
      _mdblistEpisodeProgress = loaded;
    }
    final se = _traktSeasonEpisode();
    if (se.season == null || se.episode == null) return null;
    final percent = _mdblistEpisodeProgress!['${se.season}_${se.episode}'];
    return forGuide
        ? policy.guideProgressFrom(TrackingSource.mdblist, percent)
        : percent;
  }

  Future<void> _showExternalAudioPicker() async {
    final channels = _effectiveIptvChannels ??
        widget.iptvChannels ??
        const <IptvChannel>[];
    if (channels.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No IPTV channels are available for external audio')),
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExternalAudioSheet(
        channels: channels,
        currentVideoUrl: _currentIptvChannel?.url ?? widget.videoUrl,
        selectedUrl: _externalIptvAudioUrl,
        syncSeconds: _externalIptvAudioSyncSeconds,
        onSelected: _selectExternalIptvAudio,
        onRemove: _removeExternalIptvAudio,
        onSyncChanged: _setExternalIptvAudioSync,
      ),
    );
  }

  Future<void> _selectExternalIptvAudio(IptvChannel channel) async {
    if (!mounted) return;
    final ticket = _iptvSwitchTicket;
    try {
      await _setExternalAudioTrack(channel.url);
      if (!mounted || ticket != _iptvSwitchTicket) return;
      setState(() {
        _externalIptvAudioUrl = channel.url;
        _externalIptvAudioName = channel.numberedName;
        _externalIptvAudioSyncSeconds = 0.0;
      });
      await _setExternalIptvAudioSync(0.0);
      debugPrint(
        'VideoPlayer: selected IPTV external audio channel '
        '${channel.numberedName}',
      );
    } catch (e) {
      debugPrint('VideoPlayer: IPTV external audio selection failed: $e');
      rethrow;
    }
  }

  Future<void> _removeExternalIptvAudio() async {
    ++_externalAudioGeneration;
    final audio = _externalAudioPlayer;
    try {
      await audio?.stop();
      await audio?.setVolume(0.0);
    } catch (e) {
      debugPrint('VideoPlayer: failed to stop external audio: $e');
    }

    // Stop the secondary output first, then restore the main audio chain. This
    // prevents the handoff from briefly running two live outputs.
    await _restoreMainAudioAfterExternal();

    if (!mounted) return;
    setState(() {
      _externalIptvAudioUrl = null;
      _externalIptvAudioName = null;
      _externalIptvAudioSyncSeconds = 0.0;
    });
    await _setExternalIptvAudioSync(0.0);
  }

  Future<void> _setExternalIptvAudioSync(double seconds) async {
    final clamped = seconds.clamp(-30.0, 30.0).toDouble();
    // External IPTV audio has its own libmpv handle. Never modify the main
    // video player's audio-delay while the secondary stream is active.
    final audio = _externalAudioPlayer;
    if (audio != null) {
      try {
        final audioPlatform = audio.platform;
        if (audioPlatform is mk.NativePlayer) {
          await audioPlatform.setProperty(
            'audio-delay',
            clamped.toString(),
          );
        }
      } catch (e) {
        debugPrint('VideoPlayer: failed to update external audio sync: $e');
      }
    }
    if (mounted) {
      setState(() => _externalIptvAudioSyncSeconds = clamped);
    }
  }

  Future<void> _clearExternalIptvAudioForVideoSwitch() async {
    if (_externalIptvAudioUrl == null) return;
    await _removeExternalIptvAudio();
  }

  /// Load an external audio track to play alongside a video-only stream
  /// (high-res YouTube serves video and audio separately). Uses media_kit's
  /// AudioTrack.uri (mpv `audio-add`), which is URL-safe+ßuÁ‚ùÁT unlike the
  /// `audio-files` path-list option, which mangles URLs on the `:`/`,`
  /// separators. Must be called AFTER the main media has loaded.
  Future<void> _ensureExternalAudioPlayer() async {
    if (_externalAudioPlayer != null) return;

    // Keep the secondary player strictly audio-only and much smaller than the
    // main player. This avoids a second 32 MB disk-backed IPTV cache competing
    // with the main high-resolution video stream.
    final player = mk.Player(
      configuration: mk.PlayerConfiguration(
        vo: 'null',
        bufferSize: 16 * 1024 * 1024,
        title: 'Debrify External Audio',
        logLevel: mk.MPVLogLevel.error,
      ),
    );
    _externalAudioPlayer = player;

    // NativePlayer starts with vid=no before mpv initialization. There is no
    // VideoController for this player, and the output is explicitly null.
    // Use Android AudioTrack for the external stream instead of the default
    // OpenSL ES path so the secondary stream does not compete for the same
    // low-latency audio path as the main player.
    final platform = player.platform;
    if (platform is mk.NativePlayer) {
      try {
        await platform.setProperty('vid', 'no');
        await platform.setProperty('vo', 'null');
        await platform.setProperty('audio-display', 'no');
        await platform.setProperty('ao', 'audiotrack');
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('cache-on-disk', 'no');
      } catch (e) {
        debugPrint('VideoPlayer: external audio player setup failed: $e');
      }
    }
  }

  Future<void> _disableMainAudioForExternal() async {
    if (_externalAudioPreviousMainAid != null) return;
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) return;
    try {
      final aid = await platform.getProperty('aid');
      if (aid.isEmpty) return;
      _externalAudioPreviousMainAid = aid;
      if (aid != 'no') {
        await platform.setProperty('aid', 'no');
      }
      debugPrint(
        'VideoPlayer: disabled main audio while external IPTV audio is active '
        '(previous aid=$aid)',
      );
    } catch (e) {
      debugPrint('VideoPlayer: failed to disable main audio: $e');
    }
  }

  Future<void> _restoreMainAudioAfterExternal() async {
    final previousAid = _externalAudioPreviousMainAid;
    _externalAudioPreviousMainAid = null;
    if (previousAid == null || previousAid.isEmpty || previousAid == 'no') {
      return;
    }
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) return;
    try {
      await platform.setProperty('aid', previousAid);
      debugPrint(
        'VideoPlayer: restored main audio after external IPTV audio '
        '(aid=$previousAid)',
      );
    } catch (e) {
      debugPrint('VideoPlayer: failed to restore main audio: $e');
    }
  }

  Future<void> _syncExternalAudioToVideoPosition({
    bool force = false,
  }) async {
    final audio = _externalAudioPlayer;
    if (audio == null || _externalAudioSyncInFlight) return;
    if (_effectiveIptvChannels != null || _duration <= Duration.zero) return;

    final videoPosition = _position;
    if (videoPosition <= Duration.zero) return;
    final drift = videoPosition - audio.state.position;
    if (!force && drift.abs() < const Duration(milliseconds: 900)) return;

    final now = DateTime.now();
    if (!force &&
        _externalAudioLastCorrection != null &&
        now.difference(_externalAudioLastCorrection!) <
            const Duration(seconds: 2)) {
      return;
    }

    _externalAudioSyncInFlight = true;
    _externalAudioLastCorrection = now;
    try {
      await audio.seek(videoPosition);
    } catch (e) {
      debugPrint('VideoPlayer: external audio position sync failed: $e');
    } finally {
      _externalAudioSyncInFlight = false;
    }
  }

  Future<void> _setExternalAudioTrack(String audioUrl) async {
    final generation = ++_externalAudioGeneration;
    try {
      await _ensureExternalAudioPlayer();
      final audio = _externalAudioPlayer;
      if (audio == null) return;

      // Remove the main player's active audio chain before the external output
      // starts. This leaves one live Android audio output during the dual-source
      // session and saves the main player from decoding unused audio.
      await _disableMainAudioForExternal();
      await audio.stop();
      await audio.setVolume(0.0);

      if (generation != _externalAudioGeneration || !mounted) return;

      // Start directly in playing state. The old path waited up to 8 seconds
      // for a playing event before unmuting, which added unnecessary startup
      // latency and kept the selection operation open much longer than needed.
      await audio.open(mk.Media(audioUrl), play: true);

      if (generation != _externalAudioGeneration || !mounted) return;

      if (_effectiveIptvChannels == null && _position > Duration.zero) {
        try {
          await audio.seek(_position);
        } catch (e) {
          debugPrint('VideoPlayer: external audio initial seek skipped: $e');
        }
      }

      if (generation != _externalAudioGeneration || !mounted) return;
      await audio.setVolume(100.0);
      unawaited(_syncExternalAudioToVideoPosition(force: true));
    } catch (e) {
      await _restoreMainAudioAfterExternal();
      debugPrint('VideoPlayer: failed to set external audio track: $e');
    }
  }

  /// Put Android audio on an effects-capable output and announce the session,
  /// so system effect apps (Wavelet, OEM equalizers, hearing-accessibility
  /// tools) can process our playback like they do for other video apps.
  ///
  /// Two separate things block that by default:
  ///
  ///  1. media_kit pins Android to `ao=opensles`, and mpv's OpenSL ES output
  ///     never sets SL_ANDROID_KEY_PERFORMANCE_MODE ∫w^~)ﬁt so Android applies its
  ///     default low-latency path, which is documented to carry *no* hardware
  ///     or software effects. Nothing can attach to our audio at all, which is
  ///     why even a global/"legacy mode" equalizer has no effect on us.
  ///     `audiotrack` is an ordinary AudioTrack and is effects-capable; the
  ///     `opensles` fallback keeps today's behaviour on any device where
  ///     AudioTrack fails to initialise, so audio can't be lost outright.
  ///  2. Effect apps attach to a session id learned from the standard OPEN
  ///     broadcast. mpv generates an id internally and tells nobody, so we pin
  ///     our own via `audiotrack-session-id` and announce that.
  ///
  /// Fails soft at every step: effects are a nice-to-have, playback is not.
  /// Opt-in (Settings ∫w^~)ﬁv Player Settings): switching the audio backend is a real
  /// change to how every device outputs sound, so off must leave playback byte
  /// for byte as it was.
  Future<void> _attachAudioEffectSession() async {
    if (!Platform.isAndroid) return;
    // Everything below is inside the catch: _initializePlayer() runs
    // unawaited, so anything that escapes here would abort the rest of init
    // and leave a black screen+ßuÁ‚ùÁT including for users who have this turned off,
    // since the settings read itself happens either way.
    try {
      final platform = _player.platform;
      if (platform is! mk.NativePlayer) return;
      // The CACHED field, deliberately: [_configurePlayerAudio] chose the
      // audio output from it, and a fresh preference read here could
      // diverge mid-session ∫w^~)ﬁt announcing a session on an output that was
      // never switched, or vice versa. "Restart playback to apply" is the
      // settings contract for both halves.
      if (!_systemAudioEffectsEnabled) return;
      // `ao=audiotrack,...` itself is owned by [_configurePlayerAudio] now
      // (the passthrough setting needs the same output, and two writers of
      // `ao` is how the two settings would fight) ∫w^~)ﬁt this method keeps only
      // the session-id half.
      final sessionId = await AudioEffectSessionService.generateSessionId();
      // No id available: still worth keeping the effects-capable output, since
      // effect apps that detect sessions on their own can then attach.
      if (sessionId == null) return;
      await platform.setProperty('audiotrack-session-id', '$sessionId');
      await AudioEffectSessionService.open(sessionId);
      _audioEffectSessionId = sessionId;
    } catch (e) {
      debugPrint('VideoPlayer: audio effect session setup failed: $e');
    }
  }

  /// Release the announced audio session. Unpaired OPENs leave effect apps
  /// attached to dead audio and degrade *other* apps' equalizers, so this must
  /// run on every exit from the player.
  void _releaseAudioEffectSession() {
    final sessionId = _audioEffectSessionId;
    if (sessionId == null) return;
    _audioEffectSessionId = null;
    AudioEffectSessionService.close(sessionId);
  }

  /// This player's claim on the process's one video output.
  ///
  /// HELD for the controller's lifetime rather than taken as a momentary
  /// barrier. A barrier that released before construction left a gap: a trailer
  /// parked on the lease would be granted it and build its own output while
  /// this player was still constructing"È›y¯ßy‘ the two-output case, which is a
  /// SIGABRT on tvOS.
  VideoOutputLeaseHandle? _outputLease;

  /// Take the slot before building a controller.
  ///
  /// The ambient trailer surfaces tear down when playback launches, but the
  /// native release is asynchronous+ßuÁ‚ùÁT "teardown was requested" is not "the
  /// output is gone".
  ///
  /// **Bounded, deliberately.** Review pushed back on this twice: a timeout
  /// that proceeds can, in principle, recreate the two-output case. The
  /// judgement here is that an unbounded wait turns a stuck native disposal
  /// into "video never plays again this session", which is a worse and far more
  /// likely outcome than the crash it guards against ∫w^~)ﬁt and by the time three
  /// seconds have passed, something is already wrong. It logs, and it still
  /// takes the slot when it finally frees, so the player never ends up
  /// untracked.
  ///
  /// tvOS waits longer before giving up: proceeding into the overlap is a
  /// certain SIGABRT there, and since the native Dispose handshake became
  /// completion-gated (mpv render context freed before the channel call
  /// returns) a held lease reliably frees ∫w^~)ﬁt a slow release is a wait, not a
  /// lockout.
  static final Duration _outputLeaseTimeout = PlatformUtil.isTvOS
      ? const Duration(seconds: 10)
      : const Duration(seconds: 3);

  Future<void> _claimVideoOutput() async {
    if (_outputLease != null) return; // renderer fallback reuses the claim
    if (!VideoOutputLease.isHeld) {
      final handle = await VideoOutputLease.acquire(debugLabel: 'player');
      if (_screenDisposed) {
        handle.release();
        return;
      }
      _outputLease = handle;
      return;
    }
    final pending = VideoOutputLease.acquire(debugLabel: 'player');
    VideoOutputLeaseHandle? handle;
    try {
      handle = await pending.timeout(_outputLeaseTimeout);
    } on TimeoutException {
      debugPrint(
        'VideoOutputLease: player proceeding without the slot+ßuÁ‚ùÁT a previous '
        'video output has not released after '
        '${_outputLeaseTimeout.inSeconds}s.',
      );
      // The wait was abandoned, not cancelled. Take the slot whenever it does
      // arrive rather than handing it back: this player IS alive and holding a
      // video output, so releasing would leave it untracked and let a trailer
      // build a second one beside it.
      unawaited(
        pending.then((late) {
          if (_screenDisposed || _outputLease != null) {
            late.release();
          } else {
            _outputLease = late;
          }
        }),
      );
    }
    if (_screenDisposed) {
      handle?.release();
      return;
    }
    _outputLease = handle;
  }

  void _releaseVideoOutput() {
    _outputLease?.release();
    _outputLease = null;
  }

  /// Set once `dispose()` has run, so a claim still in flight at that moment
  /// gives the slot straight back instead of being stranded by the `!mounted`
  /// return at its call site"È›y¯ßy‘ which would block every future trailer engine
  /// for the rest of the session.
  bool _screenDisposed = false;

  void _createPlayerInstance(AndroidVideoRendererMode rendererMode) {
    final instanceGeneration = ++_playerInstanceGeneration;
    _isReady = false;
    final player = mk.Player(
      configuration: mk.PlayerConfiguration(
        logLevel: mk.MPVLogLevel.error,
        ready: () => _onPlayerInstanceReady(instanceGeneration),
      ),
    );
    _player = player;
    _playerCreated = true;
    _videoController = mkv.VideoController(
      player,
      configuration: mkv.VideoControllerConfiguration(
        vo: rendererMode.videoOutput,
        // The tvOS escape hatch outranks the renderer mode (which is an
        // Android concept; its decoder string is null off-Android anyway).
        hwdec: PlatformUtil.isTvOS && _tvosForceSoftwareDecode
            ? 'no'
            : rendererMode.hardwareDecoder,
      ),
    );
    _installTvosDecodeRemedy(player);
    _bindPlayerInstanceSubscriptions(instanceGeneration, player);
    unawaited(_installDecoderObservers(instanceGeneration, player));
    unawaited(_applyAspectVideoZoom());
  }

  void _installSubtitleAutoSyncForPlayer(mk.Player player) {
    if (!_subtitleAutoSyncEnabled || !PlatformUtil.supportsSubtitleAutoSync) {
      debugPrint(
        'SubtitleAutoSync: not installing ∫w^~)ﬁt enabled=$_subtitleAutoSyncEnabled '
        'web=$kIsWeb platform=${Platform.operatingSystem}',
      );
      return;
    }
    final platform = player.platform;
    if (platform is! mk.NativePlayer) {
      debugPrint(
        'SubtitleAutoSync: not installing"È›y¯ßy‘ player backend is not NativePlayer '
        '(${platform.runtimeType})',
      );
      return;
    }
    debugPrint(
      'SubtitleAutoSync: controller installed '
      '(passthrough=${!kIsWeb && Platform.isAndroid && _audioPassthroughEnabled})',
    );
    _subtitleAutoSync = MediaKitSubtitleAutoSync(
      player: platform,
      enabled: _subtitleAutoSyncEnabled,
      passthroughEnabled:
          !kIsWeb && Platform.isAndroid && _audioPassthroughEnabled,
      currentPositionMs: () => _position.inMilliseconds,
      isPlaying: () => _isPlaying,
      currentOffsetMs: () => _subtitleSettings?.syncOffsetMs ?? 0,
      applyOffsetMs: _applyAutoSubtitleSyncOffset,
      onNotice: _showSubtitleAutoSyncNotice,
    );
  }

  Future<void> _disposeSubtitleAutoSync() async {
    final controller = _subtitleAutoSync;
    _subtitleAutoSync = null;
    _hideAutoSyncPill();
    await controller?.dispose();
  }

  Future<void> _applyAutoSubtitleSyncOffset(int milliseconds) async {
    final clamped = milliseconds.clamp(
      SubtitleSettingsService.syncOffsetMinMs,
      SubtitleSettingsService.syncOffsetMaxMs,
    );
    if (!mounted) return;
    _subtitleSettings = _subtitleSettings?.copyWith(syncOffsetMs: clamped);
    _applySubtitleSyncOffset(clamped);
    setState(() {});
    try {
      await SubtitleSettingsService.instance.setSyncOffsetMs(clamped);
    } catch (error) {
      // The live player already has the safe, bounded offset. A preference
      // write failure must not escape a timer callback or affect playback.
      debugPrint('SubtitleAutoSync: offset persistence failed: $error');
    }
  }

  void _showSubtitleAutoSyncNotice(SubtitleAutoSyncNotice notice) {
    if (!mounted) return;
    // Full detail (offsets, advice) lives here; the pill stays number-free.
    debugPrint('SubtitleAutoSync: ${notice.message}');
    switch (notice.kind) {
      case SubtitleAutoSyncNoticeKind.listening:
        // A fresh window: announce for ~5s, then go quiet until an event.
        _openAutoSyncPillWindow();
      case SubtitleAutoSyncNoticeKind.checking:
        // An alignment pass is genuinely running ∫w^~)ﬁt surface it, even if the
        // pill was idle-hidden in the meantime.
        if (_autoSyncWindowActive) {
          _autoSyncPillPhaseTimer?.cancel();
          _autoSyncPill.value = const AutoSyncPillModel(
            AutoSyncPillPhase.checking,
          );
        }
      case SubtitleAutoSyncNoticeKind.stillListening:
        // The pass ended with no verdict: leave the screen quiet again.
        if (_autoSyncWindowActive &&
            _autoSyncPill.value?.phase == AutoSyncPillPhase.checking) {
          _autoSyncPill.value = null;
        }
      case SubtitleAutoSyncNoticeKind.synced ||
          SubtitleAutoSyncNoticeKind.resynced:
        // A verify-pass re-sync corrects silently; only the first sync speaks.
        if (notice.kind == SubtitleAutoSyncNoticeKind.resynced &&
            !_autoSyncWindowActive &&
            _autoSyncPill.value == null) {
          return;
        }
        _showAutoSyncPillResult(AutoSyncPillPhase.synced);
      case SubtitleAutoSyncNoticeKind.failed:
        _showAutoSyncPillResult(AutoSyncPillPhase.failed);
    }
  }

  void _openAutoSyncPillWindow() {
    _autoSyncPillHold?.cancel();
    _autoSyncPillHold = null;
    _autoSyncWindowActive = true;
    _autoSyncPill.value = const AutoSyncPillModel(AutoSyncPillPhase.announce);
    _autoSyncPillPhaseTimer?.cancel();
    _autoSyncPillPhaseTimer = Timer(const Duration(seconds: 5), () {
      // The sentence had its moment; the screen goes quiet until a real
      // event (a checking pass or a verdict) has something to say.
      if (_autoSyncWindowActive &&
          _autoSyncPill.value?.phase == AutoSyncPillPhase.announce) {
        _autoSyncPill.value = null;
      }
    });
  }

  void _showAutoSyncPillResult(AutoSyncPillPhase phase) {
    _autoSyncWindowActive = false;
    _autoSyncPillPhaseTimer?.cancel();
    _autoSyncPillPhaseTimer = null;
    _autoSyncPillHold?.cancel();
    _autoSyncPill.value = AutoSyncPillModel(phase);
    _autoSyncPillHold = Timer(
      const Duration(milliseconds: 2400),
      _hideAutoSyncPill,
    );
  }

  void _hideAutoSyncPill() {
    _autoSyncWindowActive = false;
    _autoSyncPillPhaseTimer?.cancel();
    _autoSyncPillPhaseTimer = null;
    _autoSyncPillHold?.cancel();
    _autoSyncPillHold = null;
    if (_autoSyncPill.value != null) _autoSyncPill.value = null;
  }

  void _setActiveExternalSubtitlePath(String? path) {
    if (_activeExternalSubtitlePath == path) return;
    _activeExternalSubtitlePath = path;
    final controller = _subtitleAutoSync;
    debugPrint(
      'SubtitleAutoSync: external subtitle ${path == null ? 'cleared' : 'set'} '
      '(controller=${controller == null ? 'MISSING' : 'present'})',
    );
    if (controller == null) return;
    if (path == null) {
      unawaited(controller.deactivateSubtitle());
      _hideAutoSyncPill();
    } else {
      unawaited(controller.activateSubtitle(path));
    }
  }

  Future<void> _applyAspectVideoZoom() async {
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) return;
    final scale = AspectModeUtils.getScaleForMode(_aspectMode);
    final zoom = math.log(scale) / math.ln2;
    try {
      await platform.setProperty('video-zoom', zoom.toStringAsFixed(6));
    } catch (e) {
      debugPrint('VideoPlayer: aspect zoom apply failed: $e');
    }
  }

  /// Serializes live passthrough flips: each runs WHOLE, in order. Without
  /// this a rapid double-toggle could interleave two aid cycles and leave
  /// the newer one reading `aid=no` mid-way through the older one's cycle"È›y¯ßy‘
  /// stranding the player silent.
  Future<void> _passthroughFlipChain = Future<void>.value();

  /// The in-player passthrough flip+ßuÁ‚ùÁT persists the same setting the
  /// Playback Defaults row writes, applies the explicit property values
  /// (including the OFF restores), then cycles the audio track so the
  /// CURRENT file's audio chain re-initialises: `audio-spdif` is read at
  /// decoder init, and `ao` reloads on the reconfig. Sub-second audio gap,
  /// position untouched. Fails soft: playback outlives any of this (and
  /// mpv gives no rejection signal to roll a switch back on ∫w^~)ﬁt the toggle's
  /// caption owns the "silence means off" contract).
  Future<void> _setAudioPassthroughLive(bool enabled) {
    final flip = _passthroughFlipChain.then(
      (_) => _applyPassthroughFlip(enabled),
    );
    _passthroughFlipChain = flip.catchError((_) {});
    return flip;
  }

  Future<void> _applyPassthroughFlip(bool enabled) async {
    _audioPassthroughEnabled = enabled;
    try {
      await StorageService.setAudioPassthroughEnabled(enabled);
      // An audio filter would force compressed passthrough formats through a
      // PCM decoder. Remove the passive analysis chain before the aid cycle;
      // when passthrough is disabled, re-arm only after PCM output is restored.
      if (enabled) {
        await _subtitleAutoSync?.setPassthroughEnabled(true);
      }
      final platform = _player.platform;
      if (platform is! mk.NativePlayer) return;
      for (final (property, value)
          in PlayerAudioConfig.androidLiveToggleProperties(
            passthroughEnabled: enabled,
            systemAudioEffects: _systemAudioEffectsEnabled,
          )) {
        await platform.setProperty(property, value);
      }
      final aid = await platform.getProperty('aid');
      if (aid.isNotEmpty && aid != 'no') {
        await platform.setProperty('aid', 'no');
        await platform.setProperty('aid', aid);
      }
      if (!enabled) {
        await _subtitleAutoSync?.setPassthroughEnabled(false);
      }
    } catch (e) {
      debugPrint('VideoPlayer: live passthrough toggle failed: $e');
    }
  }

  /// The single owner of the player's audio-output properties ∫w^~)ﬁt ordered
  /// list from [PlayerAudioConfig], awaited before the first open, run at
  /// EVERY player-instance creation site (initial + the Android renderer
  /// fallback recreate). Fails soft per property: audio configuration is a
  /// nice-to-have, playback is not.
  Future<void> _configurePlayerAudio(mk.Player player) async {
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;
    final props = PlayerAudioConfig.audioProperties(
      isAndroid: !kIsWeb && Platform.isAndroid,
      isApple: PlatformUtil.isTvOS || PlatformUtil.isIosMobile,
      isTvOS: PlatformUtil.isTvOS,
      routeOutputChannels: _tvosRouteOutputChannels,
      tvosForceStereo: _tvosForceStereoAudio,
      tvosLegacyAudioOutput: _tvosLegacyAudioOutput,
      passthroughEnabled: _audioPassthroughEnabled,
      systemAudioEffects: _systemAudioEffectsEnabled,
      multichannelEnabled: _appleMultichannelEnabled,
    );
    for (final (property, value) in props) {
      try {
        await platform.setProperty(property, value);
      } catch (e) {
        debugPrint('VideoPlayer: audio config $property=$value failed: $e');
      }
    }
    // Preferred audio language, handed to mpv itself as `alang`. The Dart
    // matcher (_applyDefaultAudioLanguage) only runs after the track list
    // reaches Dart and only matches on metadata; mpv applies the preference
    // at stream selection, and its matcher also weighs the default/forced
    // dispositions. Users with no preference set send nothing.
    try {
      final lang = await StorageService.getDefaultAudioLanguage();
      if (lang != null && lang.isNotEmpty) {
        final alang = LanguageMapper.alangForCode(lang);
        if (alang.isNotEmpty) await platform.setProperty('alang', alang);
      }
    } catch (e) {
      debugPrint('VideoPlayer: alang config failed: $e');
    }
  }

  /// tvOS only: the 10-bit remedy ladder, bound to THIS player instance's
  /// property interface. Plain post-create property access"È›y¯ßy‘ deliberately
  /// not `mpv_observe_property` (see the SIGABRT note in
  /// [_installDecoderObservers]); the ladder is driven by the existing
  /// Dart-side videoParams stream instead.
  void _installTvosDecodeRemedy(mk.Player player) {
    if (!PlatformUtil.isTvOS) return;
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;
    _tvosDecodeRemedy?.dispose();
    _tvosDecodeRemedy = TvosDecodeRemedy(
      getProperty: platform.getProperty,
      setProperty: platform.setProperty,
      // The standard 8-bit-surface pin, applied before every file's decoder
      // exists: 8-bit content is NV12 already (no change), 10-bit decodes
      // straight to NV12 with no blue flash and no mid-play cycle. The
      // reactive ladder underneath only ever engages if VideoToolbox
      // rejects the pin for some exotic stream.
      pinNv12FromStart: true,
      // A settle is a decode-path change the one-shot probe has already
      // reported around ∫w^~)ﬁt re-arm it so the diagnostic line carries the
      // remedy journey.
      onStateChanged: () {
        if (mounted) _scheduleDecoderProbe();
      },
    );
  }

  void _onPlayerInstanceReady(int instanceGeneration) {
    if (!mounted || instanceGeneration != _playerInstanceGeneration) return;
    _isReady = true;
    _armPipAutoEnter();
    if (PlatformUtil.isTelevision && _controlsVisible.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Never while a guide/sheet is up: on tvOS IPTV the instance becomes
        // ready SECONDS after a zap (and again on remedy-ladder restarts), so
        // this fired after the sheet's one-shot focus claim and silently
        // yanked the remote off it+ßuÁ‚ùÁT the guide's focus went dead at random.
        if (mounted &&
            instanceGeneration == _playerInstanceGeneration &&
            _controlsVisible.value &&
            !_anyPlayerOverlayOpen &&
            !_tvBarScope.hasFocus) {
          _tvPlayPauseFocus.requestFocus();
        }
      });
    }
    setState(() {});

    // These are screen-presentation side effects, not player-instance setup.
    // Re-running them during the compatibility restart would re-raise launch
    // banners and reset guide context while preserving the same media item.
    if (_playerPresentationInitialized) return;
    _playerPresentationInitialized = true;
    final iptvChannel = _currentIptvChannel;
    if (iptvChannel != null && iptvChannel.isLive) {
      _hideTimer?.cancel();
      _controlsVisible.value = false;
      _prepareIptvBannerData(iptvChannel);
      _raiseIptvZapBanner();
      _anchorIptvGuideCategory(iptvChannel);
      _ensureIptvZapPagingArmed();
    } else {
      _raiseDebrifyBanner();
    }
  }

  Future<void> _initializePlayer() async {
    // Load default player settings
    await _loadPlayerDefaults();
    unawaited(_loadDockPrefs());
    if (Platform.isAndroid && !PlatformUtil.isAndroidTvCached) {
      _androidVideoRendererMode =
          await StorageService.getAndroidVideoRendererMode();
    }

    // Determine the initial URL and index
    String initialUrl = widget.videoUrl;
    var initialRankedAttemptFailed = false;
    int initialIndex = 0;

    if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
      // Initialize playlist

      // If auto-resume is disabled, use startIndex directly
      if (widget.disableAutoResume) {
        initialIndex = widget.startIndex ?? 0;
        debugPrint(
          'VideoPlayer: auto-resume disabled, using startIndex=$initialIndex',
        );
      } else {
        // Check if this is a series and we should find the first episode by season/episode
        final seriesPlaylist = _seriesPlaylist;
        if (seriesPlaylist != null && seriesPlaylist.isSeries) {
          // If a specific target episode was requested (e.g. quick play from Trakt),
          // jump directly to it instead of resuming from last played.
          bool targetEpisodeResolved = false;
          final hadExplicitTarget =
              widget.contentSeason != null && widget.contentEpisode != null;
          if (hadExplicitTarget) {
            final targetIndex = seriesPlaylist.findOriginalIndexBySeasonEpisode(
              widget.contentSeason!,
              widget.contentEpisode!,
            );
            if (targetIndex != -1) {
              initialIndex = targetIndex;
              targetEpisodeResolved = true;
              debugPrint(
                'VideoPlayer: target episode S${widget.contentSeason}E${widget.contentEpisode}"È›y¯ßy“ index=$initialIndex',
              );
            }
          }

          if (!targetEpisodeResolved) {
            // Only resume from the last-played episode when NO specific episode
            // was requested. If a target WAS requested but isn't in this pack
            // (e.g. "Next" with no bound source landed on a source that lacks
            // that episode), resuming would replay the last-played+ßuÁ‚ùÁT usually the
            // episode the user just finished+ßuÁ‚ùÁT which is the "Next replays the
            // same episode" bug. In that case skip straight to the first episode.
            final lastEpisode = hadExplicitTarget
                ? null
                : await _getLastPlayedEpisode(seriesPlaylist);
            if (lastEpisode != null) {
              debugPrint(
                'VideoPlayer: resume series "${seriesPlaylist.seriesTitle}" at S${lastEpisode['season']}E${lastEpisode['episode']} originalIndex=${lastEpisode['originalIndex']}',
              );
              initialIndex = lastEpisode['originalIndex'] as int;
            } else {
              // Find the first episode (lowest season, lowest episode)
              final firstEpisodeIndex = seriesPlaylist
                  .getFirstEpisodeOriginalIndex();
              if (firstEpisodeIndex != -1) {
                initialIndex = firstEpisodeIndex;
              } else {
                initialIndex = widget.startIndex ?? 0;
              }
              debugPrint(
                'VideoPlayer: no resume target for "${seriesPlaylist.seriesTitle}"'
                '${hadExplicitTarget ? ' (requested S${widget.contentSeason}E${widget.contentEpisode} not in pack)' : ''}, defaulting to index=$initialIndex',
              );
            }
          }
        } else {
          // For non-series playlists, try to restore the last played video
          if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
            // Try to find the last played video by checking each playlist entry
            int lastPlayedIndex = -1;
            Map<String, dynamic>? lastPlayedState;

            for (int i = 0; i < _activePlaylist!.length; i++) {
              final entry = _activePlaylist![i];
              final resumeId = _resumeIdForEntry(entry);
              debugPrint(
                'Resume: checking entry[$i] title="${entry.title}" resumeId=$resumeId',
              );
              final state = await StorageService.getVideoPlaybackState(
                videoTitle: resumeId,
              );
              if (state != null) {
                debugPrint(
                  'Resume: found state for entry[$i] resumeId=$resumeId updatedAt=${state['updatedAt']}',
                );
                final updatedAt = state['updatedAt'] as int? ?? 0;
                if (lastPlayedState == null ||
                    updatedAt > (lastPlayedState['updatedAt'] as int? ?? 0)) {
                  lastPlayedState = state;
                  lastPlayedIndex = i;
                }
              }
            }

            if (lastPlayedIndex != -1) {
              debugPrint('Resume: restoring playlist index $lastPlayedIndex');
              initialIndex = lastPlayedIndex;
            } else {
              debugPrint(
                'Resume: no prior playback state found, using default ordering',
              );
              // Pick the first item from Main group (by year asc then size desc)
              final indices = _getMainGroupIndices(_activePlaylist!);
              initialIndex = indices.isNotEmpty
                  ? indices.first
                  : (widget.startIndex ?? 0);
            }
          } else {
            // Not a series or no series playlist, use the provided startIndex
            initialIndex = widget.startIndex ?? 0;
          }
        }
      }
    } else {}

    // A stale launch index (resume record from a longer pack, negative
    // startIndex) must not reach list indexing: _currentIndex is used
    // unconditionally below and in later playback paths.
    if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
      initialIndex = initialIndex.clamp(0, _activePlaylist!.length - 1);
    }

    // Get the initial URL from the determined index
    if (_activePlaylist != null &&
        _activePlaylist!.isNotEmpty &&
        initialIndex < _activePlaylist!.length) {
      final entry = _activePlaylist![initialIndex];
      if (entry.url.isNotEmpty) {
        initialUrl = entry.url;
      } else {
        try {
          final resolvedUrl = await _resolvePlaylistEntryUrl(initialIndex);
          if (resolvedUrl.isNotEmpty) {
            initialUrl = resolvedUrl;
          } else if (widget.videoUrl.isNotEmpty) {
            initialUrl = widget.videoUrl;
          } else {
            initialRankedAttemptFailed = true;
          }
        } catch (e) {
          // Only fall back to widget.videoUrl if resolution fails
          if (widget.videoUrl.isNotEmpty) {
            initialUrl = widget.videoUrl;
          } else {
            initialRankedAttemptFailed = true;
          }
        }
      }
    }

    _currentIndex = initialIndex;
    _dynamicTitle = widget.title;
    await _claimVideoOutput();
    if (!mounted) return;
    _createPlayerInstance(_androidVideoRendererMode);
    await _configurePlayerAudio(_player);
    _installSubtitleAutoSyncForPlayer(_player);
    // libmpv exposes `stream-record`; the web backend does not. Gate the
    // record control on having a native player+ßuÁ‚ùÁT and, on Android, on the
    // finished file being publishable at all. Below API 29 there is no
    // MediaStore.Downloads and no WRITE_EXTERNAL_STORAGE, so a recording
    // could only sit in app-private storage the user can't reach ∫w^~)ﬁt offering
    // the button would just be a way to lose footage.
    //
    // Deny-by-default: Android starts unsupported and flips true only on a
    // positive probe. The opposite order would leave a rebuild window where
    // an API 2;ßuÁ‚ùÁS28 device shows Record, and a tap in that window starts a
    // recording whose Stop button the probe then hides.
    final nativeBackend = _player.platform is mk.NativePlayer;
    // A profile without the recordings feature never sees Record"È›y¯ßy‘ the
    // platform probe below must not be able to flip it back on.
    final recordingsAllowed = ProfilePolicyGuard.allowsSync(
      ProfileFeature.recordings,
    );
    _recordingSupported =
        recordingsAllowed && nativeBackend && !Platform.isAndroid;
    if (recordingsAllowed && nativeBackend && Platform.isAndroid) {
      unawaited(
        AndroidNativeDownloader.canPublishRecordings().then((canPublish) {
          if (!canPublish || !mounted) return;
          setState(() => _recordingSupported = true);
        }),
      );
      // Engine flag + any capture of this channel already running (a recording
      // started in an earlier player session survives into this one).
      unawaited(
        LiveRecordingService.engineEnabled().then((on) {
          if (!mounted) return;
          _engineFlagOn = on || ProfileRuntime.isProfileCommitted;
          if (_engineFlagOn) unawaited(_refreshEngineRecordingState());
        }),
      );
    }

    // Must happen before the first open()"È›y¯ßy‘ mpv reads both audio options when
    // it creates the audio output, which is on first playback.
    await _attachAudioEffectSession();

    _currentStreamUrl = initialUrl.isNotEmpty ? initialUrl : null;
    if (_activePlaylist != null &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      _activeHttpHeaders =
          _activePlaylist![_currentIndex].httpHeaders ?? widget.httpHeaders;
    }

    // IPTV launch: the first tune starts here, before either open branch
    // below (IPTV is never PikPak). Zaps re-arm this in _switchToIptvChannel.
    var launchIsLiveIptv = false;
    final launchIptvChannels = _effectiveIptvChannels;
    if (launchIptvChannels != null && initialUrl.isNotEmpty) {
      final launchIdx = widget.iptvStartIndex ?? 0;
      final launchChannel =
          (launchIdx >= 0 && launchIdx < launchIptvChannels.length)
          ? launchIptvChannels[launchIdx]
          : null;
      _iptvDiag.onTuneStart(
        launchChannel?.name,
        initialUrl,
        isLive: launchChannel?.isLive ?? true,
      );
      _iptvLiveRecovery.onTuneStarted();
      launchIsLiveIptv = launchChannel?.isLive ?? true;
    }

    final canAttemptRankedStartup =
        initialRankedAttemptFailed &&
        (_effectiveContentType == 'movie' ||
            _effectiveContentType == 'series') &&
        _effectiveSources?.isNotEmpty == true;

    // An empty initial URL caused by a failed lazy resolution is itself the
    // first failed candidate. Enter the ranked ladder so remaining sources
    // still get their configured attempts.
    if (initialUrl.isNotEmpty || canAttemptRankedStartup) {
      // For PikPak videos from playlist or any PikPak URL, use cold storage retry logic
      final currentEntry = _activePlaylist?[_currentIndex];
      final isPikPak =
          currentEntry?.provider?.toLowerCase() == 'pikpak' ||
          currentEntry?.pikpakFileId != null;
      // For non-playlist flows (Debrify TV, Stremio TV, etc.), detect PikPak by URL
      final isPikPakUrl =
          _activePlaylist == null && initialUrl.contains('mypikpak.com');
      final isDebrifyTV = isPikPakUrl && widget.requestMagicNext != null;

      if (initialUrl.isNotEmpty &&
          ((isPikPak && _activePlaylist != null) || isPikPakUrl)) {
        // The continuation can sleep up to 10s in _waitForVideoReady; the
        // screen may be left (player disposed) or the player replaced by a
        // renderer fallback in that window, so it must re-check before every
        // touch of _player.
        final pikpakGeneration = _playerInstanceGeneration;
        bool pikpakStillCurrent() =>
            mounted &&
            !_screenDisposed &&
            pikpakGeneration == _playerInstanceGeneration;
        final launchSource =
            _effectiveSources != null &&
                _currentSourceIndex >= 0 &&
                _currentSourceIndex < _effectiveSources!.length
            ? _effectiveSources![_currentSourceIndex]
            : null;
        _playPikPakVideoWithRetry(initialUrl, isDebrifyTV: isDebrifyTV).then((
          loaded,
        ) async {
          if (!pikpakStillCurrent()) return;
          if (!loaded) return;
          // PikPak uses its own cold-storage readiness gate instead of the
          // ranked VOD gate. Report the winner only after that gate confirms
          // duration, otherwise a queued-but-unplayable file would be pinned.
          unawaited(_commitValidatedStremioSource(launchSource));
          // Wait for the video to load and duration to be available
          await _waitForVideoReady();
          if (!pikpakStillCurrent()) return;
          // Random start takes precedence over resume, then startAtPercent.
          // Same initial-open shape as the ranked branch below"È›y¯ßy‘ and PikPak
          // cold-storage streams are the slowest remote opens in the app, the
          // likeliest to answer the startup seek with a restart at 0"È›y¯ßy‘ so the
          // same guarded, landing-verified seeks apply.
          if (widget.startFromRandom) {
            final offset = _randomStartOffset(_duration);
            if (offset != null) {
              // A random start has no bookmark to protect ∫w^~)ﬁt plain seek.
              await _player.seek(offset);
            } else {
              await _maybeRestoreResume(verifyLanding: true);
            }
          } else if (widget.startAtPercent != null) {
            final offset = _percentStartOffset(_duration);
            if (offset != null) {
              await _seekForResume(offset.inMilliseconds, verifyLanding: true);
            }
          } else {
            await _maybeRestoreResume(verifyLanding: true);
          }
          if (!pikpakStillCurrent()) return;
          // Restore audio and subtitle track preferences
          await _restoreTrackPreferences();
        });
      } else {
        // High-res YouTube serves video and audio as separate streams. Open
        // PAUSED, attach the external audio track, then start"È›y¯ßy‘ so both tracks
        // are loaded before the first frame and play in sync from the start.
        // (Attaching audio mid-playback makes mpv resync, causing a few seconds
        // of A/V drift.)
        final hasExternalAudio =
            widget.audioUrl != null && widget.audioUrl!.isNotEmpty;
        try {
          // Xtream VOD (movies and series episodes) is already a fully
          // resolved IPTV URL. Do not send it through the generic Stremio/debrid
          // startup validation gate: that gate requires the playback clock to
          // advance before accepting a source, which is not an appropriate
          // contract for an IPTV on-demand URL. Live IPTV keeps its existing
          // path below.
          // IPTV VOD: keep the resolved Xtream URL on the direct-open path.
    final launchIsIptvVod =
              launchIptvChannels != null &&
              ((launchIdx >= 0 && launchIdx < launchIptvChannels.length)
                  ? launchIptvChannels[launchIdx].contentType == 'vod'
                  : false);
          final plainOpen =
              initialUrl.isNotEmpty &&
              (hasExternalAudio || launchIsLiveIptv || launchIsIptvVod);
          final opened = plainOpen
              ? await (() async {
                  await _openMedia(
                    mk.Media(initialUrl, httpHeaders: _activeHttpHeaders),
                    play: !hasExternalAudio,
                    desiredPlay: true,
                    liveStream: launchIsLiveIptv,
                  );
                  return true;
                })()
              : await _openInitialVodWithFailover(
                  initialUrl,
                  httpHeaders: _activeHttpHeaders,
                  initialAttemptAlreadyFailed: initialRankedAttemptFailed,
                );
          if (!opened) {
            if (mounted) {
              final canRecover = widget.onStartupSourcesExhausted != null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    canRecover
                        ? 'Saved source failed. Looking for another sourckßuÁ‚ùÁf'
                        : 'No playable source could be started.',
                  ),
                ),
              );
              // Keep hold of this exact route: a dialog may briefly cover the
              // player while the failure message is visible. Wait for that
              // dialog to leave, but abandon the pending pop if the player
              // itself was dismissed, so an underlying detail route can never
              // be popped by this delayed callback.
              final playerRoute = ModalRoute.of(context);
              await Future<void>.delayed(
                Duration(milliseconds: canRecover ? 250 : 900),
              );
              while (mounted && playerRoute?.isActive == true) {
                if (playerRoute?.isCurrent == true) break;
                await Future<void>.delayed(const Duration(milliseconds: 50));
              }
              if (mounted && playerRoute?.isCurrent == true) {
                if (canRecover) {
                  Navigator.of(
                    context,
                  ).pop(<String, dynamic>{'startupSourcesExhausted': true});
                } else {
                  Navigator.of(context).maybePop();
                }
              }
            }
            return;
          }
          // Wait for duration-dependent resume and random-start calculations.
          await _waitForVideoReady();
          if (hasExternalAudio) {
            await _setExternalAudioTrack(widget.audioUrl!);
          }
          // Random start takes precedence over resume, then startAtPercent.
          if (widget.startFromRandom) {
            final offset = _randomStartOffset(_duration);
            if (offset != null) {
              // A random start has no bookmark to protect and no "correct"
              // position to verify against"È›y¯ßy‘ plain seek, as before.
              await _player.seek(offset);
            } else {
              await _maybeRestoreResume(verifyLanding: true);
            }
          } else if (widget.startAtPercent != null) {
            final offset = _percentStartOffset(_duration);
            if (offset != null) {
              // An explicit promised start position, exposed to the same
              // startup seek failure as a stored resume.
              await _seekForResume(offset.inMilliseconds, verifyLanding: true);
            }
          } else {
            await _maybeRestoreResume(verifyLanding: true);
          }
          _scheduleAutoHide();
          await _restoreTrackPreferences();
          if (hasExternalAudio) await _player.play();
          // The candidate is now decoded, resume has been applied, and track
          // restoration is complete. Only now may progress escape to local
          // completion or remote scrobblers.
          _setStartupGateActive(false);
          _resumeTrackingAfterValidationGate();
        } catch (e) {
          _setStartupGateActive(false);
          // A late throw (seek/track restore) can land after a successful
          // open"È›y¯ßy‘ playback proceeds, so re-arm tracking or the start
          // scrobble stays swallowed until the next play/pause transition.
          _resumeTrackingAfterValidationGate();
          debugPrint('VideoPlayer: initial open failed: $e');
        }
      }
    } else {
      // If no valid URL, try to load the first playlist entry
      if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
        _loadPlaylistIndex(_currentIndex, autoplay: false);
      }
    }
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _saveResume(debounced: true),
    );

    // Preload episode information if this is a series
    _episodeMetadataReady ??= _preloadEpisodeInfo();
  }

  void _bindPlayerInstanceSubscriptions(
    int instanceGeneration,
    mk.Player player,
  ) {
    bool isCurrent() =>
        mounted && instanceGeneration == _playerInstanceGeneration;

    _subtitleDiagnosticLogSub = player.stream.log.listen((log) {
      if (!isCurrent()) return;
      final searchable = '${log.prefix} ${log.text}'.toLowerCase();
      if (!searchable.contains('sub') &&
          !searchable.contains('libass') &&
          !searchable.contains('track')) {
        return;
      }
      debugPrint('[SubtitleDiag] mpv[${log.level}] ${log.prefix}: ${log.text}');
      final level = log.level.toLowerCase();
      final subtitleFailure =
          (level == 'error' || level == 'fatal') &&
          (log.prefix.toLowerCase().startsWith('sub') ||
              searchable.contains('subtitle decoder') ||
              searchable.contains('subtitle converter'));
      final attempt = _activeSubtitleApplyAttempt;
      if (subtitleFailure && attempt != null) {
        unawaited(_handleSubtitleApplyFailure(attempt, log.text));
      }
    });
    // Subscribe before open() so fast local media and immediate renderer
    // failures are visible to both diagnostics and the startup guard.
    _paramsSub = player.stream.videoParams.listen((params) {
      if (!isCurrent()) return;
      // First sized params ∫w^~)ﬁt first decoded frame"È›y¯ßy‘ close enough for the
      // zap-speed number, and it avoids one more subscription slot.
      if ((params.w ?? 0) > 0) {
        _iptvDiag.onFirstFrame();
        _iptvLiveRecovery.onFirstFrame();
      }
      _handleDecoderProbeParams(params);
    });
    _rendererStartupErrorSub = player.stream.error.listen((error) {
      if (!isCurrent() ||
          !AndroidRendererStartupFallback.isRendererFailure(error)) {
        return;
      }
      unawaited(
        _fallbackExplicitRendererToAutomatic(
          instanceGeneration: instanceGeneration,
          mediaGeneration: _decoderProbeGeneration,
          reason: 'renderer_error',
        ),
      );
    });
    _posSub = player.stream.position.listen((d) {
      if (!isCurrent()) return;
      if (Platform.isIOS && d.inSeconds != _lastIosPipPositionSecond) {
        _lastIosPipPositionSecond = d.inSeconds;
        _pushPipState();
      }
      _subtitleAutoSync?.observePosition(d.inMilliseconds);
      _iptvDiag.onProgress(d, playing: _isPlaying);
      // _isPlaying tracks mpv's pause property: a cache-stall keeps it true
      // (stall detector armed), a user pause flips it false (excluded).
      if (_effectiveIptvChannels != null) {
        _iptvLiveRecovery.onProgress(d, wantsPlayback: _isPlaying);
      }
      _position = d;
      unawaited(_syncExternalAudioToVideoPosition());
      _prepareNextDirectEpisode();
      _updateMdblistPosition();
      _playbackUiClock.updatePosition(d);
      _syncSkipSegmentsForCurrentContent();
      _syncActiveSkipSegmentUi();
      _checkAndApplyLocalCompletion();
    });
    if (_subtitleAutoSyncEnabled) {
      var lastAudioTrackId = player.state.track.audio.id;
      _trackSub = player.stream.track.listen((track) {
        if (!isCurrent()) return;
        final audioTrackId = track.audio.id;
        if (audioTrackId != lastAudioTrackId) {
          lastAudioTrackId = audioTrackId;
          _subtitleAutoSync?.audioTrackChanged();
        }
      });
    }
    _durSub = player.stream.duration.listen((d) {
      if (!isCurrent()) return;
      final hadDuration = _duration > Duration.zero;
      _duration = d;
      _updateMdblistPosition();
      // `playing=true` commonly arrives before libmpv publishes duration. In
      // that ordering the playing listener cannot arm MDBList, and no second
      // playing event is guaranteed. Treat the first usable duration as the
      // missing edge so the initial durable pause checkpoint is sent.
      if (!hadDuration && d > Duration.zero && _isPlaying) {
        _mdblistPlay();
      }
      _playbackUiClock.updateDuration(d);
      if (d > Duration.zero) _skipSegmentsMediaReady = true;
      _syncSkipSegmentsForCurrentContent();
      _syncActiveSkipSegmentUi();
      setState(() {});
    });
    _playSub = player.stream.playing.listen((p) {
      if (!isCurrent()) return;
      if (p && _pausedByLifecycle && !_isPipActive) {
        unawaited(player.pause());
        return;
      }
      final wasPlaying = _isPlaying;
      _isPlaying = p;
      final externalAudioPlayer = _externalAudioPlayer;
      if (externalAudioPlayer != null) {
        unawaited(
          (p ? externalAudioPlayer.play() : externalAudioPlayer.pause())
              .catchError(
            (Object error) => debugPrint(
              'VideoPlayer: external audio play-state sync failed: $error',
            ),
          ),
        );
      }
      ProfileLockController.instance.setPlaybackActive(p);
      _syncWakelock(p);
      _pushPipState();
      if (p) _noteLiveChannelPlaying();
      if (!_validationGateActive && p && _duration > Duration.zero) {
        _traktScrobble('start');
        if (_traktLastScrobbleAction == 'start') {
          _startTraktHeartbeat();
        }
      } else if (!_validationGateActive &&
          !p &&
          wasPlaying &&
          !_isTransitioning &&
          _traktLastScrobbleAction != 'stop') {
        _traktScrobble('pause');
        _stopTraktHeartbeat();
      }
      if (!_validationGateActive &&
          _simklScrobbleEnabled &&
          p &&
          _duration > Duration.zero) {
        _simklLastScrobbleAction = 'start';
        _startSimklHeartbeat();
      } else if (!_validationGateActive &&
          !p &&
          wasPlaying &&
          !_isTransitioning &&
          _simklLastScrobbleAction != 'stop') {
        _simklScrobble('pause');
        _stopSimklHeartbeat();
      }
      if (!_validationGateActive && p && _duration > Duration.zero) {
        _mdblistPlay();
      } else if (!_validationGateActive &&
          !p &&
          wasPlaying &&
          !_isTransitioning) {
        _mdblistPause();
      }
      if (p && _transitionRunning) {
        _transitionStopTimer?.cancel();
        _transitionPhaseTimer?.cancel();
        _transitionPhase = 1;
        _transitionPhase2Started = null;
        debugPrint(
          'Player: Playback started; overlay phase 1 (static) 1500ms.',
        );
        _transitionPhaseTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!isCurrent()) return;
          _transitionPhase = 2;
          _transitionPhase2Started = DateTime.now();
          setState(() {});
          debugPrint('Player: Overlay phase 2 (cinematic bars) 1500ms.');
        });
        _transitionStopTimer = Timer(const Duration(milliseconds: 3000), () {
          if (!isCurrent()) return;
          _rainbowController.stop();
          _transitionRunning = false;
          _rainbowActive = false;
          setState(() {});
          debugPrint('Player: Transition overlay stopped (3s complete).');
        });
      }
      setState(() {});
    });
    _completedSub = player.stream.completed.listen((done) {
      if (done && isCurrent()) {
        _iptvDiag.onPlaybackEnded(_position);
        _onPlaybackEnded();
      }
    });
    _bufferingSub = player.stream.buffering.listen((isBuffering) {
      if (isCurrent()) _iptvDiag.onBuffering(isBuffering, _position);
      if (!isCurrent() || !_isReady || _isTransitioning) return;
      if (isBuffering) {
        _bufferingDebounceTimer?.cancel();
        _bufferingDebounceTimer = Timer(
          VideoPlayerTimingConstants.bufferingDebounceDelay,
          () {
            if (isCurrent() &&
                player.state.buffering &&
                _isReady &&
                !_isTransitioning &&
                !_isPikPakRetrying) {
              _showBufferingIndicator.value = true;
            }
          },
        );
      } else {
        _bufferingDebounceTimer?.cancel();
        _showBufferingIndicator.value = false;
      }
    });
    if (_effectiveIptvChannels != null) {
      _iptvErrorSub = player.stream.error.listen((error) {
        if (isCurrent()) _onIptvStreamError(error);
      });
    }
  }

  Future<void> _cancelPlayerInstanceSubscriptions() async {
    final subscriptions = <StreamSubscription?>[
      _posSub,
      _durSub,
      _playSub,
      _paramsSub,
      _trackSub,
      _completedSub,
      _bufferingSub,
      _iptvErrorSub,
      _rendererStartupErrorSub,
      _subtitleDiagnosticLogSub,
    ];
    _posSub = null;
    _durSub = null;
    _playSub = null;
    _paramsSub = null;
    _trackSub = null;
    _completedSub = null;
    _bufferingSub = null;
    _iptvErrorSub = null;
    _rendererStartupErrorSub = null;
    _subtitleDiagnosticLogSub = null;
    for (final subscription in subscriptions) {
      if (subscription == null) continue;
      try {
        await subscription.cancel();
      } catch (_) {
        // A broken listener must not strand the old native player during the
        // compatibility restart.
      }
    }
  }

  void _handleDecoderProbeParams(mk.VideoParams params) {
    final width = params.dw ?? params.w ?? 0;
    final height = params.dh ?? params.h ?? 0;
    if (width <= 0 || height <= 0) {
      // Player.open() normally resets VideoParams before loading the next item.
      // Treat it as an extra invalidation signal, but do not require it: the
      // app-owned generation started in _openMedia is the session boundary.
      _decoderProbeToken++;
      _decoderProbeTimer?.cancel();
      _decoderProbeTimer = null;
      _decoderProbeParams = null;
      _rendererStartupGuardToken++;
      _rendererStartupValidationGeneration = -1;
      _resetTvosDisplayMatchForMediaBoundary();
      return;
    }
    _decoderProbeParams = params;
    _scheduleTvosDisplayMatch(params);
    _scheduleDecoderProbe();
    _scheduleRendererStartupValidation();
    final remedy = _tvosDecodeRemedy;
    if (remedy != null) {
      // Only ever STARTS the ladder (from idle, on a triggering format)"È›y¯ßy‘
      // the ladder's own transitional events are ignored inside it.
      unawaited(remedy.evaluate(params, _decoderProbeGeneration));
    }
  }

  void _resetTvosDisplayMatchForMediaBoundary() {
    _tvosDisplayMatchToken++;
    _tvosDisplayMatchTimer?.cancel();
    _tvosDisplayMatchTimer = null;
    _lastTvosDisplayMatchSignature = null;
    if (!PlatformUtil.isTvOS || !_contentDisplayMatchMode.requestsMatching) {
      return;
    }
    // AVDisplayManager retains criteria until explicitly replaced. Clear the
    // outgoing item's request so content with missing/invalid fps metadata can
    // never inherit the previous refresh rate.
    unawaited(
      TvosDisplayMatchService.clear().catchError((Object error) {
        debugPrint('DisplayMatch: tvOS boundary clear failed: $error');
      }),
    );
  }

  void _scheduleTvosDisplayMatch(mk.VideoParams params) {
    if (!PlatformUtil.isTvOS || !_contentDisplayMatchMode.requestsMatching) {
      return;
    }
    final width = params.dw ?? params.w ?? 0;
    final height = params.dh ?? params.h ?? 0;
    if (width <= 0 || height <= 0) return;
    final token = ++_tvosDisplayMatchToken;
    _tvosDisplayMatchTimer?.cancel();
    _tvosDisplayMatchTimer = Timer(const Duration(milliseconds: 200), () async {
      if (_screenDisposed || token != _tvosDisplayMatchToken) return;
      final platform = _player.platform;
      if (platform is! mk.NativePlayer) return;
      final selectedTrack = _player.state.track.video;
      var fps = selectedTrack.fps;
      if (fps == null || !fps.isFinite || fps <= 0) {
        for (final property in const ['container-fps', 'estimated-vf-fps']) {
          try {
            final candidate = double.tryParse(
              await platform.getProperty(property),
            );
            if (candidate != null && candidate.isFinite && candidate > 0) {
              fps = candidate;
              break;
            }
          } catch (_) {
            // Some containers publish only one of the two fps properties.
          }
        }
      }
      if (_screenDisposed ||
          token != _tvosDisplayMatchToken ||
          fps == null ||
          !fps.isFinite ||
          fps <= 0) {
        return;
      }
      var codec = selectedTrack.codec;
      if (codec == null || codec.isEmpty) {
        try {
          codec = await platform.getProperty('video-codec');
        } catch (_) {
          codec = null;
        }
      }
      if (_screenDisposed || token != _tvosDisplayMatchToken) return;
      final signature =
          '${_contentDisplayMatchMode.storageKey}|$width|$height|${fps.toStringAsFixed(4)}|${codec ?? ''}';
      if (signature == _lastTvosDisplayMatchSignature) return;
      try {
        final status = await TvosDisplayMatchService.apply(
          mode: _contentDisplayMatchMode,
          width: width,
          height: height,
          refreshRate: fps,
          codec: codec,
        );
        if (_screenDisposed || token != _tvosDisplayMatchToken) return;
        _lastTvosDisplayMatchSignature = signature;
        debugPrint(
          'DisplayMatch: tvOS requested ${width}x$height@${fps.toStringAsFixed(3)} '
          'mode=${_contentDisplayMatchMode.storageKey} '
          'enabled=${status['matchingEnabled']}',
        );
      } catch (error) {
        debugPrint('DisplayMatch: tvOS request failed: $error');
      }
    });
  }

  Future<void> _installDecoderObservers(
    int instanceGeneration,
    mk.Player player,
  ) async {
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;

    // ANDROID ONLY, deliberately.
    //
    // These observers exist to feed the Android explicit-renderer fallback
    // (`_scheduleRendererStartupValidation`), which is itself
    // gated on `Platform.isAndroid`"È›y¯ßy‘ so everywhere else they were pure cost.
    //
    // They are also `mpv_observe_property` calls issued unawaited, at the same
    // moment the video controller is building the native render context on its
    // own worker ∫w^~)ﬁt which is the window a tvOS SIGABRT was landing in.
    //
    // NOT confirmed as the cause: the crash stopped after this change AND a
    // reinstall that wiped the device's preferences, and either could have
    // done it. Kept regardless, because a probe that only feeds an
    // Android-gated fallback has no business running anywhere else.
    if (!Platform.isAndroid) return;

    try {
      await platform.observeProperty('hwdec-current', (value) async {
        if (mounted && instanceGeneration == _playerInstanceGeneration) {
          _scheduleDecoderProbe();
        }
      });
    } catch (_) {
      // The one-shot query below still works if this property is unavailable.
    }
    try {
      await platform.observeProperty('current-vo', (value) async {
        if (mounted && instanceGeneration == _playerInstanceGeneration) {
          _scheduleDecoderProbe();
        }
      });
    } catch (_) {
      // Keep the independent hwdec observer when only current-vo is unavailable.
    }
  }

  void _scheduleRendererStartupValidation() {
    if (!AndroidRendererStartupFallback.shouldArm(
          isAndroid: Platform.isAndroid,
          isAndroidTv: PlatformUtil.isAndroidTvCached,
          mode: _androidVideoRendererMode,
          alreadyValidated: _rendererValidatedForSession,
          fallbackInProgress: _rendererFallbackInProgress,
        ) ||
        _iptvErrorsMuted ||
        _rendererStartupValidationGeneration == _decoderProbeGeneration) {
      return;
    }
    _rendererStartupValidationGeneration = _decoderProbeGeneration;
    final guardToken = ++_rendererStartupGuardToken;
    final instanceGeneration = _playerInstanceGeneration;
    final mediaGeneration = _decoderProbeGeneration;
    final player = _player;
    unawaited(
      _validateRendererStartup(
        guardToken: guardToken,
        instanceGeneration: instanceGeneration,
        mediaGeneration: mediaGeneration,
        player: player,
      ),
    );
  }

  Future<void> _validateRendererStartup({
    required int guardToken,
    required int instanceGeneration,
    required int mediaGeneration,
    required mk.Player player,
  }) async {
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;

    // VideoParams is already positive at this point, so this is not a network
    // startup timeout. Give Android's SurfaceProducer/codec bridge three seconds
    // to attach the requested output and require two matching reads.
    var previousOutput = '';
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!mounted ||
          guardToken != _rendererStartupGuardToken ||
          instanceGeneration != _playerInstanceGeneration ||
          mediaGeneration != _decoderProbeGeneration) {
        return;
      }
      try {
        final output = await platform.getProperty('current-vo');
        if (AndroidRendererStartupFallback.isExpectedOutput(
              mode: _androidVideoRendererMode,
              value: output,
            ) &&
            output == previousOutput) {
          _rendererValidatedForSession = true;
          _rendererStartupGuardToken++;
          return;
        }
        previousOutput = output;
      } catch (_) {
        // A transient property-query failure gets the remainder of the window.
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    await _fallbackExplicitRendererToAutomatic(
      instanceGeneration: instanceGeneration,
      mediaGeneration: mediaGeneration,
      reason: 'requested_output_not_ready',
    );
  }

  Future<void> _fallbackExplicitRendererToAutomatic({
    required int instanceGeneration,
    required int mediaGeneration,
    required String reason,
  }) async {
    if (!AndroidRendererStartupFallback.shouldArm(
          isAndroid: Platform.isAndroid,
          isAndroidTv: PlatformUtil.isAndroidTvCached,
          mode: _androidVideoRendererMode,
          alreadyValidated: _rendererValidatedForSession,
          fallbackInProgress: _rendererFallbackInProgress,
        ) ||
        !mounted ||
        instanceGeneration != _playerInstanceGeneration ||
        mediaGeneration != _decoderProbeGeneration ||
        _activeOpenedMedia == null ||
        _isRecording ||
        _iptvErrorsMuted ||
        _isTransitioning) {
      return;
    }

    _rendererFallbackInProgress = true;
    _rendererStartupGuardToken++;
    final media = _activeOpenedMedia!;
    final oldPlayer = _player;
    final oldState = oldPlayer.state;
    // A renderer rebuild mid-startup can race an unlanded resume seek: the
    // live position is then a restart artifact, and the rebuilt player must
    // come back at the promised target, not ~0. (Pure query ∫w^~)ﬁt the guard stays
    // armed for the rebuilt player's own landing.)
    final livePosition = _position > Duration.zero
        ? _position
        : oldState.position;
    final heldMs = _resumeWriteGuard.heldTargetIfBlocked(
      livePosition.inMilliseconds,
    );
    final resumePosition = heldMs != null
        ? Duration(milliseconds: heldMs)
        : livePosition;
    final shouldResumePlayback =
        _activeMediaShouldPlay && !_activeMediaUserPaused && !_sleepStopLatched;
    final rate = oldState.rate;
    final volume = oldState.volume;
    final isLive = _currentIptvChannel?.isLive == true;
    final externalAudio = widget.audioUrl;
    final hasExternalAudio = externalAudio != null && externalAudio.isNotEmpty;

    final failedRenderer = _androidVideoRendererMode.storageKey;
    _releasePlayerDiagnostic(
      'generation=$mediaGeneration phase=fallback '
      'status=renderer_startup_failed platform=android backend=libmpv '
      'requested_renderer=$failedRenderer fallback=automatic reason=$reason',
    );

    // Invalidate every old callback before the first await. Only one native
    // player may own audio and the Android surface during the restart.
    _playerInstanceGeneration++;
    _playerCreated = false;
    _isReady = false;
    _isPlaying = false;
    _showBufferingIndicator.value = false;
    setState(() {});

    try {
      await _cancelPlayerInstanceSubscriptions();
      await _disposeSubtitleAutoSync();
      _activeExternalSubtitlePath = null;
      _releaseAudioEffectSession();
      try {
        await oldPlayer.pause();
      } catch (_) {}
      try {
        await oldPlayer.dispose();
      } catch (_) {
        // Disposal normally succeeds, but retain ownership if the native
        // backend throws so route teardown can make one final cleanup attempt.
        _playerCreated = true;
        rethrow;
      }
      if (!mounted) return;

      // Remember the compatibility result. The setting now visibly reads
      // Automatic, and choosing an explicit renderer again retries it.
      _androidVideoRendererMode = AndroidVideoRendererMode.automatic;
      try {
        await StorageService.setAndroidVideoRendererMode(
          AndroidVideoRendererMode.automatic,
        );
      } catch (_) {
        // Playback can still recover for this session if preferences are full
        // or unavailable.
      }
      if (!mounted) return;

      _duration = Duration.zero;
      _position = Duration.zero;
      await _claimVideoOutput();
      if (!mounted) return;
      _createPlayerInstance(AndroidVideoRendererMode.automatic);
      await _configurePlayerAudio(_player);
      _installSubtitleAutoSyncForPlayer(_player);
      await _attachAudioEffectSession();
      if (!mounted) return;
      setState(() {});

      final needsPreparation =
          hasExternalAudio || (!isLive && resumePosition > Duration.zero);
      final playOnOpen =
          shouldResumePlayback && !_pausedByLifecycle && !needsPreparation;
      await _openMedia(
        media,
        play: playOnOpen,
        desiredPlay: shouldResumePlayback,
        // The recreated player starts with a clean property set ∫w^~)ﬁt without
        // this a live channel would silently lose its ffmpeg reconnect
        // options at the renderer fallback (codex round 2, finding 16).
        liveStream: isLive,
      );
      if (needsPreparation) await _waitForVideoReady();
      if (!mounted) return;
      await _player.setRate(rate);
      await _player.setVolume(volume);
      if (hasExternalAudio) {
        await _setExternalAudioTrack(externalAudio);
      }
      if (!isLive && resumePosition > Duration.zero) {
        // Re-ARMS the guard at the carried position: the rebuilt player gets
        // its own protected landing instead of an unguarded raw seek.
        await _seekForResume(resumePosition.inMilliseconds);
      }
      unawaited(_restoreTrackPreferences());
      if (shouldResumePlayback && !_pausedByLifecycle && !playOnOpen) {
        await _player.play();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Direct Surface was unavailable. Using Automatic renderer.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      _releasePlayerDiagnostic(
        'generation=$mediaGeneration phase=fallback '
        'status=failed platform=android backend=libmpv '
        'requested_renderer=direct_surface fallback=automatic',
      );
    } finally {
      _rendererFallbackInProgress = false;
    }
  }

  void _scheduleDecoderProbe() {
    final params = _decoderProbeParams;
    if (params == null) return;
    _decoderProbeTimer?.cancel();
    final generation = _decoderProbeGeneration;
    final token = ++_decoderProbeToken;
    _decoderProbeTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(
        _reportActiveVideoDecoder(
          params: params,
          generation: generation,
          token: token,
        ),
      );
    });
  }

  Future<void> _reportActiveVideoDecoder({
    required mk.VideoParams params,
    required int generation,
    required int token,
  }) async {
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) {
      _emitDecoderDiagnosticOnce(
        generation: generation,
        signature: 'web',
        fields:
            'phase=stable status=unavailable platform=web backend=web '
            'reason=no_native_decoder',
      );
      return;
    }

    var decoder = '';
    var codec = '';
    var output = '';
    var previousDecoder = '';
    var previousOutput = '';
    var stable = false;
    // Audio, read on the DEVICE side (AUDIO_FIDELITY_PLAN.md): what the AO
    // actually writes, not what the decoder produced"È›y¯ßy‘ the gap between the
    // two is the downgrade being diagnosed.
    var aoName = '';
    var audioChannels = '';
    var previousAo = '';
    var previousAudioChannels = '';
    var audioCodec = '';
    var decodedChannels = '';
    var audioFormat = '';

    try {
      // VideoParams means a decoder has produced metadata, not necessarily
      // that the output surface has finished attaching. Require two matching
      // reads so an early `current-vo=null` is never presented as the verdict.
      // Audio joins the match condition but not the readiness one: a
      // video-only file has no AO to wait for, and empty-matches-empty.
      for (var attempt = 0; attempt < 12; attempt++) {
        if (!mounted ||
            generation != _decoderProbeGeneration ||
            token != _decoderProbeToken) {
          return;
        }
        decoder = await platform.getProperty('hwdec-current');
        output = await platform.getProperty('current-vo');
        aoName = await platform.getProperty('current-ao');
        audioChannels = await platform.getProperty(
          'audio-out-params/channel-count',
        );
        final outputReady = output.isNotEmpty && output != 'null';
        final decoderReady = decoder.isNotEmpty;
        if (decoderReady &&
            outputReady &&
            decoder == previousDecoder &&
            output == previousOutput &&
            aoName == previousAo &&
            audioChannels == previousAudioChannels) {
          stable = true;
          break;
        }
        previousDecoder = decoder;
        previousOutput = output;
        previousAo = aoName;
        previousAudioChannels = audioChannels;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted ||
          generation != _decoderProbeGeneration ||
          token != _decoderProbeToken) {
        return;
      }
      codec = await platform.getProperty('video-codec');
      audioCodec = await platform.getProperty('audio-codec-name');
      decodedChannels = await platform.getProperty(
        'audio-params/channel-count',
      );
      audioFormat = await platform.getProperty('audio-out-params/format');
    } catch (_) {
      if (!mounted || generation != _decoderProbeGeneration) return;
      _emitDecoderDiagnosticOnce(
        generation: generation,
        signature: 'error',
        fields:
            'phase=error status=unavailable '
            'platform=${Platform.operatingSystem} reason=property_query_failed',
      );
      return;
    }

    final width = params.dw ?? params.w ?? 0;
    final height = params.dh ?? params.h ?? 0;
    final status = decoder == 'no'
        ? 'software'
        : decoder.isEmpty
        ? 'unavailable'
        : 'hardware';
    final normalizedOutput = output.isEmpty || output == 'null'
        ? 'unknown'
        : output;
    final requestedRenderer = Platform.isAndroid
        ? _androidVideoRendererMode.storageKey
        : 'platform_default';
    // The remedy journey (tvOS): what the decoder produced originally, what
    // it produces now, and where the ladder settled. In the signature too ∫w^~)ﬁt
    // a settle re-arms this probe, and dedupe on the old signature would
    // swallow exactly the report that proves the remedy ran.
    final remedy = _tvosDecodeRemedy;
    final remedyState = switch (remedy?.state) {
      null || TvosRemedyState.none => 'none',
      TvosRemedyState.nv12 => 'nv12',
      TvosRemedyState.software => 'software',
      TvosRemedyState.gaveUp => 'gave_up',
    };
    // confirmed/failed mean the remedy's own settling poll verified the
    // format by DIRECT read ∫w^~)ﬁt the stream-captured params above can lag
    // behind a settle (no final event is guaranteed after reconfig).
    final remedyOutcome = remedy == null
        ? 'none'
        : remedy.applying
        ? 'pending'
        : switch (remedy.state) {
            TvosRemedyState.none => 'none',
            TvosRemedyState.nv12 || TvosRemedyState.software => 'confirmed',
            TvosRemedyState.gaveUp => 'failed',
          };
    final remedyFields = remedy == null
        ? ''
        : 'pixelformat=${params.pixelformat ?? 'unknown'} '
              'hw_pixelformat=${params.hwPixelformat ?? 'none'} '
              'detected_hw_pixelformat=${remedy.detectedHwPixelformat ?? 'none'} '
              'verified_hw_pixelformat=${remedy.verifiedHwPixelformat ?? 'none'} '
              'gamma=${params.gamma ?? 'unknown'} '
              'primaries=${params.primaries ?? 'unknown'} '
              'remedy=$remedyState remedy_outcome=$remedyOutcome ';
    final signature =
        '$decoder|$normalizedOutput|$codec|${width}x$height|'
        '$remedyState|$remedyOutcome';
    _emitDecoderDiagnosticOnce(
      generation: generation,
      signature: signature,
      fields:
          'phase=${stable ? 'stable' : 'partial'} status=$status '
          'platform=${Platform.operatingSystem} backend=libmpv '
          'codec=${codec.isEmpty ? 'unknown' : codec} '
          'decoder=${decoder.isEmpty ? 'unknown' : decoder} '
          'output=$normalizedOutput '
          '$remedyFields'
          'audio_codec=${audioCodec.isEmpty ? 'none' : audioCodec} '
          'decoded_channels=${decodedChannels.isEmpty ? 'none' : decodedChannels} '
          'audio_channels=${audioChannels.isEmpty ? 'none' : audioChannels} '
          'audio_format=${audioFormat.isEmpty ? 'none' : audioFormat} '
          'ao=${aoName.isEmpty ? 'none' : aoName} '
          'requested_renderer=$requestedRenderer '
          'resolution=${width}x$height',
    );
  }

  void _emitDecoderDiagnosticOnce({
    required int generation,
    required String signature,
    required String fields,
  }) {
    if (generation != _decoderProbeGeneration) return;
    final taggedSignature = '$generation|$signature';
    if (_lastDecoderDiagnosticSignature == taggedSignature) return;
    _lastDecoderDiagnosticSignature = taggedSignature;
    _releasePlayerDiagnostic('generation=$generation $fields');
  }

  void _beginMediaGeneration() {
    _decoderProbeGeneration++;
    _decoderProbeToken++;
    _rendererStartupGuardToken++;
    _rendererStartupValidationGeneration = -1;
    _decoderProbeTimer?.cancel();
    _decoderProbeTimer = null;
    _decoderProbeParams = null;
    _lastDecoderDiagnosticSignature = null;
    // This is the guaranteed boundary for every playlist item, IPTV zap,
    // startup candidate, and manual source switch. VideoParams normally emits
    // an invalid value too, but display correctness must not depend on it.
    _resetTvosDisplayMatchForMediaBoundary();
    _playbackUiClock.beginMedia();
    _activeSkipSegmentUi.clear();
  }

  /// The user's Network & Buffering presets, loaded once per screen. A
  /// mid-session settings change applies on the next playback ∫w^~)ﬁt accurate
  /// today because Settings isn't reachable without popping the player; an
  /// in-player settings entry point would have to re-read this.
  NetworkTuning? _networkTuning;

  /// Stock values of exactly the player-global properties [_networkTuning]
  /// has overridden, captured before the first override. A later live open
  /// on the same player (mixed playlist) restores these, so the tuned live
  /// IPTV pipeline can never inherit VOD tuning. Null until tuning has
  /// actually touched the player"È›y¯ßy‘ the Standard path never populates it and
  /// so never sets a single property.
  Map<String, String>? _networkTuningDefaults;

  /// Serializes tuning applies: a rapid zap starts a newer [_openMedia]
  /// while an older one is suspended mid-capture, and interleaved property
  /// writes could land VOD tuning on the newer open's live stream. Each
  /// apply runs WHOLE, in order, and bails via its generation check when a
  /// newer open owns the player.
  Future<void> _networkTuningChain = Future<void>.value();

  Future<void> _applyNetworkTuning(
    mk.NativePlayer platform,
    NetworkTuning tuning, {
    required bool liveStream,
    required int generation,
  }) {
    return _networkTuningChain = _networkTuningChain.then(
      (_) => _applyNetworkTuningInner(
        platform,
        tuning,
        liveStream: liveStream,
        generation: generation,
      ),
    );
  }

  Future<void> _applyNetworkTuningInner(
    mk.NativePlayer platform,
    NetworkTuning tuning, {
    required bool liveStream,
    required int generation,
  }) async {
    final want = liveStream ? const <String, String>{} : tuning.mpvProperties;
    // Standard (and live-before-any-tuning): nothing was ever applied,
    // nothing to restore ∫w^~)ﬁt the player is untouched.
    if (want.isEmpty && _networkTuningDefaults == null) return;
    if (generation != _decoderProbeGeneration) return; // superseded in queue
    try {
      if (want.isNotEmpty && _networkTuningDefaults == null) {
        final defaults = <String, String>{};
        for (final key in want.keys) {
          final value = await platform.getProperty(key);
          // The vendored getProperty returns '' instead of throwing when mpv
          // has no value. An empty "default" would silently fail to restore
          // later+ßuÁ‚ùÁT refuse to tune rather than capture poison.
          if (value.isEmpty) {
            debugPrint('Player: network tuning skipped"È›y¯ßy‘ $key unreadable');
            return;
          }
          defaults[key] = value;
        }
        if (generation != _decoderProbeGeneration) return;
        _networkTuningDefaults = defaults;
      }
      for (final entry in _networkTuningDefaults!.entries) {
        if (generation != _decoderProbeGeneration) return;
        await platform.setProperty(entry.key, want[entry.key] ?? entry.value);
      }
    } catch (e) {
      debugPrint('Player: network tuning apply failed: $e');
    }
  }

  /// A native libmpv open can remain pending even after a Dart Future timeout.
  /// For live IPTV, destroy the stalled native instance before retrying so the
  /// second open can never overlap the first one.
  Future<void> _recreatePlayerAfterLiveOpenTimeout() async {
    if (_screenDisposed || !mounted) return;
    final oldPlayer = _player;
    await _cancelPlayerInstanceSubscriptions();
    await _disposeSubtitleAutoSync();
    try { await oldPlayer.stop(); } catch (_) {}
    try { await oldPlayer.dispose(); } catch (e) {
      debugPrint('Player: timed-out IPTV player dispose failed: $e');
    }
    if (_screenDisposed || !mounted) return;
    _createPlayerInstance(_androidVideoRendererMode);
    await _configurePlayerAudio(_player);
    _installSubtitleAutoSyncForPlayer(_player);
  }

  Future<void> _openMedia(
    mk.Media media, {
    required bool play,
    bool? desiredPlay,
    bool liveStream = false,
    EpisodePlaybackRequest? request,
    bool Function()? beforeOpen,
    int liveOpenAttempt = 0,
  }) async {
    if (request?.isCurrent == false) return;
    if (liveStream && liveOpenAttempt > 1) {
      throw StateError('IPTV live open exhausted its recovery attempts');
    }
    _resumeVerifyEpoch++;
    _resumeWriteGuard.clear();
    _activeOpenedMedia = media;
    _activeMediaShouldPlay = desiredPlay ?? play;
    _activeMediaUserPaused = false;
    _beginMediaGeneration();

    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      final tuningGeneration = _decoderProbeGeneration;
      NetworkTuning tuning;
      try {
        tuning = _networkTuning ??= await NetworkTuning.load();
      } catch (e) {
        debugPrint('Player: network tuning load failed: $e');
        tuning = _networkTuning = const NetworkTuning(
          patience: NetworkTuning.standard,
          buffer: NetworkTuning.standard,
        );
      }
      try {
        await platform.setProperty(
          'stream-lavf-o',
          liveStream
              ? 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
                    'reconnect_on_http_error=5xx,reconnect_delay_max=5'
              : tuning.vodLavfOptions,
        );
      } catch (e) {
        debugPrint('Player: stream-lavf-o set failed: $e');
      }
      await _applyNetworkTuning(
        platform, tuning, liveStream: liveStream, generation: tuningGeneration,
      );
    }
    final remedy = _tvosDecodeRemedy;
    if (remedy != null) {
      final generation = _decoderProbeGeneration;
      await remedy.onNewMedia(generation);
      if (_screenDisposed || generation != _decoderProbeGeneration) return;
    }
    if (platform is mk.NativePlayer) {
      try {
        await platform.setProperty(
          'sub-visibility',
          Platform.isIOS && (_isPipActive || _iosPipStarting) ? 'yes' : 'no',
        );
      } catch (error) {
        debugPrint('Player: subtitle visibility reset failed: $error');
      }
    }
    if (beforeOpen != null && !beforeOpen()) return;

    Future<void> doOpen() {
      if (request != null) {
        return request.commit(() => _player.open(media, play: play));
      }
      return _player.open(media, play: play);
    }
    if (!liveStream) return doOpen();

    const openTimeout = Duration(seconds: 15);
    try {
      await doOpen().timeout(openTimeout);
    } on TimeoutException {
      debugPrint(
        'Player: IPTV live open timed out after ' +
        openTimeout.inSeconds.toString() +
        's; recreating native player (attempt=' +
        (liveOpenAttempt + 1).toString() + ')',
      );
      if (liveOpenAttempt >= 1) rethrow;
      await _recreatePlayerAfterLiveOpenTimeout();
      if (_screenDisposed || !mounted) return;
      return _openMedia(
        media,
        play: play,
        desiredPlay: desiredPlay,
        liveStream: true,
        request: request,
        beforeOpen: beforeOpen,
        liveOpenAttempt: liveOpenAttempt + 1,
      );
    }
  }

  void _releasePlayerDiagnostic(String fields) {
    final message = 'DEBRIFY_PLAYER_DECODER $fields';
    if (Platform.isAndroid) {
      // A dedicated native tag lets release captures select only this
      // privacy-safe line. Capturing Flutter's general stdout exposed unrelated
      // service logs and must not be required for decoder diagnostics.
      unawaited(
        _androidPlayerDiagnosticChannel
            .invokeMethod<void>('logDecoder', {'message': fields})
            .catchError((_) {}),
      );
      return;
    }
    if (PlatformUtil.isTvOS) {
      // tvOS release builds deliberately do not bridge every debugPrint call,
      // because unrelated logs can contain private playback data. This narrow,
      // privacy-safe diagnostic still needs to reach the Xcode/device console.
      unawaited(
        _tvReleaseLogChannel
            .invokeMethod<void>('log', message)
            .catchError((_) {}),
      );
      return;
    }

    // Intentional: print reaches desktop process consoles in release builds.
    // Keep this payload free of titles, URLs and account IDs.
    // ignore: avoid_print
    print(message);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `hideOptions` / `hideSeekbar` arrive through the widget, not through an
    // inherited dependency, so didChangeDependencies never fires for them.
    _refreshDockGeometry();
    if (widget.channelName != oldWidget.channelName) {
      final String? trimmed = widget.channelName?.trim();
      if ((trimmed == null || trimmed.isEmpty) && _currentChannelName != null) {
        setState(() {
          _currentChannelName = null;
        });
      } else if (trimmed != null &&
          trimmed.isNotEmpty &&
          _currentChannelName != widget.channelName) {
        setState(() {
          _currentChannelName = widget.channelName;
        });
      }
    }
  }

  // Wait for the video to be ready and duration to be available
  Future<void> _waitForVideoReady() async {
    // Wait up to 10 seconds for the video to be ready
    for (int i = 0; i < 100; i++) {
      if (_duration > Duration.zero) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Wait for subtitle tracks to be parsed from the media file
  // media_kit initially only has 'auto' and 'no' tracks, real tracks come later
  Future<void> _waitForSubtitleTracks({required int token}) async {
    // Wait up to 5 seconds for subtitle tracks to be available
    for (int i = 0; i < 50; i++) {
      if (token != _addonSubtitleFetchToken) return;
      final tracks = _player.state.tracks.subtitle;
      // Check if we have any real tracks (not just 'auto' and 'no')
      final hasRealTracks = tracks.any(
        (t) => t.id != 'auto' && t.id != 'no' && t.id.isNotEmpty,
      );
      if (hasRealTracks) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // Timeout reached - video may not have embedded subtitles
  }

  static String _diagnosticSubtitleId(mk.SubtitleTrack track) =>
      track.uri || track.data ? '<external>' : track.id;

  Future<void> _setNativeSubtitleVisibilityForTrack(
    mk.SubtitleTrack track,
  ) async {
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) return;
    final nativeRendering =
        requiresNativeSubtitleRendering(track) ||
        (Platform.isIOS && (_isPipActive || _iosPipStarting));
    await platform.setProperty(
      'sub-visibility',
      nativeRendering ? 'yes' : 'no',
    );
  }

  /// Records both media_kit's optimistic Dart state and libmpv's authoritative
  /// properties. This distinction matters for subtitle selection: media_kit
  /// updates `state.track.subtitle` after the property-set request completes,
  /// while mpv may still retain a different `sid` or fail to decode the track.
  Future<bool> _setSubtitleTrackWithDiagnostics(
    mk.SubtitleTrack track, {
    required String source,
  }) async {
    if (Platform.isAndroid &&
        !PlatformUtil.isAndroidTvCached &&
        requiresNativeSubtitleRendering(track) &&
        _androidVideoRendererMode !=
            AndroidVideoRendererMode.directMediaCodec) {
      _showSubtitleFailureMessage(
        'Bitmap subtitles require MediaCodec + GPU. Change Video renderer in Settings and restart playback.',
      );
      debugPrint(
        '[SubtitleDiag] apply rejected source=$source '
        'reason=android_renderer_incompatible',
      );
      return false;
    }
    final diagnosticGeneration = ++_subtitleDiagnosticGeneration;
    final attempt = _SubtitleApplyAttempt(
      generation: diagnosticGeneration,
      requested: track,
      previous: _player.state.track.subtitle,
      source: source,
      previousStremioId: _selectedStremioSubtitleId,
      previousExternalPath: _activeExternalSubtitlePath,
    );
    _activeSubtitleApplyAttempt = attempt;
    // Null arms the next correction even when two failures restore the same
    // selection consecutively.
    _subtitleSelectionCorrection.value = null;

    try {
      await _setNativeSubtitleVisibilityForTrack(track);
      await _player.setSubtitleTrack(track);
    } catch (error, stackTrace) {
      debugPrint(
        '[SubtitleDiag] set FAILED source=$source '
        'requestedId=${_diagnosticSubtitleId(track)} '
        'error=$error\n$stackTrace',
      );
      await _handleSubtitleApplyFailure(attempt, error.toString());
      return false;
    }
    // mpv posts decoder failures through its log stream immediately after the
    // property reply. Give that event one run-loop turn before reporting
    // success to optimistic menu UI; late failures are still handled by the
    // active attempt above and roll the selection back centrally.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (attempt.failed) return false;

    attempt.successReturned = true;
    return true;
  }

  Future<void> _handleSubtitleApplyFailure(
    _SubtitleApplyAttempt attempt,
    String reason,
  ) async {
    if (attempt.handled ||
        _activeSubtitleApplyAttempt != attempt ||
        attempt.generation != _subtitleDiagnosticGeneration) {
      return;
    }
    attempt.failed = true;
    attempt.handled = true;
    _activeSubtitleApplyAttempt = null;

    final previous = attempt.previous;
    final sameTrack = previous.id == attempt.requested.id;
    final fallback = previous.id == 'auto' || sameTrack
        ? mk.SubtitleTrack.no()
        : previous;
    var restoredOriginalSelection = fallback.id == previous.id;
    try {
      await _setNativeSubtitleVisibilityForTrack(fallback);
      await _player.setSubtitleTrack(fallback);
    } catch (error) {
      restoredOriginalSelection = false;
      debugPrint(
        '[SubtitleDiag] rollback FAILED source=${attempt.source} error=$error',
      );
      try {
        final noTrack = mk.SubtitleTrack.no();
        await _setNativeSubtitleVisibilityForTrack(noTrack);
        await _player.setSubtitleTrack(noTrack);
      } catch (_) {
        // The original actionable error is surfaced below. A second snackbar
        // for rollback failure would obscure it without giving the user a
        // useful recovery action.
      }
    }

    _selectedStremioSubtitleId = restoredOriginalSelection
        ? attempt.previousStremioId
        : null;
    _setActiveExternalSubtitlePath(
      restoredOriginalSelection ? attempt.previousExternalPath : null,
    );
    final String restoredSelection;
    if (restoredOriginalSelection && attempt.previousStremioId != null) {
      restoredSelection = 'stremio:${attempt.previousStremioId}';
    } else {
      restoredSelection = restoredOriginalSelection ? fallback.id : 'no';
    }

    // A decoder error can arrive after the property reply and after a picker
    // has persisted its optimistic selection. Undo that commit as part of the
    // same rollback, while leaving automatic (never-persisted) attempts alone.
    if (attempt.successReturned && attempt.persisted) {
      await attempt.persistenceDone?.future;
      await _persistTrackChoice(
        attempt.persistedAudioId ?? _player.state.track.audio.id,
        restoredSelection,
      );
    }
    if (!mounted) return;
    setState(() {});
    _playerMenuKey.currentState?.reconcileSubtitleSelection(restoredSelection);
    _subtitleSelectionCorrection.value = restoredSelection;

    final codec = attempt.requested.codec;
    final message = codec == null || codec.isEmpty
        ? 'CouldkßuÁ‚ùÁYt apply subtitles. Try another embedded or online track.'
        : 'Couldn∫w^~)ﬁut decode $codec subtitles. Try another embedded or online track.';
    _showSubtitleFailureMessage(message);
    debugPrint(
      '[SubtitleDiag] user notified source=${attempt.source} reason=$reason',
    );
  }

  void _showSubtitleFailureMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Wait for duration to be available before attempting position restoration
  Future<void> _waitForDuration() async {
    // Wait up to 20 seconds for duration to be available
    for (int i = 0; i < 200; i++) {
      if (_duration > Duration.zero) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Get the last played episode for a series
  Future<Map<String, dynamic>?> _getLastPlayedEpisode(
    SeriesPlaylist seriesPlaylist,
  ) async {
    try {
      final lastEpisode = await StorageService.getLastPlayedEpisode(
        seriesTitle: seriesPlaylist.seriesTitle ?? 'Unknown Series',
      );

      if (lastEpisode != null) {
        final season = lastEpisode['season'] as int;
        final episode = lastEpisode['episode'] as int;
        debugPrint(
          'VideoPlayer: StorageService returned resume S${season}E$episode for "${seriesPlaylist.seriesTitle}"',
        );

        // Find the original index for this episode
        final originalIndex = seriesPlaylist.findOriginalIndexBySeasonEpisode(
          season,
          episode,
        );
        if (originalIndex != -1) {
          return {...lastEpisode, 'originalIndex': originalIndex};
        }
        debugPrint(
          'VideoPlayer: resume entry S${season}E$episode not found in playlist for "${seriesPlaylist.seriesTitle}"',
        );
      }
    } catch (e) {
      debugPrint('VideoPlayer: failed to read last episode resume: $e');
    }
    return null;
  }

  Future<void> _onPlaybackEnded() async {
    // A manually selected replacement is not playback until its validation
    // gate commits it. In particular, a short provider error video can emit
    // `completed`; never let that become a watched/scrobble event.
    if (_validationGateActive) return;
    // LIVE IPTV: an ended live stream is a dropped connection, not a
    // finished item"È›y¯ßy‘ the origin closed on us (mpv's keep-open parks on the
    // last frame, which is the "fake pause" from the Discord report). The
    // recovery machine re-tunes to the live edge; nothing below this line
    // (scrobble stop, mark-as-finished, episode advance) may interpret a
    // live EOF as "watched to the end" ∫w^~)ﬁt so live returns here even when the
    // machine declines (backgrounded, sleep-stopped).
    final endedLiveChannel = _currentIptvChannel;
    if (endedLiveChannel != null && endedLiveChannel.isLive) {
      _iptvLiveRecovery.onEnded();
      return;
    }

    // Scrobble stop to Trakt when movie finishes
    _stopTraktHeartbeat();
    _traktScrobble('stop');
    _stopSimklHeartbeat();
    _simklScrobble('stop');
    _mdblistStop(complete: true);

    // Mark the current episode as finished if it's a series
    await _markCurrentEpisodeAsFinished();
    // A locally tracked movie may finish before the next periodic position
    // save; make EOF a completion too (tracker sessions keep their existing
    // scrobble-only path above).
    await _markCurrentMovieAsFinished();

    // "Stop at the end of this episode": suppress every advance below and let
    // the screen sleep. Playback has already finished, so there is nothing
    // left to pause.
    if (_sleepTimerMode == SleepTimerMode.endOfItem) {
      _cancelSleepTimer();
      _sleepStopLatched = true;
      _activeMediaShouldPlay = false;
      _showSleepTimerToast('Sleep timer ∫w^~)ﬁt stopping here');
      return;
    }

    // IPTV episode list (series/VOD): advance to the next episode in the
    // season, mirroring the Next button. Checked first because IPTV episodes
    // carry no playlist / magic-next, so the branches below would otherwise
    // leave the player parked on the final frame with a next episode available.
    if (_hasIptvNext) {
      await _switchToIptvChannel(_currentIptvIndex + 1);
      return;
    }

    // Playlist auto-advance keeps priority over guide-based Stremio TV next.
    if (_continuousShuffleEnabled) {
      if (await _playShowShuffle(autoAdvance: true)) return;
      final shuffleIndex = _pickShuffleIndex();
      if (shuffleIndex != null) {
        _isAutoAdvancing = true;
        await _loadPlaylistIndex(shuffleIndex, autoplay: true);
        return;
      }
    }

    final nextIndex = _findNextEpisodeIndex();
    if (nextIndex != -1) {
      _isAutoAdvancing = true;
      await _loadPlaylistIndex(nextIndex, autoplay: true);
      return;
    }

    if (_hasStremioTvNext) {
      final handled = await _goToNextStremioTvSlot(
        resumeCurrentOnFailure: false,
      );
      if (handled) return;
      debugPrint(
        'Player: Stremio TV auto-next unavailable; leaving playback ended.',
      );
      return;
    }

    // Debrify TV (no playlist): auto-advance using provider if available
    if ((_activePlaylist == null || _activePlaylist!.isEmpty) &&
        widget.requestMagicNext != null) {
      await _goToNextEpisode();
      return;
    }

    // Match manual Next for direct links and exhausted packs: keep the player
    // alive while resolving the following episode.
    if (await _fetchNextEpisodeInPlayer(autoAdvance: true)) return;

    if (_activePlaylist == null || _activePlaylist!.isEmpty) {
      // No playlist+ßuÁ‚ùÁT try series next episode
      await _handleSeriesNextEpisode();
      return;
    }

    // End of playlist"È›y¯ßy‘ try series next episode
    await _handleSeriesNextEpisode();
  }

  void _startTransitionOverlay() {
    if (!mounted) return;
    _rainbowActive = true;
    _transitionRunning = true;
    _transitionStopTimer?.cancel();
    _transitionPhaseTimer?.cancel();
    _transitionPhase = 1;
    // Pick a random retro TV message and reset subtext
    _tvStaticMessage =
        _tvStaticMessages[math.Random().nextInt(_tvStaticMessages.length)];
    _tvStaticSubtext = ''; // Clear subtext until video is ready
    debugPrint('Player: Transition overlay started.');
    // Match Android TV: update every 50ms for smooth static effect
    _rainbowController.repeat(
      period: VideoPlayerTimingConstants.rainbowRepeatPeriod,
    );
    if (mounted) setState(() {});
  }

  /// Get the current episode title for display
  String _getCurrentEpisodeTitle() => _getCurrentEpisodeTitleInfo().title;

  /// The dock title plus whether it's a fetched, human name (TVMaze episode
  /// title, catalog content title, channel name) as opposed to a release
  /// filename. TvControls skips its release-noise cleaner for fetched names ∫w^~)ﬁt
  /// the token list would truncate a real title containing e.g. "Proper".
  ({String title, bool fetched}) _getCurrentEpisodeTitleInfo() {
    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null &&
        seriesPlaylist.isSeries &&
        _activePlaylist != null) {
      // Find the current episode info
      if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
        try {
          final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
            (episode) => episode.originalIndex == _currentIndex,
            orElse: () => seriesPlaylist.allEpisodes.first,
          );

          // Return episode title if available, otherwise use the playlist entry title
          if (currentEpisode.episodeInfo?.title != null &&
              currentEpisode.episodeInfo!.title!.isNotEmpty) {
            final episodeTitle = currentEpisode.episodeInfo!.title!;
            // "Show"È›y¯ßy‘ Episode" when TVMaze supplied the official show name;
            // the subtitle then drops the name to avoid saying it twice.
            final show = seriesPlaylist.tvmazeShowName;
            return (
              title: show == null || show.isEmpty
                  ? episodeTitle
                  : '$show ∫w^~)ﬁt $episodeTitle',
              fetched: true,
            );
          } else if (currentEpisode.seriesInfo.season != null &&
              currentEpisode.seriesInfo.episode != null) {
            // Catalog singleton without TVMaze data yet: the clean catalog
            // title beats a bare "Episode N".
            final contentTitle = _effectiveContentTitle;
            if (_activePlaylist!.length == 1 &&
                contentTitle != null &&
                contentTitle.isNotEmpty &&
                _effectiveStremioTvChannels == null) {
              return (title: contentTitle, fetched: true);
            }
            final episodeTitle = 'Episode ${currentEpisode.seriesInfo.episode}';
            final show = seriesPlaylist.tvmazeShowName;
            return (
              title: show == null || show.isEmpty
                  ? episodeTitle
                  : '$show+ßuÁ‚ùÁT $episodeTitle',
              fetched: true,
            );
          }
        } catch (e) {
          // Silently fail
        }
      }
    }

    // Stremio TV: use dynamic title when a channel switch has occurred
    if (_hasStremioTvGuide && _dynamicTitle.isNotEmpty) {
      return (title: _dynamicTitle, fetched: true);
    }

    // Catalog single stream (Quick Play / Sources tap): prefer the clean
    // content title over the release filename. Packs are handled by the
    // series branch above; Debrify TV, IPTV and Stremio TV keep their
    // dynamic titles.
    final contentTitle = _effectiveContentTitle;
    if (contentTitle != null &&
        contentTitle.isNotEmpty &&
        widget.requestMagicNext == null &&
        _effectiveIptvChannels == null &&
        _effectiveStremioTvChannels == null &&
        (_activePlaylist == null || _activePlaylist!.length <= 1)) {
      return (title: contentTitle, fetched: true);
    }

    // Fallback to the current playlist entry title
    if (_activePlaylist != null &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      return (title: _activePlaylist![_currentIndex].title, fetched: false);
    }

    // If Debrify TV (no playlist) is active, use dynamic title when available
    // (a Debrify TV title can be a torrent name ∫w^~)ﬁt keep the cleaner on it).
    if ((_activePlaylist == null || _activePlaylist!.isEmpty) &&
        widget.requestMagicNext != null) {
      return _dynamicTitle.isNotEmpty
          ? (title: _dynamicTitle, fetched: false)
          : (title: widget.title, fetched: false);
    }

    // IPTV: use current channel name
    final iptvChannels = _effectiveIptvChannels;
    if (iptvChannels != null &&
        _currentIptvIndex >= 0 &&
        _currentIptvIndex < iptvChannels.length) {
      return (
        title: iptvChannels[_currentIptvIndex].numberedName,
        fetched: true,
      );
    }

    // Final fallback
    return (title: widget.title, fetched: false);
  }

  /// Get the current episode subtitle for display
  String? _getCurrentEpisodeSubtitle() {
    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null &&
        seriesPlaylist.isSeries &&
        _activePlaylist != null) {
      // Find the current episode info
      if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
        try {
          final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
            (episode) => episode.originalIndex == _currentIndex,
            orElse: () => seriesPlaylist.allEpisodes.first,
          );

          // Return series name and season/episode info as subtitle
          if (currentEpisode.seriesInfo.season != null &&
              currentEpisode.seriesInfo.episode != null) {
            // Catalog singleton: the filename-parsed series name can be a
            // mangled release string; the clean catalog title is authoritative.
            // While TVMaze hasn't supplied an episode title yet, the title line
            // is already showing the catalog name+ßuÁ‚ùÁT don't repeat it here.
            final contentTitle = _effectiveContentTitle;
            final isCatalogSingleton =
                _activePlaylist!.length == 1 &&
                contentTitle != null &&
                contentTitle.isNotEmpty &&
                _effectiveStremioTvChannels == null;
            final seasonEpisode =
                'Season ${currentEpisode.seriesInfo.season}, Episode ${currentEpisode.seriesInfo.episode}';
            // When TVMaze supplied the show name, the TITLE line already
            // reads "Show ∫w^~)ﬁt Episode", so repeating the name here would say
            // it twice. Without it, fall back to the filename-parsed series
            // name+ßuÁ‚ùÁT release strings only as a last resort, same rule as the
            // native player's OTT identity row.
            final showName = seriesPlaylist.tvmazeShowName;
            if (showName != null && showName.isNotEmpty) {
              return seasonEpisode;
            }
            if (isCatalogSingleton) {
              final hasEpisodeTitle =
                  currentEpisode.episodeInfo?.title?.isNotEmpty == true;
              return hasEpisodeTitle
                  ? '$contentTitle"È›y¯ßy“ $seasonEpisode'
                  : seasonEpisode;
            }
            return '${seriesPlaylist.seriesTitle}"È›y¯ßy“ $seasonEpisode';
          }
        } catch (e) {}
      }
    }

    // IPTV: use current channel group as subtitle
    final iptvChannels = _effectiveIptvChannels;
    if (iptvChannels != null &&
        _currentIptvIndex >= 0 &&
        _currentIptvIndex < iptvChannels.length) {
      return iptvChannels[_currentIptvIndex].group ?? 'IPTV';
    }

    // Catalog single stream: when the title shows the clean content name,
    // surface the episode identity (and the release detail line) here.
    final contentTitle = _effectiveContentTitle;
    if (contentTitle != null &&
        contentTitle.isNotEmpty &&
        widget.requestMagicNext == null &&
        _effectiveStremioTvChannels == null &&
        (_activePlaylist == null || _activePlaylist!.length <= 1)) {
      final season = _effectiveContentSeason;
      final episode = _effectiveContentEpisode;
      final parts = <String>[
        if (season != null && episode != null)
          'Season $season, Episode $episode',
        if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty)
          widget.subtitle!,
      ];
      if (parts.isNotEmpty) return parts.join(' ∫w^~)ﬁv ');
    }

    // Fallback to the current subtitle or widget subtitle
    return widget.subtitle;
  }

  /// Get enhanced metadata for OTT-style display
  Map<String, dynamic> _getEnhancedMetadata() {
    final seriesPlaylist = _seriesPlaylist;

    if (seriesPlaylist != null &&
        seriesPlaylist.isSeries &&
        _activePlaylist != null) {
      // Find the current episode info
      if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
        try {
          final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
            (episode) => episode.originalIndex == _currentIndex,
            orElse: () => seriesPlaylist.allEpisodes.first,
          );

          if (currentEpisode.episodeInfo != null) {
            final episodeInfo = currentEpisode.episodeInfo!;

            final metadata = {
              'rating': episodeInfo.rating,
              'runtime': episodeInfo.runtime,
              'year': episodeInfo.year,
              'airDate': episodeInfo.airDate,
              'language': episodeInfo.language,
              'genres': episodeInfo.genres,
              'network': episodeInfo.network,
              'country': episodeInfo.country,
              'plot': episodeInfo.plot,
            };

            return metadata;
          }
        } catch (e) {}
      }
    }

    return {};
  }

  /// Find the next logical episode index for auto-advance
  int _findNextEpisodeIndex() {
    final seriesPlaylist = _seriesPlaylist;

    if (seriesPlaylist == null || !seriesPlaylist.isSeries) {
      // Raw mode OR Sorted mode: sequential navigation through all files
      // In sorted mode, files are already pre-sorted A-Z, so sequential = alphabetical
      if (widget.viewMode == PlaylistViewMode.raw ||
          widget.viewMode == PlaylistViewMode.sorted) {
        if (_activePlaylist == null || _activePlaylist!.isEmpty) return -1;
        if (_currentIndex + 1 < _activePlaylist!.length) {
          return _currentIndex + 1;
        }
        return -1;
      }

      // Collection mode (view mode not specified): navigate within Main group only
      if (_activePlaylist == null || _activePlaylist!.isEmpty) return -1;
      final indices = _getMainGroupIndices(_activePlaylist!);
      if (indices.isEmpty) return -1;

      final currentPos = indices.indexOf(_currentIndex);
      if (currentPos == -1) {
        return indices.first;
      }

      if (currentPos + 1 < indices.length) {
        return indices[currentPos + 1];
      }

      return -1;
    }

    // Series mode: existing logic
    try {
      // Find current episode in the sorted allEpisodes list
      final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
        (episode) => episode.originalIndex == _currentIndex,
        orElse: () {
          if (seriesPlaylist.allEpisodes.isEmpty) {
            throw StateError('allEpisodes is empty');
          }
          return seriesPlaylist.allEpisodes.first;
        },
      );

      // Find the index of current episode in allEpisodes
      final currentEpisodeIndex = seriesPlaylist.allEpisodes.indexOf(
        currentEpisode,
      );

      if (currentEpisodeIndex == -1 ||
          currentEpisodeIndex + 1 >= seriesPlaylist.allEpisodes.length) {
        return -1;
      }

      // Get the next episode from the sorted list
      final nextEpisode = seriesPlaylist.allEpisodes[currentEpisodeIndex + 1];
      return nextEpisode.originalIndex;
    } catch (e) {
      return -1;
    }
  }

  /// Compute the Main group indices for movie collections (size >= 70% of largest)
  List<int> _getMainGroupIndices(List<PlaylistEntry> entries) {
    int maxSize = -1;
    for (final e in entries) {
      final s = e.sizeBytes ?? -1;
      if (s > maxSize) maxSize = s;
    }
    final double threshold = maxSize > 0 ? maxSize * 0.40 : -1;
    final main = <int>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final isSmall =
          threshold > 0 && (e.sizeBytes != null && e.sizeBytes! < threshold);
      if (!isSmall) main.add(i);
    }
    int sizeOf(int idx) => entries[idx].sizeBytes ?? -1;
    int? yearOf(int idx) {
      final m = RegExp(r'\b(19|20)\d{2}\b').firstMatch(entries[idx].title);
      if (m != null) return int.tryParse(m.group(0)!);
      return null;
    }

    main.sort((a, b) {
      final ya = yearOf(a);
      final yb = yearOf(b);
      if (ya != null && yb != null) return ya.compareTo(yb); // older first
      return sizeOf(b).compareTo(sizeOf(a));
    });
    return main;
  }

  Future<void> _showRandomPlaybackMenu() async {
    final entries = _activePlaylist ?? const [];
    if (entries.isEmpty && !_canFetchEpisodes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlist items available')),
      );
      return;
    }

    if (kUnifiedPlayerMenuEnabled) {
      _openPlayerMenuQuick(PlayerMenuSection.shuffle);
      return;
    }

    _hideTimer?.cancel();
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        final shuffleLabel = _continuousShuffleEnabled
            ? 'Turn Off Continuous Shuffle'
            : 'Shuffle Continuously';
        final shuffleSubtitle = _continuousShuffleEnabled
            ? 'Return to normal ordered playback'
            : 'Keep picking random items after each episode ends';

        return AlertDialog(
          backgroundColor: const Color(0xFF141824),
          title: const Text(
            'Shuffle Playback',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RandomChoiceTile(
                icon: Icons.shuffle_rounded,
                title: 'Play Random Once',
                subtitle: 'Pick one random item, then resume normal order',
                onTap: () => Navigator.of(context).pop('once'),
              ),
              const SizedBox(height: 8),
              _RandomChoiceTile(
                icon: _continuousShuffleEnabled
                    ? Icons.check_circle_rounded
                    : Icons.all_inclusive_rounded,
                title: shuffleLabel,
                subtitle: shuffleSubtitle,
                onTap: () => Navigator.of(context).pop('continuous'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    _scheduleAutoHide();

    if (choice == 'once') {
      await _playRandomOnce(disableContinuousShuffle: true);
    } else if (choice == 'continuous') {
      await _toggleContinuousShuffle();
    }
  }

  Future<void> _toggleContinuousShuffle() async {
    if (_continuousShuffleEnabled) {
      setState(() {
        _continuousShuffleEnabled = false;
        _shuffleBag.clear();
        _showShuffle.clear();
        _showShuffleGeneration++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Continuous shuffle off')));
    } else {
      setState(() {
        _continuousShuffleEnabled = true;
        _shuffleBag.clear();
        _showShuffle.clear();
        _showShuffleGeneration++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Continuous shuffle on')));
      await _playRandomOnce(disableContinuousShuffle: false);
    }
  }

  Future<void> _playRandomOnce({required bool disableContinuousShuffle}) async {
    if (disableContinuousShuffle) {
      if (_continuousShuffleEnabled) {
        setState(() {
          _continuousShuffleEnabled = false;
          _shuffleBag.clear();
          _showShuffle.clear();
          _showShuffleGeneration++;
        });
      } else {
        _shuffleBag.clear();
        _showShuffle.clear();
        _showShuffleGeneration++;
      }
    }

    if (await _playShowShuffle()) return;
    final nextIndex = _pickShuffleIndex();
    if (nextIndex == null) return;
    _setManualSelectionMode();
    await _loadPlaylistIndex(nextIndex, autoplay: true);
  }

  /// Returns true when show-wide shuffle owns this request, including failure.
  /// Never fall through to ordered playback after exhausting random candidates.
  Future<bool> _playShowShuffle({bool autoAdvance = false}) async {
    if (!_canFetchEpisodes) return false;
    final generation = _showShuffleGeneration;
    final navigation = _episodeNavigationGeneration;
    while (_showShuffleInProgress || _episodeFetchInProgress) {
      if (_showShuffleInProgress &&
          _activeShowShuffleGeneration == generation) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (!mounted ||
          generation != _showShuffleGeneration ||
          navigation != _episodeNavigationGeneration) {
        return true;
      }
    }
    _showShuffleInProgress = true;
    _activeShowShuffleGeneration = generation;
    bool requestIsCurrent() =>
        mounted &&
        generation == _showShuffleGeneration &&
        (!autoAdvance || !_sleepStopLatched);
    final request = EpisodePlaybackRequest(
      currentIdentity: () => _playlistIdentityToken,
      currentNavigation: () => _episodeNavigationGeneration,
      isActive: requestIsCurrent,
    );
    try {
      await (_episodeMetadataReady ??= _preloadEpisodeInfo());
      if (!request.isCurrent) return true;
      if (_seriesPlaylist == null) {
        final synthetic = _buildSyntheticGuide();
        if (synthetic != null && synthetic.$1.fullTvmazeEpisodes.isEmpty) {
          await synthetic.$1.fetchEpisodeInfo(
            playlistItem: _constructPlaylistItemData(),
            imdbId: _currentSeriesImdbId,
          );
        }
      }
      if (!request.isCurrent) return true;
      final full = _seriesPlaylist?.fullTvmazeEpisodes.isNotEmpty == true
          ? _seriesPlaylist!.fullTvmazeEpisodes
          : (_syntheticGuidePlaylist?.fullTvmazeEpisodes ??
                const <Map<String, dynamic>>[]);
      if (full.isEmpty) return false;
      final eligible = full
          .where((m) => isShuffleEpisodeEligible(m))
          .map((m) => (m['season'] as int, m['number'] as int))
          .toList();
      final attempted = <ShuffleEpisode>{};
      for (var attempt = 0; attempt < 3; attempt++) {
        final current = _traktSeasonEpisode();
        final target = _showShuffle.pick(
          eligible,
          current.season == null || current.episode == null
              ? null
              : (current.season!, current.episode!),
          excluded: attempted,
        );
        if (target == null) break;
        attempted.add(target);
        final index =
            _seriesPlaylist?.findOriginalIndexBySeasonEpisode(
              target.$1,
              target.$2,
            ) ??
            -1;
        if (index >= 0) {
          // EOF loads must retain sleep-stop and start-from-zero semantics,
          // including when URL resolution outlasts the manual-selection timer.
          _isAutoAdvancing = autoAdvance;
          if (!autoAdvance) _setManualSelectionMode();
          final outcome = await request.attempt(
            () => _loadPlaylistIndex(
              index,
              autoplay: true,
              suppressResume: true,
              request: request,
            ),
          );
          if (outcome != EpisodePlaybackOutcome.unavailable) return true;
          // A pack entry can have an unavailable URL. Try another source for
          // this episode before moving on to the next random candidate.
        }
        final outcome = await _fetchAndPlayEpisode(
          target.$1,
          target.$2,
          shuffleGeneration: generation,
          autoAdvance: autoAdvance,
          request: request,
        );
        if (outcome != EpisodePlaybackOutcome.unavailable) return true;
      }
      if (mounted) {
        setState(() => _isTransitioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No other playable episode found for shuffle'),
          ),
        );
      }
      return true;
    } catch (error) {
      debugPrint('Show shuffle failed: $error');
      if (mounted) {
        setState(() => _isTransitioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load a random episode')),
        );
      }
      return true;
    } finally {
      _showShuffleInProgress = false;
      _activeShowShuffleGeneration = null;
      if (mounted && generation != _showShuffleGeneration && _isTransitioning) {
        setState(() => _isTransitioning = false);
      }
    }
  }

  List<int> _shuffleEligibleIndices() {
    final entries = _activePlaylist;
    if (entries == null || entries.isEmpty) return const [];

    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null && seriesPlaylist.isSeries) {
      final indices = seriesPlaylist.allEpisodes
          .map((episode) => episode.originalIndex)
          .where((index) => index >= 0 && index < entries.length)
          .toSet()
          .toList();
      if (indices.isNotEmpty) return indices;
    }

    if (widget.viewMode == PlaylistViewMode.raw ||
        widget.viewMode == PlaylistViewMode.sorted) {
      return List<int>.generate(entries.length, (index) => index);
    }

    final mainIndices = _getMainGroupIndices(
      entries,
    ).where((index) => index >= 0 && index < entries.length).toList();
    if (mainIndices.isNotEmpty) return mainIndices;

    return List<int>.generate(entries.length, (index) => index);
  }

  int? _pickShuffleIndex() {
    final eligible = _shuffleEligibleIndices();
    if (eligible.isEmpty) return null;
    if (eligible.length == 1) return eligible.first;

    final eligibleSet = eligible.toSet();
    _shuffleBag.removeWhere(
      (index) => !eligibleSet.contains(index) || index == _currentIndex,
    );

    if (_shuffleBag.isEmpty) {
      _shuffleBag.addAll(
        eligible.where((index) => index != _currentIndex).toList()
          ..shuffle(_random),
      );
    }

    if (_shuffleBag.isEmpty) return null;
    return _shuffleBag.removeLast();
  }

  /// Find the previous logical episode index
  int _findPreviousEpisodeIndex() {
    final seriesPlaylist = _seriesPlaylist;

    if (seriesPlaylist == null || !seriesPlaylist.isSeries) {
      // Raw mode OR Sorted mode: sequential navigation through all files
      // In sorted mode, files are already pre-sorted A-Z, so sequential = alphabetical
      if (widget.viewMode == PlaylistViewMode.raw ||
          widget.viewMode == PlaylistViewMode.sorted) {
        if (_activePlaylist == null || _activePlaylist!.isEmpty) return -1;
        if (_currentIndex - 1 >= 0) {
          return _currentIndex - 1;
        }
        return -1;
      }

      // Collection mode (view mode not specified): navigate within Main group only
      if (_activePlaylist == null || _activePlaylist!.isEmpty) return -1;
      final indices = _getMainGroupIndices(_activePlaylist!);
      if (indices.isEmpty) return -1;

      final currentPos = indices.indexOf(_currentIndex);
      if (currentPos == -1) {
        return indices.first;
      }

      if (currentPos - 1 >= 0) {
        return indices[currentPos - 1];
      }

      return -1;
    }

    // Series mode: existing logic
    try {
      // Find current episode in the sorted allEpisodes list
      final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
        (episode) => episode.originalIndex == _currentIndex,
        orElse: () {
          if (seriesPlaylist.allEpisodes.isEmpty) {
            throw StateError('allEpisodes is empty');
          }
          return seriesPlaylist.allEpisodes.first;
        },
      );

      // Find the index of current episode in allEpisodes
      final currentEpisodeIndex = seriesPlaylist.allEpisodes.indexOf(
        currentEpisode,
      );

      if (currentEpisodeIndex <= 0) {
        return -1;
      }

      // Get the previous episode from the sorted list
      final previousEpisode =
          seriesPlaylist.allEpisodes[currentEpisodeIndex - 1];
      return previousEpisode.originalIndex;
    } catch (e) {
      return -1;
    }
  }

  /// Check if there's a next episode available
  bool _hasNextEpisode() {
    if (_findNextEpisodeIndex() != -1) return true;
    // Series content may have a next episode discoverable via Stremio metadata.
    // Requires episode info from widget params or a parsed series playlist.
    if (widget.requestMagicNext == null &&
        widget.contentType == 'series' &&
        widget.contentImdbId != null &&
        (widget.contentSeason != null || _seriesPlaylist != null)) {
      return true;
    }
    return false;
  }

  /// Check if there's a previous episode available
  bool _hasPreviousEpisode() {
    if (_findPreviousEpisodeIndex() != -1) return true;
    // Beyond the pack's start: a previous episode may exist show-wide and be
    // fetchable in-player (metadata-list adjacency decides at press time).
    if (_canFetchEpisodes) {
      final se = _traktSeasonEpisode();
      if (se.season != null && se.episode != null) {
        return _adjacentEpisode(se.season!, se.episode!, -1) != null;
      }
    }
    return false;
  }

  void _clearBufferingIndicator() {
    _bufferingDebounceTimer?.cancel();
    _showBufferingIndicator.value = false;
  }

  /// Navigate to next episode
  Future<void> _goToNextEpisode() async {
    // Check if widget is still mounted before any state changes
    if (!mounted) return;

    // Show black screen during transition to hide previous frame
    _clearBufferingIndicator();
    setState(() {
      _isTransitioning = true;
      _tvScrubGeneration++;
      _tvAbandonScrub();
    });

    // Only show transition overlay for Debrify TV content (when requestMagicNext is available)
    final isDebrifyTV = widget.requestMagicNext != null;
    if (isDebrifyTV) {
      _startTransitionOverlay();
    }
    try {
      await _player.pause();
    } catch (_) {}
    if (_continuousShuffleEnabled) {
      if (await _playShowShuffle()) return;
      final shuffleIndex = _pickShuffleIndex();
      if (shuffleIndex != null) {
        _setManualSelectionMode();
        await _loadPlaylistIndex(shuffleIndex, autoplay: true);
        return;
      }
    }

    final nextIndex = _findNextEpisodeIndex();
    if (nextIndex != -1) {
      // Mark this as a manual episode selection
      _setManualSelectionMode();
      await _loadPlaylistIndex(nextIndex, autoplay: true);
      return;
    }

    if (_hasStremioTvNext) {
      final handled = await _goToNextStremioTvSlot();
      if (handled) return;
    }

    // Series content beyond the pack: fetch the next episode IN-PLAYER when
    // possible (no relaunch), falling back to the pop-and-quick-play handoff.
    if (await _fetchNextEpisodeInPlayer()) return;

    // Series content without season pack: find next episode and trigger Quick Play
    if (widget.requestMagicNext == null) {
      final handled = await _handleSeriesNextEpisode();
      if (handled) return;
    }

    // If there is no playlist-based next item and Debrify TV provider is present, use it
    if (widget.requestMagicNext != null) {
      debugPrint('Player: MagicTV next requested.');
      try {
        final result = await widget.requestMagicNext!();
        final url = result != null ? (result['url'] ?? '') : '';
        final title = result != null ? (result['title'] ?? '') : '';
        final provider = result != null ? (result['provider'] ?? '') : '';
        final pikpakFileId = result != null
            ? (result['pikpakFileId'] ?? '')
            : '';

        if (url.isNotEmpty) {
          debugPrint(
            'Player: MagicTV next success. Opening new URL (provider: $provider, pikpakFileId: $pikpakFileId).',
          );

          // Clear subtitle, IMDB, and local completion state when switching content
          _resetSubtitleState();
          _singleFileImdbId = null;
          _singleFileImdbFetched = false;
          _resetLocalCompletionState();

          // Update TV static overlay to show signal acquired
          if (title.isNotEmpty && mounted) {
            setState(() {
              _tvStaticMessage = &È›y¯ßy€ßuÁ‚ùÁz SIGNAL ACQUIRED';
              _tvStaticSubtext = +ßuÁ‚ùÁv ${title.toUpperCase()}';
            });
          }

          // Use PikPak retry logic if this is a PikPak video
          final isPikPak =
              provider.toLowerCase() == 'pikpak' || pikpakFileId.isNotEmpty;
          if (isPikPak) {
            debugPrint(
              'Player: Detected PikPak video from Debrify TV, using retry logic',
            );
            // _playPikPakVideoWithRetry will increment _pikPakRetryId to cancel previous retries
            await _playPikPakVideoWithRetry(
              url,
              overrideProvider: provider,
              overridePikPakFileId: pikpakFileId,
              isDebrifyTV: true,
            );
          } else {
            // Cancel any ongoing PikPak retry when switching to non-PikPak video
            _pikPakRetryId++;
            await _openMedia(
              mk.Media(url, httpHeaders: _activeHttpHeaders),
              play: true,
            );
          }
          _currentStreamUrl = url;
          // Disable auto-enabled embedded subtitles to prevent duplicates
          await _setSubtitleTrackWithDiagnostics(
            mk.SubtitleTrack.no(),
            source: 'debrify-tv-open-disable-auto',
          );
          // If advanced option is enabled, jump to a random timestamp for Debrify TV items
          if (widget.startFromRandom) {
            await _waitForVideoReady();
            final offset = _randomStartOffset(_duration);
            if (offset != null) {
              await _player.seek(offset);
            }
          } else if (widget.startAtPercent != null) {
            await _waitForVideoReady();
            final offset = _percentStartOffset(_duration);
            if (offset != null) {
              await _player.seek(offset);
            }
          }
          if (title.isNotEmpty) {
            setState(() {
              _dynamicTitle = title;
            });
          }
          // Clear transition state when video is ready
          if (mounted) {
            setState(() {
              _isTransitioning = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Player: MagicTV next failed: $e');
      }
    }

    // Clear transition state if no next episode found
    if (mounted) {
      setState(() {
        _isTransitioning = false;
      });
    }
  }

  /// Shared manual/EOF path beyond the current pack. A handled fetch, including
  /// cancellation or failure, stays in-player rather than relaunching it.
  Future<bool> _fetchNextEpisodeInPlayer({bool autoAdvance = false}) async {
    if (!_canFetchEpisodes) return false;
    if (_episodeFetchInProgress) return true;
    final identity = _playlistIdentityToken;
    final navigation = _episodeNavigationGeneration;
    bool stale() =>
        !mounted ||
        identity != _playlistIdentityToken ||
        navigation != _episodeNavigationGeneration ||
        (autoAdvance && _sleepStopLatched);
    if (stale()) return true;
    final se = _traktSeasonEpisode();
    if (se.season == null || se.episode == null) return false;
    var next = _adjacentEpisode(se.season!, se.episode!, 1);
    if (next == null && widget.contentImdbId != null) {
      final episode = await NextEpisodeService.findNextEpisode(
        widget.contentImdbId!,
        se.season!,
        se.episode!,
      );
      if (episode != null) next = (episode.season, episode.episode);
    }
    if (stale()) return true;
    if (next == null) return false;
    debugPrint(
      'Player: Next episode S${next.$1}E${next.$2} in-player autoAdvance=$autoAdvance',
    );
    await _fetchAndPlayEpisode(next.$1, next.$2, autoAdvance: autoAdvance);
    return true;
  }

  /// Legacy fallback: pop with the next episode for the caller's Quick Play.
  Future<bool> _handleSeriesNextEpisode() async {
    // Already popping to hand off the next episode"È›y¯ßy‘ a second trigger (manual
    // Next racing end-of-video auto-advance) must not run again.
    if (_seriesNextDispatched) return true;
    if (widget.contentType != 'series' || widget.contentImdbId == null) {
      return false;
    }

    // Determine the CURRENT episode: prefer the series playlist (tracks actual
    // playback position within a season pack) over widget params (set at launch).
    int? currentSeason;
    int? currentEpisode;

    final seriesPlaylist = _seriesPlaylist;
    if (seriesPlaylist != null &&
        seriesPlaylist.isSeries &&
        _activePlaylist != null &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      try {
        final current = seriesPlaylist.allEpisodes.firstWhere(
          (ep) => ep.originalIndex == _currentIndex,
        );
        currentSeason = current.seriesInfo.season;
        currentEpisode = current.seriesInfo.episode;
      } catch (_) {
        // firstWhere threw ∫w^~)ﬁt no match, fall through to widget params
      }
    }

    // Fallback to widget params (single-file playback without a series playlist)
    currentSeason ??= widget.contentSeason;
    currentEpisode ??= widget.contentEpisode;

    if (currentSeason == null || currentEpisode == null) return false;

    debugPrint(
      'Player: Looking up next episode after S${currentSeason}E$currentEpisode',
    );
    final nextEp = await NextEpisodeService.findNextEpisode(
      widget.contentImdbId!,
      currentSeason,
      currentEpisode,
    );

    if (nextEp == null) {
      debugPrint(
        'Player: No next episode found (last episode or lookup failed)',
      );
      return false;
    }

    debugPrint(
      'Player: Found next episode S${nextEp.season}E${nextEp.episode}, popping for Quick Play',
    );
    // Re-check the guard right before popping. Because nothing awaits between
    // here and the pop, this set-and-pop is atomic on Dart's single thread, so
    // a concurrent call that already passed the top guard and is resuming from
    // its own await will see the flag set and return without a second pop.
    if (!mounted || _seriesNextDispatched) return true;
    _seriesNextDispatched = true;
    final result = <String, dynamic>{
      'quickPlayNext': true,
      'imdbId': widget.contentImdbId,
      'season': nextEp.season,
      'episode': nextEp.episode,
      'title': widget.contentTitle ?? widget.title,
      'contentType': widget.contentType,
    };
    if (_iosPipSession?.isParked ?? false) {
      _iosPipSession!.close(result);
    } else {
      Navigator.of(context).pop(result);
    }
    return true;
  }

  /// Parse channel directory from widget params into ChannelEntry list
  void _parseChannelDirectory() {
    final directory = widget.channelDirectory;
    if (directory == null || directory.isEmpty) {
      _channelEntries = [];
      return;
    }

    _channelEntries = directory.asMap().entries.map((e) {
      final entry = ChannelEntry.fromMap(e.value, order: e.key);
      // Check if this is the current channel
      if (entry.isCurrent && _currentChannelId == null) {
        _currentChannelId = entry.id;
        if (entry.number != null) _currentChannelNumber = entry.number;
      }
      return entry;
    }).toList();
  }

  /// Load subtitle style settings
  Future<void> _loadSubtitleSettings() async {
    final settings = await SubtitleSettingsService.instance.loadAll();
    if (mounted) {
      setState(() {
        _subtitleSettings = settings;
      });
      if (settings.syncOffsetMs != 0) {
        _applySubtitleSyncOffset(settings.syncOffsetMs);
      }
    }
  }

  /// Load default player settings (aspect)
  /// The vertical band at the bottom of the screen the dock occupies.
  ///
  /// `classic` keeps the literal each consumer has always used; only the
  /// styled dock, whose height is variable, reports a measured value. The
  /// branch at six call sites is deliberate ∫w^~)ﬁt one uniform value is impossible,
  /// since the consumers' legacy constants are 160/28, 72 and 80.
  double _dockBand(double legacy) =>
      _dockStyle.isStyled ? math.max(legacy, _dockExtent.value) : legacy;

  /// Where the skip-segment button sits above the bottom edge.
  ///
  /// The legacy value is not simply "160": it is 160 only while controls are
  /// visible AND (television OR options shown), else 28. Televisions build
  /// `TvControls`, so the styled path never engages there.
  double _skipButtonBottom(
    BuildContext context,
    bool controlsVisible,
    double dockExtent,
  ) {
    if (!_dockStyle.isStyled) {
      return controlsVisible &&
              (PlatformUtil.isTelevision || !widget.hideOptions)
          ? 160
          : 28;
    }
    // `infoPanel` mounts OUTSIDE the hideOptions guard, so a live panel can be
    // on screen while `!hideOptions` is false.
    final dockVisible =
        controlsVisible &&
        (_buildIptvInfoPanel(flush: true) != null ||
            _buildDebrifyTvInfoPanel(flush: true) != null ||
            !widget.hideOptions);
    if (!dockVisible) return 28;
    final inset = MediaQuery.paddingOf(context).bottom;
    return math.max(28.0, dockExtent + 8 - inset);
  }

  Future<void> _loadDockPrefs() async {
    final style = await StorageService.getPlayerDockStyle();
    final palette = await StorageService.getPlayerDockPalette();
    final size = await StorageService.getPlayerDockSize();
    if (!mounted) return;
    setState(() {
      _dockStyle = PlayerDockStyle.fromPref(style);
      _dockPalette = PlayerDockPalette.fromPref(palette);
      _dockSize = PlayerDockSize.fromPref(size);
      // Style/size are part of the geometry signature but arrive here, not
      // through an inherited dependency.
      _lastDockGeometrySignature = '';
      // Deliberately NOT seeded to the viewport height. Over-protecting the
      // whole screen kills every gesture until the first measurement, and it
      // also strands the fallback case: when DockMetrics.compute returns null
      // the classic subtree renders and no reporter is ever mounted, so the
      // seed would never be corrected. 0 means `_dockBand` yields the legacy
      // constant, which is exactly right for both.
    });
  }

  Future<void> _loadPlayerDefaults() async {
    _subtitleAutoSyncEnabled =
        await StorageService.getSubtitleAutoSyncEnabled();
    debugPrint(
      'SubtitleAutoSync: pref loaded, enabled=$_subtitleAutoSyncEnabled',
    );
    // Load default aspect index
    final aspectIndex = await StorageService.getPlayerDefaultAspectIndex();
    const aspects = AspectMode.values;
    _aspectMode = aspects[aspectIndex.clamp(0, aspects.length - 1)];

    // In-player guide look. `_initializePlayer` awaits this before playback
    // setup, so every IPTV surface that can actually appear (first tune,
    // zap, guide) already has the real value.
    _playerGuideStyle = PlayerGuideStyle.fromPref(
      await StorageService.getIptvPlayerGuideStyle(),
    );
    _playerGuideTokens = PlayerGuideTokens.of(_playerGuideStyle);

    if (PlatformUtil.isTvOS) {
      _tvosForceSoftwareDecode =
          await StorageService.getTvosForceSoftwareDecode();
      _contentDisplayMatchMode =
          await StorageService.getContentDisplayMatchMode();
      if (!_contentDisplayMatchMode.requestsMatching) {
        try {
          await TvosDisplayMatchService.clear();
        } catch (error) {
          debugPrint('DisplayMatch: tvOS clear failed: $error');
        }
      }
    }

    // Audio-output settings, preloaded for [_configurePlayerAudio]"È›y¯ßy‘ the
    // single owner of ao / audio-spdif / audio-channels
    // (AUDIO_FIDELITY_PLAN.md).
    if (!kIsWeb && Platform.isAndroid) {
      _audioPassthroughEnabled =
          await StorageService.getAudioPassthroughEnabled();
      _systemAudioEffectsEnabled =
          await StorageService.getPlayerSystemAudioEffects();
    } else if (PlatformUtil.isTvOS || PlatformUtil.isIosMobile) {
      _appleMultichannelEnabled =
          await StorageService.getAppleMultichannelAudio();
    }
    if (PlatformUtil.isTvOS) {
      _tvosForceStereoAudio = await StorageService.getTvosForceStereoAudio();
      _tvosLegacyAudioOutput = await StorageService.getTvosLegacyAudioOutput();
      // What the CURRENT output route can take. ao_avfoundation passes the
      // file's native layout through, so a 5.1 track on a two-channel route
      // (AirPods, Bluetooth, stereo TV) folds badly; PlayerAudioConfig caps
      // those to stereo. 0 means "unknown" and leaves mpv's default alone.
      try {
        _tvosRouteOutputChannels =
            await _tvReleaseLogChannel.invokeMethod<int>(
              'outputChannelCount',
            ) ??
            0;
      } catch (_) {
        _tvosRouteOutputChannels = 0;
      }
    }

    debugPrint('VideoPlayer: Loaded defaults - aspect=$_aspectMode');
  }

  /// Update subtitle style settings
  void _onSubtitleStyleChanged(SubtitleSettingsData settings) {
    // Style saves are awaited before this fires, so it can land after the
    // whole player route is gone (close right after adjusting a style).
    if (!mounted) return;
    final offsetChanged =
        _subtitleSettings?.syncOffsetMs != settings.syncOffsetMs;
    setState(() {
      _subtitleSettings = settings;
    });
    if (offsetChanged) {
      _subtitleAutoSync?.manualOffsetChanged(settings.syncOffsetMs);
      _hideAutoSyncPill();
      _applySubtitleSyncOffset(settings.syncOffsetMs);
    }
  }

  void _applySubtitleSyncOffset(int ms) {
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      platform.setProperty('sub-delay', (ms / 1000.0).toStringAsFixed(3));
    }
  }

  /// Reset the sync offset to 0. The offset belongs to the specific subtitle it
  /// was dialed in against, so it must reset whenever the subtitle or the
  /// content changes. mpv's `sub-delay` is push-based, so zero it explicitly
  /// rather than relying on a stale in-memory value carrying over.
  void _resetSubtitleSyncOffset() {
    SubtitleSettingsService.instance.resetSyncOffset();
    // Keep the UI model in sync (no setState needed: the sync overlay is closed
    // on these transitions and no style rendering depends on the offset).
    _subtitleSettings = _subtitleSettings?.copyWith(syncOffsetMs: 0);
    _applySubtitleSyncOffset(0);
  }

  /// Overlays inside the player share its route scope, which already has a
  /// focused child (the player root)"È›y¯ßy‘ so their `autofocus` is silently
  /// discarded and the first OK does nothing. Releasing the current focus as
  /// the overlay appears lets its autofocus node claim it.
  void _tvReleaseFocusForOverlay() {
    if (!PlatformUtil.isTelevision) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showSyncOverlayPanel() {
    _tvReleaseFocusForOverlay();
    setState(() {
      _showSyncOverlay = true;
      _controlsVisible.value = false;
    });
  }

  void _hideSyncOverlay() {
    setState(() => _showSyncOverlay = false);
  }

  Widget _buildSyncOverlay() {
    final externalPath = _activeExternalSubtitlePath;
    if (externalPath != null) {
      return SubtitleLinePickerOverlay(
        subtitleFilePath: externalPath,
        getCurrentPositionMs: () => _player.state.position.inMilliseconds,
        currentOffsetMs: _subtitleSettings?.syncOffsetMs ?? 0,
        onOffsetChanged: (ms) async {
          await SubtitleSettingsService.instance.setSyncOffsetMs(ms);
          _subtitleAutoSync?.manualOffsetChanged(ms);
          _hideAutoSyncPill();
          _applySubtitleSyncOffset(ms);
          if (mounted) {
            setState(() {
              _subtitleSettings = _subtitleSettings?.copyWith(syncOffsetMs: ms);
            });
          }
        },
        onDismiss: _hideSyncOverlay,
      );
    }

    return _buildSliderSyncOverlay();
  }

  Widget _buildSliderSyncOverlay() {
    return SyncStepperOverlay(
      offsetMs: _subtitleSettings?.syncOffsetMs ?? 0,
      onOffsetChanged: (ms) async {
        final clamped = ms.clamp(
          SubtitleSettingsService.syncOffsetMinMs,
          SubtitleSettingsService.syncOffsetMaxMs,
        );
        await SubtitleSettingsService.instance.setSyncOffsetMs(clamped);
        _subtitleAutoSync?.manualOffsetChanged(clamped);
        _hideAutoSyncPill();
        _applySubtitleSyncOffset(clamped);
        if (mounted) {
          setState(() {
            _subtitleSettings = _subtitleSettings?.copyWith(
              syncOffsetMs: clamped,
            );
          });
        }
      },
      onDismiss: _hideSyncOverlay,
    );
  }

  /// Show channel guide overlay
  void _showChannelGuideOverlay() {
    if (_channelEntries.isEmpty) {
      debugPrint('Player: No channels available for guide');
      return;
    }
    _hideIptvZapBanner();
    setState(() {
      _showChannelGuide = true;
      _controlsVisible.value = false;
    });
  }

  /// Hide channel guide overlay
  void _hideChannelGuideOverlay() {
    setState(() {
      _showChannelGuide = false;
    });
  }

  /// Show IPTV channel sheet overlay
  void _showIptvChannelSheetOverlay() {
    final channels = _effectiveIptvChannels;
    if (channels == null || channels.isEmpty) return;
    _hideIptvZapBanner();
    setState(() {
      _showIptvChannelSheet = true;
      _controlsVisible.value = false;
    });
  }

  /// Hide IPTV channel sheet overlay
  void _hideIptvChannelSheet() {
    _cancelPendingIptvCatchup();
    setState(() {
      _showIptvChannelSheet = false;
    });
  }

  /// A full-catalog guide result is not necessarily part of the launch
  /// window. Adopt the result set before tuning so every player read uses the
  /// selected channel's real index and metadata.
  Future<void> _switchToIptvGuideChannel(
    List<IptvChannel> channels,
    int index,
  ) async {
    if (index < 0 || index >= channels.length) return;
    _cancelPendingIptvCatchup();
    final channel = channels[index];
    // Adopt the visible list first so playback starts immediately; the
    // re-anchor below then replaces it with the channel's own category.
    // A browse result is not a page of any category, so the zap window's
    // coordinates stop describing the ring until the re-anchor lands.
    _resetIptvZapPaging();
    _iptvChannelsOverride = List<IptvChannel>.from(channels);
    // Take this tune's generation from the call itself. _switchToIptvChannel
    // bumps the ticket synchronously before its first await, and it returns
    // normally when a newer tune supersedes it"È›y¯ßy‘ so reading the ticket AFTER
    // the await would read the newer tune's value and defeat every staleness
    // check downstream.
    final switchFuture = _switchToIptvChannel(index);
    final switchTicket = _iptvSwitchTicket;
    await switchFuture;
    if (!mounted || switchTicket != _iptvSwitchTicket) return;
    unawaited(_reanchorIptvRingToCategory(channel, switchTicket: switchTicket));
  }

  /// Rebuild the channel ring around [channel] from its own category.
  ///
  /// The native guide does this on every pick (`beginIptvCategoryZapSession`):
  /// the list you navigate afterwards is the channel's category, never the
  /// list you happened to pick from. Without it, choosing a channel out of a
  /// search left the search matches standing in as the entire channel list ∫w^~)ﬁt
  /// so the guide reopened onto a handful of unrelated channels, and the
  /// category shown alongside them belonged to the previous selection.
  ///
  /// Best effort by design: playback has already started, so a failed or
  /// unhelpful page simply leaves the adopted list in place, which is what
  /// the native fallback does too.
  Future<void> _reanchorIptvRingToCategory(
    IptvChannel channel, {
    required int switchTicket,
  }) async {
    final provider = widget.iptvBrowseProvider;
    if (provider == null || !channel.isLive) return;
    if (switchTicket != _iptvSwitchTicket) return;
    final category = channel.group?.trim();
    final contextGeneration = _iptvGuideContextGeneration;

    Map<String, dynamic>? result;
    try {
      result = await provider({
        'action': 'zapPage',
        'sourceId': _iptvGuideContextOverride?.sourceId ?? widget.iptvSourceId,
        'contentType': 'live',
        'category': (category == null || category.isEmpty) ? null : category,
        'query': '',
        'anchorUrl': channel.url,
        'anchorName': channel.name,
        'offset': 0,
        // A full page rather than the native player's 200: unlike the native
        // guide this one has no scroll-prefetch to grow a small window, so the
        // ring has to arrive anchored AND whole. Anything past the provider's
        // own maximum is clamped there.
        'limit': _kIptvZapPageSize,
      });
    } catch (error) {
      debugPrint('Player: IPTV ring re-anchor failed: $error');
      return;
    }
    if (!mounted || result == null) return;
    // A newer zap owns the ring now+ßuÁ‚ùÁT installing this page would drop the
    // viewer onto the wrong channel's neighbours.
    if (switchTicket != _iptvSwitchTicket) return;
    // The user browsed while this was in flight. Their category is the
    // current intent; this page predates it.
    if (contextGeneration != _iptvGuideContextGeneration) return;
    // Last line of defence: whatever else moved, the ring must only ever be
    // rebuilt around the channel that is actually playing.
    final playing = _currentIptvChannel;
    if (playing == null ||
        playing.url != channel.url ||
        playing.name != channel.name) {
      return;
    }

    final page = _parseIptvZapPage(result);
    if (page == null) return;
    final playingIndex = page.channels.indexWhere(
      (candidate) =>
          candidate.url == channel.url && candidate.name == channel.name,
    );
    // The page has to contain what is playing, or the ring would no longer
    // describe the channel on screen.
    if (playingIndex < 0) return;

    _clearIptvZapBoundaryCache();
    setState(() {
      _iptvChannelsOverride = page.channels;
      _currentIptvIndex = playingIndex;
      // Where this window sits in the category. Zapping past its edge needs
      // both numbers: without them the window's end and the category's end
      // are indistinguishable, and a category larger than one page would
      // cross into the next category partway through.
      _iptvZapWindowOffset = page.offset;
      _iptvZapCategoryTotal = page.total;
      // Binds every later boundary request to the source this ring came from,
      // however far the guide wanders afterwards.
      _iptvZapSourceId =
          page.sourceId ??
          _iptvGuideContextOverride?.sourceId ??
          widget.iptvSourceId;
      _iptvZapCategory = page.category;
      if (page.categories.isNotEmpty) _iptvZapCategories = page.categories;
      _iptvZapPagingActive = true;
    });
    _anchorIptvGuideCategory(channel, categories: result['categories']);
  }

  //"È›y¯ßy€ßuÁ‚ùÁ@ Live channel zapping"È›y¯ßy€ßuÁ‚ùÁ@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@5£@(ÄÄºº(ÄÄººÅAΩ…–ÅΩòÅ—°îÅπÖ—•ŸîÅ¡±ÖÂï»ùÃÅÈÖ¿Å±Öëëï»Ä°ÅÈÖ¡%¡—Ÿ°Öππï±Ä§ËÅÕ—ï¿Å•πÕ•ëîÅ—°î(ÄÄººÅ±ΩÖëïêÅ›•πëΩ‹∞Å¡ÖùîÅ—°…Ω’ù†Å—°îÅ…ïÕ–ÅΩòÅ—°îÅçÖ—ïùΩ…‰ÅÖ–Å—°îÅ›•πëΩ‹ùÃ(ÄÄººÅïëùïÃ∞ÅÖπêÅç…ΩÕÃÅ•π—ºÅ—°îÅÖë©Öçïπ–ÅçÖ—ïùΩ…‰Å›°ï∏Å—°îÅçÖ—ïùΩ…‰Å•—Õï±òÅ…’πÃ(ÄÄººÅΩ’–ãßuÁ‚ùÁPÅ›…Ö¡¡•πúÅÖ–Å—°îÅ±ÖÕ–ÅΩπî∏ÅQ°îÅâ…Ω›ÕîÅ¡…ΩŸ•ëï»ÅÖ±…ïÖë‰ÅÕ¡ïÖ≠ÃÅ—°•Ã(ÄÄººÅ¡…Ω—ΩçΩ∞Ä°πÖ—•ŸîÅë…ΩŸîÅ•–§∞ÅÕºÅ—°îÅΩπ±‰Å—°•πúÅ—°•ÃÅÕ•ëîÅ°ÖÃÅ—ºÅçÖ……‰Å•Ã(ÄÄººÅ›°ï…îÅ—°îÅ›•πëΩ‹ÅÕ•—ÃÅÖπêÅ›°Ö–Å•ÃÅÖ±…ïÖë‰ÅΩ∏Å•—ÃÅ›Ö‰∏(ÄÄºº(ÄÄººÅ=πîÅëï±•âï…Ö—îÅë•Ÿï…ùïπçîËÅπÖ—•ŸîÅ—…•µÃÅ•—ÃÅ°•ëëï∏Å›•πëΩ‹Å—ºÄÿ¿¿Å…Ω›ÃÅ—º(ÄÄººÅ≠ïï¿ÅÑÅQXùÃÅÖëÖ¡—ï»Å±•ù°–∞ÅÖπêÅ…îµôï—ç°ïÃÅ›°Ö–Å•–Åë…Ω¡¡ïê∏Å!ï…îÅ—°îÅÕÖµî(ÄÄººÅ±•Õ–ÅâÖç≠ÃÅ—°îÅù’•ëî∞Å›°•ç†Å°ÖÃÅπºÅÕç…Ω±∞µ¡…ïôï—ç†Å—ºÅ…ïô•±∞Å•–∞ÅÕº(ÄÄººÅ—…•µµ•πúÅ›Ω’±êÅÕ•±ïπ—±‰ÅÕ°…•π¨Å—°îÅù’•ëîÅ•πÕ—ïÖê∏((ÄÄºººÅAÖùîÅÕ•ÈîÅÖÕ≠ïêÅΩòÅ—°îÅâ…Ω›ÕîÅ¡…ΩŸ•ëï»∏Å%–Åç±Öµ¡ÃÅ—ºÅ•—ÃÅΩ›∏Å¡ï»µ±Ö’πç†(ÄÄºººÅµÖ·•µ’¥∞ÅÕºÅë…•ô–Å°ï…îÅç°ÖπùïÃÅΩπ±‰Å°Ω‹ÅµÖπ‰Å…Ω›ÃÅÖ……•Ÿî∞ÅπïŸï»(ÄÄºººÅçΩ……ïç—πïÕÃËÅÖ∏ÅΩŸï…±Ö¡¡•πúÅâÖç≠›Ö…êÅ¡ÖùîÅµï…ùïÃ∞ÅÑÅÕ°Ω…–ÅΩπîÅ©’Õ–(ÄÄºººÅ±ïÖŸïÃÅµΩ…îÅ—ºÅôï—ç†∏(ÄÅÕ—Ö—•åÅçΩπÕ–Å•π–Å}≠%¡—ŸiÖ¡AÖùïM•ÈîÄÙÄƒ‘¿¿Ï((ÄÄºººÅ!Ω‹Åç±ΩÕîÅ—ºÅ—°îÅ›•πëΩ‹ùÃÅïëùîÅçΩ’π—ÃÅÖÃÄâÖâΩ’–Å—ºÅπïïêÅ›°Ö–ùÃÅπï·–à∏(ÄÅÕ—Ö—•åÅçΩπÕ–Å•π–Å}≠%¡—ŸiÖ¡ëùï5Ö…ù•∏ÄÙÄƒ»Ï((ÄÄºººÅâÕΩ±’—îÅ¡ΩÕ•—•Ω∏∞Å›•—°•∏Å—°îÅÖç—•ŸîÅçÖ—ïùΩ…‰∞ÅΩòÅ—°îÅô•…Õ–Åç°Öππï∞ÅΩò(ÄÄºººÅm}ïôôïç—•Ÿï%¡—Ÿ°Öππï±Õt∏(ÄÅ•π–Å}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–ÄÙÄ¿Ï((ÄÄºººÅ!Ω‹ÅµÖπ‰Åç°Öππï±ÃÅ—°îÅÖç—•ŸîÅçÖ—ïùΩ…‰Å°Ω±ëÃÅ•∏Å—Ω—Ö∞ÏÅ—°îÅ›•πëΩ‹Å•ÃÅÑ(ÄÄºººÅÕ±•çîÅΩòÅ•–∏(ÄÅ•π–Å}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞ÄÙÄ¿Ï((ÄÄºººÅQ°îÅ…•πúÅçÖµîÅô…Ω¥ÅÑÅ¡ÖùïêÅ…ïÕ¡ΩπÕî∞ÅÕºÅm}•¡—ŸiÖ¡]•πëΩ›=ôôÕï—tÅÖπê(ÄÄºººÅm}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö±tÅëïÕç…•âîÅ•–∏ÅÖ±ÕîÅôΩ»Å—°îÅ±Ö’πç†Å›•πëΩ‹ÅΩ»ÅÑ(ÄÄºººÅâ…Ω›ÕîÅ…ïÕ’±–ÅÕ—Öπë•πúÅ•∏Æù◊üäwùPÅÈÖ¡¡•πúÅ—°ï∏Å©’Õ–Å›…Ö¡ÃÅ•πÕ•ëîÅ—°îÅ±•Õ–∞(ÄÄºººÅ›°•ç†Å•ÃÅ›°Ö–ÅπÖ—•ŸîÅëΩïÃÅâïôΩ…îÅ•—ÃÅ¡Öù•πúÅÕïÕÕ•Ω∏ÅÕ—Ö…—Ã∏(ÄÅâΩΩ∞Å}•¡—ŸiÖ¡AÖù•πùç—•ŸîÄÙÅôÖ±ÕîÏ((ÄÄºººÅQ°îÅÕΩ’…çîÅÖπêÅçÖ—ïùΩ…‰Å—°îÅ…•πúÅâï±ΩπùÃÅ—º∏Å-ï¡–ÅÖ¡Ö…–Åô…Ω¥Å—°îÅù’•ëîùÃ(ÄÄºººÅÕï±ïç—•Ω∏ÅΩ∏Å¡’…¡ΩÕîËÅâ…Ω›Õ•πúÅçÖ∏ÅµΩŸîÅ—°îÅù’•ëîÅ—ºÅÖπΩ—°ï»ÅÕΩ’…çîÅΩ»(ÄÄºººÅçÖ—ïùΩ…‰Æù◊üäwùPÅÖπêÅ±ïÖŸîÅ•–Å—°ï…îÅ›•—°Ω’–ÅïŸï»Å—’π•πúãßuÁ‚ùÁPÅ›°•±îÅ—°îÅ…•πúÅ≠ïï¡Ã(ÄÄºººÅëïÕç…•â•πúÅ›°Ö–Å•ÃÅ¡±ÖÂ•πú∏ÅÕ≠•πúÅ—°îÅù’•ëîùÃÅÕΩ’…çîÅôΩ»Å—°îÅ…•πúùÃ(ÄÄºººÅçÖ—ïùΩ…‰Å›Ω’±êÅôï—ç†ÅÑÅçÖ—ïùΩ…‰Å—°Ö–ÅÕΩ’…çîÅµÖ‰ÅπΩ–ÅïŸï∏Å°ÖŸî∏(ÄÅM—…•πú¸Å}•¡—ŸiÖ¡MΩ’…çï%êÏ(ÄÅM—…•πú¸Å}•¡—ŸiÖ¡Ö—ïùΩ…‰Ï(ÄÅ1•Õ–ÒM—…•πú¯Å}•¡—ŸiÖ¡Ö—ïùΩ…•ïÃÄÙÅçΩπÕ–ÅmtÏ((ÄÅ•π–Å}•¡—ŸiÖ¡Iï≈’ïÕ—Q•ç≠ï–ÄÙÄ¿Ï(ÄÅâΩΩ∞Å}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–ÄÙÅôÖ±ÕîÏ((ÄÄºººÅA…ïÕÕïÃÅ—°Ö–ÅÖ……•ŸïêÅ›°•±îÅÑÅ¡ÖùîÅ›ÖÃÅ±ΩÖë•πú∏Å…ΩÕÕ•πúÅÑÅ¡ÖùîÅΩ»ÅÑ(ÄÄºººÅçÖ—ïùΩ…‰Å•ÃÅÑÅ…Ω’πêÅ—…•¿∞ÅÕºÅ°Ω±ë•πúÅ—°îÅ≠ï‰ÅëΩ›∏Å°ÖÃÅ—ºÅ≈’ï’îÅ…Ö—°ï»(ÄÄºººÅ—°Ö∏Åë…Ω¿∏(ÄÅô•πÖ∞Å1•Õ–Ò•π–¯Å}•¡—ŸiÖ¡Aïπë•πù%π¡’—ÃÄÙÅmtÏ(ÄÅâΩΩ∞Å}•¡—ŸiÖ¡…Ö•π•πù%π¡’—ÃÄÙÅôÖ±ÕîÏ((ÄÄºººÅQ°îÅÖë©Öçïπ–ÅçÖ—ïùΩ…‰∞Åôï—ç°ïêÅâïôΩ…îÅ•–Å•ÃÅπïïëïêÅÕºÅç…ΩÕÕ•πúÅΩπîÅçΩÕ—Ã(ÄÄºººÅπºÅµΩ…îÅ—°Ö∏ÅÕ—ï¡¡•πúÅ•πÕ•ëîÅ—°îÅç’……ïπ–ÅΩπî∏(ÄÅM—…•πú¸Å}•¡—ŸiÖ¡Öç°ïë=…•ù•πÖ—ïùΩ…‰Ï(ÄÅ•π–Å}•¡—ŸiÖ¡Öç°ïë•…ïç—•Ω∏ÄÙÄ¿Ï(ÄÅ}%¡—ŸiÖ¡AÖùî¸Å}•¡—ŸiÖ¡Öç°ïëAÖùîÏ((ÄÄºººÅ1•ŸîÅ%AQXÅ›•—†ÅÕΩµï›°ï…îÅ—ºÅÈÖ¿Å—ºÇÈ›y¯ßy–Åï•—°ï»ÅµΩ…îÅ—°Ö∏ÅΩπîÅç°Öππï∞Å•∏Å—°î(ÄÄºººÅ…•πú∞ÅΩ»ÅÑÅ¡ÖùïêÅçΩπ—ï·–Å—°Ö–ÅçÖ∏Åôï—ç†ÅµΩ…î∏(ÄÅâΩΩ∞Åùï–Å}çÖπiÖ¡%¡—Ÿ°Öππï∞ÄÙ¯(ÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ°Öππï∞¸π•Õ1•ŸîÄÙÙÅ—…’îÄòò(ÄÄÄÄÄÄ†°}ïôôïç—•Ÿï%¡—Ÿ°Öππï±Ã¸π±ïπù—†Ä¸¸Ä¿§Ä¯ÄƒÅÒÅ}•¡—ŸiÖ¡AÖù•πùç—•Ÿî§Ï((ÄÅŸΩ•êÅ}ç±ïÖ…%¡—ŸiÖ¡	Ω’πëÖ…ÂÖç°î†§ÅÏ(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë=…•ù•πÖ—ïùΩ…‰ÄÙÅπ’±∞Ï(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë•…ïç—•Ω∏ÄÙÄ¿Ï(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïëAÖùîÄÙÅπ’±∞Ï(ÄÅÙ((ÄÄºººÅQ°îÅ…•πúÅ•ÃÅÖâΩ’–Å—ºÅÕ—Ω¿Åâï•πúÅÑÅ¡ÖùîÅΩòÅÑÅçÖ—ïùΩ…‰∏Å	’µ¡•πúÅ—°îÅ…ï≈’ïÕ–(ÄÄºººÅ—•ç≠ï–ÅÕ—…ÖπëÃÅÖπÂ—°•πúÅ•∏Åô±•ù°–ËÅ•–Å›Ω’±êÅΩ—°ï…›•ÕîÅµï…ùîÅÑÅ¡ÖùîÅΩòÅ—°î(ÄÄºººÅΩ±êÅçÖ—ïùΩ…‰Å•π—ºÅ—°îÅπï‹Å…•πúÅÖ–Å¡ΩÕ•—•ΩπÃÅ—°Ö–ÅµïÖ∏ÅπΩ—°•πúÅ—°ï…î∏(ÄÅŸΩ•êÅ}…ïÕï—%¡—ŸiÖ¡AÖù•πú†§ÅÏ(ÄÄÄÅ}•¡—ŸiÖ¡AÖù•πùç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÄÄÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–ÄÙÄ¿Ï(ÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞ÄÙÄ¿Ï(ÄÄÄÅ}•¡—ŸiÖ¡MΩ’…çï%êÄÙÅπ’±∞Ï(ÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰ÄÙÅπ’±∞Ï(ÄÄÄÅ}•¡—ŸiÖ¡Iï≈’ïÕ—Q•ç≠ï–¨¨Ï(ÄÄÄÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–ÄÙÅôÖ±ÕîÏ(ÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπç±ïÖ»†§Ï(ÄÄÄÅ}ç±ïÖ…%¡—ŸiÖ¡	Ω’πëÖ…ÂÖç°î†§Ï(ÄÅÙ((ÄÄºººÅÅ…îµÖπç°Ω»Å•ÃÅΩ’–ÅÖ…µ•πúÅ—°îÅ±Öëëï»∞ÅÕºÅÑÅâ’…Õ–ÅΩòÅ¡…ïÕÕïÃÅçÖ∏ù–ÅÕ—Öç¨(ÄÄºººÅô’±∞µçÖ—ïùΩ…‰Å≈’ï…•ïÃÅâï°•πêÅ•–∏(ÄÅâΩΩ∞Å}•¡—ŸiÖ¡…µ•πùAÖù•πúÄÙÅôÖ±ÕîÏ((ÄÄºººÅ…¥Å—°îÅ±Öëëï»ÅÖ…Ω’πêÅ›°Ö—ïŸï»Å±•ŸîÅç°Öππï∞Å•ÃÅ¡±ÖÂ•πúÅπΩ‹∏(ÄÄººº(ÄÄºººÅQ°îÅ±Ö’πç†ÅâΩΩ—Õ—…Ö¿Å…îµÖπç°Ω…ÃÅ—°îÅç°Öππï∞Å—°îÅ¡±ÖÂï»ÅΩ¡ïπïêÅ›•—†∞Åâ’–ÅÑ(ÄÄºººÅÈÖ¿Å±Öπë•πúÅâïôΩ…îÅ—°Ö–Å…ïÕ¡ΩπÕîÅëΩïÃÅµΩŸïÃÅ—°îÅÕ›•—ç†Å—•ç≠ï–ÅΩ∏ÅÖπêÅ—°î(ÄÄºººÅ…ïÕ¡ΩπÕîÅ•ÃÅë…Ω¡¡ïê∏Å9Ω—°•πúÅï±ÕîÅ›Ω’±êÅ…îµÖ…¥Å•–∞ÅÕºÅ—°îÅ±Öëëï»Å›Ω’±êÅÕ•–(ÄÄºººÅ•πÖç—•ŸîÅÖπêÅÈÖ¡¡•πúÅ›Ω’±êÅç•…ç±îÅ—°îÅ±Ö’πç†Å›•πëΩ‹Å’π—•∞Å—°îÅ’Õï»ÅΩ¡ïπïê(ÄÄºººÅ—°îÅù’•ëîÅÖπêÅ…ï—’πïê∏ÅIï—…Â•πúÅô…Ω¥Å—°îÅÈÖ¿Å•—Õï±òÅç±ΩÕïÃÅ—°Ö–ËÅ—°îÅô•…Õ–(ÄÄºººÅ¡…ïÕÃÅÖô—ï»ÅÑÅ±ΩÕ–ÅâΩΩ—Õ—…Ö¿ÅÖ…µÃÅ—°îÅ±Öëëï»ÅôΩ»Å—°îÅç°Öππï∞Å•–Å±ÖπëïêÅΩ∏∏(ÄÅŸΩ•êÅ}ïπÕ’…ï%¡—ŸiÖ¡AÖù•πù…µïê†§ÅÏ(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡AÖù•πùç—•ŸîÅÒÅ}•¡—ŸiÖ¡…µ•πùAÖù•πú§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°›•ëùï–π•¡—Ÿ	…Ω›ÕïA…ΩŸ•ëï»ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞ÅÒÄÖç°Öππï∞π•Õ1•Ÿî§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—ŸiÖ¡…µ•πùAÖù•πúÄÙÅ—…’îÏ(ÄÄÄÅ’πÖ›Ö•—ïê†(ÄÄÄÄÄÅ}…ïÖπç°Ω…%¡—ŸI•πùQΩÖ—ïùΩ…‰†(ÄÄÄÄÄÄÄÅç°Öππï∞∞(ÄÄÄÄÄÄÄÅÕ›•—ç°Q•ç≠ï–ËÅ}•¡—ŸM›•—ç°Q•ç≠ï–∞(ÄÄÄÄÄÄ§π›°ïπΩµ¡±ï—î††§ÄÙ¯Å}•¡—ŸiÖ¡…µ•πùAÖù•πúÄÙÅôÖ±Õî§∞(ÄÄÄÄ§Ï(ÄÅÙ((ÄÄºººÅA…ïŸ•Ω’ÃΩπï·–Åç°Öππï∞Å•∏Åù’•ëîÅΩ…ëï»∏(ÄÅŸΩ•êÅ}ÈÖ¡%¡—Ÿ°Öππï∞°•π–Åëï±—Ñ§ÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅô•πÖ∞Åç’……ïπ–ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅç’……ïπ–ÄÙÙÅπ’±∞ÅÒÄÖç’……ïπ–π•Õ1•Ÿî§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•ŸîÄòòÅç°Öππï±Ãπ±ïπù—†ÄÄ»§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åô…Ω¥ÄÙÅ}ç’……ïπ—%¡—Ÿ%πëï‡πç±Öµ¿†¿∞Åç°Öππï±Ãπ±ïπù—†Ä¥Äƒ§Ï(ÄÄÄÅô•πÖ∞Åπï·–ÄÙÅô…Ω¥Ä¨Åëï±—ÑÏ((ÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•Ÿî§ÅÏ(ÄÄÄÄÄÄººÅ9ºÅ¡ÖùïêÅçΩπ—ï·–ËÅ—°îÅ…•πúÅ•ÃÅÖ±∞Å—°ï…îÅ•Ã∞ÅÕºÅ›…Ö¿Å•πÕ•ëîÅ•–∏(ÄÄÄÄÄÅ’πÖ›Ö•—ïê†(ÄÄÄÄÄÄÄÅ}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞†°πï·–Ä¨Åç°Öππï±Ãπ±ïπù—†§ÄîÅç°Öππï±Ãπ±ïπù—†§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄººÅQ’π•πúÅ°ÖÃÅÖ±…ïÖë‰ÅµΩŸïêÅ—°îÅ•πëï‡ÅÖπêÅ—°îÅÕ›•—ç†Å—•ç≠ï–∞ÅÕºÅ—°•ÃÅÖ…µÃ(ÄÄÄÄÄÄººÅ—°îÅ±Öëëï»ÅÖ…Ω’πêÅ—°îÅç°Öππï∞Å©’Õ–Å±ÖπëïêÅΩ∏∏(ÄÄÄÄÄÅ}ïπÕ’…ï%¡—ŸiÖ¡AÖù•πù…µïê†§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÅ•òÄ°πï·–Ä¯ÙÄ¿ÄòòÅπï·–ÄÅç°Öππï±Ãπ±ïπù—†§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞°πï·–§§Ï(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°%¡—ŸiÖ¡AÖùî°ëï±—Ñ§§Ï(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ§§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÅô•πÖ∞Åô•…Õ—âÕΩ±’—îÄÙÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–Ï(ÄÄÄÅô•πÖ∞Å±ÖÕ—âÕΩ±’—îÄÙÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–Ä¨Åç°Öππï±Ãπ±ïπù—†Ä¥ÄƒÏ(ÄÄÄÅô•πÖ∞Å°ÖÕπΩ—°ï…AÖùîÄÙÅëï±—ÑÄ¯Ä¿(ÄÄÄÄÄÄÄÄ¸Å±ÖÕ—âÕΩ±’—îÄ¨ÄƒÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞(ÄÄÄÄÄÄÄÄËÅô•…Õ—âÕΩ±’—îÄ¯Ä¿Ï(ÄÄÄÅ•òÄ°°ÖÕπΩ—°ï…AÖùî§ÅÏ(ÄÄÄÄÄÄººÅQ°îÅçÖ—ïùΩ…‰ÅçΩπ—•π’ïÃÅ¡ÖÕ–Å—°îÅ›•πëΩ‹∏Å!Ω±êÅ—°îÅ¡…ïÕÃÅ’π—•∞Å—°îÅ¡Öùî(ÄÄÄÄÄÄººÅ•–ÅπïïëÃÅ°ÖÃÅ±Öπëïê∞Å—°ï∏Å…ï¡±Ö‰Å•–ÅÖùÖ•πÕ–Å—°îÅù…Ω›∏Å…•πú∏(ÄÄÄÄÄÅ}≈’ï’ïAïπë•πù%¡—ŸiÖ¡%π¡’–°ëï±—Ñ§Ï(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°%¡—ŸiÖ¡AÖùî°ëï±—Ñ§§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÅ•òÄ°}çΩπÕ’µïÖç°ïëë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ§§Å…ï—’…∏Ï(ÄÄÄÅ’πÖ›Ö•—ïê°}…ï≈’ïÕ—ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ§§Ï(ÄÅÙ((ÄÄºººÅ=πîÅ¡ÖùîÅ…ï≈’ïÕ–ÅÖ–ÅÑÅ—•µî∞Å±•≠îÅπÖ—•ŸîËÅÑÅÕïçΩπêÅ•∏µô±•ù°–Å…ï≈’ïÕ–Å›Ω’±ê(ÄÄºººÅ…ÖçîÅ—°îÅô•…Õ–Å•π—ºÅ—°îÅ…•πúÅ›•—†ÅπºÅ›Ö‰Å—ºÅΩ…ëï»Å—°îÅ—›º∏(ÄÅ’—’…îÒ}%¡—ŸiÖ¡AÖùî¸¯Å}…ï≈’ïÕ—%¡—ŸiÖ¡AÖùî°Ï(ÄÄÄÅ…ï≈’•…ïêÅM—…•πú¸ÅçÖ—ïùΩ…‰∞(ÄÄÄÅ…ï≈’•…ïêÅ•π–ÅΩôôÕï–∞(ÄÄÄÅâΩΩ∞Åô…ΩµπêÄÙÅôÖ±Õî∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞Å¡…ΩŸ•ëï»ÄÙÅ›•ëùï–π•¡—Ÿ	…Ω›ÕïA…ΩŸ•ëï»Ï(ÄÄÄÅ•òÄ°¡…ΩŸ•ëï»ÄÙÙÅπ’±∞ÅÒÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞Å—•ç≠ï–ÄÙÄ¨≠}•¡—ŸiÖ¡Iï≈’ïÕ—Q•ç≠ï–Ï(ÄÄÄÅô•πÖ∞ÅçΩπ—ï·—ïπï…Ö—•Ω∏ÄÙÅ}•¡—Ÿ’•ëïΩπ—ï·—ïπï…Ö—•Ω∏Ï(ÄÄÄÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–ÄÙÅ—…’îÏ((ÄÄÄÅ5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯¸Å…ïÕ’±–Ï(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅ…ïÕ’±–ÄÙÅÖ›Ö•–Å¡…ΩŸ•ëï»°Ï(ÄÄÄÄÄÄÄÄùÖç—•Ω∏úËÄùÈÖ¡AÖùîú∞(ÄÄÄÄÄÄÄÄººÅQ°îÅ…•πúùÃÅΩ›∏ÅÕΩ’…çî∞ÅπΩ–Å—°îÅù’•ëîùÃÆù◊üäwùPÅÕïîÅm}•¡—ŸiÖ¡MΩ’…çï%ët∏(ÄÄÄÄÄÄÄÄùÕΩ’…çï%êúË(ÄÄÄÄÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡MΩ’…çï%êÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÅ}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëî¸πÕΩ’…çï%êÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÅ›•ëùï–π•¡—ŸMΩ’…çï%ê∞(ÄÄÄÄÄÄÄÄùçΩπ—ïπ—QÂ¡îúËÄù±•Ÿîú∞(ÄÄÄÄÄÄÄÄùçÖ—ïùΩ…‰úËÄ°çÖ—ïùΩ…‰ÄÙÙÅπ’±∞ÅÒÅçÖ—ïùΩ…‰π•Õµ¡—‰§Ä¸Åπ’±∞ÄËÅçÖ—ïùΩ…‰∞(ÄÄÄÄÄÄÄÄù≈’ï…‰úËÄúú∞(ÄÄÄÄÄÄÄÄùΩôôÕï–úËÅΩôôÕï–ÄÄ¿Ä¸Ä¿ÄËÅΩôôÕï–∞(ÄÄÄÄÄÄÄÄù±•µ•–úËÅ}≠%¡—ŸiÖ¡AÖùïM•Èî∞(ÄÄÄÄÄÄÄÄùô…ΩµπêúËÅô…Ωµπê∞(ÄÄÄÄÄÅÙ§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°ï……Ω»§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅ%AQXÅÈÖ¿Å¡ÖùîÅôÖ•±ïêËÄëï……Ω»ú§Ï(ÄÄÄÅÙ(ÄÄÄÄººÅÅπï›ï»Å…ï≈’ïÕ–Ä°Ω»ÅÑÅ…ïÕï–§ÅΩ›πÃÅ—°îÅô±ÖúÅπΩ‹Æù◊üäwùPÅ±ïÖŸîÅ•–Å—ºÅ—°ï¥∏(ÄÄÄÅ•òÄ°—•ç≠ï–ÄÑÙÅ}•¡—ŸiÖ¡Iï≈’ïÕ—Q•ç≠ï–§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–ÄÙÅôÖ±ÕîÏ(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ…ïÕ’±–ÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄººÅIï¡±ÖÂ•πúÅ≈’ï’ïêÅ¡…ïÕÕïÃÅÖùÖ•πÕ–ÅÑÅ…•πúÅ—°Ö–ÅπïŸï»Åù…ï‹Å›Ω’±êÅÕ¡•∏∏(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπç±ïÖ»†§Ï(ÄÄÄÄÄÅ…ï—’…∏Åπ’±∞Ï(ÄÄÄÅÙ(ÄÄÄÄººÅQ°îÅ’Õï»Åâ…Ω›ÕïêÅ›°•±îÅ—°•ÃÅ›ÖÃÅ•∏Åô±•ù°–ÏÅ—°ï•»ÅçÖ—ïùΩ…‰Å•ÃÅ—°îÅç’……ïπ–(ÄÄÄÄººÅ•π—ïπ–ÅÖπêÅïŸï…‰Å≈’ï’ïêÅ¡…ïÕÃÅâï±ΩπùïêÅ—ºÅ—°îÅΩ±êÅΩπî∏(ÄÄÄÅ•òÄ°çΩπ—ï·—ïπï…Ö—•Ω∏ÄÑÙÅ}•¡—Ÿ’•ëïΩπ—ï·—ïπï…Ö—•Ω∏§ÅÏ(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπç±ïÖ»†§Ï(ÄÄÄÄÄÅ…ï—’…∏Åπ’±∞Ï(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏Å}¡Ö…Õï%¡—ŸiÖ¡AÖùî°…ïÕ’±–§Ï(ÄÅÙ((ÄÅ}%¡—ŸiÖ¡AÖùî¸Å}¡Ö…Õï%¡—ŸiÖ¡AÖùî°5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯Å…ïÕ’±–§ÅÏ(ÄÄÄÅô•πÖ∞Å…Ö‹ÄÙÅ…ïÕ’±—lùç°Öππï±ÃùtÏ(ÄÄÄÅ•òÄ°…Ö‹Å•ÃÑÅ1•Õ–§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅl(ÄÄÄÄÄÅôΩ»Ä°ô•πÖ∞Åïπ—…‰Å•∏Å…Ö‹π›°ï…ïQÂ¡îÒ5Ö¿¯†§§(ÄÄÄÄÄÄÄÅ•¡—Ÿ°Öππï±…Ωµ	…Ω›ÕïAÖÂ±ΩÖê°5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯πô…Ω¥°ïπ—…‰§§∞(ÄÄÄÅtÏ(ÄÄÄÅô•πÖ∞Å…Ö›=ôôÕï–ÄÙÅ…ïÕ’±—lù¡Öùï=ôôÕï–ùtÏ(ÄÄÄÅô•πÖ∞ÅΩôôÕï–ÄÙÅ…Ö›=ôôÕï–Å•ÃÅπ’¥Ä¸ÅµÖ—†πµÖ‡†¿∞Å…Ö›=ôôÕï–π—Ω%π–†§§ÄËÄ¿Ï(ÄÄÄÅô•πÖ∞Å…Ö›QΩ—Ö∞ÄÙÅ…ïÕ’±—lù—Ω—Ö±°Öππï±ÃùtÏ(ÄÄÄÅô•πÖ∞Å—Ω—Ö∞ÄÙÅ…Ö›QΩ—Ö∞Å•ÃÅπ’¥Ä¸Å…Ö›QΩ—Ö∞π—Ω%π–†§ÄËÅç°Öππï±Ãπ±ïπù—†Ï(ÄÄÄÅô•πÖ∞Å…Ö›MΩ’…çï%êÄÙÄ°…ïÕ’±—lùÕΩ’…çï%êùtÅÖÃÅM—…•πú¸§¸π—…•¥†§Ï(ÄÄÄÅô•πÖ∞Å…Ö›Ö—ïùΩ…‰ÄÙÄ°…ïÕ’±—lùÕï±ïç—ïëÖ—ïùΩ…‰ùtÅÖÃÅM—…•πú¸§¸π—…•¥†§Ï(ÄÄÄÅô•πÖ∞Å…Ö›Ö—ïùΩ…•ïÃÄÙÅ…ïÕ’±—lùçÖ—ïùΩ…•ïÃùtÏ(ÄÄÄÅ…ï—’…∏Å}%¡—ŸiÖ¡AÖùî†(ÄÄÄÄÄÅç°Öππï±ÃËÅç°Öππï±Ã∞(ÄÄÄÄÄÅΩôôÕï–ËÅΩôôÕï–∞(ÄÄÄÄÄÄººÅÅ—Ω—Ö∞Å—°Ö–ÅëΩïÕ∏ù–ÅçΩŸï»Å—°îÅ¡ÖùîÅ•–ÅçÖµîÅ›•—†Å›Ω’±êÅ¡’–Å—°î(ÄÄÄÄÄÄººÅçÖ—ïùΩ…‰ùÃÅïπêÅâï°•πêÅ—°îÅ›•πëΩ‹ùÃÅΩ›∏Å±ÖÕ–Å…Ω‹∏(ÄÄÄÄÄÅ—Ω—Ö∞ËÅµÖ—†πµÖ‡°—Ω—Ö∞∞ÅΩôôÕï–Ä¨Åç°Öππï±Ãπ±ïπù—†§∞(ÄÄÄÄÄÅÕΩ’…çï%êËÄ°…Ö›MΩ’…çï%êÄÙÙÅπ’±∞ÅÒÅ…Ö›MΩ’…çï%êπ•Õµ¡—‰§(ÄÄÄÄÄÄÄÄÄÄ¸Åπ’±∞(ÄÄÄÄÄÄÄÄÄÄËÅ…Ö›MΩ’…çï%ê∞(ÄÄÄÄÄÅçÖ—ïùΩ…‰ËÄ°…Ö›Ö—ïùΩ…‰ÄÙÙÅπ’±∞ÅÒÅ…Ö›Ö—ïùΩ…‰π•Õµ¡—‰§(ÄÄÄÄÄÄÄÄÄÄ¸Åπ’±∞(ÄÄÄÄÄÄÄÄÄÄËÅ…Ö›Ö—ïùΩ…‰∞(ÄÄÄÄÄÅçÖ—ïùΩ…•ïÃËÅ…Ö›Ö—ïùΩ…•ïÃÅ•ÃÅ1•Õ–(ÄÄÄÄÄÄÄÄÄÄ¸Ål(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅôΩ»Ä°ô•πÖ∞Åïπ—…‰Å•∏Å…Ö›Ö—ïùΩ…•ïÃπ›°ï…ïQÂ¡îÒM—…•πú¯†§§(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•òÄ°ïπ—…‰π•Õ9Ω—µ¡—‰§Åïπ—…‰∞(ÄÄÄÄÄÄÄÄÄÄÄÅt(ÄÄÄÄÄÄÄÄÄÄËÅçΩπÕ–Åmt∞(ÄÄÄÄ§Ï(ÄÅÙ((ÄÄºººÅIï¡±ÖçîÅ—°îÅ…•πúÅ›•—†Åm¡Öùït∏ÅQ°îÅçÖ±±ï»Å—’πïÃÅÖô—ï…›Ö…ëÃ∞ÅÕºÅ—°îÅ•πëï‡(ÄÄºººÅ±ïô–Åâï°•πêÅ°ï…îÅ•ÃÅΩπ±‰ÅÑÅÕ—Ö…—•πúÅ¡Ω•π–∏(ÄÅŸΩ•êÅ}•πÕ—Ö±±%¡—ŸiÖ¡]•πëΩ‹†(ÄÄÄÅ}%¡—ŸiÖ¡AÖùîÅ¡Öùî∞ÅÏ(ÄÄÄÅ…ï≈’•…ïêÅâΩΩ∞Å¡…ïÕï…ŸïA±ÖÂ•πù°Öππï∞∞(ÄÅÙ§ÅÏ(ÄÄÄÅ•òÄ°¡Öùîπç°Öππï±Ãπ•Õµ¡—‰§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°¡ÖùîπçÖ—ïùΩ…‰ÄÑÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰§Å}ç±ïÖ…%¡—ŸiÖ¡	Ω’πëÖ…ÂÖç°î†§Ï(ÄÄÄÅô•πÖ∞Å¡±ÖÂ•πúÄÙÅ¡…ïÕï…ŸïA±ÖÂ•πù°Öππï∞Ä¸Å}ç’……ïπ—%¡—Ÿ°Öππï∞ÄËÅπ’±∞Ï(ÄÄÄÅŸÖ»Å•πëï‡ÄÙÄ¿Ï(ÄÄÄÅ•òÄ°¡±ÖÂ•πúÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅô•πÖ∞ÅôΩ’πêÄÙÅ¡Öùîπç°Öππï±Ãπ•πëï·]°ï…î†(ÄÄÄÄÄÄÄÄ°çÖπë•ëÖ—î§ÄÙ¯(ÄÄÄÄÄÄÄÄÄÄÄÅçÖπë•ëÖ—îπ’…∞ÄÙÙÅ¡±ÖÂ•πúπ’…∞ÄòòÅçÖπë•ëÖ—îππÖµîÄÙÙÅ¡±ÖÂ•πúππÖµî∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ°ôΩ’πêÄ¯ÙÄ¿§Å•πëï‡ÄÙÅôΩ’πêÏ(ÄÄÄÅÙ(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}•¡—Ÿ°Öππï±Õ=Ÿï……•ëîÄÙÅ¡Öùîπç°Öππï±ÃÏ(ÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÙÅ•πëï‡Ï(ÄÄÄÄÄÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–ÄÙÅ¡ÖùîπΩôôÕï–Ï(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞ÄÙÅ¡Öùîπ—Ω—Ö∞Ï(ÄÄÄÄÄÅ}•¡—ŸiÖ¡MΩ’…çï%êÄÙÅ¡ÖùîπÕΩ’…çï%êÄ¸¸Å}•¡—ŸiÖ¡MΩ’…çï%êÏ(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰ÄÙÅ¡ÖùîπçÖ—ïùΩ…‰Ï(ÄÄÄÄÄÅ•òÄ°¡ÖùîπçÖ—ïùΩ…•ïÃπ•Õ9Ω—µ¡—‰§Å}•¡—ŸiÖ¡Ö—ïùΩ…•ïÃÄÙÅ¡ÖùîπçÖ—ïùΩ…•ïÃÏ(ÄÄÄÄÄÅ}•¡—ŸiÖ¡AÖù•πùç—•ŸîÄÙÅ—…’îÏ(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÄºººÅM¡±•çîÅÑÅô…ïÕ°±‰Å±ΩÖëïêÅ¡ÖùîÅ•π—ºÅ—°îÅ…•πú∞Åù…Ω›•πúÅ—°îÅ›•πëΩ‹Å…Ö—°ï»(ÄÄºººÅ—°Ö∏Å…ï¡±Öç•πúÅ•–Æù◊üäwùPÅ—°îÅç°Öππï∞ÅΩ∏ÅÕç…ïï∏Å°ÖÃÅ—ºÅ≠ïï¿Å•—ÃÅ¡±Öçî∞ÅÖπêÅ—°î(ÄÄºººÅù’•ëîÅ•ÃÅ±ΩΩ≠•πúÅÖ–Å—°îÅÕÖµîÅ±•Õ–∏(ÄÅŸΩ•êÅ}µï…ùï%¡—ŸiÖ¡AÖùî°}%¡—ŸiÖ¡AÖùîÅ¡Öùî§ÅÏ(ÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•ŸîÅÒÅ¡Öùîπç°Öππï±Ãπ•Õµ¡—‰§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°¡ÖùîπçÖ—ïùΩ…‰ÄÑÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅç°Öππï±Ãπ•Õµ¡—‰§Å…ï—’…∏Ï((ÄÄÄÅô•πÖ∞Å›•πëΩ›M—Ö…–ÄÙÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–Ï(ÄÄÄÅô•πÖ∞Åµï…ùïêÄÙÅ•¡—Ÿ5ï…ùïiÖ¡]•πëΩ‹†(ÄÄÄÄÄÅ›•πëΩ‹ËÅç°Öππï±Ã∞(ÄÄÄÄÄÅ›•πëΩ›=ôôÕï–ËÅ›•πëΩ›M—Ö…–∞(ÄÄÄÄÄÅ¡ÖùîËÅ¡Öùîπç°Öππï±Ã∞(ÄÄÄÄÄÅ¡Öùï=ôôÕï–ËÅ¡ÖùîπΩôôÕï–∞(ÄÄÄÄ§Ï(ÄÄÄÄººÅQ°îÅ¡ÖùîÅë•ë∏ù–Å—Ω’ç†Å—°îÅ›•πëΩ‹ÇÈ›y¯ßy–ÅÕïîÅ•¡—Ÿ5ï…ùïiÖ¡]•πëΩ‹∏(ÄÄÄÅ•òÄ°µï…ùïêÄÙÙÅπ’±∞§Å…ï—’…∏Ï((ÄÄÄÅô•πÖ∞Å¡±ÖÂ•πúÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅŸÖ»Å•πëï‡ÄÙÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¨Ä°›•πëΩ›M—Ö…–Ä¥Åµï…ùïêπΩôôÕï–§Ï(ÄÄÄÅ•òÄ°¡±ÖÂ•πúÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅô•πÖ∞ÅôΩ’πêÄÙÅµï…ùïêπç°Öππï±Ãπ•πëï·]°ï…î†(ÄÄÄÄÄÄÄÄ°çÖπë•ëÖ—î§ÄÙ¯(ÄÄÄÄÄÄÄÄÄÄÄÅçÖπë•ëÖ—îπ’…∞ÄÙÙÅ¡±ÖÂ•πúπ’…∞ÄòòÅçÖπë•ëÖ—îππÖµîÄÙÙÅ¡±ÖÂ•πúππÖµî∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ°ôΩ’πêÄ¯ÙÄ¿§Å•πëï‡ÄÙÅôΩ’πêÏ(ÄÄÄÅÙ(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}•¡—Ÿ°Öππï±Õ=Ÿï……•ëîÄÙÅµï…ùïêπç°Öππï±ÃÏ(ÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÙÅ•πëï‡πç±Öµ¿†¿∞Åµï…ùïêπç°Öππï±Ãπ±ïπù—†Ä¥Äƒ§Ï(ÄÄÄÄÄÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–ÄÙÅµï…ùïêπΩôôÕï–Ï(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞ÄÙÅµÖ—†πµÖ‡†(ÄÄÄÄÄÄÄÅ¡Öùîπ—Ω—Ö∞∞(ÄÄÄÄÄÄÄÅµï…ùïêπΩôôÕï–Ä¨Åµï…ùïêπç°Öππï±Ãπ±ïπù—†∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ°¡ÖùîπçÖ—ïùΩ…•ïÃπ•Õ9Ω—µ¡—‰§Å}•¡—ŸiÖ¡Ö—ïùΩ…•ïÃÄÙÅ¡ÖùîπçÖ—ïùΩ…•ïÃÏ(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÄºººÅA’±∞Å•∏Å—°îÅπï·–Å¡ÖùîÅΩòÅ—°îÅç’……ïπ–ÅçÖ—ïùΩ…‰ÅΩπçîÅÈÖ¡¡•πúÅùï—ÃÅπïÖ»Å—°î(ÄÄºººÅ›•πëΩ‹ùÃÅïëùî∏(ÄÅ’—’…îÒŸΩ•ê¯Å}¡…ïôï—ç°%¡—ŸiÖ¡AÖùî°•π–Åëï±—Ñ§ÅÖÕÂπåÅÏ(ÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•ŸîÅÒÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅç°Öππï±Ãπ•Õµ¡—‰§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åô•…Õ—âÕΩ±’—îÄÙÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–Ï(ÄÄÄÅô•πÖ∞Å±ÖÕ—âÕΩ±’—îÄÙÅô•…Õ—âÕΩ±’—îÄ¨Åç°Öππï±Ãπ±ïπù—†Ä¥ÄƒÏ(ÄÄÄÅô•πÖ∞ÅÕ°Ω’±ë1ΩÖêÄÙÅëï±—ÑÄ¯Ä¿(ÄÄÄÄÄÄÄÄ¸Å±ÖÕ—âÕΩ±’—îÄ¨ÄƒÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞Äòò(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¯ÙÅç°Öππï±Ãπ±ïπù—†Ä¥Å}≠%¡—ŸiÖ¡ëùï5Ö…ù•∏(ÄÄÄÄÄÄÄÄËÅô•…Õ—âÕΩ±’—îÄ¯Ä¿ÄòòÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÅ}≠%¡—ŸiÖ¡ëùï5Ö…ù•∏Ï(ÄÄÄÅ•òÄ†ÖÕ°Ω’±ë1ΩÖê§Å…ï—’…∏Ï((ÄÄÄÅô•πÖ∞Å¡ÖùîÄÙÅÖ›Ö•–Å}…ï≈’ïÕ—%¡—ŸiÖ¡AÖùî†(ÄÄÄÄÄÅçÖ—ïùΩ…‰ËÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰∞(ÄÄÄÄÄÅΩôôÕï–ËÅëï±—ÑÄ¯Ä¿(ÄÄÄÄÄÄÄÄÄÄ¸Å±ÖÕ—âÕΩ±’—îÄ¨Äƒ(ÄÄÄÄÄÄÄÄÄÄËÅµÖ—†πµÖ‡†¿∞Åô•…Õ—âÕΩ±’—îÄ¥Å}≠%¡—ŸiÖ¡AÖùïM•Èî§∞(ÄÄÄÄ§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ¡ÖùîÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅ}µï…ùï%¡—ŸiÖ¡AÖùî°¡Öùî§Ï(ÄÄÄÅ}ë…Ö•πAïπë•πù%¡—ŸiÖ¡%π¡’—Ã†§Ï(ÄÅÙ((ÄÅM—…•πú¸Å}Öë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°•π–Åëï±—Ñ∞Å•π–ÅÖ——ïµ¡–§ÄÙ¯(ÄÄÄÄÄÅ•¡—Ÿë©Öçïπ—iÖ¡Ö—ïùΩ…‰†(ÄÄÄÄÄÄÄÅçÖ—ïùΩ…•ïÃËÅ}•¡—ŸiÖ¡Ö—ïùΩ…•ïÃ∞(ÄÄÄÄÄÄÄÅç’……ïπ–ËÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰∞(ÄÄÄÄÄÄÄÅëï±—ÑËÅëï±—Ñ∞(ÄÄÄÄÄÄÄÅÖ——ïµ¡–ËÅÖ——ïµ¡–∞(ÄÄÄÄÄÄ§Ï((ÄÅ’—’…îÒŸΩ•ê¯Å}¡…ïôï—ç°ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰†(ÄÄÄÅ•π–Åëï±—Ñ∞ÅÏ(ÄÄÄÅ•π–ÅÖ——ïµ¡–ÄÙÄƒ∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÄººÅÅçÖç°ïêÅ¡ÖùîÅΩπ±‰ÅÖπÕ›ï…ÃÅ—°îÅë•…ïç—•Ω∏Å•–Å›ÖÃÅôï—ç°ïêÅôΩ»ÏÅ—’…π•πú(ÄÄÄÄººÅÖ…Ω’πêÅµÖ≠ïÃÅ•–Å—°îÅ›…ΩπúÅïπêÅΩòÅ—°îÅ›…ΩπúÅçÖ—ïùΩ…‰∏(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Öç°ïëAÖùîÄÑÙÅπ’±∞ÄòòÅ}•¡—ŸiÖ¡Öç°ïë•…ïç—•Ω∏ÄÑÙÅëï±—Ñ§ÅÏ(ÄÄÄÄÄÅ}ç±ïÖ…%¡—ŸiÖ¡	Ω’πëÖ…ÂÖç°î†§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•ŸîÅÒ(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–ÅÒ(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰ÄÙÙÅπ’±∞ÅÒ(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Öç°ïëAÖùîÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅç°Öππï±Ãπ•Õµ¡—‰§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞ÅπïÖ…	Ω’πëÖ…‰ÄÙÅëï±—ÑÄ¯Ä¿(ÄÄÄÄÄÄÄÄ¸Å}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–Ä¨Åç°Öππï±Ãπ±ïπù—†Ä¯ÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…ÂQΩ—Ö∞Äòò(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¯ÙÅç°Öππï±Ãπ±ïπù—†Ä¥Å}≠%¡—ŸiÖ¡ëùï5Ö…ù•∏(ÄÄÄÄÄÄÄÄËÅ}•¡—ŸiÖ¡]•πëΩ›=ôôÕï–ÄÙÙÄ¿ÄòòÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÅ}≠%¡—ŸiÖ¡ëùï5Ö…ù•∏Ï(ÄÄÄÅ•òÄ†ÖπïÖ…	Ω’πëÖ…‰§Å…ï—’…∏Ï((ÄÄÄÅô•πÖ∞Å—Ö…ùï–ÄÙÅ}Öë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ∞ÅÖ——ïµ¡–§Ï(ÄÄÄÅ•òÄ°—Ö…ùï–ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞ÅΩ…•ù•∏ÄÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰Ï(ÄÄÄÅô•πÖ∞Å¡ÖùîÄÙÅÖ›Ö•–Å}…ï≈’ïÕ—%¡—ŸiÖ¡AÖùî†(ÄÄÄÄÄÅçÖ—ïùΩ…‰ËÅ—Ö…ùï–∞(ÄÄÄÄÄÅΩôôÕï–ËÄ¿∞(ÄÄÄÄÄÅô…ΩµπêËÅëï±—ÑÄÄ¿∞(ÄÄÄÄ§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ¡ÖùîÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÄººÅiÖ¡¡•πúÅµΩŸïêÅΩ∏Å›°•±îÅ—°•ÃÅ±ΩÖëïêÏÅ•–Å•ÃÅπºÅ±Ωπùï»Å—°îÅπï·–ÅçÖ—ïùΩ…‰∏(ÄÄÄÅ•òÄ°Ω…•ù•∏ÄÑÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°¡Öùîπç°Öππï±Ãπ•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å}¡…ïôï—ç°ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ∞ÅÖ——ïµ¡–ËÅÖ——ïµ¡–Ä¨Äƒ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë=…•ù•πÖ—ïùΩ…‰ÄÙÅΩ…•ù•∏Ï(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë•…ïç—•Ω∏ÄÙÅëï±—ÑÏ(ÄÄÄÅ}•¡—ŸiÖ¡Öç°ïëAÖùîÄÙÅ¡ÖùîÏ(ÄÄÄÅ}ë…Ö•πAïπë•πù%¡—ŸiÖ¡%π¡’—Ã†§Ï(ÄÅÙ((ÄÄºººÅ…ΩÕÃÅ•π—ºÅ—°îÅ¡…ïôï—ç°ïêÅçÖ—ïùΩ…‰Å›•—†ÅπºÅ…Ω’πêÅ—…•¿∏ÅIï—’…πÃÅôÖ±ÕîÅ›°ï∏(ÄÄºººÅπΩ—°•πúÅ’ÕÖâ±îÅ›ÖÃÅçÖç°ïê∞Å±ïÖŸ•πúÅ—°îÅçÖ±±ï»Å—ºÅôï—ç†∏(ÄÅâΩΩ∞Å}çΩπÕ’µïÖç°ïëë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°•π–Åëï±—Ñ§ÅÏ(ÄÄÄÅô•πÖ∞ÅçÖç°ïêÄÙÅ}•¡—ŸiÖ¡Öç°ïëAÖùîÏ(ÄÄÄÅ•òÄ°çÖç°ïêÄÙÙÅπ’±∞ÅÒ(ÄÄÄÄÄÄÄÅçÖç°ïêπç°Öππï±Ãπ•Õµ¡—‰ÅÒ(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë=…•ù•πÖ—ïùΩ…‰ÄÑÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…‰ÅÒ(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Öç°ïë•…ïç—•Ω∏ÄÑÙÅëï±—Ñ§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏ÅôÖ±ÕîÏ(ÄÄÄÅÙ(ÄÄÄÅ}ç±ïÖ…%¡—ŸiÖ¡	Ω’πëÖ…ÂÖç°î†§Ï(ÄÄÄÅ}ïπ—ï…%¡—ŸiÖ¡Ö—ïùΩ…‰°çÖç°ïê∞Åëï±—Ñ§Ï(ÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ§§Ï(ÄÄÄÅ…ï—’…∏Å—…’îÏ(ÄÅÙ((ÄÄºººÅëΩ¡–Åm¡ÖùïtÅÖÃÅ—°îÅ…•πúÅÖπêÅ—’πîÅ—°îÅç°Öππï∞Å—°îÅÈÖ¿Å›ÖÃÅ°ïÖë•πúÅôΩ»Ë(ÄÄºººÅùΩ•πúÅôΩ…›Ö…ëÃÅ—°Ö–Å•ÃÅ—°îÅπï‹ÅçÖ—ïùΩ…‰ùÃÅô•…Õ–Åç°Öππï∞∞ÅùΩ•πúÅâÖç≠›Ö…ëÃ(ÄÄºººÅ•—ÃÅ±ÖÕ–∏(ÄÅŸΩ•êÅ}ïπ—ï…%¡—ŸiÖ¡Ö—ïùΩ…‰°}%¡—ŸiÖ¡AÖùîÅ¡Öùî∞Å•π–Åëï±—Ñ§ÅÏ(ÄÄÄÅ}•πÕ—Ö±±%¡—ŸiÖ¡]•πëΩ‹°¡Öùî∞Å¡…ïÕï…ŸïA±ÖÂ•πù°Öππï∞ËÅôÖ±Õî§Ï(ÄÄÄÅ’πÖ›Ö•—ïê°}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞°ëï±—ÑÄ¯Ä¿Ä¸Ä¿ÄËÅ¡Öùîπç°Öππï±Ãπ±ïπù—†Ä¥Äƒ§§Ï(ÄÄÄÄººÅô—ï»Å—°îÅ—’πî∞ÅπΩ–ÅâïôΩ…îËÅ—°îÅÕ›•—ç†ÅÖπç°Ω…ÃÅ—°îÅù’•ëîÅ—ºÅ—°îÅ—’πïê(ÄÄÄÄººÅç°Öππï∞ùÃÅΩ›∏Åù…Ω’¿∞ÅÖπêÅ—°îÅ…ïÕ¡ΩπÕîùÃÅçÖ—ïùΩ…‰Å•ÃÅ—°îÅµΩ…îÅÖçç’…Ö—î(ÄÄÄÄººÅΩòÅ—°îÅ—›ºÄ°•–ÅçÖ∏ÅâîÅ—°îÅπ’±∞ÅΩòÅÖ∏Å’πçÖ—ïùΩ…•ÈïêÅ›…Ö¿∞Å›°•ç†Åπº(ÄÄÄÄººÅç°Öππï∞ùÃÅù…Ω’¿Åï·¡…ïÕÕïÃ§∏(ÄÄÄÅ}Ö¡¡±Â%¡—Ÿ’•ëïÖ—ïùΩ…‰†(ÄÄÄÄÄÅ¡ÖùîπçÖ—ïùΩ…‰∞(ÄÄÄÄÄÅ¡ÖùîπçÖ—ïùΩ…•ïÃπ•Õµ¡—‰Ä¸Åπ’±∞ÄËÅ¡ÖùîπçÖ—ïùΩ…•ïÃ∞(ÄÄÄÄ§Ï(ÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°%¡—ŸiÖ¡AÖùî°ëï±—Ñ§§Ï(ÄÅÙ((ÄÄºººÅQ°îÅçÖ—ïùΩ…‰Å…Ö∏ÅΩ’–∏Å1ΩÖêÅ—°îÅÖë©Öçïπ–ÅΩπî∞ÅÕ≠•¡¡•πúÅÖπ‰Å—°Ö–ÅçΩµîÅâÖç¨(ÄÄºººÅïµ¡—‰∞ÅÖπêÅù•ŸîÅ’¿ÅΩπçîÅïŸï…‰ÅçÖ—ïùΩ…‰Å°ÖÃÅâïï∏Å—…•ïê∏(ÄÅ’—’…îÒŸΩ•ê¯Å}…ï≈’ïÕ—ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰†(ÄÄÄÅ•π–Åëï±—Ñ∞ÅÏ(ÄÄÄÅ•π–ÅÖ——ïµ¡–ÄÙÄƒ∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–§ÅÏ(ÄÄÄÄÄÅ}≈’ï’ïAïπë•πù%¡—ŸiÖ¡%π¡’–°ëï±—Ñ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å°ÖÕÖ—ïùΩ…•ïÃÄÙÅ}•¡—ŸiÖ¡Ö—ïùΩ…•ïÃπÖπ‰†°å§ÄÙ¯Ååπ•Õ9Ω—µ¡—‰§Ï(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Ö—ïùΩ…‰ÄÙÙÅπ’±∞ÅÒÄÖ°ÖÕÖ—ïùΩ…•ïÃ§ÅÏ(ÄÄÄÄÄÄººÅ∏Å’πçÖ—ïùΩ…•Èïêºâ±∞àÅçΩπ—ï·–Å°ÖÃÅπºÅçÖ—ïùΩ…‰ÅâΩ’πëÖ…‰Å—ºÅç…ΩÕÃË(ÄÄÄÄÄÄººÅ›…Ö¿Åâ‰Å¡Öù•πúÅ—°îÅΩ¡¡ΩÕ•—îÅïπêÅΩòÅ—°îÅÕÖµîÅ…ïÕ’±–ÅÕï–∏(ÄÄÄÄÄÅô•πÖ∞Å¡ÖùîÄÙÅÖ›Ö•–Å}…ï≈’ïÕ—%¡—ŸiÖ¡AÖùî†(ÄÄÄÄÄÄÄÅçÖ—ïùΩ…‰ËÅπ’±∞∞(ÄÄÄÄÄÄÄÅΩôôÕï–ËÄ¿∞(ÄÄÄÄÄÄÄÅô…ΩµπêËÅëï±—ÑÄÄ¿∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ¡ÖùîÄÙÙÅπ’±∞ÅÒÅ¡Öùîπç°Öππï±Ãπ•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÄÄÄººÅ9Ω—°•πúÅçÖµîÅâÖç¨Å—ºÅÈÖ¿Å•π—º∞ÅÕºÅπΩ—°•πúÅ›•±∞Åë…Ö•∏Å—°ïÕîÅï•—°ï»∏(ÄÄÄÄÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπç±ïÖ»†§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ}ïπ—ï…%¡—ŸiÖ¡Ö—ïùΩ…‰°¡Öùî∞Åëï±—Ñ§Ï(ÄÄÄÄÄÅ}ë…Ö•πAïπë•πù%¡—ŸiÖ¡%π¡’—Ã†§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÄººÅ9’±∞ÅΩπçîÅ—°îÅ›Ö±¨Å°ÖÃÅâïï∏ÅÖ±∞Å—°îÅ›Ö‰Å…Ω’πêÇÈ›y¯ßy–ÅïŸï…‰ÅçÖ—ïùΩ…‰Å›ÖÃ(ÄÄÄÄººÅïµ¡—‰∞ÅÕºÅπΩ—°•πúÅ›•±∞ÅïŸï»Åë…Ö•∏Å—°îÅ≈’ï’ïêÅ¡…ïÕÕïÃ∏(ÄÄÄÅô•πÖ∞Å—Ö…ùï–ÄÙÅ}Öë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ∞ÅÖ——ïµ¡–§Ï(ÄÄÄÅ•òÄ°—Ö…ùï–ÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπç±ïÖ»†§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å¡ÖùîÄÙÅÖ›Ö•–Å}…ï≈’ïÕ—%¡—ŸiÖ¡AÖùî†(ÄÄÄÄÄÅçÖ—ïùΩ…‰ËÅ—Ö…ùï–∞(ÄÄÄÄÄÅΩôôÕï–ËÄ¿∞(ÄÄÄÄÄÅô…ΩµπêËÅëï±—ÑÄÄ¿∞(ÄÄÄÄ§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ¡ÖùîÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°¡Öùîπç°Öππï±Ãπ•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å}…ï≈’ïÕ—ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ∞ÅÖ——ïµ¡–ËÅÖ——ïµ¡–Ä¨Äƒ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅ}ïπ—ï…%¡—ŸiÖ¡Ö—ïùΩ…‰°¡Öùî∞Åëï±—Ñ§Ï(ÄÄÄÅ’πÖ›Ö•—ïê°}¡…ïôï—ç°ë©Öçïπ—%¡—ŸÖ—ïùΩ…‰°ëï±—Ñ§§Ï(ÄÄÄÅ}ë…Ö•πAïπë•πù%¡—ŸiÖ¡%π¡’—Ã†§Ï(ÄÅÙ((ÄÅŸΩ•êÅ}≈’ï’ïAïπë•πù%¡—ŸiÖ¡%π¡’–°•π–Åëï±—Ñ§ÅÏ(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπ±ïπù—†Ä¯ÙÄ»–§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—ÃπÖëê°ëï±—ÑÄ¯ÙÄ¿Ä¸ÄƒÄËÄ¥ƒ§Ï(ÄÅÙ((ÄÅŸΩ•êÅ}ë…Ö•πAïπë•πù%¡—ŸiÖ¡%π¡’—Ã†§ÅÏ(ÄÄÄÅ•òÄ°}•¡—ŸiÖ¡…Ö•π•πù%π¡’—Ã§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—ŸiÖ¡…Ö•π•πù%π¡’—ÃÄÙÅ—…’îÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅ›°•±îÄ°}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπ•Õ9Ω—µ¡—‰§ÅÏ(ÄÄÄÄÄÄÄÅô•πÖ∞Å≈’ï’ïêÄÙÅ}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπ±ïπù—†Ï(ÄÄÄÄÄÄÄÅ}ÈÖ¡%¡—Ÿ°Öππï∞°}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπ…ïµΩŸï–†¿§§Ï(ÄÄÄÄÄÄÄÄººÅπΩ—°ï»Å…Ω’πêÅ—…•¿ÅÕ—Ö…—ïêËÅ—°îÅ…ïÕ–Åë…Ö•∏Å›°ï∏Å•–Å±ÖπëÃ∏(ÄÄÄÄÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Iï≈’ïÕ—%π±•ù°–§Åâ…ïÖ¨Ï(ÄÄÄÄÄÄÄÄººÅQ°îÅ¡…ïÕÃÅ›ïπ–ÅÕ—…Ö•ù°–ÅâÖç¨ÅΩ∏Å—°îÅ≈’ï’îÅ›•—°Ω’–ÅÕ—Ö…—•πúÅΩπî∞ÅÕº(ÄÄÄÄÄÄÄÄººÅπΩ—°•πúÅ›•±∞ÅÖ……•ŸîÅ—ºÅµΩŸîÅ•–ÅÖ±ΩπúãßuÁ‚ùÁPÅÕ—Ω¿Å•πÕ—ïÖêÅΩòÅÕ¡•ππ•πú∏(ÄÄÄÄÄÄÄÅ•òÄ°}•¡—ŸiÖ¡Aïπë•πù%π¡’—Ãπ±ïπù—†Ä¯ÙÅ≈’ï’ïê§Åâ…ïÖ¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙÅô•πÖ±±‰ÅÏ(ÄÄÄÄÄÅ}•¡—ŸiÖ¡…Ö•π•πù%π¡’—ÃÄÙÅôÖ±ÕîÏ(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅQ’…∏ÅÖ∏ÅÖ…ç°•ŸïêÅAÅ¡…Ωù…ÖµµîÅ•π—ºÅÑÅô•π•—î∞ÅÕïï≠Öâ±îÅ%AQXÅ•—ï¥Å•∏Å—°î(ÄÄºººÅç’……ïπ–Å¡±ÖÂï»∏ÅQ°îÅπΩ…µÖ∞Å%AQXÅÕ›•—ç°•πúÅ¡Ö—†Å…ïµÖ•πÃÅ…ïÕ¡ΩπÕ•â±îÅôΩ»(ÄÄºººÅ°ïÖëï…Ã∞Å—…ÖπÕ•—•Ω∏ÅôïïëâÖç¨∞Å—…Öç≠Ã∞ÅÖπêÅ…ïÕ’µîÅ•ëïπ—•—‰∏(ÄÅ’—’…îÒŸΩ•ê¯Å}¡±ÖÂ%¡—ŸÖ—ç°’¿†(ÄÄÄÅ%¡—Ÿ°Öππï∞Åç°Öππï∞∞(ÄÄÄÅ¡ùA…Ωù…ÖµµîÅ¡…Ωù…Öµµî∞(ÄÄ§ÅÖÕÂπåÅÏ(ÄÄÄÅ•òÄ°¡…Ωù…ÖµµîπÖ•…Õ–°Ö—ïQ•µîππΩ‹†§§§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÄÄÅô•πÖ∞Å•πëï‡ÄÙÅç°Öππï±Ã¸π•πëï·]°ï…î†(ÄÄÄÄÄÄÄÄ°çÖπë•ëÖ—î§ÄÙ¯ÅçÖπë•ëÖ—îπ’…∞ÄÙÙÅç°Öππï∞π’…∞∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ°•πëï‡ÄÑÙÅπ’±∞ÄòòÅ•πëï‡Ä¯ÙÄ¿ÄòòÅ•πëï‡ÄÑÙÅ}ç’……ïπ—%¡—Ÿ%πëï‡§ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞°•πëï‡§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅô•πÖ∞Åç’……ïπ–ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÄÄÅ•òÄ°ç’……ïπ–ÄÑÙÅπ’±∞ÄòòÅç’……ïπ–π’…∞ÄÙÙÅç°Öππï∞π’…∞§ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}Õ—Ö…—%¡—ŸA…Ωù…Öµµï…Ωµ	ïù•ππ•πú°ç’……ïπ–∞Å¡…Ωù…Öµµî§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å…ï≈’ïÕ—Q•ç≠ï–ÄÙÅ}âïù•π%¡—ŸÖ—ç°’¡Iï≈’ïÕ–†§Ï(ÄÄÄÅô•πÖ∞ÅµïÕÕïπùï»ÄÙÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§Ï(ÄÄÄÅµïÕÕïπùï»πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†ùA…ï¡Ö…•πúÅ…ï¡±Ö‰ÅΩòÄàëÌ¡…Ωù…Öµµîπ—•—±ïÙÆù◊üäwùòú§∞(ÄÄÄÄÄÄÄÅë’…Ö—•Ω∏ËÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄÃ¿§∞(ÄÄÄÄÄÄ§∞(ÄÄÄÄ§Ï(ÄÄÄÅM—…•πú¸Å’…∞Ï(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅ’…∞ÄÙÅÖ›Ö•–Å%¡—Ÿ¡ùMï…Ÿ•çîπ•πÕ—ÖπçîπçÖ—ç°’¡U…∞°ç°Öππï∞π’…∞∞Å¡…Ωù…Öµµî§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°ï……Ω»§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅ%AQXÅ…ï¡±Ö‰Å±ΩΩ≠’¿ÅôÖ•±ïêËÄëï……Ω»ú§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ†Ö}•Õ’……ïπ—%¡—ŸÖ—ç°’¡Iï≈’ïÕ–°…ï≈’ïÕ—Q•ç≠ï–§§Å…ï—’…∏Ï(ÄÄÄÅ•òÄ°’…∞ÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅ}•¡—ŸÖ—ç°’¡Iï≈’ïÕ—ÃπçΩµ¡±ï—î°…ï≈’ïÕ—Q•ç≠ï–§Ï(ÄÄÄÄÄÅµïÕÕïπùï»π°•ëï’……ïπ—MπÖç≠	Ö»†§Ï(ÄÄÄÄÄÅµïÕÕïπùï»πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»°çΩπ—ïπ–ËÅQï·–†ùIï¡±Ö‰Å•ÃÅπΩ–ÅÖŸÖ•±Öâ±îú§§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÅô•πÖ∞ÅÕΩ’…çï%êÄÙ(ÄÄÄÄÄÄÄÅç°Öππï∞πÖ——…•â’—ïÕlùÕΩ’…çï}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÅ}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëî¸πÕΩ’…çï%êÄ¸¸(ÄÄÄÄÄÄÄÅ›•ëùï–π•¡—ŸMΩ’…çï%êÏ(ÄÄÄÅô•πÖ∞Å…ï¡±Ö‰ÄÙÅ%¡—Ÿ°Öππï∞†(ÄÄÄÄÄÅπÖµîËÅ¡…Ωù…Öµµîπ—•—±î∞(ÄÄÄÄÄÅ’…∞ËÅ’…∞∞(ÄÄÄÄÄÅ±ΩùΩU…∞ËÅç°Öππï∞π±ΩùΩU…∞∞(ÄÄÄÄÄÅù…Ω’¿ËÅç°Öππï∞ππÖµî∞(ÄÄÄÄÄÅçΩπ—ïπ—QÂ¡îËÄùŸΩêú∞(ÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅç°Öππï∞π°——¡!ïÖëï…Ã∞(ÄÄÄÄÄÅÖ——…•â’—ïÃËÅÌ•òÄ°ÕΩ’…çï%êÄÑÙÅπ’±∞§ÄùÕΩ’…çï}¡±ÖÂ±•Õ—}•êúËÅÕΩ’…çï%ëÙ∞(ÄÄÄÄ§Ï(ÄÄÄÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπ…ïçΩ…ë%¡—Ÿ]Ö—ç††(ÄÄÄÄÄÅ…ï¡±Ö‰π’…∞∞(ÄÄÄÄÄÅç°Öππï±9ÖµîËÅ…ï¡±Ö‰ππÖµî∞(ÄÄÄÄÄÅ±ΩùΩU…∞ËÅ…ï¡±Ö‰π±ΩùΩU…∞∞(ÄÄÄÄÄÅù…Ω’¿ËÅ…ï¡±Ö‰πù…Ω’¿∞(ÄÄÄÄÄÅ¡±ÖÂ±•Õ—%êËÅÕΩ’…çï%ê∞(ÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅ…ï¡±Ö‰π°——¡!ïÖëï…Ã∞(ÄÄÄÄ§Ï(ÄÄÄÅ•òÄ†Ö}•Õ’……ïπ—%¡—ŸÖ—ç°’¡Iï≈’ïÕ–°…ï≈’ïÕ—Q•ç≠ï–§§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—ŸÖ—ç°’¡Iï≈’ïÕ—ÃπçΩµ¡±ï—î°…ï≈’ïÕ—Q•ç≠ï–§Ï(ÄÄÄÅµïÕÕïπùï»π°•ëï’……ïπ—MπÖç≠	Ö»†§Ï(ÄÄÄÄººÅÅ…ï¡±Ö‰Å•ÃÅÑÅÕ•πù±îÅΩ∏µëïµÖπêÅ•—ï¥∞ÅπΩ–ÅÑÅ¡ÖùîÅΩòÅÖπ‰ÅçÖ—ïùΩ…‰∏(ÄÄÄÅ}…ïÕï—%¡—ŸiÖ¡AÖù•πú†§Ï(ÄÄÄÅ}•¡—Ÿ°Öππï±Õ=Ÿï……•ëîÄÙÅm…ï¡±ÖÂtÏ(ÄÄÄÅÖ›Ö•–Å}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞†¿§Ï(ÄÅÙ((ÄÄºººÅ5ΩπΩ—Ωπ•åÅ—•ç≠ï–ÅôΩ»Å%AQXÅç°Öππï∞ÅÕ›•—ç°ïÃ∏ÅQ°îÅM—…ïµ•ºÅçÖπë•ëÖ—îÅ±Öëëï»(ÄÄºººÅçÖ∏Å°Ω±êÅm}Õ›•—ç°QΩ%¡—Ÿ°Öππï±tÅΩ¡ï∏ÅôΩ»ÅµÖπ‰ÅÕïçΩπëÃÏÅÑÅπï›ï»ÅÕ›•—ç†(ÄÄºººÅµ’Õ–ÅÕ—…ÖπêÅ—°îÅΩ±ëï»ÅΩπîÄ°πºÅΩ¡ïπÃ∞ÅπºÅ›•ππï»ÅµÖ…≠Ã§ÅΩ»ÅÖ∏ÅÖâÖπëΩπïê(ÄÄºººÅ±Öëëï»Å›Ω’±êÅ°•©Öç¨Å¡±ÖÂâÖç¨ÅâÖç¨Å—ºÅ•—ÃÅç°Öππï∞∏(ÄÅ•π–Å}•¡—ŸM›•—ç°Q•ç≠ï–ÄÙÄ¿Ï((ÄÄºººÅQ°îÅÕ—…ïµ•ºµ—ÿËººÅ≠ï‰ÅΩòÅ—°îÅ%AQXÅç°Öππï∞Åç’……ïπ—±‰Å¡±ÖÂ•πú∞Å›°ï∏Å•–Å•Ã(ÄÄºººÅÑÅM—…ïµ•ºµÖëëΩ∏Åç°Öππï∞ãßuÁ‚ùÁPÅπΩ∏µπ’±∞Å…Ω’—ïÃÅÕΩ’…çîµÕ°ïï–ÅÕï±ïç—•ΩπÃÅëΩ›∏(ÄÄºººÅ—°îÅ±•ŸîÅ¡Ö—†Å•πÕ—ïÖêÅΩòÅ—°îÅµΩŸ•îÅÕΩ’…çîµÕ›•—ç†Å¡•¡ï±•πî∏(ÄÅM—…•πú¸Å}•¡—Ÿ°Öππï±-ï‰Ï((ÄÄºººÅM’¡¡…ïÕÕïÃÅm}Ωπ%¡—ŸM—…ïÖµ……Ω…tÅôΩ»Åï……Ω…ÃÅ—°Ö–ÅÖ…ï∏ù–Å—°îÅ—’πïê(ÄÄºººÅç°Öππï∞ùÃÅ—ºÅΩ›∏∏ÅMï–ÅôΩ»Å—°îÅ›°Ω±îÅΩòÅm}Õ›•—ç°QΩ%¡—Ÿ°Öππï±tÅÖπê(ÄÄºººÅç±ïÖ…ïêÅ—°îÅµΩµïπ–Å—°îÅπï‹Åµïë•ÑÅ•ÃÅÖç—’Ö±±‰ÅΩ¡ïπïê∞ÅâïçÖ’ÕîÅ’π—•∞Å—°ï∏(ÄÄºººÅµ¡ÿÅ•ÃÅÕ—•±∞Åë…Ö•π•πúÅ—°îÅ=UQ=%9Åç°Öππï∞ÇÈ›y¯ßy–Å›°•±îÅm}ç’……ïπ—%¡—Ÿ%πëï·t(ÄÄºººÅÖ±…ïÖë‰Å¡Ω•π—ÃÅÖ–Å—°îÅπï‹ÅΩπî∞ÅÕºÅÑÅ…ï¡Ω…–Å›Ω’±êÅâ±ÖµîÅ—°îÅ›…Ωπú(ÄÄºººÅç°Öππï∞∏ÅÅM—…ïµ•ºÅ±Öëëï»ÅÕ—ÖÂÃÅµ’—ïêÅ—°…Ω’ù°Ω’–ËÅëïÖêÅçÖπë•ëÖ—ïÃÅÖ…î(ÄÄºººÅπΩ…µÖ∞Å—°ï…îÅÖπêÅ•–Å…ï¡Ω…—ÃÅôΩ»Å•—Õï±ò∏(ÄÅâΩΩ∞Å}•¡—Ÿ……Ω…Õ5’—ïêÄÙÅôÖ±ÕîÏ((ÄÄºººÅµ¡ÿÅ…ï¡Ω…—ÃÅÑÅôÖ•±ïêÅÕ—…ïÖ¥ÅÖÃÅÕïŸï…Ö∞Åï……Ω…ÃÅ•∏ÅÑÅ…Ω‹ÏÅΩπ±‰Å—°îÅô•…Õ–ÅΩò(ÄÄºººÅÑÅâ’…Õ–Å•ÃÅ›Ω…—†ÅÑÅµïÕÕÖùî∏Å±ïÖ…ïêÅΩ∏ÅïŸï…‰ÅÈÖ¿ÅÕºÅïÖç†Åç°Öππï∞Å—°îÅ’Õï»(ÄÄºººÅ—…•ïÃÅçÖ∏Å…ï¡Ω…–ÅΩπçîÆù◊üäwùPÅçΩ±±Ö¡Õ•πúÅÑÅâ’…Õ–Åµ’Õ–ÅπΩ–ÅÕ•±ïπçîÅ—°îÅπï·–(ÄÄºººÅç°Öππï∞ùÃÅùïπ’•πîÅôÖ•±’…î∏(ÄÅÖ—ïQ•µî¸Å}±ÖÕ—%¡—Ÿ……Ω…M°Ω›∏Ï((ÄÄºººÅÅ¡±Ö•∏Å%AQXÅç°Öππï∞ùÃÅÕ—…ïÖ¥ÅôÖ•±ïê∏ÅMÖ‰ÅÕºÆù◊üäwùPÅ—°îÅÖ±—ï…πÖ—•ŸîÄ°ÖπêÅ—°î(ÄÄºººÅ¡…îµï·•Õ—•πúÅâï°ÖŸ•Ω»§Å•ÃÅÖ∏Å•πëïô•π•—îÅâ±Öç¨ÅÕç…ïï∏Å—°Ö–Å…ïÖëÃÅÖÃÅ—°î(ÄÄºººÅ›°Ω±îÅ%AQXÅÕïç—•Ω∏Åâï•πúÅâ…Ω≠ï∏∏(ÄÅŸΩ•êÅ}Ωπ%¡—ŸM—…ïÖµ……Ω»°M—…•πúÅï……Ω»§ÅÏ(ÄÄÄÅ}•¡—Ÿ•ÖúπΩπ……Ω»°ï……Ω»§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ}•¡—Ÿ……Ω…Õ5’—ïê§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞§Å…ï—’…∏Ï((ÄÄÄÄººÅµ¡ÿÅ…ï¡Ω…—ÃÅ!QQ@Å…ï©ïç—•Ω∏ÅΩ∏Å•—ÃÅï……Ω»ÅÕ—…ïÖ¥ÅïŸï∏Å›°ï∏ÅΩ¡ï∏†§(ÄÄÄÄººÅçΩµ¡±ï—ïÃÅπΩ…µÖ±±‰∏Å∏ÅÖ…ç°•ŸîÅôÖ•±’…îÅµ’Õ–Å…ï—’…∏Å—ºÅ—°îÅ±•ŸîÅUI0(ÄÄÄÄººÅâïôΩ…îÅUQ Åç±ÖÕÕ•ô•çÖ—•Ω∏ÅçÖ∏ÅâÂ¡ÖÕÃÅ—°îÅ…ïçΩŸï…‰Å±Öëëï»∏(ÄÄÄÅ•òÄ°}•¡—ŸM—Ö…—=Ÿï…ç—•ŸîÄòòÅ}ç’……ïπ—%¡—Ÿ°Öππï∞¸π•Õ1•ŸîÄÙÙÅ—…’î§ÅÏ(ÄÄÄÄÄÅ•òÄ°}•¡—ŸIïçΩŸï…Â±•ù•â±î†§§ÅÏ(ÄÄÄÄÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ}•¡—ŸM—Ö…—=Ÿï…ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÄÄÅ}•¡—ŸM—Ö…—=Ÿï…Q•µï±•πïIï≈’ïÕ—ïêÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÅÙ§Ï(ÄÄÄÄÄÄÄÅ’πÖ›Ö•—ïê°}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞°}ç’……ïπ—%¡—Ÿ%πëï‡∞Å≈’•ï—IïçΩŸï…‰ËÅ—…’î§§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÄººÅA°ÖÕîÄ»ËÅÑÅ±•ŸîÅç°Öππï∞ùÃÅï……Ω»ÅùΩïÃÅ—ºÅ—°îÅ…ïçΩŸï…‰ÅµÖç°•πîÅô•…Õ–Æù◊üäwùP(ÄÄÄÄººÅ—°îÅÕπÖç≠âÖ»Åâï±Ω‹Å•ÃÅπΩ‹Å—°îÅMUII9HÅŸΩ•çîÄ°Ÿ•ÑÅ—°îÅµÖç°•πîùÃ(ÄÄÄÄººÅΩπM’……ïπëï»§∞ÅπΩ–Å—°îÅô•…Õ–Å…ïÕ¡ΩπÕî∏Å9Ω∏µ±•ŸîÅ≠ïï¡ÃÅ—°îÅΩ±ê(ÄÄÄÄººÅÕÖ‰µ•–µ•µµïë•Ö—ï±‰Åâï°ÖŸ•Ω»∏Å’—†µç±ÖÕÃÅôÖ•±’…ïÃÄ°µ¡ÿùÃÅï……Ω»ÅÕ—…•πú(ÄÄÄÄººÅ•ÃÅÖ±∞Å›îÅ°ÖŸîÆù◊üäwùPÅâïÕ–µïôôΩ…–ÅµÖ—ç†§ÅÕ≠•¿Å—°îÅ±Öëëï»Åïπ—•…ï±‰ËÅÑ(ÄÄÄÄººÄ–¿ƒº–¿Ãº–¿–Å…ï¡ïÖ—ÃÅëï—ï…µ•π•Õ—•çÖ±±‰∞ÅÕºÅÕÖ‰ÅÕºÅ9=\Å•πÕ—ïÖêÅΩò(ÄÄÄÄººÅ…ï—…Â•πúÅôΩ»Ä‹‘ÅÕïçΩπëÃÄ°µ•……Ω»ÅΩòÅ—°îÅQXÅ¡Ω±•ç‰ùÃÅUQ Åç±ÖÕÃ§∏(ÄÄÄÅô•πÖ∞Å±ΩΩ≠Õ’—°……Ω»ÄÙÅIïù·¿°»ùqà†–¿≈–¿Õ–¿–•qàú§π°ÖÕ5Ö—ç†°ï……Ω»§Ï(ÄÄÄÅ•òÄ°}ç’……ïπ—%¡—Ÿ°Öππï∞¸π•Õ1•ŸîÄÙÙÅ—…’îÄòò(ÄÄÄÄÄÄÄÄÖ±ΩΩ≠Õ’—°……Ω»Äòò(ÄÄÄÄÄÄÄÅ}•¡—Ÿ1•ŸïIïçΩŸï…‰πΩπ……Ω»†§§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ((ÄÄÄÅô•πÖ∞ÅπΩ‹ÄÙÅÖ—ïQ•µîππΩ‹†§Ï(ÄÄÄÅô•πÖ∞Å±ÖÕ–ÄÙÅ}±ÖÕ—%¡—Ÿ……Ω…M°Ω›∏Ï(ÄÄÄÅ•òÄ°±ÖÕ–ÄÑÙÅπ’±∞ÄòòÅπΩ‹πë•ôôï…ïπçî°±ÖÕ–§ÄÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄÿ§§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅ}±ÖÕ—%¡—Ÿ……Ω…M°Ω›∏ÄÙÅπΩ‹Ï((ÄÄÄÅô•πÖ∞ÅπÖµîÄÙÄ°}ç’……ïπ—%¡—Ÿ%πëï‡Ä¯ÙÄ¿ÄòòÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÅç°Öππï±Ãπ±ïπù—†§(ÄÄÄÄÄÄÄÄ¸Åç°Öππï±Õm}ç’……ïπ—%¡—Ÿ%πëï·tππÖµî(ÄÄÄÄÄÄÄÄËÄùQ°•ÃÅç°Öππï∞úÏ(ÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅ%AQXÅÕ—…ïÖ¥Åï……Ω»ÅΩ∏ÄàëπÖµîàËÄëï……Ω»ú§Ï(ÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†àëπÖµîÅë•ë∏ù–Å¡±Ö‰ÇÈ›y¯ßy–Äëï……Ω»à§∞(ÄÄÄÄÄÄÄÅë’…Ö—•Ω∏ËÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄ‘§∞(ÄÄÄÄÄÄ§∞(ÄÄÄÄ§Ï(ÄÅÙ((ÄÄºººÅM’…ôÖçîÅÑÅM—…ïµ•ºÅ%AQXÅç°Öππï∞ùÃÅçÖπë•ëÖ—îÅ±•π≠ÃÅ•∏Å—°îÅï·•Õ—•πúÅÕΩ’…çî(ÄÄºººÅÕ°ïï–ËÅ—°îÅçÖπë•ëÖ—ïÃÅâïçΩµîÅë•…ïç–µUI0ÅmQΩ……ïπ—tÅ…Ω›ÃÅŸ•ÑÅ—°îÅΩŸï……•ëî(ÄÄºººÅ—°îÅÕ°ïï–ÅÖ±…ïÖë‰Å°ΩπΩ…Ã∏Å9’±∞Ωïµ¡—‰Åç±ïÖ…ÃÅ—°îÅÕ°ïï–Ä°¡±Ö•∏Å4ÕT(ÄÄºººÅç°Öππï±ÃÅ°ÖŸîÅï·Öç—±‰ÅΩπîÅ±•π¨ãßuÁ‚ùÁPÅπΩ—°•πúÅ—ºÅ¡•ç¨§∏(ÄÅŸΩ•êÅ}Õï—%¡—ŸMΩ’…çïÃ†(ÄÄÄÅM—…•πú¸Åç°Öππï±-ï‰∞(ÄÄÄÅ1•Õ–ÒM—…ïµ•Ω%¡—ŸÖπë•ëÖ—î¯¸ÅçÖπë•ëÖ—ïÃ∞ÅÏ(ÄÄÄÅ•π–Åç’……ïπ—%πëï‡ÄÙÄ¿∞(ÄÅÙ§ÅÏ(ÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÅ}•¡—Ÿ°Öππï±-ï‰ÄÙÅç°Öππï±-ï‰Ï(ÄÄÄÅ•òÄ°ç°Öππï±-ï‰ÄÙÙÅπ’±∞ÅÒÅçÖπë•ëÖ—ïÃÄÙÙÅπ’±∞ÅÒÅçÖπë•ëÖ—ïÃπ•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÅ•òÄ°}Õ—…ïµ•ΩMΩ’…çïÕ=Ÿï……•ëîÄÑÙÅπ’±∞ÅÒ(ÄÄÄÄÄÄÄÄÄÅ}…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çï=Ÿï……•ëîÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ}Õ—…ïµ•ΩMΩ’…çïÕ=Ÿï……•ëîÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÄÄÅ}…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çï=Ÿï……•ëîÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÅÙ§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞ÅÕΩ’…çïÃÄÙÄÒQΩ……ïπ–˘l(ÄÄÄÄÄÅôΩ»Ä°ŸÖ»Å§ÄÙÄ¿ÏÅ§ÄÅçÖπë•ëÖ—ïÃπ±ïπù—†ÏÅ§¨¨§(ÄÄÄÄÄÄÄÅQΩ……ïπ–†(ÄÄÄÄÄÄÄÄÄÅ…Ω›•êËÅ§∞(ÄÄÄÄÄÄÄÄÄÄººÅMÖµîÅÕÂπ—°ï—•åµ°ÖÕ†ÅçΩπŸïπ—•Ω∏Å}çΩπŸï…—QΩQΩ……ïπ—ÃÅ’ÕïÃÅôΩ»(ÄÄÄÄÄÄÄÄÄÄººÅë•…ïç–µUI0ÅÕ—…ïÖµÃÄ°Õ—Öâ±îÅ¡ï»µUI0Åëïë’¡îÅ≠ï‰∞ÅπΩ–ÅÑÅ…ïÖ∞Å°ÖÕ†§∏(ÄÄÄÄÄÄÄÄÄÅ•πôΩ°ÖÕ†Ë(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄù’…∞ËëÌçÖπë•ëÖ—ïÕm•tπ’…∞π°ÖÕ°Ωëîπ—ΩIÖë•·M—…•πú†ƒÿ§π¡Öë1ïô–†–¿∞Äú¿ú•Ùú∞(ÄÄÄÄÄÄÄÄÄÅπÖµîËÅçÖπë•ëÖ—ïÕm•tπ±Öâï∞∞(ÄÄÄÄÄÄÄÄÄÅÕ•Èï	Â—ïÃËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅç…ïÖ—ïëUπ•‡ËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅÕïïëï…ÃËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅ±ïïç°ï…ÃËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅçΩµ¡±ï—ïêËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅÕç…Ö¡ïëÖ—îËÄ¿∞(ÄÄÄÄÄÄÄÄÄÅÕΩ’…çîËÄùÕ—…ïµ•ºú∞(ÄÄÄÄÄÄÄÄÄÅÕ—…ïÖµQÂ¡îËÅM—…ïÖµQÂ¡îπë•…ïç—U…∞∞(ÄÄÄÄÄÄÄÄÄÅë•…ïç—U…∞ËÅçÖπë•ëÖ—ïÕm•tπ’…∞∞(ÄÄÄÄÄÄÄÄÄÅ°ÖÕIïÖ±%πôΩ!ÖÕ†ËÅôÖ±Õî∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÅtÏ(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}Õ—…ïµ•ΩMΩ’…çïÕ=Ÿï……•ëîÄÙÅÕΩ’…çïÃÏ(ÄÄÄÄÄÅ}…ïÕΩ±ŸïM—…ïµ•ΩMΩ’…çï=Ÿï……•ëîÄÙÄ°–§ÅÖÕÂπåÄÙ¯Å–πë•…ïç—U…∞Ï(ÄÄÄÄÄÅ}ç’……ïπ—MΩ’…çï%πëï‡ÄÙÅç’……ïπ—%πëï‡πç±Öµ¿†¿∞ÅÕΩ’…çïÃπ±ïπù—†Ä¥Äƒ§Ï(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÄºººÅQ°îÅ±Ö’πç†ÅÖ±…ïÖë‰Å…ïÕΩ±ŸïêÅ—°îÅ•π•—•Ö∞Åç°Öππï∞ùÃÅUI0∞Åâ’–Å—°îÅÕΩ’…çî(ÄÄºººÅÕ°ïï–Å›Öπ—ÃÅ—°îÅ›°Ω±îÅçÖπë•ëÖ—îÅ±•Õ–Æù◊üäwùPÅôï—ç†Å•–Ä°çÖç°îÅ°•–Åô…Ω¥Å—°î(ÄÄºººÅ±Ö’πç†Å…ïÕΩ±Ÿî§ÅÖπêÅ¡Ω¡’±Ö—îÅ—°îÅΩŸï……•ëîÅôΩ»Å—°îÅÕ—Ö…—•πúÅç°Öππï∞∏(ÄÅŸΩ•êÅ}•π•—%¡—ŸM—…ïµ•ΩMΩ’…çïÃ†§ÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅô•πÖ∞Å•ë‡ÄÙÅ›•ëùï–π•¡—ŸM—Ö…—%πëï‡Ä¸¸Ä¿Ï(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅ•ë‡ÄÄ¿ÅÒÅ•ë‡Ä¯ÙÅç°Öππï±Ãπ±ïπù—†§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅç°Öππï±Õm•ë·tÏ(ÄÄÄÅ•òÄ†ÖM—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•ÕM—…ïµ•Ω°Öππï±U…∞°ç°Öππï∞π’…∞§§Å…ï—’…∏Ï(ÄÄÄÅM—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•πÕ—Öπçîπ…ïÕΩ±ŸïÖπë•ëÖ—ïÃ°ç°Öππï∞π’…∞§π—°ï∏†°ôΩ’πê§ÅÏ(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅôΩ’πêπ•Õµ¡—‰§Å…ï—’…∏Ï(ÄÄÄÄÄÄººÅQ°îÅ’Õï»ÅÖ±…ïÖë‰ÅÈÖ¡¡ïêÅÖ›Ö‰Ä°Ω»ÅÑÅÕ›•—ç†Å¡Ω¡’±Ö—ïêÅÕΩ’…çïÃÅ•—Õï±ò§∏(ÄÄÄÄÄÅ•òÄ°}•¡—Ÿ°Öππï±-ï‰ÄÑÙÅπ’±∞ÅÒÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÑÙÅ•ë‡§Å…ï—’…∏Ï(ÄÄÄÄÄÅŸÖ»Åç’……ïπ–ÄÙÅôΩ’πêπ•πëï·]°ï…î†°å§ÄÙ¯Ååπ’…∞ÄÙÙÅ›•ëùï–πŸ•ëïΩU…∞§Ï(ÄÄÄÄÄÅ•òÄ°ç’……ïπ–ÄÄ¿§Åç’……ïπ–ÄÙÄ¿Ï(ÄÄÄÄÄÅ}Õï—%¡—ŸMΩ’…çïÃ°ç°Öππï∞π’…∞∞ÅôΩ’πê∞Åç’……ïπ—%πëï‡ËÅç’……ïπ–§Ï(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÄºººÅM›•—ç†Å—ºÅ%AQXÅç°Öππï∞ÅÖ–Åù•Ÿï∏Å•πëï‡(ÄÄºººÅQ°îÅ%AQXÅç°Öππï∞Åç’……ïπ—±‰Å¡±ÖÂ•πú∞ÅΩ»Åπ’±∞(ÄÄºººÅ›°ï∏ÅπΩ–Å•∏ÅÖ∏Å%AQXÅçΩπ—ï·–ÅΩ»Å—°îÅ•πëï‡Å•ÃÅΩ’–ÅΩòÅ…Öπùî∏(ÄÅ%¡—Ÿ°Öππï∞¸Åùï–Å}ç’……ïπ—%¡—Ÿ°Öππï∞ÅÏ(ÄÄÄÅô•πÖ∞Åç°ÖπÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°ÖπÃÄÙÙÅπ’±∞ÅÒ(ÄÄÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÄ¿ÅÒ(ÄÄÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¯ÙÅç°ÖπÃπ±ïπù—†§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Åπ’±∞Ï(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏Åç°ÖπÕm}ç’……ïπ—%¡—Ÿ%πëï·tÏ(ÄÅÙ((ÄÄººÄÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙ(ÄÄººÅM—Ö…—’¿µç°Öππï∞ÅµïµΩ…‰(ÄÄºº(ÄÄººÅIïµïµâï…ÃÅ—°îÅ±ÖÕ–Å1%YÅç°Öππï∞Å—°Ö–ÅÖç—’Ö±±‰Å…ïÖç°ïêÅÑÅ¡±ÖÂ•πúÅÕ—Ö—î∞ÅÕº(ÄÄººÄâÕ—Ö…–ÅΩ∏Åµ‰Å±ÖÕ–Åç°Öππï∞àÅ…îµ—’πïÃÅ›°Ö–Å›ÖÃÅâï•πúÅ›Ö—ç°ïêÅ…Ö—°ï»Å—°Ö∏Å›°Ö–(ÄÄººÅ›ÖÃÅ±ÖÕ–Å±Ö’πç°ïêÇÈ›y¯ßy–ÅÈÖ¡¡•πúÅ•ÃÅ°Ω‹Å±•ŸîÅ%AQXÅ•ÃÅ’Õïê∞ÅÖπêÅ—°îÅ±Ö’πç†(ÄÄººÅç°Öππï∞Å•ÃÅÕ—Ö±îÅ—°îÅµΩµïπ–Å—°îÅ’Õï»Å¡…ïÕÕïÃÅ’¿∏(ÄÄºº(ÄÄººÅIïçΩ…ëïêÅΩ∏ÅA1e	,∞ÅπΩ–ÅΩ∏Å—’πîËÅÑÅëïÖêÅÕ—…ïÖ¥Åµ’Õ–ÅπïŸï»Å…ï¡±ÖçîÅ—°î(ÄÄººÅ±ÖÕ–Å›Ω…≠•πúÅç°Öππï∞∞ÅâïçÖ’ÕîÅ—°îÅÕ—Ö…—’¿ÅôïÖ—’…îÅ…îµ—’πïÃÅ—°•ÃÅ’πÖ——ïπëïê(ÄÄººÅΩ∏ÅïŸï…‰ÅçΩ±êÅâΩΩ–∏(ÄÄººÄÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙÙ((ÄÅQ•µï»¸Å}±ÖÕ—1•Ÿï°Öππï±Q•µï»Ï(ÄÅM—…•πú¸Å}±ÖÕ—1•Ÿï°Öππï±…µïëU…∞Ï((ÄÄºººÅΩµµ•–µΩ∏µÕï——±îËÅÑÅç°Öππï∞ÅçΩ’π—ÃÅΩπçîÅ•–Å°ÖÃÅâïï∏Ä©¡±ÖÂ•πú®ÅôΩ»(ÄÄºººÅm}±ÖÕ—1•Ÿï°Öππï±Mï——±ït∏ÅiÖ¡¡•πúÅ—°…Ω’ù†Å—›ïπ—‰Åç°Öππï±ÃÅÖ…µÃÅÖπê(ÄÄºººÅÕ’¡ï…ÕïëïÃÅΩπîÅ—•µï»Å…Ö—°ï»Å—°Ö∏Å›…•—•πúÅ—›ïπ—‰Å—•µïÃ∞ÅÖπêÅ—°îÅçΩµµ•–(ÄÄºººÅ±ÖπëÃÅ›°•±îÅ—°îÅÖ¡¿Å•ÃÅÖ±•ŸîÆù◊üäwùPÅÖ∏ÅÖâ…’¡–ÅôΩ…çîµÕ—Ω¿Å…’πÃÅπºÅ±•ôïçÂç±î(ÄÄºººÅçÖ±±âÖç¨∞ÅÕºÅÑÅô±’Õ†µΩ∏µë•Õ¡ΩÕîÅÖ±ΩπîÅ›Ω’±êÅ±ΩÕîÅ•–∏(ÄÅÕ—Ö—•åÅçΩπÕ–Å’…Ö—•Ω∏Å}±ÖÕ—1•Ÿï°Öππï±Mï——±îÄÙÅ’…Ö—•Ω∏°ÕïçΩπëÃËÄƒ§Ï((ÄÅŸΩ•êÅ}πΩ—ï1•Ÿï°Öππï±A±ÖÂ•πú†§ÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞ÅÒÄÖç°Öππï∞π•Õ1•Ÿî§Å…ï—’…∏Ï(ÄÄÄÄººÅ±…ïÖë‰ÅçΩ’π—•πúÅëΩ›∏ÅôΩ»Å—°•ÃÅŸï…‰Åç°Öππï∞Æù◊üäwùPÅÑÅ¡Ö’ÕîΩ…ïÕ’µîÅΩ»ÅÑ(ÄÄÄÄººÅ…îµïµ•——ïêÅ¡±ÖÂ•πúÅïŸïπ–Åµ’Õ–ÅπΩ–Å…ïÕ—Ö…–Å—°îÅÕï——±îÅ›•πëΩ‹∏(ÄÄÄÅ•òÄ°}±ÖÕ—1•Ÿï°Öππï±…µïëU…∞ÄÙÙÅç°Öππï∞π’…∞Äòò(ÄÄÄÄÄÄÄÄ°}±ÖÕ—1•Ÿï°Öππï±Q•µï»¸π•Õç—•ŸîÄ¸¸ÅôÖ±Õî§§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅ}±ÖÕ—1•Ÿï°Öππï±Q•µï»¸πçÖπçï∞†§Ï(ÄÄÄÅ}±ÖÕ—1•Ÿï°Öππï±…µïëU…∞ÄÙÅç°Öππï∞π’…∞Ï(ÄÄÄÅ}±ÖÕ—1•Ÿï°Öππï±Q•µï»ÄÙÅQ•µï»°}±ÖÕ—1•Ÿï°Öππï±Mï——±î∞Ä†§ÅÏ(ÄÄÄÄÄÄººÅIîµ…ïÖêÅ…Ö—°ï»Å—°Ö∏Åç±ΩÕ•πúÅΩŸï»ËÅ—°îÅ’Õï»ÅµÖ‰Å°ÖŸîÅÈÖ¡¡ïêÅΩ∏Åë’…•πú(ÄÄÄÄÄÄººÅ—°îÅÕï——±îÅ›•πëΩ‹∞ÅÖπêÅ—°îÅç°Öππï∞Å—°Ö–ÅÕï——±ïêÅ•ÃÅ—°îÅΩπîÅ—°Ö–ÅçΩ’π—Ã∏(ÄÄÄÄÄÅô•πÖ∞ÅÕï——±ïêÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÄÄÅ•òÄ°Õï——±ïêÄÙÙÅπ’±∞ÅÒÄÖÕï——±ïêπ•Õ1•ŸîÅÒÅÕï——±ïêπ’…∞ÄÑÙÅç°Öππï∞π’…∞§ÅÏ(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ†Ö}•ÕA±ÖÂ•πú§Å…ï—’…∏Ï(ÄÄÄÄÄÅ’πÖ›Ö•—ïê†(ÄÄÄÄÄÄÄÅM—Ω…ÖùïMï…Ÿ•çîπÕï—%¡—Ÿ1ÖÕ—1•Ÿï°Öππï∞†(ÄÄÄÄÄÄÄÄÄÅÕï——±ïêπ’…∞∞(ÄÄÄÄÄÄÄÄÄÅπÖµîËÅÕï——±ïêππÖµî∞(ÄÄÄÄÄÄÄÄÄÄººÅ=…•ù•∏Å¡…ΩŸ•ëï»∞Å…ïÕΩ±ŸïêÅ—°îÅÕÖµîÅ›Ö‰Å—°îÅçÖ—ç°’¿Å¡Ö—†ÅëΩïÃÆù◊üäwùP(ÄÄÄÄÄÄÄÄÄÄººÅÅ}Ω…•ù•πA±ÖÂ±•Õ—%ëΩ…ÄÅ±•ŸïÃÅΩ∏Å—°îÅ%AQXÅ¡ÖùîÅÖπêÅ•ÃÅπΩ–Å…ïÖç°Öâ±î(ÄÄÄÄÄÄÄÄÄÄººÅô…Ω¥Å°ï…î∏(ÄÄÄÄÄÄÄÄÄÅ¡±ÖÂ±•Õ—%êË(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕï——±ïêπÖ——…•â’—ïÕlùÕΩ’…çï}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}•¡—Ÿ’•ëïΩπ—ï·—=Ÿï……•ëî¸πÕΩ’…çï%êÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ›•ëùï–π•¡—ŸMΩ’…çï%ê∞(ÄÄÄÄÄÄÄÄÄÅç°Öππï±9’µâï»ËÅÕï——±ïêπç°Öππï±9’µâï»∞(ÄÄÄÄÄÄÄÄÄÅù…Ω’¿ËÅÕï——±ïêπù…Ω’¿∞(ÄÄÄÄÄÄÄÄÄÅ±ΩùΩU…∞ËÅÕï——±ïêπ±ΩùΩU…∞∞(ÄÄÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅÕï——±ïêπ°——¡!ïÖëï…Ãπ•Õµ¡—‰Ä¸Åπ’±∞ÄËÅÕï——±ïêπ°——¡!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÄºººÅ9ï·–ΩA…ïŸ•Ω’ÃÄ°ÖπêÅïπêµΩòµï¡•ÕΩëîÅÖ’—ºµÖëŸÖπçî§ÅÖ…îÅÕçΩ¡ïêÅ—ºÅÖ∏Åa—…ïÖ¥(ÄÄºººÅMI%LÅï¡•ÕΩëîÅ±•Õ–ãßuÁ‚ùÁPÅ9=PÅïŸï…‰ÅπΩ∏µ±•ŸîÅ%AQXÅ•—ï¥∏ÅÅ¡±Ö•∏Å5ΩŸ•ïÃµù…•ê(ÄÄºººÅ¡±Ö‰ÅÖ±ÕºÅ¡ÖÕÕïÃÅ•¡—Ÿ°Öππï±Ã∞ÅÖπêÅÖëŸÖπç•πúÅ—ºÅ—°îÅπï·–Å’π…ï±Ö—ïêÅµΩŸ•î(ÄÄºººÄ°Ω»ÅÕ°Ω›•πúÅ9ï·–ΩA…ïÿÅΩ∏Å•–§Å›Ω’±êÅâîÅÑÅ…ïù…ïÕÕ•Ω∏ÏÅ—°ΩÕîÅ≠ïï¿Å—°îÅç°Öππï∞(ÄÄºººÅÕ°ïï–ÅΩπ±‰∞Åï·Öç—±‰ÅÖÃÅâïôΩ…î∏Åm}•Õ%¡—ŸMï…•ïÕΩπ—ï·—tÅùÖ—ïÃÅΩ∏Å—°î(ÄÄºººÅÕï…•ïÕ}•êÅ—°îÅ±Ö’πç°ï»ÅÕ—Öµ¡ÃÅΩπ—ºÅï¡•ÕΩëîÅç°Öππï±Ã∏(ÄÅâΩΩ∞Åùï–Å}°ÖÕ%¡—Ÿ9ï·–ÄÙ¯(ÄÄÄÄÄÅ}•Õ%¡—ŸMï…•ïÕΩπ—ï·–Äòò(ÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¨ÄƒÄÄ°}ïôôïç—•Ÿï%¡—Ÿ°Öππï±Ã¸π±ïπù—†Ä¸¸Ä¿§Ï((ÄÅâΩΩ∞Åùï–Å}°ÖÕ%¡—ŸA…ïŸ•Ω’ÃÄÙ¯(ÄÄÄÄÄÅ}•Õ%¡—ŸMï…•ïÕΩπ—ï·–ÄòòÅ}ç’……ïπ—%¡—Ÿ%πëï‡Ä¥ÄƒÄ¯ÙÄ¿Ï((ÄÄºººÅQ…’îÅΩπ±‰ÅôΩ»ÅÖ∏Åa—…ïÖ¥ÅMI%LÅï¡•ÕΩëîãßuÁ‚ùÁPÅ—°îÅ±Ö’πç°ï»ÅÕ—Öµ¡ÃÅÅÕï…•ïÕ}•ëÄ(ÄÄºººÄ†¨ÅÅÕï…•ïÕ}¡±ÖÂ±•Õ—}•ëÄ§Å•π—ºÅ—°îÅç°Öππï∞ùÃÅÖ——…•â’—ïÃ∏Å’ë•ºµ±Öπù’Öùî(ÄÄºººÅµïµΩ…‰Å•ÃÅÕçΩ¡ïêÅ—ºÅ—°•ÃËÅÑÅ¡±Ö•∏ÅY=ÄºÅçÖ—ç°’¿ÅÕ•πù±îÅ•—ï¥Ä°πΩ∏µ±•ŸîÅâ’–(ÄÄºººÅπΩ–ÅÑÅÕï…•ïÃ§Åùï—ÃÅ—°îÅπΩ…µÖ∞ÅëïôÖ’±–µ±Öπù’ÖùîÅ°Öπë±•πú∞ÅπΩ–Å¡ï»µÕï…•ïÃ(ÄÄºººÅçÖ……‰µΩŸï»∏(ÄÅâΩΩ∞Åùï–Å}•Õ%¡—ŸMï…•ïÕΩπ—ï·–ÅÏ(ÄÄÄÅô•πÖ∞Åç†ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç†ÄÙÙÅπ’±∞ÅÒÅç†π•Õ1•Ÿî§Å…ï—’…∏ÅôÖ±ÕîÏ(ÄÄÄÅ…ï—’…∏Ä°ç†πÖ——…•â’—ïÕlùÕï…•ïÕ}•êùtÄ¸¸Äúú§π•Õ9Ω—µ¡—‰Ï(ÄÅÙ((ÄÄºººÅMïÕÕ•Ω∏µÕçΩ¡ïêÅÖ’ë•ºÅ±Öπù’ÖùîÅ—°îÅ’Õï»Å¡•ç≠ïêÅ›°•±îÅ•∏Å—°•ÃÅ%AQXÅÕï…•ïÃ(ÄÄºººÄ°çÖ……•ïÃÅÖç…ΩÕÃÅï¡•ÕΩëîÅÕ›•—ç°ïÃÅ•∏Å—°•ÃÅÕ•——•πú§∏ÅAï…Õ•Õ—ïêÅ¡ï»µÕï…•ïÃ(ÄÄºººÅ—ΩºãßuÁ‚ùÁPÅÕïîÅmM—Ω…ÖùïMï…Ÿ•çîπÕï—%¡—ŸMï…•ïÕ’ë•Ω1Öπù’Öùït∏(ÄÅM—…•πú¸Å}¡…ïôï……ïë%¡—Ÿ’ë•Ω1Öπù’ÖùîÏ((ÄÄºººÅAï»µÕï…•ïÃÅ≠ï‰ÅôΩ»Å…ïµïµâï…•πúÅ—°îÅÖ’ë•ºÅ±Öπù’ÖùîãßuÁ‚ùÁPÅÄÒ¡±ÖÂ±•Õ—%ê¯ËËÒ•ê˘Ä∞(ÄÄºººÅ—°îÅM5Å•ëïπ—•—‰ÅΩπ—•π’îÅ]Ö—ç°•πúÅ≠ïÂÃÅâ‰∞ÅÕºÅ—›ºÅÕï…•ïÃÅ—°Ö–Åµï…ï±‰(ÄÄºººÅÕ°Ö…îÅÑÅë•Õ¡±Ö‰ÅπÖµîÅπïŸï»ÅçΩ±±•ëî∏Å9’±∞Å’π±ïÕÃÅ—°•ÃÅ•ÃÅÑÅÕï…•ïÃÅï¡•ÕΩëî∏(ÄÅM—…•πú¸Å}•¡—ŸMï…•ïÕ’ë•Ω-ï‰†§ÅÏ(ÄÄÄÅô•πÖ∞Åç†ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç†ÄÙÙÅπ’±∞ÅÒÅç†π•Õ1•Ÿî§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞ÅÕ•êÄÙÅç†πÖ——…•â’—ïÕlùÕï…•ïÕ}•êùtÏ(ÄÄÄÅ•òÄ°Õ•êÄÙÙÅπ’±∞ÅÒÅÕ•êπ•Õµ¡—‰§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞Å¡•êÄÙÅç†πÖ——…•â’—ïÕlùÕï…•ïÕ}¡±ÖÂ±•Õ—}•êùtÄ¸¸ÄúúÏ(ÄÄÄÅ…ï—’…∏Äúë¡•êËËëÕ•êúÏ(ÄÅÙ((ÄÄºººÅIïµïµâï»Å—°îÅÖ’ë•ºÅ±Öπù’ÖùîÅ—°îÅ’Õï»Å©’Õ–Åç°ΩÕîÅôΩ»Å—°îÅç’……ïπ–Å%AQX(ÄÄºººÅÕï…•ïÃÅï¡•ÕΩëî∞ÅÕºÅ±Ö—ï»Åï¡•ÕΩëïÃÅÖπêÅô’—’…îÅÕïÕÕ•ΩπÃÅëïôÖ’±–Å—ºÅ•–∏(ÄÄºººÅ9ºµΩ¿ÅôΩ»ÅπΩ∏µ%AQXÄºÅ±•ŸîÄºÅπΩ∏µÕï…•ïÃÅçΩπ—ïπ–∏(ÄÅŸΩ•êÅ}çÖ¡—’…ï%¡—Ÿ’ë•Ω1Öπù’Öùî°M—…•πúÅÖ’ë•Ω%ê§ÅÏ(ÄÄÄÅ•òÄ†Ö}•Õ%¡—ŸMï…•ïÕΩπ—ï·–§Å…ï—’…∏Ï(ÄÄÄÅM—…•πú¸Å±ÖπúÏ(ÄÄÄÅôΩ»Ä°ô•πÖ∞Å–Å•∏Å}¡±ÖÂï»πÕ—Ö—îπ—…Öç≠ÃπÖ’ë•º§ÅÏ(ÄÄÄÄÄÅ•òÄ°–π•êÄÙÙÅÖ’ë•Ω%ê§ÅÏ(ÄÄÄÄÄÄÄÅ±ÖπúÄÙÅ–π±Öπù’ÖùîÏ(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÅ•òÄ°±ÖπúÄÙÙÅπ’±∞ÅÒÅ±Öπúπ•Õµ¡—‰ÅÒÅ±ÖπúÄÙÙÄùÖ’—ºúÅÒÅ±ÖπúÄÙÙÄù’πêú§Å…ï—’…∏Ï(ÄÄÄÄººÅΩπQ…Öç≠°ÖπùïêÅÖ±ÕºÅô•…ïÃÅΩ∏ÅÕ’â—•—±îµΩπ±‰Åç°ÖπùïÃÅÖπêÅÖô—ï»ÅΩ’»ÅΩ›∏(ÄÄÄÄººÅÖ’—ºµÖ¡¡±‰ãßuÁ‚ùÁPÅÕ≠•¿Å—°îÅ…ïë’πëÖπ–Å›…•—îÅ›°ï∏Å—°îÅ±Öπù’ÖùîÅ•ÃÅ’πç°Öπùïê∏(ÄÄÄÅ•òÄ°±ÖπúÄÙÙÅ}¡…ïôï……ïë%¡—Ÿ’ë•Ω1Öπù’Öùî§Å…ï—’…∏Ï(ÄÄÄÅ}¡…ïôï……ïë%¡—Ÿ’ë•Ω1Öπù’ÖùîÄÙÅ±ÖπúÏ(ÄÄÄÅô•πÖ∞Å≠ï‰ÄÙÅ}•¡—ŸMï…•ïÕ’ë•Ω-ï‰†§Ï(ÄÄÄÅ•òÄ°≠ï‰ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°M—Ω…ÖùïMï…Ÿ•çîπÕï—%¡—ŸMï…•ïÕ’ë•Ω1Öπù’Öùî°≠ï‰∞Å±Öπú§§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅIîµÖ¡¡±‰Å—°îÅ¡…ïôï……ïêÅÖ’ë•ºÅ—…Öç¨ÅôΩ»ÅÖ∏Å%AQXÅÕï…•ïÃÅï¡•ÕΩëîÅÖô—ï»ÅÑ(ÄÄºººÅÕΩ’…çîÅç°ÖπùîËÅ—°•ÃÅÕ•——•πúùÃÅ¡•ç¨ÇÈ›y¯ßyÿÅ—°•ÃÅÕï…•ïÃúÅÕ—Ω…ïêÅ¡•ç¨ÇÈ›y¯ßyÿÅ—°î(ÄÄºººÅù±ΩâÖ∞ÅëïôÖ’±–ÅÖ’ë•ºÅ±Öπù’Öùî∏Å5Ö—ç°ïÃÅâ‰Å±Öπù’ÖùîÄ°…Ωâ’Õ–ÅÖç…ΩÕÃ(ÄÄºººÅï¡•ÕΩëïÃÅ›°ΩÕîÅ—…Öç¨ÅΩ…ë•πÖ±ÃÅë•ôôï»§∏Åm—•ç≠ï—tÅ•ÃÅ—°îÅÕ›•—ç†Åùïπï…Ö—•Ω∏(ÄÄºººÅ—°•ÃÅÖ¡¡±‰Åâï±ΩπùÃÅ—ºÆù◊üäwùPÅÑÅπï›ï»ÅÕ›•—ç†Ä°Ω»Å’πµΩ’π–§ÅÖâÖπëΩπÃÅ•–∞ÅÕºÅ•–(ÄÄºººÅçÖ∏ù–ÅÕï–ÅÖ’ë•ºÅΩ∏Å—°îÅ›…ΩπúÅï¡•ÕΩëî∏ÅQ°îÅ¡…ïôï……ïêÅ±Öπù’ÖùîÅ•ÃÅ…ïÖê(ÄÄºººÅQHÅ—°îÅ—…Öç¨Å›Ö•–∞ÅÕºÅÑÅµÖπ’Ö∞Å¡•ç¨ÅµÖëîÅë’…•πúÅ—°îÅ›Ö•–Å›•πÃ∏(ÄÅ’—’…îÒŸΩ•ê¯Å}Ö¡¡±Â%¡—Ÿ’ë•ΩA…ïôï…ïπçî°•π–Å—•ç≠ï–§ÅÖÕÂπåÅÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄººÅQ…Öç≠ÃÅÖ…ï∏ù–Åïπ’µï…Ö—ïêÅ—°îÅ•πÕ—Öπ–ÅΩ¡ï∏†§Å…ï—’…πÃÇÈ›y¯ßy–Å›Ö•–Åâ…•ïô±‰∞(ÄÄÄÄÄÄººÅâÖ•±•πúÅ•òÅÑÅπï›ï»ÅÕ›•—ç†ÅÕ’¡ï…ÕïëïÃÅ—°•ÃÅΩπî∏(ÄÄÄÄÄÅôΩ»Ä°ŸÖ»Å§ÄÙÄ¿ÏÅ§ÄÄ»¿ÏÅ§¨¨§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÅ•òÄ°}¡±ÖÂï»πÕ—Ö—îπ—…Öç≠ÃπÖ’ë•ºπ±ïπù—†Ä¯ÙÄ»§Åâ…ïÖ¨Ï(ÄÄÄÄÄÄÄÅÖ›Ö•–Å’—’…îπëï±ÖÂïê°çΩπÕ–Å’…Ö—•Ω∏°µ•±±•ÕïçΩπëÃËÄƒ¿¿§§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÅô•πÖ∞Å—…Öç≠ÃÄÙÅ}¡±ÖÂï»πÕ—Ö—îπ—…Öç≠ÃÏ(ÄÄÄÄÄÅ•òÄ°—…Öç≠ÃπÖ’ë•ºπ±ïπù—†ÄÄ»§Å…ï—’…∏ÏÄººÅπΩ—°•πúÅ—ºÅÕ›•—ç†Å—º((ÄÄÄÄÄÄººÅIïÕΩ±ŸîÅ—°îÅ—Ö…ùï–Å±Öπù’ÖùîÅπΩ‹Ä°πΩ–ÅâïôΩ…îÅ—°îÅ›Ö•–§ËÅÑÅµÖπ’Ö∞Å¡•ç¨(ÄÄÄÄÄÄººÅë’…•πúÅ—°îÅ›Ö•–Å’¡ëÖ—ïêÅ}¡…ïôï……ïë%¡—Ÿ’ë•Ω1Öπù’Öùî∞ÅÖπêÅ•–ÅÕ°Ω’±êÅ›•∏∏(ÄÄÄÄÄÅM—…•πú¸Å±ÖπúÄÙÅ}¡…ïôï……ïë%¡—Ÿ’ë•Ω1Öπù’ÖùîÏ(ÄÄÄÄÄÅ•òÄ°±ÖπúÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅô•πÖ∞Å≠ï‰ÄÙÅ}•¡—ŸMï…•ïÕ’ë•Ω-ï‰†§Ï(ÄÄÄÄÄÄÄÅ•òÄ°≠ï‰ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ±ÖπúÄÙÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπùï—%¡—ŸMï…•ïÕ’ë•Ω1Öπù’Öùî°≠ï‰§Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ±ÖπúÄ¸¸ÙÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπùï—ïôÖ’±—’ë•Ω1Öπù’Öùî†§Ï(ÄÄÄÄÄÅ•òÄ°±ÖπúÄÙÙÅπ’±∞ÅÒÄÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï((ÄÄÄÄÄÅµ¨π’ë•ΩQ…Öç¨¸ÅµÖ—ç†Ï(ÄÄÄÄÄÅôΩ»Ä°ô•πÖ∞Å–Å•∏Å—…Öç≠ÃπÖ’ë•º§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°1Öπù’Öùï5Ö¡¡ï»πµÖ—ç°ïÕ1Öπù’Öùî°±Öπú∞Å–π±Öπù’Öùî§ÅÒ(ÄÄÄÄÄÄÄÄÄÄÄÅ1Öπù’Öùï5Ö¡¡ï»πµÖ—ç°ïÕ1Öπù’Öùî°±Öπú∞Å–π—•—±î§§ÅÏ(ÄÄÄÄÄÄÄÄÄÅµÖ—ç†ÄÙÅ–Ï(ÄÄÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ°µÖ—ç†ÄÑÙÅπ’±∞§ÅÖ›Ö•–Å}¡±ÖÂï»πÕï—’ë•ΩQ…Öç¨°µÖ—ç†§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÏ(ÄÄÄÄÄÄººÅ9Ω∏µç…•—•çÖ∞ÇÈ›y¯ßy–ÅÖ’ë•ºÅ¡…ïôï…ïπçîÅ•ÃÅâïÕ–µïôôΩ…–∏(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅ]…•—îÅΩπîÅΩ∏µëïµÖπêÅ%AQXÅ•—ï¥Å—ºÅ—°îÅ›Ö—ç†Å°•Õ—Ω…‰∞ÅçÖ……Â•πúÅ›°Ö—ïŸï»(ÄÄºººÅÕï…•ïÃÅ•ëïπ—•—‰Å—°îÅç°Öππï∞Å›ÖÃÅâ’•±–Å›•—†Ä°ÕïîÅÅΩ¡ïπa—…ïÖµ¡•ÕΩëïÄ∞(ÄÄºººÅ›°•ç†ÅÕ—Öµ¡ÃÅ—°ïÕîÅÖ——…•â’—ïÃÅΩ∏ÅïŸï…‰Åï¡•ÕΩëîÅΩòÅÑÅÕï…•ïÃ§∏ÅQ°î(ÄÄºººÅ¡±ÖÂ±•Õ–Å•êÅ°ÖÃÅ—ºÅµÖ—ç†Å—°îÅΩπîÅ—°îÅÕï…•ïÃÅ¡ÖùîÅ…ïçΩ…ëÃÅΩ»Å—°îÅÕ°ï±ò(ÄÄºººÅ›Ω’±êÅù…Ω’¿Å—°îÅÕÖµîÅÕï…•ïÃÅ’πëï»Å—›ºÅ≠ïÂÃ∏(ÄÅ’—’…îÒŸΩ•ê¯Å}…ïçΩ…ë%¡—Ÿ]Ö—ç°Ω…°Öππï∞°%¡—Ÿ°Öππï∞Åç°Öππï∞§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞ÅÖ——…ÃÄÙÅç°Öππï∞πÖ——…•â’—ïÃÏ(ÄÄÄÅô•πÖ∞ÅÕï…•ïÕ%êÄÙÅÖ——…ÕlùÕï…•ïÕ}•êùtÏ(ÄÄÄÅô•πÖ∞Å°ÖÕ9ï·–ÄÙÅÖ——…Õlù°ÖÕ}πï·—}ï¡•ÕΩëîùtÏ(ÄÄÄÅô•πÖ∞Å°ïÖëï…ÃÄÙÅç°Öππï∞π°——¡!ïÖëï…ÃÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπ…ïçΩ…ë%¡—Ÿ]Ö—ç††(ÄÄÄÄÄÄÄÅç°Öππï∞π’…∞∞(ÄÄÄÄÄÄÄÅç°Öππï±9ÖµîËÅç°Öππï∞ππÖµî∞(ÄÄÄÄÄÄÄÅ±ΩùΩU…∞ËÅç°Öππï∞π±ΩùΩU…∞∞(ÄÄÄÄÄÄÄÅù…Ω’¿ËÅç°Öππï∞πù…Ω’¿∞(ÄÄÄÄÄÄÄÅ¡±ÖÂ±•Õ—%êË(ÄÄÄÄÄÄÄÄÄÄÄÅÖ——…ÕlùÕï…•ïÕ}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÅÖ——…ÕlùÕΩ’…çï}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÄÄÄÄÅ›•ëùï–π•¡—ŸMΩ’…çï%ê∞(ÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅ°ïÖëï…Ãπ•Õµ¡—‰Ä¸Åπ’±∞ÄËÅ°ïÖëï…Ã∞(ÄÄÄÄÄÄÄÅÕï…•ïÕ%êËÄ°Õï…•ïÕ%êÄÑÙÅπ’±∞ÄòòÅÕï…•ïÕ%êπ•Õ9Ω—µ¡—‰§Ä¸ÅÕï…•ïÕ%êÄËÅπ’±∞∞(ÄÄÄÄÄÄÄÅÕï…•ïÕ9ÖµîËÅÖ——…ÕlùÕï…•ïÕ}πÖµîùtÄ¸¸Åç°Öππï∞πù…Ω’¿∞(ÄÄÄÄÄÄÄÅÕïÖÕΩ∏ËÅ•π–π—…ÂAÖ…Õî°Ö——…ÕlùÕïÖÕΩ∏ùtÄ¸¸Äúú§∞(ÄÄÄÄÄÄÄÅï¡•ÕΩëîËÅ•π–π—…ÂAÖ…Õî°Ö——…Õlùï¡•ÕΩëîùtÄ¸¸Äúú§∞(ÄÄÄÄÄÄÄÅ°ÖÕ9ï·—¡•ÕΩëîËÅ°ÖÕ9ï·–ÄÙÙÅπ’±∞Ä¸Åπ’±∞ÄËÅ°ÖÕ9ï·–ÄÙÙÄù—…’îú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅ%AQXÅ›Ö—ç†Å…ïù•Õ—…Ö—•Ω∏ÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅQ°îÅëïÕ≠—Ω¿ÅçÖ¡—’…î∞Å›°ï∏Å•–Åâï±ΩπùÃÅ—ºÅ—°îÅUII9Q1dÅA1e%9Åç°Öππï∞ãßuÁ‚ùÁP(ÄÄºººÅÖÕ≠ïêÅΩòÅ—°îÅMIY%∞ÅπΩ–Å—°•ÃÅÕç…ïï∏ùÃÅΩ›∏Åô•ï±ê∞ÅÕºÅÑÅçÖ¡—’…îÅ—°î(ÄÄºººÅëïÕ≠—Ω¿ÅM!U1HÅÕ—Ö…—ïêÅÕ°Ω›ÃÅ’¿ÅΩ∏Ä°ÖπêÅÕ—Ω¡ÃÅô…Ω¥§Å—°îÅIïçΩ…êÅâ’——Ω∏(ÄÄºººÅ—ΩºÅ›°ï∏Å•—ÃÅç°Öππï∞Å•ÃÅâï•πúÅ›Ö—ç°ïê∏(ÄÅïÕ≠—Ω¡IïçΩ…ë•πùÖ¡—’…î¸Å}ëïÕ≠—Ω¡Ö¡—’…ïΩ…’……ïπ–†§ÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞Å¡±ÖÂ•πúÄÙÅ}¡±ÖÂ•πù1•ŸïU…∞°ç°Öππï∞§Ï(ÄÄÄÅ•òÄ°¡±ÖÂ•πúÄÙÙÅπ’±∞§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞ÅÕï…Ÿ•çîÄÙÅïÕ≠—Ω¡IïçΩ…ë•πùMï…Ÿ•çîπ•πÕ—ÖπçîÏ(ÄÄÄÅô•πÖ∞Åë•…ïç–ÄÙÅÕï…Ÿ•çîπçÖ¡—’…ïΩ…U…∞°¡±ÖÂ•πú§Ï(ÄÄÄÅ•òÄ°ë•…ïç–ÄÑÙÅπ’±∞§Å…ï—’…∏Åë•…ïç–Ï(ÄÄÄÅô•πÖ∞Å—›•∏ÄÙÅ1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπ·—…ïÖµQÕQ›•∏°¡±ÖÂ•πú§Ï(ÄÄÄÅ…ï—’…∏Å—›•∏ÄÑÙÅπ’±∞Ä¸ÅÕï…Ÿ•çîπçÖ¡—’…ïΩ…U…∞°—›•∏§ÄËÅπ’±∞Ï(ÄÅÙ((ÄÅ’—’…îÒŸΩ•ê¯Å}—Ωùù±ïIïçΩ…ë•πú†§ÅÖÕÂπåÅÏ(ÄÄÄÄººÅïÕ≠—Ω¿ÅçÖ¡—’…îÅΩòÅ—°îÅç’……ïπ–Åç°Öππï∞ËÅÕ—Ω¿Å•–∏(ÄÄÄÅô•πÖ∞ÅëïÕ≠—Ω¡Ö¡—’…îÄÙÅ}ëïÕ≠—Ω¡Ö¡—’…ïΩ…’……ïπ–†§Ï(ÄÄÄÅ•òÄ°ëïÕ≠—Ω¡Ö¡—’…îÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅô•πÖ∞ÅÕÖŸïëAÖ—†ÄÙÅëïÕ≠—Ω¡Ö¡—’…îπ¡Ö—†Ï(ÄÄÄÄÄÅô•πÖ∞ÅâÂ—ïÃÄÙÅÖ›Ö•–ÅëïÕ≠—Ω¡Ö¡—’…îπÕ—Ω¿†§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄººÅQ°îÅ…ïŸ•Õ•Ω∏Å±•Õ—ïπï»Å°ÖÃÅÖ±…ïÖë‰Å…ï¡Ö•π—ïêÄ°—°îÅçÖ¡—’…îÅïπëïêÅë’…•πú(ÄÄÄÄÄÄººÅ—°Ö–ÅÖ›Ö•–§ÏÅ—°•ÃÅΩπ±‰Åù’Ö…Öπ—ïïÃÅ•–ÅôΩ»Å—°îÅ¡Ö—°Ω±Ωù•çÖ∞ÅçÖÕîÅ›°ï…î(ÄÄÄÄÄÄººÅ—°îÅπΩ—•ô•çÖ—•Ω∏Å›ÖÃÅÕ›Ö±±Ω›ïê∏(ÄÄÄÄÄÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÅâÂ—ïÃÄ¯Ä¿(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¸ÄùIïçΩ…ë•πúÅÕÖŸïêËÄëÕÖŸïëAÖ—†ú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄËÄùIïçΩ…ë•πúÅôÖ•±ïêãßuÁ‚ùÁPÅπΩ—°•πúÅ›ÖÃÅçÖ¡—’…ïêú∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÄººÅπù•πîÅçÖ¡—’…îÅΩòÅ—°îÅç’……ïπ–Åç°Öππï∞ËÅÕ—Ω¿Å•–∏Å•πÖ±•ÈÖ—•Ω∏Å•ÃÅÖÕÂπåÅ•∏(ÄÄÄÄººÅ—°îÅÕï…Ÿ•çîÏÅ•—ÃÄâMÖŸïêàÅπΩ—•ô•çÖ—•Ω∏Å•ÃÅ—°îÅçΩπô•…µÖ—•Ω∏∏(ÄÄÄÅô•πÖ∞Åïπù•πïQÖÕ¨ÄÙÅ}ïπù•πïQÖÕ≠%êÏ(ÄÄÄÅ•òÄ°ïπù•πïQÖÕ¨ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}ïπù•πïQÖÕ≠%êÄÙÅπ’±∞§Ï(ÄÄÄÄÄÅô•πÖ∞ÅΩ¨ÄÙÅÖ›Ö•–Å1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπÕ—Ω¿°ïπù•πïQÖÕ¨§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÅΩ¨(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¸ÄùIïçΩ…ë•πúÅÕ—Ω¡¡ïêÆù◊üäwùPÅÕÖŸ•πúÅ—ºÅΩ›π±ΩÖëÃΩïâ…•ô‰ΩIïçΩ…ë•πùÃú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄËÄâΩ’±ë∏ù–ÅÕ—Ω¿Å…ïçΩ…ë•πúà∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ°}•ÕIïçΩ…ë•πú§ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å}Õ—Ω¡IïçΩ…ë•πú†§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÄººÅπù•πîÅô•…Õ–ÅΩ∏Åπë…Ω•êËÅ•—ÃÅçÖ¡—’…îÅÕ’…Ÿ•ŸïÃÅÈÖ¡Ã∞Å!Ωµî∞ÅïŸï∏Å—°îÅÖ¡¿(ÄÄÄÄººÅëÂ•πú∏ÅQ°îÅ—ïîÅÕ—ÖÂÃÅÖÃÅ—°îÅôÖ±±âÖç¨Æù◊üäwùPÅÖπêÅÖÃÅ—°îÅΩπ±‰Å…ïçΩ…ëï»ÅôΩ»Å—…’î(ÄÄÄÄººÅ!1L∞Å›°•ç†Åµ¡ÿÅçÖ∏ÅçÖ¡—’…îÅâ’–Å—°îÅïπù•πîÅçÖππΩ–∏(ÄÄÄÅ•òÄ°A±Ö—ôΩ…¥π•Õπë…Ω•êÄòòÅ}ïπù•πï±Öù=∏ÄòòÅ}…ïçΩ…ë•πùM’¡¡Ω…—ïê§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÄÄÅô•πÖ∞Å…ïçΩ…ëU…∞ÄÙÅÖ›Ö•–Å}ïπù•πïIïçΩ…ëU…±Ω…’……ïπ–†§Ï(ÄÄÄÄÄÅ•òÄ°ç°Öππï∞ÄÑÙÅπ’±∞ÄòòÅ…ïçΩ…ëU…∞ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ†ÖÖ›Ö•–ÅïπÕ’…ïIïçΩ…ë•πùÖ¡Öç•—‰°çΩπ—ï·–§§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÄººÅQ°•ÃÅ¡Ö—†ÅÕ≠•¡ÃÅïπÕ’…ïπù•πïIïÖë‰Ä°Õ’¡¡Ω…–Å›ÖÃÅ¡…îµç°ïç≠ïê§∞ÅÕº(ÄÄÄÄÄÄÄÄººÅ—°îÅΩπîµ—•µîÅπΩ—•ô•çÖ—•Ω∏ÅÖÕ¨Å±•ŸïÃÅ°ï…îÅï·¡±•ç•—±‰ãßuÁ‚ùÁPÅô•…îµÖπê¥(ÄÄÄÄÄÄÄÄººÅôΩ…ùï–∞ÅÕºÅÖ∏Å’πÖπÕ›ï…ïêÅë•Ö±ΩúÅçÖ∏ù–Åëï±Ö‰Å—°îÅçÖ¡—’…î∏(ÄÄÄÄÄÄÄÅ’πÖ›Ö•—ïê°1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπïπÕ’…ï9Ω—•ô•çÖ—•ΩπAï…µ•ÕÕ•Ω∏†§§Ï(ÄÄÄÄÄÄÄÅô•πÖ∞Å…ïÕΩ’…çîÄÙÅÖ›Ö•–Å}ç’……ïπ—IïçΩ…ë•πùIïÕΩ’…çî†§Ï(ÄÄÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÅô•πÖ∞Å…ïÕ’±–ÄÙÅÖ›Ö•–Å1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπÕ—Ö…–†(ÄÄÄÄÄÄÄÄÄÅ’…∞ËÅ…ïçΩ…ëU…∞∞(ÄÄÄÄÄÄÄÄÄÅô•±ï9ÖµîËÅ}…ïçΩ…ë•πù•±ï9Öµî°ç°Öππï∞ππÖµî§∞(ÄÄÄÄÄÄÄÄÄÅç°Öππï±9ÖµîËÅç°Öππï∞ππÖµî∞(ÄÄÄÄÄÄÄÄÄÅ°ïÖëï…ÃËÅç°Öππï∞π¡±ÖÂâÖç≠!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄÄÅçΩππïç—•ΩπIïÕΩ’…çï%êËÅ…ïÕΩ’…çî¸π•ê∞(ÄÄÄÄÄÄÄÄÄÅ…ïÕΩ’…çï’—°Ω…•ÈÖ—•ΩπIïŸ•Õ•Ω∏ËÅ…ïÕΩ’…çî¸π…ïŸ•Õ•Ω∏∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÅ•òÄ°…ïÕ’±–πΩ¨§ÅÏ(ÄÄÄÄÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}ïπù•πïQÖÕ≠%êÄÙÅ…ïÕ’±–π•ê§Ï(ÄÄÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄùIïçΩ…ë•πúÅ•∏ÅâÖç≠ù…Ω’πêÆù◊üäwùPÅ≠ïï¡ÃÅùΩ•πúÅ•òÅÂΩ‘ÅÈÖ¿ÅΩ»Å±ïÖŸî∏Äú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄùM—Ω¿Åô…Ω¥Å°ï…îÅΩ»Å—°îÅπΩ—•ô•çÖ—•Ω∏∏ú∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅÙÅï±ÕîÅ•òÄ°…ïÕ’±–πï……Ω…ΩëîÄÙÙÄù…ïçΩ…ë•πù}±•µ•—}…ïÖç°ïêú§ÅÏ(ÄÄÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄùIïçΩ…ë•πúÅ±•µ•–Å…ïÖç°ïêÆù◊üäwùPÅô…ïîÅÑÅÕ±Ω–ÅΩ»Å…Ö•ÕîÅ—°îÅ±•µ•–Äú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄù•∏Å%AQXÅÕï——•πùÃú∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅÙÅï±ÕîÅ•òÄ†ÖA…Ωô•±ïI’π—•µîπ•ÕA…Ωô•±ïΩµµ•——ïêÄòò(ÄÄÄÄÄÄÄÄÄÄÄÄ°…ïÕ’±–πï……Ω…ΩëîÄÙÙÄùïπù•πï}’πÕ’¡¡Ω…—ïêúÅÒ(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅ…ïÕ’±–πï……Ω…ΩëîÄÙÙÄùôùÕ}πΩ—}Ö±±Ω›ïêúÅÒ(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅ…ïÕ’±–πï……Ω…ΩëîÄÙÙÄùµ•ÕÕ•πù}¡±’ù•∏ú§§ÅÏ(ÄÄÄÄÄÄÄÄÄÄººÅπù•πîÅ’π…ïÖç°Öâ±îËÅ—°îÅ—ïîÅÕ—•±∞Å›Ω…≠Ã∞Å›•—†Å•—ÃÅÕïµÖπ—•çÃ∏(ÄÄÄÄÄÄÄÄÄÅÖ›Ö•–Å}Õ—Ö…—IïçΩ…ë•πú†§Ï(ÄÄÄÄÄÄÄÅÙÅï±ÕîÅÏ(ÄÄÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»°çΩπ—ïπ–ËÅQï·–†âΩ’±ë∏ù–ÅÕ—Ö…–Å…ïçΩ…ë•πúà§§∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÄººÅ…ïçΩ…ëU…∞ÄÙÙÅπ’±∞ËÅ—…’îÅÕïùµïπ—ïêÅÕ—…ïÖ¥Ä°πºÅa—…ïÖ¥Å—›•∏§ÇÈ›y¯ßy–ÅΩπ±‰Å—°î(ÄÄÄÄÄÄººÅ—ïîÅçÖ∏ÅçÖ¡—’…îÅ›°Ö–Åµ¡ÿÅ•ÃÅëïµ’·•πú∏ÅÖ±∞Å—°…Ω’ù†∏(ÄÄÄÄÄÅ•òÄ°A…Ωô•±ïI’π—•µîπ•ÕA…Ωô•±ïΩµµ•——ïê§ÅÏ(ÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†ùQ°•ÃÅÕ—…ïÖ¥ÅçÖππΩ–ÅâîÅ…ïçΩ…ëïêÅÕÖôï±‰ú§∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÄººÅïÕ≠—Ω¿ËÅ—°îÅ…Ö‹Å!QQ@ÅçÖ¡—’…îÅ•ÃÅ—°îÅ=91dÅ…ïçΩ…ëï»Å—°Ö–Å›Ω…≠ÃãßuÁ‚ùÁPÅ—°îÅµ¡ÿ(ÄÄÄÄººÅ—ïîÅ•ÃÅëïÖêÅΩ∏Åµïë•Ö}≠•–ùÃÅÕ—Ωç¨Å±•âÃÄ°πºÅµ’·ï…ÃÅ•∏Å•—ÃÅµ¡ïú§∏Å9ïŸï»(ÄÄÄÄººÅôÖ±∞Å—°…Ω’ù†Å—ºÅ—°îÅ—ïîÅ°ï…îÏÅôΩ»Å’π…ïçΩ…ëÖâ±îÅÕ—…ïÖµÃÅÕÖ‰ÅÕºÅ•πÕ—ïÖê(ÄÄÄÄººÅΩòÅÕ—Ö…—•πúÅÕΩµï—°•πúÅ—°Ö–Å¡…ΩŸÖâ±‰Å›…•—ïÃÅπΩ—°•πú∏(ÄÄÄÅ•òÄ°ïÕ≠—Ω¡IïçΩ…ë•πùMï…Ÿ•çîπ•πÕ—Öπçîπ•ÕM’¡¡Ω…—ïêÄòòÅ}…ïçΩ…ë•πùM’¡¡Ω…—ïê§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÄÄÅô•πÖ∞Å…ïçΩ…ëU…∞ÄÙÅÖ›Ö•–Å}ïπù•πïIïçΩ…ëU…±Ω…’……ïπ–†§Ï(ÄÄÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÄÄÅ•òÄ°…ïçΩ…ëU…∞ÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄâQ°•ÃÅç°Öππï∞ÅçÖ∏ù–ÅâîÅ…ïçΩ…ëïêÅΩ∏ÅëïÕ≠—Ω¿Ä°!1LÅÕ—…ïÖ¥§à∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ†ÖÖ›Ö•–ÅïπÕ’…ïIïçΩ…ë•πùÖ¡Öç•—‰°çΩπ—ï·–§§Å…ï—’…∏Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄººÅIÖ‹ÅâÂ—îÅçΩ¡‰ãßuÁ‚ùÁHÅ—°îÅçÖ¡—’…îÅ%LÅÑÅ—…ÖπÕ¡Ω…–ÅÕ—…ïÖ¥ËÄπ—Ã∞ÅπΩ–Å—°î(ÄÄÄÄÄÄººÅ—ïîùÃÄπµ≠ÿ∏(ÄÄÄÄÄÅô•πÖ∞Å¡Ö—†ÄÙÅÖ›Ö•–Å}…ïçΩ…ë•πùQÖ…ùï—AÖ—†°ç°Öππï∞ππÖµî∞Åï·—ïπÕ•Ω∏ËÄù—Ãú§Ï(ÄÄÄÄÄÄººÅQ°îÅÕç…ïï∏ÅµÖ‰Å°ÖŸîÅç±ΩÕïêÅë’…•πúÅ—°Ö–ÅÖ›Ö•–∏ÅM—Ö…—•πúÅπΩ‹Å›Ω’±êÅâî(ÄÄÄÄÄÄººÅ±ïù•—•µÖ—îãßuÁ‚ùÁPÅçÖ¡—’…ïÃÅΩ’—±•ŸîÅ—°•ÃÅÕç…ïï∏Æù◊üäwùPÅâ’–Å—°îÅÕ—Ö—îÅâï±Ω‹ÅçÖ∏ù–(ÄÄÄÄÄÄººÅâîÅÕï–ÅΩ∏ÅÑÅëïÖêÅ›•ëùï–∞ÅÖπêÅ—°îÅ’Õï»ÅÖÕ≠ïêÅôΩ»Å—°•ÃÅô…Ω¥ÅÑÅÕ’…ôÖçî(ÄÄÄÄÄÄººÅ—°Ö–Å•ÃÅùΩπî∏(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄººÅ9ºÅΩπ•π•Õ°ïêËÅïπë•πùÃÅÖ…îÅÖππΩ’πçïêÅÖ¡¿µ›•ëîÅâ‰Å—°îÅ…ï¡Ω…—ï»Å•∏(ÄÄÄÄÄÄººÅµÖ•∏†§∞Å›°•ç†Å•ÃÅÕ—•±∞ÅÖ±•ŸîÅ›°ï∏Å—°•ÃÅÕç…ïï∏Å•Õ∏ù–∞ÅÖπêÅ—°îÅ…ïŸ•Õ•Ω∏(ÄÄÄÄÄÄººÅ±•Õ—ïπï»Å…ï¡Ö•π—ÃÅ—°îÅâ’——Ω∏∏ÅÅÕç…ïï∏µÕçΩ¡ïêÅçÖ±±âÖç¨Å›Ω’±êÅΩπ±‰(ÄÄÄÄÄÄººÅë’¡±•çÖ—îÅ—°îÅ—ΩÖÕ–Å›°•±îÅ—°îÅ¡±ÖÂï»Å°Ö¡¡ïπÃÅ—ºÅâîÅΩ¡ï∏∏(ÄÄÄÄÄÅô•πÖ∞Å…ïÕΩ’…çîÄÙÅÖ›Ö•–Å}ç’……ïπ—IïçΩ…ë•πùIïÕΩ’…çî†§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅô•πÖ∞ÅçÖ¡—’…îÄÙÅÖ›Ö•–ÅïÕ≠—Ω¡IïçΩ…ë•πùMï…Ÿ•çîπ•πÕ—ÖπçîπÕ—Ö…–†(ÄÄÄÄÄÄÄÅ’…∞ËÅ…ïçΩ…ëU…∞∞(ÄÄÄÄÄÄÄÅ¡Ö—†ËÅ¡Ö—†∞(ÄÄÄÄÄÄÄÅç°Öππï±9ÖµîËÅç°Öππï∞ππÖµî∞(ÄÄÄÄÄÄÄÅ°ïÖëï…ÃËÅç°Öππï∞π¡±ÖÂâÖç≠!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÅçΩππïç—•ΩπIïÕΩ’…çï%êËÅ…ïÕΩ’…çî¸π•ê∞(ÄÄÄÄÄÄÄÅ…ïÕΩ’…çï’—°Ω…•ÈÖ—•ΩπIïŸ•Õ•Ω∏ËÅ…ïÕΩ’…çî¸π…ïŸ•Õ•Ω∏∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅ•òÄ°çÖ¡—’…îÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»°çΩπ—ïπ–ËÅQï·–†âΩ’±ë∏ù–ÅÕ—Ö…–Å…ïçΩ…ë•πúà§§∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÄùIïçΩ…ë•πúÅ•∏ÅâÖç≠ù…Ω’πêÆù◊üäwùPÅ≠ïï¡ÃÅùΩ•πúÅ•òÅÂΩ‘ÅÈÖ¿ÅΩ»Å±ïÖŸî∏Äú(ÄÄÄÄÄÄÄÄÄÄÄÄùM—Ω¿Åô…Ω¥Å°ï…îÅΩ»ÅMï——•πùÃãßuÁ‚ùÁHÅIïçΩ…ë•πùÃ∏ú∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅÖ›Ö•–Å}Õ—Ö…—IïçΩ…ë•πú†§Ï(ÄÅÙ((ÄÄºººÅQ°îÅUI0ÅÖç—’Ö±±‰ÅA1e%9ÅôΩ»Åmç°Öππï±t∏Å9=PÅÅ}ç’……ïπ—M—…ïÖµU…±ÄÅôΩ»(ÄÄºººÅ¡±Ö•∏Åç°Öππï±ÃãßuÁ‚ùÁPÅ—°îÅÈÖ¿Å¡Ö—†ÅπïŸï»Å’¡ëÖ—ïÃÅ—°Ö–Åô•ï±ê∞ÅÕºÅÖô—ï»ÅÑÅÈÖ¿(ÄÄºººÅ•–ÅÕ—•±∞Å°Ω±ëÃÅ—°îÅ¡…ïŸ•Ω’ÃÅç°Öππï∞ùÃÅUI0∞ÅÖπêÅµÖ—ç°•πúÅΩ∏Å•–Å›Ω’±êÅ¡•∏(ÄÄºººÅ—°îÅIïçΩ…êÅâ’——Ω∏Ä°ÖπêÅ•—ÃÅM—Ω¿Ñ§Å—ºÅ—°îÅ›…ΩπúÅçÖ¡—’…î∏ÅQ°îÅç°Öππï∞ùÃ(ÄÄºººÅΩ›∏ÅUI0Å•ÃÅ—°îÅ•ëïπ—•—‰ÅôΩ»ÅïŸï…Â—°•πúÅï·çï¡–ÅM—…ïµ•º∞Å›°ΩÕîÅ¡±ÖÂ•πúÅUI0(ÄÄºººÅ•ÃÅ—°îÅ…ïÕΩ±ŸïêÅçÖπë•ëÖ—îÅΩπ±‰ÅÅ}ç’……ïπ—M—…ïÖµU…±ÄÅ≠πΩ›Ã∏(ÄÅM—…•πú¸Å}¡±ÖÂ•πù1•ŸïU…∞°%¡—Ÿ°Öππï∞Åç°Öππï∞§ÅÏ(ÄÄÄÅ•òÄ†Öç°Öππï∞π’…∞πÕ—Ö…—Õ]•—††ùÕ—…ïµ•ºµ—ÿËººú§§Å…ï—’…∏Åç°Öππï∞π’…∞Ï(ÄÄÄÅô•πÖ∞Å…ïÕΩ±ŸïêÄÙÅ}ç’……ïπ—M—…ïÖµU…∞Ï(ÄÄÄÅ•òÄ°…ïÕΩ±ŸïêÄÙÙÅπ’±∞ÅÒÅ…ïÕΩ±ŸïêπÕ—Ö…—Õ]•—††ùÕ—…ïµ•ºµ—ÿËººú§§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅ…ï—’…∏Å…ïÕΩ±ŸïêÏ(ÄÅÙ((ÄÄºººÅQ°îÅUI0Å—°îÅ9%9ÅÕ°Ω’±êÅçÖ¡—’…îÅôΩ»Å—°îÅç’……ïπ–Å±•ŸîÅç°Öππï∞∞ÅΩ»Åπ’±∞(ÄÄºººÅ›°ï∏ÅΩπ±‰Å—°îÅ—ïîÅçÖ∏Å…ïçΩ…êÅ•–∏Åµ¡ÿùÃÅΩ›∏ÅÅô•±îµôΩ…µÖ—ÄÅ•ÃÅù…Ω’πêÅ—…’—†(ÄÄºººÅôΩ»Å›°Ö–ùÃÅÖç—’Ö±±‰Å¡±ÖÂ•πúÄ°ï·—ïπÕ•Ω∏µ±ïÕÃÅUI1ÃÅ±•î§ÏÅ—°îÅUI0ÅÕ°Ö¡îÅ•Ã(ÄÄºººÅ—°îÅôÖ±±âÖç¨Å›°ï∏Å—°îÅ¡…ΩâîÅ•ÃÅ’πÖŸÖ•±Öâ±î∏(ÄÅ’—’…îÒM—…•πú¸¯Å}ïπù•πïIïçΩ…ëU…±Ω…’……ïπ–†§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞ÅÒÅç°Öππï∞π•Õ1•ŸîÄÑÙÅ—…’î§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÅô•πÖ∞Å¡±ÖÂ•πúÄÙÅ}¡±ÖÂ•πù1•ŸïU…∞°ç°Öππï∞§Ï(ÄÄÄÅ•òÄ°¡±ÖÂ•πúÄÙÙÅπ’±∞ÅÒÅ¡±ÖÂ•πúπ•Õµ¡—‰§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÄººÅQ°îÅïπù•πîÅÕ¡ïÖ≠ÃÅ!QQ@ÅΩπ±‰∏Å…—µ¿Ω…—Õ¿Ω’ë¿º∏∏∏Åç°Öππï±ÃÅùºÅ—ºÅ—°îÅ—ïîãßuÁ‚ùÁP(ÄÄÄÄººÅµ¡ÿÅ¡±ÖÂÃÅ—°ï¥∞ÅÕºÅµ¡ÿÅçÖ∏Å…ïçΩ…êÅ—°ï¥∏Å°ïç≠ïêÅ	=IÅ—°îÅ¡…ΩâîËÅµ¡ÿ(ÄÄÄÄººÅ…ï¡Ω…—ÃÅîπú∏Äâô±ÿàÅôΩ»ÅIQ5@∞Å›°•ç†Å›Ω’±êÅ…ïÖêÅÖÃÅ¡…Ωù…ïÕÕ•ŸîÅâï±Ω‹∏(ÄÄÄÅ•òÄ†Ö¡±ÖÂ•πúπÕ—Ö…—Õ]•—††ù°——¿Ëººú§ÄòòÄÖ¡±ÖÂ•πúπÕ—Ö…—Õ]•—††ù°——¡ÃËººú§§ÅÏ(ÄÄÄÄÄÅ…ï—’…∏Åπ’±∞Ï(ÄÄÄÅÙ(ÄÄÄÅM—…•πúÅôΩ…µÖ–ÄÙÄúúÏ(ÄÄÄÅô•πÖ∞Å¡±Ö—ôΩ…¥ÄÙÅ}¡±ÖÂï»π¡±Ö—ôΩ…¥Ï(ÄÄÄÅ•òÄ°¡±Ö—ôΩ…¥Å•ÃÅµ¨π9Ö—•ŸïA±ÖÂï»§ÅÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅôΩ…µÖ–ÄÙÅÖ›Ö•–Å¡±Ö—ôΩ…¥πùï—A…Ω¡ï…—‰†ùô•±îµôΩ…µÖ–ú§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å±Ω›ï»ÄÙÅôΩ…µÖ–π—Ω1Ω›ï…ÖÕî†§Ï(ÄÄÄÅ•òÄ°±Ω›ï»πçΩπ—Ö•πÃ†ù°±Ãú§ÅÒÅ±Ω›ï»πçΩπ—Ö•πÃ†ùëÖÕ†ú§§ÅÏ(ÄÄÄÄÄÄººÅMïùµïπ—ïêÅôΩ»ÅÕ’…îÇÈ›y¯ßy–ÅΩπ±‰ÅÖ∏Åa—…ïÖ¥ÅÄπ—ÕÄÅ—›•∏ÅçÖ∏Å…ïÕç’îÅ•–∏(ÄÄÄÄÄÅ…ï—’…∏Å1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπ·—…ïÖµQÕQ›•∏°¡±ÖÂ•πú§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ°±Ω›ï»π•Õ9Ω—µ¡—‰§ÅÏ(ÄÄÄÄÄÄººÅA…ΩâîÅÕÖÂÃÅ¡…Ωù…ïÕÕ•ŸîËÅ…ïçΩ…êÅï·Öç—±‰Å›°Ö–ùÃÅ¡±ÖÂ•πú∏(ÄÄÄÄÄÅ…ï—’…∏Å¡±ÖÂ•πúÏ(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏Å1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπïπù•πïIïçΩ…ëÖâ±ïU…∞°¡±ÖÂ•πú§Ï(ÄÅÙ((ÄÄºººÅIîµëï…•ŸîÅm}ïπù•πïQÖÕ≠%ëtÅô…Ω¥Å—°îÅπÖ—•ŸîÅ…ïù•Õ—…‰Æù◊üäwùPÅÑÅçÖ¡—’…îÅµÖ‰Å°ÖŸî(ÄÄºººÅâïï∏ÅÕ—Ö…—ïêÅ•∏ÅÖ∏ÅïÖ…±•ï»Å¡±ÖÂï»ÅÕïÕÕ•Ω∏∞ÅΩ»ÅÕ—Ω¡¡ïêÅô…Ω¥Å—°î(ÄÄºººÅπΩ—•ô•çÖ—•Ω∏Å›°•±îÅ—°•ÃÅÕç…ïï∏Å›ÖÃÅΩ¡ï∏∏(ÄÅ’—’…îÒŸΩ•ê¯Å}…ïô…ïÕ°πù•πïIïçΩ…ë•πùM—Ö—î†§ÅÖÕÂπåÅÏ(ÄÄÄÅ•òÄ†ÖA±Ö—ôΩ…¥π•Õπë…Ω•êÅÒÄÖ}ïπù•πï±Öù=∏§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞ÅÒÅç°Öππï∞π•Õ1•ŸîÄÑÙÅ—…’î§ÅÏ(ÄÄÄÄÄÅ•òÄ°}ïπù•πïQÖÕ≠%êÄÑÙÅπ’±∞ÄòòÅµΩ’π—ïê§ÅÏ(ÄÄÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}ïπù•πïQÖÕ≠%êÄÙÅπ’±∞§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å—•ç≠ï–ÄÙÄ¨≠}ïπù•πïIïô…ïÕ°Q•ç≠ï–Ï(ÄÄÄÅô•πÖ∞Å¡±ÖÂ•πúÄÙÅ}¡±ÖÂ•πù1•ŸïU…∞°ç°Öππï∞§Ï(ÄÄÄÅ•òÄ°¡±ÖÂ•πúÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÅ•òÄ°}ïπù•πïQÖÕ≠%êÄÑÙÅπ’±∞§ÅÕï—M—Ö—î††§ÄÙ¯Å}ïπù•πïQÖÕ≠%êÄÙÅπ’±∞§Ï(ÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞Å—›•∏ÄÙÅ1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπ·—…ïÖµQÕQ›•∏°¡±ÖÂ•πú§Ï(ÄÄÄÅô•πÖ∞Å…ïçΩ…ë•πùÃÄÙÅÖ›Ö•–Å1•ŸïIïçΩ…ë•πùMï…Ÿ•çîπ≈’ï…‰†§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}ïπù•πïIïô…ïÕ°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÅM—…•πú¸ÅôΩ’πêÏ(ÄÄÄÅôΩ»Ä°ô•πÖ∞Å»Å•∏Å…ïçΩ…ë•πùÃ§ÅÏ(ÄÄÄÄÄÅ•òÄ°»π•ÕIïçΩ…ë•πúÄòò(ÄÄÄÄÄÄÄÄÄÄ°»π’…∞ÄÙÙÅ¡±ÖÂ•πúÅÒÄ°—›•∏ÄÑÙÅπ’±∞ÄòòÅ»π’…∞ÄÙÙÅ—›•∏§§§ÅÏ(ÄÄÄÄÄÄÄÅôΩ’πêÄÙÅ»π—ÖÕ≠%êÏ(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÅ•òÄ°ôΩ’πêÄÑÙÅ}ïπù•πïQÖÕ≠%ê§ÅÏ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}ïπù•πïQÖÕ≠%êÄÙÅôΩ’πê§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅÄÒ°Öππï∞˘|ÒÂÂÂÂ55ëë}!!µµÕÃ¯π—ÕÄãßuÁ‚ùÁPÅÕÖµîÅÕ°Ö¡îÅÖÃÅ—°îÅ—ïîùÃÅ—Ö…ùï–Å¡Ö—†(ÄÄºººÄ°›°•ç†ÅÖëë•—•ΩπÖ±±‰Å’π•≈’•ô•ïÃÅÖùÖ•πÕ–Å•—ÃÅΩ›∏Åë•…ïç—Ω…‰ÏÅ5ïë•ÖM—Ω…î(ÄÄºººÅ’π•≈’•ô•ïÃÅôΩ»Å—°îÅïπù•πî§∏(ÄÅM—…•πúÅ}…ïçΩ…ë•πù•±ï9Öµî°M—…•πúÅç°Öππï±9Öµî§ÅÏ(ÄÄÄÅô•πÖ∞ÅÕÖôï9ÖµîÄÙÅç°Öππï±9Öµî(ÄÄÄÄÄÄÄÄπ…ï¡±Öçï±∞°Iïù·¿°»ùmyµiÑµË¿¥‰Å|µtú§∞Äúú§(ÄÄÄÄÄÄÄÄπ—…•¥†§(ÄÄÄÄÄÄÄÄπ…ï¡±Öçï±∞°Iïù·¿°»ùqÃ¨ú§∞Äù|ú§Ï(ÄÄÄÅŸÖ»ÅâÖÕîÄÙÅÕÖôï9Öµîπ•Õµ¡—‰Ä¸Äù…ïçΩ…ë•πúúÄËÅÕÖôï9ÖµîÏ(ÄÄÄÅ•òÄ°âÖÕîπ±ïπù—†Ä¯Äÿ¿§ÅâÖÕîÄÙÅâÖÕîπÕ’âÕ—…•πú†¿∞Äÿ¿§Ï(ÄÄÄÅô•πÖ∞ÅπΩ‹ÄÙÅÖ—ïQ•µîππΩ‹†§Ï(ÄÄÄÅM—…•πúÅ—›º°•π–Åÿ§ÄÙ¯Åÿπ—ΩM—…•πú†§π¡Öë1ïô–†»∞Äú¿ú§Ï(ÄÄÄÅô•πÖ∞ÅÕ—Öµ¿ÄÙ(ÄÄÄÄÄÄÄÄúëÌπΩ‹πÂïÖ…ÙëÌ—›º°πΩ‹πµΩπ—†•ÙëÌ—›º°πΩ‹πëÖ‰•ı|ú(ÄÄÄÄÄÄÄÄúëÌ—›º°πΩ‹π°Ω’»•ÙëÌ—›º°πΩ‹πµ•π’—î•ÙëÌ—›º°πΩ‹πÕïçΩπê•ÙúÏ(ÄÄÄÅ…ï—’…∏ÄúëÌâÖÕïı|ëÕ—Öµ¿π—ÃúÏ(ÄÅÙ((ÄÅ’—’…î°ÌM—…•πúÅ•ê∞Å•π–Å…ïŸ•Õ•ΩπÙ§¸¯Å}ç’……ïπ—IïçΩ…ë•πùIïÕΩ’…çî†§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅô•πÖ∞ÅÕΩ’…çï%êÄÙ(ÄÄÄÄÄÄÄÅç°Öππï∞¸πÖ——…•â’—ïÕlùÕΩ’…çï}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÅç°Öππï∞¸πÖ——…•â’—ïÕlùÕï…•ïÕ}¡±ÖÂ±•Õ—}•êùtÄ¸¸(ÄÄÄÄÄÄÄÅ›•ëùï–π•¡—ŸMΩ’…çï%êÏ(ÄÄÄÅ•òÄ°ÕΩ’…çï%êÄÙÙÅπ’±∞§Å…ï—’…∏Åπ’±∞Ï(ÄÄÄÄººÅ…ïÕ†Å…ïÖêÅô•…Õ–ËÅ—°îÅ±Ö’πç†Å¡ÖÂ±ΩÖêùÃÅ…ïŸ•Õ•Ω∏Å¡…ïëÖ—ïÃÅÖπ‰ÅÕΩ’…çïÃ(ÄÄÄÄººÅïë•–ÅµÖëîÅ›°•±îÅ—°•ÃÅ¡±ÖÂï»Å±•ŸïÃÄ°A•@∞ÅâÖç≠ù…Ω’πê§∞ÅÖπêÅïŸï…‰Åïë•–(ÄÄÄÄººÅâ’µ¡ÃÅïŸï…‰ÅÕΩ’…çîùÃÅ…ïŸ•Õ•Ω∏ÇÈ›y¯ßy–ÅÑÅÕ—Ö±îÅΩπîÅ›Ω’±êÅâîÅ…ïô’ÕïêÅÖ–ÅÕ—Ö…–∏(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅô•πÖ∞Å¡±ÖÂ±•Õ—ÃÄÙÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπùï—%¡—ŸA±ÖÂ±•Õ—Ã†(ÄÄÄÄÄÄÄÅôΩ…Mï——•πùÃËÅôÖ±Õî∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅôΩ»Ä°ô•πÖ∞Å¡±ÖÂ±•Õ–Å•∏Å¡±ÖÂ±•Õ—Ã§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°¡±ÖÂ±•Õ–π•êÄÑÙÅÕΩ’…çï%ê§ÅçΩπ—•π’îÏ(ÄÄÄÄÄÄÄÅô•πÖ∞Å•êÄÙÅ¡±ÖÂ±•Õ–πçΩππïç—•ΩπIïÕΩ’…çï%êÏ(ÄÄÄÄÄÄÄÅô•πÖ∞Å…ïŸ•Õ•Ω∏ÄÙÅ¡±ÖÂ±•Õ–πçΩππïç—•ΩπIïÕΩ’…çïIïŸ•Õ•Ω∏Ï(ÄÄÄÄÄÄÄÅ•òÄ°•êÄÑÙÅπ’±∞ÄòòÅ•êπ•Õ9Ω—µ¡—‰ÄòòÅ…ïŸ•Õ•Ω∏ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ…ï—’…∏Ä°•êËÅ•ê∞Å…ïŸ•Õ•Ω∏ËÅ…ïŸ•Õ•Ω∏§Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ(ÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÏ(ÄÄÄÄÄÄººÅM—Ω…ÖùîÅ’πÖŸÖ•±Öâ±îÅµ•êµÕïÕÕ•Ω∏ËÅôÖ±∞Å—°…Ω’ù†Å—ºÅ—°îÅ±Ö’πç†Å¡ÖÂ±ΩÖê∏(ÄÄÄÅÙ(ÄÄÄÅôΩ»Ä°ô•πÖ∞ÅÕΩ’…çîÅ•∏Å›•ëùï–π•¡—ŸMΩ’…çïÃÄ¸¸ÅçΩπÕ–ÄÒ5Ö¿ÒM—…•πú∞ÅëÂπÖµ•å¯˘mt§ÅÏ(ÄÄÄÄÄÅ•òÄ°ÕΩ’…çïlù•êùtÄÑÙÅÕΩ’…çï%ê§ÅçΩπ—•π’îÏ(ÄÄÄÄÄÅô•πÖ∞Å•êÄÙÅÕΩ’…çïlùçΩππïç—•ΩπIïÕΩ’…çï%êùt¸π—ΩM—…•πú†§Ï(ÄÄÄÄÄÅô•πÖ∞Å…ïŸ•Õ•Ω∏ÄÙÄ°ÕΩ’…çïlùçΩππïç—•ΩπIïÕΩ’…çïIïŸ•Õ•Ω∏ùtÅÖÃÅπ’¥¸§¸π—Ω%π–†§Ï(ÄÄÄÄÄÅ•òÄ°•êÄÑÙÅπ’±∞ÄòòÅ•êπ•Õ9Ω—µ¡—‰ÄòòÅ…ïŸ•Õ•Ω∏ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅ…ï—’…∏Ä°•êËÅ•ê∞Å…ïŸ•Õ•Ω∏ËÅ…ïŸ•Õ•Ω∏§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏Åπ’±∞Ï(ÄÅÙ((ÄÄºººÅA…•π–Åµ¡ÿÅ±ΩúÅ±•πïÃÅ—°Ö–ÅµÖ——ï»Å›°•±îÅÑÅ—ïîÅ…ïçΩ…ë•πúÅ…’πÃ∏(ÄÅŸΩ•êÅ}—Ö¡5¡Ÿ1ΩùÕΩ…IïçΩ…ë•πú†§ÅÏ(ÄÄÄÅ}…ïçΩ…ë1ΩùM’à¸πçÖπçï∞†§Ï(ÄÄÄÅ}…ïçΩ…ë1ΩùM’àÄÙÅ}¡±ÖÂï»πÕ—…ïÖ¥π±Ωúπ±•Õ—ï∏†°±Ωú§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Å±ïŸï∞ÄÙÅ±Ωúπ±ïŸï∞π—Ω1Ω›ï…ÖÕî†§Ï(ÄÄÄÄÄÅ•òÄ°±ïŸï∞ÄÑÙÄùï……Ω»úÄòòÅ±ïŸï∞ÄÑÙÄùôÖ—Ö∞ú§Å…ï—’…∏Ï(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅµ¡ŸlëÌ±Ωúπ±ïŸï±ıtÄëÌ±Ωúπ¡…ïô•·ÙËÄëÌ±Ωúπ—ï·—Ùú§Ï(ÄÄÄÅÙ§Ï(ÄÅÙ((ÄÅŸΩ•êÅ}’π—Ö¡5¡Ÿ1ΩùÃ†§ÅÏ(ÄÄÄÅ}…ïçΩ…ë1ΩùM’à¸πçÖπçï∞†§Ï(ÄÄÄÅ}…ïçΩ…ë1ΩùM’àÄÙÅπ’±∞Ï(ÄÅÙ((ÄÅ’—’…îÒŸΩ•ê¯Å}Õ—Ö…—IïçΩ…ë•πú†§ÅÖÕÂπåÅÏ(ÄÄÄÅ•òÄ†Ö}¡±ÖÂï……ïÖ—ïê§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Å¡±Ö—ôΩ…¥ÄÙÅ}¡±ÖÂï»π¡±Ö—ôΩ…¥Ï(ÄÄÄÅ•òÄ°¡±Ö—ôΩ…¥Å•ÃÑÅµ¨π9Ö—•ŸïA±ÖÂï»§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅ}ç’……ïπ—%¡—Ÿ°Öππï∞Ï(ÄÄÄÅ•òÄ°ç°Öππï∞ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Åùï∏ÄÙÄ¨≠}…ïçΩ…ë•πùM—Ö…—ï∏Ï(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅô•πÖ∞Å¡Ö—†ÄÙÅÖ›Ö•–Å}…ïçΩ…ë•πùQÖ…ùï—AÖ—†°ç°Öππï∞ππÖµî§Ï(ÄÄÄÄÄÅô•πÖ∞Å¡Ö…ïπ–ÄÙÅ•…ïç—Ω…‰°¡Ö—†§π¡Ö…ïπ–Ï(ÄÄÄÄÄÅ•òÄ†ÖÖ›Ö•–Å¡Ö…ïπ–πï·•Õ—Ã†§§ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å¡Ö…ïπ–πç…ïÖ—î°…ïç’…Õ•ŸîËÅ—…’î§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÄººÅQ°îÅç°Öππï∞Ä°Ω»Å—°îÅ›°Ω±îÅÕç…ïï∏§ÅµÖ‰Å°ÖŸîÅùΩπîÅ›°•±îÅ—°îÅÕ—Ω…ÖùîÅ›Ω…¨(ÄÄÄÄÄÄººÅ…Ö∏∏Å…µ•πúÅπΩ‹Å›Ω’±êÅ—ïîÅ—°îÅ9\ÅÕ—…ïÖ¥Å•π—ºÅ—°îÅΩ±êÅç°Öππï∞ùÃÅô•±î∏(ÄÄÄÄÄÅ•òÄ°ùï∏ÄÑÙÅ}…ïçΩ…ë•πùM—Ö…—ï∏ÅÒÄÖµΩ’π—ïêÅÒÄÖ}¡±ÖÂï……ïÖ—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅ}—Ö¡5¡Ÿ1ΩùÕΩ…IïçΩ…ë•πú†§Ï(ÄÄÄÄÄÅÖ›Ö•–Å¡±Ö—ôΩ…¥πÕï—A…Ω¡ï…—‰†ùÕ—…ïÖ¥µ…ïçΩ…êú∞Å¡Ö—†§Ï(ÄÄÄÄÄÄººÅIïÖêÅ—°îÅ¡…Ω¡ï…—‰ÅâÖç¨ËÅ¡…ΩŸïÃÅ›°ï—°ï»Åµ¡ÿÅÖç—’Ö±±‰ÅAQÅ—°î(ÄÄÄÄÄÄººÅ—Ö…ùï–Ä°ÑÅÕ•±ïπ–Å•π—ï…πÖ∞ÅôÖ•±’…îÅ±ïÖŸïÃÅ•–ÅÕï–Åâ’–Å›…•—ïÃÅπΩ—°•πúÇÈ›y¯ßy–(ÄÄÄÄÄÄººÅ—°îÅ±ΩúÅ—Ö¿ÅÖâΩŸîÅçÖ—ç°ïÃÅ—°Ö–ÅçÖÕî§∏(ÄÄÄÄÄÅŸÖ»Åïç°ΩïêÄÙÄúúÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅïç°ΩïêÄÙÅÖ›Ö•–Å¡±Ö—ôΩ…¥πùï—A…Ω¡ï…—‰†ùÕ—…ïÖ¥µ…ïçΩ…êú§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùY•ëïΩA±ÖÂï»ËÅÕ—…ïÖ¥µ…ïçΩ…êÅÖ…µïêÆù◊üäwùPÅµ¡ÿÅ…ï¡Ω…—ÃÄàëïç°ΩïêàÄú(ÄÄÄÄÄÄÄÄú°›Öπ–Äàë¡Ö—†à§ú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ°ùï∏ÄÑÙÅ}…ïçΩ…ë•πùM—Ö…—ï∏ÅÒÄÖµΩ’π—ïê§ÅÏ(ÄÄÄÄÄÄÄÄººÅ1ΩÕ–Å—°îÅ…ÖçîÅ•πÕ•ëîÅÕï—A…Ω¡ï…—‰Å•—Õï±òËÅë•ÕÖ…¥Å…Ö—°ï»Å—°Ö∏Å±ïÖŸîÅÖ∏(ÄÄÄÄÄÄÄÄººÅ’π—…Öç≠ïêÅ…ïçΩ…ë•πúÅ…’ππ•πúÅΩ∏ÅÕΩµïΩπîÅï±ÕîùÃÅÕ—…ïÖ¥∏(ÄÄÄÄÄÄÄÅ}’π—Ö¡5¡Ÿ1ΩùÃ†§Ï(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}ë•ÕÖ…µM—…ÖÂIïçΩ…ë•πú°¡±Ö—ôΩ…¥∞Å¡Ö—†§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÄÄÅ}•ÕIïçΩ…ë•πúÄÙÅ—…’îÏ(ÄÄÄÄÄÄÄÅ}…ïçΩ…ë•πùQïµ¡AÖ—†ÄÙÅ¡Ö—†Ï(ÄÄÄÄÄÅÙ§Ï(ÄÄÄÄÄÄººÅ…ÖÕ†Å•πÕ’…ÖπçîËÅ…ïù•Õ—ï…ïêÅπÖ—•Ÿï±‰ÅÕºÅ—°îÅô•±îÅùï—ÃÅ¡’â±•Õ°ïêÅΩ∏(ÄÄÄÄÄÄººÅπï·–Å±Ö’πç†ÅïŸï∏Å•òÅ—°•ÃÅ¡…ΩçïÕÃÅπïŸï»Å…ïÖç°ïÃÅ}Õ—Ω¡IïçΩ…ë•πú∏(ÄÄÄÄÄÅ•òÄ°A±Ö—ôΩ…¥π•Õπë…Ω•ê§ÅÏ(ÄÄÄÄÄÄÄÅ’πÖ›Ö•—ïê†(ÄÄÄÄÄÄÄÄÄÅπë…Ω•ë9Ö—•ŸïΩ›π±ΩÖëï»π…ïù•Õ—ï…Aïπë•πùIïçΩ…ë•πú†(ÄÄÄÄÄÄÄÄÄÄÄÅ¡Ö—†ËÅ¡Ö—†∞(ÄÄÄÄÄÄÄÄÄÄÄÅô•±ï9ÖµîËÅ¡Ö—†πÕ¡±•–°A±Ö—ôΩ…¥π¡Ö—°Mï¡Ö…Ö—Ω»§π±ÖÕ–∞(ÄÄÄÄÄÄÄÄÄÄÄÅµ•µïQÂ¡îËÄùŸ•ëïºΩ‡µµÖ—…ΩÕ≠Ñú∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÄººÅQ°îÅ—ïîÅ…ïçΩ…ëÃÅ›°Ö–Å—°îÅ¡±ÖÂï»Å…ïÖëÃ∞ÅÕºÅΩ∏Åπë…Ω•êÄ°›°ï…îÅ—°î(ÄÄÄÄÄÄÄÄÄÄÄÄººÅïπù•πîÅï·•Õ—ÃÅÖÃÅ—°îÅçΩπ—…ÖÕ–§ÅÕÖ‰Å—°îÅÕïµÖπ—•çÃÅΩ’–Å±Ω’ê∏(ÄÄÄÄÄÄÄÄÄÄÄÅA±Ö—ôΩ…¥π•Õπë…Ω•ê(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¸ÄùIïçΩ…ë•πúÅÕ—Ö…—ïêÄ°Õ—Ω¡ÃÅ•òÅÂΩ‘Å±ïÖŸîÅ—°îÅç°Öππï∞§ú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄËÄùIïçΩ…ë•πúÅÕ—Ö…—ïêú∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅ}’π—Ö¡5¡Ÿ1ΩùÃ†§Ï(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅÕ—Ö…–Å…ïçΩ…ë•πúÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπÕ–ÅMπÖç≠	Ö»°çΩπ—ïπ–ËÅQï·–†ùΩ’±êÅπΩ–ÅÕ—Ö…–Å…ïçΩ…ë•πúú§§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅUπëºÅÑÅ…ïçΩ…ë•πúÅ—°Ö–ÅùΩ–ÅÖ…µïêÅÖô—ï»Å•—ÃÅç°Öππï∞ÅΩ»ÅÕç…ïï∏Å›ïπ–ÅÖ›Ö‰∏(ÄÄºººÅQ°îÅÕ—’àÅô•±îÅ•ÃÅµ•±±•ÕïçΩπëÃÅΩ±ê∞ÅÕºÅë…Ω¡¡•πúÅ•–Å±ΩÕïÃÅπΩ—°•πúÅÑÅ’Õï»(ÄÄºººÅ›Ω’±êÅ…ïçΩùπ•ÕîÅÖÃÅÑÅ…ïçΩ…ë•πú∏(ÄÅ’—’…îÒŸΩ•ê¯Å}ë•ÕÖ…µM—…ÖÂIïçΩ…ë•πú†(ÄÄÄÅµ¨π9Ö—•ŸïA±ÖÂï»Å¡±Ö—ôΩ…¥∞(ÄÄÄÅM—…•πúÅ¡Ö—†∞(ÄÄ§ÅÖÕÂπåÅÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å¡±Ö—ôΩ…¥πÕï—A…Ω¡ï…—‰†ùÕ—…ïÖ¥µ…ïçΩ…êú∞Äúú§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅë•ÕÖ…¥ÅÕ—…Ö‰Å…ïçΩ…ë•πúÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÅÙ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åô•±îÄÙÅ•±î°¡Ö—†§Ï(ÄÄÄÄÄÅ•òÄ°Ö›Ö•–Åô•±îπï·•Õ—Ã†§§ÅÖ›Ö•–Åô•±îπëï±ï—î†§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅÕ—…Ö‰Å…ïçΩ…ë•πúÅç±ïÖπ’¿ÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÄºººÅM—Ω¿Å—°îÅÖç—•ŸîÅ…ïçΩ…ë•πú∏Å’—ºµÕ—Ω¡ÃÄ°ç°Öππï∞Åç°ÖπùîÄºÅë•Õ¡ΩÕî§Å¡ÖÕÃ(ÄÄºººÅm’Õï…%π•—•Ö—ïëtÄÙÅôÖ±ÕîÅ—ºÅÕ—Ö‰Å≈’•ï–∏(ÄÅ’—’…îÒŸΩ•ê¯Å}Õ—Ω¡IïçΩ…ë•πú°ÌâΩΩ∞Å’Õï…%π•—•Ö—ïêÄÙÅ—…’ïÙ§ÅÖÕÂπåÅÏ(ÄÄÄÄººÅÅÕ—Ω¿ÅÕ’¡ï…ÕïëïÃÅÖ∏Å•∏µô±•ù°–ÅÕ—Ö…–Å—ΩºÇÈ›y¯ßy–Å•πç±’ë•πúÅΩπîÅ—°Ö–Å°ÖÃÅπΩ–(ÄÄÄÄººÅÂï–Åô±•¡¡ïêÅÅ}•ÕIïçΩ…ë•πùÄÅÖπêÅÕºÅ•ÃÅ•πŸ•Õ•â±îÅ—ºÅ—°îÅç°ïç¨Åâï±Ω‹∏(ÄÄÄÅ}…ïçΩ…ë•πùM—Ö…—ï∏¨¨Ï(ÄÄÄÅ•òÄ†Ö}•ÕIïçΩ…ë•πú§Å…ï—’…∏Ï(ÄÄÄÅô•πÖ∞Å¡Ö—†ÄÙÅ}…ïçΩ…ë•πùQïµ¡AÖ—†Ï(ÄÄÄÅô•πÖ∞Å¡±Ö—ôΩ…¥ÄÙÅ}¡±ÖÂï……ïÖ—ïêÄ¸Å}¡±ÖÂï»π¡±Ö—ôΩ…¥ÄËÅπ’±∞Ï(ÄÄÄÄººÅ±•¿ÅÕ—Ö—îÅô•…Õ–ÅÕºÅÑÅ…Ö¡•êÅ…îµ—Ö¿ÄºÅç°Öππï∞ÅÕ›•—ç†ÅçÖ∏ù–ÅëΩ’â±îµÕ—Ω¿∏(ÄÄÄÅ•òÄ°µΩ’π—ïê§ÅÏ(ÄÄÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÄÄÅ}•ÕIïçΩ…ë•πúÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÅ}…ïçΩ…ë•πùQïµ¡AÖ—†ÄÙÅπ’±∞Ï(ÄÄÄÄÄÅÙ§Ï(ÄÄÄÅÙÅï±ÕîÅÏ(ÄÄÄÄÄÅ}•ÕIïçΩ…ë•πúÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ}…ïçΩ…ë•πùQïµ¡AÖ—†ÄÙÅπ’±∞Ï(ÄÄÄÅÙ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅ•òÄ°¡±Ö—ôΩ…¥Å•ÃÅµ¨π9Ö—•ŸïA±ÖÂï»§ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å¡±Ö—ôΩ…¥πÕï—A…Ω¡ï…—‰†ùÕ—…ïÖ¥µ…ïçΩ…êú∞Äúú§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅÕ—Ω¿Å…ïçΩ…ë•πúÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÅÙ(ÄÄÄÅ}’π—Ö¡5¡Ÿ1ΩùÃ†§Ï(ÄÄÄÅ•òÄ°¡Ö—†ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÄººÅYI%dÅâïôΩ…îÅç±Ö•µ•πúÅÖπÂ—°•πúËÅµ¡ÿÅçÖ∏ÅÖççï¡–ÅÅÕ—…ïÖ¥µ…ïçΩ…ëÄÅÖπê(ÄÄÄÄººÅÕ—•±∞Å›…•—îÅπΩ—°•πúÄ°•π—ï…πÖ∞ÅôΩ¡ï∏Å…ïô’Õïê∞Å’πë’µ¡Öâ±îÅëïµ’·ï»§ÇÈ›y¯ßy–Å—°î(ÄÄÄÄººÅô•…Õ–ÅµÖç=LÅ—ïÕ–Å°•–Åï·Öç—±‰Å—°Ö–∞Å›•—†ÅÑÄâÕÖŸïêàÅµïÕÕÖùîÅΩŸï»ÅÖ∏Åïµ¡—‰(ÄÄÄÄººÅôΩ±ëï»∏(ÄÄÄÅŸÖ»Åô•±ï	Â—ïÃÄÙÄ¿Ï(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åô•±îÄÙÅ•±î°¡Ö—†§Ï(ÄÄÄÄÄÅ•òÄ°Ö›Ö•–Åô•±îπï·•Õ—Ã†§§Åô•±ï	Â—ïÃÄÙÅÖ›Ö•–Åô•±îπ±ïπù—††§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄùY•ëïΩA±ÖÂï»ËÅ—ïîÅ…ïçΩ…ë•πúÅÕ—Ω¡¡ïêÆù◊üäwùPÄëô•±ï	Â—ïÃÅâÂ—ïÃÅΩ∏Åë•Õ¨ÅÖ–Äë¡Ö—†ú∞(ÄÄÄÄ§Ï(ÄÄÄÅô•πÖ∞Åô•±ï=¨ÄÙÅô•±ï	Â—ïÃÄ¯Ä¿Ï(ÄÄÄÄººÅA’â±•Õ†Å—ºÅÑÅ’Õï»µŸ•Õ•â±îÅ±ΩçÖ—•Ω∏∏Å=∏Åπë…Ω•êÅ—°îÅô•±îÅ±•ŸïÃÅ•∏(ÄÄÄÄººÅÖ¡¿µ¡…•ŸÖ—îÅÕ—Ω…Öùî∞ÅÕºÅ°ÖπêÅ•–Å—ºÅ—°îÅπÖ—•ŸîÅ5ïë•ÖM—Ω…îÅ¡’â±•Õ°ï»ÏÅΩ∏(ÄÄÄÄººÅëïÕ≠—Ω¿Å•–ùÃÅÖ±…ïÖë‰Å’πëï»Å—°îÅ’Õï»ùÃÅΩ›π±ΩÖëÃ∏(ÄÄÄÅ•òÄ°ô•±ï=¨ÄòòÅA±Ö—ôΩ…¥π•Õπë…Ω•ê§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}¡’â±•Õ°IïçΩ…ë•πú°¡Ö—†∞Å’Õï…%π•—•Ö—ïêËÅ’Õï…%π•—•Ö—ïê§§Ï(ÄÄÄÅÙÅï±ÕîÅ•òÄ°’Õï…%π•—•Ö—ïêÄòòÅµΩ’π—ïê§ÅÏ(ÄÄÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÄÄÅô•±ï=¨(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¸ÄùIïçΩ…ë•πúÅÕÖŸïêËÄë¡Ö—†ú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄËÄùIïçΩ…ë•πúÅôÖ•±ïêÇÈ›y¯ßy–Åµ¡ÿÅ›…Ω—îÅπºÅô•±îÄ°ÕïîÅ±ΩùÃ§ú∞(ÄÄÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÅ’—’…îÒŸΩ•ê¯Å}¡’â±•Õ°IïçΩ…ë•πú†(ÄÄÄÅM—…•πúÅ¡Ö—†∞ÅÏ(ÄÄÄÅ…ï≈’•…ïêÅâΩΩ∞Å’Õï…%π•—•Ö—ïê∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅŸÖ»Å¡’â±•Õ°ïêÄÙÅôÖ±ÕîÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅô•πÖ∞Åô•±ï9ÖµîÄÙÅ¡Ö—†πÕ¡±•–°A±Ö—ôΩ…¥π¡Ö—°Mï¡Ö…Ö—Ω»§π±ÖÕ–Ï(ÄÄÄÄÄÅô•πÖ∞Å’…§ÄÙÅÖ›Ö•–Åπë…Ω•ë9Ö—•ŸïΩ›π±ΩÖëï»πÕÖŸï1ΩçÖ±•±î†(ÄÄÄÄÄÄÄÅ¡Ö—†ËÅ¡Ö—†∞(ÄÄÄÄÄÄÄÅô•±ï9ÖµîËÅô•±ï9Öµî∞(ÄÄÄÄÄÄÄÅµ•µïQÂ¡îËÄùŸ•ëïºΩ‡µµÖ—…ΩÕ≠Ñú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ¡’â±•Õ°ïêÄÙÅ’…§ÄÑÙÅπ’±∞Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùY•ëïΩA±ÖÂï»ËÅ¡’â±•Õ†Å…ïçΩ…ë•πúÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ†Ö’Õï…%π•—•Ö—ïêÅÒÄÖµΩ’π—ïê§Å…ï—’…∏Ï(ÄÄÄÄººÅ=∏ÅôÖ•±’…î∞ÅëΩ∏ù–Åç±Ö•¥ÅÑÅÕÖŸîÅ—°îÅ’Õï»ÅçÖ∏ù–Åô•πêËÅ—°îÅô•±îÅÕ•—ÃÅ•∏(ÄÄÄÄººÅÖ¡¿µ¡…•ŸÖ—îÅÕ—Ω…Öùî∞Å•—ÃÅ…ïù•Õ—…‰Åïπ—…‰ÅÕ’…Ÿ•ŸïÃÄ°Ωπ±‰ÅÑÅÕ’ççïÕÕô’∞(ÄÄÄÄººÅ¡’â±•Õ†Åç±ïÖ…ÃÅ•–§∞ÅÖπêÅ—°îÅπï·–ÅÖ¡¿Å±Ö’πç†Å…îµÖ——ïµ¡—ÃÅ—°îÅ¡’â±•Õ†∏(ÄÄÄÅMçÖôôΩ±ë5ïÕÕïπùï»πΩò°çΩπ—ï·–§πÕ°Ω›MπÖç≠	Ö»†(ÄÄÄÄÄÅMπÖç≠	Ö»†(ÄÄÄÄÄÄÄÅçΩπ—ïπ–ËÅQï·–†(ÄÄÄÄÄÄÄÄÄÅ¡’â±•Õ°ïê(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¸ÄùIïçΩ…ë•πúÅÕÖŸïêÅ—ºÅΩ›π±ΩÖëÃΩïâ…•ô‰ΩIïçΩ…ë•πùÃú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄËÄâIïçΩ…ë•πúÅçΩ’±ë∏ù–ÅâîÅÖëëïêÅ—ºÅΩ›π±ΩÖëÃÆù◊üäwùPÄà(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄù›•±∞Å…ï—…‰Åπï·–Å±Ö’πç†ú∞(ÄÄÄÄÄÄÄÄ§∞(ÄÄÄÄÄÄ§∞(ÄÄÄÄ§Ï(ÄÅÙ((ÄÄºººÅÅ¡Ö—†ÅπºÅΩ—°ï»Å…ïçΩ…ë•πúÅ•ÃÅ’Õ•πú∏ÅQ°îÅÕïçΩπêµ…ïÕΩ±’—•Ω∏ÅÕ—Öµ¿ÅÖ±Ωπî(ÄÄºººÅçΩ±±•ëïÃÅ›°ï∏Å—°îÅÕÖµîÅç°Öππï∞Å•ÃÅÕ—Ω¡¡ïêÅÖπêÅ…ïÕ—Ö…—ïêÅ•πÕ•ëîÅΩπî(ÄÄºººÅÕïçΩπê∞ÅÖπêÅ—°Ö–ÅçΩ±±•Õ•Ω∏Å•ÃÅëïÕ—…’ç—•ŸîËÅ±•âµ¡ÿÅ›Ω’±êÅ—…’πçÖ—îÄ°Ω»(ÄÄºººÅÖ¡¡ïπêÅ—º§Å—°îÅ¡…ïŸ•Ω’ÃÅô•±î∞ÅÖπêÅΩ∏Åπë…Ω•êÅ—°îÅÕ—•±∞µ…’ππ•πúÅ¡’â±•Õ°ï»(ÄÄºººÅëï±ï—ïÃÅ•—ÃÅÕΩ’…çîÅΩπçîÅçΩ¡•ïêãßuÁ‚ùÁPÅ—Ö≠•πúÅ—°îÅ9\Å…ïçΩ…ë•πúÅ›•—†Å•–∏Å∏(ÄÄºººÅï·•Õ—•πúÅô•±îÅ—°ï…ïôΩ…îÅµïÖπÃÄâ•∏Å’ÕîàËÅÕ—ï¿ÅÖÕ•ëîÅ›•—†ÅÑÅÕ’ôô•‡∏(ÄÄººº(ÄÄºººÅïôÖ’±–ÅÄπµ≠ŸÄÄ°—°îÅQ§ËÅµ¡ÿùÃÅ…ïçΩ…ëï»Å¡•ç≠ÃÅ—°îÅΩ’—¡’–Åµ’·ï»Åô…Ω¥Å—°î(ÄÄºººÅô•±ïπÖµî∞ÅÖπêÅµïë•Ö}≠•–ùÃÅëïçΩëîµ—…•µµïêÅµ¡ïúÅÕ°•¡ÃÅπºÅÅµ¡ïù—ÕÄÅµ’·ï»(ÄÄºººÄ†â…ïçΩ…ëï»ËÅ=’—¡’–ÅôΩ…µÖ–ÅπΩ–ÅôΩ’πêàÇÈ›y¯ßyÿÅ…ïçΩ…ë•πúÅÕ•±ïπ—±‰Åë•ÕÖâ±ïêÇÈ›y¯ßy–(ÄÄºººÅôΩ’πêÅ±•ŸîÅΩ∏ÅµÖç=L§∏Å5Ö—…ΩÕ≠ÑÅ•ÃÅ—°îÅΩπ±‰ÅÕÖπîÅ—Ö…ùï–Å%ÅÑÅµ’·ï»(ÄÄºººÅï·•Õ—Ã∏ÅIÖ‹ÅâÂ—îÅçΩ¡•ï…ÃÄ°—°îÅëïÕ≠—Ω¿ÅçÖ¡—’…î∞Å—°îÅπë…Ω•êÅïπù•πî§Å¡ÖÕÃ(ÄÄºººÅÅï·—ïπÕ•Ω∏ËÄù—ÃùÄÆù◊üäwùPÅ—°ï•»ÅâÂ—ïÃÅIÅÑÅ—…ÖπÕ¡Ω…–ÅÕ—…ïÖ¥∞ÅπºÅµ’·ï»(ÄÄºººÅ•πŸΩ±Ÿïê∏(ÄÅ’—’…îÒM—…•πú¯Å}…ïçΩ…ë•πùQÖ…ùï—AÖ—††(ÄÄÄÅM—…•πúÅç°Öππï±9Öµî∞ÅÏ(ÄÄÄÅM—…•πúÅï·—ïπÕ•Ω∏ÄÙÄùµ≠ÿú∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞ÅÕÖôï9ÖµîÄÙÅç°Öππï±9Öµî(ÄÄÄÄÄÄÄÄπ…ï¡±Öçï±∞°Iïù·¿°»ùmyµiÑµË¿¥‰Å|µtú§∞Äúú§(ÄÄÄÄÄÄÄÄπ—…•¥†§(ÄÄÄÄÄÄÄÄπ…ï¡±Öçï±∞°Iïù·¿°»ùqÃ¨ú§∞Äù|ú§Ï(ÄÄÄÅŸÖ»ÅâÖÕîÄÙÅÕÖôï9Öµîπ•Õµ¡—‰Ä¸Äù…ïçΩ…ë•πúúÄËÅÕÖôï9ÖµîÏ(ÄÄÄÅ•òÄ°âÖÕîπ±ïπù—†Ä¯Äÿ¿§ÅâÖÕîÄÙÅâÖÕîπÕ’âÕ—…•πú†¿∞Äÿ¿§Ï(ÄÄÄÅô•πÖ∞ÅπΩ‹ÄÙÅÖ—ïQ•µîππΩ‹†§Ï(ÄÄÄÅM—…•πúÅ—›º°•π–Åÿ§ÄÙ¯Åÿπ—ΩM—…•πú†§π¡Öë1ïô–†»∞Äú¿ú§Ï(ÄÄÄÅô•πÖ∞ÅÕ—Öµ¿ÄÙ(ÄÄÄÄÄÄÄÄúëÌπΩ‹πÂïÖ…ÙëÌ—›º°πΩ‹πµΩπ—†•ÙëÌ—›º°πΩ‹πëÖ‰•ı|ú(ÄÄÄÄÄÄÄÄúëÌ—›º°πΩ‹π°Ω’»•ÙëÌ—›º°πΩ‹πµ•π’—î•ÙëÌ—›º°πΩ‹πÕïçΩπê•ÙúÏ((ÄÄÄÅ•…ïç—Ω…‰Åë•»Ï(ÄÄÄÅ•òÄ°A±Ö—ôΩ…¥π•Õπë…Ω•ê§ÅÏ(ÄÄÄÄÄÅë•»ÄÙ(ÄÄÄÄÄÄÄÄÄÄ°Ö›Ö•–Åùï—·—ï…πÖ±M—Ω…Öùï•…ïç—Ω…‰†§§Ä¸¸ÅÖ›Ö•–Å¡¡M—Ω…ÖùîπëΩç’µïπ—Ã†§Ï(ÄÄÄÅÙÅï±ÕîÅÏ(ÄÄÄÄÄÅë•»ÄÙÄ°Ö›Ö•–Åùï—Ω›π±ΩÖëÕ•…ïç—Ω…‰†§§Ä¸¸ÅÖ›Ö•–Å¡¡M—Ω…ÖùîπëΩç’µïπ—Ã†§Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞ÅÕï¿ÄÙÅA±Ö—ôΩ…¥π¡Ö—°Mï¡Ö…Ö—Ω»Ï(ÄÄÄÅô•πÖ∞Å¡…ïô•‡ÄÙÄúëÌë•»π¡Ö—°ÙëÌÕï¡ıïâ…•ô‰ëÌÕï¡ıIïçΩ…ë•πùÃëÕï¿ëÌâÖÕïı|ëÕ—Öµ¿úÏ((ÄÄÄÅŸÖ»ÅçÖπë•ëÖ—îÄÙÄúë¡…ïô•‡∏ëï·—ïπÕ•Ω∏úÏ(ÄÄÄÅôΩ»Ä°ŸÖ»Å∏ÄÙÄ»ÏÅ∏ÄÄƒ¿¿ÄòòÅÖ›Ö•–Å•±î°çÖπë•ëÖ—î§πï·•Õ—Ã†§ÏÅ∏¨¨§ÅÏ(ÄÄÄÄÄÅçÖπë•ëÖ—îÄÙÄúëÌ¡…ïô•·ı|ë∏∏ëï·—ïπÕ•Ω∏úÏ(ÄÄÄÅÙ(ÄÄÄÄººÅAÖ—°Ω±Ωù•çÖ∞Ä†‰‰Å…ïÕ—Ö…—ÃÅ•∏ÅΩπîÅÕïçΩπê§ËÅôÖ±∞ÅâÖç¨Å—ºÅµ•ç…ΩÕïçΩπëÃ∞(ÄÄÄÄººÅ›°•ç†ÅçÖππΩ–ÅçΩ±±•ëîÅ›•—†ÅÖπ‰ÅΩòÅ—°îÅπÖµïÃÅ—…•ïêÅÖâΩŸî∏(ÄÄÄÅ•òÄ°Ö›Ö•–Å•±î°çÖπë•ëÖ—î§πï·•Õ—Ã†§§ÅÏ(ÄÄÄÄÄÅçÖπë•ëÖ—îÄÙÄúëÌ¡…ïô•·ı|ëÌπΩ‹πµ•ç…ΩÕïçΩπëÕM•πçï¡Ωç°Ù∏ëï·—ïπÕ•Ω∏úÏ(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏ÅçÖπë•ëÖ—îÏ(ÄÅÙ((ÄÅ’—’…îÒŸΩ•ê¯Å}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞†(ÄÄÄÅ•π–Å•πëï‡∞ÅÏ(ÄÄÄÅâΩΩ∞Å≈’•ï—IïçΩŸï…‰ÄÙÅôÖ±Õî∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞Åç°Öππï±ÃÄÙÅ}ïôôïç—•Ÿï%¡—Ÿ°Öππï±ÃÏ(ÄÄÄÅ•òÄ°ç°Öππï±ÃÄÙÙÅπ’±∞ÅÒÅ•πëï‡ÄÄ¿ÅÒÅ•πëï‡Ä¯ÙÅç°Öππï±Ãπ±ïπù—†§Å…ï—’…∏Ï(ÄÄÄÄººÅQ•ç≠ï–Å%IMP∞ÅâïôΩ…îÅÖπ‰ÅÖ›Ö•–Æù◊üäwùPÅçΩëï‡Å…Ω’πêÄ»ùÃÅâ±Ωç≠ï»ËÅ›•—†Å—°î(ÄÄÄÄººÅ—•ç≠ï–Å—Ö≠ï∏ÅÖô—ï»Å—°îÅ…ïçΩ…ë•πúÅÕ—Ω¿Åâï±Ω‹∞Å—›ºÅΩŸï…±Ö¡¡•πúÅÕ›•—ç†(ÄÄÄÄººÅçÖ±±ÃÅçΩ’±êÅ…ïÕ’µîÅô…Ω¥Å—°Ö–ÅÖ›Ö•–Å•∏Åï•—°ï»ÅΩ…ëï»ÅÖπêÅ—°îÅ=1H(ÄÄÄÄººÅ•π—ïπ–ÅçΩ’±êÅ—Ö≠îÅ—°îÅπï›ï»Å—•ç≠ï–∞Å°•©Öç≠•πúÅ¡±ÖÂâÖç¨ÅâÖç¨Å—ºÅ—°î(ÄÄÄÄººÅç°Öππï∞Å—°îÅ’Õï»Å©’Õ–Å±ïô–∏(ÄÄÄÅô•πÖ∞Å—•ç≠ï–ÄÙÄ¨≠}•¡—ŸM›•—ç°Q•ç≠ï–Ï(ÄÄÄÅÖ›Ö•–Å}ç±ïÖ…·—ï…πÖ±%¡—Ÿ’ë•ΩΩ…Y•ëïΩM›•—ç††§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄººÅQ°•ÃÅÕ›•—ç†ÅΩ›πÃÅ—°îÅï……Ω»ÅùÖ—îÅπΩ‹Ä°ÑÅÕ’¡ï…ÕïëïêÅ±Öëëï»ùÃÅÕ—Ö—îÅëΩïÕ∏ù–(ÄÄÄÄººÅÕ’…Ÿ•Ÿî§∏Å5’—ïêÅ’π—•∞Å—°îÅπï‹Åµïë•ÑÅ•ÃÅΩ¡ïπïêÅâï±Ω‹ÏÅ—°îÅâ’…Õ–ÅëïâΩ’πçî(ÄÄÄÄººÅ…ïÕï—ÃÅ—Ωº∞ÅÕºÅ—°•ÃÅç°Öππï∞ÅçÖ∏Å…ï¡Ω…–Å•—ÃÅΩ›∏ÅôÖ•±’…î∏(ÄÄÄÅ}•¡—Ÿ……Ω…Õ5’—ïêÄÙÅ—…’îÏ(ÄÄÄÅ}±ÖÕ—%¡—Ÿ……Ω…M°Ω›∏ÄÙÅπ’±∞Ï(ÄÄÄÄººÅ=πîÅµÖç°•πîÅ—’πîµÕ—Ö…–Å¡ï»ÅM]%Q ∞ÅπΩ–Å¡ï»ÅM—…ïµ•ºÅçÖπë•ëÖ—îãßuÁ‚ùÁPÅ—°î(ÄÄÄÄººÅçÖπë•ëÖ—îÅ±Öëëï»Åâï±Ω‹Å•ÃÅ—°•ÃÅÕ›•—ç†ùÃÅΩ›∏Å°’π–∏ÅÅµÖç°•πîµë…•Ÿï∏(ÄÄÄÄººÅÕ—…ïµ•ºÅ…îµ—’πîÅÖ……•ŸïÃÅ°ï…îÅ›•—†Åï·¡ïç—Iï—’πîÅÕï–ÅÖπêÅ≠ïï¡ÃÅ•—Ã(ÄÄÄÄººÅï¡•ÕΩëîÏÅÑÅ…ïÖ∞ÅÈÖ¿Å…ïÕï—ÃÅ—°îÅµÖç°•πîÅÖπêÅ—Ö≠ïÃÅ—°îÅ¡•±∞Å›•—†Å•–∏(ÄÄÄÅô•πÖ∞Å›ÖÕIïçΩŸï…ÂIï—’πîÄÙÅ}•¡—Ÿ1•ŸïIïçΩŸï…‰πï·¡ïç—Iï—’πîÏ(ÄÄÄÅ}•¡—Ÿ1•ŸïIïçΩŸï…‰πΩπQ’πïM—Ö…—ïê†§Ï(ÄÄÄÅ•òÄ†Ö›ÖÕIïçΩŸï…ÂIï—’πî§Å}•¡—ŸIïçΩππïç—Qï·–πŸÖ±’îÄÙÅπ’±∞Ï(ÄÄÄÄººÅÅç°Öππï∞Åç°ÖπùîÅïπëÃÅ—°îÅç’……ïπ–Å…ïçΩ…ë•πúÄ°—°îÅÕ—…ïÖ¥Å•ëïπ—•—‰Åô±•¡Ã§∏(ÄÄÄÄººÅUπçΩπë•—•ΩπÖ∞ËÅ•–Åµ’Õ–ÅÖ±ÕºÅçÖπçï∞ÅÑÅÕ—Ö…–ÅÕ—•±∞ÅÖ›Ö•—•πúÅ•—ÃÅÕ—Ω…Öùî(ÄÄÄÄººÅÕï—’¿∞Å›°•ç†ÅÅ}•ÕIïçΩ…ë•πùÄÅ›Ω’±êÅπΩ–Å…ï¡Ω…–ÅÂï–∏(ÄÄÄÅÖ›Ö•–Å}Õ—Ω¡IïçΩ…ë•πú°’Õï…%π•—•Ö—ïêËÅôÖ±Õî§Ï(ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÅ}çÖπçï±Aïπë•πù%¡—ŸÖ—ç°’¿†§Ï((ÄÄÄÅ}°•ëï%¡—Ÿ°Öππï±M°ïï–†§Ï((ÄÄÄÅô•πÖ∞Åç°Öππï∞ÄÙÅç°Öππï±Õm•πëï·tÏ(ÄÄÄÅ}ç±ïÖ…	’ôôï…•πù%πë•çÖ—Ω»†§Ï(ÄÄÄÄººÅQ°îÅÈÖ¿Å¡Ö—†ÅπïŸï»Å…’πÃÅ}µÖÂâïIïÕ—Ω…ïIïÕ’µî∞ÅÕºÅ—°îÅ¡…ïŸ•Ω’ÃÅç°Öππï∞ùÃ(ÄÄÄÄººÅ…ïÕ’µîÅù’Ö…êÄ°ÑÅY=ÅµΩŸ•îÅµ•êµ…ïÕ’µî§Å›Ω’±êÅΩ—°ï…›•ÕîÅÕ—Ö‰ÅÖ…µïêÅÖπê(ÄÄÄÄººÅÕ’¡¡…ïÕÃÅ—°îÅ•πçΩµ•πúÅç°Öππï∞ùÃÅÕÖŸïÃ∏ÅMÖµîÅÕ›•—ç†µâΩ’πëÖ…‰Å…’±îÅÖÃ(ÄÄÄÄººÅ}±ΩÖëA±ÖÂ±•Õ—%πëï‡∏(ÄÄÄÅ}…ïÕ’µï]…•—ï’Ö…êπç±ïÖ»†§Ï(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}•¡—ŸM—Ö…—=Ÿï…ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ}•¡—ŸM—Ö…—=Ÿï…1ΩÖë•πúÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ}•¡—ŸM—Ö…—=Ÿï…Q•µï±•πïIï≈’ïÕ—ïêÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄººÅÅ≈’•ï–Å…ïçΩŸï…‰Å…îµ—’πîÅ•ÃÅπΩ–ÅÑÅÈÖ¿ËÅπºÅ—…ÖπÕ•—•Ω∏ÅΩŸï…±Ö‰∞Åπº(ÄÄÄÄÄÄººÅÈÖ¿ÅâÖππï»ãßuÁ‚ùÁPÅ—°îÅ…ïçΩππïç–Å¡•±∞Å•ÃÅ—°îÅΩπ±‰ÅπÖ……Ö—•Ω∏Ä°¡±Ö∏(ÄÄÄÄÄÄººÅ•πŸÖ…•Öπ–Äâ…ï—’πîÆù◊üäwùÄÅÈÖ¿àÏÅçΩëï‡Å…Ω’πêÄ»∞Åô•πë•πúÄƒ–§∏(ÄÄÄÄÄÅ}•ÕQ…ÖπÕ•—•Ωπ•πúÄÙÄÖ≈’•ï—IïçΩŸï…‰Ï(ÄÄÄÄÄÅ}—ŸMç…’âïπï…Ö—•Ω∏¨¨Ï(ÄÄÄÄÄÅ}—ŸâÖπëΩπMç…’à†§Ï(ÄÄÄÄÄÅ}ç’……ïπ—%¡—Ÿ%πëï‡ÄÙÅ•πëï‡Ï(ÄÄÄÄÄÅ}ç’……ïπ—°Öππï±9’µâï»ÄÙÅç°Öππï∞πç°Öππï±9’µâï»Ä¸¸Ä°•πëï‡Ä¨Äƒ§Ï(ÄÄÄÄÄÄººÅQ°îÅçΩ…πï»ÅâÖëùîÅ•ÃÅ¡Ö•π—ïêÅô…Ω¥Å—°•ÃÅ¡Ö•»ÏÅ›•—°Ω’–Å—°îÅπÖµîÅ•–Å≠ï¡–(ÄÄÄÄÄÄººÅÕ°Ω›•πúÅ—°îÅ±Ö’πç†Åç°Öππï∞Å’πëï»Å—°îÅπï‹Åç°Öππï∞ùÃÅπ’µâï»∏(ÄÄÄÄÄÅ}ç’……ïπ—°Öππï±9ÖµîÄÙÅç°Öππï∞ππÖµîÏ(ÄÄÄÅÙ§Ï(ÄÄÄÅ•òÄ†Ö≈’•ï—IïçΩŸï…‰§Å}Õ—Ö…—Q…ÖπÕ•—•Ωπ=Ÿï…±Ö‰†§Ï(ÄÄÄÄººÅ%ëïπ—•—‰Å¡Ö•π—ÃÅô…Ω¥Å—°îÅç°Öππï∞Å•—Õï±ò∞ÅÕºÅ•–Å•ÃÅçΩ……ïç–ÅâïôΩ…îÅÑ(ÄÄÄÄººÅÕ•πù±îÅâÂ—îÅΩòÅ—°îÅπï‹ÅÕ—…ïÖ¥Å°ÖÃÅÖ……•ŸïêÏÅ—°îÅù’•ëîÅô•±±ÃÅ•∏Åâï°•πêÅ•–∏(ÄÄÄÄººÅiÖ¡¡•πúÅ—ºÅΩ∏µëïµÖπêÅ…ï—•…ïÃÅ—°îÅ¡Öπï∞ÅΩ’—…•ù°–Æù◊üäwùPÅ•–Å°ÖÃÅπºÅ±•Ÿî(ÄÄÄÄººÅ•ëïπ—•—‰Å—ºÅ¡…ïÕïπ–∞ÅÖπêÅ±ïÖŸ•πúÅ•–Å’¿Å›Ω’±êÅëïÕç…•âîÅ—°îÅ›…ΩπúÅ•—ï¥∏(ÄÄÄÅ•òÄ°ç°Öππï∞π•Õ1•ŸîÄòòÄÖ≈’•ï—IïçΩŸï…‰§ÅÏ(ÄÄÄÄÄÅ}¡…ï¡Ö…ï%¡—Ÿ	Öππï…Ö—Ñ°ç°Öππï∞§Ï(ÄÄÄÄÄÅ}…Ö•Õï%¡—ŸiÖ¡	Öππï»†§Ï(ÄÄÄÄÄÄººÅQ°îÅù’•ëîÅôΩ±±Ω›ÃÅ›°Ö–Å•ÃÅ¡±ÖÂ•πú∞ÅÕºÅ…ïΩ¡ïπ•πúÅ•–Å±ÖπëÃÅΩ∏Å—°î(ÄÄÄÄÄÄººÅçÖ—ïùΩ…‰Å—°îÅç’……ïπ–Åç°Öππï∞ÅÖç—’Ö±±‰Åâï±ΩπùÃÅ—º∏ÅÅ¡ÖùïêÅ…•πúÅ•ÃÅ—°î(ÄÄÄÄÄÄººÅï·çï¡—•Ω∏ËÅ•–ÅÖ±…ïÖë‰Å≠πΩ›ÃÅ•—ÃÅΩ›∏ÅçÖ—ïùΩ…‰Åô…Ω¥Å—°îÅ…ïÕ¡ΩπÕî∞Å›°•ç†(ÄÄÄÄÄÄººÅÑÅÕ•πù±îÅç°Öππï∞ùÃÅù…Ω’¿ÅçÖ∏ù–ÅÖ±›ÖÂÃÅï·¡…ïÕÃÆù◊üäwùPÅÖ∏Äâ±∞àΩ’πçÖ—ïùΩ…•Èïê(ÄÄÄÄÄÄººÅ›•πëΩ‹Å›Ω’±êÅ≠ïï¿ÅπÖ……Ω›•πúÅ—°îÅù’•ëîÅ—ºÅ›°•ç°ïŸï»Åù…Ω’¿Å•–Å±ÖπëïêÅΩ∏∏(ÄÄÄÄÄÅ•òÄ†Ö}•¡—ŸiÖ¡AÖù•πùç—•Ÿî§Å}Öπç°Ω…%¡—Ÿ’•ëïÖ—ïùΩ…‰°ç°Öππï∞§Ï(ÄÄÄÅÙÅï±ÕîÅÏ(ÄÄÄÄÄÅ}°•ëï%¡—ŸiÖ¡	Öππï»†§Ï(ÄÄÄÅÙ((ÄÄÄÄººÅIïù•Õ—ï»Å—°îÅ•—ï¥Å›îù…îÅÕ›•—ç°•πúÅQ<Å•∏Å—°îÅ%AQXÅ›Ö—ç†Å°•Õ—Ω…‰∞Åï·Öç—±‰(ÄÄÄÄººÅÖÃÅ—°îÅπÖ—•ŸîÅQXÅ¡±ÖÂï»ÅëΩïÃÅâïôΩ…îÅïŸï…‰ÅπΩ∏µ±•ŸîÅÕ—Ö…–∏Å=π±‰Å—°îÅ•—ï¥(ÄÄÄÄººÅ—°îÅ’Õï»Å1U9!Å’ÕïêÅ—ºÅâîÅ…ïçΩ…ëïê∞ÅÕºÅÖ∏ÅÖ’—ºµÖëŸÖπçïêÅï¡•ÕΩëîÅ›…Ω—î(ÄÄÄÄººÅÑÅ…ïÕ’µîÅ¡ΩÕ•—•Ω∏Å—°Ö–ÅπºÅ°•Õ—Ω…‰Å…Ω‹ÅÖççΩ’π—ïêÅôΩ»ËÅ—°îÅΩπ—•π’î(ÄÄÄÄººÅ]Ö—ç°•πúÅÕ°ï±òÅ≠ï¡–Å¡Ω•π—•πúÅÖ–Å—°îÅ±Ö’πç†Åï¡•ÕΩëî∞ÅÖπêÅÑÅÕï…•ïÃµ›•ëî(ÄÄÄÄººÅ…ïµΩŸÖ∞Ä°›°•ç†Åô•πëÃÅï¡•ÕΩëïÃÅ—°…Ω’ù†Å—°îÅ°•Õ—Ω…‰§ÅçΩ’±ë∏ù–Å…ïÖç†Å—°î(ÄÄÄÄººÅ…ïÕ–ÅΩòÅ—°ï¥∏ÅUπÖ›Ö•—ïêÆù◊üäwùPÅ—°îÅÕ°ï±òÅçÖ∏ÅÕï——±îÅÑÅô…ÖµîÅ±Ö—î∞ÅÑÅÈÖ¿ÅçÖ∏ù–∏(ÄÄÄÅ•òÄ†Öç°Öππï∞π•Õ1•Ÿî§Å’πÖ›Ö•—ïê°}…ïçΩ…ë%¡—Ÿ]Ö—ç°Ω…°Öππï∞°ç°Öππï∞§§Ï((ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å}¡±ÖÂï»π¡Ö’Õî†§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ((ÄÄÄÅ•òÄ°M—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•ÕM—…ïµ•Ω°Öππï±U…∞°ç°Öππï∞π’…∞§§ÅÏ(ÄÄÄÄÄÄººÅIï—•…îÅ—°îÅΩ’—ùΩ•πúÅç°Öππï∞ùÃÅÕΩ’…çîÅ…Ω›ÃÅ9=\ÇÈ›y¯ßy–Åë’…•πúÅ—°îÅ…ïÕΩ±Ÿî(ÄÄÄÄÄÄººÅÖ›Ö•–Åâï±Ω‹Å—°îÅÕ°ïï–Åµ’Õ–ÅπΩ–ÅΩôôï»Å—°îÅ¡…ïŸ•Ω’ÃÅç°Öππï∞ùÃÅ±•π≠Ã(ÄÄÄÄÄÄººÄ°¡•ç≠•πúÅΩπîÅ›Ω’±êÅÖâΩ…–Å—°•ÃÅÕ›•—ç†ùÃÅ±Öëëï»ÅÖπêÅ¡±Ö‰Å—°îÅΩ±ê(ÄÄÄÄÄÄººÅç°Öππï∞Å’πëï»Å—°îÅπï‹Åç°Öππï∞ùÃÅ•ëïπ—•—‰§∏(ÄÄÄÄÄÅ}Õï—%¡—ŸMΩ’…çïÃ°π’±∞∞Åπ’±∞§Ï(ÄÄÄÄÄÄººÅ5•……Ω»Å—°îÅπÖ—•ŸîÅ¡Ö—†ËÅ—°îÅU$Å°ÖÃÅÖ±…ïÖë‰ÅçΩµµ•——ïêÅ—ºÅ—°îÅπï‹(ÄÄÄÄÄÄººÅç°Öππï∞∞ÅÕºÅç±ïÖ»Å—°îÅΩ’—ùΩ•πúÅÕ—…ïÖ¥ÅπΩ‹ãßuÁ‚ùÁPÅÑÅôÖ•±ïêÅΩ»Åïµ¡—‰(ÄÄÄÄÄÄººÅ…ïÕΩ±ŸîÅµ’Õ–ÅπΩ–Å±ïÖŸîÅ—°îÅ¡…ïŸ•Ω’ÃÅç°Öππï∞ùÃÅô…ΩÈï∏Åô…ÖµîÅÕ•——•πú(ÄÄÄÄÄÄººÅ’πëï»Å—°îÅπï‹Åç°Öππï∞ùÃÅ—•—±îΩ•πëï‡∏(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}¡±ÖÂï»πÕ—Ω¿†§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÄÄÄººÅM—…ïµ•ºµÖëëΩ∏Åç°Öππï∞ËÅ…ïÕΩ±ŸîÅ•—ÃÅçÖπë•ëÖ—îÅUI1ÃÅÖπêÅ›Ö±¨Å—°ï¥Å’π—•∞(ÄÄÄÄÄÄººÅΩπîÅ¡…Ωë’çïÃÅ¡±ÖÂâÖç¨ãßuÁ‚ùÁPÅ—°îÅÕÖµîÅÕï…•Ö∞Å±Öëëï»Å—°îÅ%AQXÅ¡…ïŸ•ï‹Å…’πÃ∏(ÄÄÄÄÄÄººÅÅÈÖ¿Å•ÃÅÖ∏Åï·¡±•ç•–Å¡±Ö‰Å•π—ïπ–∞ÅÕºÅÑÅçÖç°ïêµïµ¡—‰Å…ïÕΩ±ŸîÅ•Ã(ÄÄÄÄÄÄººÅ…îµç°ïç≠ïêÅô…ïÕ†Å•πÕ—ïÖêÅΩòÅ…ï¡±ÖÂ•πúÅÑÅÕ—Ö±îÄâπΩ—°•πúà∏(ÄÄÄÄÄÅô•πÖ∞ÅçÖπë•ëÖ—ïÃÄÙÅÖ›Ö•–ÅM—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•πÕ—Öπçîπ…ïÕΩ±ŸïÖπë•ëÖ—ïÃ†(ÄÄÄÄÄÄÄÅç°Öππï∞π’…∞∞(ÄÄÄÄÄÄÄÅ…ïô…ïÕ°%ôµ¡—‰ËÅ—…’î∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÄººÅQ°îÅçÖπë•ëÖ—ïÃÅëΩ’â±îÅÖÃÅ—°îÅÕΩ’…çîÅÕ°ïï–ùÃÅ…Ω›ÃÅôΩ»Å—°•ÃÅç°Öππï∞∏(ÄÄÄÄÄÅ}Õï—%¡—ŸMΩ’…çïÃ°ç°Öππï∞π’…∞∞ÅçÖπë•ëÖ—ïÃ§Ï(ÄÄÄÄÄÅŸÖ»ÅΩ¡ïπïêÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅôΩ»Ä°ŸÖ»Å§ÄÙÄ¿ÏÅ§ÄÅçÖπë•ëÖ—ïÃπ±ïπù—†ÏÅ§¨¨§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÄÄÅô•πÖ∞Å’…∞ÄÙÅçÖπë•ëÖ—ïÕm•tπ’…∞Ï(ÄÄÄÄÄÄÄÄÄÅ}•¡—Ÿ•ÖúπΩπQ’πïM—Ö…–°ç°Öππï∞ππÖµî∞Å’…∞∞Å•Õ1•ŸîËÅç°Öππï∞π•Õ1•Ÿî§Ï(ÄÄÄÄÄÄÄÄÄÅ}•¡—Ÿ•ÖúππΩ—î†ùÕ—…ïµ•ºÅçÖπë•ëÖ—îÄëÌ§Ä¨Ä≈ÙºëÌçÖπë•ëÖ—ïÃπ±ïπù—°Ùú§Ï(ÄÄÄÄÄÄÄÄÄÅô•πÖ∞ÅΩ¨ÄÙÅÖ›Ö•–Å}—…Â=¡ïπ1•ŸïM—…ïÖ¥†(ÄÄÄÄÄÄÄÄÄÄÄÅ’…∞∞(ÄÄÄÄÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅç°Öππï∞π¡±ÖÂâÖç≠!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÄººÅÅπï›ï»ÅÕ›•—ç†ÅÕ’¡ï…ÕïëïêÅ—°•ÃÅ±Öëëï»Åµ•êµ¡…ΩâîËÅ•—ÃÅÕ’ççïÕÃÅΩ»(ÄÄÄÄÄÄÄÄÄÄººÅôÖ•±’…îÅâï±ΩπùÃÅ—ºÅ—°îÅΩ—°ï»Åç°Öππï∞ùÃÅ¡±ÖÂâÖç¨ÅπΩ‹ãßuÁ‚ùÁPÅëΩ∏ù–(ÄÄÄÄÄÄÄÄÄÄººÅç…ïë•–Å•–Å°ï…î∏(ÄÄÄÄÄÄÄÄÄÅ•òÄ°—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÄÄÅ•òÄ°Ω¨§ÅÏ(ÄÄÄÄÄÄÄÄÄÄÄÅM—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•πÕ—ÖπçîπµÖ…≠]•ππï»°ç°Öππï∞π’…∞∞Å’…∞§Ï(ÄÄÄÄÄÄÄÄÄÄÄÅ•òÄ°µΩ’π—ïêÄòòÅ}ç’……ïπ—MΩ’…çï%πëï‡ÄÑÙÅ§§ÅÏ(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕï—M—Ö—î††§ÄÙ¯Å}ç’……ïπ—MΩ’…çï%πëï‡ÄÙÅ§§Ï(ÄÄÄÄÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÄÄÄÄÅΩ¡ïπïêÄÙÅ—…’îÏ(ÄÄÄÄÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙÅô•πÖ±±‰ÅÏ(ÄÄÄÄÄÄÄÄººÅ=π±‰Å—°•ÃÅ±Öëëï»ùÃÅΩ›∏Å¡…Ωâ•πúÅ•ÃÅÕ•±ïπçïêÏÅÑÅπï›ï»ÅÕ›•—ç†ÅΩ›πÃÅ—°î(ÄÄÄÄÄÄÄÄººÅô±ÖúÅô…Ω¥Å°ï…îÄ°•–ÅÕï—ÃÅ•–ÅÖùÖ•∏ÅΩ∏Åïπ—…‰§∏(ÄÄÄÄÄÄÄÅ•òÄ°—•ç≠ï–ÄÙÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å}•¡—Ÿ……Ω…Õ5’—ïêÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ°—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï(ÄÄÄÄÄÅ•òÄ†ÖΩ¡ïπïê§ÅÏ(ÄÄÄÄÄÄÄÄººÅïÖêÅç°Öππï∞ÇÈ›y¯ßy–ÅôΩ…ùï–Å—°îÅÕ—Ö±îÅçÖπë•ëÖ—ïÃÅÕºÅÑÅ±Ö—ï»ÅÖ——ïµ¡–(ÄÄÄÄÄÄÄÄººÅ…îµ…ïÕΩ±ŸïÃ∏ÅA±ÖÂâÖç¨Å©’Õ–ÅÕ—ÖÂÃÅëΩ›∏∞Å±•≠îÅÑÅëïÖêÅ4ÕTÅç°Öππï∞∏(ÄÄÄÄÄÄÄÅM—…ïµ•Ω%¡—ŸMï…Ÿ•çîπ•πÕ—Öπçîπ•πŸÖ±•ëÖ—î°ç°Öππï∞π’…∞§Ï(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅπºÅ¡±ÖÂÖâ±îÅÕ—…ïÖ¥ÅôΩ»ÄëÌç°Öππï∞ππÖµïÙú§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙÅï±ÕîÅÏ(ÄÄÄÄÄÄººÅA±Ö•∏Å4ÕTΩa—…ïÖ¥Åç°Öππï∞ËÅÕ•πù±îÅ±•π¨∞ÅπºÅÕΩ’…çîÅÕ°ïï–∏Å!ïÖëï…ÃÅÖ…î(ÄÄÄÄÄÄººÅ¡ï»µç°Öππï∞Ä°—°îÅ¡±ÖÂ±•Õ–Åëïç±Ö…ïÃÅ—°ï¥Å¡ï»Åïπ—…‰§∞ÅÕºÅ—°ï‰ÅçΩµîÅô…Ω¥(ÄÄÄÄÄÄººÅ—°îÅç°Öππï∞Å…Ö—°ï»Å—°Ö∏Å›•ëùï–π°——¡!ïÖëï…Ã∏(ÄÄÄÄÄÅ}Õï—%¡—ŸMΩ’…çïÃ°π’±∞∞Åπ’±∞§Ï(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅ}•¡—Ÿ•ÖúπΩπQ’πïM—Ö…–†(ÄÄÄÄÄÄÄÄÄÅç°Öππï∞ππÖµî∞(ÄÄÄÄÄÄÄÄÄÅç°Öππï∞π’…∞∞(ÄÄÄÄÄÄÄÄÄÅ•Õ1•ŸîËÅç°Öππï∞π•Õ1•Ÿî∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅô•πÖ∞Åµïë•ÑÄÙÅµ¨π5ïë•Ñ†(ÄÄÄÄÄÄÄÄÄÅç°Öππï∞π’…∞∞(ÄÄÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅç°Öππï∞π¡±ÖÂâÖç≠!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄººÅQ°îÅΩ’—ùΩ•πúÅÕ—…ïÖ¥Å•ÃÅ—Ω…∏ÅëΩ›∏Ä°¡Ö’ÕîÅÖâΩŸî§ÏÅïŸï…Â—°•πúÅµ¡ÿ(ÄÄÄÄÄÄÄÄººÅ…ï¡Ω…—ÃÅô…Ω¥Å°ï…îÅ•ÃÅ—°•ÃÅç°Öππï∞ùÃ∞Å•πç±’ë•πúÅÑÅôÖÕ–ÅôÖ•±’…îÅ—°Ö–(ÄÄÄÄÄÄÄÄººÅ±ÖπëÃÅ›°•±îÅΩ¡ï∏†§Å•ÃÅÕ—•±∞ÅÖ›Ö•—•πú∏(ÄÄÄÄÄÄÄÅ}•¡—Ÿ……Ω…Õ5’—ïêÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}Ω¡ïπ5ïë•Ñ°µïë•Ñ∞Å¡±Ö‰ËÅ—…’î∞Å±•ŸïM—…ïÖ¥ËÅç°Öππï∞π•Õ1•Ÿî§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅ%AQXÅç°Öππï∞ÅÕ›•—ç†ÅôÖ•±ïêËÄëîú§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ((ÄÄÄÅ•òÄ†ÖµΩ’π—ïêÅÒÅ—•ç≠ï–ÄÑÙÅ}•¡—ŸM›•—ç°Q•ç≠ï–§Å…ï—’…∏Ï((ÄÄÄÄººÅÖ……‰Å—°îÅÖ’ë•ºÅç°Ω•çîÅΩπ—ºÅ—°îÅπï‹Åï¡•ÕΩëîÄ°Õï…•ïÃÅµïµΩ…‰§∏Å•…îÅÖπê(ÄÄÄÄººÅôΩ…ùï–ËÅ•–Å›Ö•—ÃÅôΩ»Å—°îÅπï‹ÅÕΩ’…çîùÃÅ—…Öç≠ÃÅ—°ï∏ÅµÖ—ç°ïÃÅâ‰Å±Öπù’ÖùîÏ(ÄÄÄÄººÅm—•ç≠ï—tÅ•ÃÅ—°•ÃÅÕ›•—ç†ùÃÅùïπï…Ö—•Ω∏ÅÕºÅÑÅπï›ï»ÅÕ›•—ç†ÅÖâÖπëΩπÃÅ•–∏(ÄÄÄÅ•òÄ°}•Õ%¡—ŸMï…•ïÕΩπ—ï·–§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}Ö¡¡±Â%¡—Ÿ’ë•ΩA…ïôï…ïπçî°—•ç≠ï–§§Ï(ÄÄÄÅÙ((ÄÄÄÄººÅ•…ïç—±‰Å—…•ùùï»Å—…ÖπÕ•—•Ω∏ÅΩŸï…±Ö‰Åç±ïÖπ’¿ÅÕï≈’ïπçî∏(ÄÄÄÄººÅUπ±•≠îÅëïâ…•êÅç°Öππï∞ÅÕ›•—ç°•πúÄ°›°ï…îÅ}¡±ÖÂM’àÅ±•Õ—ïπï»Å°Öπë±ïÃ(ÄÄÄÄººÅ—°îÅ—…ÖπÕ•—•Ω∏Å¡°ÖÕïÃÅÖô—ï»Äù¡±ÖÂ•πúúÅô•…ïÃ§∞Å%AQXÅUI1ÃÅÖ…îÅÖ±…ïÖë‰(ÄÄÄÄººÅ…ïÕΩ±ŸïêÅÕºÅ›îÅÕ≠•¿Å¡°ÖÕîÄƒÅÖπêÅùºÅÕ—…Ö•ù°–Å—ºÅ—°îÅ…ïŸïÖ∞Å¡°ÖÕî∏(ÄÄÄÄººÅQ°•ÃÅ¡…ïŸïπ—ÃÅ—°îÅΩŸï…±Ö‰Åô…Ω¥Åùï——•πúÅÕ—’ç¨Å•òÅ—°îÅ¡±ÖÂ•πúÅïŸïπ–(ÄÄÄÄººÅëΩïÕ∏ù–Åô•…îÅ…ï±•Öâ±‰ÅôΩ»Å!1LΩ±•ŸîÅÕ—…ïÖµÃ∏(ÄÄÄÅ}—…ÖπÕ•—•ΩπM—Ω¡Q•µï»¸πçÖπçï∞†§Ï(ÄÄÄÅ}—…ÖπÕ•—•ΩπA°ÖÕïQ•µï»¸πçÖπçï∞†§Ï(ÄÄÄÅ}—…ÖπÕ•—•ΩπA°ÖÕîÄÙÄ»Ï(ÄÄÄÅ}—…ÖπÕ•—•ΩπA°ÖÕî…M—Ö…—ïêÄÙÅÖ—ïQ•µîππΩ‹†§Ï(ÄÄÄÅÕï—M—Ö—î††§ÅÏ(ÄÄÄÄÄÅ}•ÕQ…ÖπÕ•—•Ωπ•πúÄÙÅôÖ±ÕîÏ(ÄÄÄÅÙ§Ï(ÄÄÄÅ}—…ÖπÕ•—•ΩπM—Ω¡Q•µï»ÄÙÅQ•µï»°çΩπÕ–Å’…Ö—•Ω∏°µ•±±•ÕïçΩπëÃËÄƒ‘¿¿§∞Ä†§ÅÏ(ÄÄÄÄÄÅ}…Ö•πâΩ›Ωπ—…Ω±±ï»πÕ—Ω¿†§Ï(ÄÄÄÄÄÅ}—…ÖπÕ•—•ΩπI’ππ•πúÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ}…Ö•πâΩ›ç—•ŸîÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÅ•òÄ°µΩ’π—ïê§ÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÄÄÅÙ§Ï((ÄÄÄÄººÅQ°îÅ9\Åç°Öππï∞ÅµÖ‰Å•—Õï±òÅÖ±…ïÖë‰ÅâîÅ…ïçΩ…ë•πúÄ°ïπù•πîÅçÖ¡—’…ïÃÅ≠ïï¿(ÄÄÄÄººÅ…’ππ•πúÅÖç…ΩÕÃÅÈÖ¡Ã§ãßuÁ‚ùÁPÅ…ï¡Ö•π–Å—°îÅIïçΩ…êÅâ’——Ω∏Åô…Ω¥ÅπÖ—•ŸîÅ—…’—†∏(ÄÄÄÅ•òÄ°}ïπù•πï±Öù=∏§Å’πÖ›Ö•—ïê°}…ïô…ïÕ°πù•πïIïçΩ…ë•πùM—Ö—î†§§Ï(ÄÅÙ((ÄÄºººÅ=¡ï∏Åm’…±tÅÖπêÅ›Ö•–Å’π—•∞Å•–ÅëïµΩπÕ—…Öâ±‰Å¡±ÖÂÃÄ°ÑÅëïçΩëïêÅŸ•ëïºÅÕ•ÈîÅΩ»(ÄÄºººÅÖëŸÖπç•πúÅ¡ΩÕ•—•Ω∏§ÅΩ»ÅëïµΩπÕ—…Öâ±‰ÅôÖ•±ÃÄ°¡±ÖÂï»Åï……Ω»∞ÅΩ¡ï∏†§Å—°…Ω‹∞(ÄÄºººÅΩ»Å—°îÅ—•µïΩ’–Æù◊üäwùPÅ±•ŸîÅÕ—…ïÖµÃÅçÖ∏ÅÕ—Ö±∞Å›•—°Ω’–ÅïŸï»Åï……Ω…•πú§∏ÅUÕïêÅâ‰(ÄÄºººÅ—°îÅM—…ïµ•ºÅç°Öππï∞Å±Öëëï»Å—ºÅëïç•ëîÅ›°ï—°ï»Å—ºÅ—…‰Å—°îÅπï·–ÅçÖπë•ëÖ—î∏(ÄÅ’—’…îÒâΩΩ∞¯Å}—…Â=¡ïπ1•ŸïM—…ïÖ¥†(ÄÄÄÅM—…•πúÅ’…∞∞ÅÏ(ÄÄÄÅ’…Ö—•Ω∏Å—•µïΩ’–ÄÙÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄƒ»§∞(ÄÄÄÅ5Ö¿ÒM—…•πú∞ÅM—…•πú¯¸Å°——¡!ïÖëï…Ã∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÄººÅŸï…‰Å±•ŸîÅµïë•ÑÅ…ï¡±Öçïµïπ–ÅïπëÃÅ—°îÅ…ïçΩ…ë•πú∞ÅπΩ–Å©’Õ–ÅÑÅç°Öππï∞ÅÈÖ¿Ë(ÄÄÄÄººÅ¡•ç≠•πúÅÖπΩ—°ï»Å…Ω‹Å•∏Å—°îÅMΩ’…çïÃÅÕ°ïï–Å±ÖπëÃÅ°ï…îÅŸ•Ñ(ÄÄÄÄººÅ}Õ›•—ç°QΩ%¡—ŸMΩ’…çî∞ÅÖπêÅµ¡ÿÅµÖ≠ïÃÅπºÅ¡…Ωµ•ÕîÅÖâΩ’–ÅÅÕ—…ïÖ¥µ…ïçΩ…ëÄ(ÄÄÄÄººÅÖç…ΩÕÃÅÖ∏ÅΩ¡ï∏†§ãßuÁ‚ùÁPÅ•–ÅµÖ‰Å≈’•ï—±‰ÅÕ—Ω¿ÅΩ»ÅΩŸï…›…•—îÅ—°îÅô•±îÅ›°•±î(ÄÄÄÄººÅÅ}•ÕIïçΩ…ë•πùÄÅÕ—•±∞Åç±Ö•µÃÅ•–Å•ÃÅ…’ππ•πú∏ÅIïë’πëÖπ–Ä°ÖπêÅ°Ö…µ±ïÕÃ§ÅΩ∏(ÄÄÄÄººÅ—°îÅ}Õ›•—ç°QΩ%¡—Ÿ°Öππï∞Å¡Ö—†∞Å›°•ç†ÅÖ±…ïÖë‰ÅÕ—Ω¡¡ïêÅâïôΩ…îÅ•—ÃÅ±Öëëï»∏(ÄÄÄÅÖ›Ö•–Å}Õ—Ω¡IïçΩ…ë•πú°’Õï…%π•—•Ö—ïêËÅôÖ±Õî§Ï((ÄÄÄÅô•πÖ∞ÅçΩµ¡±ï—ï»ÄÙÅΩµ¡±ï—ï»ÒâΩΩ∞¯†§Ï(ÄÄÄÅŸΩ•êÅô•π•Õ†°âΩΩ∞ÅΩ¨§ÅÏ(ÄÄÄÄÄÅ•òÄ†ÖçΩµ¡±ï—ï»π•ÕΩµ¡±ï—ïê§ÅçΩµ¡±ï—ï»πçΩµ¡±ï—î°Ω¨§Ï(ÄÄÄÅÙ((ÄÄÄÄººÅAΩÕ•—•Ω∏Ωï……Ω»ÅïŸïπ—ÃÅΩπ±‰ÅçΩ’π–ÅÖô—ï»ÅΩ¡ï∏†§Å…ï—’…πÃãßuÁ‚ùÁPÅ—°îÅÕ—…ïÖ¥ÅçÖ∏(ÄÄÄÄººÅÕ—•±∞ÅâîÅë…Ö•π•πúÅ—°îÅ¡…ïŸ•Ω’ÃÅµïë•ÑùÃÅ¡ΩÕ•—•ΩπÃÄ°Ω»ÅÑÅëïÖêÅΩ’—ùΩ•πú(ÄÄÄÄººÅç°Öππï∞ùÃÅ≈’ï’ïêÅï……Ω»§ÅâïôΩ…îÅ—°ï∏∏Åïπ’•πîÅ¡…îµΩ¡ï∏ÅôÖ•±’…ïÃÅÖ…î(ÄÄÄÄººÅçΩŸï…ïêÅâ‰Å—°îÅΩ¡ï∏†§Å—°…Ω‹ÅÖπêÅ—°îÅ—•µïΩ’–∏(ÄÄÄÅŸÖ»ÅΩ¡ïπΩπîÄÙÅôÖ±ÕîÏ(ÄÄÄÅô•πÖ∞ÅÕ’âÃÄÙÄÒM—…ïÖµM’âÕç…•¡—•Ω∏˘l(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πï……Ω»π±•Õ—ï∏†°|§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°Ω¡ïπΩπî§Åô•π•Õ†°ôÖ±Õî§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π›•ë—†π±•Õ—ï∏†°‹§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°Ω¡ïπΩπîÄòòÅ‹ÄÑÙÅπ’±∞ÄòòÅ‹Ä¯Ä¿§Åô•π•Õ†°—…’î§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π¡ΩÕ•—•Ω∏π±•Õ—ï∏†°¿§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°Ω¡ïπΩπîÄòòÅ¿Ä¯Å’…Ö—•Ω∏πÈï…º§Åô•π•Õ†°—…’î§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÅtÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄººÅA±Ö∏Åô•πë•πúÅ@‹ËÅçÖπë•ëÖ—îÅΩ¡ïπÃÅ’ÕïêÅ—ºÅë…Ω¿Å—°îÅç°Öππï∞ùÃÅΩ›∏(ÄÄÄÄÄÄººÅ°ïÖëï…ÃãßuÁ‚ùÁPÅ—°îÅΩπîÅΩ¡ï∏Å¡Ö—†Å—°Ö–Å±ΩÕ–Å—°ï¥∏ÅÖ……‰Å—°ï¥Å±•≠îÅïŸï…‰(ÄÄÄÄÄÄººÅΩ—°ï»ÅΩ¡ï∏ÅëΩïÃ∏(ÄÄÄÄÄÅÖ›Ö•–Å}Ω¡ïπ5ïë•Ñ†(ÄÄÄÄÄÄÄÅµ¨π5ïë•Ñ°’…∞∞Å°——¡!ïÖëï…ÃËÅ°——¡!ïÖëï…Ã§∞(ÄÄÄÄÄÄÄÅ¡±Ö‰ËÅ—…’î∞(ÄÄÄÄÄÄÄÅ±•ŸïM—…ïÖ¥ËÅ—…’î∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅΩ¡ïπΩπîÄÙÅ—…’îÏ(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†ùA±ÖÂï»ËÅÕ—…ïµ•ºÅçÖπë•ëÖ—îÅôÖ•±ïêÅ—ºÅΩ¡ï∏ËÄëîú§Ï(ÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî§Ï(ÄÄÄÅÙ(ÄÄÄÅô•πÖ∞ÅΩ¨ÄÙÅÖ›Ö•–ÅçΩµ¡±ï—ï»πô’—’…îπ—•µïΩ’–°—•µïΩ’–∞ÅΩπQ•µïΩ’–ËÄ†§ÄÙ¯ÅôÖ±Õî§Ï(ÄÄÄÅôΩ»Ä°ô•πÖ∞ÅÃÅ•∏ÅÕ’âÃ§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°ÃπçÖπçï∞†§§Ï(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏ÅΩ¨Ï(ÄÅÙ((ÄÄºººÅ=¡ïπÃÅΩπîÅY=ÅçÖπë•ëÖ—îÅ›•—†Å—°îÅ…ïÖ∞Åµïë•Ñµ≠•–Å¡±ÖÂï»ÅÖπêÅ≠ïï¡ÃÅ—°Ö–(ÄÄºººÅï·Öç–Å¡±ÖÂï»ÅÕïÕÕ•Ω∏ÅΩ∏ÅÕ’ççïÕÃ∏ÅUπ±•≠îÅ—°îÅΩ±êÅÖ…–Å!Å¡…ΩâîÅ—°•ÃÅ°ÖÃ(ÄÄºººÅπºÅŸÖ±•ëÖ—•Ω∏Ω¡±ÖÂâÖç¨Å…ÖçîËÅëïçΩëïêÅŸ•ëïºÅΩ»ÅÖëŸÖπç•πúÅ¡ΩÕ•—•Ω∏ÅçΩµµ•—Ã(ÄÄºººÅ—°îÅçÖπë•ëÖ—îÏÅÖ∏Åï……Ω»∞ÅΩ¡ï∏Å—°…Ω‹∞ÅΩ»ÅâΩ’πëïêÅÕ—Ö…—’¿ÅÕ—Ö±∞Å…ï©ïç—ÃÅ•–∏(ÄÄºººÅïâ…•êµ…ïÕΩ±ŸïêÅçÖπë•ëÖ—ïÃÅÕ≠•¿Å—°îÅëïçΩëîÅ¡…Ωâî∏ÅQ°îÅëïâ…•êÅA$Åµ•π—ïê(ÄÄºººÄ°ÖπêÅ—°ï…ïâ‰ÅŸΩ’ç°ïêÅôΩ»§Å—°îÅUI0ÅµΩµïπ—ÃÅÖùº∞ÅÕºÅ—°îÅ¡…ΩâîùÃÅëïÖêµ±•π¨(ÄÄºººÅ¡…Ω—ïç—•Ω∏Å•ÃÅ…ïë’πëÖπ–Æù◊üäwùPÅÖπêÅ•—ÃÅçΩÕ–Å•ÃÅ…ïÖ∞ËÅçΩµµ•——•πúÅΩ∏Å—°îÅô•…Õ–(ÄÄºººÅëïçΩëïêÅô…ÖµîÅµïÖπÃÅ—°îÅ…ïÕ’µîÅÕïï¨Å±ÖπëÃÅµ•êµÕ—Ö…—’¿µâ’…Õ–ÅÖ–Ä¿∞Å›°•ç†(ÄÄºººÅµ¡ÿÅΩ∏ÅÑÅçΩ±êÅÕ—…ïÖ¥ÅÖπÕ›ï…ÃÅâ‰Å…ïÕ—Ö…—•πúÄ°—°îÅµÖÕ≠ïêµÕïï¨Å…ï¡…º§∏(ÄÄºººÅÅ¡±Ö•∏ÅΩ¡ï∏Å•πÕ—ïÖêÅÖççï¡—ÃÅΩ∏Åë’…Ö—•Ω∏Ä°°ïÖëï»Åµï—ÖëÖ—Ñ∞Å¡…îµëïçΩëî§∞(ÄÄºººÅÕºÅ—°îÅ…ïÕ’µîÅÕïï¨ÅôΩ±ëÃÅ•π—ºÅÕ—Ö…—’¿ÅÖÃÄââïù•∏Å°ï…îàãßuÁ‚ùÁPÅ—°îÅ¡…îµ±Öëëï»(ÄÄºººÅ—•µ•πúÅ—°Ö–ÅÖ±›ÖÂÃÅ›Ω…≠ïê∏ÅëëΩ∏Åë•…ïç–ÅUI1ÃÄ°—°îÅÕ—Ö±îµçÖç°ïêµ±•π¨(ÄÄºººÅç±ÖÕÃÅ—°îÅ¡…ΩâîÅï·•Õ—ÃÅôΩ»§Å≠ïï¿Å—°îÅô’±∞ÅŸÖ±•ëÖ—•Ω∏∏(ÄÅ’—’…îÒâΩΩ∞¯Å}Ω¡ïπM—Ö…—’¡ïâ…•ë•…ïç–†(ÄÄÄÅM—…•πúÅ’…∞∞ÅÏ(ÄÄÄÅ5Ö¿ÒM—…•πú∞ÅM—…•πú¯¸Å°——¡!ïÖëï…Ã∞(ÄÄÄÅQΩ……ïπ–¸ÅÕΩ’…çî∞(ÄÄÄÅ•π–¸ÅÕΩ’…çï%πëï‡∞(ÄÄÄÅ•π–ÅÖ——ïµ¡–ÄÙÄƒ∞(ÄÄÄÅ•π–ÅµÖ·——ïµ¡—ÃÄÙÄƒ∞(ÄÄÄÅ’…Ö—•Ω∏Å—•µïΩ’–ÄÙÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄƒ»§∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞ÅÕ—Ω¡›Ö—ç†ÄÙÅM—Ω¡›Ö—ç††§∏πÕ—Ö…–†§Ï(ÄÄÄÅô•πÖ∞ÅçΩµ¡±ï—ï»ÄÙÅΩµ¡±ï—ï»ÒâΩΩ∞¯†§Ï(ÄÄÄÅŸÖ»ÅçÖπë•ëÖ—ï’…Ö—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅŸÖ»Åâ’ôôï…ïëµΩ’π–ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅô•πÖ∞ÅÕΩ’…çï•ï±ëÃÄÙÅ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°ÕΩ’…çï%πëï‡∞ÅÕΩ’…çî§Ï(ÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}Ω¡ï∏Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄùÖ——ïµ¡–ÙëÖ——ïµ¡–ºëµÖ·——ïµ¡—ÃÄëÕΩ’…çï•ï±ëÃÅ…Ω’—îıëïâ…•ë}ë•…ïç–Äú(ÄÄÄÄÄÄù—•µïΩ’—5ÃÙëÌ—•µïΩ’–π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄ§Ï(ÄÄÄÅŸΩ•êÅô•π•Õ†°âΩΩ∞ÅΩ¨∞ÅM—…•πúÅ…ïÖÕΩ∏§ÅÏ(ÄÄÄÄÄÅ•òÄ°çΩµ¡±ï—ï»π•ÕΩµ¡±ï—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}…ïÕ’±–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄùÖ——ïµ¡–ÙëÖ——ïµ¡–ºëµÖ·——ïµ¡—ÃÄëÕΩ’…çï•ï±ëÃÅΩ¨ÙëΩ¨Å…ïÖÕΩ∏Ùë…ïÖÕΩ∏Äú(ÄÄÄÄÄÄÄÄùï±Ö¡Õïë5ÃÙëÌÕ—Ω¡›Ö—ç†πï±Ö¡Õïë5•±±•ÕïçΩπëÕÙÄú(ÄÄÄÄÄÄÄÄùë’…Ö—•Ωπ5ÃÙëÌçÖπë•ëÖ—ï’…Ö—•Ω∏π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅçΩµ¡±ï—ï»πçΩµ¡±ï—î°Ω¨§Ï(ÄÄÄÅÙ((ÄÄÄÄººÅÅëïÖêÅëïâ…•êÅ±•π¨Ä°ëï±ï—ïêÅ—Ω……ïπ–Å…Öçî∞Åï·¡•…ïêÅ—Ω≠ï∏§Åï……Ω…ÃÅΩ»(ÄÄÄÄººÅÕï…ŸïÃÅÕΩµï—°•πúÅ›•—†ÅπºÅ¡Ö…ÕïÖâ±îÅë’…Ö—•Ω∏ãßuÁ‚ùÁPÅï•—°ï»Å›Ö‰Å—°îÅ±Öëëï»(ÄÄÄÄººÅÖëŸÖπçïÃÅ—ºÅ—°îÅπï·–ÅçÖπë•ëÖ—îÅï·Öç—±‰Å±•≠îÅÑÅôÖ•±ïêÅ¡…Ωâî∏(ÄÄÄÅô•πÖ∞ÅÕ’âÃÄÙÄÒM—…ïÖµM’âÕç…•¡—•Ω∏˘l(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πï……Ω»π±•Õ—ï∏†°ï……Ω»§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°πë…Ω•ëIïπëï…ï…M—Ö…—’¡Ö±±âÖç¨π•ÕIïπëï…ï…Ö•±’…î°ï……Ω»§Äòò(ÄÄÄÄÄÄÄÄÄÄÄÅπë…Ω•ëIïπëï…ï…M—Ö…—’¡Ö±±âÖç¨πÕ°Ω’±ë…¥†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•Õπë…Ω•êËÅA±Ö—ôΩ…¥π•Õπë…Ω•ê∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•Õπë…Ω•ëQÿËÅA±Ö—ôΩ…µU—•∞π•Õπë…Ω•ëQŸÖç°ïê∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅµΩëîËÅ}Öπë…Ω•ëY•ëïΩIïπëï…ï…5Ωëî∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÖ±…ïÖëÂYÖ±•ëÖ—ïêËÅ}…ïπëï…ï…YÖ±•ëÖ—ïëΩ…MïÕÕ•Ω∏∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅôÖ±±âÖç≠%πA…Ωù…ïÕÃËÅ}…ïπëï…ï…Ö±±âÖç≠%πA…Ωù…ïÕÃ∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§§ÅÏ(ÄÄÄÄÄÄÄÄÄÄººÅIïπëï…ï»µâΩ’πêÅôÖ•±’…î∞ÅΩ›πïêÅâ‰Å—°îÅ…ïπëï…ï»ÅôÖ±±âÖç¨ãßuÁ‚ùÁPÅÕÖµî(ÄÄÄÄÄÄÄÄÄÄººÅçΩπ—…Öç–ÅÖÃÅ—°îÅ¡…ΩâîÅ¡Ö—†Ä°ÕïîÅ}—…Â=¡ïπM—Ö…—’¡YΩê§∏(ÄÄÄÄÄÄÄÄÄÅô•π•Õ†°—…’î∞Äù…ïπëï…ï…}ôÖ±±âÖç≠}ëïôï……ïêú§Ï(ÄÄÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞Äù¡±ÖÂï…}ï……Ω»ú§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πë’…Ö—•Ω∏π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅçÖπë•ëÖ—ï’…Ö—•Ω∏ÄÙÅŸÖ±’îÏ(ÄÄÄÄÄÄÄÅ•òÄ°ŸÖ±’îÄ¯Å’…Ö—•Ω∏πÈï…º§Åô•π•Õ†°—…’î∞Äùë’…Ö—•Ωπ}≠πΩ›∏ú§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÄººÅ’…Ö—•Ωπ±ïÕÃÅµïë•ÑÄ°ÕΩµîÅ5AµQLΩ4…QLÅÖπêÅπΩ∏µÕïï≠Öâ±îÅ¡…Ωù…ïÕÕ•Ÿî(ÄÄÄÄÄÄººÅô•±ïÃ§ÅπïŸï»Å¡’â±•Õ°ïÃÅÑÅë’…Ö—•Ω∏ÇÈ›y¯ßy–ÅÖççï¡–ÅΩ∏ÅëïçΩëïê∞ÅÖëŸÖπç•πú(ÄÄÄÄÄÄººÅŸ•ëïºÅ±•≠îÅ—°îÅ¡…ΩâîÅ›Ω’±ê∞ÅΩ»Å—°îÅ›Ö—ç°ëΩúÅïŸïπ—’Ö±±‰Å≠•±±ÃÅÑ(ÄÄÄÄÄÄººÅÕ—…ïÖ¥Å—°Ö–Å•ÃÅŸ•Õ•â±‰Å¡±ÖÂ•πú∏Å’…Ö—•Ω∏ÅÖ±µΩÕ–ÅÖ±›ÖÂÃÅÖ……•ŸïÃ(ÄÄÄÄÄÄººÅô•…Õ–∞ÅÕºÅ—°•ÃÅôÖ±±âÖç¨ÅëΩïÃÅπΩ–Åëï±Ö‰Å—°îÅçΩµµΩ∏ÅçÖÕî∏(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π›•ë—†π±•Õ—ï∏†°›•ë—†§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ†°›•ë—†Ä¸¸Ä¿§Ä¯Ä¿ÄòòÅ}¡±ÖÂï»πÕ—Ö—îπ¡ΩÕ•—•Ω∏Ä¯Å’…Ö—•Ω∏πÈï…º§ÅÏ(ÄÄÄÄÄÄÄÄÄÅô•π•Õ†°—…’î∞ÄùëïçΩëïë}Ÿ•ëïºú§Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π¡ΩÕ•—•Ω∏π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°ŸÖ±’îÄ¯Å’…Ö—•Ω∏πÈï…ºÄòòÄ°}¡±ÖÂï»πÕ—Ö—îπ›•ë—†Ä¸¸Ä¿§Ä¯Ä¿§ÅÏ(ÄÄÄÄÄÄÄÄÄÅô•π•Õ†°—…’î∞ÄùëïçΩëïë}Ÿ•ëïºú§Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πâ’ôôï»π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅâ’ôôï…ïëµΩ’π–ÄÙÅŸÖ±’îÏ(ÄÄÄÄÄÅÙ§∞(ÄÄÄÅtÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅÖ›Ö•–Å}Ω¡ïπ5ïë•Ñ°µ¨π5ïë•Ñ°’…∞∞Å°——¡!ïÖëï…ÃËÅ°——¡!ïÖëï…Ã§∞Å¡±Ö‰ËÅ—…’î§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıΩ¡ïπ}ï·çï¡—•Ω∏Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅï·çï¡—•Ω∏ÙëÌîπ…’π—•µïQÂ¡ïÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞ÄùΩ¡ïπ}ï·çï¡—•Ω∏ú§Ï(ÄÄÄÅÙ(ÄÄÄÄººÅMÖµîÅÕ±Ω‹µŸï…Õ’ÃµëïÖêÅë•Õ—•πç—•Ω∏ÅÖÃÅ—°îÅ¡…ΩâîÅ¡Ö—†ËÅÑÅ±•π¨Å›°ΩÕî(ÄÄÄÄººÅâ’ôôï»Å≠ïï¡ÃÅù…Ω›•πúÅ•ÃÅëΩ›π±ΩÖë•πú∞ÅπΩ–ÅëïÖêãßuÁ‚ùÁPÅôÖ•±•πúÅ•–Å›Ω’±êÅâ’…∏(ÄÄÄÄººÅÑÅ¡ΩÕÕ•â±‰ÅÕ•πù±îµ’ÕîÅëïâ…•êÅ±•π¨∏Å·—ïπêÅ•∏ÅÕ—ï¡ÃÅ’¿Å—ºÅ—°îÅÕÖµîÅçÖ¿∏(ÄÄÄÅçΩπÕ–Åï·—ïπëM—ï¿ÄÙÅ’…Ö—•Ω∏°ÕïçΩπëÃËÄÃ§Ï(ÄÄÄÅçΩπÕ–ÅµÖ·]Ö•–ÄÙÅ’…Ö—•Ω∏°ÕïçΩπëÃËÄ–‘§Ï(ÄÄÄÅŸÖ»Å±ÖÕ—	’ôôï…5Ö…¨ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅŸÖ»ÅΩ¨ÄÙÅôÖ±ÕîÏ(ÄÄÄÅ›°•±îÄ°—…’î§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Å…ïµÖ•π•πúÄÙÅ—•µïΩ’–Ä¥ÅÕ—Ω¡›Ö—ç†πï±Ö¡ÕïêÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅΩ¨ÄÙÅÖ›Ö•–ÅçΩµ¡±ï—ï»πô’—’…îπ—•µïΩ’–†(ÄÄÄÄÄÄÄÄÄÅ…ïµÖ•π•πúÄ¯Å’…Ö—•Ω∏πÈï…ºÄ¸Å…ïµÖ•π•πúÄËÅï·—ïπëM—ï¿∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙÅΩ∏ÅQ•µïΩ’—·çï¡—•Ω∏ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°â’ôôï…ïëµΩ’π–Ä¯Å±ÖÕ—	’ôôï…5Ö…¨ÄòòÅÕ—Ω¡›Ö—ç†πï±Ö¡ÕïêÄÅµÖ·]Ö•–§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ±ÖÕ—	’ôôï…5Ö…¨ÄÙÅâ’ôôï…ïëµΩ’π–Ï(ÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı›Ö—ç°ëΩù}ï·—ïπêÅ¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅï±Ö¡Õïë5ÃÙëÌÕ—Ω¡›Ö—ç†πï±Ö¡Õïë5•±±•ÕïçΩπëÕÙÄú(ÄÄÄÄÄÄÄÄÄÄÄÄùâ’ôôï…ïë5ÃÙëÌâ’ôôï…ïëµΩ’π–π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞Äù—•µïΩ’–ú§Ï(ÄÄÄÄÄÄÄÅΩ¨ÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÅôΩ»Ä°ô•πÖ∞ÅÕ’àÅ•∏ÅÕ’âÃ§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°Õ’àπçÖπçï∞†§§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ†ÖΩ¨§ÅÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}¡±ÖÂï»πÕ—Ω¿†§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏ÅΩ¨Ï(ÄÅÙ((ÄÅ’—’…îÒâΩΩ∞¯Å}—…Â=¡ïπM—Ö…—’¡YΩê†(ÄÄÄÅM—…•πúÅ’…∞∞ÅÏ(ÄÄÄÅ’…Ö—•Ω∏Å—•µïΩ’–ÄÙÅçΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄƒ»§∞(ÄÄÄÅ5Ö¿ÒM—…•πú∞ÅM—…•πú¯¸Å°——¡!ïÖëï…Ã∞(ÄÄÄÅQΩ……ïπ–¸ÅÕΩ’…çî∞(ÄÄÄÅ•π–¸ÅÕΩ’…çï%πëï‡∞(ÄÄÄÅ•π–ÅÖ——ïµ¡–ÄÙÄƒ∞(ÄÄÄÅ•π–ÅµÖ·——ïµ¡—ÃÄÙÄƒ∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞ÅÕ—Ω¡›Ö—ç†ÄÙÅM—Ω¡›Ö—ç††§∏πÕ—Ö…–†§Ï(ÄÄÄÅô•πÖ∞ÅçΩµ¡±ï—ï»ÄÙÅΩµ¡±ï—ï»ÒâΩΩ∞¯†§Ï(ÄÄÄÅŸÖ»ÅÖ…µïêÄÙÅôÖ±ÕîÏ(ÄÄÄÅŸÖ»ÅŸ•ëïΩ]•ë—†ÄÙÄ¿Ï(ÄÄÄÅŸÖ»Å¡ΩÕ•—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅŸÖ»ÅçÖπë•ëÖ—ï’…Ö—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅQ•µï»¸Åë’…Ö—•Ωπ…ÖçïQ•µï»Ï(ÄÄÄÅô•πÖ∞Å•Õ•ΩM—…ïÖµÃÄÙÅM—Ö…—’¡M—…ïÖµAΩ±•ç‰π•Õ•ΩM—…ïÖµÃ†(ÄÄÄÄÄÅÖëëΩπ%êËÅÕΩ’…çî¸πÕ—…ïµ•ΩëëΩπ%ê∞(ÄÄÄÄÄÅÕΩ’…çï9ÖµîËÅÕΩ’…çî¸πÕΩ’…çî∞(ÄÄÄÄÄÅ’…∞ËÅ’…∞∞(ÄÄÄÄ§Ï(ÄÄÄÅô•πÖ∞ÅÕΩ’…çï•ï±ëÃÄÙÅ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°ÕΩ’…çï%πëï‡∞ÅÕΩ’…çî§Ï(ÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}Ω¡ï∏Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄùÖ——ïµ¡–ÙëÖ——ïµ¡–ºëµÖ·——ïµ¡—ÃÄëÕΩ’…çï•ï±ëÃÅÖ•ºÙë•Õ•ΩM—…ïÖµÃÄú(ÄÄÄÄÄÄù—•µïΩ’—5ÃÙëÌ—•µïΩ’–π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄ§Ï(ÄÄÄÅŸΩ•êÅô•π•Õ†°âΩΩ∞ÅΩ¨∞ÅM—…•πúÅ…ïÖÕΩ∏§ÅÏ(ÄÄÄÄÄÅ•òÄ°çΩµ¡±ï—ï»π•ÕΩµ¡±ï—ïê§Å…ï—’…∏Ï(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}…ïÕ’±–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄùÖ——ïµ¡–ÙëÖ——ïµ¡–ºëµÖ·——ïµ¡—ÃÄëÕΩ’…çï•ï±ëÃÅΩ¨ÙëΩ¨Å…ïÖÕΩ∏Ùë…ïÖÕΩ∏Äú(ÄÄÄÄÄÄÄÄùï±Ö¡Õïë5ÃÙëÌÕ—Ω¡›Ö—ç†πï±Ö¡Õïë5•±±•ÕïçΩπëÕÙÅ›•ë—†ÙëŸ•ëïΩ]•ë—†Äú(ÄÄÄÄÄÄÄÄù¡ΩÕ•—•Ωπ5ÃÙëÌ¡ΩÕ•—•Ω∏π•π5•±±•ÕïçΩπëÕÙÄú(ÄÄÄÄÄÄÄÄùë’…Ö—•Ωπ5ÃÙëÌçÖπë•ëÖ—ï’…Ö—•Ω∏π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅçΩµ¡±ï—ï»πçΩµ¡±ï—î°Ω¨§Ï(ÄÄÄÅÙ((ÄÄÄÅŸΩ•êÅµÖÂâïΩµµ•–†§ÅÏ(ÄÄÄÄÄÄººÅ]•ë—†ÅÖ±ΩπîÅçÖ∏ÅâîÅ¡Ö…ÕïêÅô…Ω¥ÅçΩπ—Ö•πï»Åµï—ÖëÖ—ÑÅâïôΩ…îÅÑÅëïçΩëï»Å°ÖÃ(ÄÄÄÄÄÄººÅ¡…Ωë’çïêÅÖπÂ—°•πú∏ÅIï≈’•…•πúÅ—°îÅµïë•ÑÅç±Ωç¨Å—ºÅÖëŸÖπçîÅÖÃÅ›ï±∞Å≠ïï¡Ã(ÄÄÄÄÄÄººÅµï—ÖëÖ—ÑµΩπ±‰ÅÖπêÅ¡ï…µÖπïπ—±‰µâ’ôôï…•πúÅçÖπë•ëÖ—ïÃÅâï°•πêÅ—°îÅùÖ—î∏(ÄÄÄÄÄÅ•òÄ†ÖÖ…µïêÅÒÅŸ•ëïΩ]•ë—†ÄÙÄ¿ÅÒÅ¡ΩÕ•—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…º§Å…ï—’…∏Ï(ÄÄÄÄÄÅ•òÄ°M—Ö…—’¡M—…ïÖµAΩ±•ç‰π•Õ1•≠ï±Â•ΩM—…ïÖµÕ……Ω…M±Ö—î†(ÄÄÄÄÄÄÄÅÖëëΩπ%êËÅÕΩ’…çî¸πÕ—…ïµ•ΩëëΩπ%ê∞(ÄÄÄÄÄÄÄÅÕΩ’…çï9ÖµîËÅÕΩ’…çî¸πÕΩ’…çî∞(ÄÄÄÄÄÄÄÅ’…∞ËÅ’…∞∞(ÄÄÄÄÄÄÄÅë’…Ö—•Ω∏ËÅçÖπë•ëÖ—ï’…Ö—•Ω∏∞(ÄÄÄÄÄÄ§§ÅÏ(ÄÄÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞ÄùÖ•ΩÕ—…ïÖµÕ}ï……Ω…}Õ±Ö—îú§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ°•Õ•ΩM—…ïÖµÃÄòòÅçÖπë•ëÖ—ï’…Ö—•Ω∏ÄÙÅ’…Ö—•Ω∏πÈï…º§ÅÏ(ÄÄÄÄÄÄÄÄººÅA…Ωù…ïÕÕ•ŸîÅÕΩ’…çïÃÅçÖ∏Å¡’â±•Õ†Åë’…Ö—•Ω∏Å©’Õ–ÅÖô—ï»Å¡±ÖÂâÖç¨ÅÕ—Ö…—Ã∏(ÄÄÄÄÄÄÄÄººÅ•ŸîÅ—°Ö–Åµï—ÖëÖ—ÑÅÑÅâΩ’πëïêÅç°ÖπçîÅ—ºÅï·¡ΩÕîÅ%=M—…ïÖµÃúÅÕ°Ω…–∞(ÄÄÄÄÄÄÄÄººÅëïçΩëÖâ±îÅï……Ω»ÅÕ±Ö—îÏÅ’π≠πΩ›∏µë’…Ö—•Ω∏Å…ïÖ∞ÅÕ—…ïÖµÃÅÕ—•±∞Å¡…Ωçïïê∏(ÄÄÄÄÄÄÄÅë’…Ö—•Ωπ…ÖçïQ•µï»Ä¸¸ÙÅQ•µï»°çΩπÕ–Å’…Ö—•Ω∏°ÕïçΩπëÃËÄƒ§∞Ä†§ÅÏ(ÄÄÄÄÄÄÄÄÄÅô•πÖ∞Å•ÕM±Ö—îÄÙÅM—Ö…—’¡M—…ïÖµAΩ±•ç‰π•Õ1•≠ï±Â•ΩM—…ïÖµÕ……Ω…M±Ö—î†(ÄÄÄÄÄÄÄÄÄÄÄÅÖëëΩπ%êËÅÕΩ’…çî¸πÕ—…ïµ•ΩëëΩπ%ê∞(ÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çï9ÖµîËÅÕΩ’…çî¸πÕΩ’…çî∞(ÄÄÄÄÄÄÄÄÄÄÄÅ’…∞ËÅ’…∞∞(ÄÄÄÄÄÄÄÄÄÄÄÅë’…Ö—•Ω∏ËÅçÖπë•ëÖ—ï’…Ö—•Ω∏∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅô•π•Õ††(ÄÄÄÄÄÄÄÄÄÄÄÄÖ•ÕM±Ö—î∞(ÄÄÄÄÄÄÄÄÄÄÄÅ•ÕM±Ö—îÄ¸ÄùÖ•ΩÕ—…ïÖµÕ}ï……Ω…}Õ±Ö—îúÄËÄùëïçΩëïë}Ÿ•ëïºú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅÙ§Ï(ÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅô•π•Õ†°—…’î∞ÄùëïçΩëïë}Ÿ•ëïºú§Ï(ÄÄÄÅÙ((ÄÄÄÅŸÖ»Åâ’ôôï…ïëµΩ’π–ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅô•πÖ∞ÅÕ’âÃÄÙÄÒM—…ïÖµM’âÕç…•¡—•Ω∏˘l(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πï……Ω»π±•Õ—ï∏†°ï……Ω»§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ†ÖÖ…µïê§Å…ï—’…∏Ï(ÄÄÄÄÄÄÄÄººÅ∏Åï·¡±•ç•–µ…ïπëï…ï»ÅÕ—Ö…—’¿ÅôÖ•±’…îÅ•ÃÅΩ›πïêÅâ‰Å—°îÅ…ïπëï…ï»(ÄÄÄÄÄÄÄÄººÅôÖ±±âÖç¨Ä°}…ïπëï…ï…M—Ö…—’¡……Ω…M’àÅÕïïÃÅ—°•ÃÅÕÖµîÅïŸïπ–§ËÅ•–(ÄÄÄÄÄÄÄÄººÅë•Õ¡ΩÕïÃÅÖπêÅ…ïâ’•±ëÃÅ—°îÅ¡±ÖÂï»∞Å—°ï∏Å…ïΩ¡ïπÃÅQ!%LÅµïë•ÑÅΩ∏Å—°î(ÄÄÄÄÄÄÄÄººÅÖ’—ΩµÖ—•åÅ…ïπëï…ï»∏ÅÖ•±•πúÅ—°îÅçÖπë•ëÖ—îÅ°ï…îÅ›Ω’±êÅ…ÖçîÅ—›º(ÄÄÄÄÄÄÄÄººÅΩ¡ïπÃÅΩ∏ÅΩπîÅÕ’…ôÖçîÆù◊üäwùPÅ—°îÅ±Öëëï»ÅÖëŸÖπç•πúÅΩ∏ÅÑÅ¡±ÖÂï»Åâï•πú(ÄÄÄÄÄÄÄÄººÅë•Õ¡ΩÕïêÇÈ›y¯ßy–ÅÖπêÅ—°îÅôÖ•±’…îÅ•ÃÅ…ïπëï…ï»µâΩ’πê∞ÅπΩ–ÅÕΩ’…çîµâΩ’πê∞(ÄÄÄÄÄÄÄÄººÅÕºÅïŸï…‰ÅΩ—°ï»ÅçÖπë•ëÖ—îÅ›Ω’±êÅôÖ•∞Å•ëïπ—•çÖ±±‰ÅÖπÂ›Ö‰∏Åççï¡–(ÄÄÄÄÄÄÄÄººÅ—°îÅçÖπë•ëÖ—îÅÖπêÅ±ï–Å—°îÅôÖ±±âÖç¨Åô•π•Õ†Å•—ÃÅ…ïçΩŸï…‰∏(ÄÄÄÄÄÄÄÅ•òÄ°πë…Ω•ëIïπëï…ï…M—Ö…—’¡Ö±±âÖç¨π•ÕIïπëï…ï…Ö•±’…î°ï……Ω»§Äòò(ÄÄÄÄÄÄÄÄÄÄÄÅπë…Ω•ëIïπëï…ï…M—Ö…—’¡Ö±±âÖç¨πÕ°Ω’±ë…¥†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•Õπë…Ω•êËÅA±Ö—ôΩ…¥π•Õπë…Ω•ê∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•Õπë…Ω•ëQÿËÅA±Ö—ôΩ…µU—•∞π•Õπë…Ω•ëQŸÖç°ïê∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅµΩëîËÅ}Öπë…Ω•ëY•ëïΩIïπëï…ï…5Ωëî∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÖ±…ïÖëÂYÖ±•ëÖ—ïêËÅ}…ïπëï…ï…YÖ±•ëÖ—ïëΩ…MïÕÕ•Ω∏∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅôÖ±±âÖç≠%πA…Ωù…ïÕÃËÅ}…ïπëï…ï…Ö±±âÖç≠%πA…Ωù…ïÕÃ∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§§ÅÏ(ÄÄÄÄÄÄÄÄÄÅô•π•Õ†°—…’î∞Äù…ïπëï…ï…}ôÖ±±âÖç≠}ëïôï……ïêú§Ï(ÄÄÄÄÄÄÄÄÄÅ…ï—’…∏Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞Äù¡±ÖÂï…}ï……Ω»ú§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π›•ë—†π±•Õ—ï∏†°›•ë—†§ÅÏ(ÄÄÄÄÄÄÄÅŸ•ëïΩ]•ë—†ÄÙÅ›•ë—†Ä¸¸Ä¿Ï(ÄÄÄÄÄÄÄÅµÖÂâïΩµµ•–†§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥π¡ΩÕ•—•Ω∏π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅ¡ΩÕ•—•Ω∏ÄÙÅŸÖ±’îÏ(ÄÄÄÄÄÄÄÅµÖÂâïΩµµ•–†§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πë’…Ö—•Ω∏π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅçÖπë•ëÖ—ï’…Ö—•Ω∏ÄÙÅŸÖ±’îÏ(ÄÄÄÄÄÄÄÅµÖÂâïΩµµ•–†§Ï(ÄÄÄÄÄÅÙ§∞(ÄÄÄÄÄÅ}¡±ÖÂï»πÕ—…ïÖ¥πâ’ôôï»π±•Õ—ï∏†°ŸÖ±’î§ÅÏ(ÄÄÄÄÄÄÄÅâ’ôôï…ïëµΩ’π–ÄÙÅŸÖ±’îÏ(ÄÄÄÄÄÅÙ§∞(ÄÄÄÅtÏ(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄººÅ…¥ÅâïôΩ…îÅΩ¡ï∏ËÅÑÅôÖÕ–Å±ΩçÖ∞Ω8Å…ïÕ¡ΩπÕîÅçÖ∏Å…ïπëï»Å•—ÃÅô•…Õ–Åô…Öµî(ÄÄÄÄÄÄººÅâïôΩ…îÅΩ¡ï∏†§ÅçΩµ¡±ï—ïÃ∏Å%π•—•Ö∞ÅÕ—Ö…—’¿Å°ÖÃÅπºÅ¡…ïŸ•Ω’Ãµµïë•ÑÅïŸïπ—ÃÏ(ÄÄÄÄÄÄººÅÕ’âÕï≈’ïπ–ÅÖ——ïµ¡—ÃÅ’ÕîÅΩ¡ï∏†§ùÃÅµïë•ÑÅ…ïÕï–Å—ºÅïÕ—Öâ±•Õ†Å—°îÅâΩ’πëÖ…‰∏(ÄÄÄÄÄÅÖ…µïêÄÙÅ—…’îÏ(ÄÄÄÄÄÅÖ›Ö•–Å}Ω¡ïπ5ïë•Ñ°µ¨π5ïë•Ñ°’…∞∞Å°——¡!ïÖëï…ÃËÅ°——¡!ïÖëï…Ã§∞Å¡±Ö‰ËÅ—…’î§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÄººÅ·çï¡—•Ω∏ÅÕ—…•πùÃÅô…Ω¥Åµïë•ÑÅâÖç≠ïπëÃÅµÖ‰ÅïµâïêÅÕ•ùπïêÅÕ—…ïÖ¥ÅUI1Ã∏(ÄÄÄÄÄÄººÅQ°îÅ…’π—•µîÅ—Â¡îÅ•ÃÅïπΩ’ù†Å—ºÅë•Õ—•πù’•Õ†ÅΩ¡ï∏ÅôÖ•±’…ïÃÅÕÖôï±‰∏(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıΩ¡ïπ}ï·çï¡—•Ω∏Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅï·çï¡—•Ω∏ÙëÌîπ…’π—•µïQÂ¡ïÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞ÄùΩ¡ïπ}ï·çï¡—•Ω∏ú§Ï(ÄÄÄÅÙ(ÄÄÄÄººÅQ°îÅâÖÕîÅ—•µïΩ’–Å•ÃÅôΩ»ÅëïÖêÅÕΩ’…çïÃÄ°πºÅï……Ω»∞ÅπºÅëÖ—Ñ§∏ÅÅÕΩ’…çî(ÄÄÄÄººÅ—°Ö–Å•ÃÅëïµΩπÕ—…Öâ±‰ÅÕ—•±∞ÅëΩ›π±ΩÖë•πúãßuÁ‚ùÁPÅ•—ÃÅâ’ôôï»Å≠ïï¡ÃÅù…Ω›•πúãßuÁ‚ùÁP(ÄÄÄÄººÅ•ÃÅÕ±Ω‹∞ÅπΩ–ÅëïÖêÄ°±Ö…ùîÄ—,Å…ïµ’‡∞ÅçΩ±êÅ8∞ÅÕ±Ω‹Åëïâ…•êÅ¡ïï…•πú§Ï(ÄÄÄÄººÅôÖ•±•πúÅ•–Å›Ω’±êÅâ’…∏ÅÑÅ¡ΩÕÕ•â±‰ÅÕ•πù±îµ’ÕîÅ±•π¨ÅÖπêÅôÖ±∞Å—ºÅÑ(ÄÄÄÄººÅ±Ω›ï»µ…Öπ≠ïêÅÕΩ’…çî∏Å·—ïπêÅ•∏ÅÕ°Ω…–ÅÕ—ï¡ÃÅ›°•±îÅâÂ—ïÃÅ≠ïï¿ÅÖ……•Ÿ•πú∞(ÄÄÄÄººÅâΩ’πëïêÅâ‰ÅÑÅ°Ö…êÅçÖ¿∏(ÄÄÄÅçΩπÕ–Åï·—ïπëM—ï¿ÄÙÅ’…Ö—•Ω∏°ÕïçΩπëÃËÄÃ§Ï(ÄÄÄÅçΩπÕ–ÅµÖ·]Ö•–ÄÙÅ’…Ö—•Ω∏°ÕïçΩπëÃËÄ–‘§Ï(ÄÄÄÅŸÖ»Å±ÖÕ—	’ôôï…5Ö…¨ÄÙÅ’…Ö—•Ω∏πÈï…ºÏ(ÄÄÄÅŸÖ»ÅΩ¨ÄÙÅôÖ±ÕîÏ(ÄÄÄÅ›°•±îÄ°—…’î§ÅÏ(ÄÄÄÄÄÅô•πÖ∞Å…ïµÖ•π•πúÄÙÅ—•µïΩ’–Ä¥ÅÕ—Ω¡›Ö—ç†πï±Ö¡ÕïêÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅΩ¨ÄÙÅÖ›Ö•–ÅçΩµ¡±ï—ï»πô’—’…îπ—•µïΩ’–†(ÄÄÄÄÄÄÄÄÄÅ…ïµÖ•π•πúÄ¯Å’…Ö—•Ω∏πÈï…ºÄ¸Å…ïµÖ•π•πúÄËÅï·—ïπëM—ï¿∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙÅΩ∏ÅQ•µïΩ’—·çï¡—•Ω∏ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°â’ôôï…ïëµΩ’π–Ä¯Å±ÖÕ—	’ôôï…5Ö…¨ÄòòÅÕ—Ω¡›Ö—ç†πï±Ö¡ÕïêÄÅµÖ·]Ö•–§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ±ÖÕ—	’ôôï…5Ö…¨ÄÙÅâ’ôôï…ïëµΩ’π–Ï(ÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı›Ö—ç°ëΩù}ï·—ïπêÅ¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅï±Ö¡Õïë5ÃÙëÌÕ—Ω¡›Ö—ç†πï±Ö¡Õïë5•±±•ÕïçΩπëÕÙÄú(ÄÄÄÄÄÄÄÄÄÄÄÄùâ’ôôï…ïë5ÃÙëÌâ’ôôï…ïëµΩ’π–π•π5•±±•ÕïçΩπëÕÙú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅô•π•Õ†°ôÖ±Õî∞Äù—•µïΩ’–ú§Ï(ÄÄÄÄÄÄÄÅΩ¨ÄÙÅôÖ±ÕîÏ(ÄÄÄÄÄÄÄÅâ…ïÖ¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÅÙ(ÄÄÄÅë’…Ö—•Ωπ…ÖçïQ•µï»¸πçÖπçï∞†§Ï(ÄÄÄÅôΩ»Ä°ô•πÖ∞ÅÕ’àÅ•∏ÅÕ’âÃ§ÅÏ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°Õ’àπçÖπçï∞†§§Ï(ÄÄÄÅÙ(ÄÄÄÅ•òÄ†ÖΩ¨§ÅÏ(ÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÅÖ›Ö•–Å}¡±ÖÂï»πÕ—Ω¿†§Ï(ÄÄÄÄÄÅÙÅçÖ—ç†Ä°|§ÅÌÙ(ÄÄÄÅÙ(ÄÄÄÅ…ï—’…∏ÅΩ¨Ï(ÄÅÙ((ÄÄºººÅM—Ö…—’¿µΩπ±‰ÅÖ’—ΩµÖ—•åÅôÖ•±ΩŸï»ÅôΩ»ÅM—…ïµ•ºΩE’•ç¨ÅA±Ö‰ÅY=∏ÅÖπë•ëÖ—ïÃ(ÄÄºººÅ…ïµÖ•∏Åâï°•πêÅ—°îÅ¡±ÖÂï»Å±ΩÖë•πúÅÕ’…ôÖçîÅ’π—•∞Å—°îÅÖç—’Ö∞Å¡±ÖÂï»ÅëïçΩëïÃ(ÄÄºººÅΩπî∏ÅQ°îÅÕ’ççïÕÕô’∞ÅUI0Å•ÃÅπïŸï»Å…ïΩ¡ïπïê∞Å›°•ç†Å•ÃÅïÕÕïπ—•Ö∞ÅôΩ»(ÄÄºººÅÕ•πù±îµ’ÕîÅÖπêÅô•…Õ–µ…ï≈’ïÕ–µ%@µâΩ’πêÅëïâ…•êÅ±•π≠Ã∏(ÄÅ’—’…îÒâΩΩ∞¯Å}Ω¡ïπ%π•—•Ö±YΩë]•—°Ö•±ΩŸï»†(ÄÄÄÅM—…•πúÅ•π•—•Ö±U…∞∞ÅÏ(ÄÄÄÅ5Ö¿ÒM—…•πú∞ÅM—…•πú¯¸Å°——¡!ïÖëï…Ã∞(ÄÄÄÅâΩΩ∞Å•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïêÄÙÅôÖ±Õî∞(ÄÅÙ§ÅÖÕÂπåÅÏ(ÄÄÄÅô•πÖ∞ÅÕΩ’…çïÃÄÙÅ}ïôôïç—•ŸïMΩ’…çïÃÏ(ÄÄÄÅô•πÖ∞ÅçΩπ—ïπ—QÂ¡îÄÙÅ}ïôôïç—•ŸïΩπ—ïπ—QÂ¡îÏ(ÄÄÄÅô•πÖ∞Å•ÕYΩêÄÙÅçΩπ—ïπ—QÂ¡îÄÙÙÄùµΩŸ•îúÅÒÅçΩπ—ïπ—QÂ¡îÄÙÙÄùÕï…•ïÃúÏ(ÄÄÄÅ•òÄ†Ö•ÕYΩê§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıâÂ¡ÖÕÃÅ¡±Ö—ôΩ…¥ıô±’——ï»Å…ïÖÕΩ∏ıπΩπ}ŸΩêÄú(ÄÄÄÄÄÄÄÄùçΩπ—ïπ—QÂ¡îÙëÌçΩπ—ïπ—QÂ¡îÄ¸¸Äù’π≠πΩ›∏ùÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Å}—…Â=¡ïπM—Ö…—’¡YΩê°•π•—•Ö±U…∞∞Å°——¡!ïÖëï…ÃËÅ°——¡!ïÖëï…Ã§Ï(ÄÄÄÅÙ((ÄÄÄÅ}Õï—M—Ö…—’¡Ö—ïç—•Ÿî°—…’î§Ï(ÄÄÄÅ•òÄ°ÕΩ’…çïÃÄÙÙÅπ’±∞ÅÒÅÕΩ’…çïÃπ•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıâïù•∏Å¡±Ö—ôΩ…¥ıô±’——ï»ÅçΩπ—ïπ—QÂ¡îÙëçΩπ—ïπ—QÂ¡îÄú(ÄÄÄÄÄÄÄÄùÕΩ’…çïΩ’π–Ù¿Å¡Ω±•ç‰ıÕ•πù±ï}çÖπë•ëÖ—îú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅô•πÖ∞ÅΩ¨ÄÙÅÖ›Ö•–Å}—…Â=¡ïπM—Ö…—’¡YΩê°•π•—•Ö±U…∞∞Å°——¡!ïÖëï…ÃËÅ°——¡!ïÖëï…Ã§Ï(ÄÄÄÄÄÄººÅÅÕ’ççïÕÕô’∞ÅçÖπë•ëÖ—îÅÕ—ÖÂÃÅùÖ—ïêÅ—°…Ω’ù†Å…ïÕ’µîΩ—…Öç¨Å…ïÕ—Ω…Ö—•Ω∏(ÄÄÄÄÄÄººÅ•∏Å—°îÅçÖ±±ï»∏ÅÖ•±’…îÅµ’Õ–Å…ï±ïÖÕîÅ—°îÅÕ’…ôÖçîÅâïôΩ…îÅ…Ω’—îÅç±ïÖπ’¿∏(ÄÄÄÄÄÅ•òÄ†ÖΩ¨§Å}Õï—M—Ö…—’¡Ö—ïç—•Ÿî°ôÖ±Õî§Ï(ÄÄÄÄÄÅ…ï—’…∏ÅΩ¨Ï(ÄÄÄÅÙ((ÄÄÄÅô•πÖ∞Å…’±ïÃÄÙÅ›•ëùï–πÕ—Ö…—’¡Ö•±ΩŸï…πÖâ±ïê(ÄÄÄÄÄÄÄÄ¸ÅÖ›Ö•–ÅM—Ω…ÖùïMï…Ÿ•çîπùï—E’•ç≠A±ÖÂI’±ïÃ†(ÄÄÄÄÄÄÄÄÄÄÄÅ•Õ5ΩŸ•îËÅçΩπ—ïπ—QÂ¡îÄÙÙÄùµΩŸ•îú∞(ÄÄÄÄÄÄÄÄÄÄ§(ÄÄÄÄÄÄÄÄËÅπ’±∞Ï(ÄÄÄÅô•πÖ∞Å—…Â9ï·–ÄÙÅ…’±ïÃ¸π—…Â9ï·—=πÖ•±’…îÄ¸¸ÅôÖ±ÕîÏ(ÄÄÄÅô•πÖ∞ÅµÖ·——ïµ¡—ÃÄÙÅ—…Â9ï·–Ä¸Å…’±ïÃÑπµÖ·——ïµ¡—Ãπç±Öµ¿†ƒ∞Äƒ¿§ÄËÄƒÏ(ÄÄÄÅô•πÖ∞Åô•…Õ—%πëï‡ÄÙÅ}ç’……ïπ—MΩ’…çï%πëï‡πç±Öµ¿†¿∞ÅÕΩ’…çïÃπ±ïπù—†Ä¥Äƒ§Ï(ÄÄÄÅô•πÖ∞ÅÕ—Ö…–ÄÙÅM—Ö…—’¡M—…ïÖµAΩ±•ç‰π…Öπ≠ïëÖ•±ΩŸï…M—Ö…–†(ÄÄÄÄÄÅÕï±ïç—ïëMΩ’…çï%πëï‡ËÅô•…Õ—%πëï‡∞(ÄÄÄÄÄÅ•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïêËÅ•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïê∞(ÄÄÄÄ§Ï(ÄÄÄÅŸÖ»ÅÖ——ïµ¡—ÃÄÙÅÕ—Ö…–πÖ——ïµ¡—ÃÏ(ÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıâïù•∏Å¡±Ö—ôΩ…¥ıô±’——ï»ÅçΩπ—ïπ—QÂ¡îÙëçΩπ—ïπ—QÂ¡îÄú(ÄÄÄÄÄÄùÕΩ’…çïΩ’π–ÙëÌÕΩ’…çïÃπ±ïπù—°ÙÅÕï±ïç—ïë%πëï‡Ùëô•…Õ—%πëï‡Äú(ÄÄÄÄÄÄùÕ—Ö…—%πëï‡ÙëÌÕ—Ö…–πÕΩ’…çï%πëï·ÙÅ•π•—•Ö±Ö•±ïêÙë•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïêÄú(ÄÄÄÄÄÄù—…Â9ï·–Ùë—…Â9ï·–ÅµÖ·——ïµ¡—ÃÙëµÖ·——ïµ¡—ÃÄú(ÄÄÄÄÄÄù—Ö…ùï—MïÖÕΩ∏ÙëÌ}ïôôïç—•ŸïΩπ—ïπ—MïÖÕΩ∏Ä¸¸Äú¥ùÙÄú(ÄÄÄÄÄÄù—Ö…ùï—¡•ÕΩëîÙëÌ}ïôôïç—•ŸïΩπ—ïπ—¡•ÕΩëîÄ¸¸Äú¥ùÙú∞(ÄÄÄÄ§Ï((ÄÄÄÅô•πÖ∞Å¡•≠AÖ≠IïÕΩ±Ÿï»ÄÙ(ÄÄÄÄÄÄÄÅ›•ëùï–πÕ—Ö…—’¡IïÕΩ±Ÿï…A…ΩŸ•ëï»¸π—Ω1Ω›ï…ÖÕî†§ÄÙÙÄù¡•≠¡Ö¨úÏ(ÄÄÄÅŸÖ»Å¡•≠AÖ≠QΩ……ïπ—ç≈’•Õ•—•Ωπ——ïµ¡—ïêÄÙ(ÄÄÄÄÄÄÄÅM—Ö…—’¡M—…ïÖµAΩ±•ç‰π•π•—•Ö±A•≠AÖ≠ç≈’•Õ•—•Ωπ——ïµ¡—ïê†(ÄÄÄÄÄÄÄÄÄÅ•ÕA•≠AÖ≠IïÕΩ±Ÿï»ËÅ¡•≠AÖ≠IïÕΩ±Ÿï»∞(ÄÄÄÄÄÄÄÄÄÅ•π•—•Ö±MΩ’…çï%ÕQΩ……ïπ–Ë(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çïÕmô•…Õ—%πëï·tπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπ—Ω……ïπ–∞(ÄÄÄÄÄÄÄÄÄÅ°ÖÕIïÕΩ±Ÿïë%π•—•Ö±U…∞ËÅ•π•—•Ö±U…∞π•Õ9Ω—µ¡—‰∞(ÄÄÄÄÄÄÄÄÄÅ•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïêËÅ•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïê∞(ÄÄÄÄÄÄÄÄ§Ï((ÄÄÄÅôΩ»Ä†(ÄÄÄÄÄÅŸÖ»ÅÕΩ’…çï%πëï‡ÄÙÅÕ—Ö…–πÕΩ’…çï%πëï‡Ï(ÄÄÄÄÄÅÕΩ’…çï%πëï‡ÄÅÕΩ’…çïÃπ±ïπù—†ÄòòÅÖ——ïµ¡—ÃÄÅµÖ·——ïµ¡—ÃÏ(ÄÄÄÄÄÅÕΩ’…çï%πëï‡¨¨(ÄÄÄÄ§ÅÏ(ÄÄÄÄÄÅô•πÖ∞ÅÕΩ’…çîÄÙÅÕΩ’…çïÕmÕΩ’…çï%πëï·tÏ(ÄÄÄÄÄÄººÅQ°îÅ±Ö’πç†ÅUI0Å•ÃÅÖ±…ïÖë‰Å…ïÕΩ±ŸïêÅÖπêÅ¡±ÖÂÖâ±îÅ•∏µÖ¡¿Å…ïùÖ…ë±ïÕÃÅΩò(ÄÄÄÄÄÄººÅ°Ω‹Å•—ÃÅÕΩ’…çîÅ…Ω‹Å•ÃÅ—Â¡ïêãßuÁ‚ùÁPÅπïŸï»ÅÕ≠•¿Å•–ÅΩŸï»ÅÕ—…ïÖµQÂ¡î∏(ÄÄÄÄÄÅô•πÖ∞Å•ÕIïÕΩ±Ÿïë1Ö’πç°U…∞ÄÙ(ÄÄÄÄÄÄÄÄÄÅÕΩ’…çï%πëï‡ÄÙÙÅô•…Õ—%πëï‡ÄòòÅ•π•—•Ö±U…∞π•Õ9Ω—µ¡—‰Ï(ÄÄÄÄÄÅ•òÄ†Ö•ÕIïÕΩ±Ÿïë1Ö’πç°U…∞ÄòòÅÕΩ’…çîπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπï·—ï…πÖ±U…∞§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}Õ≠•¿Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄúëÌ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°ÕΩ’…çï%πëï‡∞ÅÕΩ’…çî•ÙÅ…ïÖÕΩ∏ıï·—ï…πÖ±}’…∞ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ•òÄ°¡•≠AÖ≠IïÕΩ±Ÿï»Äòò(ÄÄÄÄÄÄÄÄÄÄÖ•ÕIïÕΩ±Ÿïë1Ö’πç°U…∞Äòò(ÄÄÄÄÄÄÄÄÄÅÕΩ’…çîπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπ—Ω……ïπ–§ÅÏ(ÄÄÄÄÄÄÄÅ•òÄ°¡•≠AÖ≠QΩ……ïπ—ç≈’•Õ•—•Ωπ——ïµ¡—ïê§ÅÏ(ÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}Õ≠•¿Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄúëÌ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°ÕΩ’…çï%πëï‡∞ÅÕΩ’…çî•ÙÄú(ÄÄÄÄÄÄÄÄÄÄÄÄù…ïÖÕΩ∏ı¡•≠¡Ö≠}Öç≈’•Õ•—•Ωπ}±•µ•–ú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÄººÅΩ’π–Å—°îÅÖç≈’•Õ•—•Ω∏ÅâïôΩ…îÅ…ïÕΩ±Ÿ•πúËÅÑÅçΩ±êµÕ—Ω…ÖùîÅ…ï≈’ïÕ–ÅµÖ‰(ÄÄÄÄÄÄÄÄººÅ°ÖŸîÅâïï∏Å≈’ï’ïêÅïŸï∏Å›°ï∏Å—°îÅ…ïÕΩ±Ÿï»Å’±—•µÖ—ï±‰Å…ï—’…πÃÅπ’±∞∏(ÄÄÄÄÄÄÄÅ¡•≠AÖ≠QΩ……ïπ—ç≈’•Õ•—•Ωπ——ïµ¡—ïêÄÙÅ—…’îÏ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÖ——ïµ¡—Ã¨¨Ï(ÄÄÄÄÄÅô•πÖ∞ÅÕΩ’…çï•ï±ëÃÄÙÅ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°ÕΩ’…çï%πëï‡∞ÅÕΩ’…çî§Ï(ÄÄÄÄÄÄººÅÅëïâ…•êµë•…ïç–Åô•…Õ–ÅΩ¡ï∏Å•Õ∏ù–Äâç°ïç≠•πúàÅÖπÂ—°•πúÆù◊üäwùPÅ•–ùÃÅ±ΩÖë•πú(ÄÄÄÄÄÄººÅ—°îÅ’Õï»ùÃÅΩ›∏ÅÕΩ’…çîÏÅÕÖ‰ÅÕº∏ÅÖ•±ΩŸï»Å…ï—…•ïÃÅ≠ïï¿Å—°îÅçΩ’π—ï»(ÄÄÄÄÄÄººÄ°—°îÅ±Öëëï»Å…ïÖ±±‰Å•ÃÅ—…Â•πúÅÖ±—ï…πÖ—•ŸïÃÅÖ–Å—°Ö–Å¡Ω•π–§∏(ÄÄÄÄÄÅô•πÖ∞Åô•…Õ———ïµ¡–ÄÙÅÖ——ïµ¡—ÃÄÙÙÄƒÄòòÄÖ•π•—•Ö±——ïµ¡—±…ïÖëÂÖ•±ïêÏ(ÄÄÄÄÄÅô•πÖ∞Åëïâ…•ë•…Õ—=¡ï∏ÄÙ(ÄÄÄÄÄÄÄÄÄÅô•…Õ———ïµ¡–Äòò(ÄÄÄÄÄÄÄÄÄÄÖ¡•≠AÖ≠IïÕΩ±Ÿï»Äòò(ÄÄÄÄÄÄÄÄÄÅÕΩ’…çîπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπ—Ω……ïπ–Ï(ÄÄÄÄÄÅ•òÄ°}Õ—Ö…—’¡Ö—ï=Ÿï…±ÖÂ!•ëëï∏ÄÑÙÅëïâ…•ë•…Õ—=¡ï∏§ÅÏ(ÄÄÄÄÄÄÄÅ}Õ—Ö…—’¡Ö—ï=Ÿï…±ÖÂ!•ëëï∏ÄÙÅëïâ…•ë•…Õ—=¡ï∏Ï(ÄÄÄÄÄÄÄÅ•òÄ°µΩ’π—ïê§ÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ}Õï—M—Ö…—’¡Ö—ï5ïÕÕÖùî†(ÄÄÄÄÄÄÄÅëïâ…•ë•…Õ—=¡ï∏(ÄÄÄÄÄÄÄÄÄÄÄÄ¸Äù1ΩÖë•πúÅÕ—…ïÖÆù◊üäwùòú(ÄÄÄÄÄÄÄÄÄÄÄÄËÅô•…Õ———ïµ¡–(ÄÄÄÄÄÄÄÄÄÄÄÄ¸Äù°ïç≠•πúÅÕ—…ïÖ¥ÄƒÅΩòÄëµÖ·——ïµ¡—Óù◊üäwùòú(ÄÄÄÄÄÄÄÄÄÄÄÄËÄùM—…ïÖ¥Å’πÖŸÖ•±Öâ±îÇ‹ÅQ…Â•πúÄëÖ——ïµ¡—ÃÅΩòÄëµÖ·——ïµ¡—ÀßuÁ‚ùÁXú∞(ÄÄÄÄÄÄ§Ï((ÄÄÄÄÄÅM—…•πú¸Å’…∞Ï(ÄÄÄÄÄÅ1•Õ–ÒA±ÖÂ±•Õ—π—…‰¯¸Å…ïÕΩ±ŸïëA±ÖÂ±•Õ–Ï(ÄÄÄÄÄÅŸÖ»Å…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï‡ÄÙÄ¿Ï(ÄÄÄÄÄÅ•òÄ°•ÕIïÕΩ±Ÿïë1Ö’πç°U…∞§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±ŸîÅ¡±Ö—ôΩ…¥ıô±’——ï»ÅÖ——ïµ¡–ÙëÖ——ïµ¡—ÃºëµÖ·——ïµ¡—ÃÄú(ÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…Ω’—îı±Ö’πç°}’…∞ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ’…∞ÄÙÅ•π•—•Ö±U…∞Ï(ÄÄÄÄÄÅÙÅï±ÕîÅ•òÄ°ÕΩ’…çîπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπë•…ïç—U…∞Äòò(ÄÄÄÄÄÄÄÄÄÅÕΩ’…çîπë•…ïç—U…∞¸π•Õ9Ω—µ¡—‰ÄÙÙÅ—…’î§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±ŸîÅ¡±Ö—ôΩ…¥ıô±’——ï»ÅÖ——ïµ¡–ÙëÖ——ïµ¡—ÃºëµÖ·——ïµ¡—ÃÄú(ÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…Ω’—îıë•…ïç—}’…∞ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ’…∞ÄÙÅÕΩ’…çîπë•…ïç—U…∞Ï(ÄÄÄÄÄÅÙÅï±ÕîÅ•òÄ°›•ëùï–π…ïÕΩ±ŸïMΩ’…çïQΩA±ÖÂ±•Õ–ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±ŸîÅ¡±Ö—ôΩ…¥ıô±’——ï»ÅÖ——ïµ¡–ÙëÖ——ïµ¡—ÃºëµÖ·——ïµ¡—ÃÄú(ÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…Ω’—îı¡±ÖÂ±•Õ–ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÄÄÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÙÅÖ›Ö•–Å›•ëùï–π…ïÕΩ±ŸïMΩ’…çïQΩA±ÖÂ±•Õ–Ñ°ÕΩ’…çî§Ï(ÄÄÄÄÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±Ÿï}…ïÕ’±–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅΩ¨ıôÖ±ÕîÅ…ïÖÕΩ∏ıï·çï¡—•Ω∏Åï·çï¡—•Ω∏ÙëÌîπ…’π—•µïQÂ¡ïÙú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÅ•òÄ°…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÑÙÅπ’±∞ÄòòÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–π•Õ9Ω—µ¡—‰§ÅÏ(ÄÄÄÄÄÄÄÄÄÅ•òÄ°M—Ö…—’¡M—…ïÖµAΩ±•ç‰π…ï≈’•…ïÕ·Öç—¡•ÕΩëï5Ö—ç††(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅ•ÕMï…•ïÃËÅçΩπ—ïπ—QÂ¡îÄÙÙÄùÕï…•ïÃú∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅ¡±ÖÂ±•Õ—1ïπù—†ËÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–π±ïπù—†∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄ§Äòò(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ïôôïç—•ŸïΩπ—ïπ—MïÖÕΩ∏ÄÑÙÅπ’±∞Äòò(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ïôôïç—•ŸïΩπ—ïπ—¡•ÕΩëîÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÄÄÄÄÅô•πÖ∞Å¡Ö…ÕïêÄÙÅMï…•ïÕA±ÖÂ±•Õ–πô…ΩµA±ÖÂ±•Õ—π—…•ïÃ†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅçΩ±±ïç—•ΩπQ•—±îËÅ›•ëùï–π—•—±î∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅôΩ…çïMï…•ïÃËÅ—…’î∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÄÄÅô•πÖ∞Å—Ö…ùï–ÄÙÅ¡Ö…Õïêπô•πë=…•ù•πÖ±%πëï·	ÂMïÖÕΩπ¡•ÕΩëî†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ïôôïç—•ŸïΩπ—ïπ—MïÖÕΩ∏Ñ∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ}ïôôïç—•ŸïΩπ—ïπ—¡•ÕΩëîÑ∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÄÄÅô•πÖ∞Åï·Öç—%πëï‡ÄÙÅM—Ö…—’¡M—…ïÖµAΩ±•ç‰π…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï‡†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ…ï≈’•…ïÕ¡•ÕΩëï5Ö—ç†ËÅ—…’î∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅµÖ—ç°ïë¡•ÕΩëï%πëï‡ËÅ—Ö…ùï–∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÄÄÅ•òÄ°ï·Öç—%πëï‡ÄÙÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄººÅÅ¡Öç¨Å—°Ö–ÅΩµ•—ÃÅ—°îÅ…ï≈’ïÕ—ïêÅï¡•ÕΩëîÅ•ÃÅπΩ–ÅÑÅŸÖ±•ê(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄººÅôÖ±±âÖç¨∏Å=¡ïπ•πúÅ…Ω‹ÅÈï…ºÅ›Ω’±êÅÕ•±ïπ—±‰Å¡±Ö‰Å—°îÅ›…Ωπú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄººÅï¡•ÕΩëîÅÖπêÅ—°ï∏ÅÖëΩ¡–Å—°Ö–Å’π…ï±Ö—ïêÅ¡±ÖÂ±•Õ–∏(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}…ï©ïç–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…ïÖÕΩ∏ı¡±ÖÂ±•Õ—}µ•ÕÕ•πù}ï¡•ÕΩëîÄú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄù—Ö…ùï—MïÖÕΩ∏Ùë}ïôôïç—•ŸïΩπ—ïπ—MïÖÕΩ∏Äú(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄù—Ö…ùï—¡•ÕΩëîÙë}ïôôïç—•ŸïΩπ—ïπ—¡•ÕΩëîú∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÄÄÄÄÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï‡ÄÙÅï·Öç—%πëï‡Ï(ÄÄÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÄÄÄÄÅ’…∞ÄÙÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ—m…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï·tπ’…∞Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙÅï±ÕîÅ•òÄ°}ïôôïç—•ŸïIïÕΩ±Ÿï»ÄÑÙÅπ’±∞§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±ŸîÅ¡±Ö—ôΩ…¥ıô±’——ï»ÅÖ——ïµ¡–ÙëÖ——ïµ¡—ÃºëµÖ·——ïµ¡—ÃÄú(ÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…Ω’—îıÕ•πù±ï}’…∞ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÄÄÄÄÅ’…∞ÄÙÅÖ›Ö•–Å}ïôôïç—•ŸïIïÕΩ±Ÿï»Ñ°ÕΩ’…çî§Ï(ÄÄÄÄÄÄÄÅÙÅçÖ—ç†Ä°î§ÅÏ(ÄÄÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ı…ïÕΩ±Ÿï}…ïÕ’±–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅΩ¨ıôÖ±ÕîÅ…ïÖÕΩ∏ıï·çï¡—•Ω∏Åï·çï¡—•Ω∏ÙëÌîπ…’π—•µïQÂ¡ïÙú∞(ÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÄÄÅ’…∞ÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÅÙ(ÄÄÄÄÄÅÙ((ÄÄÄÄÄÅ•òÄ°’…∞ÄÙÙÅπ’±∞ÅÒÅ’…∞π•Õµ¡—‰§ÅÏ(ÄÄÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçÖπë•ëÖ—ï}…ï©ïç–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄÄÄúëÕΩ’…çï•ï±ëÃÅ…ïÖÕΩ∏ıïµ¡—Â}…ïÕΩ±’—•Ω∏ú∞(ÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÄÄÅçΩπ—•π’îÏ(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÄººÅïâ…•êµ…ïÕΩ±ŸïêÅ—Ω……ïπ—ÃÅâÂ¡ÖÕÃÅ—°îÅëïçΩëîÅ¡…ΩâîÄ°Õïî(ÄÄÄÄÄÄººÅ}Ω¡ïπM—Ö…—’¡ïâ…•ë•…ïç–§ÏÅÖëëΩ∏Åë•…ïç–ÅUI1ÃÅ≠ïï¿Å•–∞ÅÖπêÅÕºÅëº(ÄÄÄÄÄÄººÅA•≠AÖ¨ÅÕïÕÕ•ΩπÃãßuÁ‚ùÁPÅçΩ±êµÕ—Ω…ÖùîÅΩ¡ïπÃÅÖ…îÅ—°îÅÕ±Ω›ïÕ–Å•∏Å—°îÅÖ¡¿ÅÖπê(ÄÄÄÄÄÄººÅ°ÖŸîÅ—°ï•»ÅΩ›∏Å…ïÖë•πïÕÃÅπïïëÃ∏(ÄÄÄÄÄÅô•πÖ∞Å•Õïâ…•ëIïÕΩ±ŸïêÄÙ(ÄÄÄÄÄÄÄÄÄÄÖ¡•≠AÖ≠IïÕΩ±Ÿï»ÄòòÅÕΩ’…çîπÕ—…ïÖµQÂ¡îÄÙÙÅM—…ïÖµQÂ¡îπ—Ω……ïπ–Ï(ÄÄÄÄÄÅô•πÖ∞ÅçÖπë•ëÖ—ï!ïÖëï…ÃÄÙÅ•ÕIïÕΩ±Ÿïë1Ö’πç°U…∞(ÄÄÄÄÄÄÄÄÄÄ¸Å°——¡!ïÖëï…Ã(ÄÄÄÄÄÄÄÄÄÄËÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÑÙÅπ’±∞(ÄÄÄÄÄÄÄÄÄÄ¸Å…ïÕΩ±ŸïëA±ÖÂ±•Õ—m…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï·tπ°——¡!ïÖëï…Ã(ÄÄÄÄÄÄÄÄÄÄËÅÕΩ’…çîπ°——¡!ïÖëï…ÃÏ(ÄÄÄÄÄÅô•πÖ∞ÅΩ¨ÄÙÅ•Õïâ…•ëIïÕΩ±Ÿïê(ÄÄÄÄÄÄÄÄÄÄ¸ÅÖ›Ö•–Å}Ω¡ïπM—Ö…—’¡ïâ…•ë•…ïç–†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ’…∞∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅçÖπë•ëÖ—ï!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çîËÅÕΩ’…çî∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çï%πëï‡ËÅÕΩ’…çï%πëï‡∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÖ——ïµ¡–ËÅÖ——ïµ¡—Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅµÖ·——ïµ¡—ÃËÅµÖ·——ïµ¡—Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§(ÄÄÄÄÄÄÄÄÄÄËÅÖ›Ö•–Å}—…Â=¡ïπM—Ö…—’¡YΩê†(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ’…∞∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅ°——¡!ïÖëï…ÃËÅçÖπë•ëÖ—ï!ïÖëï…Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çîËÅÕΩ’…çî∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÕΩ’…çï%πëï‡ËÅÕΩ’…çï%πëï‡∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅÖ——ïµ¡–ËÅÖ——ïµ¡—Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄÄÅµÖ·——ïµ¡—ÃËÅµÖ·——ïµ¡—Ã∞(ÄÄÄÄÄÄÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ•òÄ†ÖµΩ’π—ïê§Å…ï—’…∏ÅôÖ±ÕîÏ(ÄÄÄÄÄÅ•òÄ†ÖΩ¨§ÅçΩπ—•π’îÏ((ÄÄÄÄÄÅ}Öç—•Ÿï!——¡!ïÖëï…ÃÄÙÅçÖπë•ëÖ—ï!ïÖëï…ÃÏ((ÄÄÄÄÄÅ}ç’……ïπ—MΩ’…çï%πëï‡ÄÙÅÕΩ’…çï%πëï‡Ï(ÄÄÄÄÄÅ}ç’……ïπ—M—…ïÖµU…∞ÄÙÅ’…∞Ï(ÄÄÄÄÄÅ•òÄ°…ïÕΩ±ŸïëA±ÖÂ±•Õ–ÄÑÙÅπ’±∞ÄòòÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–π•Õ9Ω—µ¡—‰§ÅÏ(ÄÄÄÄÄÄÄÅ}Öç—•ŸïA±ÖÂ±•Õ–ÄÙÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ–Ï(ÄÄÄÄÄÄÄÅ}ç’……ïπ—%πëï‡ÄÙÅ…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï‡Ï(ÄÄÄÄÄÄÄÅ}çÖç°ïëMï…•ïÕA±ÖÂ±•Õ–ÄÙÅπ’±∞Ï(ÄÄÄÄÄÄÄÅ}¡±ÖÂ±•Õ—%ëïπ—•—ÂQΩ≠ï∏¨¨Ï(ÄÄÄÄÄÅÙ(ÄÄÄÄÄÅ’πÖ›Ö•—ïê°}çΩµµ•—YÖ±•ëÖ—ïëM—…ïµ•ΩMΩ’…çî°ÕΩ’…çî§§Ï(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıçΩµµ•–Å¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄùÖ——ïµ¡–ÙëÖ——ïµ¡—ÃºëµÖ·——ïµ¡—ÃÄëÕΩ’…çï•ï±ëÃÄú(ÄÄÄÄÄÄÄÄù¡±ÖÂ±•Õ—%—ïµÃÙëÌ…ïÕΩ±ŸïëA±ÖÂ±•Õ–¸π±ïπù—†Ä¸¸Ä¡ÙÄú(ÄÄÄÄÄÄÄÄù¡±ÖÂ±•Õ—%πëï‡Ùë…ïÕΩ±ŸïëA±ÖÂ±•Õ—%πëï‡ú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÄÄÅ…ï—’…∏Å—…’îÏ(ÄÄÄÅÙ(ÄÄÄÅ}Õï—M—Ö…—’¡Ö—ïç—•Ÿî°ôÖ±Õî§Ï(ÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıï·°Ö’Õ—ïêÅ¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄùÖ——ïµ¡—ÃÙëÖ——ïµ¡—ÃÅµÖ·——ïµ¡—ÃÙëµÖ·——ïµ¡—ÃÅÕΩ’…çïΩ’π–ÙëÌÕΩ’…çïÃπ±ïπù—°Ùú∞(ÄÄÄÄ§Ï(ÄÄÄÅ…ï—’…∏ÅôÖ±ÕîÏ(ÄÅÙ((ÄÅ’—’…îÒŸΩ•ê¯Å}çΩµµ•—YÖ±•ëÖ—ïëM—…ïµ•ΩMΩ’…çî°QΩ……ïπ–¸ÅÕΩ’…çî§ÅÖÕÂπåÅÏ(ÄÄÄÅ±ΩùMΩ’…çïMï±ïç—•Ω∏†(ÄÄÄÄÄÄù¡±ÖÂï…}ÕΩ’…çï}çΩµµ•——ïêú∞(ÄÄÄÄÄÅÕΩ’…çîËÅÕΩ’…çî∞(ÄÄÄÄÄÅ•πëï‡ËÅ}ç’……ïπ—MΩ’…çï%πëï‡∞(ÄÄÄÄÄÅ¡±ÖÂï»ËÄùµ¡ÿú∞(ÄÄÄÄ§Ï(ÄÄÄÅô•πÖ∞ÅçΩµµ•–ÄÙÅ›•ëùï–πΩπM—…ïµ•ΩMΩ’…çïΩµµ•——ïêÏ(ÄÄÄÅ•òÄ°ÕΩ’…çîÄÙÙÅπ’±∞ÅÒÅçΩµµ•–ÄÙÙÅπ’±∞§Å…ï—’…∏Ï(ÄÄÄÅ—…‰ÅÏ(ÄÄÄÄÄÅÖ›Ö•–ÅçΩµµ•–°ÕΩ’…çî§Ï(ÄÄÄÅÙÅçÖ—ç†Ä°ï……Ω»§ÅÏ(ÄÄÄÄÄÅëïâ’ùA…•π–†(ÄÄÄÄÄÄÄÄùmM—Ö…—’¡Ö•±ΩŸï…tÅïŸïπ–ıâ•πë•πù}çΩµµ•—}ôÖ•±ïêÅ¡±Ö—ôΩ…¥ıô±’——ï»Äú(ÄÄÄÄÄÄÄÄùï·çï¡—•Ω∏ÙëÌï……Ω»π…’π—•µïQÂ¡ïÙú∞(ÄÄÄÄÄÄ§Ï(ÄÄÄÅÙ(ÄÅÙ((ÄÅM—…•πúÅ}Õ—Ö…—’¡MΩ’…çï•ï±ëÃ°•π–¸Å•πëï‡∞ÅQΩ……ïπ–¸ÅÕΩ’…çî§ÅÏ(ÄÄÄÅM—…•πúÅÕÖôî°M—…•πú¸ÅŸÖ±’î§ÅÏ(ÄÄÄÄÄÅ•òÄ°ŸÖ±’îÄÙÙÅπ’±∞ÅÒÅŸÖ±’îπ•Õµ¡—‰§Å…ï—’…∏Äú¥úÏ(ÄÄÄÄÄÅô•πÖ∞ÅçΩµ¡Öç–ÄÙÅŸÖ±’îπ…ï¡±Öçï±∞°Iïù·¿°»ùqÃ¨ú§∞ÄúÄú§Ï(ÄÄÄÄÄÅ…ï—’…∏ÅçΩµ¡Öç–π±ïπù—†ÄÙÄÿ–Ä¸ÅçΩµ¡Öç–ÄËÅçΩµ¡Öç–πÕ’âÕ—…•πú†¿∞Äÿ–§Ï(ÄÄÄÅÙ((ÄÄÄÅ…ï—’…∏ÄùÕΩ’…çï%πëï‡ÙëÌ•πëï‡Ä¸¸Äú¥ùÙÅ—Â¡îÙëÌÕΩ’…çî¸πÕ—…ïÖµQÂ¡îππÖµîÄ¸¸Äú¥ùÙÄú(ÄÄÄÄÄÄÄÄùÖëëΩ∏ÙëÌÕÖôî°ÕΩ’…çî¸πÕ—…ïµ•ΩëëΩπ%ê•ÙÅÕΩ’…çîÙëÌÕÖôî°ÕΩ’…çî¸πÕΩ’…çî•ÙúÏ(ÄÅÙ((ÄÅŸΩ•êÅ}Õï—M—Ö…—’¡Ö—ïç—•Ÿî°âΩΩ∞ÅÖç—•Ÿî§ÅÏ(ÄÄÄÅ•òÄ°}Õ—Ö…—’¡Ö—ïç—•ŸîÄÙÙÅÖç—•Ÿî§Å…ï—’…∏Ï(ÄÄÄÅ}Õ—Ö…—’¡Ö—ïç—•ŸîÄÙÅÖç—•ŸîÏ(ÄÄÄÅ•òÄ†ÖÖç—•Ÿî§Å}Õ—Ö…—’¡Ö—ï=Ÿï…±ÖÂ!•ëëï∏ÄÙÅôÖ±ÕîÏ(ÄÄÄÅ•òÄ°µΩ’π—ïê§ÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÅÙ((ÄÅŸΩ•êÅ}Õï—M—Ö…—’¡Ö—ï5ïÕÕÖùî°M—…•πúÅµïÕÕÖùî§ÅÏ(ÄÄÄÅ•òÄ°}Õ—Ö…—’¡Ö—ï5ïÕÕÖùîÄÙÙÅµïÕÕÖùî§Å…ï—’…∏Ï(ÄÄÄÅ}Õ—Ö…—’¡Ö—ï5ïÕÕÖùîÄÙÅµïÕÕÖùîÏ(ÄÄÄÅ•òÄ°µΩ’π—ïêÄòòÅ}Õ—Ö…—’¡Ö—ïç—•Ÿî§ÅÕï—M—Ö—î††§ÅÌÙ§Ï(ÄÅÙ((ÄÄººÄ÷ç ÅM—…ïµ•ºÅMΩ’…çîÅM°ïï–ãßuÁ‚ùÁnù◊üäwù ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç †¢fˆñB˜6Ü˜u6˜W&6U6ÜVWD˜fW&∆íÇí∞¢fñÊ¬6˜W&6W2“ˆVffV7FófU6˜W&6W3∞¢ñbá6˜W&6W2”“ÁV∆¬«¬6˜W&6W2Êó4V◊Gíí&WGW&„∞¢ˆÜñFTóGe¶&ÊÊW"Çì∞¢6WE7FFRÇÇí∞¢˜6Ü˜u6˜W&6U6ÜVWB“G'VS∞¢ˆ6ˆÁG&ˆ«5fó6ñ&∆RÁf«VR“f«6S∞¢“ì∞¢–†¢fˆñBˆÜñFU6˜W&6U6ÜVWBÇí∞¢6WE7FFRÇÇí∞¢˜6Ü˜u6˜W&6U6ÜVWB“f«6S∞¢“ì∞¢–†¢gWGW&S≈7G&ñÊsÛ‚gVÊ7Fñˆ‚ÖF˜'&VÁBíˆ'Vñ∆E6˜W&6U6ÜVWE&W6ˆ«fW"Çí∞¢ñbávñFvWBÁ&W6ˆ«fU6˜W&6UFı∆ñ∆ó7B“ÁV∆¬í∞¢&WGW&‚ÖF˜'&VÁBF˜'&VÁBí7ñÊ2∞¢fñÊ¬∆ñ∆ó7B“vóBvñFvWBÁ&W6ˆ«fU6˜W&6UFı∆ñ∆ó7BáF˜'&VÁBì∞¢ñbá∆ñ∆ó7B”“ÁV∆¬«¬∆ñ∆ó7BÊó4V◊Gíí&WGW&‚ÁV∆√∞¢˜VÊFñÊu6˜W&6U∆ñ∆ó7B“∆ñ∆ó7C∞¢fñÊ¬fó'7EW&¬“∆ñ∆ó7BÊfó'7BÁW&√∞¢&WGW&‚fó'7EW&¬Êó4Ê˜DV◊GíÚfó'7EW&¬¢ÁV∆√∞¢”∞¢–¢&WGW&‚ˆVffV7FófU&W6ˆ«fW"∞¢–†¢gWGW&S«fˆñC‚ˆÜÊF∆U6˜W&6U6V∆V7FVBÜñÁBñÊFWÇ¬7G&ñÊrW&¬í7ñÊ2∞¢ÚÚñ6∂ñÊr6˜W&6R&˜'G2FÜR∆ÊFñÊrfW&ñfñW".ù◊üäwùBóB◊W7BÊ˜B&R÷ó77VRFÜP¢ÚÚˆ∆BF&vWBvñÁ7BFÜR&W∆6V÷VÁB7G&V“áFÜB6˜V∆BWfV‚G&óFÜP¢ÚÚf∆ñFF˜"w2˜6óFñˆ‚vFRí‚FÜRuT$BFV∆ñ&W&FV«í7Fó2&÷VC¢FÜP¢ÚÚ7vóF6ÇFá2&V∆˜r6ÜV6∑ˆñÁBFÜR˜WFvˆñÊr˜6óFñˆ‚¬ÊBFÜB6fR◊W7@¢ÚÚ7Fñ∆¬&R&˜FV7FVBáFÜWí7V'7FóGWFRFÜRÜV∆BF&vWBvÜW&RÊVVFVBí‡¢˜&W7V÷UfW&ñgîWˆ6Ç≤≥∞¢ÚÚ∆ófRïEb6ÜÊÊV√¢FÜR÷˜fñRóV∆ñÊR&V∆˜r6VV∑2FÚFÜR&Wfñ˜W0¢ÚÚ˜6óFñˆ‚ÊB&V∆ˆG27V'FóF∆W2ßuÁ‚ùÁB&˜FÇ÷VÊñÊv∆W72ÜÊBÜ&÷gV¬íf˜"¢ÚÚ∆ófR7G&V“‚&˜WFRFÚFÜRFVFñ6FVB∆ófR7vóF6ÇñÁ7FVB‡¢ñbÖˆóGd6ÜÊÊVƒ∂Wí“ÁV∆¬í∞¢vóB˜7vóF6ÖFÙóGe6˜W&6RÜñÊFWÇ¬W&¬ì∞¢&WGW&„∞¢–¢fñÊ¬VÊFñÊu∆ñ∆ó7B“˜VÊFñÊu6˜W&6U∆ñ∆ó7C∞¢˜VÊFñÊu6˜W&6U∆ñ∆ó7B“ÁV∆√∞¢ñbáVÊFñÊu∆ñ∆ó7B“ÁV∆¬bbVÊFñÊu∆ñ∆ó7BÊó4Ê˜DV◊Gíí∞¢vóB˜7vóF6ÖFı6˜W&6U∆ñ∆ó7BÄ¢ñÊFWÇ¿¢VÊFñÊu∆ñ∆ó7B¿¢f∆ñFFTWá∆ñ6óE6V∆V7Fñˆ„¢G'VR¿¢ì∞¢“V«6R∞¢vóB˜7vóF6ÖFı7G&V÷ñı6˜W&6RÜñÊFWÇ¬W&¬ì∞¢–¢–†¢ÚÚÚ÷ÁV¬ñ6≤g&ˆ“FÜR6˜W&6R6ÜVWBvÜñ∆R7G&V÷ñÚïEb6ÜÊÊV¬∆ó3†¢ÚÚÚ˜V‚FÜR6Ü˜6V‚∆ñÊ≤Fó&V7F«í‚ÊÚ˜6óFñˆ‚6VV≤¬ÊÚ7V'FóF∆P¢ÚÚÚ&ˆˆ∂∂VWñÊr¬ÊBÊÚWFÚ÷GfÊ6Rˆ‚fñ«W&RßuÁ‚ùÁBFÜRW6W"6Ü˜6RFÜó2∆ñÊ∞¢ÚÚÚFV∆ñ&W&FV«í¬6ÚFVBñ6≤ßW7B∆VfW2FÜR6ÜÊÊV¬F˜v‚áFÜWí6‡¢ÚÚÚñ6≤Ê˜FÜW"g&ˆ“FÜR6ÜVWBí‡¢gWGW&S«fˆñC‚˜7vóF6ÖFÙóGe6˜W&6RÜñÁBñÊFWÇ¬7G&ñÊrW&¬í7ñÊ2∞¢ˆÜñFU6˜W&6U6ÜVWBÇì∞¢fñÊ¬∂Wí“ˆóGd6ÜÊÊVƒ∂Wì∞¢fñÊ¬Fñ6∂WB“≤µˆóGe7vóF6ÖFñ6∂WC∞¢fñÊ¬&Wfñ˜W4ñÊFWÇ“ˆ7W'&VÁE6˜W&6TñÊFWÉ∞¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“ñÊFWÉ∞¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞¢ÚÚFV∆ñ&W&FR6˜W&6Rñ6≤ó2g&W6ÇGVÊS¢Áí&V6˜fW'íWó6ˆFRÜÊ@¢ÚÚóG2ñ∆¬í&V∆ˆÊvVBFÚFÜR∆ñÊ≤&VñÊr&ÊFˆÊVB‡¢ˆóGd∆ófU&V6˜fW'íÊˆÂGVÊU7F'FVBÇì∞¢ˆóGe&V6ˆÊÊV7EFWáBÁf«VR“ÁV∆√∞¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–¢fñÊ¬ˆ≤“vóB˜G'î˜V‰∆ófU7G&V“Ä¢W&¬¿¢áGGÜVFW'3¢ˆ7W'&VÁDóGd6ÜÊÊV√ÚÁ∆ñ&6¥ÜVFW'2¿¢ì∞¢ñbÇ÷˜VÁFVB«¬Fñ6∂WB“ˆóGe7vóF6ÖFñ6∂WBí&WGW&„∞¢ñbÜˆ≤í∞¢ñbÜ∂Wí“ÁV∆¬í∞¢7G&V÷ñÙóGe6W'fñ6RÊñÁ7FÊ6RÊ÷&µvñÊÊW"Ü∂Wí¬W&¬ì∞¢–¢“V«6R∞¢ÚÚfñ∆VBñ6≥¢&W7F˜&RFÜRÜñvÜ∆ñváB∫w^~)ﬁuB∆VfñÊróBˆ‚FÜRFVB&˜p¢ÚÚv˜V∆B&˜FÇ6Ü˜rf«6Rƒîî‰r&FvRÊB&∆ˆ6≤&WG'ññÊróBáFÜP¢ÚÚ6ÜVWBñvÊ˜&W26V∆V7FñÊrFÜR&7W'&VÁB"6˜W&6Rí‡¢6WE7FFRÇÇí”‚ˆ7W'&VÁE6˜W&6TñÊFWÇ“&Wfñ˜W4ñÊFWÇì∞¢–¢ÚÚ6÷RFó&V7BG&Á6óFñˆ‚÷˜fW&∆í6∆VÁW2˜7vóF6ÖFÙóGd6ÜÊÊV¬∫w^~)ﬁuBFÜP¢ÚÚw∆ññÊrrWfVÁBó2VÁ&V∆ñ&∆Rf˜"Ñ≈2ˆ∆ófR7G&V◊2‡¢˜G&Á6óFñˆÂ7F˜Fñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6UFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6R“#∞¢˜G&Á6óFñˆÂÜ6S%7F'FVB“FFUFñ÷RÊÊ˜rÇì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢˜G&Á6óFñˆÂ7F˜Fñ÷W"“Fñ÷W"Ü6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Sí¬Çí∞¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"Á7F˜Çì∞¢˜G&Á6óFñˆÂ'VÊÊñÊr“f«6S∞¢˜&ñÊ&˜t7FófR“f«6S∞¢ñbÜ÷˜VÁFVBí6WE7FFRÇÇí∑“ì∞¢“ì∞¢–†¢gWGW&S∆&ˆˆ√‚˜7vóF6ÖFı6˜W&6U∆ñ∆ó7BÄ¢ñÁB6˜W&6TñÊFWÇ¿¢∆ó7C≈∆ñ∆ó7DVÁG'ì‚ÊWu∆ñ∆ó7B¬∞¢ñÁCÚF&vWE6V6ˆ‚¿¢ñÁCÚF&vWDWó6ˆFR¿¢&ˆˆ¬f∆ñFFTWá∆ñ6óE6V∆V7Fñˆ‚“f«6R¿¢&ˆˆ¬7W&W75&W7V÷R“f«6R¿¢Wó6ˆFU∆ñ&6µ&WVW7CÚ&WVW7B¿¢“í7ñÊ2∞¢ñbá&WVW7B”“ÁV∆¬íˆWó6ˆFTÊfñvFñˆ‰vVÊW&Fñˆ‚≤≥∞¢ñbá&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ˆÜñFU6˜W&6U6ÜVWBÇì∞¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢fñÊ¬˜WFvˆñÊu∆ñ∆ó7B“ˆ7FófU∆ñ∆ó7B”“ÁV∆¿¢ÚÁV∆¿¢¢∆ó7C≈∆ñ∆ó7DVÁG'ì‚ÊˆbÖˆ7FófU∆ñ∆ó7Bì∞¢fñÊ¬˜WFvˆñÊtñÊFWÇ“ˆ7W'&VÁDñÊFWÉ∞¢fñÊ¬˜WFvˆñÊt66ÜVE6W&ñW2“ˆ66ÜVE6W&ñW5∆ñ∆ó7C∞¢fñÊ¬˜WFvˆñÊu6˜W&6TñÊFWÇ“ˆ7W'&VÁE6˜W&6TñÊFWÉ∞¢ÚÚñb7F'GW&W7V÷RÊWfW"∆ÊFVB¬FÜR∆ófR˜6óFñˆ‚ó2&W7F'@¢ÚÚ'Fñf7BßuÁ‚ùÁB6''íFÜRÑTƒBF&vWB7&˜72FÜR7vóF6ÇÜÊBñÁFÚFÜP¢ÚÚfñ«W&R◊&W7F˜&RFÇí6ÚFÜRÊWr6˜W&6R˜VÁ2BFÜR&ˆˆ∂÷&≤¬Ê˜B„‡¢ÚÚW&RVW'ì¢FÜRwV&BóG6V∆b7Fó2&÷VBf˜"FÜR6ÜV6∑ˆñÁB6fR&V∆˜r‡¢fñÊ¬˜WFvˆñÊtÜV∆D◊2“˜&W7V÷Uw&óFTwV&BÊÜV∆EF&vWDñd&∆ˆ6∂VBÄ¢˜˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2¿¢ì∞¢fñÊ¬˜WFvˆñÊu˜6óFñˆ‚“˜WFvˆñÊtÜV∆D◊2“ÁV∆¿¢ÚGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢˜WFvˆñÊtÜV∆D◊2ê¢¢˜˜6óFñˆ„∞¢fñÊ¬˜WFvˆñÊtFó&V7EW&¬“ˆ7W'&VÁE7G&V’W&√∞¢fñÊ¬˜WFvˆñÊtÜVFW'2“ˆ7FófTáGGÜVFW'3∞¢fñÊ¬6V∆V7FVE6˜W&6R–¢ÖˆVffV7FófU6˜W&6W2“ÁV∆¬b`¢6˜W&6TñÊFWÇ„“b`¢6˜W&6TñÊFWÇ¬ˆVffV7FófU6˜W&6W2Ê∆VÊwFÇê¢ÚˆVffV7FófU6˜W&6W2∑6˜W&6TñÊFWÖ–¢¢ÁV∆√∞¢ÚÚ6GW&RFÜRWó6ˆFRvRw&Rˆ‚$Tdı$R7vñÊrFÜR∆ñ∆ó7B¬6ÚvR6‡¢ÚÚ∆ÊBˆ‚óBñ‚FÜRÊWr6˜W&6RñÁ7FVBˆbßV◊ñÊrFÚFÜR6≤w2fó'7@¢ÚÚVÁG'íÖ3Sí‚&VBg&ˆ“FÜR7W'&VÁB∆ñ∆ó7BVÁG'íáG&6∑2WFÚ÷GfÊ6Rí‡¢ÚÚ‚Wó6ˆFR÷wVñFRfWF6ÇF&vWG2DîddU$TÂBWó6ˆFS¢∆ÊBFÜW&RñÁ7FVB‡¢fñÊ¬7W'&VÁB“˜G&∑E6V6ˆ‰Wó6ˆFRÇì∞¢fñÊ¬Wá∆ñ6óEF&vWB“F&vWE6V6ˆ‚“ÁV∆¬bbF&vWDWó6ˆFR“ÁV∆√∞¢fñÊ¬6R“Wá∆ñ6óEF&vW@¢Úá6V6ˆ„¢F&vWE6V6ˆ‚¬Wó6ˆFS¢F&vWDWó6ˆFRê¢¢7W'&VÁC∞¢ÚÚ6ÜV6∑ˆñÁBFÜRıUDtÙî‰rWó6ˆFRÊ˜r¬vÜñ∆Rˆ7FófU∆ñ∆ó7Bıˆ7W'&VÁDñÊFWÄ¢ÚÚ7Fñ∆¬ˆñÁBBóB.ù◊üäwùBgFW"FÜR7vFÜRñÊFWÇv˜V∆B&W6ˆ«fRvñÁ7BFÜP¢ÚÚÊWr∆ñ∆ó7B‚ˆ∆ˆE∆ñ∆ó7DñÊFWÇ&V∆˜ró2Fˆ∆BFÚ6∂óóG2˜v‚6fR‡¢vóB˜6fU&W7V÷RÇì∞¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞†¢ÚÚ&W∆6R∆ñ∆ó7BÊBñÁf∆ñFFR6W&ñW266ÜR‚6˜W&6RˆWó6ˆFR7vóF6Ä¢ÚÚ7Fó2vóFÜñ‚FÜR6÷R6Ü˜r¬6ÚFÜRgV∆¬Ed÷¶RWó6ˆFR∆ó7B6'&ñW0¢ÚÚ˜fW"ßuÁ‚ùÁBvóFÜ˜WBóB¬wVñFRF¶6VÊ7íÊBFÜRgV∆¬Wó6ˆFR6ÜVWBv˜V∆Bv¢ÚÚF&≤VÁFñ¬Ê˜FÜW"Ed÷¶RfWF6Ç7V66VVG2ÜÊWfW"¬vÜV‚ˆff∆ñÊRí‡¢fñÊ¬˜WFvˆñÊu6W&ñW2“˜6W&ñW5∆ñ∆ó7BÛÚ˜7ñÁFÜWFñ4wVñFU∆ñ∆ó7C∞¢fñÊ¬6'&ñVDwVñFR“˜WFvˆñÊu6W&ñW3ÚÊgV∆≈Gf÷¶TWó6ˆFW2Êó4Ê˜DV◊Gí”“G'VP¢Ú˜WFvˆñÊu6W&ñW2ÊgV∆≈Gf÷¶TWó6ˆFW0¢¢ÁV∆√∞¢fñÊ¬6'&ñVDñ÷F$ñB“˜WFvˆñÊu6W&ñW3ÚÊñ÷F$ñBÛÚˆ7W'&VÁE6W&ñW4ñ÷F$ñC∞¢fñÊ¬6'&ñVEGf÷¶U6Ü˜tñB“˜WFvˆñÊu6W&ñW3ÚÁGf÷¶U6Ü˜tñC∞¢fñÊ¬6'&ñVEGf÷¶U6Ü˜tÊ÷R“˜WFvˆñÊu6W&ñW3ÚÁGf÷¶U6Ü˜tÊ÷S∞¢fñÊ¬6'&ñVE˜7FW%W&¬“˜WFvˆñÊu6W&ñW3ÚÁ6Ü˜u˜7FW%W&√∞¢fˆñB&W∆6U∆ñ∆ó7BÇí”‚6WE7FFRÇÇí∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“6˜W&6TñÊFWÉ∞¢ˆ7FófU∆ñ∆ó7B“ÊWu∆ñ∆ó7C∞¢ˆ66ÜVE6W&ñW5∆ñ∆ó7B“ÁV∆√∞¢˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚≤≥∞¢“ì∞¢ñbá&WVW7B“ÁV∆¬í∞¢ñbÇ&WVW7BÁ&W∆6U∆ñ∆ó7Bá&W∆6U∆ñ∆ó7Bíí&WGW&‚f«6S∞¢“V«6R∞¢&W∆6U∆ñ∆ó7BÇì∞¢–¢fñÊ¬&V'Vñ«B“˜6W&ñW5∆ñ∆ó7C∞¢ñbá&V'Vñ«B“ÁV∆¬í∞¢&V'Vñ«BÊñ÷F$ñBÛÛ“6'&ñVDñ÷F$ñC∞¢&V'Vñ«BÁGf÷¶U6Ü˜tñBÛÛ“6'&ñVEGf÷¶U6Ü˜tñC∞¢&V'Vñ«BÁGf÷¶U6Ü˜tÊ÷RÛÛ“6'&ñVEGf÷¶U6Ü˜tÊ÷S∞¢&V'Vñ«BÁ6Ü˜u˜7FW%W&¬ÛÛ“6'&ñVE˜7FW%W&√∞¢ñbÜ6'&ñVDwVñFR“ÁV∆¬b`¢6'&ñVDwVñFRÊó4Ê˜DV◊Gíb`¢&V'Vñ«BÊgV∆≈Gf÷¶TWó6ˆFW2Êó4V◊Gíí∞¢&V'Vñ«BÊgV∆≈Gf÷¶TWó6ˆFW2“6'&ñVDwVñFS∞¢–¢ˆWó6ˆFT÷WFFF&VGí“˜&V∆ˆDWó6ˆFTñÊfÚÇì∞¢–†¢ÚÚ&W7V÷RFÜR4‘RWó6ˆFRg&ˆ“FÜRÊWr6˜W&6RÜ6V6ˆ‚ˆ6ˆ◊∆WFR6≤v˜V∆@¢ÚÚ˜FÜW'vó6R&W7F'BB3Sì≤ˆ∆ˆE∆ñ∆ó7DñÊFWÇ&W7F˜&W2óG26fV@¢ÚÚ˜6óFñˆ‚‡¢f"F&vWDñÊFWÇ“∞¢ÚÚvÜWFÜW"FÜRÊWr6˜W&6R∆ÊFVBˆ‚FÜR4‘R6ˆÁFVÁBvRvW&RvF6ÜñÊrßuÁ‚ùÁBˆÊ«ê¢ÚÚFÜV‚FˆW2'&VfW"FÜR6ÜV6∑ˆñÁFVB∆ˆ6¬˜6óFñˆ‚˜fW"G&∑B"«í‚vÜV‡¢ÚÚvRf∆¬&6≤FÚFñffW&VÁBWó6ˆFR¬óG2˜v‚G&∑B&W7V÷R◊W7B7Fñ∆¬v˜&≤‡¢ÚÚ‚Wá∆ñ6óBWó6ˆFR÷wVñFRF&vWBó2FñffW&VÁB6ˆÁFVÁB'íFVfñÊóFñˆ‚‡¢f"∆ÊFVDˆÂ6÷T6ˆÁFVÁB–¢Wá∆ñ6óEF&vWB«¿¢áF&vWE6V6ˆ‚”“7W'&VÁBÁ6V6ˆ‚bbF&vWDWó6ˆFR”“7W'&VÁBÊWó6ˆFRì∞¢f"6ˆÁFñÁ5&WVW7FVDWó6ˆFR“G'VS∞¢ñbá6RÁ6V6ˆ‚“ÁV∆¬bb6RÊWó6ˆFR“ÁV∆¬í∞¢fñÊ¬7“˜6W&ñW5∆ñ∆ó7C∞¢fñÊ¬ñGÇ–¢7ÚÊfñÊD˜&ñvñÊƒñÊFWÑ'ï6V6ˆ‰Wó6ˆFRá6RÁ6V6ˆ‚¬6RÊWó6ˆFRíÛÚ”∞¢ñbÜñGÇ„“í∞¢F&vWDñÊFWÇ“ñGÉ∞¢“V«6RñbÜÊWu∆ñ∆ó7BÊ∆VÊwFÇ”“í∞¢ÚÚ6ñÊv∆R&W6ˆ«fVB7G&V“ˆgFV‚Ü2‚VÁ'6V&∆RÊ÷RÇ%F˜'&VÁFñ¢ÚÚÉ"¬Êñ÷Rˆ'6ˆ«WFRÁV÷&W&ñÊrì≤óG2ˆÊRVÁG'íï2FÜR&WVW7FV@¢ÚÚWó6ˆFR.ù◊üäwùBFÜRfWF6Çv2Wó6ˆFR◊66˜VB‚FÜó2◊W7BÜˆ∆Bf˜"÷ÁV¿¢ÚÚ6ÜVWBñ6∑2FˆÚÜÊÚWá∆ñ6óBF&vWBí¬˜"∆VvóFñ÷FR6ñÊv∆WFˆ‡¢ÚÚv˜V∆B&R&V¶V7FVB&V∆˜rvóFÜ˜WBWfW"&VñÊr˜VÊVB‚÷ó'&˜'2FÜP¢ÚÚ∂˜F∆ñ‚7W'6˜"w2Wó6ˆFW2Á6ó¶R√“WÜV◊Fñˆ‚‡¢F&vWDñÊFWÇ“∞¢“V«6R∞¢∆ÊFVDˆÂ6÷T6ˆÁFVÁB“f«6S∞¢6ˆÁFñÁ5&WVW7FVDWó6ˆFR“f«6S∞¢ÚÚFÜRWÜ7BWó6ˆFRó6‚wBñ‚FÜó26˜W&6R‚Fˆ‚wBf∆¬&6≤FÚ&rVÁG'ê¢ÚÚ∫w^~)ﬁuBñ‚F˜'&VÁB˜&FW"FÜBw2ˆgFV‚‚WáG&2ˆ&ˆÁW26∆ó‚∆ÊBˆ‚FÜP¢ÚÚfó'7B$T¬Wó6ˆFRá6∂ó26V6ˆ‚Ú7V6ñ«2íÊBv&‚FÜRW6W"‡¢fñÊ¬fó'7E&V¬“7ÚÊvWDfó'7DWó6ˆFT˜&ñvñÊƒñÊFWÇÇíÛÚ”∞¢ñbÜfó'7E&V¬„“íF&vWDñÊFWÇ“fó'7E&V√∞¢ñbÜ÷˜VÁFVBbbf∆ñFFTWá∆ñ6óE6V∆V7Fñˆ‚í∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢u2G∑6RÁ6V6ˆÁ‘RG∑6RÊWó6ˆFW“Ê˜Bñ‚FÜó26˜W&6R∫w^~)ﬁuB∆ññÊrg&ˆ“FÜR7F'Br¿¢í¿¢í¿¢ì∞¢–¢–¢–¢ÚÚ6˜W&6R7vóF6Ç◊W7B&W7V÷RFÜR˜WFvˆñÊrWó6ˆFRw2˜6óFñˆ‚á6fVB&˜fRí‡¢ÚÚ6∆V"Áí∆ñÊvW&ñÊr÷ÁV¬◊6V∆V7Fñˆ‚7FFRfó'7C¢ñbFÜRW6W"ÜB÷ÁV∆«ê¢ÚÚßV◊VBFÚ‚Wó6ˆFRvóFÜñ‚FÜR∆7B32¬FÜB7F∆Rf∆r÷∂W0¢ÚÚˆ÷ñ&U&W7F˜&U&W7V÷V&ñ¬˜WBÊBFÜRÊWr6˜W&6R˜VÁ2B£ñÁ7FVBˆ`¢ÚÚ&W7V÷ñÊr‚FÜR7vóF6Çó2Ê˜B&÷ÁV¬Wó6ˆFRñ6≤"¬6ÚG&˜FÜRf∆r‡¢ˆó4÷ÁVƒWó6ˆFU6V∆V7Fñˆ‚“f«6S∞¢ˆ∆∆˜u&W7V÷Tf˜$÷ÁV≈6V∆V7Fñˆ‚“f«6S∞¢ÚÚ&W7V÷RFÜR6ÜV6∑ˆñÁFVBƒÙ4¬˜6óFñˆ‚¬Ê˜BG&∑BáFÜó2ó26˜W&6R7v ¢ÚÚ÷ñB÷Wó6ˆFR¬Ê˜Bg&W6Ç˜V‚í.ù◊üäwùB'WBˆÊ«ívÜV‚FÜRÊWr6˜W&6R∆ÊFVBˆ‡¢ÚÚFÜR6÷R6ˆÁFVÁC≤f∆∆&6≤Wó6ˆFR∂VW2óG2˜v‚G&∑B&W7V÷R‡¢f"6ˆ÷÷óGFVB“f«6S∞¢ñbÇf∆ñFFTWá∆ñ6óE6V∆V7Fñˆ‚í∞¢G'í∞¢6ˆ÷÷óGFVB“vóBˆ∆ˆE∆ñ∆ó7DñÊFWÇÄ¢F&vWDñÊFWÇ¿¢WF˜∆ì¢G'VR¿¢6∂óñÊóFñ≈6fS¢G'VR¿¢&VfW$∆ˆ6≈&W7V÷S¢∆ÊFVDˆÂ6÷T6ˆÁFVÁB¿¢7W&W75&W7V÷S¢7W&W75&W7V÷R¿¢&WVW7C¢&WVW7B¿¢ì∞¢“6F6ÇÜW'&˜"í∞¢ñbá&WVW7B”“ÁV∆¬í&WFá&˜s∞¢FV'Vu&ñÁBÇtWó6ˆFR6˜W&6R∆ˆBfñ∆VC¢FW'&˜"rì∞¢6ˆ÷÷óGFVB“f«6S∞¢–¢“V«6R∞¢ˆ÷ÁV≈6˜W&6TvFT7FófR“G'VS∞¢G'í∞¢G'í∞¢ñbÜ6ˆÁFñÁ5&WVW7FVDWó6ˆFRí∞¢6ˆ÷÷óGFVB“vóBˆ∆ˆE∆ñ∆ó7DñÊFWÇÄ¢F&vWDñÊFWÇ¿¢WF˜∆ì¢G'VR¿¢6∂óñÊóFñ≈6fS¢G'VR¿¢&VfW$∆ˆ6≈&W7V÷S¢∆ÊFVDˆÂ6÷T6ˆÁFVÁB¿¢7W&W75&W7V÷S¢7W&W75&W7V÷R¿¢&WVW7C¢&WVW7B¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6S¢6V∆V7FVE6˜W&6R¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÉ¢6˜W&6TñÊFWÇ¿¢ì∞¢–¢“6F6ÇÜW'&˜"í∞¢FV'Vu&ñÁBÄ¢u∆ñW#¢÷ÁV¬∆ñ∆ó7B6˜W&6R&V¶V7FVBp¢rÇG∂W'&˜"Á'VÁFñ÷UGóW“ír¿¢ì∞¢6ˆ÷÷óGFVB“f«6S∞¢–¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ñbÇ6ˆ÷÷óGFVBb`¢˜WFvˆñÊu∆ñ∆ó7B“ÁV∆¬b`¢˜WFvˆñÊu∆ñ∆ó7BÊó4Ê˜DV◊Gíí∞¢6WE7FFRÇÇí∞¢ˆ7FófU∆ñ∆ó7B“˜WFvˆñÊu∆ñ∆ó7C∞¢ˆ66ÜVE6W&ñW5∆ñ∆ó7B“ÁV∆√∞¢˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚≤≥∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“˜WFvˆñÊu6˜W&6TñÊFWÉ∞¢ˆ7W'&VÁDñÊFWÇ“˜WFvˆñÊtñÊFWÇÊ6∆◊É¬˜WFvˆñÊu∆ñ∆ó7BÊ∆VÊwFÇ“ì∞¢“ì∞¢fñÊ¬&W7F˜&VB“vóBˆ∆ˆE∆ñ∆ó7DñÊFWÇÄ¢ˆ7W'&VÁDñÊFWÇ¿¢WF˜∆ì¢G'VR¿¢6∂óñÊóFñ≈6fS¢G'VR¿¢&VfW$∆ˆ6≈&W7V÷S¢G'VR¿¢ì∞¢ñbá&W7F˜&VBbb˜WFvˆñÊu˜6óFñˆ‚‚GW&Fñˆ‚Á¶W&Úí∞¢ÚÚwV&FVC¢fñ«W&R◊FÇ&W7F˜&R◊W7BÊ˜B∆VfRFÜR&ˆˆ∂÷&≤@¢ÚÚFÜR÷W&7íˆb7G&V“FÜBÁ7vW'2FÜó26VV≤vóFÇ&W7F'B‡¢vóB˜6VV¥f˜%&W7V÷RÜ˜WFvˆñÊu˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2ì∞¢–¢“V«6RñbÇ6ˆ÷÷óGFVBb`¢˜WFvˆñÊtFó&V7EW&¬“ÁV∆¬b`¢˜WFvˆñÊtFó&V7EW&¬Êó4Ê˜DV◊Gíí∞¢ÚÚFó&V7B∆VÊ6ÇÜ2ÊÚ7FófR∆ñ∆ó7BFÚ&W7F˜&R‚FÜR6ÊFñFFP¢ÚÚf∆ñFF˜"Ü27F˜VBóG2÷VFñˆ‚fñ«W&R¬6ÚWá∆ñ6óF«í&V'Vñ∆@¢ÚÚFÜR˜WFvˆñÊrFó&V7B6W76ñˆ‚ñÁ7FVBˆb∆VfñÊrFÜR∆ñW"7F˜V@¢ÚÚvóFÇFÜR&V¶V7FVB∆ñ∆ó7B6V∆V7FVB‡¢6WE7FFRÇÇí∞¢ˆ7FófU∆ñ∆ó7B“ÁV∆√∞¢ˆ66ÜVE6W&ñW5∆ñ∆ó7B“ÁV∆√∞¢˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚≤≥∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“˜WFvˆñÊu6˜W&6TñÊFWÉ∞¢ˆ7W'&VÁDñÊFWÇ“˜WFvˆñÊtñÊFWÉ∞¢“ì∞¢G'í∞¢ˆ7FófTáGGÜVFW'2“˜WFvˆñÊtÜVFW'3∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñÜ˜WFvˆñÊtFó&V7EW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢ì∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢ñbÜ˜WFvˆñÊu˜6óFñˆ‚‚GW&Fñˆ‚Á¶W&Úí∞¢vóB˜6VV¥f˜%&W7V÷RÜ˜WFvˆñÊu˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2ì∞¢–¢ˆ7W'&VÁE7G&V’W&¬“˜WFvˆñÊtFó&V7EW&√∞¢VÊvóFVBÖ˜&W7F˜&UG&6µ&VfW&VÊ6W2Çíì∞¢“6F6Çá&W7F˜&TW'&˜"í∞¢FV'Vu&ñÁBÄ¢u∆ñW#¢˜WFvˆñÊrFó&V7B6˜W&6R&W7F˜&Rfñ∆VBp¢rÇG∑&W7F˜&TW'&˜"Á'VÁFñ÷UGóW“ír¿¢ì∞¢–¢–¢“fñÊ∆«í∞¢ˆ÷ÁV≈6˜W&6TvFT7FófR“f«6S∞¢˜&W7V÷UG&6∂ñÊtgFW%f∆ñFFñˆ‰vFRÇì∞¢–¢–¢ñbÇ÷˜VÁFVBí&WGW&‚f«6S∞¢ñbÇ6ˆ÷÷óGFVBbb&WVW7B“ÁV∆¬í∞¢ÚÚˆÊ«í&ˆ∆¬&6≤&W&Fñˆ‚‚ñb÷VFñ˜V‚Ü27F'FVB¬FÜR&WVW7@¢ÚÚ&WFñÁ2FÜRñÊ6ˆ÷ñÊrñFVÁFóGí6Ú&ˆw&W727Fó2vóFÇFÜB÷VFñ‡¢fñÊ¬&W7F˜&VB“&WVW7BÁ&W7F˜&U∆ñ∆ó7BÄ¢Çí”‚6WE7FFRÇÇí∞¢ˆ7FófU∆ñ∆ó7B“˜WFvˆñÊu∆ñ∆ó7C∞¢ˆ66ÜVE6W&ñW5∆ñ∆ó7B“˜WFvˆñÊt66ÜVE6W&ñW3∞¢˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚≤≥∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“˜WFvˆñÊu6˜W&6TñÊFWÉ∞¢ˆ7W'&VÁDñÊFWÇ“˜WFvˆñÊtñÊFWÉ∞¢ˆ7W'&VÁE7G&V’W&¬“˜WFvˆñÊtFó&V7EW&√∞¢ˆ7FófTáGGÜVFW'2“˜WFvˆñÊtÜVFW'3∞¢“í¿¢ì∞¢ñbá&W7F˜&VBívóB˜7vóF6Ñ÷F&∆ó7EF&vWBÇì∞¢–¢ñbá&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞†¢ñbÜ6ˆ÷÷óGFVBí∞¢VÊvóFVBÖˆ6ˆ÷÷óEf∆ñFFVE7G&V÷ñı6˜W&6Rá6V∆V7FVE6˜W&6Ríì∞¢–¢ñbáf∆ñFFTWá∆ñ6óE6V∆V7Fñˆ‚bb6ˆ÷÷óGFVBí∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÇuFÜó26˜W&6Ró2VÊfñ∆&∆R‚6Üˆ˜6RÊ˜FÜW"6˜W&6R‚rí¿¢í¿¢ì∞¢–†¢ÚÚVÊBG&Á6óFñˆ‚á6÷RGFW&‚2˜7vóF6ÖFı7G&V÷ñı6˜W&6Rê¢˜G&Á6óFñˆÂ7F˜Fñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6UFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6R“#∞¢˜G&Á6óFñˆÂÜ6S%7F'FVB“FFUFñ÷RÊÊ˜rÇì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢˜G&Á6óFñˆÂ7F˜Fñ÷W"“Fñ÷W"Ü6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Sí¬Çí∞¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"Á7F˜Çì∞¢˜G&Á6óFñˆÂ'VÊÊñÊr“f«6S∞¢˜&ñÊ&˜t7FófR“f«6S∞¢ñbÜ÷˜VÁFVBí6WE7FFRÇÇí∑“ì∞¢“ì∞¢&WGW&‚6ˆ÷÷óGFVC∞¢–†¢÷≈7G&ñÊr¬7G&ñÊs„Úˆ7FófTáGGÜVFW'3∞†¢gWGW&S«fˆñC‚˜7vóF6ÖFı7G&V÷ñı6˜W&6RÜñÁBñÊFWÇ¬7G&ñÊrW&¬í7ñÊ2∞¢ˆÜñFU6˜W&6U6ÜVWBÇì∞†¢ÚÚ6GW&R7W'&VÁB˜6óFñˆ‚&Vf˜&R7vóF6ÜñÊr6Ú∆ñ&6≤6ˆÁFñÁVW0¢ÚÚ6V÷∆W76«í‚ÜV∆BáVÊ∆ÊFVBí&W7V÷RF&vWB˜WG&Ê∑2FÜR∆ófR˜6óFñˆ‚∫w^~)ﬁu@¢ÚÚFÜR∆ófRf«VRó2&W7F'B'Fñf7BÊBFÜRÊWr6˜W&6R◊W7B˜V‚@¢ÚÚFÜR&ˆˆ∂÷&≤‚W&RVW'ì≤FÜRwV&B7Fó2&÷VB6ÚFÜRÊWr6˜W&6Rw2˜v‡¢ÚÚ∆ÊFñÊrÜ˜"fñ«W&Rí∂VW2FÜR&ˆˆ∂÷&≤&˜FV7FVB‡¢fñÊ¬ÜV∆E7vóF6Ñ◊2“˜&W7V÷Uw&óFTwV&BÊÜV∆EF&vWDñd&∆ˆ6∂VBÄ¢˜˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2¿¢ì∞¢fñÊ¬&W7V÷U˜6óFñˆ‚“ÜV∆E7vóF6Ñ◊2“ÁV∆¿¢ÚGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢ÜV∆E7vóF6Ñ◊2ê¢¢˜˜6óFñˆ„∞¢fñÊ¬&Wfñ˜W5W&¬“ˆ7W'&VÁE7G&V’W&√∞¢fñÊ¬&Wfñ˜W4ÜVFW'2“ˆ7FófTáGGÜVFW'3∞¢fñÊ¬&Wfñ˜W56˜W&6TñÊFWÇ“ˆ7W'&VÁE6˜W&6TñÊFWÉ∞¢fñÊ¬6˜W&6R–¢ÖˆVffV7FófU6˜W&6W2“ÁV∆¬b`¢ñÊFWÇ„“b`¢ñÊFWÇ¬ˆVffV7FófU6˜W&6W2Ê∆VÊwFÇê¢ÚˆVffV7FófU6˜W&6W2∂ñÊFWÖ–¢¢ÁV∆√∞†¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“ñÊFWÉ∞¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞†¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–†¢ñbÇ÷˜VÁFVBí&WGW&„∞†¢ˆ÷ÁV≈6˜W&6TvFT7FófR“G'VS∞†¢ÚÚf˜"ñ˜UGV&RV6ÇV∆óGíó2fñFVÚ÷ˆÊ«íG&6≤6Ü&ñÊrˆÊRVFñÚ7G&V–¢ÚÚávñFvWBÊVFñıW&¬í‚÷ó'&˜"FÜRñÊóFñ¬÷∆VÊ6Ç˜&FW&ñÊs¢˜V‚U4TB¿¢ÚÚGF6ÇFÜRWáFW&Ê¬VFñÚ¬6VV≤¬FÜV‚∆íßuÁ‚ùÁB6Ú&˜FÇG&6∑2∆ˆBñ‚7ñÊ0¢ÚÚÜGF6ÜñÊrVFñÚ÷ñB◊∆í÷∂W2◊b&W7ñÊ2ÊBG&ñgBí‚6˜W&6W2vóFÜ˜WB¢ÚÚ6W&FRVFñÚG&6≤áF˜'&VÁG2í∂VWFÜR∆ñ‚˜V‚÷ÊB◊∆íFÇ‡¢fñÊ¬Ü4WáFW&ÊƒVFñÚ–¢vñFvWBÊVFñıW&¬“ÁV∆¬bbvñFvWBÊVFñıW&¬Êó4Ê˜DV◊Gì∞†¢ÚÚf˜"Fó&V7B˜F˜'&VÁB7vóF6ÜW2¬˜∆ñW"Ê˜VÊFó66&G2FÜRˆ∆B÷VFñw0¢ÚÚ7V'FóF∆RG&6∑2¬6Ú‚7FófRWáFW&Ê¬ˆFFˆ‚7V'FóF∆Rv˜V∆B6ñ∆VÁF«ê¢ÚÚfÊó6ÇÊBFÜR66ÜVBñFVÁFñfñW'2v˜V∆BFÊv∆R‚&W6WBÊ˜rÜ÷ó'&˜'0¢ÚÚˆ∆ˆE∆ñ∆ó7DñÊFWÜí6ÚFÜRÊWr÷VFñ7F'G26∆V‚ÊBFFˆ‚◊7V'FóF∆P¢ÚÚ∆ˆvñ2&R◊'VÁ2‚FV∆ñ&W&FV«í‰ıBFˆÊRf˜"FÜRWáFW&Ê¬÷VFñÚÖñ˜UGV&Rê¢ÚÚFÇ∫w^~)ﬁuBFÜBf∆˜ró2∆VgBWÜ7F«í2&Vf˜&RFÚfˆñBÁí&Vw&W76ñˆ‚‡¢ñbÇÜ4WáFW&ÊƒVFñÚí∞¢˜&W6WE7V'FóF∆U7FFRÇì∞¢–†¢f"6ˆ÷÷óGFVB“f«6S∞¢G'í∞¢fñÊ¬f∆ñB“Ü4WáFW&ÊƒVFñ¢ÚvóBÇÇí7ñÊ2∞¢vóBˆ˜V‰÷VFñÜ÷≤‰÷VFñáW&¬í¬∆ì¢f«6R¬FW6ó&VE∆ì¢G'VRì∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢&WGW&‚ˆGW&Fñˆ‚‚GW&Fñˆ‚Á¶W&Û∞¢“íÇê¢¢vóB˜G'î˜VÂ7F'GWfˆBÄ¢W&¬¿¢áGGÜVFW'3¢6˜W&6SÚÊáGGÜVFW'2¿¢6˜W&6S¢6˜W&6R¿¢6˜W&6TñÊFWÉ¢ñÊFWÇ¿¢ì∞¢ñbÇ÷˜VÁFVBí&WGW&„∞¢ñbÇf∆ñBí∞¢Fá&˜r6ˆÁ7BÙ÷ÁV≈6˜W&6Uf∆ñFFñˆ‰fñ«W&RÇì∞¢–¢ñbÇ÷˜VÁFVBí&WGW&„∞¢ñbÜÜ4WáFW&ÊƒVFñÚí∞¢vóB˜6WDWáFW&ÊƒVFñıG&6≤ávñFvWBÊVFñıW&¬ì∞¢–¢ÚÚ6VV≤FÚFÜR˜6óFñˆ‚g&ˆ“FÜR&Wfñ˜W26˜W&6R‚˜6VV¥f˜%&W7V÷P¢ÚÚ&R‘$’2FÜRwV&BÜW&RÜV∆B◊F&vWBVW'íÊWfW"&W7F'FVBFÜP¢ÚÚ6WGF∆RvñÊF˜rí¬6Ú7vóF6ÜVB◊FÚ7G&V“FÜB&W7F'G2B6ÊÊ˜@¢ÚÚÜfRóG2fó'7BWF˜6fRfñ∆R„˜fW"FÜR6'&ñVB&ˆˆ∂÷&≤ßuÁ‚ùÁBFÜP¢ÚÚñFVÁFñ6¬fñ«W&RFÜRwV&BWÜó7G2f˜"¬ˆ‚FÜR7vóF6ÇFÇ‡¢ñbá&W7V÷U˜6óFñˆ‚‚GW&Fñˆ‚Á¶W&Úí∞¢vóB˜6VV¥f˜%&W7V÷Rá&W7V÷U˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2ì∞¢–¢ñbÜÜ4WáFW&ÊƒVFñÚí∞¢vóB˜∆ñW"Á∆íÇì∞¢“V«6R∞¢ÚÚ&W7F˜&R7F˜&VBVFñÚ˜7V'FóF∆RG&6≤&VfW&VÊ6W2f˜"FÜó26ˆÁFVÁ@¢ÚÚá6÷R2FÜR∆ñ∆ó7BFÇí‚6∂óVBf˜"FÜRWáFW&Ê¬÷VFñÚÖñ˜UGV&Rê¢ÚÚ66R&˜fR¬vÜW&RFÜR÷W&vVBVFñÚG&6≤ó26WBWá∆ñ6óF«íÊBG&6∞¢ÚÚ&VfW&VÊ6W2v˜V∆BfñváBóB‡¢Ú¢ÚÚfó&R÷ÊB÷f˜&vWC¢˜&W7F˜&UG&6µ&VfW&VÊ6W6vóG2˜vóDf˜%7V'FóF∆UG&6∑6¿¢ÚÚvÜñ6Çˆ∆«2WFÚ„W2ˆ‚÷VFñvóFÇÊÚV÷&VFFVB7V'FóF∆RG&6∑0¢ÚÚÜ6ˆ÷÷ˆ‚f˜"Fó&V7B’B˜F˜'&VÁB7G&V◊2í‚vóFñÊróBÜW&Rv˜V∆BÜˆ∆@¢ÚÚFÜR&∆6≤G&Á6óFñˆ‚˜fW&∆íf˜"FÜBvÜˆ∆RvóB.ù◊üäwùB&Vw&W76ñˆ‚g2FÜP¢ÚÚˆ∆BFó&V7B◊7vóF6ÇFÇ¬vÜñ6ÇVÊFVBFÜRG&Á6óFñˆ‚&ñváBgFW"FÜP¢ÚÚ6VV≤‚∆WBóB«íñ‚FÜR&6∂w&˜VÊC≤FÜR˜fW&∆íVÊG2&V∆˜rˆ‚Fñ÷R‡¢VÊvóFVBÖ˜&W7F˜&UG&6µ&VfW&VÊ6W2Çíì∞¢–¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“ñÊFWÉ∞¢ˆ7W'&VÁE7G&V’W&¬“W&√∞¢ˆ7FófTáGGÜVFW'2“6˜W&6SÚÊáGGÜVFW'3∞¢6ˆ÷÷óGFVB“G'VS∞¢VÊvóFVBÖˆ6ˆ÷÷óEf∆ñFFVE7G&V÷ñı6˜W&6Rá6˜W&6Ríì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢÷ÁV¬7G&V÷ñÚ6˜W&6R&V¶V7FVBÇG∂RÁ'VÁFñ÷UGóW“írì∞¢∆ˆu6˜W&6U6V∆V7Fñˆ‚Ä¢w∆ñW%˜7vóF6Ö˜&V¶V7FVBr¿¢6˜W&6S¢6˜W&6R¿¢ñÊFWÉ¢ñÊFWÇ¿¢&Wfñ˜W4ñÊFWÉ¢&Wfñ˜W56˜W&6TñÊFWÇ¿¢∆ñW#¢v◊br¿¢&V6ˆ„¢wf∆ñFFñˆÂˆfñ∆VBr¿¢ì∞¢ÚÚFÜR6ÊFñFFR∆ñW"ó27F˜VB'íFÜRf∆ñFF˜"‚&W7F˜&RFÜR∂Ê˜v‡¢ÚÚv˜&∂ñÊr7G&V“vÜV‚˜76ñ&∆R¬'WBÊWfW"f∆ñFFRˆfñ¬˜fW"FÚÊ˜FÜW ¢ÚÚ&˜s¢FÜó2v2‚Wá∆ñ6óBW6W"6V∆V7Fñˆ‚‡¢ñbá&Wfñ˜W5W&¬“ÁV∆¬bb&Wfñ˜W5W&¬Êó4Ê˜DV◊Gíí∞¢G'í∞¢ˆ7FófTáGGÜVFW'2“&Wfñ˜W4ÜVFW'3∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñá&Wfñ˜W5W&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢ì∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢ñbÜÜ4WáFW&ÊƒVFñÚí∞¢ÚÚñ˜UGV&R◊7Gñ∆R7∆óB7G&V◊3¢FÜR&V˜V‚G&˜VBFÜRWáFW&Ê¿¢ÚÚVFñÚG&6≤ßuÁ‚ùÁBvóFÜ˜WBFÜó2FÜR&W7F˜&VBfñFVÚ∆ó26ñ∆VÁB‡¢vóB˜6WDWáFW&ÊƒVFñıG&6≤ávñFvWBÊVFñıW&¬ì∞¢–¢ñbá&W7V÷U˜6óFñˆ‚‚GW&Fñˆ‚Á¶W&Úí∞¢vóB˜6VV¥f˜%&W7V÷Rá&W7V÷U˜6óFñˆ‚Êñ‰÷ñ∆∆ó6V6ˆÊG2ì∞¢–¢ˆ7W'&VÁE7G&V’W&¬“&Wfñ˜W5W&√∞¢ñbÇÜ4WáFW&ÊƒVFñÚí∞¢ÚÚ7V'FóF∆R7FFRv2&W6WBf˜"FÜR6ÊFñFFS≤'&ñÊrFÜRW6W"w0¢ÚÚ7V'FóF∆RˆVFñÚ6Üˆñ6W2&6≤ˆ‚FÜR&W7F˜&VB7G&V“‡¢VÊvóFVBÖ˜&W7F˜&UG&6µ&VfW&VÊ6W2Çíì∞¢–¢“6F6Çá&W7F˜&TW'&˜"í∞¢FV'Vu&ñÁBÄ¢u∆ñW#¢&Wfñ˜W26˜W&6R&W7F˜&Rfñ∆VBp¢rÇG∑&W7F˜&TW'&˜"Á'VÁFñ÷UGóW“ír¿¢ì∞¢–¢–¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“&Wfñ˜W56˜W&6TñÊFWÉ∞¢“fñÊ∆«í∞¢ˆ÷ÁV≈6˜W&6TvFT7FófR“f«6S∞¢˜&W7V÷UG&6∂ñÊtgFW%f∆ñFFñˆ‰vFRÇì∞¢–†¢ñbÇ÷˜VÁFVBí&WGW&„∞†¢ñbÇ6ˆ÷÷óGFVBí∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÇuFÜó26˜W&6Ró2VÊfñ∆&∆R‚6Üˆ˜6RÊ˜FÜW"6˜W&6R‚rí¿¢í¿¢ì∞¢–†¢˜G&Á6óFñˆÂ7F˜Fñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6UFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6R“#∞¢˜G&Á6óFñˆÂÜ6S%7F'FVB“FFUFñ÷RÊÊ˜rÇì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢˜G&Á6óFñˆÂ7F˜Fñ÷W"“Fñ÷W"Ü6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Sí¬Çí∞¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"Á7F˜Çì∞¢˜G&Á6óFñˆÂ'VÊÊñÊr“f«6S∞¢˜&ñÊ&˜t7FófR“f«6S∞¢ñbÜ÷˜VÁFVBí6WE7FFRÇÇí∑“ì∞¢“ì∞¢–†¢ÚÚZ47G&V÷ñÚEbwVñFRZ4Z4Z4Z4Z4Z4Z4Z4Z4Z4Z4Z4Z4Z4Z4 †¢7G&ñÊsÚˆfñÊDñÊóFñ≈7G&V÷ñıGd6ÜÊÊVƒñBÇí∞¢ÚÚW6RWá∆ñ6óF«í&˜fñFVB7W'&VÁB6ÜÊÊV¬î@¢ñbávñFvWBÁ7G&V÷ñıGd7W'&VÁD6ÜÊÊVƒñB“ÁV∆¬í∞¢&WGW&‚vñFvWBÁ7G&V÷ñıGd7W'&VÁD6ÜÊÊVƒñC∞¢–¢&WGW&‚ÁV∆√∞¢–†¢&ˆˆ¬vWBˆÜ57G&V÷ñıGdwVñFR”‡¢ˆVffV7FófU7G&V÷ñıGd6ÜÊÊV«2“ÁV∆¬b`¢ˆVffV7FófU7G&V÷ñıGd6ÜÊÊV«2Êó4Ê˜DV◊Gíb`¢vñFvWBÁ7G&V÷ñıGd6ÜÊÊV≈7vóF6Ö&˜fñFW"“ÁV∆√∞†¢&ˆˆ¬vWBˆÜ57G&V÷ñıGdÊWáB”‡¢ˆ7W'&VÁE7G&V÷ñıGd6ÜÊÊVƒñB“ÁV∆¬b`¢vñFvWBÁ7G&V÷ñıGdÊWáE&˜fñFW"“ÁV∆√∞†¢&ˆˆ¬vWBˆÜ4ÁîÊWáB”‡¢ˆÜ4ÊWáDWó6ˆFRÇí«¬vñFvWBÁ&WVW7D÷vñ4ÊWáB“ÁV∆¬«¬ˆÜ57G&V÷ñıGdÊWáC∞†¢fˆñB˜6Ü˜u7G&V÷ñıGdwVñFT˜fW&∆íÇí∞¢ñbÇˆÜ57G&V÷ñıGdwVñFRí&WGW&„∞¢6WE7FFRÇÇí∞¢˜6Ü˜u7G&V÷ñıGdwVñFR“G'VS∞¢ˆ6ˆÁG&ˆ«5fó6ñ&∆RÁf«VR“f«6S∞¢“ì∞¢–†¢fˆñBˆÜñFU7G&V÷ñıGdwVñFRÇí∞¢6WE7FFRÇÇí∞¢˜6Ü˜u7G&V÷ñıGdwVñFR“f«6S∞¢“ì∞¢–†¢fˆñB˜6WE7G&V÷ñıGdÊWáD∆ˆFñÊrÜ&ˆˆ¬∆ˆFñÊrí∞¢ñbÇ÷˜VÁFVB«¬˜6Ü˜u7G&V÷ñıGdÊWáD∆ˆFñÊr”“∆ˆFñÊrí&WGW&„∞¢6WE7FFRÇÇí∞¢˜6Ü˜u7G&V÷ñıGdÊWáD∆ˆFñÊr“∆ˆFñÊs∞¢“ì∞¢–†¢fˆñBˆ«ï7G&V÷ñıGdwVñFU∆ñ&6¥FFÄ¢7G&ñÊr6ÜÊÊVƒñB¬∞¢÷≈7G&ñÊr¬GñÊ÷ñ3„ÚÊ˜u∆ññÊr¿¢÷≈7G&ñÊr¬GñÊ÷ñ3„ÚÊWáEW¿¢“í∞¢fñÊ¬7W'&VÁB“ˆVffV7FófU7G&V÷ñıGd6ÜÊÊV«3∞¢ñbÜ7W'&VÁB”“ÁV∆¬«¬7W'&VÁBÊó4V◊Gíí&WGW&„∞†¢˜7G&V÷ñıGd6ÜÊÊV«4˜fW'&ñFR“7W'&VÁ@¢Ê÷ÇÜVÁG'íí∞¢fñÊ¬6˜í“÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“ÜVÁG'íì∞¢ñbÜ6˜ï≤vñBu“”“6ÜÊÊVƒñBí∞¢ñbÜÊ˜u∆ññÊr“ÁV∆¬í∞¢6˜ï≤vÊ˜u∆ññÊru““÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“ÜÊ˜u∆ññÊrì∞¢–¢ñbÜÊWáEW“ÁV∆¬í∞¢6˜ï≤vÊWáEWu““÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“ÜÊWáEWì∞¢–¢–¢&WGW&‚6˜ì∞¢“ê¢ÁFÙ∆ó7BÜw&˜v&∆S¢f«6Rì∞¢–†¢∆ó7C≈F˜'&VÁC„Ú˜'6U7G&V÷ñıGe6˜W&6W2ÜGñÊ÷ñ2&u6˜W&6W2í∞¢ñbá&u6˜W&6W2ó2∆ó7Bí&WGW&‚ÁV∆√∞¢&WGW&‚&u6˜W&6W0¢Ê÷Ä¢á2í”‡¢2ó2÷ÚF˜'&VÁBÊg&ˆ‘ß6ˆ‚Ñ÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“á2íí¢ÁV∆¬¿¢ê¢ÁvÜW&UGóS≈F˜'&VÁC‚Çê¢ÁFÙ∆ó7BÇì∞¢–†¢gWGW&S«fˆñC‚˜7vóF6ÖFı7G&V÷ñıGd6ÜÊÊV¬Ä¢7G&ñÊr6ÜÊÊVƒñB¿¢7G&ñÊrW&¬¿¢7G&ñÊrFóF∆R¬∞¢7G&ñÊsÚ6ˆÁFVÁDñ÷F$ñB¿¢7G&ñÊsÚ6ˆÁFVÁEGóR¿¢ñÁCÚ6ˆÁFVÁE6V6ˆ‚¿¢ñÁCÚ6ˆÁFVÁDWó6ˆFR¿¢÷≈7G&ñÊr¬GñÊ÷ñ3„ÚÊ˜u∆ññÊr¿¢÷≈7G&ñÊr¬GñÊ÷ñ3„ÚÊWáEW¿¢F˜V&∆SÚ7F'DEW&6VÁB¿¢∆ó7C≈F˜'&VÁC„ÚÊWu6˜W&6W2¿¢ñÁCÚÊWu6˜W&6TñÊFWÇ¿¢gWGW&S≈7G&ñÊsÛ‚gVÊ7Fñˆ‚ÖF˜'&VÁBìÚ6˜W&6U&W6ˆ«fW"¿¢“í7ñÊ2∞¢ˆÜñFU7G&V÷ñıGdwVñFRÇì∞¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢ˆ7W'&VÁE7G&V÷ñıGd6ÜÊÊVƒñB“6ÜÊÊVƒñC∞¢ˆGñÊ÷ñ5FóF∆R“FóF∆S∞¢ˆ7W'&VÁE7G&V÷ñıGd6ˆÁFVÁDñ÷F$ñB“6ˆÁFVÁDñ÷F$ñC∞¢ˆ7W'&VÁE7G&V÷ñıGd6ˆÁFVÁEGóR“6ˆÁFVÁEGóS∞¢ˆ7W'&VÁE7G&V÷ñıGd6ˆÁFVÁE6V6ˆ‚“6ˆÁFVÁE6V6ˆ„∞¢ˆ7W'&VÁE7G&V÷ñıGd6ˆÁFVÁDWó6ˆFR“6ˆÁFVÁDWó6ˆFS∞¢ˆ7W'&VÁE7G&V÷ñıGd6ˆÁFVÁEFóF∆R“FóF∆S∞¢ˆ«ï7G&V÷ñıGdwVñFU∆ñ&6¥FFÄ¢6ÜÊÊVƒñB¿¢Ê˜u∆ññÊs¢Ê˜u∆ññÊr¿¢ÊWáEW¢ÊWáEW¿¢ì∞¢ñbÜÊWu6˜W&6W2“ÁV∆¬í∞¢˜7G&V÷ñı6˜W&6W4˜fW'&ñFR“ÊWu6˜W&6W3∞¢ˆ7W'&VÁE6˜W&6TñÊFWÇ“ÊWu6˜W&6TñÊFWÇÛÚ∞¢–¢ñbá6˜W&6U&W6ˆ«fW"“ÁV∆¬í∞¢˜&W6ˆ«fU7G&V÷ñı6˜W&6T˜fW'&ñFR“6˜W&6U&W6ˆ«fW#∞¢–¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞†¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–†¢˜&W6WE7V'FóF∆U7FFRÇì∞¢˜6ñÊv∆Tfñ∆Tñ÷F$ñB“ÁV∆√∞¢˜6ñÊv∆Tfñ∆Tñ÷F$fWF6ÜVB“f«6S∞¢˜&W6WD∆ˆ6ƒ6ˆ◊∆WFñˆÂ7FFRÇì∞†¢G'í∞¢˜ñµµ&WG'îñB≤≥∞¢vóBˆ˜V‰÷VFñÜ÷≤‰÷VFñáW&¬í¬∆ì¢G'VRì∞¢ˆ7W'&VÁE7G&V’W&¬“W&√∞¢vóB˜6WE7V'FóF∆UG&6µvóFÑFñvÊ˜7Fñ72Ä¢÷≤Â7V'FóF∆UG&6≤ÊÊÚÇí¿¢6˜W&6S¢w7G&V÷ñÚ◊Gb◊7vóF6Ç÷Fó6&∆R÷WFÚr¿¢ì∞¢ñbá7F'DEW&6VÁB“ÁV∆¬bb7F'DEW&6VÁB‚í∞¢ÚÚ«í7F'B˜6óFñˆ‚ˆÊ6RGW&Fñˆ‚ó2∂Ê˜v‡¢˜∆ñW"Á7G&V“ÊGW&Fñˆ‚Êfó'7EvÜW&RÇÜBí”‚B‚GW&Fñˆ‚Á¶W&ÚíÁFÜV‚ÇÜBí∞¢ñbÜ÷˜VÁFVBí∞¢fñÊ¬6VVµFÚ“GW&Fñˆ‚Ä¢÷ñ∆∆ó6V6ˆÊG3¢ÜBÊñ‰÷ñ∆∆ó6V6ˆÊG2¢7F'DEW&6VÁBíÁ&˜VÊBÇí¿¢ì∞¢˜∆ñW"Á6VV≤á6VVµFÚì∞¢–¢“ì∞¢–¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢7G&V÷ñÚEb6ÜÊÊV¬7vóF6Çfñ∆VC¢FRrì∞¢–†¢ñbÇ÷˜VÁFVBí&WGW&„∞†¢ÚÚVÊBG&Á6óFñˆ‡¢˜G&Á6óFñˆÂ7F˜Fñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6UFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6R“#∞¢˜G&Á6óFñˆÂÜ6S%7F'FVB“FFUFñ÷RÊÊ˜rÇì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢˜G&Á6óFñˆÂ7F˜Fñ÷W"“Fñ÷W"Ü6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Sí¬Çí∞¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"Á7F˜Çì∞¢˜G&Á6óFñˆÂ'VÊÊñÊr“f«6S∞¢˜&ñÊ&˜t7FófR“f«6S∞¢ñbÜ÷˜VÁFVBí6WE7FFRÇÇí∑“ì∞¢“ì∞¢–†¢gWGW&S∆&ˆˆ√‚ˆvıFÙÊWáE7G&V÷ñıGe6∆˜Bá∞¢&ˆˆ¬&W7V÷T7W'&VÁDˆ‰fñ«W&R“G'VR¿¢“í7ñÊ2∞¢fñÊ¬&WVW7DÊWáB“vñFvWBÁ7G&V÷ñıGdÊWáE&˜fñFW#∞¢fñÊ¬6ÜÊÊVƒñB“ˆ7W'&VÁE7G&V÷ñıGd6ÜÊÊVƒñC∞¢ñbá&WVW7DÊWáB”“ÁV∆¬«¬6ÜÊÊVƒñB”“ÁV∆¬«¬6ÜÊÊVƒñBÊó4V◊Gíí∞¢&WGW&‚f«6S∞¢–¢ñbÖ˜6Ü˜u7G&V÷ñıGdÊWáD∆ˆFñÊrí∞¢&WGW&‚G'VS∞¢–†¢÷≈7G&ñÊr¬GñÊ÷ñ3„Ú&W7V«C∞¢˜6WE7G&V÷ñıGdÊWáD∆ˆFñÊráG'VRì∞¢G'í∞¢&W7V«B“vóB&WVW7DÊWáBÜ6ÜÊÊVƒñBì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢7G&V÷ñÚEbÊWáBfñ∆VC¢FRrì∞¢–†¢ñbÇ÷˜VÁFVBí&WGW&‚G'VS∞¢˜6WE7G&V÷ñıGdÊWáD∆ˆFñÊrÜf«6Rì∞†¢ñbá&W7V«B”“ÁV∆¬í∞¢6WE7FFRÇÇí”‚ˆó5G&Á6óFñˆÊñÊr“f«6Rì∞¢ñbÇ&W7V÷T7W'&VÁDˆ‰fñ«W&Rí&WGW&‚f«6S∞¢G'í∞¢vóB˜∆ñW"Á∆íÇì∞¢“6F6ÇÖÚí∑–¢&WGW&‚G'VS∞¢–†¢fñÊ¬W&¬“&W7V«E≤wW&¬u“27G&ñÊsÛ∞¢fñÊ¬FóF∆R“&W7V«E≤wFóF∆Ru“27G&ñÊsÚÛÚˆGñÊ÷ñ5FóF∆S∞¢ñbáW&¬”“ÁV∆¬«¬W&¬Êó4V◊Gíí∞¢6WE7FFRÇÇí”‚ˆó5G&Á6óFñˆÊñÊr“f«6Rì∞¢ñbÇ&W7V÷T7W'&VÁDˆ‰fñ«W&Rí&WGW&‚f«6S∞¢G'í∞¢vóB˜∆ñW"Á∆íÇì∞¢“6F6ÇÖÚí∑–¢&WGW&‚G'VS∞¢–†¢fñÊ¬ÊWu6˜W&6W2“˜'6U7G&V÷ñıGe6˜W&6W2á&W7V«E≤w7G&V÷ñı6˜W&6W2u“ì∞¢fñÊ¬6˜W&6U&W6ˆ«fW"–¢&W7V«E≤w6˜W&6U&W6ˆ«fW"u“2gWGW&S≈7G&ñÊsÛ‚gVÊ7Fñˆ‚ÖF˜'&VÁBìÛ∞†¢vóB˜7vóF6ÖFı7G&V÷ñıGd6ÜÊÊV¬Ä¢&W7V«E≤v6ÜÊÊVƒñBu“27G&ñÊsÚÛÚ6ÜÊÊVƒñB¿¢W&¬¿¢FóF∆R¿¢6ˆÁFVÁDñ÷F$ñC¢&W7V«E≤v6ˆÁFVÁDñ÷F$ñBu“27G&ñÊsÚ¿¢6ˆÁFVÁEGóS¢&W7V«E≤v6ˆÁFVÁEGóRu“27G&ñÊsÚ¿¢6ˆÁFVÁE6V6ˆ„¢á&W7V«E≤v6ˆÁFVÁE6V6ˆ‚u“2ÁV”ÚìÚÁFÙñÁBÇí¿¢6ˆÁFVÁDWó6ˆFS¢á&W7V«E≤v6ˆÁFVÁDWó6ˆFRu“2ÁV”ÚìÚÁFÙñÁBÇí¿¢Ê˜u∆ññÊs¢&W7V«E≤vÊ˜u∆ññÊru“ó2÷ ¢Ú÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“á&W7V«E≤vÊ˜u∆ññÊru“2÷ê¢¢ÁV∆¬¿¢ÊWáEW¢&W7V«E≤vÊWáEWu“ó2÷ ¢Ú÷≈7G&ñÊr¬GñÊ÷ñ3‚Êg&ˆ“á&W7V«E≤vÊWáEWu“2÷ê¢¢ÁV∆¬¿¢7F'DEW&6VÁC¢á&W7V«E≤w7F'DEW&6VÁBu“2ÁV”ÚìÚÁFÙF˜V&∆RÇí¿¢ÊWu6˜W&6W3¢ÊWu6˜W&6W2¿¢ÊWu6˜W&6TñÊFWÉ¢á&W7V«E≤w7G&V÷ñÙ7W'&VÁE6˜W&6TñÊFWÇu“2ÁV”ÚìÚÁFÙñÁBÇí¿¢6˜W&6U&W6ˆ«fW#¢6˜W&6U&W6ˆ«fW"¿¢ì∞¢&WGW&‚G'VS∞¢–†¢ÚÚÚ7vóF6ÇFÚ7V6ñfñ26ÜÊÊV¬'íîBÜg&ˆ“6ÜÊÊV¬wVñFRê¢gWGW&S«fˆñC‚ˆvıFÙ6ÜÊÊVƒ'îñBÑ6ÜÊÊVƒVÁG'í6ÜÊÊV¬í7ñÊ2∞¢ˆÜñFT6ÜÊÊVƒwVñFT˜fW&∆íÇì∞†¢fñÊ¬&WVW7B“vñFvWBÁ&WVW7D6ÜÊÊVƒ'îñC∞¢ñbá&WVW7B”“ÁV∆¬í∞¢FV'Vu&ñÁBÇu∆ñW#¢&WVW7D6ÜÊÊVƒ'îñBÊ˜B&˜fñFVBrì∞¢&WGW&„∞¢–†¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢ˆ7W'&VÁD6ÜÊÊVƒñB“6ÜÊÊV¬ÊñC∞¢ˆ7W'&VÁD6ÜÊÊVƒÊ÷R“6ÜÊÊV¬ÊÊ÷S∞¢ñbÜ6ÜÊÊV¬ÊÁV÷&W"“ÁV∆¬í∞¢ˆ7W'&VÁD6ÜÊÊVƒÁV÷&W"“6ÜÊÊV¬ÊÁV÷&W#∞¢–¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞†¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–†¢÷≈7G&ñÊr¬GñÊ÷ñ3„Úñ∆ˆC∞¢G'í∞¢ñ∆ˆB“vóB&WVW7BÜ6ÜÊÊV¬ÊñBì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢6ÜÊÊV¬7vóF6Ç'íîBfñ∆VC¢FRrì∞¢–†¢ñbÇ÷˜VÁFVBí&WGW&„∞†¢ñbáñ∆ˆB”“ÁV∆¬í∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“{ßuÁ‚ùÁB4Ñ‰‰T¬5tïD4ÇdîƒTBs∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢fñÊ¬GñÊ÷ñ2&uW&¬“ñ∆ˆE≤vfó'7EW&¬u“ÛÚñ∆ˆE≤wW&¬u”∞¢fñÊ¬GñÊ÷ñ2&uFóF∆R“ñ∆ˆE≤vfó'7EFóF∆Ru“ÛÚñ∆ˆE≤wFóF∆Ru”∞¢fñÊ¬7G&ñÊrÊWáEW&¬“&uW&¬ó27G&ñÊrÚ&uW&¬¢rs∞¢fñÊ¬7G&ñÊrÊWáEFóF∆R“&uFóF∆Ró27G&ñÊrÚ&uFóF∆R¢rs∞†¢ÚÚWFFR6ÜÊÊV¬÷WFFFg&ˆ“ñ∆ˆBñb&˜fñFV@¢fñÊ¬7G&ñÊsÚñ∆ˆD6ÜÊÊVƒÊ÷R“ñ∆ˆE≤v6ÜÊÊVƒÊ÷Ru“ó27G&ñÊp¢Úáñ∆ˆE≤v6ÜÊÊVƒÊ÷Ru“27G&ñÊrê¢¢ÁV∆√∞¢fñÊ¬7G&ñÊsÚñ∆ˆD6ÜÊÊVƒñB“ñ∆ˆE≤v6ÜÊÊVƒñBu“ó27G&ñÊp¢Úáñ∆ˆE≤v6ÜÊÊVƒñBu“27G&ñÊrê¢¢ÁV∆√∞¢fñÊ¬GñÊ÷ñ26ÜÊÊVƒÁV÷&W%&r“ñ∆ˆE≤v6ÜÊÊVƒÁV÷&W"u”∞¢ñÁCÚñ∆ˆD6ÜÊÊVƒÁV÷&W#∞¢ñbÜ6ÜÊÊVƒÁV÷&W%&ró2ñÁBí∞¢ñ∆ˆD6ÜÊÊVƒÁV÷&W"“6ÜÊÊVƒÁV÷&W%&s∞¢“V«6RñbÜ6ÜÊÊVƒÁV÷&W%&ró27G&ñÊrí∞¢ñ∆ˆD6ÜÊÊVƒÁV÷&W"“ñÁBÁG'ï'6RÜ6ÜÊÊVƒÁV÷&W%&rì∞¢–†¢6WE7FFRÇÇí∞¢ñbáñ∆ˆD6ÜÊÊVƒñB“ÁV∆¬íˆ7W'&VÁD6ÜÊÊVƒñB“ñ∆ˆD6ÜÊÊVƒñC∞¢ñbáñ∆ˆD6ÜÊÊVƒÊ÷R“ÁV∆¬bbñ∆ˆD6ÜÊÊVƒÊ÷RÁG&ñ“ÇíÊó4Ê˜DV◊Gíí∞¢ˆ7W'&VÁD6ÜÊÊVƒÊ÷R“ñ∆ˆD6ÜÊÊVƒÊ÷S∞¢–¢ñbáñ∆ˆD6ÜÊÊVƒÁV÷&W"“ÁV∆¬í∞¢ˆ7W'&VÁD6ÜÊÊVƒÁV÷&W"“ñ∆ˆD6ÜÊÊVƒÁV÷&W#∞¢–¢“ì∞†¢˜&ó6TFV'&ñgî&ÊÊW"Çì∞†¢ñbÜÊWáEW&¬Êó4V◊Gíí∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“∫w^~)ﬁv4Ñ‰‰T¬Ñ2‰Ú5E$T’2s∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢ñbÜÊWáEFóF∆RÊó4Ê˜DV◊Gíí∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“nù◊üäwù∫w^~)ﬁw¢4ît‰¬5Tï$TBs∞¢˜Ge7FFñ57V'FWáB“∫w^~)ﬁwbG∂ÊWáEFóF∆RÁFıWW$66RÇó“s∞¢“ì∞¢–†¢ÚÚ6∆V"7V'FóF∆RÊBî‘D"7FFRvÜV‚7vóF6ÜñÊr6ÜÊÊV«0¢˜&W6WE7V'FóF∆U7FFRÇì∞¢˜6ñÊv∆Tfñ∆Tñ÷F$ñB“ÁV∆√∞¢˜6ñÊv∆Tfñ∆Tñ÷F$fWF6ÜVB“f«6S∞†¢G'í∞¢˜ñµµ&WG'îñB≤≥∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñÜÊWáEW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢ì∞¢ˆ7W'&VÁE7G&V’W&¬“ÊWáEW&√∞¢ÚÚFó6&∆RWFÚ÷VÊ&∆VBV÷&VFFVB7V'FóF∆W2FÚ&WfVÁBGW∆ñ6FW0¢vóB˜6WE7V'FóF∆UG&6µvóFÑFñvÊ˜7Fñ72Ä¢÷≤Â7V'FóF∆UG&6≤ÊÊÚÇí¿¢6˜W&6S¢v6ÜÊÊV¬◊7vóF6Ç÷Fó6&∆R÷WFÚr¿¢ì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢fñ∆VBFÚ˜V‚6ÜÊÊV¬7G&V”¢FRrì∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“{ßuÁ‚ùÁB4Ñ‰‰T¬5tïD4ÇdîƒTBs∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢ñbÜÊWáEFóF∆RÊó4Ê˜DV◊Gíí∞¢ˆGñÊ÷ñ5FóF∆R“ÊWáEFóF∆S∞¢–¢“ì∞¢–¢–†¢ÚÚÚ7vóF6ÇFÚFÜRÊWáBFV'&ñgíEb6ÜÊÊV¬Ñ÷VFñ∂óBf∆∆&6≤ê¢gWGW&S«fˆñC‚ˆvıFÙÊWáD6ÜÊÊV¬Çí7ñÊ2∞¢fñÊ¬&WVW7B“vñFvWBÁ&WVW7DÊWáD6ÜÊÊV√∞¢ñbá&WVW7B”“ÁV∆¬í∞¢&WGW&„∞¢–†¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢“ì∞¢˜7F'EG&Á6óFñˆ‰˜fW&∆íÇì∞†¢G'í∞¢vóB˜∆ñW"ÁW6RÇì∞¢“6F6ÇÖÚí∑–†¢÷≈7G&ñÊr¬GñÊ÷ñ3„Úñ∆ˆC∞¢G'í∞¢ñ∆ˆB“vóB&WVW7BÇì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢ÊWáB6ÜÊÊV¬&WVW7Bfñ∆VC¢FRrì∞¢–†¢ñbÇ÷˜VÁFVBí∞¢&WGW&„∞¢–†¢ñbáñ∆ˆB”“ÁV∆¬í∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“∫w^~)ﬁv4Ñ‰‰T¬5tïD4ÇdîƒTBs∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢fñÊ¬GñÊ÷ñ2&uW&¬“ñ∆ˆE≤vfó'7EW&¬u“ÛÚñ∆ˆE≤wW&¬u”∞¢fñÊ¬GñÊ÷ñ2&uFóF∆R“ñ∆ˆE≤vfó'7EFóF∆Ru“ÛÚñ∆ˆE≤wFóF∆Ru”∞¢fñÊ¬7G&ñÊrÊWáEW&¬“&uW&¬ó27G&ñÊrÚ&uW&¬¢rs∞¢fñÊ¬7G&ñÊrÊWáEFóF∆R“&uFóF∆Ró27G&ñÊrÚ&uFóF∆R¢rs∞†¢fñÊ¬7G&ñÊsÚ6ÜÊÊVƒÊ÷R“ñ∆ˆE≤v6ÜÊÊVƒÊ÷Ru“ó27G&ñÊp¢Úáñ∆ˆE≤v6ÜÊÊVƒÊ÷Ru“27G&ñÊrê¢¢ÁV∆√∞¢fñÊ¬7G&ñÊsÚ6ÜÊÊVƒñB“ñ∆ˆE≤v6ÜÊÊVƒñBu“ó27G&ñÊp¢Úáñ∆ˆE≤v6ÜÊÊVƒñBu“27G&ñÊrê¢¢ÁV∆√∞¢fñÊ¬GñÊ÷ñ26ÜÊÊVƒÁV÷&W%&r“ñ∆ˆE≤v6ÜÊÊVƒÁV÷&W"u”∞¢ñÁCÚ6ÜÊÊVƒÁV÷&W#∞¢ñbÜ6ÜÊÊVƒÁV÷&W%&ró2ñÁBí∞¢6ÜÊÊVƒÁV÷&W"“6ÜÊÊVƒÁV÷&W%&s∞¢“V«6RñbÜ6ÜÊÊVƒÁV÷&W%&ró27G&ñÊrí∞¢6ÜÊÊVƒÁV÷&W"“ñÁBÁG'ï'6RÜ6ÜÊÊVƒÁV÷&W%&rì∞¢–†¢ñbÇÜ6ÜÊÊVƒÊ÷R“ÁV∆¬bb6ÜÊÊVƒÊ÷RÁG&ñ“ÇíÊó4Ê˜DV◊Gíí«¿¢6ÜÊÊVƒÁV÷&W"“ÁV∆¬«¿¢6ÜÊÊVƒñB“ÁV∆¬í∞¢6WE7FFRÇÇí∞¢ñbÜ6ÜÊÊVƒñB“ÁV∆¬í∞¢ˆ7W'&VÁD6ÜÊÊVƒñB“6ÜÊÊVƒñC∞¢–¢ñbÜ6ÜÊÊVƒÊ÷R“ÁV∆¬bb6ÜÊÊVƒÊ÷RÁG&ñ“ÇíÊó4Ê˜DV◊Gíí∞¢ˆ7W'&VÁD6ÜÊÊVƒÊ÷R“6ÜÊÊVƒÊ÷S∞¢–¢ñbÜ6ÜÊÊVƒÁV÷&W"“ÁV∆¬í∞¢ˆ7W'&VÁD6ÜÊÊVƒÁV÷&W"“6ÜÊÊVƒÁV÷&W#∞¢–¢“ì∞¢˜&ó6TFV'&ñgî&ÊÊW"Çì∞¢–†¢ñbÜÊWáEW&¬Êó4V◊Gíí∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“{ßuÁ‚ùÁB4Ñ‰‰T¬Ñ2‰Ú5E$T’2s∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢ñbÜÊWáEFóF∆RÊó4Ê˜DV◊Gíí∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“∫w^~)ﬁw€ßuÁ‚ùÁb4ît‰¬5Tï$TBs∞¢˜Ge7FFñ57V'FWáB“{ßuÁ‚ùÁbG∂ÊWáEFóF∆RÁFıWW$66RÇó“s∞¢“ì∞¢–†¢ÚÚ6∆V"7V'FóF∆RÊBî‘D"7FFRvÜV‚7vóF6ÜñÊr6ÜÊÊV«0¢˜&W6WE7V'FóF∆U7FFRÇì∞¢˜6ñÊv∆Tfñ∆Tñ÷F$ñB“ÁV∆√∞¢˜6ñÊv∆Tfñ∆Tñ÷F$fWF6ÜVB“f«6S∞†¢G'í∞¢ÚÚ6Ê6V¬ÁíˆÊvˆñÊrñµ≤&WG'ívÜV‚7vóF6ÜñÊr6ÜÊÊV«0¢˜ñµµ&WG'îñB≤≥∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñÜÊWáEW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢ì∞¢ˆ7W'&VÁE7G&V’W&¬“ÊWáEW&√∞¢ÚÚFó6&∆RWFÚ÷VÊ&∆VBV÷&VFFVB7V'FóF∆W2FÚ&WfVÁBGW∆ñ6FW0¢vóB˜6WE7V'FóF∆UG&6µvóFÑFñvÊ˜7Fñ72Ä¢÷≤Â7V'FóF∆UG&6≤ÊÊÚÇí¿¢6˜W&6S¢vÊWáB÷6ÜÊÊV¬÷Fó6&∆R÷WFÚr¿¢ì∞¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇu∆ñW#¢fñ∆VBFÚ˜V‚ÊWáB6ÜÊÊV¬7G&V”¢FRrì∞¢6WE7FFRÇÇí∞¢˜Ge7FFñ4÷W76vR“{ßuÁ‚ùÁB4Ñ‰‰T¬5tïD4ÇdîƒTBs∞¢˜Ge7FFñ57V'FWáB“rs∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢&WGW&„∞¢–†¢ñbávñFvWBÁ7F'Dg&ˆ’&ÊFˆ“í∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢fñÊ¬ˆfg6WB“˜&ÊFˆ’7F'Dˆfg6WBÖˆGW&Fñˆ‚ì∞¢ñbÜˆfg6WB“ÁV∆¬í∞¢vóB˜∆ñW"Á6VV≤Üˆfg6WBì∞¢–¢“V«6RñbávñFvWBÁ7F'DEW&6VÁB“ÁV∆¬í∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢fñÊ¬ˆfg6WB“˜W&6VÁE7F'Dˆfg6WBÖˆGW&Fñˆ‚ì∞¢ñbÜˆfg6WB“ÁV∆¬í∞¢vóB˜∆ñW"Á6VV≤Üˆfg6WBì∞¢–¢–†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ñbÜÊWáEFóF∆RÊó4Ê˜DV◊Gíí∞¢ˆGñÊ÷ñ5FóF∆R“ÊWáEFóF∆S∞¢–¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢–¢–†¢ÚÚÚÊfñvFRFÚ&Wfñ˜W2Wó6ˆFP¢gWGW&S«fˆñC‚ˆvıFı&Wfñ˜W4Wó6ˆFRÇí7ñÊ2∞¢ÚÚ6Ü˜r&∆6≤67&VV‚GW&ñÊrG&Á6óFñˆ‚FÚÜñFR&Wfñ˜W2g&÷P¢ˆ6∆V$'VffW&ñÊtñÊFñ6F˜"Çì∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“G'VS∞¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢“ì∞†¢fñÊ¬&Wfñ˜W4ñÊFWÇ“ˆfñÊE&Wfñ˜W4Wó6ˆFTñÊFWÇÇì∞¢ñbá&Wfñ˜W4ñÊFWÇ“”í∞¢ÚÚ÷&≤FÜó22÷ÁV¬Wó6ˆFR6V∆V7Fñˆ‡¢˜6WD÷ÁV≈6V∆V7Fñˆ‰÷ˆFRÇì∞¢vóBˆ∆ˆE∆ñ∆ó7DñÊFWÇá&Wfñ˜W4ñÊFWÇ¬WF˜∆ì¢G'VRì∞¢“V«6R∞¢ÚÚ&WñˆÊBFÜR6≤w27F'C¢fWF6ÇFÜR&Wfñ˜W2Wó6ˆFRñ‚◊∆ñW"‡¢ñbÖˆ6‰fWF6ÑWó6ˆFW2í∞¢fñÊ¬6R“˜G&∑E6V6ˆ‰Wó6ˆFRÇì∞¢fñÊ¬&Wb“á6RÁ6V6ˆ‚“ÁV∆¬bb6RÊWó6ˆFR“ÁV∆¬ê¢ÚˆF¶6VÁDWó6ˆFRá6RÁ6V6ˆ‚¬6RÊWó6ˆFR¬”ê¢¢ÁV∆√∞¢ñbá&Wb“ÁV∆¬í∞¢vóBˆfWF6ÑÊE∆îWó6ˆFRá&Wb‚C¬&Wb‚C"ì∞¢&WGW&„∞¢–¢–¢ÚÚ6∆V"G&Á6óFñˆ‚7FFRñbÊÚ&Wfñ˜W2Wó6ˆFRf˜VÊ@¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢–¢–¢–†¢ÚÚÚ÷&≤FÜR7W'&VÁBWó6ˆFR2fñÊó6ÜVBñbóBw26W&ñW0¢gWGW&S«fˆñC‚ˆ÷&¥7W'&VÁDWó6ˆFT4fñÊó6ÜVBÇí7ñÊ2∞¢fñÊ¬6W&ñW5∆ñ∆ó7B“˜6W&ñW5∆ñ∆ó7C∞¢ÚÚ6ñÊv∆R÷fñ∆R6W&ñW2∆ñ&6≥¢W6RvñFvWB&◊0¢ñbÇá6W&ñW5∆ñ∆ó7B”“ÁV∆¬«¬6W&ñW5∆ñ∆ó7BÊó56W&ñW2íb`¢vñFvWBÊ6ˆÁFVÁEGóR”“w6W&ñW2rb`¢vñFvWBÊ6ˆÁFVÁE6V6ˆ‚“ÁV∆¬b`¢vñFvWBÊ6ˆÁFVÁDWó6ˆFR“ÁV∆¬b`¢vñFvWBÊ6ˆÁFVÁDñ÷F$ñB“ÁV∆¬í∞¢ˆ7W'&VÁDWó6ˆFT÷&∂VD4fñÊó6ÜVB“G'VS∞¢G'í∞¢vóB7F˜&vU6W'fñ6RÊ÷&¥Wó6ˆFT4fñÊó6ÜVBÄ¢6W&ñW5FóF∆S¢vñFvWBÊ6ˆÁFVÁEFóF∆RÛÚvñFvWBÁFóF∆R¿¢6V6ˆ„¢vñFvWBÊ6ˆÁFVÁE6V6ˆ‚¿¢Wó6ˆFS¢vñFvWBÊ6ˆÁFVÁDWó6ˆFR¿¢ñ÷F$ñC¢vñFvWBÊ6ˆÁFVÁDñ÷F$ñB¿¢ì∞¢“6F6ÇÖÚí∑–¢&WGW&„∞¢–¢ñbá6W&ñW5∆ñ∆ó7B”“ÁV∆¬«¿¢6W&ñW5∆ñ∆ó7BÊó56W&ñW2«¿¢6W&ñW5∆ñ∆ó7BÁ6W&ñW5FóF∆R”“ÁV∆¬í∞¢&WGW&„∞¢–¢ˆ7W'&VÁDWó6ˆFT÷&∂VD4fñÊó6ÜVB“G'VS∞¢G'í∞¢ÚÚfñÊBFÜR7W'&VÁBWó6ˆFRñÊf¢ñbÖˆ7W'&VÁDñÊFWÇ„“bbˆ7W'&VÁDñÊFWÇ¬ˆ7FófU∆ñ∆ó7BÊ∆VÊwFÇí∞¢fñÊ¬7W'&VÁDWó6ˆFR“6W&ñW5∆ñ∆ó7BÊ∆ƒWó6ˆFW2Êfó'7EvÜW&RÄ¢ÜWó6ˆFRí”‚Wó6ˆFRÊ˜&ñvñÊƒñÊFWÇ”“ˆ7W'&VÁDñÊFWÇ¿¢˜$V«6S¢Çí”‚6W&ñW5∆ñ∆ó7BÊ∆ƒWó6ˆFW2Êfó'7B¿¢ì∞†¢ñbÜ7W'&VÁDWó6ˆFRÁ6W&ñW4ñÊfÚÁ6V6ˆ‚“ÁV∆¬b`¢7W'&VÁDWó6ˆFRÁ6W&ñW4ñÊfÚÊWó6ˆFR“ÁV∆¬í∞¢vóB7F˜&vU6W'fñ6RÊ÷&¥Wó6ˆFT4fñÊó6ÜVBÄ¢6W&ñW5FóF∆S¢6W&ñW5∆ñ∆ó7BÁ6W&ñW5FóF∆R¿¢6V6ˆ„¢7W'&VÁDWó6ˆFRÁ6W&ñW4ñÊfÚÁ6V6ˆ‚¿¢Wó6ˆFS¢7W'&VÁDWó6ˆFRÁ6W&ñW4ñÊfÚÊWó6ˆFR¿¢ñ÷F$ñC¢6W&ñW5∆ñ∆ó7BÊñ÷F$ñBÛÚvñFvWBÊ6ˆÁFVÁDñ÷F$ñB¿¢ì∞¢–¢–¢“6F6ÇÜRí∑–¢–†¢gWGW&S«fˆñC‚ˆ÷&¥7W'&VÁD÷˜fñT4fñÊó6ÜVBÇí7ñÊ2∞¢fñÊ¬ñ÷F$ñB“ˆ7W'&VÁD∆ˆ6ƒ÷˜fñTñ÷F$ñC∞¢ñbÇ˜W6W4∆ˆ6ƒ6ˆ◊∆WFñˆÂG&6∂ñÊr«¿¢ˆ7W'&VÁD÷˜fñT÷&∂VD4fñÊó6ÜVB«¿¢ñ÷F$ñB”“ÁV∆¬í∞¢&WGW&„∞¢–¢ÚÚ6WBFÜó2&Vf˜&RFÜRvóC¢˜6óFñˆ‚WfVÁG2&Rg&WVVÁBÊB6ˆ◊∆WFñˆ‡¢ÚÚ◊W7BW&f˜&“ˆÊR6∆VÁW˜w&óFR¬Ê˜BVWVRˆÊRW"g&÷R‡¢ˆ7W'&VÁD÷˜fñT÷&∂VD4fñÊó6ÜVB“G'VS∞¢G'í∞¢vóBgWGW&RÁvóBÖ∞¢7F˜&vU6W'fñ6RÊ÷&¥÷˜fñT4fñÊó6ÜVBÜñ÷F$ñBí¿¢7F˜&vU6W'fñ6RÁ&V÷˜fUfñFVı&W7V÷RÖ˜&W7V÷T∂Wí¬∆ñ&6¥6ÜV6∑ˆñÁC¢G'VRí¿¢“ì∞¢“6F6ÇÖÚí∞¢ÚÚ∆ñ&6≤&V÷ñÁ2W6&∆Rñb∆ˆ6¬7F˜&vRó2FV◊˜&&ñ«íVÊfñ∆&∆R‡¢–¢–†¢ÚÚÚ«íFÜR∆ˆ6¬¬W6W"÷6ˆÊfñwW&VB6ˆ◊∆WFñˆ‚'V∆R‚FÜó2ó27ñÊ6á&ˆÊ˜W2ˆ‡¢ÚÚÚW'˜6R&V6W6RóB'VÁ2f˜"WfW'í˜6óFñˆ‚WFFS≤7GV¬w&óFW27Fê¢ÚÚÚVÊvóFVBÊB&RwV&FVBˆÊR◊6Ü˜B&˜fRˆñ‚µˆ÷&¥7W'&VÁDWó6ˆFT4fñÊó6ÜVE“‡¢fˆñBˆ6ÜV6¥ÊD«î∆ˆ6ƒ6ˆ◊∆WFñˆ‚Çí∞¢ñbÖ˜f∆ñFFñˆ‰vFT7FófR«¿¢˜W6W4∆ˆ6ƒ6ˆ◊∆WFñˆÂG&6∂ñÊr«¿¢ˆGW&Fñˆ‚√“GW&Fñˆ‚Á¶W&Ú«¿¢˜˜6óFñˆ‚√“GW&Fñˆ‚Á¶W&Úí∞¢&WGW&„∞¢–†¢fñÊ¬W&6VÁB“˜˜6óFñˆ‚Êñ‰÷ñ7&˜6V6ˆÊG2¢ÚˆGW&Fñˆ‚Êñ‰÷ñ7&˜6V6ˆÊG3∞¢fñÊ¬÷˜fñTñ÷F$ñB“ˆ7W'&VÁD∆ˆ6ƒ÷˜fñTñ÷F$ñC∞¢ñbÜ÷˜fñTñ÷F$ñB“ÁV∆¬í∞¢ñbÇˆ7W'&VÁD÷˜fñU&WvF6Ö7F'FVBbbW&6VÁB¬ˆ÷˜fñT6ˆ◊∆WFñˆÂFá&W6Üˆ∆Bí∞¢ÚÚFÜRFóF∆Rv2fñÊó6ÜVBGW&ñÊr‚V&∆ñW"6W76ñˆ‚‚&V¬ÊWr∆ê¢ÚÚ&V∆˜róG2Fá&W6Üˆ∆Bó2&WvF6Ç¬6Ú&W7F˜&RóBFÚÊ˜&÷¬∆ˆ6¿¢ÚÚ6ˆÁFñÁVRvF6ÜñÊr&VÜfñ˜"&Vf˜&RFÜRÊWáB&W7V÷R6fR‡¢ˆ7W'&VÁD÷˜fñU&WvF6Ö7F'FVB“G'VS∞¢VÊvóFVBÖ7F˜&vU6W'fñ6RÁVÊ÷&¥÷˜fñT4fñÊó6ÜVBÜ÷˜fñTñ÷F$ñBíì∞¢–¢ñbÇˆ7W'&VÁD÷˜fñT÷&∂VD4fñÊó6ÜVBb`¢W&6VÁB„“ˆ÷˜fñT6ˆ◊∆WFñˆÂFá&W6Üˆ∆Bí∞¢VÊvóFVBÖˆ÷&¥7W'&VÁD÷˜fñT4fñÊó6ÜVBÇíì∞¢–¢&WGW&„∞¢–†¢fñÊ¬ó56W&ñW2–¢ˆVffV7FófT6ˆÁFVÁEGóR”“w6W&ñW2r«¬˜6W&ñW5∆ñ∆ó7CÚÊó56W&ñW2”“G'VS∞¢ñbÇó56W&ñW2í&WGW&„∞¢ñbÖˆ7W'&VÁDWó6ˆFT÷&∂VD4fñÊó6ÜVB«¿¢W&6VÁB¬ˆWó6ˆFT6ˆ◊∆WFñˆÂFá&W6Üˆ∆Bí∞¢&WGW&„∞¢–¢VÊvóFVBÖˆ÷&¥7W'&VÁDWó6ˆFT4fñÊó6ÜVBÇíì∞¢–†¢ÚÚÚFV"F˜v‚FÜR&∆6≤G&Á6óFñˆ‚˜fW&∆ívÜV‚∆ˆBfñ«2'GvíÜ&@¢ÚÚÚñÊFWÇ¬˜"ÊÚ&W6ˆ«f&∆RU$¬.ù◊üäwùBRÊr‚FVBFV'&ñB˜F˜&&˜Ç∆ñÊ≤ˆ‚FÜRÊWá@¢ÚÚÚWó6ˆFRí‚vóFÜ˜WBFÜó2FÜRTí7Fó27GV6≤ˆ‚FÜR&∆6≤G&Á6óFñˆ‡¢ÚÚÚ6ˆÁFñÊW&ÊBFÜR&ñÊ&˜r˜fW&∆íÊWfW"7F˜2‚FÜR6˜W&6R◊7vóF6Ç6∆∆W ¢ÚÚÚ6∆V'2G&Á6óFñˆ‚7FFRóG6V∆b¬6ÚFÜó2ˆÊ«í&W67VW2FÜR˜FÜW"6∆∆W'0¢ÚÚÚÜˆvıFÙÊWáDWó6ˆFV¬6áVff∆Rí‚6fRFÚ6∆¬&VGVÊFÁF«í‡¢fˆñBˆ6∆V%G&Á6óFñˆ‰ˆ‰fñ«W&RÇí∞¢˜G&Á6óFñˆÂ7F˜Fñ÷W#ÚÊ6Ê6V¬Çì∞¢˜G&Á6óFñˆÂÜ6UFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"Á7F˜Çì∞¢˜G&Á6óFñˆÂ'VÊÊñÊr“f«6S∞¢˜&ñÊ&˜t7FófR“f«6S∞¢ÚÚÊÚÊWr÷VFñvñ∆¬˜V‚¬6ÚFÜRGW&Fñˆ‚V÷óBFÜBÊ˜&÷∆«í&R÷&◊2FÜP¢ÚÚ6∂ó∆ˆˆ∑WÊWfW"6ˆ÷W2‚∆VfñÊróBFó6&÷VBv˜V∆B6ñ∆VÁF«í6˜7BFÜP¢ÚÚ6∂ó'WGFˆ‚f˜"FÜR&W7BˆbvÜFWfW"ó27Fñ∆¬∆ññÊr‡¢˜6∂ó6Vv÷VÁG4÷VFñ&VGí“G'VS∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢“V«6R∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢–¢–†¢gWGW&S∆&ˆˆ√‚ˆ∆ˆE∆ñ∆ó7DñÊFWÇÄ¢ñÁBñÊFWÇ¬∞¢&ˆˆ¬WF˜∆í“f«6R¿¢Wó6ˆFU∆ñ&6µ&WVW7CÚ&WVW7B¿¢&ˆˆ¬6∂óñÊóFñ≈6fR“f«6R¿¢ÚÚ6˜W&6R7vóF6Çˆ‚FÜR6÷R6ˆÁFVÁC¢&W7V÷RFÜR6ÜV6∑ˆñÁFVB∆ˆ6¬˜6óFñˆ‡¢ÚÚWÜ7F«íá6VRˆ÷ñ&U&W7F˜&U&W7V÷Rí‡¢&ˆˆ¬&VfW$∆ˆ6≈&W7V÷R“f«6R¿¢&ˆˆ¬7W&W75&W7V÷R“f«6R¿¢F˜'&VÁCÚ÷ÁV≈f∆ñFFñˆÂ6˜W&6R¿¢ñÁCÚ÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ¿¢“í7ñÊ2∞¢ñbá&WVW7B”“ÁV∆¬í∞¢&WGW&‚ˆ∆ˆE∆ñ∆ó7DñÊFWÑGFV◊BÄ¢ñÊFWÇ¿¢WF˜∆ì¢WF˜∆í¿¢6∂óñÊóFñ≈6fS¢6∂óñÊóFñ≈6fR¿¢&VfW$∆ˆ6≈&W7V÷S¢&VfW$∆ˆ6≈&W7V÷R¿¢7W&W75&W7V÷S¢7W&W75&W7V÷R¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6S¢÷ÁV≈f∆ñFFñˆÂ6˜W&6R¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÉ¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ¿¢ì∞¢–¢fñÊ¬˜WFvˆñÊtñÊFWÇ“ˆ7W'&VÁDñÊFWÉ∞¢fñÊ¬˜WFvˆñÊuW&¬“ˆ7W'&VÁE7G&V’W&√∞¢fñÊ¬˜WFvˆñÊtÜVFW'2“ˆ7FófTáGGÜVFW'3∞¢fñÊ¬˜WFvˆñÊt÷VFñ“ˆ7FófT˜VÊVD÷VFñ∞¢fñÊ¬˜WFvˆñÊu6Ü˜V∆E∆í“ˆ7FófT÷VFñ6Ü˜V∆E∆ì∞¢fñÊ¬˜WFvˆñÊuW6VB“ˆ7FófT÷VFñW6W%W6VC∞¢f"∆ˆFVB“f«6S∞¢G'í∞¢∆ˆFVB“vóBˆ∆ˆE∆ñ∆ó7DñÊFWÑGFV◊BÄ¢ñÊFWÇ¿¢WF˜∆ì¢WF˜∆í¿¢&WVW7C¢&WVW7B¿¢6∂óñÊóFñ≈6fS¢6∂óñÊóFñ≈6fR¿¢&VfW$∆ˆ6≈&W7V÷S¢&VfW$∆ˆ6≈&W7V÷R¿¢7W&W75&W7V÷S¢7W&W75&W7V÷R¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6S¢÷ÁV≈f∆ñFFñˆÂ6˜W&6R¿¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÉ¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ¿¢ì∞¢&WGW&‚∆ˆFVC∞¢“fñÊ∆«í∞¢ñbÇ∆ˆFVBbb÷˜VÁFVBí∞¢fñÊ¬&W7F˜&VB“&WVW7BÁ&W7F˜&U∆ñ∆ó7BÇÇí∞¢ˆ7W'&VÁDñÊFWÇ“˜WFvˆñÊtñÊFWÉ∞¢ˆ7W'&VÁE7G&V’W&¬“˜WFvˆñÊuW&√∞¢ˆ7FófTáGGÜVFW'2“˜WFvˆñÊtÜVFW'3∞¢ˆ7FófT˜VÊVD÷VFñ“˜WFvˆñÊt÷VFñ∞¢ˆ7FófT÷VFñ6Ü˜V∆E∆í“˜WFvˆñÊu6Ü˜V∆E∆ì∞¢ˆ7FófT÷VFñW6W%W6VB“˜WFvˆñÊuW6VC∞¢ˆó4WFÙGfÊ6ñÊr“f«6S∞¢“ì∞¢ñbá&W7F˜&VBívóB˜7vóF6Ñ÷F&∆ó7EF&vWBÇì∞¢–¢–¢–†¢gWGW&S∆&ˆˆ√‚ˆ∆ˆE∆ñ∆ó7DñÊFWÑGFV◊BÄ¢ñÁBñÊFWÇ¬∞¢&ˆˆ¬WF˜∆í“f«6R¿¢Wó6ˆFU∆ñ&6µ&WVW7CÚ&WVW7B¿¢&ˆˆ¬6∂óñÊóFñ≈6fR“f«6R¿¢ÚÚ6˜W&6R7vóF6Çˆ‚FÜR6÷R6ˆÁFVÁC¢&W7V÷RFÜR6ÜV6∑ˆñÁFVB∆ˆ6¬˜6óFñˆ‡¢ÚÚWÜ7F«íá6VRˆ÷ñ&U&W7F˜&U&W7V÷Rí‡¢&ˆˆ¬&VfW$∆ˆ6≈&W7V÷R“f«6R¿¢&ˆˆ¬7W&W75&W7V÷R“f«6R¿¢F˜'&VÁCÚ÷ÁV≈f∆ñFFñˆÂ6˜W&6R¿¢ñÁCÚ÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ¿¢“í7ñÊ2∞¢ñbá&WVW7B”“ÁV∆¬íˆWó6ˆFTÊfñvFñˆ‰vVÊW&Fñˆ‚≤≥∞¢ñbá&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ÚÚÊWróFV“ó2&VñÊr∆ˆFVC¢Áí67'V"ñ‚f∆ñváB&V∆ˆÊw2FÚFÜR˜WFvˆñÊp¢ÚÚˆÊRÊB◊W7BÊWfW"∆ÊBˆ‚FÜó2ˆÊS≤6÷Rf˜"FÜR∆ÊFñÊrfW&ñfñW ¢ÚÚÜWˆ6Ç'V◊ßuÁ‚ùÁBfW&ñfñW"&WG'í◊W7BÊWfW"6VV≤FÜRñÊ6ˆ÷ñÊróFV“í‡¢ÚÚ‰ıDS¢FÜR&W7V÷Rw&óFRuT$Bó2FV∆ñ&W&FV«í‰ıB6∆V&VBÜW&R.ù◊üäwùBFÜP¢ÚÚ˜WFvˆñÊróFV“w26ÜV6∑ˆñÁB˜6fU&W7V÷RÇí&V∆˜r◊W7B7Fñ∆¬'V‚vñÁ7@¢ÚÚFÜR&÷VBwV&B¬˜"‚VÊ∆ÊFVB&W7V÷Rw2„˜6óFñˆ‚v˜V∆B&Rfñ∆VB˜fW ¢ÚÚFÜBóFV“w2&ˆˆ∂÷&≤'íFÜRfW'í7vóF6ÇFÜB&ÊFˆÁ2óB‚FÜR6∆V"6óG0¢ÚÚñ÷÷VFñFV«ígFW"FÜB6fR‡¢˜Ge67'V$vVÊW&Fñˆ‚≤≥∞¢˜Gd&ÊFˆÂ67'V"Çì∞¢˜&W7V÷UfW&ñgîWˆ6Ç≤≥∞¢ñbÖˆ7FófU∆ñ∆ó7B”“ÁV∆¬«¿¢ñÊFWÇ¬«¿¢ñÊFWÇ„“ˆ7FófU∆ñ∆ó7BÊ∆VÊwFÇí∞¢ˆ6∆V%G&Á6óFñˆ‰ˆ‰fñ«W&RÇì∞¢&WGW&‚f«6S∞¢–†¢ÚÚ6∆VW7F˜vñÁ2˜fW"ÁóFÜñÊr«&VGíVWVVB‚6ÜV6∂VB$Tdı$RÁí7FFP¢ÚÚ÷˜fW3¢&ñ∆ñÊr˜WBgFW"ˆ7W'&VÁDñÊFWÇÜ2GfÊ6VBv˜V∆B∆VfRFÜP¢ÚÚ∆ñ∆ó7BˆñÁFñÊrB‚Wó6ˆFRFÜBÊWfW"˜VÊVB¬6Ú&W7V÷RÊ@¢ÚÚ÷WFFFv˜V∆Bfñ∆RvñÁ7BFÜRw&ˆÊróFV“‚ˆÊ«íWFˆ÷Fñ2GfÊ6W2&P¢ÚÚ7W&W76VB.ù◊üäwùBñ6∂ñÊr6ˆ÷WFÜñÊr'íÜÊB÷VÁ2FÜRfñWvW"ó2v∂R¬6Úó@¢ÚÚ6∆V'2FÜR∆F6ÇñÁ7FVB‡¢ñbÖ˜6∆VW7F˜∆F6ÜVBí∞¢ñbÜWF˜∆íbbˆó4WFÙGfÊ6ñÊrí∞¢ˆó4WFÙGfÊ6ñÊr“f«6S∞¢ˆ6∆V%G&Á6óFñˆ‰ˆ‰fñ«W&RÇì∞¢&WGW&‚f«6S∞¢–¢˜6∆VW7F˜∆F6ÜVB“f«6S∞¢–†¢&ñÁBÄ¢uñµ≥¢ˆ∆ˆE∆ñ∆ó7DñÊFWÇ6∆∆VBvóFÇñÊFWÉ¢FñÊFWÇ¬WF˜∆ì¢FWF˜∆ír¿¢ì∞†¢ÚÚ&W6ˆ«fR&Vf˜&R6ÜÊvñÊrFÜR∆ññÊrñFVÁFóGì¢6Ê6V∆∆VB˜"fñ∆V@¢ÚÚ∆ˆˆ∑W◊W7BÊ˜B∆&V¬FÜR˜WFvˆñÊr7G&V“2FÜRVÁ∆ñVBF&vWB‡¢fñÊ¬VÁG'í“ˆ7FófU∆ñ∆ó7B∂ñÊFWÖ”∞¢ÚÚ&W6ˆ«fRFÜR7GV¬7G&V÷ñÊrU$¬ñbÊVVFV@¢7G&ñÊrfñFVıW&¬“VÁG'íÁW&√∞¢ñbáfñFVıW&¬Êó4V◊Gíí∞¢G'í∞¢fñFVıW&¬“vóB˜&W6ˆ«fU∆ñ∆ó7DVÁG'ïW&¬ÜñÊFWÇì∞¢“6F6ÇÜRí∞¢fñÊ¬W'&˜%FWáB“RÁFı7G&ñÊrÇíÁ&W∆6Tfó'7BÇtWÜ6WFñˆ„¢r¬rrì∞¢ñbÜ÷˜VÁFVBbb&WVW7CÚÊó47W'&VÁB“f«6Rí∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢tfñ∆VBFÚ&W&RfñFVÛ¢FW'&˜%FWáBr¿¢7Gñ∆S¢6ˆÁ7BFWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢FÜV÷RÊˆbÜ6ˆÁFWáBíÊ6ˆ∆˜%66ÜV÷RÊW'&˜"¿¢GW&Fñˆ„¢fñFVı∆ñW%Fñ÷ñÊt6ˆÁ7FÁG2Ê6ˆÁG&ˆ«4WFÙÜñFTGW&Fñˆ‚¿¢í¿¢ì∞¢–¢fñFVıW&¬“VÁG'íÁW&√∞¢–¢–¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ñbáfñFVıW&¬Êó4V◊Gíí∞¢ñbá&WVW7B”“ÁV∆¬íˆ7W'&VÁE7G&V’W&¬“ÁV∆√∞¢ñbÜ÷˜VÁFVBí∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6Ê6¥&"Ä¢6ˆÁFVÁC¢6ˆÁ7BFWáBÄ¢tÊÚ∆ñ&∆RU$¬f˜VÊBf˜"FÜó2VÁG'ír¿¢7Gñ∆S¢FWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢FÜV÷RÊˆbÜ6ˆÁFWáBíÊ6ˆ∆˜%66ÜV÷RÊW'&˜"¿¢GW&Fñˆ„¢fñFVı∆ñW%Fñ÷ñÊt6ˆÁ7FÁG2Ê6ˆÁG&ˆ«4WFÙÜñFTGW&Fñˆ‚¿¢í¿¢ì∞¢–¢ˆ6∆V%G&Á6óFñˆ‰ˆ‰fñ«W&RÇì∞¢&WGW&‚f«6S∞¢–†¢ÚÚ67&ˆ&&∆R7F˜f˜"FÜR7W'&VÁBWó6ˆFR&Vf˜&R7vóF6ÜñÊp¢˜7F˜G&∑DÜV'F&VBÇì∞¢˜G&∑E67&ˆ&&∆RÇw7F˜rì∞¢˜7F˜6ñ÷∂ƒÜV'F&VBÇì∞¢˜6ñ÷∂≈67&ˆ&&∆RÇw7F˜rì∞¢ÚÚ∂VWFÜR‘D$∆ó7B6W76ñˆ‚w2∆ññÊr&óBVÁFñ¬7vóF6ÖF&vWB6GW&W2óB‡¢ÚÚ6∆∆ñÊrWÜóBÜW&Rv˜V∆B÷∂RFÜRñÊ6ˆ÷ñÊrWó6ˆFR∆ˆˆ≤W6VBÊBv˜V∆@¢ÚÚ&WfVÁBóG2ñÊóFñ¬6ÜV6∑ˆñÁB˜Fñ÷W"g&ˆ“7F'FñÊr‡¢˜WFFT÷F&∆ó7E˜6óFñˆ‚Çì∞†¢ÚÚ6∆∆W'2FÜB«&VGí6ÜV6∑ˆñÁFVBFÜR˜WFvˆñÊrWó6ˆFRÜRÊr‚6˜W&6P¢ÚÚ7vóF6Ç¬vÜñ6Ç6fW2$Tdı$R7vñÊrFÜR∆ñ∆ó7Bí6∂óFÜó26fR6Úó@¢ÚÚ6‚wBw&óFRFÜR7W'&VÁB˜6óFñˆ‚vñÁ7BFÜRÊWv«í◊7vVB∆ñ∆ó7B‡¢ñbÇ6∂óñÊóFñ≈6fRí∞¢vóB˜6fU&W7V÷RÇì∞¢–¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ÚÚFÜR˜WFvˆñÊróFV“w2wV&FVB6ÜV6∑ˆñÁBÜ2'V„≤g&ˆ“ÜW&Rˆ‚FÜRwV&@¢ÚÚ&V∆ˆÊw2FÚÊˆ&ˆGí‚6∆V&ñÊrÊ˜r7F˜2óB7W&W76ñÊrFÜRñÊ6ˆ÷ñÊróFV“w0¢ÚÚ6fW2ÊB÷∂W2Áíñ‚÷f∆ñváB∆ÊFñÊrfW&ñfñW"&˜'BñÁ7FVBˆ`¢ÚÚ&R÷ó77VñÊrFÜR˜WFvˆñÊróFV“w2F&vWBvñÁ7BFÜRÊWrˆÊR‡¢˜&W7V÷Uw&óFTwV&BÊ6∆V"Çì∞¢ˆ7W'&VÁDñÊFWÇ“ñÊFWÉ∞¢vóB˜7vóF6Ñ÷F&∆ó7EF&vWBÇì∞¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢˜&W6WD∆ˆ6ƒ6ˆ◊∆WFñˆÂ7FFRÇì∞†¢ÚÚ6∆V"7V'FóF∆R66ÜRÊB6V∆V7Fñˆ‚vÜV‚6ÜÊvñÊr6ˆÁFVÁ@¢˜&W6WE7V'FóF∆U7FFRÇì∞¢˜&W6WE6∂ó6Vv÷VÁE7FFRÇì∞†¢ÚÚf˜"÷˜fñR6ˆ∆∆V7FñˆÁ2¬&VfWF6Ç÷˜fñR÷WFFFf˜"FÜRÊWrñÊFWÄ¢ÚÚFÜó2'VÁ2ñ‚&6∂w&˜VÊB6Ú7V'FóF∆W2&R&VGívÜV‚W6W"˜VÁ2G&6∑56ÜVW@¢fñÊ¬6W&ñW5∆ñ∆ó7B“˜6W&ñW5∆ñ∆ó7C∞¢ñbá6W&ñW5∆ñ∆ó7B“ÁV∆¬bb6W&ñW5∆ñ∆ó7BÊó56W&ñW2í∞¢6W&ñW5∆ñ∆ó7BÊfWF6Ñ÷˜fñT÷WFFFf˜$ñÊFWÇÜñÊFWÇíÊ6F6ÑW'&˜"ÇÜRí∞¢ÚÚ6ñ∆VÁF«íñvÊ˜&RW'&˜'2“÷WFFFó2˜FñˆÊ¿¢&WGW&‚ÁV∆√∞¢“ì∞¢–†¢&ñÁBÄ¢uñµ≥¢∆ˆFñÊr∆ñ∆ó7BVÁG'í“&˜fñFW#¢G∂VÁG'íÁ&˜fñFW'“¬ñ∑¥fñ∆TñC¢G∂VÁG'íÁñ∑¥fñ∆TñG“r¿¢ì∞†¢ˆ7W'&VÁE7G&V’W&¬“fñFVıW&√∞†¢ÚÚ6ÜV6≤ñbFÜó2ó2ñµ≤fñFV¢fñÊ¬7W'&VÁDVÁG'í“ˆ7FófU∆ñ∆ó7Cı∂ñÊFWÖ”∞¢ˆ7FófTáGGÜVFW'2“7W'&VÁDVÁG'ìÚÊáGGÜVFW'3∞¢fñÊ¬ó5ñµ≤–¢7W'&VÁDVÁG'ìÚÁ&˜fñFW#ÚÁFÙ∆˜vW$66RÇí”“wñ∑≤r«¿¢7W'&VÁDVÁG'ìÚÁñ∑¥fñ∆TñB“ÁV∆√∞†¢ÚÚ≈tï2W6R&WG'í∆ˆvñ2f˜"ñµ≤fñFV˜2¬&Vv&F∆W72ˆbWF˜∆ê¢ñbÜó5ñµ≤í∞¢ÚÚf˜"ñµ≤¬vRÊVVB&WG'í∆ˆvñ2WfV‚ñbÊ˜BWF˜∆ññÊp¢ÚÚ˜∆ïñµµfñFVıvóFÖ&WG'ívñ∆¬ñÊ7&V÷VÁB˜ñµµ&WG'îñBFÚ6Ê6V¬&Wfñ˜W2&WG&ñW0¢fñÊ¬ñµ¥∆ˆFVB“vóB˜∆ïñµµfñFVıvóFÖ&WG'íÄ¢fñFVıW&¬¿¢&WVW7C¢&WVW7B¿¢ÚÚ÷ÁV¬6˜W&6RG&Á67Fñˆ‚˜vÁ2óG26ñÊv∆Rfñ«W&R÷W76vR‚FÜP¢ÚÚ&WG'íTí&V÷ñÁ2VÊ6ÜÊvVBvÜñ∆R6ˆ∆B7F˜&vRó2&VñÊr&V7FófFVB‡¢6Ü˜tfñ«W&S¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ”“ÁV∆¬¿¢ì∞¢ñbÜ÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ“ÁV∆¬bbñµ¥∆ˆFVBí&WGW&‚f«6S∞¢ñbá&WVW7B“ÁV∆¬bb7W&W75&W7V÷Rbbñµ¥∆ˆFVBí&WGW&‚f«6S∞¢ñbÇWF˜∆íí∞¢ÚÚ7Fñ∆¬W6R&WG'í'WBvóFÜ˜WBWF˜∆ì≤W6RˆÊ«ígFW"óB7V66VVG2‡¢ˆ7FófT÷VFñ6Ü˜V∆E∆í“f«6S∞¢ñbáñµ¥∆ˆFVBívóB˜∆ñW"ÁW6RÇì∞¢–¢“V«6R∞¢ÚÚÊˆ‚’ñµ≤fñFV˜2∆íÊ˜&÷∆«ê¢ÚÚ6Ê6V¬ÁíˆÊvˆñÊrñµ≤&WG'ívÜV‚7vóF6ÜñÊrFÚÊˆ‚’ñµ≤fñFV¢˜ñµµ&WG'îñB≤≥∞¢ñbÜ÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ“ÁV∆¬í∞¢fñÊ¬f∆ñB“vóB˜G'î˜VÂ7F'GWfˆBÄ¢fñFVıW&¬¿¢áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2¿¢6˜W&6S¢÷ÁV≈f∆ñFFñˆÂ6˜W&6R¿¢6˜W&6TñÊFWÉ¢÷ÁV≈f∆ñFFñˆÂ6˜W&6TñÊFWÇ¿¢ì∞¢ñbÇf∆ñBí&WGW&‚f«6S∞¢ñbÇWF˜∆íívóB˜∆ñW"ÁW6RÇì∞¢“V«6R∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñáfñFVıW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢WF˜∆í¿¢&WVW7C¢&WVW7B¿¢ì∞¢–¢–†¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ÚÚ6áVff∆RÊVVG2∆ñ&6≤&ˆˆbFÚFV6ñFRvÜWFÜW"FÚG'íÊ˜FÜW"Wó6ˆFR‡¢ÚÚ˜&FñÊ'íWó6ˆFR˜6˜W&6RÊfñvFñˆ‚&WFñÁ2óG2WÜó7FñÊr&VFñÊW72FÇ‡¢ñbá&WVW7B“ÁV∆¬bb7W&W75&W7V÷Rí∞¢fñÊ¬&VGí“vóBvóDf˜$Wó6ˆFU∆ñ&6≤Ä¢ó47W'&VÁC¢Çí”‚&WVW7BÊó47W'&VÁB¿¢ó5W6VC¢Çí”‚ˆ7FófT÷VFñW6W%W6VB«¬˜W6VD'î∆ñfV7ñ6∆R¿¢ó5&VGì¢Çí”‡¢˜∆ñW"Á7FFRÊGW&Fñˆ‚‚GW&Fñˆ‚Á¶W&Úb`¢Öˆ7FófT÷VFñW6W%W6VB«¿¢˜W6VD'î∆ñfV7ñ6∆R«¿¢Ö˜∆ñW"Á7FFRÁ∆ññÊrb`¢˜∆ñW"Á7FFRÁ˜6óFñˆ‚„–¢6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Cííí¿¢ì∞¢ñbÇ&VGíí&WGW&‚f«6S∞¢“V«6R∞¢vóB˜vóDf˜%fñFVı&VGíÇì∞¢–¢ñbÇ÷˜VÁFVB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ñbá7W&W75&W7V÷Rí∞¢ÚÚ7F'FñÊr&ÊFˆ“Wó6ˆFRB¶W&Úó2ñÊFWVÊFVÁBˆbvÜWFÜW"FÜP¢ÚÚfñWvW"&WVW7FVBóB˜"TÙbGfÊ6VBWFˆ÷Fñ6∆«í‡¢˜&W7V÷Uw&óFTwV&BÊ6∆V"Çì∞¢ˆó4WFÙGfÊ6ñÊr“f«6S∞¢“V«6R∞¢vóBˆ÷ñ&U&W7F˜&U&W7V÷Rá&VfW$∆ˆ6≈&W7V÷S¢&VfW$∆ˆ6≈&W7V÷Rì∞¢–¢ÚÚ&W7F˜&RVFñÚÊB7V'FóF∆RG&6≤&VfW&VÊ6W0¢vóB˜&W7F˜&UG&6µ&VfW&VÊ6W2Çì∞†¢ÚÚ6∆V"G&Á6óFñˆ‚7FFRvÜV‚fñFVÚó2&VGê¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5G&Á6óFñˆÊñÊr“f«6S∞¢“ì∞¢–¢&WGW&‚G'VS∞¢–†¢gWGW&S≈7G&ñÊs‚˜&W6ˆ«fU∆ñ∆ó7DVÁG'ïW&¬ÜñÁBñÊFWÇí7ñÊ2∞¢ñbÖˆ7FófU∆ñ∆ó7B”“ÁV∆¬«¿¢ñÊFWÇ¬«¿¢ñÊFWÇ„“ˆ7FófU∆ñ∆ó7BÊ∆VÊwFÇí∞¢&WGW&‚rs∞¢–†¢fñÊ¬VÁG'í“ˆ7FófU∆ñ∆ó7B∂ñÊFWÖ”∞†¢ñbÜVÁG'íÁW&¬Êó4Ê˜DV◊Gíí∞¢&WGW&‚VÁG'íÁW&√∞¢–†¢fñÊ¬&˜fñFW"“VÁG'íÁ&˜fñFW#ÚÁFÙ∆˜vW$66RÇì∞¢fñÊ¬Ü5F˜&&˜Ñ÷WFFF–¢VÁG'íÁF˜&&˜ÖF˜'&VÁDñB“ÁV∆¬bbVÁG'íÁF˜&&˜Ñfñ∆TñB“ÁV∆√∞¢fñÊ¬Ü5F˜&&˜ÖvV$F˜vÊ∆ˆD÷WFFF–¢VÁG'íÁF˜&&˜ÖvV$F˜vÊ∆ˆDñB“ÁV∆¬bbVÁG'íÁF˜&&˜Ñfñ∆TñB“ÁV∆√∞†¢ñbá&˜fñFW"”“wF˜&&˜Çr«¿¢Ü5F˜&&˜Ñ÷WFFF«¿¢Ü5F˜&&˜ÖvV$F˜vÊ∆ˆD÷WFFFí∞¢fñÊ¬F˜'&VÁDñB“VÁG'íÁF˜&&˜ÖF˜'&VÁDñC∞¢fñÊ¬vV$F˜vÊ∆ˆDñB“VÁG'íÁF˜&&˜ÖvV$F˜vÊ∆ˆDñC∞¢fñÊ¬fñ∆TñB“VÁG'íÁF˜&&˜Ñfñ∆TñC∞¢ñbÜfñ∆TñB”“ÁV∆¬«¬áF˜'&VÁDñB”“ÁV∆¬bbvV$F˜vÊ∆ˆDñB”“ÁV∆¬íí∞¢Fá&˜rWÜ6WFñˆ‚ÇuF˜&&˜Çfñ∆R÷WFFF÷ó76ñÊrrì∞¢–¢fñÊ¬î∂Wí“vóB7F˜&vU6W'fñ6RÊvWEF˜&&˜Ñî∂WíÇì∞¢ñbÜî∂Wí”“ÁV∆¬«¬î∂WíÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt÷ó76ñÊrF˜&&˜Çí∂Wírì∞¢–¢G'í∞¢7G&ñÊrW&√∞¢ñbávV$F˜vÊ∆ˆDñB“ÁV∆¬í∞¢ÚÚvV"F˜vÊ∆ˆB“W6RvV"F˜vÊ∆ˆBê¢W&¬“vóBF˜&&˜Ö6W'fñ6RÁ&WVW7EvV$F˜vÊ∆ˆDfñ∆T∆ñÊ≤Ä¢î∂Wì¢î∂Wí¿¢vV$ñC¢vV$F˜vÊ∆ˆDñB¿¢fñ∆TñC¢fñ∆TñB¿¢ì∞¢“V«6R∞¢ÚÚF˜'&VÁB“W6RF˜'&VÁBê¢W&¬“vóBF˜&&˜Ö6W'fñ6RÁ&WVW7Dfñ∆TF˜vÊ∆ˆD∆ñÊ≤Ä¢î∂Wì¢î∂Wí¿¢F˜'&VÁDñC¢F˜'&VÁDñB¿¢fñ∆TñC¢fñ∆TñB¿¢ì∞¢–¢ñbáW&¬Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚ÇuF˜&&˜Ç&WGW&ÊVB‚V◊Gí7G&V“U$¬rì∞¢–¢&WGW&‚W&√∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚ÇuF˜&&˜Ç∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢ÚÚñµ≤∆ßí&W6ˆ«WFñˆ‡¢fñÊ¬Ü5ñµ¥÷WFFF“VÁG'íÁñ∑¥fñ∆TñB“ÁV∆√∞¢ñbá&˜fñFW"”“wñ∑≤r«¬Ü5ñµ¥÷WFFFí∞¢fñÊ¬fñ∆TñB“VÁG'íÁñ∑¥fñ∆TñC∞¢ñbÜfñ∆TñB”“ÁV∆¬í∞¢Fá&˜rWÜ6WFñˆ‚Çuñµ≤fñ∆R÷WFFF÷ó76ñÊrrì∞¢–¢G'í∞¢fñÊ¬ñ∑≤“ñµ¥ï6W'fñ6RÊñÁ7FÊ6S∞¢fñÊ¬fñ∆TFF“vóBñ∑≤ÊvWDfñ∆TFWFñ«2Üfñ∆TñBì∞¢fñÊ¬W&¬“ñ∑≤ÊvWE7G&V÷ñÊuW&¬Üfñ∆TFFì∞¢ñbáW&¬”“ÁV∆¬«¬W&¬Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çuñµ≤&WGW&ÊVB‚V◊Gí7G&V“U$¬rì∞¢–¢&WGW&‚W&√∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚Çuñµ≤∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢ÚÚ&V÷óV÷ó¶R6∆˜VB÷'&˜w6W"∆ßí&W6ˆ«WFñˆ„¢&R÷fWF6Çg&W6ÇFó&V7B∆ñÊ≤'ê¢ÚÚ6∆˜VBóFV“ñBÜóFV◊26fVBg&ˆ“FÜR6∆˜VB'&˜w6W"ÜfRÊÚñÊfˆÜ6Çí‡¢ñbÜVÁG'íÁ&V÷óV÷ó¶TóFV‘ñB“ÁV∆¬bbVÁG'íÁ&V÷óV÷ó¶TóFV‘ñBÊó4Ê˜DV◊Gíí∞¢fñÊ¬î∂Wí“vóB7F˜&vU6W'fñ6RÊvWE&V÷óV÷ó¶Tî∂WíÇì∞¢ñbÜî∂Wí”“ÁV∆¬«¬î∂WíÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt÷ó76ñÊr&V÷óV÷ó¶Rí∂Wírì∞¢–¢G'í∞¢fñÊ¬fñ∆R“vóB&V÷óV÷ó¶U6W'fñ6RÁ&W6ˆ«fTóFV‘'îñBÄ¢î∂Wí¿¢VÁG'íÁ&V÷óV÷ó¶TóFV‘ñB¿¢ì∞¢ñbÜfñ∆R”“ÁV∆¬«¬fñ∆RÊ∆ñÊ≤Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çtfñ∆RÊ˜Bf˜VÊBñ‚&V÷óV÷ó¶R6∆˜VBrì∞¢–¢&WGW&‚fñ∆RÊ∆ñÊ≥∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V÷óV÷ó¶R∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢ÚÚ&V÷óV÷ó¶R∆ßí&W6ˆ«WFñˆ„¢&R÷fWF6ÇFó&V7B∆ñÊ∑2'íñÊfˆÜ6ÇÊB÷F6Ä¢ÚÚFÜRfñ∆R'íóG27F˜&VBFÇÖ&V÷óV÷ó¶RFó&V7B∆ñÊ∑2WfVÁGV∆«íWáó&Rí‡¢fñÊ¬Ü5&V÷óV÷ó¶T÷WFFF–¢VÁG'íÁ&V÷óV÷ó¶TÜ6Ç“ÁV∆¬bbVÁG'íÁ&V÷óV÷ó¶UFÇ“ÁV∆√∞¢ñbá&˜fñFW"”“w&V÷óV÷ó¶Rr«¬Ü5&V÷óV÷ó¶T÷WFFFí∞¢fñÊ¬Ü6Ç“VÁG'íÁ&V÷óV÷ó¶TÜ6É∞¢fñÊ¬FÇ“VÁG'íÁ&V÷óV÷ó¶UFÉ∞¢ñbÜÜ6Ç”“ÁV∆¬«¬Ü6ÇÊó4V◊Gí«¬FÇ”“ÁV∆¬«¬FÇÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V÷óV÷ó¶Rfñ∆R÷WFFF÷ó76ñÊrrì∞¢–¢fñÊ¬î∂Wí“vóB7F˜&vU6W'fñ6RÊvWE&V÷óV÷ó¶Tî∂WíÇì∞¢ñbÜî∂Wí”“ÁV∆¬«¬î∂WíÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt÷ó76ñÊr&V÷óV÷ó¶Rí∂Wírì∞¢–¢G'í∞¢fñÊ¬fñ∆W2“vóB&V÷óV÷ó¶U6W'fñ6RÁ&W6ˆ«fTfñ∆W4'îÜ6ÇÜî∂Wí¬Ü6Çì∞¢fñÊ¬÷F6Ç“fñ∆W2Êfó'7EvÜW&RÄ¢Übí”‚bÁFÇ”“FÇ¿¢˜$V«6S¢Çí”‚Fá&˜rWÜ6WFñˆ‚Çtfñ∆RÊ˜Bf˜VÊBñ‚&V÷óV÷ó¶R6∆˜VBrí¿¢ì∞¢ñbÜ÷F6ÇÊ∆ñÊ≤Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V÷óV÷ó¶R&WGW&ÊVB‚V◊Gí7G&V“U$¬rì∞¢–¢&WGW&‚÷F6ÇÊ∆ñÊ≥∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V÷óV÷ó¶R∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢ñbÜVÁG'íÁ&W7G&ñ7FVD∆ñÊ≤“ÁV∆¬í∞¢fñÊ¬î∂Wí“vóB7F˜&vU6W'fñ6RÊvWDî∂WíÇì∞¢ñbÜî∂Wí”“ÁV∆¬«¬î∂WíÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt÷ó76ñÊr&V¬FV'&ñBí∂Wírì∞¢–¢G'í∞¢fñÊ¬VÁ&W7G&ñ7E&W7V«B“vóBFV'&ñE6W'fñ6RÁVÁ&W7G&ñ7D∆ñÊ≤Ä¢î∂Wí¿¢VÁG'íÁ&W7G&ñ7FVD∆ñÊ≤¿¢ì∞¢fñÊ¬W&¬“VÁ&W7G&ñ7E&W7V«E≤vF˜vÊ∆ˆBu”ÚÁFı7G&ñÊrÇíÛÚrs∞¢ñbáW&¬Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V¬FV'&ñB&WGW&ÊVB‚V◊Gí7G&V“U$¬rì∞¢–¢&WGW&‚W&√∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚Çu&V¬FV'&ñB∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢ÚÚ∆ƒFV'&ñB∆ßí&W6ˆ«WFñˆ„¢VÊ∆ˆ6≤FÜR7F˜&VB∆ˆ6∂VB∆ñÊ≤ˆ‚FV÷Ê@¢ÚÚÜ÷ó'&˜'2&V¬‘FV'&ñBw2&W7G&ñ7FVD∆ñÊ≤∫w^~)ﬁu"VÁ&W7G&ñ7Bí‚FÜR∆ˆ6∂VB∆ñÊ≤ó0¢ÚÚ7F&∆S≤ˆÊ«íFÜRVÊ∆ˆ6∂VB4D‚U$¬Wáó&W2¬6ÚFÜó2ó2«6Ú÷˜&R&ˆ'W7@¢ÚÚFÜ‚&W6ˆ«fñÊrWfW'íWó6ˆFRWg&ˆÁB‡¢ñbá&˜fñFW"”“v∆∆FV'&ñBr«¿¢ÜVÁG'íÊ∆ƒFV'&ñD∆ñÊ≤“ÁV∆¬bbVÁG'íÊ∆ƒFV'&ñD∆ñÊ≤Êó4Ê˜DV◊Gííí∞¢fñÊ¬∆ˆ6∂VD∆ñÊ≤“VÁG'íÊ∆ƒFV'&ñD∆ñÊ≥∞¢ñbÜ∆ˆ6∂VD∆ñÊ≤”“ÁV∆¬«¬∆ˆ6∂VD∆ñÊ≤Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt∆ƒFV'&ñB∆ñÊ≤÷WFFF÷ó76ñÊrrì∞¢–¢fñÊ¬î∂Wí“vóB7F˜&vU6W'fñ6RÊvWD∆ƒFV'&ñDî∂WíÇì∞¢ñbÜî∂Wí”“ÁV∆¬«¬î∂WíÊó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt÷ó76ñÊr∆ƒFV'&ñBí∂Wírì∞¢–¢G'í∞¢fñÊ¬W&¬“vóB∆ƒFV'&ñE6W'fñ6RÁVÊ∆ˆ6¥∆ñÊ≤Üî∂Wí¬∆ˆ6∂VD∆ñÊ≤ì∞¢ñbáW&¬Êó4V◊Gíí∞¢Fá&˜rWÜ6WFñˆ‚Çt∆ƒFV'&ñB&WGW&ÊVB‚V◊Gí7G&V“U$¬rì∞¢–¢&WGW&‚W&√∞¢“6F6ÇÜRí∞¢Fá&˜rWÜ6WFñˆ‚Çt∆ƒFV'&ñB∆ñÊ≤fñ∆VC¢FRrì∞¢–¢–†¢Fá&˜rWÜ6WFñˆ‚ÇtÊÚU$¬÷WFFFfñ∆&∆Rf˜"FÜó2VÁG'írì∞¢–†¢ÚÚÚvóG2f˜"fñFVÚ÷WFFFÜGW&Fñˆ‚íFÚ&V6ˆ÷Rfñ∆&∆P¢ÚÚÚ&WGW&Á2G'VRñb÷WFFF∆ˆG2¬f«6RñbFñ÷V˜WB˜"6Ê6V∆∆V@¢ÚÚÚFÜó2ó2FÜRˆÊ«í&V∆ñ&∆RvíFÚFWFV7Bñbñµ≤fñ∆Ró27GV∆«í∆ˆFñÊp¢ÚÚ¢ÚÚÚFÜRFFóFñˆÊƒ÷ˆÊóF˜&ñÊu6V6ˆÊG2&÷WFW"∆∆˜w26ˆÁFñÁV˜W2÷ˆÊóF˜&ñÊrGW&ñÊr&WG'íFV∆ó0¢ÚÚÚFÚFWFV7BñbfñFVÚ∆ˆG2GW&ñÊrFÜRFV∆íW&ñˆBá&WfVÁG2VÊÊV6W76'í∆ñW"&W6WG2ê¢gWGW&S∆&ˆˆ√‚˜vóDf˜%fñFVÙ÷WFFFá∞¢ñÁBFñ÷V˜WE6V6ˆÊG2“R¿¢&WVó&VBñÁB&WG'îñB¿¢ñÁBFFóFñˆÊƒ÷ˆÊóF˜&ñÊu6V6ˆÊG2“¿¢“í7ñÊ2∞¢fñÊ¬F˜F≈Fñ÷V˜WE6V6ˆÊG2“Fñ÷V˜WE6V6ˆÊG2≤FFóFñˆÊƒ÷ˆÊóF˜&ñÊu6V6ˆÊG3∞¢fñÊ¬7F˜vF6Ç“7F˜vF6ÇÇí‚Á7F'BÇì∞†¢vÜñ∆Rá7F˜vF6ÇÊV∆6VBÊñÂ6V6ˆÊG2¬F˜F≈Fñ÷V˜WE6V6ˆÊG2í∞¢ÚÚ6ÜV6≤ñbFÜó2&WG'íÜ2&VV‚6Ê6V∆∆VBáW6W"ÊfñvFVBFÚFñffW&VÁBfñFVÚê¢ñbÖ˜ñµµ&WG'îñB“&WG'îñBí∞¢&ñÁBÄ¢uñµ≥¢&WG'í6Ê6V∆∆VBáFˆ∂V‚÷ó6÷F6É¢7W'&VÁC“E˜ñµµ&WG'îñB¬WáV7FVC“G&WG'îñBír¿¢ì∞¢&WGW&‚f«6S∞¢–†¢ÚÚ6ÜV6≤ñbvñFvWBv2Fó7˜6VBá&WfVÁG2˜W&FñˆÁ2ˆ‚VÊ÷˜VÁFVBvñFvWBê¢ñbÇ÷˜VÁFVBí∞¢&ñÁBÇuñµ≥¢vñFvWBFó7˜6VBGW&ñÊr÷WFFFvóBrì∞¢&WGW&‚f«6S∞¢–†¢ÚÚdïÉ¢6ÜV6≤$ıDÇˆGW&Fñˆ‚fñV∆BÜg&ˆ“7G&V“í‰B∆ñW"Á7FFRÊGW&Fñˆ‚ÜFó&V7B7FFRê¢ÚÚFÜó2VÁ7W&W2vR6F6ÇFÜRfñFVÚ∆ˆFñÊrvÜWFÜW"FÜR7G&V“Ü2fó&VB˜"Ê˜@¢ÚÚf˜"FÜRfó'7BfñFVÚ¬7G&V◊2÷ñváBÊ˜Bfó&R&V∆ñ&«í¬6ÚvRÊVVBFÜRFó&V7B7FFR6ÜV6∞¢fñÊ¬7G&V‘GW&Fñˆ‚“ˆGW&Fñˆ„∞¢fñÊ¬Fó&V7DGW&Fñˆ‚“˜∆ñW"Á7FFRÊGW&Fñˆ„∞¢fñÊ¬VffV7FófTGW&Fñˆ‚“7G&V‘GW&Fñˆ‚‚GW&Fñˆ‚Á¶W&¢Ú7G&V‘GW&Fñˆ‡¢¢Fó&V7DGW&Fñˆ„∞†¢ñbÜVffV7FófTGW&Fñˆ‚‚GW&Fñˆ‚Á¶W&Úí∞¢&ñÁBÄ¢uñµ≥¢fñFVÚGW&Fñˆ‚fñ∆&∆Rá7G&V”¢G7G&V‘GW&Fñˆ‚¬Fó&V7C¢FFó&V7DGW&Fñˆ‚¬VffV7FófS¢FVffV7FófTGW&Fñˆ‚ír¿¢ì∞†¢ÚÚFFóFñˆÊ¬fW&ñfñ6Fñˆ„¢vóB&óB∆ˆÊvW"FÚVÁ7W&R∆ñ&6≤7GV∆«í7F'FV@¢ÚÚFÜó2vófW2FÜR∆ñW"Fñ÷RFÚG&Á6óFñˆ‚g&ˆ“&Ü2GW&Fñˆ‚"FÚ&ó2∆ññÊr ¢ÚÚÊB∆∆˜w2∆¬7G&V“∆ó7FVÊW'2FÚ7ñÊ6á&ˆÊó¶RFÜVó"7FFRWFFW0¢&ñÁBÄ¢uñµ≥¢GW&Fñˆ‚FWFV7FVB¬vóFñÊrf˜"∆ñ&6≤FÚ7F&ñ∆ó¶R‚‚‚r¿¢ì∞¢vóBgWGW&RÊFV∆ñVBÜ6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Éíì∞†¢ÚÚ6ÜV6≤÷˜VÁFVB7FFRgFW"FV∆ê¢ñbÇ÷˜VÁFVBí∞¢&ñÁBÇuñµ≥¢vñFvWBFó7˜6VBGW&ñÊr7F&ñ∆ó¶Fñˆ‚FV∆írì∞¢&WGW&‚f«6S∞¢–†¢ÚÚfñÊ¬6Ê6V∆∆Fñˆ‚6ÜV6≤gFW"7F&ñ∆ó¶Fñˆ‚FV∆ê¢ñbÖ˜ñµµ&WG'îñB“&WG'îñBí∞¢&ñÁBÄ¢uñµ≥¢&WG'í6Ê6V∆∆VBGW&ñÊr7F&ñ∆ó¶Fñˆ‚ÜÊfñvFñˆ‚ˆ67W'&VBír¿¢ì∞¢&WGW&‚f«6S∞¢–†¢ÚÚfW&ñgí∆ñ&6≤ó27GV∆«íÜVÊñÊr¬Ê˜BßW7B'VffW&ñÊrvóFÇGW&Fñˆ‡¢ÚÚFÜó2&WfVÁG2f«6R˜6óFófW2vÜW&RGW&Fñˆ‚∆ˆG2'WBfñFVÚvˆ‚wB∆ê¢ÚÚ6ÜV6≤&˜FÇ7G&V“7FFRÊBFó&V7B∆ñW"7FFRf˜"&V∆ñ&ñ∆óGê¢fñÊ¬7G&V’∆ññÊr“ˆó5∆ññÊs∞¢fñÊ¬Fó&V7E∆ññÊr“˜∆ñW"Á7FFRÁ∆ññÊs∞†¢ñbá7G&V’∆ññÊr«¬Fó&V7E∆ññÊrí∞¢&ñÁBÄ¢uñµ≥¢fñFVÚ6ˆÊfó&÷VB∆ññÊr“GW&Fñˆ„¢FVffV7FófTGW&Fñˆ‚¬∆ññÊs¢G'VRá7G&V”¢G7G&V’∆ññÊr¬Fó&V7C¢FFó&V7E∆ññÊrír¿¢ì∞¢“V«6R∞¢ÚÚGW&Fñˆ‚ó2fñ∆&∆R'WB∆ñ&6≤Ü6‚wB7F'FVBñW@¢ÚÚFÜó2ó266WF&∆R“GW&Fñˆ‚∆ˆÊRó27Vffñ6ñVÁBf˜"6ˆ∆B7F˜&vRFWFV7Fñˆ‡¢&ñÁBÄ¢uñµ≥¢GW&Fñˆ‚fñ∆&∆RÇFVffV7FófTGW&Fñˆ‚í¬∆ñ&6≤vñ∆¬7F'B6Ü˜'F«ír¿¢ì∞¢–†¢ÚÚ5$ïDî4¬dïÉ¢6∆V"&WG'í7FFRî‘‘TDîDT≈ívÜV‚fñFVÚ∆ˆG0¢ÚÚFÜó2&WfVÁG2FÜR&WG'íTíg&ˆ“&V÷ñÊñÊrfó6ñ&∆RñbfñFVÚ∆ˆFVBGW&ñÊr÷ˆÊóF˜&ñÊp¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ÚÚ7FFR«&VGí6∆V&VB&˜fR“FÜó2ßW7BG&ñvvW'2&V'Vñ∆@¢“ì∞¢–†¢&WGW&‚G'VS∞¢–†¢ÚÚvóB&óB&Vf˜&R6ÜV6∂ñÊrvñ‡¢vóBgWGW&RÊFV∆ñVBÜ6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Síì∞¢–†¢ÚÚFñ÷V˜WB“fñFVÚ÷WFFFÊWfW"∆ˆFVB¬fñ∆Ró2∆ñ∂V«íñ‚6ˆ∆B7F˜&vP¢&ñÁBÄ¢uñµ≥¢Fñ÷V˜WBvóFñÊrf˜"fñFVÚ÷WFFFÇG∑F˜F≈Fñ÷V˜WE6V6ˆÊG7◊2V∆6VBír¿¢ì∞¢&WGW&‚f«6S∞¢–†¢ÚÚÚGFV◊G2FÚ∆íñµ≤fñFVÚvóFÇ&WG'í∆ˆvñ2f˜"6ˆ∆B7F˜&vP¢gWGW&S∆&ˆˆ√‚˜∆ïñµµfñFVıvóFÖ&WG'íÄ¢7G&ñÊrfñFVıW&¬¬∞¢7G&ñÊsÚ˜fW'&ñFU&˜fñFW"¿¢7G&ñÊsÚ˜fW'&ñFUñµ¥fñ∆TñB¿¢&ˆˆ¬ó4FV'&ñgïEb“f«6R¿¢&ˆˆ¬6Ü˜tfñ«W&R“G'VR¿¢Wó6ˆFU∆ñ&6µ&WVW7CÚ&WVW7B¿¢“í7ñÊ2∞¢ñbá&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ÚÚˆÊ«í«í&WG'í∆ˆvñ2f˜"ñµ≤fñFV˜0¢ÚÚ7W˜'B&˜FÇ∆ñ∆ó7BVÁG&ñW2ÊBFV'&ñgíEbá&WVW7D÷vñ4ÊWáBíf∆˜w0¢fñÊ¬7W'&VÁDVÁG'í–¢ˆ7FófU∆ñ∆ó7B“ÁV∆¬b`¢ˆ7W'&VÁDñÊFWÇ„“b`¢ˆ7W'&VÁDñÊFWÇ¬ˆ7FófU∆ñ∆ó7BÊ∆VÊwFÄ¢Úˆ7FófU∆ñ∆ó7Bµˆ7W'&VÁDñÊFWÖ–¢¢ÁV∆√∞¢fñÊ¬ó5ñµ≤–¢˜fW'&ñFU&˜fñFW#ÚÁFÙ∆˜vW$66RÇí”“wñ∑≤r«¿¢˜fW'&ñFUñµ¥fñ∆TñB“ÁV∆¬«¿¢7W'&VÁDVÁG'ìÚÁ&˜fñFW#ÚÁFÙ∆˜vW$66RÇí”“wñ∑≤r«¿¢7W'&VÁDVÁG'ìÚÁñ∑¥fñ∆TñB“ÁV∆¬«¿¢ó4FV'&ñgïEb«¿¢fñFVıW&¬Ê6ˆÁFñÁ2Ä¢v◊óñ∑≤Ê6ˆ“r¿¢ì≤ÚÚFWFV7Bñµ≤'íU$¬Ö7G&V÷ñÚEb¬WF2‚ê†¢&ñÁBÄ¢uñµ≥¢˜∆ïñµµfñFVıvóFÖ&WG'í6∆∆VBf˜"ñÊFWÇEˆ7W'&VÁDñÊFWÇ¬ó5ñµ≥¢Fó5ñµ≤¬˜fW'&ñFU&˜fñFW#¢F˜fW'&ñFU&˜fñFW"¬˜fW'&ñFUñµ¥fñ∆TñC¢F˜fW'&ñFUñµ¥fñ∆TñB¬ó4FV'&ñgïEc¢Fó4FV'&ñgïEbr¿¢ì∞†¢ñbÇó5ñµ≤í∞¢ÚÚÊ˜Bñµ≤fñFVÚ¬∆íÊ˜&÷∆«ê¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñáfñFVıW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢&WVW7C¢&WVW7B¿¢ì∞¢&WGW&‚G'VS∞¢–†¢&ñÁBÇuñµ≥¢7F'FñÊr&WG'í∆ˆvñ2f˜"6ˆ∆B7F˜&vRÜÊF∆ñÊrrì∞†¢ÚÚvVÊW&FRÊWr&WG'íîBFÚ6Ê6V¬Áí&Wfñ˜W2&WG'í∆ˆ˜0¢˜ñµµ&WG'îñB≤≥∞¢fñÊ¬◊ï&WG'îñB“˜ñµµ&WG'îñC∞¢&ñÁBÇuñµ≥¢vVÊW&FVB&WG'íîC¢F◊ï&WG'îñBrì∞†¢ÚÚ&W6WB&WG'í7FFP¢˜ñµµ&WG'î6˜VÁB“∞¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞†¢ÚÚ&WG'ívóFÇWáˆÊVÁFñ¬&6∂ˆf`¢ÚÚ7FÊF&Fó¶VB&WG'í&÷WFW'2FÚ÷F6Ç¶fÙ∂˜F∆ñ‚ñ◊∆V÷VÁFFñˆ‡¢6ˆÁ7B÷Ö&WG&ñW2“S≤ÚÚbF˜F¬GFV◊G2ñÊ6«VFñÊrñÊóFñ¿¢6ˆÁ7B&6TFV∆ï6V6ˆÊG2“#∞¢6ˆÁ7B÷WFFFFñ÷V˜WE6V6ˆÊG2“≤ÚÚ7FÊF&Fó¶VBFñ÷V˜W@¢6ˆÁ7B÷ÑFV∆ï6V6ˆÊG2“É≤ÚÚ7FÊF&Fó¶VB÷ÇFV∆í6 †¢ÚÚ5$ïDî4¬dïÉ¢˜V‚∆ñW"Ù‰4R&Vf˜&RFÜR&WG'í∆ˆ˜ ¢ÚÚFÜó2&WfVÁG2&W6WGFñÊrFÜRfñFVÚFÚ£ñbóB∆ˆG2GW&ñÊr&WG'íFV∆ê¢&ñÁBÇuñµ≥¢ñÊóFñ¬∆ñ&6≤GFV◊B“˜VÊñÊr÷VFñ‚‚‚rì∞¢G'í∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñáfñFVıW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢&WVW7C¢&WVW7B¿¢ì∞¢“6F6ÇÜRí∞¢&ñÁBÇuñµ≥¢ñÊóFñ¬∆ñW"Ê˜V‚Çífñ∆VBvóFÇW'&˜#¢FRrì∞¢ÚÚ6ˆÁFñÁVRvóFÇ&WG'í∆ˆ˜“÷ñváBv˜&≤ˆ‚7V'6WVVÁBGFV◊G0¢–†¢ñÁBGFV◊B“∞¢vÜñ∆RÜGFV◊B√“÷Ö&WG&ñW2í∞¢G'í∞¢ÚÚ6ÜV6≤ñb6Ê6V∆∆VB&Vf˜&R7F'FñÊrGFV◊@¢ñbÖ˜ñµµ&WG'îñB“◊ï&WG'îñB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí∞¢&ñÁBÄ¢uñµ≥¢&WG'í∆ˆ˜6Ê6V∆∆VB&Vf˜&RGFV◊BG∂GFV◊B≤“ÜÊfñvFñˆ‚ˆ67W'&VBír¿¢ì∞¢ÚÚ6∆V"7FFR7ñÊ6á&ˆÊ˜W6«ê¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞¢–¢&WGW&‚f«6S∞¢–†¢&ñÁBÇuñµ≥¢÷ˆÊóF˜&ñÊrGFV◊BG∂GFV◊B≤“ÚG∂÷Ö&WG&ñW2≤“‚‚‚rì∞†¢ÚÚ6∆7V∆FRFV∆íf˜"FÜó2GFV◊BÉf˜"fó'7BGFV◊Bê¢fñÊ¬FV∆ï6V6ˆÊG2“GFV◊B”“ ¢Ú ¢¢Ü&6TFV∆ï6V6ˆÊG2¢É√¬ÜGFV◊B“ííì∞¢fñÊ¬6VDFV∆í“FV∆ï6V6ˆÊG2‚÷ÑFV∆ï6V6ˆÊG0¢Ú÷ÑFV∆ï6V6ˆÊG0¢¢FV∆ï6V6ˆÊG3∞†¢ÚÚ5$ïDî4¬dïÉ¢vóBf˜"fñFVÚ÷WFFFvóFÇUÖDT‰DTB÷ˆÊóF˜&ñÊrGW&ñÊrFV∆íW&ñˆ@¢ÚÚFÜó2∆∆˜w2FWFV7Fñˆ‚ˆbfñFVÚ∆ˆFñÊrEU$î‰rFÜRFV∆í¬&WfVÁFñÊrVÊÊV6W76'í∆ñW"&W6WG0¢&ñÁBÄ¢uñµ≥¢vóFñÊrf˜"fñFVÚGW&Fñˆ‚ÇG∂÷WFFFFñ÷V˜WE6V6ˆÊG7◊2í≤÷ˆÊóF˜&ñÊrGW&ñÊrFV∆íÇG∂6VDFV∆ó◊2í‚‚‚r¿¢ì∞¢fñÊ¬∆ˆE7V66W72“vóB˜vóDf˜%fñFVÙ÷WFFFÄ¢Fñ÷V˜WE6V6ˆÊG3¢÷WFFFFñ÷V˜WE6V6ˆÊG2¿¢&WG'îñC¢◊ï&WG'îñB¿¢FFóFñˆÊƒ÷ˆÊóF˜&ñÊu6V6ˆÊG3¢6VDFV∆í¿¢ì∞†¢ñbá&WVW7CÚÊó47W'&VÁB”“f«6Rí&WGW&‚f«6S∞¢ñbÜ∆ˆE7V66W72í∞¢ÚÚ7V66W72fñFVÚ∆ˆFVBÜVóFÜW"ñ÷÷VFñFV«í˜"GW&ñÊr÷ˆÊóF˜&ñÊrˆFV∆íê¢&ñÁBÇuñµ≥¢fñFVÚ÷WFFF∆ˆFVB7V66W76gV∆«í“fñ∆Ró2&VGírì∞¢ÚÚÊ˜FS¢&WG'í7FFR«&VGí6∆V&VB'í˜vóDf˜%fñFVÙ÷WFFF¢&ñÁBÇuñµ≥¢&WG'í÷V6ÜÊó6“gV∆«íFV7FófFVB¬∆ñ&6≤&VGírì∞¢&WGW&‚G'VS∞¢–†¢ÚÚfñFVÚFñF‚wB∆ˆBWfV‚gFW"÷ˆÊóF˜&ñÊrGW&ñÊrFV∆ê¢&ñÁBÄ¢uñµ≥¢fñFVÚ÷WFFFfñ∆VBFÚ∆ˆBgFW"G∂÷WFFFFñ÷V˜WE6V6ˆÊG2≤6VDFV∆ó◊2“fñ∆R∆ñ∂V«íñ‚6ˆ∆B7F˜&vRr¿¢ì∞†¢ÚÚ6ÜV6≤ñbFÜó2v2FÜR∆7BGFV◊BÜ∆¬&WG&ñW2WÜÜW7FVBê¢ñbÜGFV◊B„“÷Ö&WG&ñW2í∞¢ÚÚƒ¬$UE$îU2UÑÑU5DTB“ÜÊF∆RÜW&P¢&ñÁBÇuñµ≥¢∆¬&WG'íGFV◊G2WÜÜW7FVB‚fñFVÚfñ∆VBFÚ∆ˆB‚rì∞†¢ÚÚ6∆V"&WG'í7FFP¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞†¢ñbÜó4FV'&ñgïEbí∞¢ÚÚWFÚ◊6∂óf˜"FV'&ñgíE`¢&ñÁBÇuñµ≥¢WFÚ÷GfÊ6ñÊrFÚÊWáBfñFVÚñ‚FV'&ñgíEbVWVRrì∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢ufñFVÚfñ∆VBFÚ∆ˆB‚6∂óñÊrFÚÊWáB‚‚‚r¿¢7Gñ∆S¢FWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢6ˆ∆˜'2Ê˜&ÊvR¿¢GW&Fñˆ„¢GW&Fñˆ‚á6V6ˆÊG3¢2í¿¢í¿¢ì∞¢vóBˆvıFÙÊWáDWó6ˆFRÇì∞¢“V«6Rñbá6Ü˜tfñ«W&Rí∞¢ÚÚ6Ü˜rW'&˜"f˜"&VwV∆"∆ñ∆ó7@¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢tfñ∆VBFÚ∆ífñFVÚgFW"◊V«Fó∆RGFV◊G2‚∆V6RG'ívñ‚∆FW"‚r¿¢7Gñ∆S¢FWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢6ˆ∆˜'2Á&VB¿¢GW&Fñˆ„¢GW&Fñˆ‚á6V6ˆÊG3¢Rí¿¢í¿¢ì∞¢–¢–¢&WGW&‚f«6S≤ÚÚWÜÜW7FVBFÜR6ˆ∆B◊7F˜&vR&WG&ñW2‡¢–†¢ÚÚ7Fñ∆¬ÜfR&WG&ñW2∆VgB“6ˆÁFñÁVRvóFÇ&WG'í∆ˆvñ0¢ÚÚ6∆7V∆FRFV∆íf˜"‰UÖBGFV◊@¢fñÊ¬ÊWáDFV∆ï6V6ˆÊG2“&6TFV∆ï6V6ˆÊG2¢É√¬GFV◊Bì∞¢fñÊ¬ÊWáDFV∆í“ÊWáDFV∆ï6V6ˆÊG2‚÷ÑFV∆ï6V6ˆÊG0¢Ú÷ÑFV∆ï6V6ˆÊG0¢¢ÊWáDFV∆ï6V6ˆÊG3∞†¢ÚÚWFFRTíFÚ6Ü˜r&WG'í7FFP¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5ñµµ&WG'ññÊr“G'VS∞¢˜ñµµ&WG'î6˜VÁB“GFV◊B≤∞¢˜ñµµ&WG'î÷W76vR“u&V7FófFñÊrfñFVÚ‚‚‚s∞¢“ì∞¢–†¢&ñÁBÄ¢uñµ≥¢&WG'íG∂GFV◊B≤““&V˜VÊñÊr∆ñW"ÊBvóFñÊrG∂ÊWáDFV∆ó◊2&Vf˜&RÊWáB6ÜV6≤‚‚‚r¿¢ì∞†¢ÚÚ6ÜV6≤ñbvñFvWBv2Fó7˜6V@¢ñbÇ÷˜VÁFVBí∞¢&ñÁBÇuñµ≥¢vñFvWBFó7˜6VB&Vf˜&R&WG'írì∞¢&WGW&‚f«6S∞¢–†¢ÚÚ6ÜV6≤ñb6Ê6V∆∆V@¢ñbÖ˜ñµµ&WG'îñB“◊ï&WG'îñB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí∞¢&ñÁBÄ¢uñµ≥¢&WG'í∆ˆ˜6Ê6V∆∆VB&Vf˜&R&V˜VÊñÊr∆ñW"ÜÊfñvFñˆ‚ˆ67W'&VBír¿¢ì∞¢ÚÚ6∆V"7FFR7ñÊ6á&ˆÊ˜W6«ê¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞¢–¢&WGW&‚f«6S∞¢–†¢ÚÚG'í&V˜VÊñÊrFÜR∆ñW"Ü÷ñváBÜV«&V7FófFR6ˆ∆B7F˜&vRfñ∆Rê¢G'í∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñáfñFVıW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢&WVW7C¢&WVW7B¿¢ì∞¢“6F6ÇÜRí∞¢&ñÁBÄ¢uñµ≥¢&WG'íG∂GFV◊B≤““∆ñW"Ê˜V‚Çífñ∆VBvóFÇW'&˜#¢FRr¿¢ì∞¢ÚÚ6ˆÁFñÁVR“FÜR÷ˆÊóF˜&ñÊrñ‚ÊWáBóFW&Fñˆ‚÷ñváB7Fñ∆¬FWFV7BñbóB∆ˆG0¢–¢“6F6ÇÜRí∞¢&ñÁBÇuñµ≥¢&WG'íGFV◊BG∂GFV◊B≤“fñ∆VBvóFÇW'&˜#¢FRrì∞†¢ÚÚ6ÜV6≤ñbFÜó2v2FÜR∆7BGFV◊BÜ∆¬&WG&ñW2WÜÜW7FVBê¢ñbÜGFV◊B„“÷Ö&WG&ñW2í∞¢ÚÚƒ¬$UE$îU2UÑÑU5DTB“ÜÊF∆RÜW&P¢&ñÁBÄ¢uñµ≥¢∆¬&WG'íGFV◊G2WÜÜW7FVBgFW"W'&˜"‚fñFVÚfñ∆VBFÚ∆ˆB‚r¿¢ì∞†¢ÚÚ6∆V"&WG'í7FFP¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞†¢ñbÜó4FV'&ñgïEbí∞¢ÚÚWFÚ◊6∂óf˜"FV'&ñgíE`¢&ñÁBÇuñµ≥¢WFÚ÷GfÊ6ñÊrFÚÊWáBfñFVÚñ‚FV'&ñgíEbVWVRrì∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢ufñFVÚfñ∆VBFÚ∆ˆB‚6∂óñÊrFÚÊWáB‚‚‚r¿¢7Gñ∆S¢FWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢6ˆ∆˜'2Ê˜&ÊvR¿¢GW&Fñˆ„¢GW&Fñˆ‚á6V6ˆÊG3¢2í¿¢í¿¢ì∞¢vóBˆvıFÙÊWáDWó6ˆFRÇì∞¢“V«6Rñbá6Ü˜tfñ«W&Rí∞¢ÚÚ6Ü˜rW'&˜"f˜"&VwV∆"∆ñ∆ó7@¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6ˆÁ7B6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÄ¢tfñ∆VBFÚ∆ífñFVÚgFW"◊V«Fó∆RGFV◊G2‚∆V6RG'ívñ‚∆FW"‚r¿¢7Gñ∆S¢FWáE7Gñ∆RÜ6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢&6∂w&˜VÊD6ˆ∆˜#¢6ˆ∆˜'2Á&VB¿¢GW&Fñˆ„¢GW&Fñˆ‚á6V6ˆÊG3¢Rí¿¢í¿¢ì∞¢–¢–¢&WGW&‚f«6S≤ÚÚWÜÜW7FVBFÜR6ˆ∆B◊7F˜&vR&WG&ñW2‡¢–†¢ÚÚ7Fñ∆¬ÜfR&WG&ñW2∆VgB“6ˆÁFñÁVRvóFÇ&WG'í∆ˆvñ0¢ÚÚ6∆7V∆FRFV∆íf˜"ÊWáBGFV◊@¢fñÊ¬FV∆ï6V6ˆÊG2“&6TFV∆ï6V6ˆÊG2¢É√¬GFV◊Bì∞¢fñÊ¬ÊWáDFV∆í“FV∆ï6V6ˆÊG2‚÷ÑFV∆ï6V6ˆÊG0¢Ú÷ÑFV∆ï6V6ˆÊG0¢¢FV∆ï6V6ˆÊG3∞†¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢ˆó5ñµµ&WG'ññÊr“G'VS∞¢˜ñµµ&WG'î6˜VÁB“GFV◊B≤∞¢˜ñµµ&WG'î÷W76vR“u&V7FófFñÊrfñFVÚ‚‚‚s∞¢“ì∞¢–†¢&ñÁBÄ¢uñµ≥¢W'&˜"ñ‚GFV◊BG∂GFV◊B≤“¬vóFñÊrG∂ÊWáDFV∆ó◊2&Vf˜&R&WG'í‚‚‚r¿¢ì∞†¢ÚÚ6ÜV6≤ñbvñFvWBv2Fó7˜6V@¢ñbÇ÷˜VÁFVBí∞¢&ñÁBÇuñµ≥¢vñFvWBFó7˜6VBGW&ñÊrW'&˜"ÜÊF∆ñÊrrì∞¢&WGW&‚f«6S∞¢–†¢ÚÚ6ÜV6≤ñb6Ê6V∆∆V@¢ñbÖ˜ñµµ&WG'îñB“◊ï&WG'îñB«¬&WVW7CÚÊó47W'&VÁB”“f«6Rí∞¢&ñÁBÄ¢uñµ≥¢&WG'í∆ˆ˜6Ê6V∆∆VBGW&ñÊrW'&˜"ÜÊF∆ñÊrÜÊfñvFñˆ‚ˆ67W'&VBír¿¢ì∞¢ÚÚ6∆V"7FFR7ñÊ6á&ˆÊ˜W6«ê¢ˆó5ñµµ&WG'ññÊr“f«6S∞¢˜ñµµ&WG'î÷W76vR“ÁV∆√∞¢˜ñµµ&WG'î6˜VÁB“∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞¢–¢&WGW&‚f«6S∞¢–†¢ÚÚG'í&V˜VÊñÊrFÜR∆ñW"f˜"ÊWáBGFV◊@¢G'í∞¢vóBˆ˜V‰÷VFñÄ¢÷≤‰÷VFñáfñFVıW&¬¬áGGÜVFW'3¢ˆ7FófTáGGÜVFW'2í¿¢∆ì¢G'VR¿¢&WVW7C¢&WVW7B¿¢ì∞¢“6F6Çá&V˜V‰W'&˜"í∞¢&ñÁBÄ¢uñµ≥¢W'&˜"&WG'í“∆ñW"Ê˜V‚Çífñ∆VBvóFÇW'&˜#¢G&V˜V‰W'&˜"r¿¢ì∞¢ÚÚ6ˆÁFñÁVR“ÊWáBóFW&Fñˆ‚÷ñváB7V66VV@¢–¢–†¢GFV◊B≤≥∞¢–¢&WGW&‚f«6S∞¢–†¢ÚÚÚ&V∆ˆBWó6ˆFRñÊf˜&÷Fñˆ‚ñ‚FÜR&6∂w&˜VÊ@¢gWGW&S«fˆñC‚˜&V∆ˆDWó6ˆFTñÊfÚÇí7ñÊ2∞¢fñÊ¬6W&ñW5∆ñ∆ó7B“˜6W&ñW5∆ñ∆ó7C∞†¢ñbá6W&ñW5∆ñ∆ó7B“ÁV∆¬bb6W&ñW5∆ñ∆ó7BÊó56W&ñW2í∞¢fñÊ¬∆ñ∆ó7DñFVÁFóGïFˆ∂V‚“˜∆ñ∆ó7DñFVÁFóGïFˆ∂V„∞¢ÚÚ&V∆ˆBWó6ˆFRñÊf˜&÷Fñˆ‚ñ‚FÜR&6∂w&˜VÊ@¢ÚÚ72î‘D"îBg&ˆ“6F∆ˆrf˜"f7FW"¬÷˜&R67W&FR∆ˆˆ∑W ¢vóB6W&ñW5∆ñ∆ó7@¢ÊfWF6ÑWó6ˆFTñÊfÚÄ¢∆ñ∆ó7DóFV”¢ˆ6ˆÁ7G'V7E∆ñ∆ó7DóFV‘FFÇí¿¢ñ÷F$ñC¢vñFvWBÊ6ˆÁFVÁDñ÷F$ñB¿¢ê¢ÁFÜV‚ÇÖÚí7ñÊ2∞¢ñbÇ÷˜VÁFVB«¿¢∆ñ∆ó7DñFVÁFóGïFˆ∂V‚“˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚«¿¢ñFVÁFñ6¬á6W&ñW5∆ñ∆ó7B¬˜6W&ñW5∆ñ∆ó7Bíí∞¢&WGW&„∞¢–†¢ÚÚEd÷¶R6‚Fó66˜fW"FÜR6W&ñW2î‘D"îBgFW"FÜRñÊóFñ¬7V'FóF∆P¢ÚÚ&W7F˜&RÜ2«&VGí'V‚‚&WG'íFÜRWÜó7FñÊrFFˆ‚7V'FóF∆RFÇ6¢ÚÚ$BıF˜&&˜Ç6V6ˆ‚6∑2FÚÊ˜B&WVó&R&V˜VÊñÊrFÜR∆ñW"‡¢˜&WG'îFFˆÂ7V'FóF∆TfWF6ÑgFW%6W&ñW4÷WFFFÄ¢6W&ñW5∆ñ∆ó7B¿¢∆ñ∆ó7DñFVÁFóGïFˆ∂V‚¿¢ì∞†¢ÚÚG&ñvvW"TíWFFRFÚ6Ü˜rFÜRWó6ˆFRñÊf¢6WE7FFRÇÇí∑“ì∞†¢ÚÚ6fRFó66˜fW&VBî‘D"îB&6≤FÚ∆ñ∆ó7BóFV“f˜"gWGW&RFó&V7B∆ó0¢vóB˜6fTñ÷F$ñEFı∆ñ∆ó7Bá6W&ñW5∆ñ∆ó7Bì∞†¢ÚÚWáG&7B˜7FW"U$¬g&ˆ“6W&ñW2FFÊB6fRFÚ∆ñ∆ó7@¢vóB˜6fU6W&ñW5˜7FW%Fı∆ñ∆ó7Bá6W&ñW5∆ñ∆ó7Bì∞¢“ê¢Ê6F6ÑW'&˜"ÇÜW'&˜"í∞¢ÚÚ6ñ∆VÁF«íÜÊF∆RW'&˜'2“FÜó2ó2ßW7B&V∆ˆFñÊp¢“ì∞¢“V«6Rñbá6W&ñW5∆ñ∆ó7B“ÁV∆¬bb6W&ñW5∆ñ∆ó7BÊó56W&ñW2í∞¢ÚÚf˜"Êˆ‚◊6W&ñW26ˆÁFVÁBÜ÷˜fñR6ˆ∆∆V7FñˆÁ2í¬fWF6Ç÷˜fñR÷WFFFf˜"7W'&VÁBñÊFWÄ¢ÚÚFÜó2VÊ&∆W27V'FóF∆W2f˜"÷˜fñW2g&ˆ“FV'&ñBıF˜&&˜Çıñµ∞¢vóB6W&ñW5∆ñ∆ó7@¢ÊfWF6Ñ÷˜fñT÷WFFFf˜$ñÊFWÇÖˆ7W'&VÁDñÊFWÇê¢ÁFÜV‚ÇÜñ÷F$ñBí∞¢ÚÚG&ñvvW"TíWFFRñbî‘D"îBv2Fó66˜fW&V@¢ñbÜ÷˜VÁFVBbbñ÷F$ñB“ÁV∆¬í∞¢6WE7FFRÇÇí∑“ì∞¢–¢“ê¢Ê6F6ÑW'&˜"ÇÜW'&˜"í∞¢ÚÚ6ñ∆VÁF«íÜÊF∆RW'&˜'2“FÜó2ó2ßW7B&V∆ˆFñÊp¢“ì∞¢“V«6Rñbá6W&ñW5∆ñ∆ó7B”“ÁV∆¬bbvñFvWBÊ6ˆÁFVÁDñ÷F$ñB”“ÁV∆¬í∞¢ÚÚ6ñÊv∆R÷fñ∆R∆ñ&6≤ÜÊÚ∆ñ∆ó7Bí“G'íFÚfWF6Ç÷˜fñR÷WFFFg&ˆ“FóF∆P¢vóBˆfWF6Ö6ñÊv∆Tfñ∆T÷˜fñT÷WFFFÇì∞¢–¢–†¢fˆñB˜&WG'îFFˆÂ7V'FóF∆TfWF6ÑgFW%6W&ñW4÷WFFFÄ¢6W&ñW5∆ñ∆ó7B6W&ñW5∆ñ∆ó7B¿¢ñÁB∆ñ∆ó7DñFVÁFóGïFˆ∂V‚¿¢í∞¢fñÊ¬ñ÷F$ñB“6W&ñW5∆ñ∆ó7BÊñ÷F$ñC∞¢ñbÜñ÷F$ñB”“ÁV∆¬«¬ñ÷F$ñBÁ7F'G5vóFÇÇwGBríí&WGW&„∞¢ñbá∆ñ∆ó7DñFVÁFóGïFˆ∂V‚“˜∆ñ∆ó7DñFVÁFóGïFˆ∂V‚í&WGW&„∞¢ñbÇñFVÁFñ6¬á6W&ñW5∆ñ∆ó7B¬˜6W&ñW5∆ñ∆ó7Bíí&WGW&„∞†¢ÚÚñbG&6≤&VfW&VÊ6W2ÜfRÊ˜B6ˆ◊∆WFVBñWB¬FÜRÊ˜&÷¬&W7F˜&RFÇvñ∆¿¢ÚÚ6VRFÜRÊWv«íFó66˜fW&VBî‘D"îBÊBfWF6Ç7V'FóF∆W2BFÜR&ñváBFñ÷R‡¢ñbÇ˜G&6µ&VfW&VÊ6W5&VGîf˜$FFˆÂ7V'FóF∆W2í∞¢FV'Vu&ñÁBÄ¢ufñFVı∆ñW#¢6W&ñW2î‘D"&W6ˆ«fVB&Vf˜&RG&6≤&W7F˜&S≤7V'FóF∆RfWF6Çvñ∆¬'V‚GW&ñÊr&W7F˜&Rr¿¢ì∞¢&WGW&„∞¢–†¢FV'Vu&ñÁBÄ¢ufñFVı∆ñW#¢6W&ñW2î‘D"&W6ˆ«fVBgFW"ñÊóFñ¬7V'FóF∆RfWF6Ç¬&WG'ññÊrFFˆ‚7V'FóF∆W2Ñî‘D#¢Fñ÷F$ñBír¿¢ì∞¢VÊvóFVBÖˆfWF6ÑÊD÷ñ&TWFı6V∆V7DFFˆÂ7V'FóF∆RÇíì∞¢–†¢ÚÚÚfWF6Ç÷˜fñR÷WFFFf˜"6ñÊv∆R÷fñ∆R∆ñ&6≤ávÜV‚ÊÚ∆ñ∆ó7BWÜó7G2ê¢gWGW&S«fˆñC‚ˆfWF6Ö6ñÊv∆Tfñ∆T÷˜fñT÷WFFFÇí7ñÊ2∞¢ÚÚ6∂óñb«&VGífWF6ÜVB˜"vRÜfR‚î‘D"î@¢ñbÖ˜6ñÊv∆Tfñ∆Tñ÷F$fWF6ÜVB«¬vñFvWBÊ6ˆÁFVÁDñ÷F$ñB“ÁV∆¬í∞¢&WGW&„∞¢–†¢˜6ñÊv∆Tfñ∆Tñ÷F$fWF6ÜVB“G'VS∞†¢ÚÚW6RGñÊ÷ñ2FóF∆RáWFFVBˆ‚7G&V“7vóF6Çí˜"f∆¬&6≤FÚvñFvWBFóF∆P¢fñÊ¬FóF∆R“ˆGñÊ÷ñ5FóF∆RÊó4Ê˜DV◊GíÚˆGñÊ÷ñ5FóF∆R¢vñFvWBÁFóF∆S∞¢ñbáFóF∆RÊó4V◊Gíí∞¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢ÊÚFóF∆Rf˜"6ñÊv∆R÷fñ∆R∆ˆˆ∑Wrì∞¢&WGW&„∞¢–†¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢6ñÊv∆R÷fñ∆R∆ˆˆ∑Wf˜""GFóF∆R"rì∞†¢ÚÚ'6RFÜRFóF∆Rf˜"÷˜fñRñÊf¢fñÊ¬÷˜fñTñÊfÚ“÷˜fñU'6W"Á'6Tfñ∆VÊ÷RáFóF∆Rì∞†¢ñbÇ÷˜fñTñÊfÚÊÜ5ñV"í∞¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢ÊÚñV"GFW&‚ñ‚6ñÊv∆R÷fñ∆RFóF∆Rrì∞¢&WGW&„∞¢–†¢ñbÜ÷˜fñTñÊfÚÁFóF∆R”“ÁV∆¬«¬÷˜fñTñÊfÚÁFóF∆RÊó4V◊Gíí∞¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢6˜V∆BÊ˜BWáG&7BFóF∆Rg&ˆ“6ñÊv∆R÷fñ∆Rrì∞¢&WGW&„∞¢–†¢FV'Vu&ñÁBÄ¢t÷˜fñT÷WFFF¢'6VB6ñÊv∆R÷fñ∆RFóF∆S“"G∂÷˜fñTñÊfÚÁFóF∆W“"¬ñV#“G∂÷˜fñTñÊfÚÁñV'“r¿¢ì∞†¢G'í∞¢fñÊ¬÷WFFF“vóB÷˜fñT÷WFFF6W'fñ6RÊ∆ˆˆ∑W÷˜fñRÄ¢÷˜fñTñÊfÚÁFóF∆R¿¢÷˜fñTñÊfÚÁñV"¿¢ì∞†¢ñbÜ÷WFFF“ÁV∆¬í∞¢˜6ñÊv∆Tfñ∆Tñ÷F$ñB“÷WFFFÊñ÷F$ñC∞¢FV'Vu&ñÁBÄ¢t÷˜fñT÷WFFF¢f˜VÊBî‘D"îB"G∂÷WFFFÊñ÷F$ñG“"f˜"6ñÊv∆R÷fñ∆R"G∂÷WFFFÁFóF∆W“"r¿¢ì∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∑“ì∞¢–¢“V«6R∞¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢ÊÚ÷F6Çf˜VÊBf˜"6ñÊv∆R÷fñ∆Rrì∞¢–¢“6F6ÇÜRí∞¢FV'Vu&ñÁBÇt÷˜fñT÷WFFF¢W'&˜"GW&ñÊr6ñÊv∆R÷fñ∆R∆ˆˆ∑W¢FRrì∞¢–¢–†¢gWGW&S«fˆñC‚˜6fTñ÷F$ñEFı∆ñ∆ó7BÖ6W&ñW5∆ñ∆ó7B6W&ñW5∆ñ∆ó7Bí7ñÊ2∞¢fñÊ¬ñ÷F$ñB“6W&ñW5∆ñ∆ó7BÊñ÷F$ñC∞¢ñbÜñ÷F$ñB”“ÁV∆¬«¬ñ÷F$ñBÁ7F'G5vóFÇÇwGBríí&WGW&„∞¢ñbávñFvWBÊ6ˆÁFVÁDñ÷F$ñB“ÁV∆¬í&WGW&„∞†¢vóB7F˜&vU6W'fñ6RÁWFFU∆ñ∆ó7DóFV‘ñ÷F$ñBÄ¢ñ÷F$ñB¿¢&EF˜'&VÁDñC¢vñFvWBÁ&EF˜'&VÁDñB¿¢F˜&&˜ÖF˜'&VÁDñC¢vñFvWBÁF˜&&˜ÖF˜'&VÁDñB¿¢ñ∑¥6ˆ∆∆V7Fñˆ‰ñC¢vñFvWBÁñ∑¥6ˆ∆∆V7Fñˆ‰ñB¿¢ì∞¢–†¢ÚÚÚ6fR6W&ñW2˜7FW"U$¬FÚ∆ñ∆ó7BóFV–¢gWGW&S«fˆñC‚˜6fU6W&ñW5˜7FW%Fı∆ñ∆ó7BÄ¢6W&ñW5∆ñ∆ó7B6W&ñW5∆ñ∆ó7B¿¢í7ñÊ2∞¢&ñÁBÇnù◊üäwù∫w^~)ﬁv¬˜6fU6W&ñW5˜7FW%Fı∆ñ∆ó7B6∆∆VBrì∞¢&ñÁBÇr6W&ñW5FóF∆S¢G∑6W&ñW5∆ñ∆ó7BÁ6W&ñW5FóF∆W“rì∞†¢ñbá6W&ñW5∆ñ∆ó7BÁ6W&ñW5FóF∆R”“ÁV∆¬í∞¢&ñÁBÇr.ù◊üäwù∫w^~)ﬁtÚÊÚ6W&ñW2FóF∆R¬6∂óñÊr˜7FW"6fRrì∞¢&WGW&„∞¢–†¢ÚÚvWBñFVÁFñfñW'2g&ˆ“vñFvWB&÷WFW'0¢fñÊ¬&EF˜'&VÁDñB“vñFvWBÁ&EF˜'&VÁDñC∞¢fñÊ¬F˜&&˜ÖF˜'&VÁDñB“vñFvWBÁF˜&&˜ÖF˜'&VÁDñC∞¢fñÊ¬ñ∑¥6ˆ∆∆V7Fñˆ‰ñB“vñFvWBÁñ∑¥6ˆ∆∆V7Fñˆ‰ñC∞†¢&ñÁBÇr&EF˜'&VÁDñC¢G&EF˜'&VÁDñBrì∞¢&ñÁBÇrF˜&&˜ÖF˜'&VÁDñC¢GF˜&&˜ÖF˜'&VÁDñBrì∞¢&ñÁBÇrñ∑¥6ˆ∆∆V7Fñˆ‰ñC¢Gñ∑¥6ˆ∆∆V7Fñˆ‰ñBrì∞†¢ÚÚÊVVBB∆V7BˆÊRñFVÁFñfñW"FÚ6fR˜7FW ¢ñbÇá&EF˜'&VÁDñB”“ÁV∆¬«¬&EF˜'&VÁDñBÊó4V◊Gííb`¢áF˜&&˜ÖF˜'&VÁDñB”“ÁV∆¬«¬F˜&&˜ÖF˜'&VÁDñBÊó4V◊Gííb`¢áñ∑¥6ˆ∆∆V7Fñˆ‰ñB”“ÁV∆¬«¬ñ∑¥6ˆ∆∆V7Fñˆ‰ñBÊó4V◊Gííí∞¢&ñÁBÇrZ7»õ»ò[YY[ùYöY\àõ›[ô⁄⁄\[ô»‹›\àÿ]ôI N¬àô]\õé¬àBÇàö[ò[‹›\ï\õHŸ\öY\‘^[\›ú⁄›‘‹›\ï\õ¬àYà
‹›\ï\õOHù[‹›\ï\õö\—[\JH¬àö[ù
	»hﬂ No poster URL from fetchEpisodeInfo');
      return;
    }

    print('  Poster URL: $posterUrl');
    try {
      if (rdTorrentId != null && rdTorrentId.isNotEmpty) {
        await StorageService.updatePlaylistItemPoster(
          posterUrl,
          rdTorrentId: rdTorrentId,
        );
      }
      if (torboxTorrentId != null && torboxTorrentId.isNotEmpty) {
        await StorageService.updatePlaylistItemPoster(
          posterUrl,
          torboxTorrentId: torboxTorrentId,
        );
      }
      if (pikpakCollectionId != null && pikpakCollectionId.isNotEmpty) {
        await StorageService.updatePlaylistItemPoster(
          posterUrl,
          pikpakCollectionId: pikpakCollectionId,
        );
      }
    } catch (e) {
      print('  ∫w^~)ﬁt Error saving poster: $e');
    }
  }

  bool _iosPipStarting = false;
  bool _iosPipDetached = false;
  PlayerPipSession? _iosPipSession;
  int _lastIosPipPositionSecond = -1;

  /// Enter PiP now, sized to the current video's pixel aspect when known.
  Future<void> _enterPip() async {
    if (!PipService.isOwner(this) ||
        !_playerCreated ||
        _isTransitioning ||
        _iosPipStarting ||
        _isPipActive)
      return;
    final player = _player;
    if (Platform.isIOS) setState(() => _iosPipStarting = true);
    var entered = false;
    try {
      final handle = Platform.isIOS ? await player.handle : null;
      if (!mounted || !PipService.isOwner(this) || !identical(player, _player))
        return;
      if (Platform.isIOS) {
        await _setNativeSubtitleVisibilityForTrack(player.state.track.subtitle);
      }
      _pushPipState();
      entered = await PipService.enterPip(
        aspectWidth: player.state.width,
        aspectHeight: player.state.height,
        playerHandle: handle,
      );
    } catch (error) {
      debugPrint('PiP entry failed: $error');
    } finally {
      if (mounted && PipService.isOwner(this) && identical(player, _player)) {
        if (Platform.isIOS) {
          setState(() => _iosPipStarting = false);
          unawaited(
            _setNativeSubtitleVisibilityForTrack(player.state.track.subtitle),
          );
        }
        if (!entered) {
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.paused) {
            _pauseForBackground();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Picture in Picture could not start. Please try again.',
              ),
            ),
          );
        }
      }
    }
  }

  /// Arm auto-enter (Home button) for this screen, seeding the current video
  /// aspect so the auto-entered window matches the video shape. No-op unless
  /// this screen is the active, supported PiP owner.
  void _armPipAutoEnter() {
    if (Platform.isIOS) return; // iOS prepares its renderer on explicit entry.
    if (!PipService.isOwner(this)) return;
    final w = _player.state.width ?? 0;
    final h = _player.state.height ?? 0;
    unawaited(PipService.setAutoEnter(true, aspectWidth: w, aspectHeight: h));
  }

  /// Keep the native side's play/pause icon, Next button and window aspect in
  /// sync with the live player"È›y¯ßy‘ both for an open PiP window and for the next
  /// Home-button auto-enter. No-op unless this screen is the active PiP owner.
  void _pushPipState() {
    if (!PipService.isOwner(this)) return;
    final w = _player.state.width ?? 0;
    final h = _player.state.height ?? 0;
    unawaited(
      PipService.updatePlaybackState(
        isPlaying: _isPlaying,
        hasNext: _hasAnyNext,
        positionMs: _player.state.position.inMilliseconds,
        durationMs: _player.state.duration.inMilliseconds,
        aspectWidth: w,
        aspectHeight: h,
      ),
    );
  }

  /// Collapse the control chrome while inside the small PiP window, and restore
  /// it when the window expands back to fullscreen.
  void _onPipModeChanged(bool inPip) {
    if (!mounted) return;
    if (inPip) {
      _hideTimer?.cancel();
      _controlsVisible.value = false;
      _pushPipState();
    }
    setState(() => _isPipActive = inPip);
    if (Platform.isIOS && _playerCreated) {
      if (inPip && (_iosPipSession?.park() ?? false)) {
        _iosPipDetached = true;
        unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
        unawaited(
          SystemChrome.setPreferredOrientations(DeviceOrientation.values),
        );
      } else if (!inPip && (_iosPipSession?.isParked ?? false)) {
        // Native close (or a newer playback owner) ends the detached session.
        // Fullscreen restoration has already reattached it before this event.
        _iosPipSession?.close();
        return;
      }
      unawaited(
        _setNativeSubtitleVisibilityForTrack(_player.state.track.subtitle),
      );
    }
  }

  Future<bool> _restoreIosPipPlayer() async {
    if (!mounted || !PipService.isOwner(this)) return false;
    final session = _iosPipSession;
    if (session == null) return false;
    if (session.isParked && !session.restore()) return false;
    _iosPipDetached = false;
    await SystemChrome.setPreferredOrientations(
      _landscapeLocked
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WidgetsBinding.instance.endOfFrame;
    return mounted && PipService.isOwner(this);
  }

  /// Handle taps on the PiP window's action buttons.
  void _onPipAction(String action) {
    if (!mounted || !_playerCreated) return;
    if (action.startsWith('seek:')) {
      final seconds = double.tryParse(action.substring(5));
      if (seconds == null || !seconds.isFinite || _isTransitioning) return;
      final target =
          (_player.state.position.inMilliseconds + (seconds * 1000).round())
              .clamp(0, _player.state.duration.inMilliseconds);
      final position = Duration(milliseconds: target);
      unawaited(_player.seek(position));
      _traktScrobbleSeek(position);
      _simklScrobbleSeek(position);
      _mdblistScrobbleSeek(position);
      return;
    }
    switch (action) {
      case 'play':
        if (!_isPlaying) _togglePlay();
        break;
      case 'pause':
        if (_isPlaying) _togglePlay();
        break;
      case 'playpause':
        _togglePlay();
        break;
      case 'next':
        if (_hasAnyNext) _goToNextEpisode();
        break;
    }
  }

  /// The app left the foreground (Home, power button, app switch): stop
  /// playback instead of decoding video nobody can see. Mobile only ∫w^~)ﬁt on
  /// desktop a minimized/covered window keeping its audio is normal use, and
  /// desktop power budgets are not why this exists. PiP never gets here: a
  /// visible PiP activity stays at `inactive` (see [_lifecycle]).
  void _pauseForBackground() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Platform.isIOS && (_isPipActive || _iosPipStarting)) return;
    // Even paused playback can have a Start Over probe in flight. Cancel
    // before the playing/transition checks, including recording teardown.
    _cancelPendingIptvCatchup(hideFeedback: false);
    // A renderer restart has intentionally invalidated the old player and may
    // not have created the replacement yet. Preserve playback intent without
    // requiring either instance to be live at this exact lifecycle callback.
    if (_rendererFallbackInProgress) {
      _pausedByLifecycle = true;
      if (_playerCreated) unawaited(_player.pause());
      return;
    }
    // _isTransitioning too, not just _isPlaying: mid-switch (next episode, a
    // zap) `playing` is briefly false while an open(play: true) is in flight.
    // Backgrounding in that window must still arm the flag, or the open lands
    // moments later and plays behind the backgrounded app with the guard in
    // the playing listener disarmed. A user's own pause has neither set.
    final openingStartOver =
        _iptvStartOverActive &&
        _activeMediaShouldPlay &&
        !_activeMediaUserPaused;
    if (!_playerCreated ||
        (!_isPlaying && !_isTransitioning && !openingStartOver)) {
      return;
    }
    // A recovery in flight must not re-open streams behind a backgrounded
    // app; the resume path below re-arms recovery when it matters.
    _backgroundedAt = DateTime.now();
    _iptvLiveRecovery.cancel();
    _iptvReconnectText.value = null;
    _pausedByLifecycle = true;
    unawaited(_player.pause());
  }

  /// Undo [_pauseForBackground] when the app returns, restoring the
  /// pre-existing contract that coming back to this screen shows it playing.
  /// A pause the user made themselves (flag unset) stays a pause.
  void _resumeFromBackground() {
    if (!_pausedByLifecycle) return;
    // Cleared BEFORE play(): the playing event this triggers must not read as
    // "playback restarted behind a backgrounded app" to the guard in the
    // playing listener.
    _pausedByLifecycle = false;
    // The replacement player will read the cleared lifecycle flag immediately
    // before open/play. Calling play on the disposing instance would race the
    // one-player ownership guarantee.
    if (_rendererFallbackInProgress) return;
    if (!_playerCreated || !mounted) return;
    // Coming back from the background is not a request to un-stop the night:
    // if the sleep timer fired while we were away, stay paused until someone
    // presses play.
    if (_sleepStopLatched) return;
    // LIVE, back after a real absence: the paused stream is minutes behind
    // the edge (or dead). Re-tune to the live edge+ßuÁ‚ùÁT same "comes back
    // playing" contract, at the right point in the broadcast. Short trips
    // keep the cheap in-buffer resume (legitimate timeshift).
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (_currentIptvChannel?.isLive == true &&
        !_iptvStartOverActive &&
        backgroundedAt != null &&
        DateTime.now().difference(backgroundedAt) >
            const Duration(seconds: 30)) {
      _iptvLiveRecovery.userRetry('lifecycle-rejoin');
      return;
    }
    unawaited(_player.play());
  }

  /// The screen wakelock follows PLAYBACK, not this screen's lifetime: a
  /// paused video left on a table must not pin the display on until the
  /// route pops"È›y¯ßy‘ on phones the display is the single biggest battery
  /// consumer. Buffering stalls keep the lock (media_kit's `playing` tracks
  /// the pause property, which stays false during a stall). initState still
  /// takes the lock up front so the screen can't sleep through a slow
  /// resolve/open before the first playing event arrives.
  void _syncWakelock(bool playing) {
    unawaited(PlayerDisplayControls.instance.setWakelock(playing));
  }

  @override
  void dispose() {
    final replacedPip =
        (_iosPipSession?.wasReplaced ?? false) ||
        (_iosPipDetached && !PipService.isOwner(this));
    _iosPipSession?.close();
    PlayerVisibility.closed(this);
    if (!replacedPip) ProfileLockController.instance.setPlaybackActive(false);
    _iptvDiag.onSessionEnd();
    _iptvLiveRecovery.cancel();
    _iptvReconnectText.dispose();
    _autoSyncPillHold?.cancel();
    _autoSyncPillPhaseTimer?.cancel();
    _autoSyncPill.dispose();
    // The sleep timer belongs to this playback session"È›y¯ßy‘ a pending one must not
    // outlive the player and fire against a disposed state.
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _lifecycle?.dispose();
    final revisionListener = _desktopRecordingRevisionListener;
    if (revisionListener != null) {
      DesktopRecordingService.instance.revision.removeListener(
        revisionListener,
      );
      _desktopRecordingRevisionListener = null;
    }
    // Nothing to do for a desktop capture: closing the player is not a stop
    // request, on either platform. This screen used to finish its own capture
    // because it was the only stop control desktop had; the Recordings hub
    // (one Stop card per capture, both backends) is that control now, so the
    // contract matches Android's engine"È›y¯ßy‘ "runs while the app runs"+ßuÁ‚ùÁT and
    // endings are announced by the app-level reporter in main(), which
    // outlives this screen.
    // Finalize any in-progress recording before the player is torn down. The
    // bump also cancels a start still awaiting its storage setup (it would
    // otherwise arm a disposed player and leave the file untracked).
    //
    // Done inline rather than through `_stopRecording`: dispose() cannot await,
    // so that call would race `_player.dispose()` a few lines below AND reach
    // its own setState() mid-teardown. The order that matters is preserved by
    // hand ∫w^~)ﬁt state cleared now, publish handed off immediately (it reads the
    // .ts from disk and never touches mpv), property clear issued best-effort.
    // A live .ts stays playable even if its tail is lost to the teardown, and
    // the lifecycle listener above already caught the common backgrounding
    // case with a clean, awaited flush.
    _recordingStartGen++;
    if (_isRecording) {
      final path = _recordingTempPath;
      final platform = _playerCreated ? _player.platform : null;
      _isRecording = false;
      _recordingTempPath = null;
      if (platform is mk.NativePlayer) {
        // Publication is CHAINED after the property clear, not run alongside
        // it: libmpv keeps appending until stream-record is cleared, and a
        // concurrent copy could reach EOF early, publish a truncated file and
        // delete the source out from under the still-writing muxer.
        unawaited(
          platform
              .setProperty('stream-record', '')
              .catchError(
                (Object e) => debugPrint(
                  'VideoPlayer: stop recording on dispose failed: $e',
                ),
              )
              .whenComplete(() {
                if (path != null && Platform.isAndroid) {
                  _publishRecording(path, userInitiated: false);
                }
              }),
        );
      } else if (path != null && Platform.isAndroid) {
        unawaited(_publishRecording(path, userInitiated: false));
      }
    }
    _iptvCatchupRequests.cancel();
    // Detach from PiP (disarms auto-enter); ignored if a newer player already
    // took ownership, so route replacement can't disarm the incoming screen.
    PipService.detach(this);
    // Scrobble stop to Trakt when user exits player
    _stopTraktHeartbeat();
    _analyticsHeartbeatTimer?.cancel();
    _traktScrobble('stop');
    _stopSimklHeartbeat();
    _simklScrobble('stop');
    _mdblistStop();
    unawaited(_mdblistSession?.close() ?? Future.value());

    // Save the current state before disposing
    _saveResume();
    // Every in-app player route converges here, including callers that push
    // VideoPlayerScreen directly. The sync trigger is debounced, so the async
    // resume write above settles before its hot-state snapshot is built.
    MainPageBridge.notifyContentPlaybackStopped();

    // Cancel any ongoing PikPak retry operations
    _pikPakRetryId++;
    _isPikPakRetrying = false;
    _pikPakRetryCount = 0;
    _pikPakRetryMessage = null;

    _cleanupTempSubtitleFilesSync();
    _skipSegmentsFetchGeneration++;
    _skipSegmentProvider?.close();
    _skipSegmentProvider = null;
    _hideTimer?.cancel();
    _autosaveTimer?.cancel();
    _manualSelectionResetTimer?.cancel();
    _debrifyBannerTimer?.cancel();
    _iptvZapHideTimer?.cancel();
    _iptvZapTicker?.cancel();
    _tvScrubGeneration++; // invalidate any scrub still in flight
    _tvBarScope.dispose();
    _dockExtent.dispose();
    _tvPlayPauseFocus.dispose();
    _tvProgressFocus.dispose();
    _tvRootFocus.dispose();
    _controlsVisible.removeListener(_onControlsVisibilityChanged);
    _controlsVisible.dispose();
    _seekHud.dispose();
    _verticalHud.dispose();
    _speedHoldHud.dispose();
    _recordLogSub?.cancel();
    _subtitleDiagnosticLogSub?.cancel();
    _subtitleSelectionCorrection.dispose();
    _subtitleDiagnosticGeneration++;
    _activeSubtitleApplyAttempt = null;
    _decoderProbeGeneration++;
    _decoderProbeToken++;
    _rendererStartupGuardToken++;
    _playerInstanceGeneration++;
    _decoderProbeTimer?.cancel();
    _decoderProbeTimer = null;
    _tvosDisplayMatchToken++;
    _tvosDisplayMatchTimer?.cancel();
    _tvosDisplayMatchTimer = null;
    if (PlatformUtil.isTvOS && !replacedPip) {
      unawaited(
        TvosDisplayMatchService.clear().catchError((Object error) {
          debugPrint('DisplayMatch: tvOS dispose clear failed: $error');
        }),
      );
    }
    _posSub?.cancel();
    _durSub?.cancel();
    _playbackUiClock.dispose();
    _activeSkipSegmentUi.dispose();
    _playSub?.cancel();
    _lastLiveChannelTimer?.cancel();
    _paramsSub?.cancel();
    _trackSub?.cancel();
    _tvosDecodeRemedy?.dispose();
    _tvosDecodeRemedy = null;
    _completedSub?.cancel();
    _bufferingSub?.cancel();
    _iptvErrorSub?.cancel();
    _rendererStartupErrorSub?.cancel();
    _bufferingDebounceTimer?.cancel();
    _showBufferingIndicator.dispose();
    _releaseAudioEffectSession();
    _screenDisposed = true;
    ++_externalAudioGeneration;
    final externalAudioPlayer = _externalAudioPlayer;
    _externalAudioPlayer = null;
    if (externalAudioPlayer != null) {
      unawaited(
        externalAudioPlayer.dispose().catchError(
          (Object error) => debugPrint(
            'VideoPlayer: external audio player dispose failed: $error',
          ),
        ),
      );
    }
    final subtitleAutoSync = _subtitleAutoSync;
    _subtitleAutoSync = null;
    if (_playerCreated) {
      // The slot frees only once the native output has actually gone, not when
      // disposal is requested+ßuÁ‚ùÁT the same rule the trailer engines follow.
      () async {
        await subtitleAutoSync?.dispose();
        await _player.dispose();
      }().whenComplete(_releaseVideoOutput);
    } else if (subtitleAutoSync != null) {
      unawaited(subtitleAutoSync.dispose());
      _releaseVideoOutput();
    }
    _transitionStopTimer?.cancel();
    _rainbowController.dispose();
    // Each helper awaits native failures before completing, including disposal.
    if (!replacedPip) {
      unawaited(PlayerDisplayControls.instance.resetBrightness());
      unawaited(PlayerDisplayControls.instance.setWakelock(false));
    }
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.setFullScreen(false);
    }
    if (!replacedPip) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      AndroidNativeDownloader.isTelevision().then((isTv) {
        if (!isTv) {
          // Restore all orientations so the app respects device auto-rotate
          // after the player exits (matches main.dart's _initOrientation).
          // Locking portraitUp here forced users to flip the device back to
          // browse lists after watching in landscape.
          SystemChrome.setPreferredOrientations(<DeviceOrientation>[
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      });
    }
    super.dispose();
  }

  Timer? _autosaveTimer;

  String get _resumeKey {
    if (_activePlaylist != null &&
        _activePlaylist!.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      final entry = _activePlaylist![_currentIndex];

      // Check for Torbox-specific key
      final torboxKey = _torboxResumeKeyForEntry(entry);
      if (torboxKey != null) {
        debugPrint(
          'ResumeKey: using torbox key $torboxKey for index $_currentIndex',
        );
        return torboxKey;
      }

      // Check for PikPak-specific key
      final pikpakKey = _pikpakResumeKeyForEntry(entry);
      if (pikpakKey != null) {
        debugPrint(
          'ResumeKey: using pikpak key $pikpakKey for index $_currentIndex',
        );
        return pikpakKey;
      }
    }

    // Use playlist-specific resume ID for other items
    if (_activePlaylist != null &&
        _activePlaylist!.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _activePlaylist!.length) {
      final id = _resumeIdForEntry(_activePlaylist![_currentIndex]);
      debugPrint(
        'ResumeKey: using playlist entry id $id for index $_currentIndex',
      );
      return id;
    }

    // IPTV launches carry no playlist, so the fallback below would key every
    // channel in the session to the URL the player was OPENED with"È›y¯ßy‘ zap to
    // another channel and its position would be filed under the first one's
    // name. Key on the channel actually playing instead. (Identical to the
    // fallback until the user zaps, so existing resume points still resolve.)
    final iptvChannels = _effectiveIptvChannels;
    if (iptvChannels != null &&
        _currentIptvIndex >= 0 &&
        _currentIptvIndex < iptvChannels.length) {
      return iptvChannels[_currentIptvIndex].url;
    }

    // Fallback to videoUrl for single items
    // Note: This is the expected path for Debrify TV mode
    return widget.videoUrl;
  }

  String? _torboxResumeKeyForEntry(PlaylistEntry entry) {
    final provider = entry.provider?.toLowerCase();
    if (provider == 'torbox') {
      final torrentId = entry.torboxTorrentId;
      final webDownloadId = entry.torboxWebDownloadId;
      final fileId = entry.torboxFileId;
      if (webDownloadId != null && fileId != null) {
        debugPrint(
          'ResumeKey: torbox web download detected web=$webDownloadId file=$fileId',
        );
        return 'torbox_web_${webDownloadId}_$fileId';
      }
      if (torrentId != null && fileId != null) {
        debugPrint(
          'ResumeKey: torbox entry detected torrent=$torrentId file=$fileId',
        );
        return 'torbox_${torrentId}_$fileId';
      }
      debugPrint(
        'ResumeKey: torbox entry missing IDs torrent=$torrentId web=$webDownloadId file=$fileId',
      );
    }
    return null;
  }

  String? _pikpakResumeKeyForEntry(PlaylistEntry entry) {
    final provider = entry.provider?.toLowerCase();
    if (provider == 'pikpak') {
      final fileId = entry.pikpakFileId;
      if (fileId != null && fileId.isNotEmpty) {
        debugPrint('ResumeKey: pikpak entry detected fileId=$fileId');
        return 'pikpak_$fileId';
      }
      debugPrint('ResumeKey: pikpak entry missing fileId');
    }
    return null;
  }

  String _resumeIdForEntry(PlaylistEntry entry) {
    // Check for Torbox-specific key
    final torboxKey = _torboxResumeKeyForEntry(entry);
    if (torboxKey != null) {
      return torboxKey;
    }
    // Check for PikPak-specific key
    final pikpakKey = _pikpakResumeKeyForEntry(entry);
    if (pikpakKey != null) {
      return pikpakKey;
    }
    // Fallback to filename hash
    final name = entry.title.isNotEmpty ? entry.title : widget.title;
    return _generateFilenameHash(name);
  }

  /// [preferLocalResume]: a source switch landed on the SAME content and
  /// checkpointed the live position ∫w^~)ﬁt resume exactly there (any position, even
  /// past the 90% cutoff, matching the native TV player) and skip Trakt.
  /// Threaded as a parameter, not ambient state, so an early return or throw
  /// anywhere in the load path can never leak it into a later load.
  ///
  /// [verifyLanding]: this is the initial open, where the startup gate commits
  /// a candidate after ~40ms of decoded media and the seek can be answered with
  /// a stream restart. Confirm the seek took and re-issue once. See
  /// [_seekForResume].
  Future<void> _maybeRestoreResume({
    bool preferLocalResume = false,
    bool verifyLanding = false,
  }) async {
    // Every item load lands here, so this is where a previous item's unlanded
    // resume target stops applying"È›y¯ßy‘ including on the paths below that return
    // without arming a new one (auto-advance, manual episode pick).
    _resumeWriteGuard.clear();
    // If this is auto-advancing, don't restore position
    if (_isAutoAdvancing) {
      _isAutoAdvancing = false; // Reset the flag
      return;
    }

    // If this is a manual episode selection, only restore if we have saved progress
    if (_isManualEpisodeSelection && !_allowResumeForManualSelection) {
      // Don't reset _isManualEpisodeSelection here - let it be reset after a delay
      return;
    }
    final trackingPolicy = await TrackingSourcePolicy.load();
    // The launched item's widget percent is a first-load-only signal; capture it
    // before marking it spent so it can't apply to a later switched-to episode.
    final firstLoad = !_launchTraktPercentSpent;
    _launchTraktPercentSpent = true;
    final simklFirstLoad = !_launchSimklPercentSpent;
    _launchSimklPercentSpent = true;
    final mdblistFirstLoad = !_launchMdblistPercentSpent;
    _launchMdblistPercentSpent = true;

    await _waitForDuration();
    final dur = _duration;

    // Trakt candidate (cross-device %), skipped for a source switch. Launched
    // item uses the widget percent (first load); a switched item uses its own
    // per-episode store percent. The widget percent is an EXPLICIT promise ∫w^~)ﬁt
    // the details-screen Resume button advertised this position"È›y¯ßy‘ so when
    // seekable it wins outright below (never silently overridden by local).
    double? traktPct;
    double? traktProviderPct;
    double? simklProviderPct;
    double? mdblistProviderPct;
    var explicitLaunch = false;
    if (!preferLocalResume &&
        trackingPolicy.progressFrom(TrackingSource.trakt)) {
      final launchPct = firstLoad ? widget.traktProgressPercent : null;
      if (launchPct != null) {
        traktPct = launchPct;
        traktProviderPct = launchPct;
        explicitLaunch = true;
      } else {
        traktPct = await _currentEpisodeTraktPercent();
        traktProviderPct = traktPct;
      }
    }
    if (!preferLocalResume &&
        trackingPolicy.progressFrom(TrackingSource.mdblist)) {
      final explicitMdblistPct = mdblistFirstLoad
          ? widget.mdblistProgressPercent
          : null;
      final mdblistPct =
          explicitMdblistPct ?? await _currentEpisodeMdblistPercent();
      mdblistProviderPct = mdblistPct;
      if (mdblistPct != null && (traktPct == null || mdblistPct > traktPct)) {
        traktPct = mdblistPct;
        explicitLaunch = explicitMdblistPct != null;
      }
    }
    // Simkl candidate: the explicit launch promise on first load, otherwise
    // this episode's launch-time snapshot. Folded into the same candidate as
    // Trakt so the furthest remote progress wins.
    if (!preferLocalResume &&
        trackingPolicy.progressFrom(TrackingSource.simkl)) {
      final explicitSimklPct = simklFirstLoad
          ? widget.simklProgressPercent
          : null;
      final simklPct = explicitSimklPct ?? await _currentEpisodeSimklPercent();
      simklProviderPct = simklPct;
      if (simklPct != null && (traktPct == null || simklPct > traktPct)) {
        traktPct = simklPct;
        explicitLaunch = explicitSimklPct != null;
      }
    }
    final int traktMs =
        (traktPct != null &&
            traktPct > 0 &&
            traktPct < 100 &&
            dur > Duration.zero)
        ? (dur.inMilliseconds * traktPct / 100).floor()
        : 0;

    // Local candidate + speed/aspect restore (enhanced state preferred, else the
    // legacy resume store). Speed/aspect are restored regardless of the seek.
    int localMs = 0;
    final allowLocalResume =
        preferLocalResume || trackingPolicy.progressFrom(TrackingSource.local);
    final localMovieImdbId = _currentLocalMovieImdbId;
    final locallyFinishedMovie =
        !preferLocalResume &&
        localMovieImdbId != null &&
        await StorageService.isMovieFinished(localMovieImdbId);
    // Speed/aspect are device prefs riding in the resume record ∫w^~)ﬁt restore
    // them in EVERY progress mode; only the POSITION is a policy-gated
    // resume candidate.
    final state = locallyFinishedMovie
        ? null
        : await _getEnhancedPlaybackState() ??
              await StorageService.getVideoResume(_resumeKey);
    if (state != null) {
      if (allowLocalResume) {
        localMs = (state['positionMs'] ?? 0) as int;
      }
      final speed = (state['speed'] ?? 1.0) as double;
      final aspect = (state['aspect'] ?? 'contain') as String;
      if (speed != 1.0) {
        await _player.setRate(speed);
        _playbackSpeed = speed;
      }
      _aspectMode = AspectModeUtils.stringToAspectMode(aspect);
      await _applyAspectVideoZoom();
    }

    if (dur <= Duration.zero) return;

    // Source switch on the same content: come back EXACTLY where you were ∫w^~)ﬁt
    // no resumable-window gating (you might be 93% in, mid-credits), matching
    // the native TV player's source-switch semantics.
    if (preferLocalResume) {
      if (localMs > 0 && localMs < dur.inMilliseconds) {
        await _seekForResume(localMs, verifyLanding: verifyLanding);
      }
      return;
    }

    final loMs =
        VideoPlayerTimingConstants.minimumPlaybackPosition.inMilliseconds;
    final hiMs = (dur.inMilliseconds * 0.9).floor();
    // Legacy builds persisted Trakt watched history as if it were a local
    // completion. A current partial Trakt session is a rewatch, so that stale
    // completed position must not force a fresh start. Keep this migration
    // in-memory; the old record has no provenance and may be genuine local
    // history. Independent Simkl/MDBList completion still wins.
    if (localMs >= hiMs) {
      // The rewatch detector consumes the same policy-masked inputs as guide
      // rendering (ticks AND partials both follow the Progress source since
      // 2026-08-27)"È›y¯ßy‘ a non-selected provider's session can't un-tick local
      // completion.
      traktProviderPct ??= await _currentEpisodeTraktPercent(forGuide: true);
      simklProviderPct ??= await _currentEpisodeSimklPercent(forGuide: true);
      mdblistProviderPct ??= await _currentEpisodeMdblistPercent(
        forGuide: true,
      );
      if (hasActiveTraktEpisodeRewatch(
        traktPercent: traktProviderPct,
        simklPercent: simklProviderPct,
        mdblistPercent: mdblistProviderPct,
      )) {
        localMs = 0;
      }
    }
    // The details-screen Resume promised THIS position+ßuÁ‚ùÁT honour it outright when
    // seekable (matching the pre-rework launched-item behaviour), even over a
    // deeper/stale local. An unseekable promise falls through to furthest-wins.
    if (explicitLaunch && traktMs > loMs && traktMs < hiMs) {
      debugPrint('Resume: explicit tracker percent -> ${traktMs}ms');
      await _seekForResume(traktMs, verifyLanding: verifyLanding);
      return;
    }
    // FURTHEST-WATCHED WINS: seek the deeper of the local position and the Trakt
    // percent, provided it's in the resumable window (past the first 2s, before
    // the last 10%). If neither qualifies, start fresh.
    // Locally FINISHED (past the 90% cutoff on this device): start fresh, and
    // never let a shallower/stale Trakt percent yank a restarted episode into
    // its middle+ßuÁ‚ùÁT local IS the furthest position, it's just not seekable.
    if (localMs >= hiMs && localMs > 0) return;
    final traktCand = (traktMs > loMs && traktMs < hiMs) ? traktMs : 0;
    final localCand = (localMs > loMs && localMs < hiMs) ? localMs : 0;
    final target = traktCand > localCand ? traktCand : localCand;
    if (target > 0) {
      debugPrint(
        'Resume: furthest of remote=${traktMs}ms local=${localMs}ms -> ${target}ms',
      );
      await _seekForResume(target, verifyLanding: verifyLanding);
    }
  }

  /// Single exit for every resume seek: arms the write guard so a seek that
  /// never lands cannot have its own bookmark overwritten, and"È›y¯ßy‘ on the startup
  /// path only"È›y¯ßy‘ confirms the position actually moved.
  ///
  /// [verifyLanding] is opt-in because only the startup path seeks into a
  /// stream the gate committed after ~40ms of decoded media. mpv can answer
  /// that seek by restarting the remote stream at 0 (observed on a debrid link
  /// via the pinned-source ladder), which leaves playback at the beginning with
  /// no error to react to. Re-issuing once, after the stream has warmed up,
  /// recovers it. Mid-session seeks (source switch, episode change) already run
  /// against a settled stream and keep their existing single-shot behaviour.
  Future<void> _seekForResume(
    int targetMs, {
    bool verifyLanding = false,
  }) async {
    // Never GUARD a near-finished target (∫w^~)ﬁu80% of a known duration"È›y¯ßy‘ the
    // trackers' stop-scrobble threshold, below the 90% local finished cutoff):
    // substituting one would scrobble a watched mark and store a finished-
    // looking position for content that may be playing at 0:00. The seek
    // itself still happens; such a start just plays unguarded.
    final durMs = _duration.inMilliseconds;
    final nearFinished = durMs > 0 && targetMs >= (durMs * 0.8).floor();
    if (nearFinished) {
      _resumeWriteGuard.clear();
    } else {
      _resumeWriteGuard.arm(targetMs);
    }
    final target = Duration(milliseconds: targetMs);
    await _player.seek(target);
    // Without an armed guard the verifier would abort on its first check.
    if (!verifyLanding || nearFinished) return;
    // Deliberately NOT awaited: the caller is the startup chain, and the
    // "Checking streanÈ›y¯ßy÷" gate does not come down until it returns. Blocking
    // here would hold that overlay over the video for the whole verification
    // window on exactly the runs that already went wrong.
    unawaited(_verifyResumeLanding(targetMs, _resumeVerifyEpoch));
  }

  /// Confirms a startup resume seek took, re-issuing it once if it did not.
  ///
  /// Aborts the moment its media stops being current+ßuÁ‚ùÁT [epoch] changed (item
  /// change, source switch), the guard stopped pointing at [targetMs] (user
  /// seek), or the position reached the target"È›y¯ßy‘ so a late retry can never
  /// yank playback away from where the user put it or seek a replacement
  /// stream it was never watching.
  Future<void> _verifyResumeLanding(int targetMs, int epoch) async {
    // A viewer who sees playback start from 0 decides "broken" within a couple
    // of seconds ∫w^~)ﬁt a single retry after 5s (the first version of this) lost
    // the race against the user's own quit on the observed phone repro. Check
    // early and re-issue up to three times: the first retry catches the common
    // case (mpv restarted a barely-warmed debrid stream at 0), the later ones
    // land on a progressively warmer stream. Every cycle keeps the same abort
    // conditions, so a user seek, item change, or dispose stops it instantly.
    const waits = [
      Duration(milliseconds: 1500),
      Duration(milliseconds: 1500),
      Duration(seconds: 3),
    ];
    for (var attempt = 0; attempt < waits.length; attempt++) {
      if (await _resumeSeekLanded(targetMs, epoch, timeout: waits[attempt])) {
        return;
      }
      if (!mounted || _screenDisposed) return;
      if (epoch != _resumeVerifyEpoch) return;
      if (_resumeWriteGuard.pendingTargetMs != targetMs) return;
      debugPrint(
        'Resume: seek did not land '
        '(position=${_player.state.position.inMilliseconds}ms '
        'target=${targetMs}ms)"È›y¯ßy‘ re-issuing (${attempt + 1}/${waits.length})',
      );
      await _player.seek(Duration(milliseconds: targetMs));
    }
    if (await _resumeSeekLanded(targetMs, epoch)) return;
    // Still adrift: leave playback where it is rather than fighting the stream.
    // The write guard keeps the stored resume point intact either way.
    debugPrint(
      'Resume: seek still unlanded after retries"È›y¯ßy‘ leaving playback in place',
    );
  }

  /// Polls for the resume target within a bounded window. Landing is judged
  /// with the same tolerance the write guard uses, since a seek resolves to the
  /// nearest keyframe rather than the exact millisecond.
  ///
  /// Returns true for "stop verifying", which covers landing as well as the
  /// cases where the target stopped being ours: the screen went away, the
  /// epoch moved on, the user seeked, or another item loaded.
  Future<bool> _resumeSeekLanded(
    int targetMs,
    int epoch, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const interval = Duration(milliseconds: 200);
    // mpv can MASK a seek: it reports the target position for a moment, then
    // a cold debrid stream answers the actual seek by restarting at 0+ßuÁ‚ùÁT the
    // observed "seekbar at halfway for a few ms" phone repro. A single
    // position reading is therefore worthless as landing proof: require the
    // position to still be at the target after a beat, or keep watching.
    const confirmDelay = Duration(milliseconds: 800);
    bool atTarget() =>
        _player.state.position.inMilliseconds >=
        targetMs - _resumeWriteGuard.toleranceMs;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted || _screenDisposed) return true;
      if (epoch != _resumeVerifyEpoch) return true;
      if (_resumeWriteGuard.pendingTargetMs != targetMs) return true;
      if (atTarget()) {
        await Future<void>.delayed(confirmDelay);
        if (!mounted || _screenDisposed) return true;
        if (epoch != _resumeVerifyEpoch) return true;
        if (_resumeWriteGuard.pendingTargetMs != targetMs) return true;
        if (atTarget()) return true;
        debugPrint(
          'Resume: landing was transient (masked seek unwound to '
          '${_player.state.position.inMilliseconds}ms)+ßuÁ‚ùÁT still watching',
        );
        continue;
      }
      await Future<void>.delayed(interval);
    }
    return false;
  }

  /// Get enhanced playback state for current content
  Future<Map<String, dynamic>?> _getEnhancedPlaybackState() async {
    try {
      final seriesPlaylist = _seriesPlaylist;
      if (seriesPlaylist != null && seriesPlaylist.isSeries) {
        // For series, get the current episode info
        if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
          final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
            (episode) => episode.originalIndex == _currentIndex,
            orElse: () => seriesPlaylist.allEpisodes.first,
          );

          if (currentEpisode.seriesInfo.season != null &&
              currentEpisode.seriesInfo.episode != null) {
            // Catalog series follow IMDb + S/E across release-title aliases;
            // generic packs keep their exact title-keyed record.
            return LocalPlaybackResumeResolver.episode(
              seriesTitle: seriesPlaylist.seriesTitle ?? 'Unknown Series',
              season: currentEpisode.seriesInfo.season!,
              episode: currentEpisode.seriesInfo.episode!,
              imdbId: seriesPlaylist.imdbId ?? _effectiveContentImdbId,
              policy: widget.resumePolicy,
            );
          }
        }
      }

      PlaylistEntry? currentEntry;
      final activePlaylist = _activePlaylist;
      if (activePlaylist != null &&
          _currentIndex >= 0 &&
          _currentIndex < activePlaylist.length) {
        currentEntry = activePlaylist[_currentIndex];
      }

      // A lone series stream has no SeriesPlaylist, but its catalog S/E is
      // authoritative. Prefer the canonical episode record for catalog play;
      // generic playback retains its exact video/source lookup first.
      if (_effectiveContentType == 'series') {
        if (widget.resumePolicy == PlaybackResumePolicy.sourceSpecific &&
            currentEntry != null) {
          final exactVideo = await StorageService.getVideoPlaybackState(
            videoTitle: _resumeIdForEntry(currentEntry),
          );
          if (exactVideo != null) return exactVideo;
        }

        if (_effectiveContentSeason != null &&
            _effectiveContentEpisode != null) {
          final episodeState = await LocalPlaybackResumeResolver.episode(
            seriesTitle: _effectiveContentTitle ?? widget.title,
            season: _effectiveContentSeason!,
            episode: _effectiveContentEpisode!,
            imdbId: _effectiveContentImdbId,
            policy: widget.resumePolicy,
          );
          if (episodeState != null) return episodeState;
        }

        // Legacy single-episode launches may only have the mirrored video row.
        if (currentEntry != null) {
          return StorageService.getVideoPlaybackState(
            videoTitle: _resumeIdForEntry(currentEntry),
          );
        }
        final legacyTitle = widget.title.isNotEmpty
            ? widget.title
            : 'Unknown Video';
        return StorageService.getVideoPlaybackState(videoTitle: legacyTitle);
      }

      final resumeId = currentEntry != null
          ? _resumeIdForEntry(currentEntry)
          : ((_currentStremioTvContentTitle ?? widget.title).isNotEmpty
                ? (_currentStremioTvContentTitle ?? widget.title)
                : 'Unknown Video');
      // A multi-file movie/collection must keep an existing per-file bookmark
      // ahead of the one catalog IMDb bookmark. ExoPlayer already restricts
      // canonical movie resume to `_PlaybackContentType.single`; mirror that
      // boundary here while retaining the legacy IMDb fallback for unseen files.
      final isSingleLogicalMovie =
          activePlaylist == null || activePlaylist.length <= 1;
      final moviePolicy =
          widget.resumePolicy == PlaybackResumePolicy.catalogCanonical &&
              isSingleLogicalMovie
          ? PlaybackResumePolicy.catalogCanonical
          : PlaybackResumePolicy.sourceSpecific;
      debugPrint(
        'Resume Load: fetching state for resumeId=$resumeId '
        'policy=${moviePolicy.name}',
      );
      final videoState = await LocalPlaybackResumeResolver.movie(
        resumeId: resumeId,
        imdbId: _effectiveContentImdbId,
        policy: moviePolicy,
      );
      if (videoState != null) {
        debugPrint(
          'Resume Load: found state for resumeId=$resumeId '
          'updatedAt=${videoState['updatedAt']}',
        );
      }
      return videoState;
    } catch (e) {}
    return null;
  }

  bool _resumeSaveBlocked(bool debounced) {
    if (_validationGateActive || !_isReady) return true;
    // An IPTV zap flips _currentIptvIndex ∫w^~)ﬁt and therefore _resumeKey ∫w^~)ﬁt before
    // the incoming stream opens, while _position/_duration still describe the
    // OUTGOING one (_isReady is never cleared for the gap). A tick landing in
    // that window would file the old movie's position under the new channel's
    // key, which the Continue-watching shelf would then show as real progress.
    // Nothing is lost by skipping: the next tick saves once the switch lands.
    if (_effectiveIptvChannels != null && _isTransitioning) {
      return true;
    }

    // If this is a manual episode selection and it's been less than 30 seconds, skip saving
    // This gives the user time to seek to where they want
    if (_isManualEpisodeSelection && debounced) {
      return true;
    }
    return false;
  }

  Future<void> _saveResume({
    bool debounced = false,
    Duration? positionOverride,
  }) {
    // Check both when requested and after queueing. A save requested inside a
    // transition/validation guard must not become valid merely because an
    // older write kept it queued until the guard ended; conversely, a newly
    // started transition must suppress work which was waiting on the lock.
    if (_resumeSaveBlocked(debounced)) return Future<void>.value();
    // A periodic tick carries no unique intent. If any newer/older save owns
    // the lock, drop this tick instead of building an unbounded timer backlog.
    if (debounced && _resumeSaveLock.locked) return Future<void>.value();
    return _resumeSaveLock.synchronized(
      () => _saveResumeLocked(
        debounced: debounced,
        positionOverride: positionOverride,
      ),
    );
  }

  Future<void> _saveResumeLocked({
    required bool debounced,
    Duration? positionOverride,
  }) async {
    if (_resumeSaveBlocked(debounced)) return;

    var pos = positionOverride ?? _position;
    final dur = _duration;
    if (dur <= Duration.zero) {
      return;
    }

    // A resume seek was requested and playback is still nowhere near it: the
    // seek did not land, so the live position describes a stream that
    // restarted at the beginning. Filing it would destroy the very bookmark we
    // tried to resume from"È›y¯ßy‘ persist the REQUESTED target instead, which keeps
    // the bookmark where it was while still recording speed/aspect changes
    // made in the window (this is their only persistence route). The guard
    // self-releases once the seek lands, the user seeks, or they have watched
    // from here long enough for it to be their real position.
    if (!_resumeWriteGuard.allowsPersist(pos.inMilliseconds)) {
      // allowsPersist(false) implies an armed target.
      final heldTarget = _resumeWriteGuard.pendingTargetMs!;
      if (heldTarget >= dur.inMilliseconds) {
        // _duration mirrors mpv live and can briefly read short on a fresh
        // remote stream. Writing the target against that duration would store
        // a ∫w^~)ﬁu100% (finished-looking) position, so skip this tick entirely+ßuÁ‚ùÁT
        // including speed/aspect, which the next tick (or exit save) persists
        // once the duration settles. Deliberate trade: a rare few-second delay
        // beats a bookmark that reads as watched.
        return;
      }
      pos = Duration(milliseconds: heldTarget);
    }

    // Completion clears local movie resume/CW state. Do not let the autosave
    // tick immediately recreate that state while end credits keep playing.
    if (_currentMovieMarkedAsFinished && _currentLocalMovieImdbId != null) {
      return;
    }

    final aspectStr = AspectModeUtils.aspectModeToString(_aspectMode);
    // While the user is holding for temporary 2x boost, persist the prior speed
    // so a kill/dispose mid-hold doesn't strand 2x as the resume value.
    final persistedSpeed = _speedBeforeHold ?? _playbackSpeed;

    // Save to enhanced playback state system
    try {
      final seriesPlaylist = _seriesPlaylist;
      if (seriesPlaylist != null && seriesPlaylist.isSeries) {
        // For series content
        if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
          final currentEpisode = seriesPlaylist.allEpisodes.firstWhere(
            (episode) => episode.originalIndex == _currentIndex,
            orElse: () => seriesPlaylist.allEpisodes.first,
          );

          if (currentEpisode.seriesInfo.season != null &&
              currentEpisode.seriesInfo.episode != null) {
            await StorageService.saveSeriesPlaybackState(
              seriesTitle: seriesPlaylist.seriesTitle ?? 'Unknown Series',
              season: currentEpisode.seriesInfo.season!,
              episode: currentEpisode.seriesInfo.episode!,
              positionMs: pos.inMilliseconds,
              durationMs: dur.inMilliseconds,
              speed: persistedSpeed,
              aspect: aspectStr,
              imdbId: seriesPlaylist.imdbId ?? widget.contentImdbId,
            );
          }
        }
      } else {
        // For non-series content
        if (_activePlaylist != null && _activePlaylist!.isNotEmpty) {
          PlaylistEntry? currentEntry;
          if (_currentIndex >= 0 && _currentIndex < _activePlaylist!.length) {
            currentEntry = _activePlaylist![_currentIndex];
          }

          if (currentEntry != null) {
            final resumeId = _resumeIdForEntry(currentEntry);
            debugPrint(
              'Resume Save: storing state resumeId=$resumeId pos=${pos.inMilliseconds} dur=${dur.inMilliseconds}',
            );
            String currentVideoUrl = '';
            if (_currentStreamUrl != null && _currentStreamUrl!.isNotEmpty) {
              currentVideoUrl = _currentStreamUrl!;
            } else if (currentEntry.url.isNotEmpty) {
              currentVideoUrl = currentEntry.url;
            } else if (widget.videoUrl.isNotEmpty) {
              currentVideoUrl = widget.videoUrl;
            }

            await StorageService.saveVideoPlaybackState(
              videoTitle: resumeId,
              videoUrl: currentVideoUrl,
              positionMs: pos.inMilliseconds,
              durationMs: dur.inMilliseconds,
              speed: persistedSpeed,
              aspect: aspectStr,
              imdbId: widget.contentImdbId,
            );

            // ALSO save in collection format for playlist progress tracking
            // This allows the playlist screen to display progress indicators
            debugPrint(
              &È›y¯ßy€ßuÁ‚ùÁ~ Collection Save Check: seriesPlaylist=${seriesPlaylist != null}, seriesTitle="${seriesPlaylist?.seriesTitle}", isSeries=${seriesPlaylist?.isSeries}',
            );
            if (seriesPlaylist != null && seriesPlaylist.seriesTitle != null) {
              // Parse season/episode from filename for consistent progress tracking across view modes
              final seriesInfo = SeriesParser.parseFilename(currentEntry.title);
              final season = seriesInfo.season ?? 0;
              final episode = seriesInfo.episode ?? (_currentIndex + 1);

              await StorageService.saveSeriesPlaybackState(
                seriesTitle: seriesPlaylist.seriesTitle!,
                season: season, // Parsed from filename, fallback to 0
                episode: episode, // Parsed from filename, fallback to index
                positionMs: pos.inMilliseconds,
                durationMs: dur.inMilliseconds,
                speed: persistedSpeed,
                aspect: aspectStr,
                imdbId: seriesPlaylist.imdbId ?? widget.contentImdbId,
              );
              debugPrint(
                +ßuÁ‚ùÁE Collection Save: title="${seriesPlaylist.seriesTitle}" S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')} (index=$_currentIndex) filename="${currentEntry.title}"',
              );
            } else {
              debugPrint(
                &È›y¯ßy‹ Collection Save SKIPPED: seriesPlaylist is null or has no title',
              );
            }
          }
        } else {
          // Single video file (no playlist)
          // If it's a series episode (from Quick Play next episode), save as series state
          if (_effectiveContentType == 'series' &&
              _effectiveContentSeason != null &&
              _effectiveContentEpisode != null) {
            await StorageService.saveSeriesPlaybackState(
              seriesTitle: _effectiveContentTitle ?? widget.title,
              season: _effectiveContentSeason!,
              episode: _effectiveContentEpisode!,
              positionMs: pos.inMilliseconds,
              durationMs: dur.inMilliseconds,
              speed: persistedSpeed,
              aspect: aspectStr,
              imdbId: _effectiveContentImdbId,
            );
          } else {
            final currentUrl =
                (_currentStreamUrl != null && _currentStreamUrl!.isNotEmpty)
                ? _currentStreamUrl!
                : widget.videoUrl;
            final title = _currentStremioTvContentTitle ?? widget.title;
            final videoTitle = title.isNotEmpty ? title : 'Unknown Video';

            await StorageService.saveVideoPlaybackState(
              videoTitle: videoTitle,
              videoUrl: currentUrl,
              positionMs: pos.inMilliseconds,
              durationMs: dur.inMilliseconds,
              speed: persistedSpeed,
              aspect: aspectStr,
              imdbId: _effectiveContentImdbId,
            );
          }
        }
      }
    } catch (e) {}

    // Also save to legacy system for backward compatibility
    await StorageService.upsertVideoResume(
      _resumeKey,
      {
        'positionMs': pos.inMilliseconds,
        'speed': persistedSpeed,
        'aspect': aspectStr,
        'durationMs': dur.inMilliseconds,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      sourceId:
          _currentIptvChannel?.attributes['series_playlist_id'] ??
          _currentIptvChannel?.attributes['source_playlist_id'] ??
          _iptvGuideContextOverride?.sourceId ??
          widget.iptvSourceId,
    );

    // Explicit checkpoints (pause, settled seek, exit-adjacent saves) are the
    // handoff moments another device would resume from ∫w^~)ﬁt let sync flush now
    // instead of waiting out the playback coalescing window. The 6s autosave
    // tick stays on the throttled path.
    if (!debounced) {
      MainPageBridge.notifyPlaybackCheckpoint();
    }
  }

  /// True while the auto-hide poll is being held off by a scrub, a pause, a
  /// route or an overlay"È›y¯ßy‘ so the tick that finds the blocker gone can grant a
  /// full interval instead of hiding on the spot.
  bool _tvAutoHideBlocked = false;

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(VideoPlayerTimingConstants.controlsAutoHideDuration, () {
      if (!mounted) return;
      // Televisions dismiss the dock on INACTIVITY, the way an OTT transport
      // bar does, and only while something is actually playing. A paused TV
      // bar staying up is correct"È›y¯ßy‘ BACK is how you dismiss that one.
      if (PlatformUtil.isTelevision) {
        // Nothing on screen to dismiss+ßuÁ‚ùÁT let the timer lapse rather than
        // re-arming one that would poll forever behind a hidden bar.
        if (!_controlsVisible.value) return;
        // BLOCKED, not finished. A tracks/episodes sheet is a ROUTE: it takes
        // focus, and the bar would be excluded underneath it, leaving nothing
        // sane to focus when the sheet closes. A scrub owns the bar outright,
        // and a paused player is meant to keep it.
        //
        // Re-arm instead of returning: this is a one-shot Timer, so a bare
        // return SPENT it+ßuÁ‚ùÁT a scrub or a sheet lasting longer than the
        // interval meant the dock never auto-hid again for the rest of the
        // session. Re-arming makes the block a pause, not a cancellation.
        final route = ModalRoute.of(context);
        if (_tvScrubTarget != null ||
            !_isPlaying ||
            (route != null && !route.isCurrent) ||
            _anyPlayerOverlayOpen) {
          _tvAutoHideBlocked = true;
          _scheduleAutoHide();
          return;
        }
        if (_tvAutoHideBlocked) {
          // The blocker cleared somewhere inside the last poll. Start the
          // interval again from NOW: closing a sheet must not be met by a
          // countdown that already ran out behind it.
          _tvAutoHideBlocked = false;
          _scheduleAutoHide();
          return;
        }
        // Deliberately NOT gated on "focus is inside the bar". Raising the bar
        // always focuses Play/Pause, so that test is true for the entire life
        // of the bar and the timer could never fire ∫w^~)ﬁt the dock sat over
        // playing video until the user pressed BACK. Every key that reaches
        // the player and every bar action reschedules this timer, so what
        // actually elapses here is INACTIVITY, which is what an OTT dock
        // dismisses on. Route through _tvHideBar so focus leaves the bar
        // before it is excluded; setting the flag alone would strand the
        // remote on a node that no longer exists.
        _tvHideBar();
        return;
      }
      _controlsVisible.value = false;
    });
  }

  // ---- Television transport bar -------------------------------------------

  /// Raise the bar and put focus on Play/Pause (not the first button+ßuÁ‚ùÁT the
  /// control you want 90% of the time should be under the thumb already).
  void _tvShowBar() {
    _controlsVisible.value = true;
    // A fresh raise starts from a clean slate: a stale "was blocked" left over
    // from the previous time the bar was up would silently buy this one an
    // extra interval before it could hide.
    _tvAutoHideBlocked = false;
    _scheduleAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controlsVisible.value) return;
      // An open overlay owns the remote+ßuÁ‚ùÁT the bar must not pull focus out
      // from under it.
      if (_anyPlayerOverlayOpen) return;
      if (!_tvBarScope.hasFocus) _tvPlayPauseFocus.requestFocus();
    });
  }

  /// Lower the bar and take focus back to the player root. Without the second
  /// half the focused control is excluded from the tree and the remote dies.
  void _tvHideBar() {
    _controlsVisible.value = false;
    // With an overlay up, focus belongs to the overlay (its claim may still
    // be a frame away)+ßuÁ‚ùÁT grabbing the root here would strand its DPAD.
    if (!_anyPlayerOverlayOpen) _tvRootFocus.requestFocus();
  }

  /// Cinema scrub: hold LEFT/RIGHT to pause and preview a destination, OK to
  /// confirm, BACK/DOWN to cancel. One seek on confirm, so the trackers and
  /// resume see a single jump instead of a burst.
  void _tvScrubBegin(int direction) {
    if (_tvNoTimeline) return;
    _tvScrubStartedAtGeneration = _tvScrubGeneration;
    _tvScrubWasPlaying = _isPlaying;
    if (_isPlaying) _player.pause();
    _tvScrubTarget = _position;
    _tvShowBar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tvScrubTarget != null) _tvProgressFocus.requestFocus();
    });
    _tvScrubStep(direction);
  }

  void _tvScrubStep(int direction) {
    final base = _tvScrubTarget;
    if (base == null) return;
    // Accelerate with the hold: fine control at first, then long strides so a
    // two-hour remux is crossable without holding the key for a minute.
    final step = _tvScrubRepeats < 8
        ? 10
        : _tvScrubRepeats < 16
        ? 30
        : 60;
    _tvScrubRepeats++;
    final next = base + Duration(seconds: step * direction);
    setState(() {
      _tvScrubTarget = next < Duration.zero
          ? Duration.zero
          : (next > _duration ? _duration : next);
    });
    _scheduleAutoHide();
  }

  void _tvScrubCommit() {
    final target = _tvScrubTarget;
    // Captured when the scrub STARTED. Reading it here would always match and
    // the guard would never fire ∫w^~)ﬁt a scrub begun before a source switch would
    // happily seek whatever replaced it.
    final generation = _tvScrubStartedAtGeneration;
    if (target == null) return;
    setState(() => _tvScrubTarget = null);
    _tvScrubRepeats = 0;
    // A source switch or dispose bumps the generation; a confirm that lands
    // afterwards must not seek whatever replaced the item being scrubbed.
    if (generation != _tvScrubGeneration || !mounted) return;
    _player.seek(target);
    _traktScrobbleSeek(target);
    _simklScrobbleSeek(target);
    _mdblistScrobbleSeek(target);
    if (_tvScrubWasPlaying) _player.play();
    if (!_anyPlayerOverlayOpen) _tvPlayPauseFocus.requestFocus();
    // Fresh interval: the countdown that was running belonged to the scrub,
    // and inheriting its remainder could drop the bar the instant OK lands.
    _scheduleAutoHide();
  }

  /// Drop a scrub without seeking and without touching playback ∫w^~)ﬁt the item it
  /// belonged to is going away. Restoring "was playing" here would fight the
  /// transition, which drives play/pause itself.
  void _tvAbandonScrub() {
    if (_tvScrubTarget == null) return;
    _tvScrubTarget = null;
    _tvScrubRepeats = 0;
  }

  void _tvScrubCancel() {
    if (_tvScrubTarget == null) return;
    setState(() => _tvScrubTarget = null);
    _tvScrubRepeats = 0;
    if (_tvScrubWasPlaying) _player.play();
    if (!_anyPlayerOverlayOpen) _tvPlayPauseFocus.requestFocus();
    _scheduleAutoHide();
  }

  /// The television bar. Reuses every flag the touch call site already
  /// computes, so the two stay in step: live comes from the same
  /// zap-banner signal, sources/guide/record from the same capability checks.
  Widget _buildTvControls() {
    // Live means a live CHANNEL"È›y¯ßy‘ it decides which button set the dock shows.
    // `hideSeekbar` is a different thing entirely: Magic/Debrify TV sets it on
    // ordinary seekable VOD to hide the scrub bar, and treating it as live
    // stripped episodes, sources and speed from those sessions.
    final isLive = _iptvZapBannerOwnsIdentity;
    final hasSources =
        _effectiveSources != null &&
        _effectiveSources!.isNotEmpty &&
        (_effectiveResolver != null || widget.resolveSourceToPlaylist != null);
    final hasGuide =
        (_channelEntries.isNotEmpty && widget.requestChannelById != null) ||
        _hasStremioTvGuide;

    // BACK precedence, mounted with the bar so `canPop` is always current:
    // cancel a scrub, else close an overlay, else lower the bar, else leave the
    // player. Menu on tvOS arrives here rather than as a key event (measured),
    // so this+ßuÁ‚ùÁT not the key handler ∫w^~)ﬁt is what makes BACK behave.
    return PopScope(
      canPop:
          _tvScrubTarget == null &&
          !_controlsVisible.value &&
          !_anyPlayerOverlayOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        if (_tvScrubTarget != null) {
          _tvScrubCancel();
          return;
        }
        if (_anyPlayerOverlayOpen) {
          _closeTopPlayerOverlay();
          return;
        }
        if (_controlsVisible.value) _tvHideBar();
      },
      child: TvControlsScope(
        seek: (target) {
          _player.seek(target);
          _traktScrobbleSeek(target);
          _simklScrobbleSeek(target);
          _mdblistScrobbleSeek(target);
          _scheduleAutoHide();
        },
        // `_` on purpose: `context` inside must keep resolving to the State's
        // context, exactly as before this wrapper existed"È›y¯ßy‘ sheet callbacks
        // like _showTracksSheet await before using it, and the Builder's own
        // element dies whenever the controls subtree is dropped (PiP,
        // not-ready), which the State's context survives.
        child: Builder(
          builder: (_) {
            final showIdentity =
                widget.showVideoTitle && !widget.showChannelName;
            final titleInfo = showIdentity
                ? _getCurrentEpisodeTitleInfo()
                : null;
            return TvControls(
              title: titleInfo?.title ?? '',
              titleIsClean: titleInfo?.fetched ?? false,
              subtitle: showIdentity ? _getCurrentEpisodeSubtitle() : null,
              infoPanel:
                  _buildIptvInfoPanel(flush: true) ??
                  _buildDebrifyTvInfoPanel(flush: true),
              clock: _playbackUiClock,
              isPlaying: _isPlaying,
              isLive: isLive,
              isTransitioning: _isTransitioning,
              scopeNode: _tvBarScope,
              playPauseFocusNode: _tvPlayPauseFocus,
              progressFocusNode: _tvProgressFocus,
              // Dead controls are never focusable: a live stream or an unknown
              // duration has nothing to scrub, so traversal skips the row entirely
              // rather than parking the remote on it.
              progressFocusable: !_tvNoTimeline,
              // OK is claimed by the dock's own buttons, so those presses never
              // reach _handleTvKey and never restarted the countdown.
              onInteract: _scheduleAutoHide,
              scrubPreview: _tvScrubTarget,
              onPlayPause: _togglePlay,
              onShowTracks: () => _showTracksSheet(context),
              onSpeed: _onSpeedButton,
              onAspect: _onAspectButton,
              onSleepTimer: _showSleepTimerSheet,
              sleepTimerLabel: _sleepTimerButtonLabel,
              speed: _playbackSpeed,
              aspectMode: _aspectMode,
              hideOptions: widget.hideOptions,
              onNext: _hasIptvNext
                  ? () => _switchToIptvChannel(_currentIptvIndex + 1)
                  : _canZapIptvChannel
                  ? () => _zapIptvChannel(1)
                  : (_hasAnyNext ? _goToNextEpisode : null),
              onPrevious: _hasIptvPrevious
                  ? () => _switchToIptvChannel(_currentIptvIndex - 1)
                  : _canZapIptvChannel
                  ? () => _zapIptvChannel(-1)
                  : (_hasPreviousEpisode() ? _goToPreviousEpisode : null),
              onNextChannel: widget.requestNextChannel != null
                  ? _goToNextChannel
                  : null,
              onShowPlaylist:
                  (_activePlaylist != null && _activePlaylist!.isNotEmpty) ||
                      _canFetchEpisodes
                  ? () => _showPlaylistSheet(context)
                  : null,
              onRandom:
                  _effectiveIptvChannels == null &&
                      ((_activePlaylist?.isNotEmpty ?? false) ||
                          _canFetchEpisodes)
                  ? () => unawaited(_showRandomPlaybackMenu())
                  : null,
              onShowSources: hasSources ? _showSourceSheetOverlay : null,
              onShowGuide: hasGuide
                  ? (_channelEntries.isNotEmpty &&
                            widget.requestChannelById != null
                        ? _showChannelGuideOverlay
                        : _showStremioTvGuideOverlay)
                  : null,
              onShowIptvChannels: _effectiveIptvChannels?.isNotEmpty == true
                  ? _showIptvChannelSheetOverlay
                  : null,
              hasRecord: _canRecord,
              isRecording: _recordingActiveNow,
              onRecord: _canRecord ? _toggleRecording : null,
              onLiveEdgeAction: _iptvLiveEdgeAction,
              liveEdgeActionActive: _iptvStartOverActive,
              liveEdgeActionLoading: _iptvStartOverLoading,
              onToggleStartOverTimeline: _iptvStartOverActive
                  ? _toggleIptvStartOverTimeline
                  : null,
              startOverTimelineVisible: _iptvStartOverTimelineVisible,
            );
          },
        ),
      ),
    );
  }

  /// Any of the player's in-route overlays. They are not routes, so BACK has to
  /// close them explicitly or it would pop the whole player instead.

  /// Lets BACK reach the IPTV guide's own contract: from the schedule pane it
  /// returns to the channel pane, and closing restores the category an
  /// unfinished all-category search interrupted. On tvOS the Menu press never
  /// reaches the sheet as a key, so the host has to hand it over.
  final GlobalKey<IptvChannelSheetState> _iptvSheetKey =
      GlobalKey<IptvChannelSheetState>();

  /// True once, for the tail of the very BACK press that closed an overlay.
  ///
  /// Driven by an explicit signal from the overlay rather than a clock: a close
  /// by OK, tap or selection must not swallow the user's next deliberate BACK,
  /// which a pure time window did.
  bool get _overlayJustClosed => TvOverlayBack.consume();

  bool get _anyPlayerOverlayOpen =>
      _showSyncOverlay ||
      _showChannelGuide ||
      _showIptvChannelSheet ||
      _showSourceSheet ||
      _showStremioTvGuide ||
      _showPlayerMenu;

  /// Closes the topmost overlay and returns focus to the player root, which the
  /// individual hide methods do not do on their own.
  void _closeTopPlayerOverlay() {
    if (_showPlayerMenu) {
      // Delegate: BACK inside the menu walks values -> rail before closing
      // (tvOS Menu arrives here via PopScope, never as a key).
      if (_playerMenuKey.currentState?.handleHostBack() != true) {
        _hidePlayerMenu();
      }
      // Still open means the press was spent on a pane change.
      if (_showPlayerMenu) return;
    } else if (_showSyncOverlay) {
      _hideSyncOverlay();
    } else if (_showChannelGuide) {
      _hideChannelGuideOverlay();
    } else if (_showIptvChannelSheet) {
      // Delegate: the guide's own back walks schedule -> channels first, and
      // its close restores a search-interrupted category.
      if (_iptvSheetKey.currentState?.handleHostBack() != true) {
        _hideIptvChannelSheet();
      }
      // It may still be open (pane change rather than close). Taking focus to
      // the player root would leave its DPAD dead.
      if (_showIptvChannelSheet) return;
    } else if (_showSourceSheet) {
      _hideSourceSheet();
    } else if (_showStremioTvGuide) {
      _hideStremioTvGuide();
    } else {
      return;
    }
    if (PlatformUtil.isTelevision) _tvRootFocus.requestFocus();
  }

  /// Opens whichever guide this session actually has, in the order the dock
  /// offers them. Returns false when there is none, so the caller can fall back
  /// to raising the transport bar.
  bool _openTvGuide() {
    if (_channelEntries.isNotEmpty && widget.requestChannelById != null) {
      _showChannelGuideOverlay();
      return true;
    }
    if (_hasStremioTvGuide) {
      _showStremioTvGuideOverlay();
      return true;
    }
    if (_effectiveIptvChannels?.isNotEmpty == true) {
      _showIptvChannelSheetOverlay();
      return true;
    }
    return false;
  }

  /// Returns null to let the desktop mapping below handle the key.
  KeyEventResult? _handleTvKey(LogicalKeyboardKey key) {
    // Not const: LogicalKeyboardKey overrides ==, which a const set forbids.
    // The Siri Remote's click pad arrives as `enter` (measured on device);
    // `select`/`gameButtonA` cover Android TV remotes and game controllers.
    final activate = <LogicalKeyboardKey>{
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    final isLeft = key == LogicalKeyboardKey.arrowLeft;
    final isRight = key == LogicalKeyboardKey.arrowRight;
    final isBack =
        key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack;

    // A scrub in flight owns the remote completely.
    if (_tvScrubTarget != null) {
      if (isLeft || isRight) {
        _tvScrubStep(isRight ? 1 : -1);
      } else if (activate.contains(key)) {
        _tvScrubCommit();
      } else if (isBack || key == LogicalKeyboardKey.arrowDown) {
        _tvScrubCancel();
      }
      return KeyEventResult.handled;
    }

    // Nothing is actionable until the first frame, and acting during a
    // transition would drive the OUTGOING item.
    // Nothing is actionable before the first frame, and during a switch most
    // actions would drive the OUTGOING item. Two exceptions, both deliberate:
    // BACK must always get you out (a tune can hang on the network), and
    // LEFT/RIGHT must still zap, because a newer switch is allowed to
    // supersede a slow one (_iptvSwitchTicket).
    if (!_isReady || _isTransitioning) {
      if (isBack) return null;
      // Zap directly rather than falling through: the mapping below only zaps
      // when the bar is hidden, so with it up the press would reach the seek
      // branch and seek the OUTGOING item.
      if ((isLeft || isRight) && _canZapIptvChannel) {
        _zapIptvChannel(isRight ? 1 : -1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (!_controlsVisible.value) {
      if (activate.contains(key)) {
        // While a skip is offered it owns OK: the button is on screen naming
        // the action, and it lives outside the bar's focus scope so the remote
        // has no other way to reach it.
        if (_activeSkipSegment != null) {
          _skipActiveSegment();
          return KeyEventResult.handled;
        }
        // Native TV player: OK both toggles playback and raises the bar.
        _togglePlay();
        _tvShowBar();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _tvShowBar();
        return KeyEventResult.handled;
      }
      // UP opens the guide, matching the native TV player. The desktop mapping
      // below only knows the Debrify-TV and Stremio guides, so on an IPTV
      // session it fell through to volume and UP appeared dead.
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_openTvGuide()) return KeyEventResult.handled;
        _tvShowBar();
        return KeyEventResult.handled;
      }
      if ((isLeft || isRight) && _tvNoTimeline) {
        // No timeline to move along. Hand the key down ONLY when the mapping
        // below has something real to do with it+ßuÁ‚ùÁT zapping to the next
        // channel. Falling through unconditionally reached the generic 10s
        // seek, which on a live stream is a blind jump on a rolling window and
        // on a `hideSeekbar` session is exactly the seek that session turned
        // off. And never enter a scrub whose progress row is hidden.
        return _canZapIptvChannel ? null : KeyEventResult.handled;
      }
      if ((isLeft || isRight) && !_canZapIptvChannel) {
        // Repeats arriving in quick succession mean the key is held; the third
        // one enters scrub. Slower taps stay 10s nudges, so a single press
        // still does the obvious thing.
        final now = DateTime.now();
        final last = _tvLastArrowAt;
        _tvScrubRepeats =
            (last != null && now.difference(last).inMilliseconds < 400)
            ? _tvScrubRepeats + 1
            : 0;
        _tvLastArrowAt = now;
        if (_tvScrubRepeats >= 2 && _duration > Duration.zero) {
          _tvScrubRepeats = 0;
          _tvScrubBegin(isRight ? 1 : -1);
          return KeyEventResult.handled;
        }
      }
      // UP keeps its existing precedence (channel guide, Stremio guide) and
      // LEFT/RIGHT fall through to zap-or-seek, both already below.
      return null;
    }

    // Bar up: it owns the DPAD and OK.
    if (isBack) {
      _tvHideBar();
      return KeyEventResult.handled;
    }
    if ((isLeft || isRight) && _tvProgressFocus.hasFocus) {
      if (!_tvNoTimeline) {
        _tvScrubBegin(isRight ? 1 : -1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled; // nothing to scrub; don't fall through
    }
    _scheduleAutoHide();
    // Traversal and activation belong to the bar's own focus tree.
    return KeyEventResult.ignored;
  }

  void _toggleControls() {
    _controlsVisible.value = !_controlsVisible.value;
    if (_controlsVisible.value) {
      _scheduleAutoHide();
      // Identity rides IN the bar (IPTV zap panel / Debrify TV banner both
      // embed as the dock's info panel), so nothing floats when it rises.
    }
  }

  /// Adopt [channel] as the banner's subject and start its guide lookup.
  ///
  /// Called on the first tune and on every zap, whatever is on screen at the
  /// time: the dock can be opened minutes later and must find the panel's
  /// data already loaded.
  void _prepareIptvBannerData(IptvChannel channel) {
    if (!mounted || !channel.isLive) return;
    final ticket = ++_iptvZapEpgTicket;
    // Whatever the guide already knows paints immediately; the fetch below
    // only ever upgrades it.
    final known = IptvEpgService.instance.peekNowNext(channel.url);
    setState(() {
      _iptvZapChannel = channel;
      _iptvZapEpg = known;
      _iptvZapEpgLoading = known == null;
      _iptvZapClock = DateTime.now();
    });
    // Even with an immediate XMLTV answer, the playing Xtream channel needs
    // one archive-aware upgrade: XMLTV has titles/times but no has_archive.
    unawaited(_loadIptvZapBannerEpg(channel, ticket));
    // Zapping from VOD to live with the dock already open gives the panel its
    // first channel here rather than at raise time+ßuÁ‚ùÁT start its clock.
    _syncIptvBannerTicker();
  }

  /// Float the banner over bare video and let it fade itself out.
  void _raiseIptvZapBanner() {
    if (!mounted || _iptvZapChannel == null) return;
    // Anything the user deliberately opened keeps the frame. The dock is the
    // exception it used to share this strip with: it now carries the same
    // panel itself, so there is nothing to raise over it.
    if (_showIptvChannelSheet ||
        _showSourceSheet ||
        _showChannelGuide ||
        _controlsVisible.value) {
      return;
    }
    setState(() {
      _showIptvZapBanner = true;
      _iptvZapFloatingMounted = true;
    });
    _iptvZapHideTimer?.cancel();
    _iptvZapHideTimer = Timer(
      const Duration(milliseconds: 4500),
      _hideIptvZapBanner,
    );
    _syncIptvBannerTicker();
  }

  void _onControlsVisibilityChanged() {
    _syncPlaybackClockVisibility();
    // The dock carries its own copy of the panel, so the floating one goes the
    // instant the dock opens. Fading it would cross-dissolve two copies of the
    // same panel at two different heights.
    if (_controlsVisible.value) {
      _hideIptvZapBanner(immediate: true);
      _hideDebrifyBanner(immediate: true);
      // The Record button is about to be looked at ∫w^~)ﬁt make sure it reflects
      // engine captures stopped from the notification (which this screen
      // otherwise never hears about).
      if (_engineFlagOn) unawaited(_refreshEngineRecordingState());
    }
    // Return focus to the player root whenever the bar goes down, so the
    // remote is never left pointing at a control that has just been excluded
    // from the tree.
    if (PlatformUtil.isTelevision) {
      // Not while an overlay is up: the source / guide / channel sheets
      // autofocus their own KeyboardListener and drive a virtual focus index,
      // so taking focus back here would leave them unable to see any keys.
      if (!_controlsVisible.value &&
          _tvBarScope.hasFocus &&
          !_anyPlayerOverlayOpen) {
        _tvRootFocus.requestFocus();
      }
    }
    _syncIptvBannerTicker();
  }

  /// [immediate] skips the fade and unmounts in the same frame ∫w^~)ﬁt for a handoff
  /// to the dock's copy, where a fade would show both at once.
  void _hideIptvZapBanner({bool immediate = false}) {
    _iptvZapHideTimer?.cancel();
    _iptvZapHideTimer = null;
    final live = _showIptvZapBanner || (immediate && _iptvZapFloatingMounted);
    if (mounted && live) {
      setState(() {
        _showIptvZapBanner = false;
        if (immediate) _iptvZapFloatingMounted = false;
      });
    }
    _syncIptvBannerTicker();
  }

  /// The panel's clock only has to run while the panel is on screen ∫w^~)ﬁt in
  /// either home. Without it the countdown and the elapsed rule sit frozen,
  /// which is most obvious exactly where the dock is used: while paused,
  /// where the position stream has stopped driving rebuilds.
  void _syncIptvBannerTicker() {
    final onScreen =
        _iptvZapChannel != null &&
        (_showIptvZapBanner ||
            (_controlsVisible.value && _iptvZapBannerOwnsIdentity));
    if (!onScreen) {
      _iptvZapTicker?.cancel();
      _iptvZapTicker = null;
      return;
    }
    if (_iptvZapTicker != null) return;
    _iptvZapTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _iptvZapClock = DateTime.now());
      _refreshIptvBannerEpgIfEnded();
    });
  }

  /// The dock can stay open past the end of the programme it is describing.
  /// Re-ask once the current one has finished rather than leave a listing
  /// that is quietly wrong.
  DateTime? _iptvArchiveRetryAt;

  void _refreshIptvBannerEpgIfEnded() {
    if (_iptvZapEpgLoading) return;
    final channel = _iptvZapChannel;
    final current = _iptvZapEpg?.now;
    if (channel == null || current == null) return;
    final retryArchive =
        !current.hasArchive &&
        _iptvArchiveRetryAt != null &&
        !DateTime.now().isBefore(_iptvArchiveRetryAt!);
    if (current.stop.isAfter(DateTime.now()) && !retryArchive) return;
    final ticket = ++_iptvZapEpgTicket;
    setState(() => _iptvZapEpgLoading = true);
    unawaited(_loadIptvZapBannerEpg(channel, ticket));
  }

  /// The same lazy now/next fetch the guide rows use. [ticket] is the banner's
  /// generation: a zap that lands mid-flight owns the banner, so a late answer
  /// for the previous channel is dropped rather than painted under the new
  /// channel's name.
  Future<void> _loadIptvZapBannerEpg(IptvChannel channel, int ticket) async {
    EpgNowNext? result;
    try {
      result = await IptvEpgService.instance.nowNextWithCatchupMetadata(
        channel.url,
      );
    } catch (_) {
      result = null;
    }
    if (!mounted || ticket != _iptvZapEpgTicket) return;
    _iptvArchiveRetryAt = DateTime.now().add(const Duration(seconds: 60));
    setState(() {
      _iptvZapEpg = result;
      _iptvZapEpgLoading = false;
    });
  }

  Future<void> _handleDoubleTap(TapDownDetails details) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final localPos = details.localPosition;
    // Avoid edge conflicts with system back gesture by requiring a margin
    const edgeGuard = 24.0;
    if (localPos.dx < edgeGuard || localPos.dx > size.width - edgeGuard) return;
    // If controls visible, ignore double-taps near top/bottom bars to not clash with buttons/slider
    if (_controlsVisible.value) {
      const topBar = 72.0;
      final bottomBar = _dockBand(72.0);
      if (localPos.dy < topBar || localPos.dy > size.height - bottomBar) return;
    }

    // Default seek behavior for left/right taps
    final isLeft = localPos.dx < size.width / 2;
    final delta = VideoPlayerTimingConstants.seekDelta;
    final target = _position + (isLeft ? -delta : delta);
    final minPos = Duration.zero;
    final maxPos = _duration;
    final clamped = target < minPos
        ? minPos
        : (target > maxPos ? maxPos : target);
    await _player.seek(clamped);
    _traktScrobbleSeek(clamped);
    _simklScrobbleSeek(clamped);
    _mdblistScrobbleSeek(clamped);
    _ripple = DoubleTapRipple(
      center: localPos,
      icon: isLeft ? Icons.replay_10_rounded : Icons.forward_10_rounded,
    );
    setState(() {});
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _ripple = null);
    });
  }

  void _onPanStart(DragStartDetails details) async {
    // If controls are visible, ignore pans that begin within top/bottom bars so buttons and slider work unaffected
    _panIgnore = false;
    if (_controlsVisible.value) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final size = box.size;
        const topBar = 72.0;
        final bottomBar = _dockBand(72.0);
        final dy = details.localPosition.dy;
        if (dy < topBar || dy > size.height - bottomBar) {
          _panIgnore = true;
          return;
        }
      }
    }
    _gestureStartPosition = details.localPosition;
    _gestureStartVideoPosition = _position;
    _gestureStartVolume = (_player.state.volume / 100.0).clamp(0.0, 1.0);
    _gestureStartBrightness = await PlayerDisplayControls.instance.brightness();
    if (!mounted) return;
    _mode = GestureMode.none;
    _verticalHud.value = null;
    _seekHud.value = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panIgnore) return;
    final dx = details.localPosition.dx - _gestureStartPosition.dx;
    final dy = details.localPosition.dy - _gestureStartPosition.dy;
    final absDx = dx.abs();
    final absDy = dy.abs();
    final size = (context.findRenderObject() as RenderBox).size;

    // Decide mode on first significant movement
    if (_mode == GestureMode.none) {
      if (absDx > 12 && absDx > absDy) {
        _mode = GestureMode.seek;
      } else if (absDy > 12) {
        final isLeftHalf = _gestureStartPosition.dx < size.width / 2;
        if (isLeftHalf && !PlayerDisplayControls.supportsBrightness) return;
        _mode = isLeftHalf ? GestureMode.brightness : GestureMode.volume;
      }
    }

    if (_mode == GestureMode.seek) {
      final duration = _duration;
      if (duration == Duration.zero) return;
      // Map horizontal delta to seconds, proportional to width
      final totalSeconds = duration.inSeconds.toDouble();
      final seekSeconds = (dx / size.width) * math.min(120.0, totalSeconds);
      var newPos =
          _gestureStartVideoPosition + Duration(seconds: seekSeconds.round());
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > duration) newPos = duration;
      _seekHud.value = SeekHudState(
        target: newPos,
        base: _position,
        isForward: newPos >= _position,
      );
    } else if (_mode == GestureMode.volume) {
      var newVol = (_gestureStartVolume - dy / size.height).clamp(0.0, 1.0);
      _player.setVolume((newVol * 100).clamp(0.0, 100.0));
      _verticalHud.value = VerticalHudState(
        kind: VerticalKind.volume,
        value: newVol,
      );
    } else if (_mode == GestureMode.brightness) {
      var newBright = (_gestureStartBrightness - dy / size.height).clamp(
        0.0,
        1.0,
      );
      unawaited(PlayerDisplayControls.instance.setBrightness(newBright));
      _verticalHud.value = VerticalHudState(
        kind: VerticalKind.brightness,
        value: newBright,
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_panIgnore) return;
    if (_mode == GestureMode.seek && _seekHud.value != null) {
      final target = _seekHud.value!.target;
      _player.seek(target);
      _traktScrobbleSeek(target);
      _simklScrobbleSeek(target);
      _mdblistScrobbleSeek(target);
    }
    _mode = GestureMode.none;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _seekHud.value = null;
        _verticalHud.value = null;
      }
    });
  }

  String _format(Duration d) => formatDuration(d);

  void _togglePlay() {
    if (!_isReady) return;
    if (_isPlaying) {
      _activeMediaUserPaused = true;
      _activeMediaShouldPlay = false;
      _player.pause();
      unawaited(_saveResume(positionOverride: _position));
    } else {
      // An explicit press is the one thing that clears a sleep stop.
      _sleepStopLatched = false;
      _activeMediaUserPaused = false;
      _activeMediaShouldPlay = true;
      _player.play();
    }
    _scheduleAutoHide();
  }

  /// Sets manual episode selection mode with automatic reset after 30 seconds
  void _setManualSelectionMode({bool allowResume = false}) {
    _isManualEpisodeSelection = true;
    _allowResumeForManualSelection = allowResume;
    _manualSelectionResetTimer?.cancel();
    _manualSelectionResetTimer = Timer(
      VideoPlayerTimingConstants.manualSelectionResetDuration,
      () {
        _isManualEpisodeSelection = false;
        _allowResumeForManualSelection = false;
      },
    );
  }

  void _cycleAspectMode() {
    AspectMode newMode;
    String modeName;
    IconData modeIcon;

    switch (_aspectMode) {
      case AspectMode.contain:
        newMode = AspectMode.cover;
        modeName = 'Cover';
        modeIcon = Icons.crop_free_rounded;
        break;
      case AspectMode.cover:
        newMode = AspectMode.fitWidth;
        modeName = 'Fit Width';
        modeIcon = Icons.fit_screen_rounded;
        break;
      case AspectMode.fitWidth:
        newMode = AspectMode.fitHeight;
        modeName = 'Fit Height';
        modeIcon = Icons.fit_screen_rounded;
        break;
      case AspectMode.fitHeight:
        newMode = AspectMode.aspect16_9;
        modeName = '16:9';
        modeIcon = Icons.aspect_ratio_rounded;
        break;
      case AspectMode.aspect16_9:
        newMode = AspectMode.aspect4_3;
        modeName = '4:3';
        modeIcon = Icons.aspect_ratio_rounded;
        break;
      case AspectMode.aspect4_3:
        newMode = AspectMode.aspect21_9;
        modeName = '21:9';
        modeIcon = Icons.aspect_ratio_rounded;
        break;
      case AspectMode.aspect21_9:
        newMode = AspectMode.aspect1_1;
        modeName = '1:1';
        modeIcon = Icons.crop_square_rounded;
        break;
      case AspectMode.aspect1_1:
        newMode = AspectMode.aspect3_2;
        modeName = '3:2';
        modeIcon = Icons.aspect_ratio_rounded;
        break;
      case AspectMode.aspect3_2:
        newMode = AspectMode.aspect5_4;
        modeName = '5:4';
        modeIcon = Icons.aspect_ratio_rounded;
        break;
      case AspectMode.aspect5_4:
        newMode = AspectMode.cinemaZoom;
        modeName = 'Cinema Zoom';
        modeIcon = Icons.zoom_in_map_rounded;
        break;
      case AspectMode.cinemaZoom:
        newMode = AspectMode.contain;
        modeName = 'Contain';
        modeIcon = Icons.crop_free_rounded;
        break;
    }

    setState(() {
      _aspectMode = newMode;
    });
    unawaited(_applyAspectVideoZoom());

    // Show elegant HUD feedback
    _aspectRatioHud.value = AspectRatioHudState(
      aspectRatio: modeName,
      icon: modeIcon,
    );

    // Auto-hide the HUD after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _aspectRatioHud.value = null;
      }
    });

    _scheduleAutoHide();
    _saveResume();
  }

  // 5£@ÅM±ïï¿Å—•µï»Ä÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç ÷ç †¢ÚÚÚvÜˆ∆R÷ñÁWFW2∆VgB¬&˜VÊFVBW6Úg&W6Ç3÷÷ñÁWFRFñ÷W"&VG2#3"‡¢ñÁBvWB˜6∆VWFñ÷W$÷ñÁWFW4∆VgB∞¢fñÊ¬FVF∆ñÊR“˜6∆VWFñ÷W$FVF∆ñÊS∞¢ñbÖ˜6∆VWFñ÷W$÷ˆFR“6∆VWFñ÷W$÷ˆFRÊ6˜VÁFF˜v‚«¬FVF∆ñÊR”“ÁV∆¬í∞¢&WGW&‚∞¢–¢fñÊ¬&V÷ñÊñÊr“FVF∆ñÊRÊFñffW&VÊ6RÑFFUFñ÷RÊÊ˜rÇííÊñ‰÷ñ∆∆ó6V6ˆÊG3∞¢ñbá&V÷ñÊñÊr√“í&WGW&‚∞¢&WGW&‚á&V÷ñÊñÊrÚcíÊ6Vñ¬Çì∞¢–†¢ÚÚÚ6Ü˜'B∆&V¬f˜"FÜR6ˆÁG&ˆ«2'WGFˆ‚¬˜"ÁV∆¬vÜV‚Ê˜FÜñÊró2&÷VB‡¢7G&ñÊsÚvWB˜6∆VWFñ÷W$'WGFˆ‰∆&V¬”‚7vóF6ÇÖ˜6∆VWFñ÷W$÷ˆFRí∞¢6∆VWFñ÷W$÷ˆFRÊˆfb”‚ÁV∆¬¿¢6∆VWFñ÷W$÷ˆFRÊVÊDˆdóFV“”‚tWó6ˆFRr¿¢6∆VWFñ÷W$÷ˆFRÊ6˜VÁFF˜v‚”‚rE˜6∆VWFñ÷W$÷ñÁWFW4∆VgB÷ñ‚r¿¢”∞†¢gWGW&S«fˆñC‚˜6Ü˜u6∆VWFñ÷W%6ÜVWBÇí7ñÊ2∞¢ñbÜµVÊñfñVE∆ñW$÷VÁTVÊ&∆VBí∞¢ˆ˜VÂ∆ñW$÷VÁUVñ6≤Ö∆ñW$÷VÁU6V7Fñˆ‚Á6∆VWì∞¢&WGW&„∞¢–¢ˆÜñFUFñ÷W#ÚÊ6Ê6V¬Çì∞¢fñÊ¬ñ6∂VB“vóB6∆VWFñ÷W%6ÜVWBÁ6Ü˜rÄ¢6ˆÁFWáB¿¢7W'&VÁC¢˜6∆VWFñ÷W$÷ˆFR¿¢&÷VD÷ñÁWFW3¢˜6∆VWFñ÷W$&÷VD÷ñÁWFW2¿¢÷ñÁWFW4∆VgC¢˜6∆VWFñ÷W$÷ñÁWFW4∆VgB¿¢ÚÚ∆ófR6ÜÊÊV¬Ü2ÊÚVÊBFÚ7F˜B¬6ÚˆÊ«íFÜR6˜VÁFF˜v‚∆ñW2.ù◊üäwù@¢ÚÚvÜñ6Çó2FÜR66RV˜∆R7GV∆«ívÁB6∆VWFñ÷W"f˜"‡¢∆∆˜tVÊDˆdóFV”¢ˆ7W'&VÁDóGd6ÜÊÊV√ÚÊó4∆ófR“G'VR¿¢ì∞¢ñbÇ÷˜VÁFVBí&WGW&„∞¢˜66ÜVGV∆TWFÙÜñFRÇì∞¢ñbáñ6∂VB”“ÁV∆¬í&WGW&„∞¢ˆ«ï6∆VWFñ÷W%6V∆V7Fñˆ‚áñ6∂VBì∞¢–†¢fˆñBˆ«ï6∆VWFñ÷W%6V∆V7Fñˆ‚Ö6∆VWFñ÷W%6V∆V7Fñˆ‚ñ6∂VBí∞¢7vóF6Çáñ6∂VBÊ÷ˆFRí∞¢66R6∆VWFñ÷W$÷ˆFRÊˆfc†¢ˆ6Ê6V≈6∆VWFñ÷W"Çì∞¢˜6Ü˜u6∆VWFñ÷W%Fˆ7BÇu6∆VWFñ÷W"ˆfbrì∞¢66R6∆VWFñ÷W$÷ˆFRÊ6˜VÁFF˜v„†¢˜7F'E6∆VW6˜VÁFF˜v‚áñ6∂VBÊ÷ñÁWFW2ì∞¢66R6∆VWFñ÷W$÷ˆFRÊVÊDˆdóFV”†¢ˆ6Ê6V≈6∆VWFñ÷W"Çì∞¢6WE7FFRÇÇí”‚˜6∆VWFñ÷W$÷ˆFR“6∆VWFñ÷W$÷ˆFRÊVÊDˆdóFV“ì∞¢˜6Ü˜u6∆VWFñ÷W%Fˆ7BÇu7F˜ñÊrBFÜRVÊBˆbFÜó2Wó6ˆFRrì∞¢–¢–†¢fˆñB˜7F'E6∆VW6˜VÁFF˜v‚ÜñÁB÷ñÁWFW2í∞¢ˆ6Ê6V≈6∆VWFñ÷W"Çì∞¢fñÊ¬GW&Fñˆ‚“GW&Fñˆ‚Ü÷ñÁWFW3¢÷ñÁWFW2ì∞¢6WE7FFRÇÇí∞¢˜6∆VWFñ÷W$÷ˆFR“6∆VWFñ÷W$÷ˆFRÊ6˜VÁFF˜v„∞¢˜6∆VWFñ÷W$FVF∆ñÊR“FFUFñ÷RÊÊ˜rÇíÊFBÜGW&Fñˆ‚ì∞¢˜6∆VWFñ÷W$&÷VD÷ñÁWFW2“÷ñÁWFW3∞¢“ì∞¢˜6∆VWFñ÷W"“Fñ÷W"ÜGW&Fñˆ‚¬ˆfó&U6∆VWFñ÷W"ì∞¢˜6Ü˜u6∆VWFñ÷W%Fˆ7BÇu6∆VWFñ÷W"6WBf˜"F÷ñÁWFW2÷ñÁWFW2rì∞¢–†¢fˆñBˆ6Ê6V≈6∆VWFñ÷W"Çí∞¢˜6∆VWFñ÷W#ÚÊ6Ê6V¬Çì∞¢˜6∆VWFñ÷W"“ÁV∆√∞¢ñbÖ˜6∆VWFñ÷W$÷ˆFR”“6∆VWFñ÷W$÷ˆFRÊˆfbí&WGW&„∞¢ñbÜ÷˜VÁFVBí∞¢6WE7FFRÇÇí∞¢˜6∆VWFñ÷W$÷ˆFR“6∆VWFñ÷W$÷ˆFRÊˆfc∞¢˜6∆VWFñ÷W$FVF∆ñÊR“ÁV∆√∞¢˜6∆VWFñ÷W$&÷VD÷ñÁWFW2“∞¢“ì∞¢“V«6R∞¢˜6∆VWFñ÷W$÷ˆFR“6∆VWFñ÷W$÷ˆFRÊˆfc∞¢˜6∆VWFñ÷W$FVF∆ñÊR“ÁV∆√∞¢–¢–†¢ÚÚÚ7F˜f˜"FÜRÊñváC¢W'6ó7BFÜR˜6óFñˆ‚fó'7BÜ∆˜6ñÊr6ˆ÷VˆÊRw2∆6P¢ÚÚÚ˜fW&ÊñváBó2WÜ7F«íFÜR÷ˆ÷VÁBFÜó2fVGW&Ró2÷VÁBFÚ&RÜV«ñÊrí¿¢ÚÚÚFÜV‚W6RßuÁ‚ùÁBvÜñ6Ç&V∆V6W2FÜRv∂V∆ˆ6≤ÊB∆WG2FÜR67&VV‚6∆VW‡¢gWGW&S«fˆñC‚ˆfó&U6∆VWFñ÷W"Çí7ñÊ2∞¢ˆ6Ê6V≈6∆VWFñ÷W"Çì∞¢˜6∆VW7F˜∆F6ÜVB“G'VS∞¢ˆ7FófT÷VFñ6Ü˜V∆E∆í“f«6S∞¢ñbÇ˜∆ñW$7&VFVBí&WGW&„∞¢vóB˜6fU&W7V÷RÇì∞¢vóB˜∆ñW"ÁW6RÇì∞¢˜6Ü˜u6∆VWFñ÷W%Fˆ7BÇu6∆VWFñ÷W"VÊFVBßuÁ‚ùÁBW6VBrì∞¢–†¢fˆñB˜6Ü˜u6∆VWFñ÷W%Fˆ7BÖ7G&ñÊr÷W76vRí∞¢ñbÇ÷˜VÁFVBí&WGW&„∞¢66ffˆ∆D÷W76VÊvW"ÊˆbÜ6ˆÁFWáBíÁ6Ü˜u6Ê6¥&"Ä¢6Ê6¥&"Ä¢6ˆÁFVÁC¢FWáBÜ÷W76vRí¿¢&VÜfñ˜#¢6Ê6¥&$&VÜfñ˜"Êf∆ˆFñÊr¿¢GW&Fñˆ„¢6ˆÁ7BGW&Fñˆ‚á6V6ˆÊG3¢2í¿¢í¿¢ì∞¢–†¢fˆñBˆ6ÜÊvU7VVBÇí∞¢6ˆÁ7B7VVG2“≥„R¬„sR¬„¬„#R¬„R¬„sR¬"„”∞¢fñÊ¬ñGÇ“7VVG2ÊñÊFWÑˆbÖ˜∆ñ&6µ7VVBì∞¢fñÊ¬ÊWáB“7VVG5≤ÜñGÇ≤íR7VVG2Ê∆VÊwFÖ”∞¢˜∆ñW"Á6WE&FRÜÊWáBì∞¢6WE7FFRÇÇí”‚˜∆ñ&6µ7VVB“ÊWáBì∞¢˜66ÜVGV∆TWFÙÜñFRÇì∞¢˜6fU&W7V÷RÇì∞¢–†¢ÚÚÚ7VVB'WGFˆ„¢FÜR÷VÁRw27VVBÊRvÜV‚FÜRVÊñfñVB÷VÁRó2ˆ‚¬FÜP¢ÚÚÚˆ∆B&∆ñÊB7ñ6∆R˜FÜW'vó6R‚∂Wñ&ˆ&Bˆ∆ˆÊr◊&W727ñ6∆ñÊró2VÁF˜V6ÜVB‡¢fˆñBˆˆÂ7VVD'WGFˆ‚Çí∞¢ñbÜµVÊñfñVE∆ñW$÷VÁTVÊ&∆VBí∞¢ˆ˜VÂ∆ñW$÷VÁUVñ6≤Ö∆ñW$÷VÁU6V7Fñˆ‚Á7VVBì∞¢&WGW&„∞¢–¢ˆ6ÜÊvU7VVBÇì∞¢–†¢fˆñBˆˆ‰7V7D'WGFˆ‚Çí∞¢ñbÜµVÊñfñVE∆ñW$÷VÁTVÊ&∆VBí∞¢ˆ˜VÂ∆ñW$÷VÁUVñ6≤Ö∆ñW$÷VÁU6V7Fñˆ‚Ê7V7Bì∞¢&WGW&„∞¢–¢ˆ7ñ6∆T7V7D÷ˆFRÇì∞¢–†¢fˆñB˜6WE∆ñ&6µ7VVBÜF˜V&∆Rbí∞¢˜∆ñW"Á6WE&FRábì∞¢6WE7FFRÇÇí”‚˜∆ñ&6µ7VVB“bì∞¢˜6fU&W7V÷RÇì∞¢–†¢fˆñB˜6WD7V7D÷ˆFTFó&V7BÑ7V7D÷ˆFR“í∞¢ñbÜ“”“ˆ7V7D÷ˆFRí&WGW&„∞¢6WE7FFRÇÇí”‚ˆ7V7D÷ˆFR““ì∞¢VÊvóFVBÖˆ«î7V7EfñFVı¶ˆˆ“Çíì∞¢˜6fU&W7V÷RÇì∞¢–†¢fˆñBˆˆ‰∆ˆÊu&W757F'BÑ∆ˆÊu&W757F'DFWFñ«2FWFñ«2í∞¢ÚÚ&W7V7BFÜR6÷R∆ˆ6≤W6VB'íFÜR6ñÊv∆R◊FFÄ¢ñbávñFvWBÊÜñFT&6¥'WGFˆ‚bbvñFvWBÊÜñFT˜FñˆÁ2í&WGW&„∞¢ÚÚˆÊ«íVÊvvRGW&ñÊr∆ñ&6≤6ÚW6R÷Üˆ∆BFˆW6‚wB7G&ÊB7VVBB'Ä¢ñbÇˆó5∆ññÊrí&WGW&„∞¢fñÊ¬&˜Ç“6ˆÁFWáBÊfñÊE&VÊFW$ˆ&¶V7BÇí2&VÊFW$&˜ÉÛ∞¢ñbÜ&˜Ç“ÁV∆¬í∞¢fñÊ¬6ó¶R“&˜ÇÁ6ó¶S∞¢fñÊ¬∆ˆ6≈˜2“FWFñ«2Ê∆ˆ6≈˜6óFñˆ„∞¢ÚÚfˆñBVFvR6ˆÊf∆ñ7G2vóFÇFÜR7ó7FV“&6≤vW7GW&P¢6ˆÁ7BVFvTwV&B“#B„∞¢ñbÜ∆ˆ6≈˜2ÊGÇ¬VFvTwV&B«¬∆ˆ6≈˜2ÊGÇ‚6ó¶RÁvñGFÇ“VFvTwV&Bí∞¢&WGW&„∞¢–¢ÚÚvÜV‚6ˆÁG&ˆ«2&Rfó6ñ&∆R¬6∂óF˜ˆ&˜GFˆ“&"&VvñˆÁ26Ú'WGFˆÁ2˜6∆ñFW"vñ‡¢ñbÖˆ6ˆÁG&ˆ«5fó6ñ&∆RÁf«VRí∞¢6ˆÁ7BF˜&"“s"„∞¢fñÊ¬&˜GFˆ‘&"“ˆFˆ6¥&ÊBÉs"„ì∞¢ñbÜ∆ˆ6≈˜2ÊGí¬F˜&"«¬∆ˆ6≈˜2ÊGí‚6ó¶RÊÜVñváB“&˜GFˆ‘&"í∞¢&WGW&„∞¢–¢–¢–¢˜7VVD&Vf˜&TÜˆ∆B“˜∆ñ&6µ7VVC∞¢˜∆ñW"Á6WE&FRÉ"„ì∞¢6WE7FFRÇÇí”‚˜∆ñ&6µ7VVB“"„ì∞¢˜7VVDÜˆ∆DáVBÁf«VR“G'VS∞¢ÜFñ4fVVF&6≤Ê÷VFóV‘ñ◊7BÇì∞¢–†¢fˆñBˆˆ‰∆ˆÊu&W74VÊBÑ∆ˆÊu&W74VÊDFWFñ«2FWFñ«2í∞¢fñÊ¬&ñ˜"“˜7VVD&Vf˜&TÜˆ∆C∞¢ñbá&ñ˜"”“ÁV∆¬í&WGW&„∞¢˜7VVD&Vf˜&TÜˆ∆B“ÁV∆√∞¢ñbÇ÷˜VÁFVBí&WGW&„∞¢˜∆ñW"Á6WE&FRá&ñ˜"ì∞¢6WE7FFRÇÇí”‚˜∆ñ&6µ7VVB“&ñ˜"ì∞¢˜7VVDÜˆ∆DáVBÁf«VR“f«6S∞¢–†¢gWGW&S«fˆñC‚˜Fˆvv∆T˜&ñVÁFFñˆ‚Çí7ñÊ2∞¢ñbÖˆ∆ÊG66T∆ˆ6∂VBí∞¢vóB7ó7FV‘6á&ˆ÷RÁ6WE&VfW'&VD˜&ñVÁFFñˆÁ2ÉƒFWfñ6T˜&ñVÁFFñˆ„Â∞¢FWfñ6T˜&ñVÁFFñˆ‚Á˜'G&óEW¿¢“ì∞¢ˆ∆ÊG66T∆ˆ6∂VB“f«6S∞¢“V«6R∞¢vóB7ó7FV‘6á&ˆ÷RÁ6WE&VfW'&VD˜&ñVÁFFñˆÁ2ÉƒFWfñ6T˜&ñVÁFFñˆ„Â∞¢FWfñ6T˜&ñVÁFFñˆ‚Ê∆ÊG66T∆VgB¿¢FWfñ6T˜&ñVÁFFñˆ‚Ê∆ÊG66U&ñváB¿¢“ì∞¢ˆ∆ÊG66T∆ˆ6∂VB“G'VS∞¢–¢7ó7FV‘6á&ˆ÷RÁ6WDVÊ&∆VE7ó7FV’Tî÷ˆFRÖ7ó7FV’Vî÷ˆFRÊñ÷÷W'6ófU7Fñ6∑íì∞¢ñbÜ÷˜VÁFVBí6WE7FFRÇÇí∑“ì∞¢˜66ÜVGV∆TWFÙÜñFRÇì∞¢–†¢&˜ÑfóBˆ7W'&VÁDfóBÇí”‚7V7D÷ˆFUWFñ«2ÊvWD&˜ÑfóDf˜$÷ˆFRÖˆ7V7D÷ˆFRì∞†¢ÚÚ'Vñ∆B7V'FóF∆RfñWr6ˆÊfñwW&Fñˆ‚g&ˆ“6WGFñÊw0¢ÚÚ‰ıDS¢FÜRFV∆Wfó6ñˆ‚&"FV∆ñ&W&FV«íFˆW2‰ıB÷˜fR7V'FóF∆W2‡¢Ú¢ÚÚÊFófRfó6ñ&ñ∆óGí&V÷ñÁ2ˆfbf˜"FWáBG&6∑2&V6W6RVÊ&∆ñÊróBG&w0¢ÚÚWfW'í∆ñÊRGvñ6RÑ÷VFñ∂óB«6Ú&VÊFW'2FÜ˜6R7VW2ñ‚f«WGFW"í‚&óF÷ ¢ÚÚ6V∆V7FñˆÁ2Fˆvv∆RóB6W&FV«í&V6W6RFÜWíÜfRÊÚFWáB7VW2‚FFñÊp¢ÚÚ7V'FóF∆W2Wv&Bf˜VváBFÜRW6W"w2˜v‚7V'FóF∆P¢ÚÚV∆WfFñˆ‚6WGFñÊrÊBFá&WrFÜV“ñÁFÚFÜR÷ñFF∆RˆbFÜR67&VV‚‚FÜR&"ó0¢ÚÚG&Á6ñVÁBÊBFÜRV∆WfFñˆ‚6WGFñÊr«&VGíWÜó7G2f˜"WÜ7F«íFÜó0¢ÚÚ&VfW&VÊ6R¬6Ú7V'FóF∆W27FívÜW&RFÜRW6W"WBFÜV“‡¢÷∑bÂ7V'FóF∆UfñWt6ˆÊfñwW&Fñˆ‚ˆ'Vñ∆E7V'FóF∆UfñWt6ˆÊfñrÇí∞¢ñbÖ∆Ff˜&“Êó4îı2bbÖˆó5ó7FófR«¬ˆñ˜5ó7F'FñÊríí∞¢&WGW&‚6ˆÁ7B÷∑bÂ7V'FóF∆UfñWt6ˆÊfñwW&Fñˆ‚áfó6ñ&∆S¢f«6Rì∞¢–¢fñÊ¬6WGFñÊw2“˜7V'FóF∆U6WGFñÊw3∞¢ñbá6WGFñÊw2”“ÁV∆¬í∞¢&WGW&‚6ˆÁ7B÷∑bÂ7V'FóF∆UfñWt6ˆÊfñwW&Fñˆ‚Çì∞¢–†¢&WGW&‚÷∑bÂ7V'FóF∆UfñWt6ˆÊfñwW&Fñˆ‚Ä¢7Gñ∆S¢6WGFñÊw2Ê'Vñ∆EFWáE7Gñ∆RÇí¿¢FFñÊs¢VFvTñÁ6WG2Êg&ˆ‘≈E$"Éb¬¬b¬6WGFñÊw2ÊV∆WfFñˆ‚Ê&˜GFˆ’FFñÊrí¿¢ì∞¢–†¢ÚÚ'Vñ∆BfñFVÚvóFÇ7W7Fˆ“7V7B&Fñ¢vñFvWBˆ'Vñ∆D7W7Fˆ‘7V7E&FñıfñFVÚÇí∞¢&WGW&‚7V7E&FñıfñFVÚÄ¢∂Wì¢f«VT∂WíÄ¢wfñFVıˆV∆WfFñˆÂÚGµ˜7V'FóF∆U6WGFñÊw3ÚÊV∆WfFñˆ‰ñÊFWÇÛÚ“r¿¢í¿¢fñFVÙ6ˆÁG&ˆ∆∆W#¢˜fñFVÙ6ˆÁG&ˆ∆∆W"¿¢W6UWˆ‰VÁFW&ñÊt&6∂w&˜VÊD÷ˆFS¢∆Ff˜&“Êó4îı2¿¢7W7Fˆ‘7V7E&FñÛ¢ˆvWD7W7Fˆ‘7V7E&FñÚÇí¿¢7W'&VÁDfóC¢ˆ7W'&VÁDfóBÇí¿¢7V'FóF∆UfñWt6ˆÊfñwW&Fñˆ„¢ˆ'Vñ∆E7V'FóF∆UfñWt6ˆÊfñrÇí¿¢ì∞¢–†¢ÚÚgV∆«67&VV‚G&Á6óFñˆ‚˜fW&∆ì¢&WG&ÚEb7FFñ2VffV7BÜ÷F6ÜW2ÊG&ˆñBEbê¢vñFvWBˆ'Vñ∆EG&Á6óFñˆ‰˜fW&∆íÇí∞¢&WGW&‚G&Á6óFñˆ‰˜fW&∆íÄ¢&ñÊ&˜t6ˆÁG&ˆ∆∆W#¢˜&ñÊ&˜t6ˆÁG&ˆ∆∆W"¿¢Ge7FFñ4÷W76vS¢˜Ge7FFñ4÷W76vR¿¢Ge7FFñ57V'FWáC¢˜Ge7FFñ57V'FWáB¿¢ì∞¢–†¢vñFvWBˆ'Vñ∆E7G&V÷ñıGdÊWáD∆ˆFñÊt˜fW&∆íÇí∞¢&WGW&‚ñvÊ˜&UˆñÁFW"Ä¢6Üñ∆C¢Êñ÷FVD˜6óGíÄ¢˜6óGì¢˜6Ü˜u7G&V÷ñıGdÊWáD∆ˆFñÊrÚ¢¿¢GW&Fñˆ„¢6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢cí¿¢6Üñ∆C¢6ˆÁFñÊW"Ä¢6ˆ∆˜#¢6ˆ∆˜'2Ê&∆6≤ÁvóFÖf«VW2Ü«Ü¢„SRí¿¢6Üñ∆C¢6VÁFW"Ä¢6Üñ∆C¢6ˆÁFñÊW"Ä¢FFñÊs¢6ˆÁ7BVFvTñÁ6WG2Á7ñ÷÷WG&ñ2ÜÜ˜&ó¶ˆÁF√¢#"¬fW'Fñ6√¢Çí¿¢FV6˜&Fñˆ„¢&˜ÑFV6˜&Fñˆ‚Ä¢6ˆ∆˜#¢6ˆ∆˜'2Ê&∆6≤ÁvóFÖf«VW2Ü«Ü¢„s"í¿¢&˜&FW%&FóW3¢&˜&FW%&FóW2Ê6ó&7V∆"ÉÇí¿¢&˜&FW#¢&˜&FW"Ê∆¬Ü6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFRÁvóFÖf«VW2Ü«Ü¢„íí¿¢í¿¢6Üñ∆C¢6ˆÁ7B&˜rÄ¢÷ñ‰Üó56ó¶S¢÷ñ‰Üó56ó¶RÊ÷ñ‚¿¢6Üñ∆G&V„¢∞¢6ó¶VD&˜ÇÄ¢vñGFÉ¢#Ç¿¢ÜVñváC¢#Ç¿¢6Üñ∆C¢6ó&7V∆%&ˆw&W74ñÊFñ6F˜"Ä¢7G&ˆ∂UvñGFÉ¢"„b¿¢f«VT6ˆ∆˜#¢«vó57F˜VDÊñ÷Fñˆ„ƒ6ˆ∆˜#‚Ñ6ˆ∆˜'2ÁvÜóFRí¿¢í¿¢í¿¢6ó¶VD&˜ÇávñGFÉ¢Bí¿¢FWáBÄ¢t∆ˆFñÊrÊWáB‚‚‚r¿¢7Gñ∆S¢FWáE7Gñ∆RÄ¢6ˆ∆˜#¢6ˆ∆˜'2ÁvÜóFR¿¢fˆÁE6ó¶S¢R¿¢fˆÁEvVñváC¢fˆÁEvVñváBÁsc¿¢í¿¢í¿¢“¿¢í¿¢í¿¢í¿¢í¿¢í¿¢ì∞¢–†¢ÚÚÚˆÊRG'WFÇf˜"&ó2FÜó2∆ñ&6≤&VñÊr&V6˜&FVB&ñváBÊ˜r"¬6Ü&VB'ê¢ÚÚÚFÜRFˆ6≤w2&V6˜&B'WGFˆ‚ÊBFÜR7Gñ∆VB¶&ÊÊW"w2$T2FrßuÁ‚ùÁBFÜP¢ÚÚÚFá&VR÷V6ÜÊó6◊2&R∆ñ&◊b7G&V“◊&V6˜&B¬FÜRÊG&ˆñB&V6˜&FñÊp¢ÚÚÚVÊvñÊR¬ÊBFÜRFW6∑F˜6GW&R&ˆ6W72‡¢&ˆˆ¬vWB˜&V6˜&FñÊt7FófTÊ˜r”‡¢ˆó5&V6˜&FñÊr«¿¢ˆVÊvñÊUF6¥ñB“ÁV∆¬«¿¢ˆFW6∑F˜6GW&Tf˜$7W'&VÁBÇí“ÁV∆√∞†¢ÚÚÚFÜR∆ófR‘ïEbÊV¬¬˜"ÁV∆¬vÜV‚FÜó2∆ñ&6≤Ü2ÊÚ6ÜÊÊV¬ñFVÁFóGê¢ÚÚÚFÚ&W6VÁB‚∂f«W6Ö“V÷&VG2óBñ‚FÜR6ˆÁG&ˆ«2Fˆ6≥≤˜FÜW'vó6RóBf∆ˆG2‡¢ÚÚÚFV'&ñgíEb˜vÁ2FÜR6W76ñˆ‚ñFVÁFóGívÜV‚FÜR∆VÊ6Ç6∂VBf˜"FÜP¢ÚÚÚ6ÜÊÊV¬6á&ˆ÷RÊBÊÚ∆ófRïEb&ÊÊW"FˆW2‡¢&ˆˆ¬vWBˆFV'&ñgïGd˜vÁ4ñFVÁFóGí”‡¢vñFvWBÁ6Ü˜t6ÜÊÊVƒÊ÷RbbˆóGe¶&ÊÊW$˜vÁ4ñFVÁFóGì∞†¢vñFvWCÚˆ'Vñ∆DFV'&ñgïGdñÊfıÊV¬á∑&WVó&VB&ˆˆ¬f«W6á“í∞¢ñbÇˆFV'&ñgïGd˜vÁ4ñFVÁFóGíí&WGW&‚ÁV∆√∞¢fñÊ¬Ê÷R“Öˆ7W'&VÁD6ÜÊÊVƒÊ÷RÛÚvñFvWBÊ6ÜÊÊVƒÊ÷RìÚÁG&ñ“Çì∞¢fñÊ¬FóF∆R“vñFvWBÁ6Ü˜ufñFVıFóF∆RÚˆvWD7W'&VÁDWó6ˆFUFóF∆RÇí¢ÁV∆√∞¢ñbÇÜÊ÷R”“ÁV∆¬«¬Ê÷RÊó4V◊Gííb`¢ˆ7W'&VÁD6ÜÊÊVƒÁV÷&W"”“ÁV∆¬b`¢áFóF∆R”“ÁV∆¬«¬FóF∆RÊó4V◊Gííí∞¢&WGW&‚ÁV∆√∞¢–¢&WGW&‚FV'&ñgïGd&ÊÊW"Ä¢6ÜÊÊVƒÁV÷&W#¢ˆ7W'&VÁD6ÜÊÊVƒÁV÷&W"¿¢6ÜÊÊVƒÊ÷S¢Ê÷R¿¢FóF∆S¢FóF∆R¿¢6∆ˆ6≥¢˜∆ñ&6µVî6∆ˆ6≤¿¢ÚÚÜñFU6VV∂&"∂VW2'VÁFñ÷W27W'&ó6R.ù◊üäwùBFÜR&ÊÊW"◊W7BÊ˜B∆V∞¢ÚÚvÜBFÜRFˆ6≤ÜñFW2‡¢6Ü˜u&ˆw&W73¢vñFvWBÊÜñFU6VV∂&"¿¢f«W6É¢f«W6Ç¿¢ì∞¢–†¢ÚÚÚFÜR6∆ˆ6≤ó2‚˜Fñ÷ó¶Fñˆ‚vFRßuÁ‚ùÁBóBˆÊ«íV&∆ó6ÜW2vÜñ∆R6ˆ÷WFÜñÊp¢ÚÚÚˆ‚67&VV‚&VG2óB‚FÜBW6VBFÚ÷V‚'FÜR&"#≤FÜRf∆ˆFñÊrFV'&ñgê¢ÚÚÚ&ÊÊW"w2&ˆw&W72&˜r&VG2óBFˆÚÜˆÊ«ívÜV‚FÜR6W76ñˆ‚6Ü˜w0¢ÚÚÚ&ˆw&W72B∆¬í‡¢fˆñB˜7ñÊ5∆ñ&6¥6∆ˆ6µfó6ñ&ñ∆óGíÇí∞¢˜∆ñ&6µVî6∆ˆ6≤Á6WEfó6ñ&∆RÄ¢ˆ6ˆÁG&ˆ«5fó6ñ&∆RÁf«VR«¿¢Ö˜6Ü˜tFV'&ñgî&ÊÊW"bbˆFV'&ñgïGd˜vÁ4ñFVÁFóGíbbvñFvWBÊÜñFU6VV∂&"í¿¢ì∞¢–†¢ÚÚÚ&ó6W2FÜRf∆ˆFñÊr∆˜vW"◊FÜó&BáGVÊR¬¶¬∆VÊ6Çí‚FÜRÜñFRFñ÷W ¢ÚÚÚ&R÷&◊2vÜñ∆R6ÜÊÊV¬7vóF6Çó27Fñ∆¬&W6ˆ«fñÊrßuÁ‚ùÁBFÜRˆ∆B6˜&ÊW ¢ÚÚÚ&FvW2Fñ÷VB˜WBEU$î‰rFÜR&W6ˆ«fR¬vÜñ6Çó2váíGdı2ÊWfW"6rFÜV“‡¢fˆñB˜&ó6TFV'&ñgî&ÊÊW"Çí∞¢ñbÇˆFV'&ñgïGd˜vÁ4ñFVÁFóGíí&WGW&„∞¢ñbÖˆÁï∆ñW$˜fW&∆î˜V‚«¬ˆ6ˆÁG&ˆ«5fó6ñ&∆RÁf«VRí&WGW&„∞¢ˆFV'&ñgî&ÊÊW%Fñ÷W#ÚÊ6Ê6V¬Çì∞¢6WE7FFRÇÇí∞¢˜6Ü˜tFV'&ñgî&ÊÊW"“G'VS∞¢ˆFV'&ñgî&ÊÊW$f∆ˆFñÊt÷˜VÁFVB“G'VS∞¢“ì∞¢˜7ñÊ5∆ñ&6¥6∆ˆ6µfó6ñ&ñ∆óGíÇì∞¢ˆ&‘FV'&ñgî&ÊÊW%Fñ÷W"Çì∞¢–†¢fˆñBˆ&‘FV'&ñgî&ÊÊW%Fñ÷W"Çí∞¢ÚÚvÜñ∆R&W6ˆ«fñÊr¬ˆ∆¬f7B.ù◊üäwùB6ÚFÜReTƒ¬Fó7∆ívñÊF˜ró2w&ÁFV@¢ÚÚg&ˆ“á&˜VvÜ«ííFÜR÷ˆ÷VÁBFÜRÊWr7G&V“∆ÊG2¬Ê˜Bg&ˆ“¶7F'B‡¢fñÊ¬&W6ˆ«fñÊr“ˆó5G&Á6óFñˆÊñÊs∞¢ˆFV'&ñgî&ÊÊW%Fñ÷W"“Fñ÷W"Ä¢&W6ˆ«fñÊp¢Ú6ˆÁ7BGW&Fñˆ‚Ü÷ñ∆∆ó6V6ˆÊG3¢Cê¢¢fñFVı∆ñW%Fñ÷ñÊt6ˆÁ7FÁG2Ê&FvTFó7∆îGW&Fñˆ‚¿¢Çí∞¢ñbÇ÷˜VÁFVBí&WGW&„∞¢ñbá&W6ˆ«fñÊr«¬ˆó5G&Á6óFñˆÊñÊrí∞¢ÚÚVóFÜW"FÜó2v2&W6ˆ«fR◊ˆ∆¬¬˜"ÊWr7vóF6Ç&Vv‡¢ÚÚ÷ñB◊vñÊF˜s¢∂VWFÜRñFVÁFóGíWÊB&R÷Wf«VFR‡¢ˆ&‘FV'&ñgî&ÊÊW%Fñ÷W"Çì∞¢&WGW&„∞¢–¢6WE7FFRÇÇí”‚˜6Ü˜tFV'&ñgî&ÊÊW"“f«6Rì∞¢˜7ñÊ5∆ñ&6¥6∆ˆ6µfó6ñ&ñ∆óGíÇì∞¢“¿¢ì∞¢–†¢fˆñBˆÜñFTFV'&ñgî&ÊÊW"á∂&ˆˆ¬ñ÷÷VFñFR“f«6W“í∞¢ˆFV'&ñgî&ÊÊW%Fñ÷W#ÚÊ6Ê6V¬Çì∞¢ñbÇ˜6Ü˜tFV'&ñgî&ÊÊW"bbÜñ÷÷VFñFRbbˆFV'&ñgî&ÊÊW$f∆ˆFñÊt÷˜VÁFVBíí∞¢&WGW&„∞¢–¢6WE7FFRÇÇí∞¢˜6Ü˜tFV'&ñgî&ÊÊW"“f«6S∞¢ñbÜñ÷÷VFñFRíˆFV'&ñgî&ÊÊW$f∆ˆFñÊt÷˜VÁFVB“f«6S∞¢“ì∞¢˜7ñÊ5∆ñ&6¥6∆ˆ6µfó6ñ&ñ∆óGíÇì∞¢–†¢vñFvWCÚˆ'Vñ∆DóGdñÊfıÊV¬á∑&WVó&VB&ˆˆ¬f«W6á“í∞¢fñÊ¬6ÜÊÊV¬“ˆóGe¶6ÜÊÊV√∞¢ñbÜ6ÜÊÊV¬”“ÁV∆¬«¬ˆóGe¶&ÊÊW$˜vÁ4ñFVÁFóGíí&WGW&‚ÁV∆√∞¢&WGW&‚óGe¶&ÊÊW"Ä¢6ÜÊÊV√¢6ÜÊÊV¬¿¢Ws¢ˆóGe¶Wr¿¢Wt∆ˆFñÊs¢ˆóGe¶Wt∆ˆFñÊr¿¢Ê˜s¢ˆóGe¶6∆ˆ6≤¿¢f«W6É¢f«W6Ç¿¢7Gñ∆S¢˜∆ñW$wVñFU7Gñ∆R¿¢Fˆ∂VÁ3¢˜∆ñW$wVñFUFˆ∂VÁ2¿¢ó5&V6˜&FñÊs¢˜&V6˜&FñÊt7FófTÊ˜r¿¢ì∞¢–†¢ÚÚvWBFÜR7W7Fˆ“7V7B&FñÚf˜"7V6ñfñ2÷ˆFW0¢F˜V&∆SÚˆvWD7W7Fˆ‘7V7E&FñÚÇí”‡¢7V7D÷ˆFUWFñ«2ÊvWD7V7E&Fñıf«VRÖˆ7V7D÷ˆFRì∞†¢ÚÚ∫w^~)ﬁtZ4\\€ŸH›ZYNà[ã\^Y\àô]⁄ŸàXúŸ[ù\\€Ÿ\ È›y¯ßy–h–h–h–h–h–ÇàÀÀ»⁄]\à[à\\€ŸH]\€â›[àH›\úô[ù^[\›ÿ[àôHô]⁄YàÀÀ»[ô^YY⁄]›]X]ö[ô»H^Y\éàÿ][Ÿ»Ÿ\öY\»€€ù[ù⁄]BàÀÀ»]ôHô]⁄\à
»ô\€€ô\ã›]⁄YHH⁄[õô[\›[H[Ÿ\»
›ô[Z[»à¬àÀÀ»Tà»XúöYûHà›€àZ\àY[ù]H[ôô^‹ô]àŸ[X[ùX‹ KÇàõ€€Ÿ]ÿÿ[ëô]⁄\\€Ÿ\»OÇà⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\àOHù[	âÇà]⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\àKö\”[›öYH	âÇà⁄YŸ]úô\€€ôT€›\òŸU‘^[\›OHù[	âÇà‹›ô[Z[‘€›\òŸ\”›ô\úöYHOHù[	âÇàŸYôôX›]ôT›ô[Z[’ê⁄[õô[»OHù[	âÇàŸYôôX›]ôR\ê⁄[õô[»OHù[	âÇà⁄YŸ]úô\]Y\›XY⁄X”ô^OHù[¬Çàõ€€Ÿ\\€ŸQô]⁄[îõŸ‹ô\‹»Hò[ŸN¬ÇàÀ»ﬁ[ù]X»KY[ùûH›ZYHòX⁄⁄[ô»õ‹à⁄[ô€K\›ôX[H][ò⁄\»
õ»^[\›
NÇàÀ»]»H\\€ŸH›ZYH‹[à[ôŸôô\àH⁄›…‹»ù[\\€ŸH\›ÇàŸ\öY\‘^[\›»‹ﬁ[ù]X—›ZYT^[\›¬à\›^[\›[ùûOè»‹ﬁ[ù]X—›ZYQ[ùöY\Œ¬Çà›]X»›ö[ô»‹Yä[ùäHOàãù‘›ö[ô 
KúYYù
ã	Ã	 N¬Çà
Ÿ\öY\‘^[\›\›^[\›[ùûOäO»ÿùZ[ﬁ[ù]X—›ZYJ
H¬àö[ò[^\›[ô‘‹H‹ﬁ[ù]X—›ZYT^[\›¬àö[ò[^\›[ô—[ùöY\»H‹ﬁ[ù]X—›ZYQ[ùöY\Œ¬àYà
^\›[ô‘‹OHù[	âà^\›[ô—[ùöY\»OHù[
H¬àô]\õà
^\›[ô‘‹^\›[ô—[ùöY\ N¬àBàö[ò[ŸHH›òZ›ŸX\€€ë\\€ŸJ
N¬àYà
ŸKúŸX\€€àOHù[ŸKô\\€ŸHOHù[
Hô]\õàù[¬àò\à]HH⁄YŸ]ù]N¬àö[ò[[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJ]JN¬àYà
[ôõÀúŸX\€€àOHù[[ôõÀô\\€ŸHOHù[
H¬àÀ»›[\H^Z[ô»\\€ŸI‹»Y[ù]H€»H›ZYH‹õ›\»]öY⁄Çà]HH	‘…◊‹YäŸKúŸX\€€àJ_QI◊‹YäŸKô\\€ŸHJ_H	]IŒ¬àBàö[ò[[ùöY\»H‘^[\›[ùûJ\õà⁄YŸ]ùöY[’\õ]Nà]JWN¬àö[ò[‹HŸ\öY\‘^[\›ôúõ€T^[\›[ùöY\ à[ùöY\Àà€€X›[€ï]Nà⁄YŸ]ò€€ù[ù]Hœ»⁄YŸ]ù]Kàõ‹òŸTŸ\öY\ŒàùYKà
N¬à‹ö[YíYHÿ›\úô[ùŸ\öY\“[YíY¬à‹ﬁ[ù]X—›ZYT^[\›H‹¬à‹ﬁ[ù]X—›ZYQ[ùöY\»H[ùöY\Œ¬àô]\õà
‹[ùöY\ N¬àBÇàõ€€‹X⁄–€›ô\ú‘ŸX\€€ä‹úô[ù[ùŸX\€€äH¬à›⁄]⁄
ò€›ô\òYŸU\JH¬àÿ\ŸH	ÿ€€\]TŸ\öY\…ŒÇàö[ò[›\ùHú›\ùŸX\€€é¬àö[ò[[ôHô[ôŸX\€€é¬àYà
›\ùOHù[	âà[ôOHù[
Hô]\õàùYN¬àô]\õàŸX\€€àèH
›\ùœ»JH	âàŸX\€€àH
[ôœ»ŸX\€€äN¬àÿ\ŸH	€][TŸX\€€îX⁄…ŒÇàö[ò[›\ùHú›\ùŸX\€€é¬àö[ò[[ôHô[ôŸX\€€é¬àô]\õà›\ùOHù[	âà[ôOHù[	âàŸX\€€àèH›\ù	âàŸX\€€àH[ô¬àÿ\ŸH	‹ŸX\€€îX⁄…ŒÇàô]\õàúŸX\€€ìù[Xô\àOHŸX\€€é¬àYò][Çàô]\õàò[ŸN¬àBàBÇàÀÀ»]ZX⁄À\^H[à\\€ŸH]\€â›[àH›\úô[ù^[\›“U’UàÀÀ»X]ö[ô»H^Y\éàûHX⁄‹»[ôXYH[àH€›\òŸH\›[à[ÇàÀÀ»\\€ŸK]\ôŸ]Yô]⁄[àHúô\⁄X⁄»ŸX\ò⁄∫w^~)ﬁu›⁄]⁄[ô»»BàÀÀ»ö\ú›ÿ[ôY]H]ô\€€ô\»[ôX›X[H€€ùZ[ú»H\\€ŸKÇàù]\ôO\\€ŸT^XòX⁄”›]€€YOàŸô]⁄[ô^Q\\€ŸJà[ùŸX\€€ãà[ù\\€ŸK¬à[ù»⁄YôõQŸ[ô\ò][€ãàõ€€]]–Yò[òŸHHò[ŸKà\\€ŸT^XòX⁄‘ô\]Y\›»ô\]Y\›àJH\ﬁ[ò»¬àYà
Wÿÿ[ëô]⁄\\€Ÿ\»Ÿ\\€ŸQô]⁄[îõŸ‹ô\‹ H¬àÀ»Hô^‹ô]àô\‹»X^H]ôHòZ\ŸYHò[ú⁄][€à›\ùZ[à[ôXYN¬àÀ»ô]ô\àX]ôH]\⁄[àHô\]Y\›ÿ[â›ù[ãÇàYà
[›[ùY	âà⁄\’ò[ú⁄][€ö[ô H¬àŸ]›]J

HOà⁄\’ò[ú⁄][€ö[ô»Hò[ŸJN¬àBàô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàYà
ô\]Y\›OHù[
HŸ\\€ŸSò]öYÿ][€ëŸ[ô\ò][€ä Œ¬àô\]Y\›œœH\\€ŸT^XòX⁄‘ô\]Y\›
à›\úô[ùY[ù]Nà

HOà‹^[\›Y[ù]U⁄Ÿ[ãà›\úô[ùò]öYÿ][€éà

HOàŸ\\€ŸSò]öYÿ][€ëŸ[ô\ò][€ãà\–X›]ôNà

HOÇà[›[ùY	âÇà
X]]–Yò[òŸHW‹€Y\›‹]⁄Y
H	âÇà
⁄YôõQŸ[ô\ò][€àOHù[à⁄YôõQŸ[ô\ò][€àOH‹⁄›‘⁄YôõQŸ[ô\ò][€äKà
N¬àö[ò[ô]⁄\àH⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\àN¬àŸ\\€ŸQô]⁄[îõŸ‹ô\‹»HùYN¬àö[ò[Y\‹Ÿ[ôŸ\àHÿÿYôõ€Y\‹Ÿ[ôŸ\ãõŸä€€ù^
N¬àö[ò[Xô[H	‘…◊‹YäŸX\€€ä_QI◊‹Yä\\€ŸJ_IŒ¬àY\‹Ÿ[ôŸ\ãú⁄›‘€òX⁄–ò\äà€òX⁄–ò\äà€€ù[ùà^
	—ô]⁄[ô»	XôZÈ›y¯ßyŸâ Kà\ò][€éà€€ú›\ò][€äŸX€€ôŒàäKà
Kà
N¬àûH¬àö[ò[[õôYHô]⁄\ãú[õôY\ôX›ÿ[ôY]\Œ¬àYà
[õôYOHù[
H¬à]ÿZ]õ‹à
ö[ò[ÿ[ôY]H[à[õôY
àŸX\€€ãà\\€ŸKà€îôYô\úôYZ\‹⁄[ôŒà

H¬àYà
\ô\]Y\›Kö\–›\úô[ù[[›[ùY
Hô]\õé¬àY\‹Ÿ[ôŸ\ãú⁄›‘€òX⁄–ò\äà€€ú›€òX⁄–ò\äà€€ù[ùà^
à	÷[›\àô]ö[›\»€›\òŸH\»[ò]òZ[XõHõ‹à\»\\€ŸKàûZ[ô»›\à€›\òŸ\ÀâÀà
Kà
Kà
N¬àKà
JH¬àYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàö[ò[€›\òŸ\»H\›‹úô[ùãõŸäŸYôôX›]ôT€›\òŸ\»œ»€€ú›◊JN¬àö[ò[[ô^H€›\òŸ\Àõ[ô›¬à€›\òŸ\ÀòY
ÿ[ôY]JN¬àŸ]›]J

HOàÿ]Y€Y[ùY€›\òŸ\»H€›\òŸ\ N¬àö[ò[›]€€YHH]ÿZ]›ûQ\\€ŸPÿ[ôY]Jà[ô^àÿ[ôY]KàŸX\€€ãà\\€ŸKàô\]Y\›à⁄YôõQŸ[ô\ò][€éà⁄YôõQŸ[ô\ò][€ãà]]–Yò[òŸNà]]–Yò[òŸKà
N¬àYà
›]€€YHOH\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõJHô]\õà›]€€YN¬àYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàBàBÇàÀ»KàûH⁄]	‹»[ôXYH[àH€›\òŸH\›à^X›Y\\€ŸH⁄[ô€\»[ôàÀ»X⁄‹»€›ô\ö[ô»HŸX\€€à
Ÿù[à[ôXYH[õÿ⁄ŸY€àHXÿ€›[ù
KÇàö[ò[^\›[ô»H\›‹úô[ùãõŸäŸYôôX›]ôT€›\òŸ\»œ»€€ú›‹úô[ùñ◊JN¬àò\à][\»H¬àõ‹à
ò\àHH»H^\›[ôÀõ[ô›	âà][\»»J  H¬àYà
HOHÿ›\úô[ù€›\òŸR[ô^
H€€ù[ùYN¬àö[ò[H^\›[ô÷⁄WN¬àYà
ú›ôX[U\HOH›ôX[U\Kô^\õò[\õ
H€€ù[ùYN¬àö[ò[[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJô\‹^U]JN¬àö[ò[X]⁄\—\\€ŸHH[ôõÀúŸX\€€àOHŸX\€€à	âà[ôõÀô\\€ŸHOH\\€ŸN¬àö[ò[€›ô\ú–\‘X⁄»Bàú›ôX[U\HOH›ôX[U\Kù‹úô[ù	âà‹X⁄–€›ô\ú‘ŸX\€€äŸX\€€äN¬àYà
[X]⁄\—\\€ŸH	âàX€›ô\ú–\‘X⁄ H€€ù[ùYN¬à][\  Œ¬àö[ò[›]€€YHH]ÿZ]›ûQ\\€ŸPÿ[ôY]JàKààŸX\€€ãà\\€ŸKàô\]Y\›à⁄YôõQŸ[ô\ò][€éà⁄YôõQŸ[ô\ò][€ãà]]–Yò[òŸNà]]–Yò[òŸKà
N¬àYà
›]€€YHOH\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõJHô]\õà›]€€YN¬àYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàBÇàÀ»ãà\\€ŸK]\ôŸ]Yô]⁄
\ôX›[ö‹»ô\€€ôH[ú›[ùJKÇà\›‹úô[ùè»ô]⁄Y¬àûH¬àô]⁄YH]ÿZ]ô]⁄\ãôô]⁄
àŸ\öY\‘€›\òŸQô]⁄\ãõ[ŸQ\\€Ÿ\ÀàŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà
N¬àHÿ]⁄
 H¬àô]⁄YHù[¬àBàYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàYà
ô]⁄YOHù[	âàô]⁄Yö\”õ›[\JH¬àö[ò[ò\ŸHHŸYôôX›]ôT€›\òŸ\»œ»€€ú›‹úô[ùñ◊N¬àö[ò[Y\ôŸYHŸ\öY\‘€›\òŸQô]⁄\ãõY\ôŸT€›\òŸ\ ò\ŸKô]⁄Y
N¬àŸ]›]J

HOàÿ]Y€Y[ùY€›\òŸ\»HY\ôŸY
N¬à][\»H¬àõ‹à
ò\àHHò\ŸKõ[ô›»HY\ôŸYõ[ô›	âà][\»N»J  H¬àö[ò[HY\ôŸY⁄WN¬àYà
ú›ôX[U\HOH›ôX[U\Kô^\õò[\õ
H€€ù[ùYN¬à][\  Œ¬àö[ò[›]€€YHH]ÿZ]›ûQ\\€ŸPÿ[ôY]JàKààŸX\€€ãà\\€ŸKàô\]Y\›à⁄YôõQŸ[ô\ò][€éà⁄YôõQŸ[ô\ò][€ãà]]–Yò[òŸNà]]–Yò[òŸKà
N¬àYà
›]€€YHOH\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõJHô]\õà›]€€YN¬àYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàBàBÇàÀ»Àà\›ô\€‹ùàHúô\⁄X⁄»ŸX\ò⁄õ‹à]ŸX\€€ãÇà\›‹úô[ùè»X⁄‹Œ¬àûH¬àX⁄‹»H]ÿZ]ô]⁄\ãôô]⁄
àŸ\öY\‘€›\òŸQô]⁄\ãõ[ŸTX⁄‹ÀàŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà
N¬àHÿ]⁄
 H¬àX⁄‹»Hù[¬àBàYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàYà
X⁄‹»OHù[	âàX⁄‹Àö\”õ›[\JH¬àö[ò[ò\ŸHHŸYôôX›]ôT€›\òŸ\»œ»€€ú›‹úô[ùñ◊N¬àö[ò[Y\ôŸYHŸ\öY\‘€›\òŸQô]⁄\ãõY\ôŸT€›\òŸ\ ò\ŸKX⁄‹ N¬àŸ]›]J

HOàÿ]Y€Y[ùY€›\òŸ\»HY\ôŸY
N¬à][\»H¬àõ‹à
ò\àHHò\ŸKõ[ô›»HY\ôŸYõ[ô›	âà][\»Œ»J  H¬àö[ò[HY\ôŸY⁄WN¬àYà
ú›ôX[U\HOH›ôX[U\Kù‹úô[ù
H€€ù[ùYN¬àÀ»X⁄À\ŸX\ò⁄ô\›[»\ôHŸX\€€ã]\ôŸ]Y»€õH⁄⁄\€ô\»⁄‹ŸBàÀ»]X›Y€›ô\òYŸH‹⁄]]ô[H^€Y\»HŸX\€€ãÇàYà
ò€›ô\òYŸU\HOHù[	âàW‹X⁄–€›ô\ú‘ŸX\€€äŸX\€€äJH¬à€€ù[ùYN¬àBà][\  Œ¬àö[ò[›]€€YHH]ÿZ]›ûQ\\€ŸPÿ[ôY]JàKààŸX\€€ãà\\€ŸKàô\]Y\›à⁄YôõQŸ[ô\ò][€éà⁄YôõQŸ[ô\ò][€ãà]]–Yò[òŸNà]]–Yò[òŸKà
N¬àYà
›]€€YHOH\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõJHô]\õà›]€€YN¬àYà
\ô\]Y\›ö\–›\úô[ù
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àBàBàBÇàYà
ô\]Y\›ö\–›\úô[ù
H¬àÀ»Hô^‹ô]àô\‹»òZ\ŸYHò[ú⁄][€à›\ùZ[àôYõ‹ôHÿ[[ô»[ÇàÀ»\ôJÈ›y¯ßy’õ‹]‹àHòZ[Yô]⁄X]ô\»Hÿ‹ôY[àõX⁄ÀÇàYà
⁄\’ò[ú⁄][€ö[ô H¬àŸ]›]J

HOà⁄\’ò[ú⁄][€ö[ô»Hò[ŸJN¬àBàY\‹Ÿ[ôŸ\ãú⁄›‘€òX⁄–ò\äà€òX⁄–ò\ä€€ù[ùà^
	”õ»^XXõH€›\òŸHõ›[ôõ‹à	Xô[	 JKà
N¬àBàô]\õà\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõN¬àHö[ò[H¬àŸ\\€ŸQô]⁄[îõŸ‹ô\‹»Hò[ŸN¬àBàBÇàÀÀ»ô\€€ôH€ôHÿ[ôY]H[ô›⁄]⁄»]⁄[à]X›X[H€€ùZ[ú»BàÀÀ»\ôŸ]\\€ŸKô\‹ù[ô»òZ[\ôH[ô\[ô[ùHŸà^[\›ô\XŸ[Y[ùÇàù]\ôO\\€ŸT^XòX⁄”›]€€YOà›ûQ\\€ŸPÿ[ôY]Jà[ù€›\òŸR[ô^à‹úô[ùà[ùŸX\€€ãà[ù\\€ŸKà\\€ŸT^XòX⁄‘ô\]Y\›ô\]Y\›¬à[ù»⁄YôõQŸ[ô\ò][€ãàõ€€]]–Yò[òŸHHò[ŸKàJH\ﬁ[ò»¬àŸ‘€›\òŸTŸ[X›[€äà	€ô^Ÿ\\€ŸWÿÿ[ôY]IÀà€›\òŸNàà[ô^à€›\òŸR[ô^àŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà^Y\éà	€\âÀà
N¬àYà
X]ÿZ]⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\àKò[›‹–ÿ[ôY]J
JH¬àô]\õà\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõN¬àBàYà
\ô\]Y\›ö\–›\úô[ù
Hô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬à\›^[\›[ùûOè»^[\›¬àûH¬à^[\›H]ÿZ]⁄YŸ]úô\€€ôT€›\òŸU‘^[\›J
N¬àHÿ]⁄
 H¬à^[\›Hù[¬àBàYà
\ô\]Y\›ö\–›\úô[ù
Hô]\õà\\€ŸT^XòX⁄”›]€€YKòÿ[òŸ[Y¬àYà
^[\›OHù[^[\›ö\—[\JH¬àŸ‘€›\òŸTŸ[X›[€äà	€ô^Ÿ\\€ŸWÿÿ[ôY]W‹ôZôX›Y	Àà€›\òŸNàà[ô^à€›\òŸR[ô^àŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà^Y\éà	€\âÀàôX\€€éà	€õ◊‹^[\›	Àà
N¬àô]\õà\\€ŸT^XòX⁄”›]€€YKù[ò]òZ[XõN¬àBàYà
^[\›õ[ô›OHJH¬àö[ò[[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJ^[\›ôö\ú›ù]JN¬àYà
[ôõÀúŸX\€€àOHù[[ôõÀô\\€ŸHOHù[
H¬àÀ»[ú\úŸXXõH⁄[ô€H›ôX[Nà›[\H\ôŸ]Y[ù]H[ù»BàÀ»]H€»\ú⁄[ô»
]\Àÿ‹õÿòõ[ôÀH›ZYJH›^\»€⁄\ô[ùÇà^[\›H¬à^[\›ôö\ú›ò€‹U⁄]]Jà	‘…◊‹YäŸX\€€ä_QI◊‹Yä\\€ŸJ_H	‹^[\›ôö\ú›ù]_IÀà
KàN¬àH[ŸHYà
[ôõÀúŸX\€€àOHŸX\€€à[ôõÀô\\€ŸHOH\\€ŸJH¬àô]\õà\\€ŸT^XòX⁄”›]€€YBàù[ò]òZ[XõN»À»ô\€€ô\»»HQëëTëSï\\€ŸH∫w^~)ﬁu‹õ€ô»ô\›[àBàH[ŸH¬àö[ò[‹HŸ\öY\‘^[\›ôúõ€T^[\›[ùöY\ à^[\›à€€X›[€ï]Nà⁄YŸ]ù]Kàõ‹òŸTŸ\öY\ŒàùYKà
N¬àYà
‹ôö[ô‹öY⁄[ò[[ô^ûTŸX\€€ë\\€ŸJŸX\€€ã\\€ŸJH
H¬àô]\õà\\€ŸT^XòX⁄”›]€€YBàù[ò]òZ[XõN»À»X⁄»⁄]›]H\ôŸ]
È›y¯ßy’ûHHô^ÿ[ôY]BàBàBà‹Ÿ]X[ùX[Ÿ[X›[€ì[ŸJ[›‘ô\›[YNàùYJN¬à⁄\–]]–Yò[ò⁄[ô»H]]–Yò[òŸN¬àö[ò[ô\€€ôY^[\›H^[\›¬àö[ò[›]€€YHH]ÿZ]ô\]Y\›ò][\
à

HOà‹›⁄]⁄‘€›\òŸT^[\›
à€›\òŸR[ô^àô\€€ôY^[\›à\ôŸ]ŸX\€€éàŸX\€€ãà\ôŸ]\\€ŸNà\\€ŸKà›\ô\‹‘ô\›[YNà]]–Yò[òŸH⁄YôõQŸ[ô\ò][€àOHù[àô\]Y\›àô\]Y\›à
Kà
N¬àYà
›]€€YHOH\\€ŸT^XòX⁄”›]€€YKò€€[Z]Y	âÇà[›[ùY	âÇàô\]Y\›ö\–›\úô[ù
H¬àö[ò[ô]Z[ôYHŸ\öY\‘€›\òŸQô]⁄\ãúô]Z[ëõ‹ë\\€ŸJàŸYôôX›]ôT€›\òŸ\»œ»€€ú›‹úô[ùñ◊KàŸX\€€ãà\\€ŸKà
N¬àò\àô]Z[ôY[ô^Hô]Z[ôYö[ô^⁄\ôJ
€›\òŸJHOàY[ùXÿ[
€›\òŸK
JN¬àô]Z[ôY[ô^Hô]Z[ôY[ô^èHà»ô]Z[ôY[ô^ààô]Z[ôYö[ô^⁄\ôJà
€›\òŸJHOÇàŸ\öY\‘€›\òŸQô]⁄\ãú€›\òŸRŸ^J€›\òŸJHOBàŸ\öY\‘€›\òŸQô]⁄\ãú€›\òŸRŸ^J
Kà
N¬àYà
ô]Z[ôY[ô^èH
H¬àŸ]›]J

H¬àÿ]Y€Y[ùY€›\òŸ\»Hô]Z[ôY¬àÿ›\úô[ù€›\òŸR[ô^Hô]Z[ôY[ô^¬àJN¬àBàBàŸ‘€›\òŸTŸ[X›[€äà	€ô^Ÿ\\€ŸWÿÿ[ôY]W€›]€€YIÀà€›\òŸNàà[ô^à€›\òŸR[ô^àŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà^Y\éà	€\âÀàôX\€€éà›]€€YKõò[YKà
N¬àô]\õà›]€€YN¬àBÇàÀÀ»H\\€ŸHYòXŸ[ù»
ŸX\€€ã\\€ŸJH[àH⁄›…‹»ù[ìX^ôBàÀÀ»\›
‹X⁄X[»^€YY
N»ù[⁄[à[ö€õ›€à‹à›]Ÿàò[ôŸKÇà
[ù[ù
O»ÿYòXŸ[ù\\€ŸJ[ùŸX\€€ã[ù\\€ŸK[ù\ôX›[€äH¬àö[ò[ù[H‹Ÿ\öY\‘^[\›Àôù[õX^ôQ\\€Ÿ\Àö\”õ›[\HOHùYBà»‹Ÿ\öY\‘^[\›Kôù[õX^ôQ\\€Ÿ\¬àà
‹ﬁ[ù]X—›ZYT^[\›Àôù[õX^ôQ\\€Ÿ\»œ¬à€€ú›X\›ö[ôÀ[ò[ZXœèñ◊JN¬àYà
ù[ö\—[\JHô]\õàù[¬àö[ò[\»H
[ù[ù
Oñ¬àõ‹à
ö[ò[H[àù[
BàYà
V…‹ŸX\€€â◊H\»[ù	âÇàV…€ù[Xô\â◊H\»[ù	âÇà
V…‹ŸX\€€â◊H\»[ù
Hà
Bà

V…‹ŸX\€€â◊H\»[ù
K
V…€ù[Xô\â◊H\»[ù
JKàKãú€‹ù

KäHOàKâHOHãâH»KâHHãâHàKâàHãâäN¬àö[ò[YH\Àö[ô^⁄\ôJ

HOàâHOHŸX\€€à	âàâàOH\\€ŸJN¬àYà
Y
Hô]\õàù[¬àö[ò[\ôŸ]HY
»\ôX›[€é¬àYà
\ôŸ]\ôŸ]èH\Àõ[ô›
Hô]\õàù[¬àô]\õà\÷›\ôŸ]N¬àBÇàõ⁄Y‹ô\\ôSô^\ôX›\\€ŸJ
H¬àö[ò[ô]⁄\àH⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\é¬àö[ò[€›\òŸ\»HŸYôôX›]ôT€›\òŸ\Œ¬àYà
ô]⁄\àOHù[à›ò[Y][€ëÿ]PX›]ôHàW⁄\‘^Z[ô»à⁄\’ò[ú⁄][€ö[ô»à€›\òŸ\»OHù[àÿ›\úô[ù€›\òŸR[ô^àÿ›\úô[ù€›\òŸR[ô^èH€›\òŸ\Àõ[ô›
Bàô]\õé¬àö[ò[›\úô[ùHÿ›\úô[ùŸX\€€ë\\€ŸQõ‹íY[ù]J
N¬àYà
›\úô[ùOHù[
Hô]\õé¬à[ò]ÿZ]Y
àô]⁄\ãúô\\ôQúõ€TõŸ‹ô\‹ à€›\òŸNà€›\òŸ\÷◊ÿ›\úô[ù€›\òŸR[ô^KàŸX\€€éà›\úô[ùúŸX\€€ãà\\€ŸNà›\úô[ùô\\€ŸKà‹⁄][€ì\Œà‹‹⁄][€ãö[ìZ[\ŸX€€ôÀà\ò][€ì\ŒàŸ\ò][€ãö[ìZ[\ŸX€€ôÀà
Kà
N¬àBÇàù]\ôOõ⁄Yà‹⁄›‘^[\›⁄Y]
ùZ[€€ù^€€ù^
H\ﬁ[ò»¬àò\à^[\›HÿX›]ôT^[\›œ»€€ú›^[\›[ùûOñ◊N¬àò\àŸ\öY\‘^[\›H‹Ÿ\öY\‘^[\›¬àò\à›\úô[ù[ô^Hÿ›\úô[ù[ô^¬àö[ò[ÿ[ëô]⁄Hÿÿ[ëô]⁄\\€Ÿ\Œ¬àYà
^[\›ö\—[\H	âàÿ[ëô]⁄
H¬àÀ»⁄[ô€H›ôX[H⁄]›]H^[\›àòX⁄»H›ZYH⁄]Hﬁ[ù]X¬àÀ»KY[ùûH^[\›€»Hù[\\€ŸH\›ÿ[àô[ô\ãÇàö[ò[ﬁ[ù]X»HÿùZ[ﬁ[ù]X—›ZYJ
N¬àYà
ﬁ[ù]X»OHù[
Hô]\õé¬àŸ\öY\‘^[\›Hﬁ[ù]XÀâN¬à^[\›Hﬁ[ù]XÀâé¬à›\úô[ù[ô^H¬àBàYà
Ÿ\öY\‘^[\›OHù[	âàŸ\öY\‘^[\›ö\‘Ÿ\öY\ H¬àŸ\\€ŸSY]Y]TôXYHœœH‹ô[ÿY\\€ŸR[ôõ 
N¬àBà]ÿZ]^[\›⁄Y]ú⁄› à€€ù^à^[\›à^[\›à›\úô[ù[ô^à›\úô[ù[ô^àŸ\öY\‘^[\›àŸ\öY\‘^[\›à^[\›][Q]Nàÿ€€ú›ùX›^[\›][Q]J
Kà[YíYàŸ\öY\‘^[\›Àö[YíYœ»ÿ›\úô[ùŸ\öY\“[YíYà[Yí€õ›€ê]][ò⁄à‹Ÿ\öY\“[Yí€õ›€ê]][ò⁄àY]Y]TôXYNàŸ\\€ŸSY]Y]TôXYKàöY]”[ŸNà⁄YŸ]ùöY]”[ŸKà€îŸ[X›à
[ô^ÿõ€€[›‘ô\›[YHHò[Ÿ_JH\ﬁ[ò»¬àÀ»ﬁ[ù]X»›ZYNà]»€õH^[\›õ›»T»H^Z[ô»›ôX[KÇàYà
ÿX›]ôT^[\›OHù[ÿX›]ôT^[\›Kö\—[\JHô]\õé¬à‹Ÿ]X[ùX[Ÿ[X›[€ì[ŸJ[›‘ô\›[YNà[›‘ô\›[YJN¬à]ÿZ]€ÿY^[\›[ô^
[ô^]]‹^NàùYJN¬àKà€ëô]⁄\\€ŸNàÿ[ëô]⁄»Ÿô]⁄[ô^Q\\€ŸHàù[à
N¬àBÇà›ô\úöYBà⁄YŸ]ùZ[
ùZ[€€ù^€€ù^
H¬àö[ò[\‘ôXYHH⁄\‘ôXYN¬àÀ»[àHT⁄[ô›ÀYH]ô\ûH[ù\òX›]ôKŸX€‹ò]]ôH^Y\à€»€õHBàÀ»öY[»^\ôH
[ôHùYôô\ö[ô»‹[õô\äH⁄›‹Ààô\›‹ô\»€à^]Çàö[ò[[î\H⁄\‘\X›]ôN¬Çàô]\õàÿÿYôõ€
àòX⁄Ÿ‹õ›[ô€€‹éà€€‹úÀòõX⁄ÀàõŸNàÿYôP\ôXJàYùàò[ŸKà‹àò[ŸKàöY⁄àò[ŸKàõ›€Nàò[ŸKà⁄[àõÿ›\ àõÿ›\”õŸNà›îõ€›õÿ›\Àà]]Ÿõÿ›\ŒàùYKà€íŸ^Nà
õŸK]ô[ù
H¬àYà
]ô[ù\»Hò]“Ÿ^Q›€ë]ô[ù
Hô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àö[ò[Ÿ^HH]ô[ùõŸ⁄Xÿ[Ÿ^N¬ÇàÀ»[öYöYYY[ùH\»‹[ãàZŸHHTà⁄Y]]›€ú»]ô\ûHŸ^BàÀ»[ò€Y[ô»êP“»
ò[Y\»OàòZ[Oà€‹ŸK⁄]ì›ô\õ^PòX⁄¬àÀ»X\ö⁄[ô»H€‹⁄[ô»ô\‹ N»]»Ÿ^Xõÿ\ô\›[ô\à€»õÿ›\ÀÇàYà
‹⁄›‘^Y\ìY[ùJH¬àô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»ﬁ[ò»›ô\õ^H\»‹[àH[ôH]»Ÿ^\»ö\ú›àYà
‹⁄›‘ﬁ[ò”›ô\õ^JH¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô€–òX⁄ H¬à⁄YTﬁ[ò”›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»⁄[õô[›ZYH\»‹[àH[ôH]»Ÿ^\»ö\ú›àYà
‹⁄›–⁄[õô[›ZYJH¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô€–òX⁄ H¬à⁄YP⁄[õô[›ZYS›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàÀ»]⁄[õô[›ZYH[ôH›\àŸ^\¬àô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»Tà⁄[õô[⁄Y]\»‹[ãà]›€ú»êP“»]Ÿ[à∫w^~)ﬁuúõ€HBàÀ»ÿ⁄Y[H[ôH]ô]\õú»»⁄[õô[»ò]\à[à€‹⁄[ôÀ[ôàÀ»€‹⁄[ô»ô\›‹ô\»HŸX\ò⁄Z[ù\úù\Yÿ]Y€‹ûKà[ô[ô»êP“¬àÀ»\ôH\»Ÿ[ö\ôYõ›àH⁄Y]⁄[ôŸY[ôH[ô\»€‹ŸYàÀ»]à]»Ÿ^Xõÿ\ô\›[ô\à€»õÿ›\»
]€Z[\»]€à[›[ù
K€¬àÀ»]ô\ûHŸ^H[ò€Y[ô»êP“»ôXX⁄\»]ö\ú›ÇàYà
‹⁄›“\ê⁄[õô[⁄Y]
H¬àô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»€›\òŸH⁄Y]\»‹[àH[ôH]»Ÿ^\»ö\ú›àYà
‹⁄›‘€›\òŸT⁄Y]
H¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô€–òX⁄ H¬à⁄YT€›\òŸT⁄Y]

N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàÀ»]€›\òŸH⁄Y][ôH›\àŸ^\¬àô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»›ô[Z[»à›ZYH\»‹[àH[ôH]»Ÿ^\»ö\ú›àYà
‹⁄›‘›ô[Z[’ë›ZYJH¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô€–òX⁄ H¬à⁄YT›ô[Z[’ë›ZYJ
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàÀ»]›ZYH⁄Y][ôH›\àŸ^\¬àô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àBÇàÀ»KKKH[]ö\⁄[€àô[[›HKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBàÀ»]ô\û][ô»ô[›»ÿ\»‹ö][àõ‹àH\⁄›‹Ÿ^Xõÿ\ôà]\úÀàÀ»õ€[YH€àT—’”ã\úõ›‹»][ÿ^\»ŸYZÀàHô[[›H\»õ¬àÀ»]\úÀ]»“»\úö]ô\»\»[ù\ò[ô⁄[HHò\à\»\BàÀ»Qô[€ô‹»»Hò\ãàZ\úõ‹ú»Hò]]ôH[ôõ⁄Yà^Y\à€¬àÀ»õ›^Y\ú»ôZ]ôHHÿ[YKà›X⁄[ô\⁄›‹ô]ô\à[ù\à\ôKÇàYà
]õ‹õU][ö\’[]ö\⁄[€äH¬àö[ò[îô\›[H⁄[ôUíŸ^JŸ^JN¬àYà
îô\›[OHù[
Hô]\õàîô\›[¬àBÇàÀ»HOà\‹X›ò][¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^PJH¬àÿﬁX€P\‹X›[ŸJ
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»»Oà⁄[õô[›ZYH
XúöYûHà‹à›ô[Z[»äBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^Q H¬àYà
ÿ⁄[õô[[ùöY\Àö\”õ›[\H	âÇà⁄YŸ]úô\]Y\›⁄[õô[ûRYOHù[
H¬à‹⁄›–⁄[õô[›ZYS›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàYà
⁄\‘›ô[Z[’ë›ZYJH¬à‹⁄›‘›ô[Z[’ë›ZYS›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàYà
ŸYôôX›]ôR\ê⁄[õô[œÀö\”õ›[\HOHùYJH¬à‹⁄›“\ê⁄[õô[⁄Y]›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBÇàÀ»»OàTà⁄[õô[⁄Y]àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^P H¬àYà
ŸYôôX›]ôR\ê⁄[õô[œÀö\”õ›[\HOHùYJH¬à‹⁄›“\ê⁄[õô[⁄Y]›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBÇàÀ»»Oà›ô[Z[»€›\òŸH⁄Y]àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^T H¬àYà
ŸYôôX›]ôT€›\òŸ\»OHù[	âÇàŸYôôX›]ôT€›\òŸ\»Kö\”õ›[\H	âÇà
ŸYôôX›]ôTô\€€ô\àOHù[à⁄YŸ]úô\€€ôT€›\òŸU‘^[\›OHù[
JH¬à‹⁄›‘€›\òŸT⁄Y]›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBÇàÀ»‹XŸHOà]\ŸHô\›[YBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kú‹XŸJH¬à›ŸŸ€T^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»\\úõ›»Oà⁄[õô[›ZYH
Yà⁄[õô[»]òZ[XõJH‹àõ€[YBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›’\
H¬àÀ»Yà⁄[õô[»\ôH]òZ[XõK⁄›»⁄[õô[›ZYBàYà
ÿ⁄[õô[[ùöY\Àö\”õ›[\H	âÇà⁄YŸ]úô\]Y\›⁄[õô[ûRYOHù[
H¬à‹⁄›–⁄[õô[›ZYS›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàÀ»›ô[Z[»à›ZYBàYà
⁄\‘›ô[Z[’ë›ZYJH¬à‹⁄›‘›ô[Z[’ë›ZYS›ô\õ^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»›\ù⁄\ŸK€€ùõ€õ€[YBàÿ€€ùõ€’ö\⁄XõKùò[YHHùYN¬à‹ÿ⁄Y[P]]“YJ
N¬ÇàÀ»[ò‹ôX\ŸHõ€[YBàö[ò[›\úô[ùõ€[YHH
‹^Y\ãú›]Kùõ€[YH»Lå
Kò€[\
àåàKåà
N¬àö[ò[ô]’õ€[YHH
›\úô[ùõ€[YH
»åJKò€[\
åKå
N¬à‹^Y\ãúŸ]õ€[YJ
ô]’õ€[YH
àL
Kò€[\
åLå
JN¬ÇàÀ»⁄›»õ€[YHQà›ô\ùXÿ[Yùò[YHHô\ùXÿ[Y›]Jà⁄[ôàô\ùXÿ[⁄[ôùõ€[YKàò[YNàô]’õ€[YKà
N¬àù]\ôKô[^YY
€€ú›\ò][€äZ[\ŸX€€ôŒàçL
K

H¬àYà
[›[ùY
H¬à›ô\ùXÿ[Yùò[YHHù[¬àBàJN¬Çàô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›—›€äH¬àÀ»⁄›»€€ùõ€»ö\ú›àÿ€€ùõ€’ö\⁄XõKùò[YHHùYN¬à‹ÿ⁄Y[P]]“YJ
N¬ÇàÀ»X‹ôX\ŸHõ€[YBàö[ò[›\úô[ùõ€[YHH
‹^Y\ãú›]Kùõ€[YH»Lå
Kò€[\
àåàKåà
N¬àö[ò[ô]’õ€[YHH
›\úô[ùõ€[YHHåJKò€[\
åKå
N¬à‹^Y\ãúŸ]õ€[YJ
ô]’õ€[YH
àL
Kò€[\
åLå
JN¬ÇàÀ»⁄›»õ€[YHQà›ô\ùXÿ[Yùò[YHHô\ùXÿ[Y›]Jà⁄[ôàô\ùXÿ[⁄[ôùõ€[YKàò[YNàô]’õ€[YKà
N¬àù]\ôKô[^YY
€€ú›\ò][€äZ[\ŸX€€ôŒàçL
K

H¬àYà
[›[ùY
H¬à›ô\ùXÿ[Yùò[YHHù[¬àBàJN¬Çàô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»Ÿ[ù\ã—[ù\àŸŸ€\»^H‹à⁄›‹»€€ùõ€¬àYà
\–X›]ò]RŸ^JŸ^JJH¬àYà
ÿ€€ùõ€’ö\⁄XõKùò[YJH¬à›ŸŸ€T^J
N¬àH[ŸH¬à›ŸŸ€P€€ùõ€ 
N¬àBàô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»QYù‹öY⁄ò\⁄[õô[»€àH]ôH⁄[õô[⁄]H€€ùõ€¬àÀ»Y[à.ù◊üäwùHÿ[YH€€ùòX›\»Hò]]ôH^Y\â‹¬àÀ»\”]ôR\ñò\€€ù^

Kà\ôH\»õ›[ô»»ŸYZ»€àH]ôBàÀ»›ôX[K[ô⁄]Hÿ⁄»\\ŸHŸ^\»ô[€ô»»]»ù]€úÀÇàYà
ÿÿ[ñò\\ê⁄[õô[	âàWÿ€€ùõ€’ö\⁄XõKùò[YJH¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›‘öY⁄
H¬àﬁò\\ê⁄[õô[
JN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›”Yù
H¬àﬁò\\ê⁄[õô[
LJN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBÇàÀ»QYù‹öY⁄ŸYZ»L¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›”YùàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXTô]⁄[ô
H¬àö[ò[ÿ[ôY]HBà‹‹⁄][€àHöY[‘^Y\ï[Z[ô–€€ú›[ùÀúŸYZ—[N¬àö[ò[ô]‘‹»Hÿ[ôY]H\ò][€ãûô\õ¬à»\ò][€ãûô\õ¬àà
ÿ[ôY]HàŸ\ò][€à»Ÿ\ò][€ààÿ[ôY]JN¬à‹^Y\ãúŸYZ ô]‘‹ N¬à›òZ›ÿ‹õÿòõTŸYZ ô]‘‹ N¬à‹⁄[Z€ÿ‹õÿòõTŸYZ ô]‘‹ N¬à€Yõ\›ÿ‹õÿòõTŸYZ ô]‘‹ N¬àÀ»€â›⁄›»€€ùõ€»‹à[ûH›ô\õ^Hõ‹àŸ^Xõÿ\ôŸYZ⁄[ô¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò\úõ›‘öY⁄àŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXQò\›õ‹ùÿ\ô
H¬àö[ò[ÿ[ôY]HBà‹‹⁄][€à
»öY[‘^Y\ï[Z[ô–€€ú›[ùÀúŸYZ—[N¬àö[ò[ô]‘‹»Hÿ[ôY]H\ò][€ãûô\õ¬à»\ò][€ãûô\õ¬àà
ÿ[ôY]HàŸ\ò][€à»Ÿ\ò][€ààÿ[ôY]JN¬à‹^Y\ãúŸYZ ô]‘‹ N¬à›òZ›ÿ‹õÿòõTŸYZ ô]‘‹ N¬à‹⁄[Z€ÿ‹õÿòõTŸYZ ô]‘‹ N¬à€Yõ\›ÿ‹õÿòõTŸYZ ô]‘‹ N¬àÀ»€â›⁄›»€€ùõ€»‹à[ûH›ô\õ^Hõ‹àŸ^Xõÿ\ôŸYZ⁄[ô¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»YYXH^K‹]\ŸHŸ^\¬àYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXT^T]\ŸHàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXT^HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXT]\ŸJH¬à›ŸŸ€T^J
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»àŸ^Hõ‹àô^\\€ŸH
XX BàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^SäH¬àYà
⁄\–[ûSô^
H¬àŸ€’”ô^\\€ŸJ
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBÇàÀ»à»åLNàŸŸ€Hù[ÿ‹ôY[à€à⁄[ô›‹À”[ù^àYà

Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KöŸ^QààŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KôåLJH	âÇà
]õ‹õKö\’⁄[ô›‹»]õ‹õKö\”[ù^
JH¬à⁄[ô›”X[òYŸ\ãö\—ù[ÿ‹ôY[ä
Kù[ä
\—ù[ÿ‹ôY[äH¬àYà
[[›[ùY
Hô]\õé¬à⁄[ô›”X[òYŸ\ãúŸ]ù[ÿ‹ôY[äZ\—ù[ÿ‹ôY[äN¬àJN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»[à›ô\õ^H€‹ŸY]Ÿ[à€à\»ô\ûHêP“»ô\‹»
ŸYBàÀ»’ì›ô\õ^PòX⁄◊JNàHô\‹»\»[ôXYH‹[ù€»]]\›õ›àÀ»[€»]Z]H^Y\ãÇàYà

Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\HàŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô€–òX⁄ H	âÇà€›ô\õ^Rù\›€‹ŸY
H¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»\ÿÿ\HŸ^Nà^]ù[ÿ‹ôY[àö\ú›[à]Z]H^Y\ÇàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kô\ÿÿ\JH¬àÀ»€à⁄[ô›‹À”[ù^\⁄›‹^]ù[ÿ‹ôY[àö\ú›Yà[àù[ÿ‹ôY[ÇàYà
]õ‹õKö\’⁄[ô›‹»]õ‹õKö\”[ù^
H¬à⁄[ô›”X[òYŸ\ãö\—ù[ÿ‹ôY[ä
Kù[ä
\—ù[ÿ‹ôY[äH¬àYà
[[›[ùY
Hô]\õé»À»ÿYô]H⁄X⁄»õ‹à\ﬁ[ò»ÿ[òX⁄¬àYà
\—ù[ÿ‹ôY[äH¬àÀ»^]ù[ÿ‹ôY[àù]€â›]Z]H^Y\Çà⁄[ô›”X[òYŸ\ãúŸ]ù[ÿ‹ôY[äò[ŸJN¬àH[ŸH¬àÀ»õ›[àù[ÿ‹ôY[ã]Z]H^Y\Çàò]öYÿ]‹ãõŸä€€ù^
Kú‹

N¬àBàJN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàÀ»€à›\à]õ‹õ\»
[ÿö[KXX”‘ Kù\›]Z]àò]öYÿ]‹ãõŸä€€ù^
Kú‹

N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBÇàÀ»ô^‘ô]ö[›\»\\€ŸHò]öYÿ][€ÇàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXT⁄⁄\õ‹ùÿ\ô
H¬àYà
⁄\–[ûSô^
H¬àŸ€’”ô^\\€ŸJ
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KõYYXT⁄⁄\òX⁄›ÿ\ô
H¬àYà
⁄\‘ô]ö[›\—\\€ŸJ
JH¬àŸ€’‘ô]ö[›\—\\€ŸJ
N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò⁄[õô[\àŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KúYŸU\
H¬àYà
ÿÿ[ñò\\ê⁄[õô[
H¬àﬁò\\ê⁄[õô[
JN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàYà
⁄YŸ]úô\]Y\›ô^⁄[õô[OHù[
H¬àŸ€’”ô^⁄[õô[

N¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBàYà
Ÿ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^Kò⁄[õô[›€ààŸ^HOHŸ⁄Xÿ[Ÿ^Xõÿ\ôŸ^KúYŸQ›€äH¬àYà
ÿÿ[ñò\\ê⁄[õô[
H¬àﬁò\\ê⁄[õô[
LJN¬àô]\õàŸ^Q]ô[ùô\›[ö[ôY¬àBàBàô]\õàŸ^Q]ô[ùô\›[öY€õ‹ôY¬àKà⁄[àò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNàÿ€€ùõ€’ö\⁄XõKà⁄[à›X⁄ àö]à›X⁄—ö]ô^[ôà⁄[ô[éà¬àÀ»öY[»^\ôH
YYXW⁄⁄]ô[ô\ô\äBàYà
\‘ôXYH	âàW⁄\’ò[ú⁄][€ö[ô BàŸŸ]›\›€P\‹X›ò][ 
HOHù[à»ÿùZ[›\›€P\‹X›ò][’öY[ 
BààZ›ãïöY[ àŸ^Nàò[YRŸ^Jà	›öY[◊Ÿ[]ò][€ó…◊‹›Xù]TŸ][ô‹œÀô[]ò][€í[ô^œ»IÀà
Kà€€ùõ€\éà›öY[–€€ùõ€\ãà]\ŸU\€ë[ù\ö[ô–òX⁄Ÿ‹õ›[ô[ŸNàT]õ‹õKö\“S‘Àà€€ùõ€Œàù[àö]àÿ›\úô[ùö]

Kà›Xù]UöY]–€€ôöY›\ò][€éàÿùZ[›Xù]UöY]–€€ôöY 
Kà
Bà[ŸHYà
⁄\’ò[ú⁄][€ö[ô BàÀ»õX⁄»ÿ‹ôY[à\ö[ô»ò[ú⁄][€ú»»YHô]ö[›\»úò[YBà€€ùZ[ô\ä€€‹éà€€‹úÀòõX⁄ Bà[ŸBà€€ú›Ÿ[ù\äà⁄[à⁄\ò›[\îõŸ‹ô\‹“[ôXÿ]‹ä€€‹éà€€‹úÀù⁄]JKà
KàÀ»õ€ã\›\ù\ò[ú⁄][€ú»›[\ŸHH^\›[ô»ÿY[ô»RKÇàYà
‹òZ[òõ›–X›]ôJHÿùZ[ò[ú⁄][€ì›ô\õ^J
KàYà
‹⁄›‘›ô[Z[’ìô^ÿY[ô BàÿùZ[›ô[Z[’ìô^ÿY[ô”›ô\õ^J
KàÀ»›XõK]\ö\BàYà
‹ö\HOHù[
BàY€õ‹ôT⁄[ù\äà⁄[à›\›€TZ[ù
àZ[ù\éà›XõU\ö\TZ[ù\ä‹ö\HJKà
Kà
KàÀ»Q¬àò[YS\›[òXõPùZ[\èŸYZ“Y›]Oœäàò[YS\›[òXõNà‹ŸYZ“YàùZ[\éà
€€ù^Y H¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]NàYOHù[»àKà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàLå
Kà⁄[àŸ[ù\äà⁄[àYOHù[à»€€ú›⁄^ôYõﬁú⁄ö[ö 
BààŸYZ“Y
YàYõ‹õX]àŸõ‹õX]
Kà
Kà
Kà
N¬àKà
Kàò[YS\›[òXõPùZ[\èô\ùXÿ[Y›]Oœäàò[YS\›[òXõNà›ô\ùXÿ[YàùZ[\éà
€€ù^Y H¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]NàYOHù[»àKà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàLå
Kà⁄[à[Y€äà[Y€õY[ùà[Y€õY[ùòŸ[ù\îöY⁄à⁄[àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àõ€õJöY⁄àç
Kà⁄[àYOHù[à»€€ú›⁄^ôYõﬁú⁄ö[ö 
Bààô\ùXÿ[Y
YàY
Kà
Kà
Kà
Kà
N¬àKà
Kàò[YS\›[òXõPùZ[\è\‹X›ò][“Y›]Oœäàò[YS\›[òXõNàÿ\‹X›ò][“YàùZ[\éà
€€ù^Y H¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]NàYOHù[»àKà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàå
Kà⁄[à[Y€äà[Y€õY[ùà[Y€õY[ùù‹öY⁄à⁄[àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àõ€õJ‹àöY⁄àç
Kà⁄[àYOHù[à»€€ú›⁄^ôYõﬁú⁄ö[ö 
Bàà\‹X›ò][“Y
YàY
Kà
Kà
Kà
Kà
N¬àKà
Kàò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNà‹‹YY€YàùZ[\éà
€€ù^X›]ôK H¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]NàX›]ôH»Hàà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàML
Kà⁄[à[Y€äà[Y€õY[ùà[Y€õY[ùù‹Ÿ[ù\ãà⁄[àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àõ€õJ‹à
Kà⁄[à€€ùZ[ô\äàY[ôŒà€€ú›YŸR[úŸ]Àúﬁ[[Y]öX à‹ö^õ€ù[àåàô\ùXÿ[àLãà
KàX€‹ò][€éàõﬁX€‹ò][€äà€€‹éà€€‹úÀòõX⁄Àù⁄]ò[Y\ [Nàç Kàõ‹ô\îòY]\Œàõ‹ô\îòY]\Àò⁄\ò›[\äMäKàõﬁ⁄Y›Œà¬àõﬁ⁄Y› à€€‹éà€€‹úÀòõX⁄Àù⁄]ò[Y\ [Nàå Kàõ\îòY]\ŒàLãàŸôúŸ]à€€ú›ŸôúŸ]

Kà
KàKà
Kà⁄[à€€ú›õ› àXZ[ê^\‘⁄^ôNàXZ[ê^\‘⁄^ôKõZ[ãà⁄[ô[éà¬àX€€äàX€€úÀôò\›Ÿõ‹ùÿ\ô‹õ›[ôYà€€‹éà€€‹úÀù⁄]Kà⁄^ôNàåà
Kà⁄^ôYõﬁ
⁄Yà
Kà^
à	Ãµ»‹YY	Àà›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kàõ€ù⁄^ôNàMãàõ€ùŸZY⁄àõ€ùŸZY⁄ùÕåà
Kà
KàKà
Kà
Kà
Kà
Kà
Kà
N¬àKà
KàÀ»›Xù]H]]À\ﬁ[ò»€›[ù›€à[à]ZY]õ›€K\öY⁄€\‹ÀàÀ»\‹^K[€õK›]⁄YHH›Xù]HôXY[ô»õ€ôKààŸY\»]àÀ»[ú⁄YHH›ô\úÿÿ[àÿYôH\ôXKÇàò[YS\›[òXõPùZ[\è]]‘ﬁ[ò‘[[Ÿ[œäàò[YS\›[òXõNàÿ]]‘ﬁ[ò‘[àùZ[\éà
€€ù^[Ÿ[ H¬àYà
[Ÿ[OHù[
Hÿ]]‘ﬁ[ò‘[\›⁄›€àH[Ÿ[¬àÀ»òYH›]›ô\àHT’⁄›€à[Ÿ[.ù◊üäwù›ÿ\[ô»»[ÇàÀ»[\Hõﬁ\ôH€›[XZŸHH\€Z\‹»òYH[ùö\⁄XõKÇàö[ò[\‹^HH[Ÿ[œ»ÿ]]‘ﬁ[ò‘[\›⁄›€é¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]Nà[Ÿ[OHù[»àKà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàÕL
Kà›\ùôNà›\ùô\ÀôX\ŸS›]›XöXÀà⁄[à[Y€äà[Y€õY[ùà[Y€õY[ùòõ›€TöY⁄à⁄[àY[ô àY[ôŒàYŸR[úŸ]Àõ€õJàöY⁄à]]‘ﬁ[ò‘[ò€‹õô\í[úŸ]àõ›€Nà]]‘ﬁ[ò‘[ò€‹õô\í[úŸ]à
Kà⁄[à\‹^HOHù[à»€€ú›⁄^ôYõﬁú⁄ö[ö 
Bàà]]‘ﬁ[ò‘[
[Ÿ[à\‹^JKà
Kà
Kà
Kà
N¬àKà
KàÀ»Tà]ôHôX€€õôX›[
\ŸHHŸàHô\⁄[Y[òŸH[äNÇàÀ»€õHHôX€›ô\ûH\\€ŸH]\»ù[àåú»⁄›‹»]∫w^~)ﬁuBàÀ»[ùö\⁄XõHò\›ôX€€õôX›»›^H[ùö\⁄XõKÇàò[YS\›[òXõPùZ[\è›ö[ôœœäàò[YS\›[òXõNà⁄\îôX€€õôX›^àùZ[\éà
€€ù^^ H¬àô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]Nà^OHù[»Hàà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàML
Kà⁄[à[Y€äà[Y€õY[ùà[Y€õY[ùòõ›€PŸ[ù\ãà⁄[àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àõ€õJõ›€NàMäKà⁄[à€€ùZ[ô\äàY[ôŒà€€ú›YŸR[úŸ]Àúﬁ[[Y]öX à‹ö^õ€ù[àåàô\ùXÿ[àLà
KàX€‹ò][€éàõﬁX€‹ò][€äà€€‹éà€€‹úÀòõX⁄Àù⁄]ò[Y\ [Nàç Kàõ‹ô\îòY]\Œàõ‹ô\îòY]\Àò⁄\ò›[\äåäKà
Kà⁄[à^
à^œ»	…Àà›[Nà€€ú›^›[Jà€€‹éà€€‹úÀù⁄]Kàõ€ù⁄^ôNàMKàõ€ùŸZY⁄àõ€ùŸZY⁄ùÕåà
Kà
Kà
Kà
Kà
Kà
Kà
N¬àKà
KàÀ»ùYôô\ö[ô»[ôXÿ]‹à
’\›[HŸ[ù\ôY‹[õô\äBàò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNà‹⁄›–ùYôô\ö[ô“[ôXÿ]‹ãàùZ[\éà
€€ù^⁄›À H¬àÀ»H›\ù\ÿ]H\»]»›€à‹[õô\à[ô^[ò]‹ûBàÀ»›]\ÀàŸY\[ô»H‹ô[ò\ûHùYôô\ö[ô»[ôXÿ]‹àXõ›ôBàÀ»]õŸXŸ\»€»›ô\õ\[ô»ÿY\ú»⁄[Hÿ[ôY]\¬àÀ»\ôHôZ[ô»ôZôX›Y[ôô]öYYÇàYà
‹›\ù\ÿ]PX›]ôH	âàW‹›\ù\ÿ]S›ô\õ^RY[äH¬àô]\õà€€ú›⁄^ôYõﬁú⁄ö[ö 
N¬àBàô]\õàY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]Nà⁄›»»Hàà\ò][€éà⁄›¬à»€€ú›\ò][€äZ[\ŸX€€ôŒàçL
Bàà€€ú›\ò][€äZ[\ŸX€€ôŒàå
Kà⁄[à€€ú›Ÿ[ù\ä⁄[àùYôô\ö[ô“[ôXÿ]‹ä
JKà
Kà
N¬àKà
KàÀ»ù[\ÿ‹ôY[àŸ\›\ôH^Y\à
XŸYô[›»€€ùõ€ BàYà
Z[î\
BàŸ\›\ôQ]X›‹äàôZ]ö[‹éà]\›ôZ]ö[‹ãùò[ú€XŸ[ùà€ï\›€éà

HOà€\›\ÿÿ[Hõÿÿ[‹⁄][€ãà€ï\à

H¬àÀ»\ÿXõH⁄[ô€H\⁄[àõ›òX⁄»ù]€à[ô‹[€ú»\ôHY[ÇàYà
⁄YŸ]öYPòX⁄–ù]€à	âà⁄YŸ]öYS‹[€ú H¬àô]\õé¬àBàö[ò[õﬁH€€ù^ôö[ôô[ô\ìÿöôX›

H\»ô[ô\êõﬁŒ¬àYà
õﬁOHù[
Hô]\õé¬àö[ò[⁄^ôHHõﬁú⁄^ôN¬àö[ò[‹»H€\›\ÿÿ[œ»ŸôúŸ]ûô\õŒ¬àYà
⁄›[ŸŸ€Qõ‹ï\
à‹Àà⁄^ôKà€€ùõ€’ö\⁄XõNàÿ€€ùõ€’ö\⁄XõKùò[YKàõ›€Pò\éàŸÿ⁄–ò[ô
Ããå
Kà
JH¬à›ŸŸ€P€€ùõ€ 
N¬àBàKà€ë›XõU\›€éà⁄[ôQ›XõU\à€ì€ô‘ô\‹‘›\ùà€€ì€ô‘ô\‹‘›\ùà€ì€ô‘ô\‹—[ôà€€ì€ô‘ô\‹—[ôà€î[î›\ùà€€î[î›\ùà€î[ï\]Nà€€î[ï\]Kà€î[ë[ôà€€î[ë[ôà
KàÀ»Xõ›ôHHŸ\›\ôH^Y\éà›\ù\Y\»õ‹õX[€€ùõ€Àù]àÀ»X]ö[ô»H^Y\à]\›ô[XZ[à]òZ[XõH⁄[H[ö‹»ô\€€ôKÇàYà
‹›\ù\ÿ]PX›]ôH	âàW‹›\ù\ÿ]S›ô\õ^RY[äBà‹⁄][€ôYôö[
à⁄[à[î\àÀ»T]\›õ›ô]ôX[ÿ[ôY]\»ôYõ‹ôHò[Y][€à›XÿŸYYÀÇàÀ»õ»€€ùõ€Àõÿ›\À‹àŸ\›\ô\»[àH€€\X›⁄Y[Çà»€€ú›Xú€‹òî⁄[ù\äà⁄[à€€‹ôYõﬁ
€€‹éà€€‹úÀòõX⁄ Kà
Bàà^XòX⁄‘›\ù\öY] à]Nà⁄YŸ]ò€€ù[ù]Hœ»⁄YŸ]ù]Kà\\€ŸNÇà⁄YŸ]ò€€ù[ù\HOH	‹Ÿ\öY\…»	âÇà⁄YŸ]ò€€ù[ùŸX\€€àOHù[	âÇà⁄YŸ]ò€€ù[ù\\€ŸHOHù[à»	‘ŸX\€€à	›⁄YŸ]ò€€ù[ùŸX\€€üH-»\\€ŸH	›⁄YŸ]ò€€ù[ù\\€Ÿ_I¬ààù[à]Z[Œà‹›\ù\ÿ]SY\‹ÿYŸKàô]ûZ[ôŒà‹›\ù\ÿ]SY\‹ÿYŸKú›\ù’⁄]
à	‘›ôX[H[ò]òZ[XõIÀà
Kà€êòX⁄Œà⁄YŸ]öYPòX⁄–ù]€Çà»ù[àà

HOàò]öYÿ]‹ãõŸä€€ù^
KõX^XôT‹

Kà
Kà
KàÀ»€€ùõ€»›ô\õ^H
⁄›€à€õH⁄[àôXYJBàYà
\‘ôXYH	âÇàZ[î\	âÇà
W‹›\ù\ÿ]PX›]ôH‹›\ù\ÿ]S›ô\õ^RY[äJBàò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNàÿ€€ùõ€’ö\⁄XõKàùZ[\éà
€€ù^ö\⁄XõK H¬àô]\õà[ö[X]Y‹X⁄]Jà‹X⁄]Nàö\⁄XõH»Hàà\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàML
Kà⁄[àY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒà]ö\⁄XõKàÀ»[]ö\⁄[€ú»Ÿ]Z\à›€àò\éàH›X⁄€€ùõ€¬àÀ»\»õ»õÿ›\»õŸ\»][€»Hô[[›Hÿ[õõ›àÀ»ôXX⁄[û][ô»[à]à^€YQõÿ›\»ŸY\»HY[ÇàÀ»ò\à›]Ÿàò]ô\úÿ[∫w^~)ﬁuY€õ‹ôT⁄[ù\à›‹»\¬àÀ»ù]ì’õÿ›\À⁄X⁄€›[›ò[ôHQ€ÇàÀ»[ùö\⁄XõHù]€úÀÇà⁄[à]õ‹õU][ö\’[]ö\⁄[€Çà»^€YQõÿ›\ à^€Y[ôŒà]ö\⁄XõKà⁄[àÿùZ[ê€€ùõ€ 
Kà
Bàà€€ùõ€ àÀ»]ôHTàX]ô\»H‹ò\à[\H€à\ú‹ŸNÇàÀ»]»Y[ù]H\»[àH[ôõ»[ô[ô[›À[ôàÀ»ô\X][ô»H⁄[õô[[àõ›€‹õô\ú»\»BàÀ»\Xÿ][€à\»ôY\⁄Y€àŸ]›]»ô[[›ôKÇà]NÇà⁄YŸ]ú⁄›’öY[’]H	âÇà]⁄YŸ]ú⁄›–⁄[õô[ò[YBà»ŸŸ]›\úô[ù\\€ŸU]J
Bàà	…Àà›Xù]NÇà⁄YŸ]ú⁄›’öY[’]H	âÇà]⁄YŸ]ú⁄›–⁄[õô[ò[YBà»ŸŸ]›\úô[ù\\€ŸT›Xù]J
Bààù[àÀ»Y\ôŸY[ù»Hÿ⁄ŒàH⁄[õô[[ô[öY\»€ÇàÀ»‹ŸàHò[ú‹‹ùò\à\»€ôH›\ôòXŸKÇà[ôõ‘[ô[ÇàÿùZ[\í[ôõ‘[ô[
õ\⁄àùYJHœ¬àÿùZ[XúöYûUí[ôõ‘[ô[
õ\⁄àùYJKà[ôõ‘[ô[ZY⁄à‹ô\Ÿ\ùôY[ôõ‘[ô[ZY⁄àŸ[€Y]ûQŸ[ô\ò][€éàŸÿ⁄—Ÿ[€Y]ûQŸ[ô\ò][€ãà[ôõ‘[ô[Ÿ[ô\ò][€éà⁄[ôõ‘[ô[Ÿ[ô\ò][€ãà€í[ôõ‘[ô[^[ùà
Ÿ[ô\ò][€äH¬àÀ»Hô\‹ùúõ€HHô]ö[›\»^[›]\¬àÀ»›[HûHYö[ö][€à∫w^~)ﬁuõ‹]ÇàYà
Ÿ[ô\ò][€àOH⁄[ôõ‘[ô[Ÿ[ô\ò][€äH¬àô]\õé¬àBàÀ»Xõ\⁄[ò‹ôX\Ÿ\»^X›N»€õHY€õ‹ôBàÀ»›Xã\^[⁄ö[öÿYŸKÇàYà
à⁄[ôõ‘[ô[ZY⁄à
⁄[ôõ‘[ô[ZY⁄H
HèHKå
H¬àŸ]›]J

HOà⁄[ôõ‘[ô[ZY⁄H
N¬àBàKàõ€[YNàŸÿ⁄’õ€[YKà€ïõ€[YP⁄[ôŸYà
äH¬àŸ]›]J

HOàŸÿ⁄’õ€[YHHäN¬à‹^Y\ãúŸ]õ€[YJà
à
àL
Kò€[\
åLå
Kà
N¬àKàÀ»⁄[ô›”X[òYŸ\àö]ô\»ù[ÿ‹ôY[à€õH€ÇàÀ»⁄[ô›‹À”[ù^»XX”‘»[ô[ÿö[HX]ôH]àÀ»»H‘À€»Hù]€à€›[ôHHYKÇà⁄›—ù[ÿ‹ôY[éÇà]õ‹õKö\’⁄[ô›‹»]õ‹õKö\”[ù^à€ëù[ÿ‹ôY[éà

H\ﬁ[ò»¬àö[ò[\—ù[H]ÿZ]⁄[ô›”X[òYŸ\Çàö\—ù[ÿ‹ôY[ä
N¬àYà
[[›[ùY
Hô]\õé¬à]ÿZ]⁄[ô›”X[òYŸ\ãúŸ]ù[ÿ‹ôY[äZ\—ù[
N¬àKàÿ⁄‘›[NàŸÿ⁄‘›[Kàÿ⁄‘[]NàŸÿ⁄‘[]Kàÿ⁄‘⁄^ôNàŸÿ⁄‘⁄^ôKàÀ»õ›][€à€õHYX[ú»€€Y][ô»[àH[ôÇà⁄›‘õ›]Nà]õ‹õU][ö\‘€ôKà€ëÿ⁄—^[ùà
Ÿ[ô\ò][€äH¬àYà
Ÿ[ô\ò][€àOHŸÿ⁄—Ÿ[€Y]ûQŸ[ô\ò][€äH¬àô]\õé¬àBàÀ»Xõ\⁄]ô\ûH[ò‹ôX\ŸH^X›N»€õBàÀ»›\ô\‹»›Xã\^[⁄ö[öÿYŸKÇàö[ò[ô]àHŸÿ⁄—^[ùùò[YN¬àYà
àô]à
ô]àH
HèHKå
H¬àŸÿ⁄—^[ùùò[YHH¬àBàKà[ö[òŸYY]Y]NàŸŸ][ö[òŸYY]Y]J
Kà€ÿ⁄Œà‹^XòX⁄’ZP€ÿ⁄Àà\‘^Z[ôŒà⁄\‘^Z[ôÀà\‘ôXYNà\‘ôXYKà€î^T]\ŸNà›ŸŸ€T^Kà€êòX⁄Œà

HOàò]öYÿ]‹ãõŸä€€ù^
Kú‹

Kà€ê\‹X›à€€ê\‹X›ù]€ãà€î‹YYà€€î‹YYù]€ãà€î€Y\[Y\éà‹⁄›‘€Y\[Y\î⁄Y]à€Y\[Y\ìXô[à‹€Y\[Y\êù]€ìXô[à‹YYà‹^XòX⁄‘‹YYà\‹X›[ŸNàÿ\‹X›[ŸKà\”[ôÿÿ\Nà€[ôÿÿ\Sÿ⁄ŸYà€îõ›]Nà›ŸŸ€S‹öY[ù][€ãà\‘^[\›Çà
ÿX›]ôT^[\›OHù[	âÇàÿX›]ôT^[\›Kö\”õ›[\JHàÿÿ[ëô]⁄\\€Ÿ\Àà€î⁄›‘^[\›à

HOÇà‹⁄›‘^[\›⁄Y]
€€ù^
Kà€î⁄›’òX⁄‹Œà

HOà‹⁄›’òX⁄‹‘⁄Y]
€€ù^
Kà€îŸYZ–ò\ê⁄[ôŸY›\ùà

H¬à⁄\‘ŸYZ⁄[ô’⁄]€Y\àHùYN¬àÀ»HöY]Ÿ\à›€ú»H‹⁄][€àúõ€HBàÀ»ö\ú››X⁄∫w^~)ﬁuô[X\ŸHHô\›[YH›X\ôàÀ»ì’Àõ›]òY»[ô‹àH[ô[ô¬àÀ»ô\öYöY\à€›[ôKZ\‹›YH]»\ôŸ][ôàÀ»X[ö»^XòX⁄»ZYYòYÀÇà‹ô\›[YU‹ö]Q›X\ôõõ›U\Ÿ\îŸYZ 
N¬àKà€îŸYZ–ò\ê⁄[ôŸYà
äH¬àö[ò[ô]‘‹»HŸ\ò][€à
àé¬à‹^XòX⁄’ZP€ÿ⁄Àù\]T‹⁄][€äàô]‘‹Àà[[YYX]NàùYKà
N¬à‹^Y\ãúŸYZ ô]‘‹ N¬à€\›€Y\îŸYZ‘‹»Hô]‘‹Œ¬àKà€îŸYZ–ò\ê⁄[ôŸQ[ôà

H¬à⁄\‘ŸYZ⁄[ô’⁄]€Y\àHò[ŸN¬à‹ÿ⁄Y[P]]“YJ
N¬àYà
€\›€Y\îŸYZ‘‹»OHù[
H¬àö[ò[Ÿ]Y‹⁄][€àBà€\›€Y\îŸYZ‘‹»N¬à›òZ›ÿ‹õÿòõTŸYZ Ÿ]Y‹⁄][€äN¬à‹⁄[Z€ÿ‹õÿòõTŸYZ Ÿ]Y‹⁄][€äN¬à€Yõ\›ÿ‹õÿòõTŸYZ Ÿ]Y‹⁄][€äN¬à€\›€Y\îŸYZ‘‹»Hù[¬àÀ»HŸ]YŸYZ»\»H[ôŸôà[€Y[ùÇàÀ»\ú⁄\›[ô]ﬁ[ò»õ\⁄õ€\KÇà[ò]ÿZ]Y
à‹ÿ]ôTô\›[YJà‹⁄][€ì›ô\úöYNàŸ]Y‹⁄][€ãà
Kà
N¬àBàKàÀ»Tà\\€ŸH\›
Ÿ\öY\À’ì—
HŸ]»ô^‘ô]ö[›\¬àÀ»]ÿ[»HŸX\€€é»H]ôH⁄[õô[Ÿ]»BàÀ»ÿ[YHZ\à\»ô]ö[›\À€ô^⁄[õô[⁄X⁄\»BàÀ»€õHÿ^H»ò\⁄]›]H“
ÀÀHŸ^Kàò[»òX⁄¬àÀ»»HXúöYûKUà\\€ŸK‹^[\›õ›ÀÇà€ìô^à⁄\“\ìô^à»

HOà‹›⁄]⁄“\ê⁄[õô[
àÿ›\úô[ù\í[ô^
»Kà
Bààÿÿ[ñò\\ê⁄[õô[à»

HOàﬁò\\ê⁄[õô[
JBàà
⁄\–[ûSô^»Ÿ€’”ô^\\€ŸHàù[
Kà€ìô^⁄[õô[Çà⁄YŸ]úô\]Y\›ô^⁄[õô[OHù[à»Ÿ€’”ô^⁄[õô[ààù[à€îô]ö[›\Œà⁄\“\îô]ö[›\¬à»

HOà‹›⁄]⁄“\ê⁄[õô[
àÿ›\úô[ù\í[ô^HKà
Bààÿÿ[ñò\\ê⁄[õô[à»

HOàﬁò\\ê⁄[õô[
LJBàà
⁄\‘ô]ö[›\—\\€ŸJ
Bà»Ÿ€’‘ô]ö[›\—\\€ŸBààù[
Kà\”ô^Çà⁄\–[ûSô^à⁄\“\ìô^àÿÿ[ñò\\ê⁄[õô[à\”ô^⁄[õô[Çà⁄YŸ]úô\]Y\›ô^⁄[õô[OHù[à\—›ZYNÇà
ÿ⁄[õô[[ùöY\Àö\”õ›[\H	âÇà⁄YŸ]úô\]Y\›⁄[õô[ûRYOHù[
Hà⁄\‘›ô[Z[’ë›ZYKà€î⁄›—›ZYNÇàÿ⁄[õô[[ùöY\Àö\”õ›[\H	âÇà⁄YŸ]úô\]Y\›⁄[õô[ûRYOHù[à»‹⁄›–⁄[õô[›ZYS›ô\õ^Bàà⁄\‘›ô[Z[’ë›ZYBà»‹⁄›‘›ô[Z[’ë›ZYS›ô\õ^Bààù[à\‘ô]ö[›\ŒÇà⁄\‘ô]ö[›\—\\€ŸJ
Hà⁄\“\îô]ö[›\»àÿÿ[ñò\\ê⁄[õô[àÀ»H]ôH⁄[õô[\»õ»[Y[[ôH»ÿ‹ùXéàBàÀ»‹⁄][€ãŸ\ò][€à\àô\‹ù»\»ù\›H¬àÀ»õ€[ô»⁄[ô›À€»Hò\à€›[ù»€€Y][ô¬àÀ»YX[ö[ô€\‹»[ô⁄]»[ô\àHõŸ‹ò[[YHù[KàÀ»⁄X⁄\»HõŸ‹ô\‹»]X›X[HYX[ú¬àÀ»€€Y][ô»\ôKà\ö]ôYõ›H][ò⁄\ôÀ€¬àÀ»ò\[ô»»€ãY[X[ôúö[ô‹»]›òZY⁄òX⁄ÀÇàYTŸYZÿò\éÇà⁄YŸ]öYTŸYZÿò\àà
⁄\ñò\ò[õô\ì›€ú“Y[ù]H	âÇàW⁄\î›\ù›ô\ï[Y[[ôUö\⁄XõJKàÀ»ÿ[YHÿ[Hò]]ôHÿ⁄»XZŸ\»õ‹à]ôKÇàYT‹YYà⁄\ñò\ò[õô\ì›€ú“Y[ù]KàÀ»⁄YôõHX⁄‹»úõ€HÿX›]ôT^[\›⁄X⁄[ÇàÀ»TàŸ\‹⁄[€àô]ô\à\».ù◊üäwùHù]€à€›[€õBàÀ»]ô\à‹[àHY[ùH]Ÿ\»õ›[ôÀÇàYTò[ô€NàŸYôôX›]ôR\ê⁄[õô[»OHù[àYS‹[€úŒà⁄YŸ]öYS‹[€úÀàYPòX⁄–ù]€éà⁄YŸ]öYPòX⁄–ù]€ãà€îò[ô€Nà

HOÇà[ò]ÿZ]Y
‹⁄›‘ò[ô€T^XòX⁄”Y[ùJ
JKà\“\ê⁄[õô[ŒÇàŸYôôX›]ôR\ê⁄[õô[œÀö\”õ›[\HOBàùYKà€î⁄›“\ê⁄[õô[ŒÇàŸYôôX›]ôR\ê⁄[õô[œÀö\”õ›[\HOHùYBà»‹⁄›“\ê⁄[õô[⁄Y]›ô\õ^Bààù[à\‘›ô[Z[‘€›\òŸ\ŒÇàŸYôôX›]ôT€›\òŸ\»OHù[	âÇàŸYôôX›]ôT€›\òŸ\»Kö\”õ›[\H	âÇà
ŸYôôX›]ôTô\€€ô\àOHù[à⁄YŸ]úô\€€ôT€›\òŸU‘^[\›OBàù[
Kà€î⁄›‘›ô[Z[‘€›\òŸ\ŒÇàŸYôôX›]ôT€›\òŸ\»OHù[	âÇàŸYôôX›]ôT€›\òŸ\»Kö\”õ›[\H	âÇà
ŸYôôX›]ôTô\€€ô\àOHù[à⁄YŸ]úô\€€ôT€›\òŸU‘^[\›OBàù[
Bà»‹⁄›‘€›\òŸT⁄Y]›ô\õ^Bààù[à⁄›‘\ù]€éà\Ÿ\ùöXŸKö\”›€ô\ä\ Kà€î\à\Ÿ\ùöXŸKö\”›€ô\ä\ Bà»Ÿ[ù\î\ààù[à\‘ôX€‹ôàÿÿ[îôX€‹ôà\‘ôX€‹ô[ôŒà‹ôX€‹ô[ô–X›]ôSõ›Àà€îôX€‹ôàÿÿ[îôX€‹ôà»›ŸŸ€TôX€‹ô[ô¬ààù[à€ì]ôQYŸPX›[€éà⁄\ì]ôQYŸPX›[€ãà]ôQYŸPX›[€êX›]ôNà⁄\î›\ù›ô\êX›]ôKà]ôQYŸPX›[€ìÿY[ôŒà⁄\î›\ù›ô\ìÿY[ôÀà€ïŸŸ€T›\ù›ô\ï[Y[[ôNÇà⁄\î›\ù›ô\êX›]ôBà»›ŸŸ€R\î›\ù›ô\ï[Y[[ôBààù[à›\ù›ô\ï[Y[[ôUö\⁄XõNÇà⁄\î›\ù›ô\ï[Y[[ôUö\⁄XõKà
Kà
Kà
N¬àKà
KàÀ»X[ùX[’\›[H⁄⁄\X›[€ãà]›^\»]òZ[XõH]ô[à⁄[ÇàÀ»HXZ[à€€ùõ€»\ôHY[ã[ôYù»Xõ›ôHHÿ⁄»⁄[ÇàÀ»^H\ôHö\⁄XõH€»ôZ]\à€€ùõ€[ù\òŸ\»H›\ãÇàYà
Z[î\
Bàò[YS\›[òXõPùZ[\è⁄⁄\ŸY€Y[ùœäàò[YS\›[òXõNàÿX›]ôT⁄⁄\ŸY€Y[ùZKàùZ[\éà
€€ù^X›]ôT⁄⁄\ŸY€Y[ù H¬àYà
X›]ôT⁄⁄\ŸY€Y[ùOHù[
H¬àô]\õà€€ú›⁄^ôYõﬁú⁄ö[ö 
N¬àBàô]\õàò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNàÿ€€ùõ€’ö\⁄XõKàùZ[\éà
€€ù^€€ùõ€’ö\⁄XõK H¬àÀ»ôXùZ[»⁄[àH›[Yÿ⁄…‹»ZY⁄⁄[ôŸ\Œ¬àÀ»›\ù⁄\ŸHHù]€à€›[ŸY\H›[H‹⁄][€ÇàÀ»[ù[€€YH[úô[]YôXùZ[\[ôY»ÿÿ›\ãÇàô]\õàò[YS\›[òXõPùZ[\è›XõOäàò[YS\›[òXõNàŸÿ⁄—^[ùàùZ[\éà
€€ù^ÿ⁄—^[ù H¬àô]\õà[ö[X]Y‹⁄][€ôY
à\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàML
Kà›\ùôNà›\ùô\ÀôX\ŸS›]àöY⁄àçàÀ»€\‹⁄X»ŸY\»H^X›YÿXﬁH\õò\ûKàBàÀ»›[Yÿ⁄»\»ò\öXXõKZZY⁄€»]\Ÿ\»BàÀ»YX\›\ôYò[ô[ô›XùòX›»\»ù]€â‹»’”ÇàÀ»õ›€HÿYôP\ôXH[úŸ]⁄X⁄H⁄[ôKXYÀÇàõ›€Nà‹⁄⁄\ù]€êõ›€Jà€€ù^à€€ùõ€’ö\⁄XõKàÿ⁄—^[ùà
Kà⁄[àÿYôP\ôXJà‹àò[ŸKàYùàò[ŸKà⁄[à⁄⁄\ŸY€Y[ùù]€äàŸ^Nàò[YRŸ^JX›]ôT⁄⁄\ŸY€Y[ùù\JKà\NàX›]ôT⁄⁄\ŸY€Y[ùù\Kà€îô\‹ŸYà‹⁄⁄\X›]ôTŸY€Y[ùà
Kà
Kà
N¬àKà
N¬àKà
N¬àKà
KàÀ»XúöYûHà›Ÿ\ã]\ô∫w^~)ﬁu⁄[õô[]H
»^Z[ô»]H.ù◊üäwùàÀ»õÿ][ô»›ô\àò\ôHöY[»
Hÿ⁄»[XôY»]»›€à€‹JKÇàÀ»ô\XŸ\»H€»YÿXﬁH€‹õô\àòYŸ\ÀÇàYà
ŸXúöYûPò[õô\ëõÿ][ô”[›[ùY	âÇàŸXúöYûUì›€ú“Y[ù]H	âÇàZ[î\
Bà‹⁄][€ôY
àYùààöY⁄ààõ›€Nàà⁄[àY€õ‹ôT⁄[ù\äàY€õ‹ö[ôŒàùYKà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]Nà‹⁄›—XúöYûPò[õô\à»Kåàåà\ò][€éà\ò][€äàZ[\ŸX€€ôŒà‹⁄›—XúöYûPò[õô\à»åàÕLà
Kà›\ùôNà›\ùô\ÀôX\ŸR[ì›]àÀ»[õ[›[ù€òŸHòYYà\»ÿ‹ôY[àôXùZ[»]ô\ûBàÀ»‹⁄][€àX⁄À[ôHò[ú‹\ô[ùò[õô\à€›[ŸY\àÀ»ôK[^Z[ô»›]õ‹àHô\›ŸàHŸ\‹⁄[€ãÇà€ë[ôà

H¬àYà
[[›[ùY‹⁄›—XúöYûPò[õô\äHô]\õé¬àŸ]›]J

HOàŸXúöYûPò[õô\ëõÿ][ô”[›[ùYHò[ŸJN¬àKà⁄[ÇàÿùZ[XúöYûUí[ôõ‘[ô[
õ\⁄àò[ŸJHœ¬à€€ú›⁄^ôYõﬁú⁄ö[ö 
Kà
Kà
Kà
KàÀ»Tàò\ò[õô\ãõÿ][ô»›ô\àò\ôHöY[»Yù\àHò\à⁄[ÇàÀ»Hÿ⁄»\»‹[à\»\»XúŸ[ù∫w^~)ﬁuHÿ[YH[ô[\»[ú⁄YBàÀ»][ú›XYàZXYŸàH⁄Y]»[ôH›ZYH[àH›X⁄¬àÀ»€»[û][ô»H\Ÿ\à‹[ú»ò]‹»›ô\à]ÇàYà
⁄\ñò\õÿ][ô”[›[ùY	âàZ[î\
Bà‹⁄][€ôY
àYùààöY⁄ààõ›€Nàà⁄[à[ö[X]Y‹X⁄]Jà‹X⁄]Nà‹⁄›“\ñò\ò[õô\à»Kåàåà\ò][€éà\ò][€äàZ[\ŸX€€ôŒà‹⁄›“\ñò\ò[õô\à»MåàNà
Kà›\ùôNà›\ùô\ÀôX\ŸR[ì›]àÀ»õ‹H›XùôYH€òŸH]\»òYY›]à\»ÿ‹ôY[ÇàÀ»ôXùZ[»€à]ô\ûH‹⁄][€àX⁄À€»X]ö[ô»BàÀ»ù[K]ò[ú‹\ô[ùò[õô\à[›[ùY€›[ôK[^H]›]àÀ»õ‹àHô\›ŸàHŸ\‹⁄[€ãà€õHHô\Ÿ[ù][€ÇàÀ»€Ÿ\ È›y¯ßy’H⁄[õô[—T»]H›^\»õ‹àHÿ⁄ÀÇà€ë[ôà

H¬àYà
[[›[ùY‹⁄›“\ñò\ò[õô\äHô]\õé¬àŸ]›]J

HOà⁄\ñò\õÿ][ô”[›[ùYHò[ŸJN¬àKà⁄[ÇàÿùZ[\í[ôõ‘[ô[
õ\⁄àò[ŸJHœ¬à€€ú›⁄^ôYõﬁú⁄ö[ö 
Kà
Kà
KàÀ»Z‘Z»ô]ûH›ô\õ^HHõ€ãXõÿ⁄⁄[ôÀ‹⁄][€ôY]õ›€HöY⁄àYà
⁄\‘Z‘Z‘ô]ûZ[ô»	âà‹Z‘Z‘ô]ûSY\‹ÿYŸHOHù[	âàZ[î\
Bàò[YS\›[òXõPùZ[\è›XõOäàò[YS\›[òXõNàŸÿ⁄—^[ùàùZ[\éà
€€ù^ÿ⁄—^[ù HOÇàò[YS\›[òXõPùZ[\èõ€€äàò[YS\›[òXõNàÿ€€ùõ€’ö\⁄XõKàùZ[\éà
€€ù^€€ùõ€’ö\⁄XõK H¬àÀ»€õHYù»⁄[HHÿ⁄»\»X›X[H€àÿ‹ôY[éÇàÀ»€€ùõ€»›^\»[›[ùY[ô\à[ö[X]Y‹X⁄]H⁄[ÇàÀ»Y[ã€»H^[ù[€ôH\»õ›[õ›Y⁄Çàö[ò[ÿ⁄’ö\⁄XõHBàŸÿ⁄‘›[Kö\‘›[Y	âÇà€€ùõ€’ö\⁄XõH	âÇà
ÿùZ[\í[ôõ‘[ô[
õ\⁄àùYJHOHù[àÿùZ[XúöYûUí[ôõ‘[ô[
õ\⁄àùYJHOBàù[à]⁄YŸ]öYS‹[€ú N¬àô]\õàZ‘Z‘ô]ûS›ô\õ^JàY\‹ÿYŸNà‹Z‘Z‘ô]ûSY\‹ÿYŸHKàõ›€Nàÿ⁄’ö\⁄XõBà»X]õX^
åÿ⁄—^[ù
»LäBààåà
N¬àKà
Kà
KàÀ»⁄[õô[›ZYH›ô\õ^BàYà
‹⁄›–⁄[õô[›ZYH	âàÿ⁄[õô[[ùöY\Àö\”õ›[\H	âàZ[î\
Bà‹⁄][€ôYôö[
à⁄[à⁄[õô[›ZYJà⁄[õô[Œàÿ⁄[õô[[ùöY\Àà›\úô[ù⁄[õô[Yàÿ›\úô[ù⁄[õô[Yà›\úô[ù⁄[õô[ù[Xô\éàÿ›\úô[ù⁄[õô[ù[Xô\ãà€ê⁄[õô[Ÿ[X›YàŸ€’–⁄[õô[ûRYà€ê€‹ŸNà⁄YP⁄[õô[›ZYS›ô\õ^Kà
Kà
KàÀ»Tà⁄[õô[⁄Y]›ô\õ^BàYà
‹⁄›“\ê⁄[õô[⁄Y]	âÇàŸYôôX›]ôR\ê⁄[õô[œÀö\”õ›[\HOHùYH	âÇàZ[î\
Bà‹⁄][€ôYôö[
à⁄[à\ê⁄[õô[⁄Y]
àŸ^Nà⁄\î⁄Y]Ÿ^Kà⁄[õô[ŒàŸYôôX›]ôR\ê⁄[õô[»Kà›\úô[ù[ô^àÿ›\úô[ù\í[ô^à€ê⁄[õô[Ÿ[X›Yà‹›⁄]⁄“\ë›ZYP⁄[õô[à€î^TõŸ‹ò[[YNà‹^R\êÿ]⁄\à€ê€‹ŸNà⁄YR\ê⁄[õô[⁄Y]àÿ]Y€‹öY\ŒÇà⁄\ë›ZYP€€ù^›ô\úöYOÀòÿ]Y€‹öY\»œ¬à⁄YŸ]ö\êÿ]Y€‹öY\»œ¬à€€ú›◊Kà€›\òŸRYà⁄\ë›ZYP€€ù^›ô\úöYHOHù[à»⁄YŸ]ö\î€›\òŸRYàà⁄\ë›ZYP€€ù^›ô\úöYHKú€›\òŸRYà€›\òŸSò[YNà⁄\ë›ZYP€€ù^›ô\úöYHOHù[à»⁄YŸ]ö\î€›\òŸSò[YBàà⁄\ë›ZYP€€ù^›ô\úöYHKú€›\òŸSò[YKàŸ[X›Yÿ]Y€‹ûNà⁄\ë›ZYP€€ù^›ô\úöYHOHù[à»⁄YŸ]ö\îŸ[X›Yÿ]Y€‹ûBàà⁄\ë›ZYP€€ù^›ô\úöYHKúŸ[X›Yÿ]Y€‹ûKà€€ù[ù\NÇà⁄\ë›ZYP€€ù^›ô\úöYOÀò€€ù[ù\Hœ¬à⁄YŸ]ö\ê€€ù[ù\Hœ¬à	€]ôIÀà€›\òŸ\Œà⁄YŸ]ö\î€›\òŸ\»œ»€€ú›◊Kàúõ›‹ŸTõ›öY\éà⁄YŸ]ö\êúõ›‹ŸTõ›öY\ãà€ê€€ù^⁄[ôŸYà‹\ú⁄\›\ë›ZYP€€ù^à›[Nà‹^Y\ë›ZYT›[Kà⁄Ÿ[úŒà‹^Y\ë›ZYU⁄Ÿ[úÀà
Kà
KàÀ»›ô[Z[»€›\òŸH⁄Y]›ô\õ^BàYà
‹⁄›‘€›\òŸT⁄Y]	âÇàŸYôôX›]ôT€›\òŸ\»OHù[	âÇàŸYôôX›]ôT€›\òŸ\»Kö\”õ›[\H	âÇà
ŸYôôX›]ôTô\€€ô\àOHù[à⁄YŸ]úô\€€ôT€›\òŸU‘^[\›OHù[
H	âÇàZ[î\
Bà‹⁄][€ôYôö[
à⁄[àùZ[\äàùZ[\éà
€€ù^
H¬àÀ»H›ô[Z[»à⁄[õô[›⁄]⁄ô\XŸ\»H€›\òŸ\¬àÀ»⁄€\ÿ[H∫w^~)ﬁuH][ò⁄ô]⁄\àõ»€ôŸ\àX]⁄\»BàÀ»€€ù[ù€»ÿY[[‹ôH\»€õHŸôô\ôYôK\›⁄]⁄Çàö[ò[ô]⁄\àH‹›ô[Z[‘€›\òŸ\”›ô\úöYHOHù[à»⁄YŸ]úŸ\öY\‘€›\òŸQô]⁄\Çààù[¬àö[ò[ŸHH›òZ›ŸX\€€ë\\€ŸJ
N¬àô]\õà€›\òŸT⁄Y]
à€›\òŸ\ŒàŸYôôX›]ôT€›\òŸ\»Kà›\úô[ù€›\òŸR[ô^àÿ›\úô[ù€›\òŸR[ô^àô\€€ôT€›\òŸNàÿùZ[€›\òŸT⁄Y]ô\€€ô\ä
Kà€î€›\òŸTŸ[X›Yà⁄[ôT€›\òŸTŸ[X›Yà€ê€‹ŸNà⁄YT€›\òŸT⁄Y]àŸ\öY\—ô]⁄\éàô]⁄\ãà›\úô[ùŸX\€€éàŸKúŸX\€€ãà›\úô[ù\\€ŸNàŸKô\\€ŸKà€î€›\òŸ\”Y\ôŸYà
Y\ôŸY
H¬àYà
[[›[ùY
Hô]\õé¬àŸ]›]J

HOàÿ]Y€Y[ùY€›\òŸ\»HY\ôŸY
N¬àKà
N¬àKà
Kà
KàÀ»›ô[Z[»à›ZYH⁄Y]›ô\õ^BàYà
‹⁄›‘›ô[Z[’ë›ZYH	âà⁄\‘›ô[Z[’ë›ZYH	âàZ[î\
Bà‹⁄][€ôYôö[
à⁄[à›ô[Z[’ë›ZYT⁄Y]
à⁄[õô[ŒàŸYôôX›]ôT›ô[Z[’ê⁄[õô[»Kà›\úô[ù⁄[õô[Yàÿ›\úô[ù›ô[Z[’ê⁄[õô[Yà›ZYQ]Tõ›öY\éà⁄YŸ]ú›ô[Z[’ë›ZYQ]Tõ›öY\ãà⁄[õô[›⁄]⁄õ›öY\éÇà⁄YŸ]ú›ô[Z[’ê⁄[õô[›⁄]⁄õ›öY\àKà€ê⁄[õô[›⁄]⁄Yà‹›⁄]⁄‘›ô[Z[’ê⁄[õô[à€ê€‹ŸNà⁄YT›ô[Z[’ë›ZYKà
Kà
KàÀ»[öYöYY^Y\àY[ùH
‹›Y⁄[ô[
BàYà
‹⁄›‘^Y\ìY[ùH	âàZ[î\
Bà‹⁄][€ôYôö[
⁄[àÿùZ[^Y\ìY[ùT[ô[

JKàÀ»›Xù]Hﬁ[ò»›ô\õ^BàYà
‹⁄›‘ﬁ[ò”›ô\õ^H	âàZ[î\
HÿùZ[ﬁ[ò”›ô\õ^J
KàKà
KàùZ[\éà
€€ù^€€ùõ€’ö\⁄XõK⁄[
H¬àÀ»YHH\⁄›‹[›\ŸH⁄[ù\à€òŸH€€ùõ€»òYH›]»[ûBàÀ»[›\ŸH[›ô[Y[ùÿZŸ\»õ›H›\ú€‹à[ôH€€ùõ€ÀÇàÀ»ŸY\H›\ú€‹àö\⁄XõH⁄[ô]ô\à[à›ô\õ^K‹⁄Y]\»‹[à∫w^~)ﬁuàÀ»‹ŸHŸ]ÿ€€ùõ€’ö\⁄XõOYò[ŸHù]›[ôYYH⁄[ù\ãÇàö[ò[YP›\ú€‹àHX€€ùõ€’ö\⁄XõH	âàW⁄\–[ûS›ô\õ^S‹[é¬àô]\õà[›\ŸTôY⁄[€äà›\ú€‹éàYP›\ú€‹Çà»ﬁ\›[S[›\ŸP›\ú€‹úÀõõ€ôBàà[›\ŸP›\ú€‹ãôYô\ãà€í›ô\éà
 HOà›ÿZŸP€€ùõ€”€î⁄[ù\ä
Kà⁄[à⁄[à
N¬àKà
Kà
Kà
Kà
N¬àBÇàÀÀ»ùYH⁄[H[ûH›ô\õ^K‹⁄Y]\»‹[à€à‹ŸàH^Y\ãà\ŸHŸ]àÀÀ»ÿ€€ùõ€’ö\⁄XõOYò[ŸHù]]\›ŸY\H[›\ŸH⁄[ù\àö\⁄XõKÇàõ€€Ÿ]⁄\–[ûS›ô\õ^S‹[àOÇà‹⁄›‘ﬁ[ò”›ô\õ^Hà‹⁄›–⁄[õô[›ZYHà‹⁄›“\ê⁄[õô[⁄Y]à‹⁄›‘€›\òŸT⁄Y]à‹⁄›‘›ô[Z[’ë›ZYHà‹⁄›‘^Y\ìY[ùN¬ÇàÀÀ»ÿ[Y€à[›\ŸH[›ô[Y[ùàô]ôX[€€ùõ€»
[ôH›\ú€‹äHYàY[à[ôàÀÀ»
ôJ\›\ùH]]ÀZYH€›[ù›€à€»€€ù[ù[›\»[›ô[Y[ùŸY\»[H[]ôKÇàõ⁄Y›ÿZŸP€€ùõ€”€î⁄[ù\ä
H¬àÀ»€â›\›\òàHò\ŸH€€ùõ€»⁄[H[à›ô\õ^H›€ú»Hÿ‹ôY[é»BàÀ»›\ú€‹à\»[ôXYHŸ\ö\⁄XõHûH⁄\–[ûS›ô\õ^S‹[à[àHùZ[\ãÇàYà
⁄\–[ûS›ô\õ^S‹[äHô]\õé¬àYà
Wÿ€€ùõ€’ö\⁄XõKùò[YJH¬àÿ€€ùõ€’ö\⁄XõKùò[YHHùYN¬àBà‹ÿ⁄Y[P]]“YJ
N¬àBÇà›ö[ô»ÿ›\úô[ù^XòX⁄’]Qõ‹íY[ù]J
H¬àYà
ÿX›]ôT^[\›OHù[	âÇàÿ›\úô[ù[ô^èH	âÇàÿ›\úô[ù[ô^ÿX›]ôT^[\›Kõ[ô›
H¬àô]\õàÿX›]ôT^[\›V◊ÿ›\úô[ù[ô^Kù]N¬àBàYà
Ÿ[ò[ZX’]Kö\”õ›[\JHô]\õàŸ[ò[ZX’]N¬àö[ò[›ô[Z[’]HHÿ›\úô[ù›ô[Z[’ê€€ù[ù]N¬àYà
›ô[Z[’]HOHù[	âà›ô[Z[’]Kùö[J
Kö\”õ›[\JH¬àô]\õà›ô[Z[’]N¬àBàö[ò[€€ù[ù]HH⁄YŸ]ò€€ù[ù]N¬àYà
€€ù[ù]HOHù[	âà€€ù[ù]Kùö[J
Kö\”õ›[\JH¬àô]\õà€€ù[ù]N¬àBàô]\õà⁄YŸ]ù]N¬àBÇà›ö[ô»⁄Y[ù]TŸX\ò⁄[ö]X[]Y\ûJ
H¬àö[ò[ò]’]HHÿ›\úô[ù^XòX⁄’]Qõ‹íY[ù]J
N¬àö[ò[Ÿ\öY\“[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJò]’]JN¬àö[ò[Ÿ\öY\’]HHŸ\öY\“[ôõÀù]OÀùö[J
N¬àYà
Ÿ\öY\“[ôõÀö\‘Ÿ\öY\»	âàŸ\öY\’]HOHù[	âàŸ\öY\’]Kö\”õ›[\JH¬àô]\õàŸ\öY\’]N¬àBÇàö[ò[[›öYR[ôõ»H[›öYT\úŸ\ãú\úŸQö[[ò[YJò]’]JN¬àö[ò[[›öYU]HH[›öYR[ôõÀù]OÀùö[J
N¬àYà
[›öYU]HOHù[	âà[›öYU]Kö\”õ›[\JH¬àô]\õà[›öYU]N¬àBÇàô]\õàò]’]Bàúô\XŸP[
àôY—^
àâ◊äZ›ü\]ö_[›ü€]üõüŸXõ_Müﬂ\ﬂ\Y I	Ààÿ\ŸTŸ[ú⁄]]ôNàò[ŸKà
Kà	…Àà
Bàúô\XŸP[
ôY—^
â÷Àó◊J… K	»	 Bàúô\XŸP[
ôY—^
â◊ … K	»	 Bàùö[J
N¬àBÇà›ö[ô»€õ‹õX[\ŸY€€ù[ù\J›ö[ô»\JHOÇà\Kù”›Ÿ\êÿ\ŸJ
HOH	‹Ÿ\öY\…»»	‹Ÿ\öY\…»à	€[›öYIŒ¬Çà›ö[ôœ»‹›Xù]RY[ù]SXô[õ‹î⁄Y]

H¬àö[ò[X[ùX[Xô[H€X[ùX[›Xù]Q\‹^SXô[Àùö[J
N¬àYà
X[ùX[Xô[OHù[	âàX[ùX[Xô[ö\”õ›[\JH¬àô]\õà	‘›Xù]\»õ‹à	X[ùX[Xô[	Œ¬àBÇàö[ò[]X›Y]HH⁄Y[ù]TŸX\ò⁄[ö]X[]Y\ûJ
N¬àYà
]X›Y]Kö\—[\JHô]\õàù[¬àô]\õà	—]X›Yà	]X›Y]IŒ¬àBÇà›ö[ô»‹›Xù]TŸX\ò⁄\‹^SXô[
à›ô[Z[”Y]HY]K¬àô\]Z\ôY›ö[ô»€€ù[ù\Kà[ù»ŸX\€€ãà[ù»\\€ŸKàJH¬àö[ò[YX\àHY]KûYX\èÀùö[J
N¬àö[ò[]HHYX\àOHù[	âàYX\ãö\”õ›[\Bà»	…€Y]Kõò[Y_H
	YX\äI¬ààY]Kõò[YN¬àYà
€€ù[ù\HOH	‹Ÿ\öY\…»	âàŸX\€€àOHù[	âà\\€ŸHOHù[
H¬àô]\õà	…]H…‹ŸX\€€üQI\\€ŸIŒ¬àBàô]\õà]N¬àBÇà\››ô[Z[”Y]OàŸö[\íY[ù]TŸX\ò⁄ô\›[ \››ô[Z[”Y]OàY]\ H¬àö[ò[ô\›ûRŸ^HH›ö[ôÀ›ô[Z[”Y]OûﬂN¬Çàõ‹à
ö[ò[Y]H[àY]\ H¬àö[ò[[YíYHY]KôYôôX›]ôR[YíY¬àYà
[YíYOHù[Z[YíYú›\ù’⁄]
	›	 JH€€ù[ùYN¬Çàö[ò[\HHY]Kù\Kù”›Ÿ\êÿ\ŸJ
N¬àYà
\HOH	€[›öYI»	âà\HOH	‹Ÿ\öY\… H€€ù[ùYN¬Çàö[ò[Ÿ^HH	…\Nâ[YíY	Œ¬àö[ò[^\›[ô»Hô\›ûRŸ^V⁄Ÿ^WN¬àYà
^\›[ô»OHù[
H¬àô\›ûRŸ^V⁄Ÿ^WHHY]N¬à€€ù[ùYN¬àBÇàö[ò[^\›[ô‘ÿ€‹ôHBà
^\›[ôÀú‹›\àOHù[»àà
H
»
^\›[ôÀûYX\àOHù[»Hà
N¬àö[ò[ô]‘ÿ€‹ôHBà
Y]Kú‹›\àOHù[»àà
H
»
Y]KûYX\àOHù[»Hà
N¬àYà
ô]‘ÿ€‹ôHà^\›[ô‘ÿ€‹ôJH¬àô\›ûRŸ^V⁄Ÿ^WHHY]N¬àBàBÇàô]\õàô\›ûRŸ^Kùò[Y\Àù”\›
‹õ›ÿXõNàò[ŸJN¬àBÇà›ö[ôœ»€õ‹õX[\ŸT‹›\ï\õ
›ö[ôœ»\õ
H¬àYà
\õOHù[\õùö[J
Kö\—[\JHô]\õàù[¬àYà
\õú›\ù’⁄]
	ÀÀ… JHô]\õà	⁄Œâ\õ	Œ¬àô]\õà\õ¬àBÇà›ö[ô»⁄Y[ù]SY]T›Xù]J›ô[Z[”Y]HY]JH¬àö[ò[\ù»H›ö[ôœñ¬àY]Kù\Kù”›Ÿ\êÿ\ŸJ
HOH	‹Ÿ\öY\…»»	‘Ÿ\öY\…»à	”[›öYIÀàYà
Y]KûYX\àOHù[	âàY]KûYX\àKùö[J
Kö\”õ›[\JHY]KûYX\àKàYà
Y]Kú€›\òŸPY€èÀõò[YKùö[J
Kö\”õ›[\HOHùYJBàY]Kú€›\òŸPY€àKõò[YKàN¬àô]\õà\ùÀöõ⁄[ä	»	 N¬àBÇà⁄YŸ]ÿùZ[Y[ùYûU]Tô\›[[Jà›ô[Z[”Y]HY]K¬àõÿ›\”õŸO»õÿ›\”õŸKàJH¬àö[ò[‹›\ï\õH€õ‹õX[\ŸT‹›\ï\õ
Y]Kú‹›\äN¬Çàô]\õà[ö’Ÿ[
àõÿ›\”õŸNàõÿ›\”õŸKà€ï\à

HOàò]öYÿ]‹ãõŸä€€ù^
Kú‹
Y]JKà⁄[àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àúﬁ[[Y]öX ‹ö^õ€ù[àåô\ùXÿ[à
Kà⁄[àõ› à⁄[ô[éà¬à€\îôX›
àõ‹ô\îòY]\Œàõ‹ô\îòY]\Àò⁄\ò›[\ääKà⁄[à€€ùZ[ô\äà⁄YàãàZY⁄àéà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [Nàå
Kà⁄[à‹›\ï\õOHù[à»X€€äàX€€úÀõ[›öYWÿ‹ôX][€ó€›][ôYà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçJKà
Bàà[XYŸKõô]€‹ö à‹›\ï\õàö]àõﬁö]ò€›ô\ãà\úõ‹êùZ[\éà
À◊À◊◊ HOàX€€äàX€€úÀõ[›öYWÿ‹ôX][€ó€›][ôYà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçJKà
Kà
Kà
Kà
Kà€€ú›⁄^ôYõﬁ
⁄YàM
Kà^[ôY
à⁄[à€€[[äà‹õ‹‹–^\–[Y€õY[ùà‹õ‹‹–^\–[Y€õY[ùú›\ùà⁄[ô[éà¬à^
àY]Kõò[YKàX^[ô\Œàãà›ô\ôõ›Œà^›ô\ôõ›Àô[\⁄\Àà›[Nà€€ú›^›[Jà€€‹éà€€‹úÀù⁄]Kàõ€ù⁄^ôNàMKàõ€ùŸZY⁄àõ€ùŸZY⁄ùÕåà
Kà
Kà€€ú›⁄^ôYõﬁ
ZY⁄à
Kà^
à⁄Y[ù]SY]T›Xù]JY]JKàX^[ô\ŒàKà›ô\ôõ›Œà^›ô\ôõ›Àô[\⁄\Àà›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçN
Kàõ€ù⁄^ôNàLãà
Kà
KàKà
Kà
Kà€€ú›⁄^ôYõﬁ
⁄Yà
KàX€€äàX€€úÀò⁄]úõ€ó‹öY⁄‹õ›[ôYà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçJKà
KàKà
Kà
Kà
N¬àBÇàù]\ôO›ô[Z[”Y]Oœà‹⁄›“Y[ùYûU]TŸX\ò⁄⁄Y]
¬àô\]Z\ôY›ö[ô»[ö]X[]Y\ûKàJH\ﬁ[ò»¬àYà
[[›[ùY
Hô]\õàù[¬Çàö[ò[€€ùõ€\àH^Y][ô–€€ùõ€\ä^à[ö]X[]Y\ûJN¬àö[ò[ŸX\ò⁄õÿ›\”õŸHHõÿ›\”õŸJXùY”Xô[à	⁄Y[ùYûK]]K\ŸX\ò⁄	 N¬àö[ò[ö\ú›ô\›[õÿ›\”õŸHHõÿ›\”õŸJàXùY”Xô[à	⁄Y[ùYûK]]KYö\ú›\ô\›[	Àà
N¬àö[ò[ŸX\ò⁄›XõZ]õÿ›\»HîŸX\ò⁄õÿ›\“[ôŸôä
N¬àò\àô\›[»H›ô[Z[”Y]Oñ◊N¬àò\à\‘ŸX\ò⁄[ô»Hò[ŸN¬àò\à\‘ŸX\ò⁄YHò[ŸN¬à›ö[ôœ»\úõ‹ìY\‹ÿYŸN¬àò\àŸX\ò⁄⁄Ÿ[àH¬àò\à⁄Y]X›]ôHHùYN¬Çàù]\ôOõ⁄Yàù[îŸX\ò⁄
›ö[ô»ò]‘]Y\ûK›]TŸ]\àŸ]⁄Y]›]JH\ﬁ[ò»¬àö[ò[]Y\ûHHò]‘]Y\ûKùö[J
N¬àö[ò[⁄Ÿ[àH
 ‹ŸX\ò⁄⁄Ÿ[é¬ÇàYà
]Y\ûKö\—[\JH¬àŸX\ò⁄›XõZ]õÿ›\Àòÿ[òŸ[

N¬àŸ]⁄Y]›]J

H¬àô\›[»H◊N¬à\úõ‹ìY\‹ÿYŸHHù[¬à\‘ŸX\ò⁄[ô»Hò[ŸN¬à\‘ŸX\ò⁄YHò[ŸN¬àJN¬àô]\õé¬àBÇàŸ]⁄Y]›]J

H¬à\‘ŸX\ò⁄[ô»HùYN¬à\úõ‹ìY\‹ÿYŸHHù[¬à\‘ŸX\ò⁄YHùYN¬àJN¬ÇàûH¬àö[ò[Y]\»H]ÿZ]›ô[Z[‘Ÿ\ùöXŸKö[ú›[òŸKúŸX\ò⁄ÿ][Ÿ‹ ]Y\ûJN¬àYà
\⁄Y]X›]ôH[[›[ùY⁄Ÿ[àOHŸX\ò⁄⁄Ÿ[äHô]\õé¬àŸ]⁄Y]›]J

H¬àô\›[»HŸö[\íY[ù]TŸX\ò⁄ô\›[ Y]\ N¬à\‘ŸX\ò⁄[ô»Hò[ŸN¬àJN¬àYà
ô\›[Àö\—[\JH¬àŸX\ò⁄›XõZ]õÿ›\Àòÿ[òŸ[

N¬àH[ŸH¬àŸX\ò⁄›XõZ]õÿ›\Àò€€\]JàöY[àŸX\ò⁄õÿ›\”õŸKà\”[›[ùYà

HOà⁄Y]X›]ôH	âà[›[ùYàô\]Y\›õÿ›\Œàö\ú›ô\›[õÿ›\”õŸKúô\]Y\›õÿ›\Àà\ôŸ]\—õÿ›\Œà

HOàö\ú›ô\›[õÿ›\”õŸKö\—õÿ›\Àà
N¬àBàHÿ]⁄
JH¬àYà
\⁄Y]X›]ôH[[›[ùY⁄Ÿ[àOHŸX\ò⁄⁄Ÿ[äHô]\õé¬àŸX\ò⁄›XõZ]õÿ›\Àòÿ[òŸ[

N¬àŸ]⁄Y]›]J

H¬àô\›[»H◊N¬à\úõ‹ìY\‹ÿYŸHH	‘ŸX\ò⁄òZ[YàûHYÿZ[ãâŒ¬à\‘ŸX\ò⁄[ô»Hò[ŸN¬àJN¬àBàBÇàù]\ôOõ⁄Yà›XõZ]ŸX\ò⁄
à›ö[ô»ò]‘]Y\ûKà›]TŸ]\àŸ]⁄Y]›]Kà
H\ﬁ[ò»¬àŸX\ò⁄›XõZ]õÿ›\Àò\õJ[òXõYà]õ‹õU][ö\’[]ö\⁄[€äN¬à]ÿZ]ù[îŸX\ò⁄
ò]‘]Y\ûKŸ]⁄Y]›]JN¬àBÇàÀ»öY⁄\⁄YH€\‹»[ô[
H^Y\àY[ùI‹»‹ò[[X\äHò]\à[àH€àÀ»X]\öX[õ›€H⁄Y]
È›y¯ßy’HX›\ôH›^\»ö\⁄XõH€àHYùÇàö[ò[Ÿ[X›YBà]ÿZ]⁄›—Ÿ[ô\ò[X[Ÿœ›ô[Z[”Y]Oäà€€ù^à€€ù^àò\úöY\ë\€Z\‹⁄XõNàùYKàò\úöY\ìXô[à	Ÿ\€Z\‹…Ààò\úöY\ê€€‹éà€€‹úÀòõX⁄Àù⁄]ò[Y\ [NàçJKàò[ú⁄][€ë\ò][€éà€€ú›\ò][€äZ[\ŸX€€ôŒàé
Kàò[ú⁄][€êùZ[\éà
€€ù^[ö[KÀ⁄[
H¬àö[ò[›\ùôYH›\ùôY[ö[X][€äà\ô[ùà[ö[Kà›\ùôNà›\ùô\ÀôX\ŸS›]›XöXÀà
N¬àô]\õàòYUò[ú⁄][€äà‹X⁄]Nà›\ùôYà⁄[à€YUò[ú⁄][€äà‹⁄][€éàŸY[èŸôúŸ]äàôY⁄[éà€€ú›ŸôúŸ]
åLã
Kà[ôàŸôúŸ]ûô\õÀà
Kò[ö[X]J›\ùôY
Kà⁄[à⁄[à
Kà
N¬àKàYŸPùZ[\éà
⁄Y]€€ù^À◊ H¬àò\à[ö]X[ŸX\ò⁄›\ùYHò[ŸN¬àô]\õà›]Yù[ùZ[\äàùZ[\éà
⁄Y]€€ù^Ÿ]⁄Y]›]JH¬àYà
Z[ö]X[ŸX\ò⁄›\ùY	âà[ö]X[]Y\ûKùö[J
Kö\”õ›[\JH¬à[ö]X[ŸX\ò⁄›\ùYHùYN¬àù]\ôJ

HOàù[îŸX\ò⁄
[ö]X[]Y\ûKŸ]⁄Y]›]JJN¬àBÇàö[ò[ÿ‹ôY[î⁄^ôHHYYXT]Y\ûKõŸä⁄Y]€€ù^
Kú⁄^ôN¬àö[ò[€€\X›Hÿ‹ôY[î⁄^ôKù⁄YÃå¬àö[ò[[ô[⁄YH€€\X›à»ÿ‹ôY[î⁄^ôKù⁄Yàà
ÿ‹ôY[î⁄^ôKù⁄Y
àçäKò€[\
ÃåMåå
N¬Çàö[ò[[ô[H€€ùZ[ô\äà⁄Yà[ô[⁄YàZY⁄à›XõKö[ôö[ö]KàX€‹ò][€éàõﬁX€‹ò][€äà€€‹éà]õ‹õU][ö\–[ôõ⁄YêÿX⁄Yà»€€ú›€€‹äçLLLLäBàà€€ú›€€‹äëåLLLäKù⁄]ò[Y\ [NàéäKàõ‹ô\éàõ‹ô\äàYùàõ‹ô\î⁄YJà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàåM
Kà⁄YàçÕKà
Kà
Kà
Kà⁄[àÿYôP\ôXJàYùàò[ŸKà⁄[à€€[[äà⁄[ô[éà¬àY[ô àY[ôŒà€€ú›YŸR[úŸ]Àôúõ€SêäççM
Kà⁄[àõ› à⁄[ô[éà¬à^[ôY
à⁄[à^
à	—íVHUIÀà›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçäKàõ€ù⁄^ôNàLKàõ€ùŸZY⁄àõ€ùŸZY⁄ùÕåà]\î‹X⁄[ôŒàKéà
Kà
Kà
KàX€€êù]€äàX€€éà€€ú›X€€äX€€úÀò€‹ŸW‹õ›[ôY
Kà€€‹éà€€‹úÀù⁄]MÃà€îô\‹ŸYà

HOÇàò]öYÿ]‹ãõŸä⁄Y]€€ù^
Kú‹

Kà
KàKà
Kà
KàY[ô àY[ôŒà€€ú›YŸR[úŸ]Àôúõ€SêäççLäKà⁄[àï^öY[
à€€ùõ€\éà€€ùõ€\ãàõÿ›\”õŸNàŸX\ò⁄õÿ›\”õŸKà]]Ÿõÿ›\Œà[ö]X[]Y\ûKùö[J
Kö\—[\Kà€ê⁄[ôŸYà
 HOàŸX\ò⁄›XõZ]õÿ›\Àòÿ[òŸ[

Kà€î›XõZ]Yà
ò[YJHOÇà›XõZ]ŸX\ò⁄
ò[YKŸ]⁄Y]›]JKà›[Nà€€ú›^›[J€€‹éà€€‹úÀù⁄]JKà^[ú]X›[€éà^[ú]X›[€ãúŸX\ò⁄àX€‹ò][€éà[ú]X€‹ò][€äà[ù^à	‘ŸX\ò⁄[›öYH‹à⁄›…Àà[ù›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçäKà
KàôYö^X€€éàX€€äàX€€úÀúŸX\ò⁄‹õ›[ôYà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçJKà
Kà›Yôö^X€€éàX€€êù]€äàX€€éà€€ú›X€€äX€€úÀò\úõ›◊Ÿõ‹ùÿ\ô‹õ›[ôY
Kà€€‹éà€€‹úÀù⁄]MÃà€îô\‹ŸYà

HOÇàù[îŸX\ò⁄
€€ùõ€\ãù^Ÿ]⁄Y]›]JKà
Kàö[YàùYKàö[€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [Nàå
Kàõ‹ô\éà›][ôR[ú]õ‹ô\äàõ‹ô\îòY]\Œàõ‹ô\îòY]\Àò⁄\ò›[\äLäKàõ‹ô\î⁄YNàõ‹ô\î⁄YKõõ€ôKà
Kà
Kà
Kà
Kà^[ôY
à⁄[àùZ[\äàùZ[\éà
 H¬àYà
\‘ŸX\ò⁄[ô H¬àô]\õàŸ[ù\äà⁄[à⁄^ôYõﬁ
à⁄YàåãàZY⁄àåãà⁄[à⁄\ò›[\îõŸ‹ô\‹“[ôXÿ]‹äà›õ⁄ŸU⁄Yàãà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ à[Nàçãà
Kà
Kà
Kà
N¬àBÇàYà
\úõ‹ìY\‹ÿYŸHOHù[
H¬àô]\õàŸ[ù\äà⁄[à^
à\úõ‹ìY\‹ÿYŸHKà›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ à[NàççKà
Kàõ€ù⁄^ôNàMà
Kà
Kà
N¬àBÇàYà
\‘ŸX\ò⁄Y	âàô\›[Àö\—[\JH¬àô]\õàŸ[ù\äà⁄[à^
à	”õ»SQãXòX⁄ŸYô\›[»õ›[ô	Àà›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ à[NàççKà
Kàõ€ù⁄^ôNàMà
Kà
Kà
N¬àBÇàô]\õà\›öY]ÀúŸ\\ò]Y
àY[ôŒà€€ú›YŸR[úŸ]Àõ€õJõ›€Nàå
Kà][P€›[ùàô\›[Àõ[ô›àŸ\\ò]‹êùZ[\éà
À◊ HOà]öY\äàZY⁄àKà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàåäKà
Kà][PùZ[\éà
À[ô^
HOÇàÿùZ[Y[ùYûU]Tô\›[[Jàô\›[÷⁄[ô^Kàõÿ›\”õŸNà[ô^OHà»ö\ú›ô\›[õÿ›\”õŸBààù[à
Kà
N¬àKà
Kà
KàKà
Kà
Kà
N¬Çàô]\õà[Y€äà[Y€õY[ùà[Y€õY[ùòŸ[ù\îöY⁄à⁄[àX]\öX[
€€‹éà€€‹úÀùò[ú‹\ô[ù⁄[à[ô[
Kà
N¬àKà
N¬àKà
Kù⁄[ê€€\]J

H¬à⁄Y]X›]ôHHò[ŸN¬àJN¬ÇàŸX\ò⁄›XõZ]õÿ›\Àòÿ[òŸ[

N¬àŸX\ò⁄õÿ›\”õŸKô\‹‹ŸJ
N¬àö\ú›ô\›[õÿ›\”õŸKô\‹‹ŸJ
N¬à€€ùõ€\ãô\‹‹ŸJ
N¬àô]\õàŸ[X›Y¬àBÇà‘ŸX\€€ë\\€ŸTŸ[X›[€è»ÿ›\úô[ùŸX\€€ë\\€ŸQõ‹íY[ù]J
H¬àö[ò[Ÿ\öY\‘^[\›H‹Ÿ\öY\‘^[\›¬àYà
Ÿ\öY\‘^[\›OHù[	âàŸ\öY\‘^[\›ö\‘Ÿ\öY\ H¬àö[ò[›\úô[ù\HŸö[ôŸ\öY\—\\€ŸQõ‹ê›\úô[ù[ô^
Ÿ\öY\‘^[\›
N¬àö[ò[ŸX\€€àH›\úô[ù\ÀúŸ\öY\“[ôõÀúŸX\€€é¬àö[ò[\\€ŸHH›\úô[ù\ÀúŸ\öY\“[ôõÀô\\€ŸN¬àYà
ŸX\€€àOHù[	âà\\€ŸHOHù[
H¬àô]\õà‘ŸX\€€ë\\€ŸTŸ[X›[€äŸX\€€éàŸX\€€ã\\€ŸNà\\€ŸJN¬àBàBÇàö[ò[Ÿ\öY\“[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJàÿ›\úô[ù^XòX⁄’]Qõ‹íY[ù]J
Kà
N¬àö[ò[ŸX\€€àBàŸ\öY\“[ôõÀúŸX\€€àœ¬à€X[ùX[€€ù[ùŸX\€€àœ¬àÿ›\úô[ù›ô[Z[’ê€€ù[ùŸX\€€àœ¬à⁄YŸ]ò€€ù[ùŸX\€€é¬àö[ò[\\€ŸHBàŸ\öY\“[ôõÀô\\€ŸHœ¬à€X[ùX[€€ù[ù\\€ŸHœ¬àÿ›\úô[ù›ô[Z[’ê€€ù[ù\\€ŸHœ¬à⁄YŸ]ò€€ù[ù\\€ŸN¬ÇàYà
ŸX\€€àOHù[\\€ŸHOHù[
Hô]\õàù[¬àô]\õà‘ŸX\€€ë\\€ŸTŸ[X›[€äŸX\€€éàŸX\€€ã\\€ŸNà\\€ŸJN¬àBÇàù]\ôO‘ŸX\€€ë\\€ŸTŸ[X›[€èœà‹ô\]Y\›ŸX\€€ë\\€ŸQõ‹íY[ù]Jà›ö[ô»]Kà
H\ﬁ[ò»¬àYà
[[›[ùY
Hô]\õàù[¬Çàö[ò[ŸX\€€ê€€ùõ€\àH^Y][ô–€€ùõ€\ä
N¬àö[ò[\\€ŸP€€ùõ€\àH^Y][ô–€€ùõ€\ä
N¬à›ö[ôœ»\úõ‹ï^¬Çàö[ò[ô\›[H]ÿZ]⁄›‘‹›Y⁄X[Ÿœ‘ŸX\€€ë\\€ŸTŸ[X›[€èäà€€ù^àùZ[\éà
X[Ÿ–€€ù^
H¬àô]\õà›]Yù[ùZ[\äàùZ[\éà
X[Ÿ–€€ù^Ÿ]X[Ÿ‘›]JH¬àô]\õà‹›Y⁄X[Ÿ–ÿ\ô
à]Nà	’⁄X⁄\\€ŸO…ÀàõŸU^à]Kà⁄[à€€[[äàXZ[ê^\‘⁄^ôNàXZ[ê^\‘⁄^ôKõZ[ãà⁄[ô[éà¬àõ› à⁄[ô[éà¬à^[ôY
à⁄[àï^öY[
à€€ùõ€\éàŸX\€€ê€€ùõ€\ãàŸ^Xõÿ\ô\Nà^[ú]\Kõù[Xô\ãà›[Nà€€ú›^›[J€€‹éà€€‹úÀù⁄]JKàX€‹ò][€éà[ú]X€‹ò][€äàXô[^à	‘ŸX\€€âÀàXô[›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçåäKà
Kà
Kà
Kà
Kà€€ú›⁄^ôYõﬁ
⁄YàLäKà^[ôY
à⁄[àï^öY[
à€€ùõ€\éà\\€ŸP€€ùõ€\ãàŸ^Xõÿ\ô\Nà^[ú]\Kõù[Xô\ãà›[Nà€€ú›^›[J€€‹éà€€‹úÀù⁄]JKàX€‹ò][€éà[ú]X€‹ò][€äàXô[^à	—\\€ŸIÀàXô[›[Nà^›[Jà€€‹éà€€‹úÀù⁄]Kù⁄]ò[Y\ [NàçåäKà
Kà
Kà
Kà
KàKà
KàYà
\úõ‹ï^OHù[
Hããñ¬à€€ú›⁄^ôYõﬁ
ZY⁄àLäKà^
à\úõ‹ï^Kà›[Nà€€ú›^›[Jà€€‹éà‹›Y⁄X[Ÿ–ÿ\ôú›]\‘ôYàõ€ù⁄^ôNàLãà
Kà
KàKàKà
KàX›[€úŒà¬à‹›Y⁄X[Ÿ–X›[€äà	–ÿ[òŸ[	Àà

HOàò]öYÿ]‹ãõŸäX[Ÿ–€€ù^
Kú‹

Kà
KàÀ»€€YàHôX€€[Y[ôYX›[€ã[ô€ààH]]Ÿõÿ›\¬àÀ»[ò⁄‹à∫w^~)ﬁu⁄]›]]HX[Ÿ»‹[ú»⁄]õ›[ô»õÿ›\ŸYàÀ»[ôHö\ú›“»ô\‹»Y\ÀÇà‹›Y⁄X[Ÿ–X›[€ä	–\IÀ€€YàùYK

H¬àö[ò[ŸX\€€àH[ùùûT\úŸJŸX\€€ê€€ùõ€\ãù^ùö[J
JN¬àö[ò[\\€ŸHH[ùùûT\úŸJ\\€ŸP€€ùõ€\ãù^ùö[J
JN¬àYà
ŸX\€€àOHù[àŸX\€€àHà\\€ŸHOHù[à\\€ŸHH
H¬àŸ]X[Ÿ‘›]J

H¬à\úõ‹ï^H	—[ù\àHò[YŸX\€€à[ô\\€ŸKâŒ¬àJN¬àô]\õé¬àBàò]öYÿ]‹ãõŸäX[Ÿ–€€ù^
Kú‹
à‘ŸX\€€ë\\€ŸTŸ[X›[€äŸX\€€éàŸX\€€ã\\€ŸNà\\€ŸJKà
N¬àJKàKà
N¬àKà
N¬àKà
N¬ÇàŸX\€€ê€€ùõ€\ãô\‹‹ŸJ
N¬à\\€ŸP€€ùõ€\ãô\‹‹ŸJ
N¬àô]\õàô\›[¬àBÇàù]\ôOòX⁄‹‘⁄Y]›Xù]TŸX\ò⁄ô\›[œÇà⁄Y[ùYûU]P[ôô]⁄›Xù]\ 
H\ﬁ[ò»¬àö[ò[Y[ùYûU⁄Ÿ[àHÿY€î›Xù]Qô]⁄⁄Ÿ[é¬àö[ò[Ÿ[X›YH]ÿZ]‹⁄›“Y[ùYûU]TŸX\ò⁄⁄Y]
à[ö]X[]Y\ûNà⁄Y[ù]TŸX\ò⁄[ö]X[]Y\ûJ
Kà
N¬àYà
[[›[ùYàŸ[X›YOHù[àY[ùYûU⁄Ÿ[àOHÿY€î›Xù]Qô]⁄⁄Ÿ[äH¬àô]\õàù[¬àBÇàö[ò[[YíYHŸ[X›YôYôôX›]ôR[YíY¬àYà
[YíYOHù[Z[YíYú›\ù’⁄]
	›	 JH¬àÿÿYôõ€Y\‹Ÿ[ôŸ\ãõŸä€€ù^
Kú⁄›‘€òX⁄–ò\äà€€ú›€òX⁄–ò\ä€€ù[ùà^
	‘Ÿ[X›Y]H\»õ»SQàQ	 JKà
N¬àô]\õàù[¬àBÇàö[ò[€€ù[ù\HH€õ‹õX[\ŸY€€ù[ù\JŸ[X›Yù\JN¬à[ù»ŸX\€€é¬à[ù»\\€ŸN¬ÇàYà
€€ù[ù\HOH	‹Ÿ\öY\… H¬àö[ò[›\úô[ù\\€ŸHHÿ›\úô[ùŸX\€€ë\\€ŸQõ‹íY[ù]J
N¬àŸX\€€àH›\úô[ù\\€ŸOÀúŸX\€€é¬à\\€ŸHH›\úô[ù\\€ŸOÀô\\€ŸN¬ÇàYà
ŸX\€€àOHù[\\€ŸHOHù[
H¬àö[ò[[ù\ôYH]ÿZ]‹ô\]Y\›ŸX\€€ë\\€ŸQõ‹íY[ù]JŸ[X›Yõò[YJN¬àYà
[[›[ùYà[ù\ôYOHù[àY[ùYûU⁄Ÿ[àOHÿY€î›Xù]Qô]⁄⁄Ÿ[äH¬àô]\õàù[¬àBàŸX\€€àH[ù\ôYúŸX\€€é¬à\\€ŸHH[ù\ôYô\\€ŸN¬àBàBÇàö[ò[›Xù]Q\‹^SXô[H‹›Xù]TŸX\ò⁄\‹^SXô[
àŸ[X›Yà€€ù[ù\Nà€€ù[ù\KàŸX\€€éàŸX\€€ãà\\€ŸNà\\€ŸKà
N¬Çàö[ò[ô]⁄⁄Ÿ[àHÿY€î›Xù]Qô]⁄⁄Ÿ[à
»N¬àŸ]›]J

H¬àÿY€î›Xù]Qô]⁄⁄Ÿ[àHô]⁄⁄Ÿ[é¬à€X[ùX[€€ù[ù[YíYH[YíY¬à€X[ùX[€€ù[ù\HH€€ù[ù\N¬à€X[ùX[€€ù[ùŸX\€€àH€€ù[ù\HOH	‹Ÿ\öY\…»»ŸX\€€ààù[¬à€X[ùX[€€ù[ù\\€ŸHH€€ù[ù\HOH	‹Ÿ\öY\…»»\\€ŸHàù[¬à€X[ùX[›Xù]Q\‹^SXô[H›Xù]Q\‹^SXô[¬à‹Ÿ[X›Y›ô[Z[‘›Xù]RYHù[¬àŸ[XôYY›Xù]P\YYHò[ŸN¬à›\Ÿ\ìX[ùX[TŸ[X›Y›Xù]HHò[ŸN¬àÿÿX⁄Y›ô[Z[‘›Xù]\»Hù[¬àÿÿX⁄YY€î€›»Hù[¬àÿÿX⁄Y›Xù]RŸ^HHù[¬àJN¬ÇàûH¬àö[ò[€›»H]ÿZ]›ô[Z[‘›Xù]TŸ\ùöXŸKö[ú›[òŸKôô]⁄›Xù]T€› à\Nà€€ù[ù\Kà[YíYà[YíYàŸX\€€éà€€ù[ù\HOH	‹Ÿ\öY\…»»ŸX\€€ààù[à\\€ŸNà€€ù[ù\HOH	‹Ÿ\öY\…»»\\€ŸHàù[à
N¬àö[ò[›Xù]\»HY€î›Xù]T€›ôõ][ä€› N¬ÇàYà
[[›[ùYô]⁄⁄Ÿ[àOHÿY€î›Xù]Qô]⁄⁄Ÿ[äHô]\õàù[¬Çàö[ò[ÿX⁄RŸ^HBà€€ù[ù\HOH	‹Ÿ\öY\…»	âàŸX\€€àOHù[	âà\\€ŸHOHù[à»	…[YíYâŸX\€€éâ\\€ŸI¬àà[YíY¬ÇàÿÿX⁄Y›ô[Z[‘›Xù]\»H›Xù]\Œ¬àÿÿX⁄YY€î€›»H€›Œ¬àÿÿX⁄Y›Xù]RŸ^HHÿX⁄RŸ^N¬Çà]ÿZ]Ÿô]⁄[ôX^XôP]]‘Ÿ[X›Y€î›Xù]J
N¬ÇàYà
›Xù]\Àö\—[\H	âà[›[ùY
H¬àÿÿYôõ€Y\‹Ÿ[ôŸ\ãõŸä€€ù^
Kú⁄›‘€òX⁄–ò\äà€€ú›€òX⁄–ò\äà€€ù[ùà^
	”õ»€õ[ôH›Xù]\»õ›[ôõ‹à\»]I Kà
Kà
N¬àBÇàô]\õàòX⁄‹‘⁄Y]›Xù]TŸX\ò⁄ô\›[
à›Xù]\Œà›Xù]\Àà€›Œà€›ÀàŸ[X›Y›Xù]RYà‹Ÿ[X›Y›ô[Z[‘›Xù]RYàY[ù]SXô[à	‘›Xù]\»õ‹à	›Xù]Q\‹^SXô[	Àà[YíYà[YíYà€€ù[ù\Nà€€ù[ù\KàŸX\€€éà€€ù[ù\HOH	‹Ÿ\öY\…»»ŸX\€€ààù[à\\€ŸNà€€ù[ù\HOH	‹Ÿ\öY\…»»\\€ŸHàù[à
N¬àHÿ]⁄
JH¬àXùY‘ö[ù
	’öY[‘^Y\éàŸX\ò⁄›Xù]Hô]⁄òZ[Yà	I N¬àYà
[›[ùY
H¬àÿÿYôõ€Y\‹Ÿ[ôŸ\ãõŸäà€€ù^à
Kú⁄›‘€òX⁄–ò\ä€€ú›€òX⁄–ò\ä€€ù[ùà^
	‘›Xù]HŸX\ò⁄òZ[Y	 JJN¬àBàô]\õàù[¬àBàBÇàù]\ôOõ⁄Yà‹⁄›’òX⁄‹‘⁄Y]
ùZ[€€ù^€€ù^
H\ﬁ[ò»¬àÀ»[ò[ZXÿ[H\úŸHŸX\€€ãŸ\\€ŸHúõ€H›\úô[ùöY[…‹»ö[[ò[YBàö[ò[›\úô[ù]HHÿ›\úô[ù^XòX⁄’]Qõ‹íY[ù]J
N¬àö[ò[Ÿ\öY\“[ôõ»HŸ\öY\‘\úŸ\ãú\úŸQö[[ò[YJ›\úô[ù]JN¬àö[ò[ŸX\€€àBàŸ\öY\“[ôõÀúŸX\€€àœ»€X[ùX[€€ù[ùŸX\€€àœ»ŸYôôX›]ôP€€ù[ùŸX\€€é¬àö[ò[\\€ŸHBàŸ\öY\“[ôõÀô\\€ŸHœ»€X[ùX[€€ù[ù\\€ŸHœ»ŸYôôX›]ôP€€ù[ù\\€ŸN¬ÇàÀ»Ÿ]SQàQõ‹à›\úô[ù][BàÀ»õ‹àŸ\öY\Œà\Ÿ\»⁄\ôYSQàQ
[\\€Ÿ\»⁄\ôHÿ[YH⁄›»Q
BàÀ»õ‹à[›öY\Œà\Ÿ\»\ãZ][HSQàQ
XX⁄[›öYH[à€€X›[€à\»[ö\]YHQ
Bà›ö[ôœ»YôôX›]ôR[YíY¬àö[ò[Ÿ\öY\‘^[\›H‹Ÿ\öY\‘^[\›¬ÇàYà
€X[ùX[€€ù[ù[YíYOHù[	âà€X[ùX[€€ù[ù[YíYKö\”õ›[\JH¬àYôôX›]ôR[YíYH€X[ùX[€€ù[ù[YíY¬àH[ŸHYà
Ÿ\öY\‘^[\›OHù[
H¬àYà
Ÿ\öY\‘^[\›ö\‘Ÿ\öY\ H¬àÀ»Ÿ\öY\Œà\ŸH⁄\ôYSQàQàYôôX›]ôR[YíYHŸ\öY\‘^[\›ö[YíYœ»ŸYôôX›]ôP€€ù[ù[YíY¬àH[ŸH¬àÀ»[›öYH€€X›[€éàûH»Ÿ]Ÿô]⁄SQàQõ‹à›\úô[ù[ô^àYôôX›]ôR[YíYHŸ\öY\‘^[\›ôŸ][YíYõ‹í[ô^
ÿ›\úô[ù[ô^
N¬ÇàÀ»Yàõ›ÿX⁄YûH»ô]⁄]õ›»
\ﬁ[ò»ù]ŸHÿZ]õ‹à]
BàYà
YôôX›]ôR[YíYOHù[	âàŸYôôX›]ôP€€ù[ù[YíYOHù[
H¬àXùY‘ö[ù
à	’öY[‘^Y\éàô]⁄[ô»[›öYHY]Y]Hõ‹à[ô^	ÿ›\úô[ù[ô^ôYõ‹ôH⁄›⁄[ô»òX⁄‹…Àà
N¬àYôôX›]ôR[YíYH]ÿZ]Ÿ\öY\‘^[\›ôô]⁄[›öYSY]Y]Qõ‹í[ô^
àÿ›\úô[ù[ô^à
N¬àBÇàÀ»ò[òX⁄»»⁄YŸ]	‹»€€ù[ù[YíYYà›[ù[àYôôX›]ôR[YíYœœHŸYôôX›]ôP€€ù[ù[YíY¬àBàH[ŸH¬àÀ»⁄[ô€KYö[H^XòX⁄»
õ»^[\›
BàÀ»ûHÿX⁄Y⁄[ô€KYö[HSQàQ[à⁄YŸ]	‹»€€ù[ù[YíYàYôôX›]ôR[YíYH‹⁄[ô€Qö[R[YíYœ»ŸYôôX›]ôP€€ù[ù[YíY¬ÇàÀ»Yàõ›ÿX⁄YY]ûH»ô]⁄]õ›¬àYà
YôôX›]ôR[YíYOHù[	âàW‹⁄[ô€Qö[R[Yëô]⁄Y
H¬àXùY‘ö[ù
à	’öY[‘^Y\éàô]⁄[ô»⁄[ô€KYö[H[›öYHY]Y]HôYõ‹ôH⁄›⁄[ô»òX⁄‹…Àà
N¬à]ÿZ]Ÿô]⁄⁄[ô€Qö[S[›öYSY]Y]J
N¬àYôôX›]ôR[YíYH‹⁄[ô€Qö[R[YíY¬àBàBÇàÀ»]\õZ[ôH€€ù[ù\BàÀ»ö[‹ö]NàX[ùX[›ô\úöYHà⁄YŸ]ÿ⁄[õô[Y]Y]Hà^[\›]X›[€Çà›ö[ôœ»YôôX›]ôP€€ù[ù\HH€X[ùX[€€ù[ù\Hœ»ŸYôôX›]ôP€€ù[ù\N¬àYà
YôôX›]ôP€€ù[ù\HOHù[
H¬àYà
Ÿ\öY\‘^[\›Àö\‘Ÿ\öY\»OHùYJH¬àYôôX›]ôP€€ù[ù\HH	‹Ÿ\öY\…Œ¬àH[ŸHYà
YôôX›]ôR[YíYOHù[
H¬àÀ»ŸH]ôH[àSQàQ
Z]\àúõ€H^[\›‹à⁄[ô€KYö[H€⁄›\
BàÀ»Yàõ›HŸ\öY\À]	‹»H[›öYBàYôôX›]ôP€€ù[ù\HH	€[›öYIŒ¬àBàBÇàXùY‘ö[ù
à	’öY[‘^Y\éà‹[ö[ô»òX⁄‹‘⁄Y]⁄]€€ù[ù[YíYIYôôX›]ôR[YíY	¬à	ÿ€€ù[ù\OIYôôX›]ôP€€ù[ù\K	¬à	‹ŸX\€€èIŸX\€€ã\\€ŸOI\\€ŸH
\úŸYúõ€Nà	›\úô[ù]JIÀà
N¬Çàö[ò[›Xù]TŸX\€€àHYôôX›]ôP€€ù[ù\HOH	‹Ÿ\öY\…»»ŸX\€€ààù[¬àö[ò[›Xù]Q\\€ŸHHYôôX›]ôP€€ù[ù\HOH	‹Ÿ\öY\…»»\\€ŸHàù[¬ÇàÀ»ùZ[ÿX⁄HŸ^Hõ‹à›Xù]HÿX⁄[ô»
\ãZ][HZŸH[ôõ⁄YäBàö[ò[›ö[ôœ»ÿX⁄RŸ^HHYôôX›]ôR[YíYOHù[à»
›Xù]TŸX\€€àOHù[	âà›Xù]Q\\€ŸHOHù[à»	…YôôX›]ôR[YíYâ›Xù]TŸX\€€éâ›Xù]Q\\€ŸI¬ààYôôX›]ôR[YíY
Bààù[¬ÇàÀ»⁄X⁄»YàŸH]ôHÿX⁄Y\ãXY€à›Xù]H€›»õ‹à\»€€ù[ùÇàö[ò[\›Y€î›Xù]T€›è»ò\ŸT€›»Bà
ÿX⁄RŸ^HOHù[	âàÿÿX⁄Y›Xù]RŸ^HOHÿX⁄RŸ^JBà»ÿÿX⁄YY€î€›¬ààù[¬àÀ»[ÿ^\»[ò€YH][ò⁄\›\YY›Xù]\»
KôÀà[›UXôHÿ\[€ú Kà^BàÀ»\ô[â›SQãZŸ^YY€»^Hô]ô\à]ôH[àH\ãZ][HÿX⁄HXõ›ôH[ôàÀ»]\›ôH\[ôY[ò€€ô][€ò[JÈ›y¯ßy’›\ù⁄\ŸHY[ùYûZ[ô»H]H
⁄X⁄àÀ»‹[]\»ÿÿX⁄YY€î€› H€›[XZŸHHÿ\[€à‹õ›\\ÿ\X\ãÇàö[ò[\›Y€î›Xù]T€›è»ÿX⁄Y€›»H⁄[öôX›Y›Xù]T€›»OHù[à»Àããèÿò\ŸT€›Àããó⁄[öôX›Y›Xù]T€›»WBààò\ŸT€›Œ¬ÇàYà
ÿX⁄Y€›»OHù[
H¬àXùY‘ö[ù
à	’öY[‘^Y\éà\⁄[ô»	ÿÿX⁄Y€›Àõ[ô›HÿX⁄YY€à€›»õ‹àŸ^Nà	ÿX⁄RŸ^IÀà
N¬àBÇàYà
X€€ù^õ[›[ùY
Hô]\õé¬ÇàYà
’[öYöYY^Y\ìY[ùQ[òXõY
H¬à€‹[î^Y\ìY[ùP]
à^Y\ìY[ùTŸX›[€ãú›Xù]\Àà[YíYàYôôX›]ôR[YíYà€€ù[ù\NàYôôX›]ôP€€ù[ù\KàŸX\€€éà›Xù]TŸX\€€ãà\\€ŸNà›Xù]Q\\€ŸKàÿX⁄Y€›ŒàÿX⁄Y€›ÀàÿX⁄RŸ^NàÿX⁄RŸ^Kà
N¬àô]\õé¬àBÇà]ÿZ]òX⁄‹‘⁄Y]ú⁄› à€€ù^à‹^Y\ãà€ïòX⁄–⁄[ôŸYà
]Y[“Y›Xù]RY
H\ﬁ[ò»¬à›\Ÿ\ìX[ùX[TŸ[X›Y›Xù]HHùYN¬àYà
\›Xù]RYú›\ù’⁄]
	‹›ô[Z[Œâ JH¬à‹Ÿ]X›]ôQ^\õò[›Xù]T]
ù[
N¬àBàÀ»ô[Y[Xô\àH⁄‹Ÿ[à]Y[»[ô›XYŸHõ‹à\»TàŸ\öY\»
ÿ\úöY\»¬àÀ»]\à\\€Ÿ\»[ôù]\ôHŸ\‹⁄[€ú KàõÀ[‹ŸôàTãÇàÿÿ\\ôR\ê]Y[”[ô›XYŸJ]Y[“Y
N¬à]ÿZ]‹\ú⁄\›òX⁄–⁄⁄XŸJ]Y[“Y›Xù]RY
N¬àKàÀ»ö\ô\»€õH€àHŸ[ùZ[ôH›Xù]H›⁄]⁄
õ›]Y[Àõ›ôK\Ÿ[X›õ›BàÀ»òZ[YÿY
NàHﬁ[ò»ŸôúŸ]ÿ\»ÿ[Xúò]Yõ‹àHô]ö[›\»›Xù]KÇà€î›Xù]UòX⁄–⁄[ôŸYà‹ô\Ÿ]›Xù]Tﬁ[ò”ŸôúŸ]àÀ»[ôõ⁄Yö]›ôX[H\‹›õ›Y⁄\YYUëH
ÿ[YH›‹ôYŸ][ô»\¬àÀ»H^XòX⁄»Yò][»õ› KÇà]Y[‘\‹›õ›Y⁄àZ“\’ŸXà	âà]õ‹õKö\–[ôõ⁄Yà»ÿ]Y[‘\‹›õ›Y⁄[òXõYààù[à€ê]Y[‘\‹›õ›Y⁄⁄[ôŸYàZ“\’ŸXà	âà]õ‹õKö\–[ôõ⁄Yà»‹Ÿ]]Y[‘\‹›õ›Y⁄]ôBààù[à€î›Xù]T›[P⁄[ôŸYà€€î›Xù]T›[P⁄[ôŸYà€îﬁ[ò”›ô\õ^Tô\]Y\›Yà‹⁄›‘ﬁ[ò”›ô\õ^T[ô[à€€ù[ù[YíYàYôôX›]ôR[YíYà€€ù[ù\NàYôôX›]ôP€€ù[ù\Kà€€ù[ùŸX\€€éà›Xù]TŸX\€€ãà€€ù[ù\\€ŸNà›Xù]Q\\€ŸKàÿX⁄YY€î€›ŒàÿX⁄Y€›Àà€êY€î€›—ô]⁄Yà
€› H¬àÀ»ÿX⁄HH\ãXY€à€›»
[ôZ\àõ]õ⁄ôX›[€ã⁄X⁄BàÀ»]]À\Ÿ[X›]€€ú›[Y\ Hõ‹à\»€€ù[ùàYàHY[ù]Hÿ\¬àÀ»ö^Y⁄[HH⁄Y]ÿ\»‹[ãHY[ùYûHõ›»[ôXYHôKZŸ^YYàÀ»HÿX⁄H∫w^~)ﬁu\]\»Ÿ^YY»H›[H‹[ã][YHY[ù]H]\›õ›àÀ»€ÿòô\à]ÇàYà
ÿX⁄RŸ^HOHù[
Hô]\õé¬àYà
ÿÿX⁄Y›Xù]RŸ^HOHù[	âàÿÿX⁄Y›Xù]RŸ^HOHÿX⁄RŸ^JH¬àô]\õé¬àBàÿÿX⁄YY€î€›»H€›Œ¬àÿÿX⁄Y›ô[Z[‘›Xù]\»HY€î›Xù]T€›ôõ][ä€› N¬àÿÿX⁄Y›Xù]RŸ^HHÿX⁄RŸ^N¬àKàŸ[X›Y›ô[Z[‘›Xù]RYà‹Ÿ[X›Y›ô[Z[‘›Xù]RYà›Xù]TŸ[X›[€ê€‹úôX›[€éà‹›Xù]TŸ[X›[€ê€‹úôX›[€ãà€î›ô[Z[‘›Xù]TŸ[X›Yà
Y
H¬à‹Ÿ[X›Y›ô[Z[‘›Xù]RYHY¬à›\Ÿ\ìX[ùX[TŸ[X›Y›Xù]HHùYN¬àKà€ê\Q[XôYY›Xù]Nà
òX⁄ HOà‹Ÿ]›Xù]UòX⁄’⁄]XY€õ‹›X‹ àòX⁄Àà€›\òŸNà	›òX⁄‹À\⁄Y]Y[XôYY	Àà
Kà€ê\T›ô[Z[‘›Xù]Nàÿ\T›ô[Z[‘›Xù]Qúõ€UòX⁄‹‘⁄Y]à€íY[ùYûU]Nà⁄Y[ùYûU]P[ôô]⁄›Xù]\Àà›Xù]RY[ù]SXô[à‹›Xù]RY[ù]SXô[õ‹î⁄Y]

Kà
N¬àBÇàÀ»h– Unified player menu (Spotlight panel)+ßuÁ‚ùÁ@5£@5£@5£@5£@5£@5£@5£@5£@5£@∫w^~)ﬁt

  /// Opens the menu with the subtitle-identity context already resolved
  /// (the tracks-button path, which may await a metadata fetch first).
  void _openPlayerMenuAt(
    PlayerMenuSection section, {
    String? imdbId,
    String? contentType,
    int? season,
    int? episode,
    List<AddonSubtitleSlot>? cachedSlots,
    String? cacheKey,
  }) {
    _hideIptvZapBanner();
    _hideTimer?.cancel();
    _tvReleaseFocusForOverlay();
    setState(() {
      _playerMenuInitialSection = section;
      _menuImdbId = imdbId;
      _menuContentType = contentType;
      _menuSeason = season;
      _menuEpisode = episode;
      _menuCachedSlots = cachedSlots;
      _menuCacheKey = cacheKey;
      _showPlayerMenu = true;
      _controlsVisible.value = false;
    });
  }

  /// Opens the menu from a non-subtitle entry (speed, sleep, aspect,
  /// shuffle) without awaiting anything: identity comes from caches only.
  /// If the IMDb id was never fetched, the Subtitles pane still offers the
  /// "Fix the title" recovery, so nothing is lost"È›y¯ßy‘ just not pre-fetched.
  void _openPlayerMenuQuick(PlayerMenuSection section) {
    final currentTitle = _currentPlaybackTitleForIdentity();
    final seriesInfo = SeriesParser.parseFilename(currentTitle);
    final season =
        seriesInfo.season ?? _manualContentSeason ?? _effectiveContentSeason;
    final episode =
        seriesInfo.episode ?? _manualContentEpisode ?? _effectiveContentEpisode;

    String? imdbId;
    final seriesPlaylist = _seriesPlaylist;
    if (_manualContentImdbId != null && _manualContentImdbId!.isNotEmpty) {
      imdbId = _manualContentImdbId;
    } else if (seriesPlaylist != null) {
      imdbId = seriesPlaylist.isSeries
          ? (seriesPlaylist.imdbId ?? _effectiveContentImdbId)
          : (seriesPlaylist.getImdbIdForIndex(_currentIndex) ??
                _effectiveContentImdbId);
    } else {
      imdbId = _singleFileImdbId ?? _effectiveContentImdbId;
    }

    String? contentType = _manualContentType ?? _effectiveContentType;
    if (contentType == null) {
      if (seriesPlaylist?.isSeries == true) {
        contentType = 'series';
      } else if (imdbId != null) {
        contentType = 'movie';
      }
    }

    final subtitleSeason = contentType == 'series' ? season : null;
    final subtitleEpisode = contentType == 'series' ? episode : null;
    final String? cacheKey = imdbId != null
        ? (subtitleSeason != null && subtitleEpisode != null
              ? '$imdbId:$subtitleSeason:$subtitleEpisode'
              : imdbId)
        : null;
    final baseSlots = (cacheKey != null && _cachedSubtitleKey == cacheKey)
        ? _cachedAddonSlots
        : null;
    final cachedSlots = _injectedSubtitleSlots != null
        ? [...?baseSlots, ..._injectedSubtitleSlots!]
        : baseSlots;

    _openPlayerMenuAt(
      section,
      imdbId: imdbId,
      contentType: contentType,
      season: subtitleSeason,
      episode: subtitleEpisode,
      cachedSlots: cachedSlots,
      cacheKey: cacheKey,
    );
  }

  void _hidePlayerMenu() {
    if (!_showPlayerMenu) return;
    setState(() => _showPlayerMenu = false);
    if (PlatformUtil.isTelevision) _tvRootFocus.requestFocus();
  }

  /// The old tracks-sheet `onTrackChanged` closure, verbatim: shared tail of
  /// every track selection made from the menu.
  Future<void> _menuApplyTrackChange(String audioId, String subtitleId) async {
    _userManuallySelectedSubtitle = true;
    if (!subtitleId.startsWith('stremio:')) {
      _setActiveExternalSubtitlePath(null);
    }
    _captureIptvAudioLanguage(audioId);
    await _persistTrackChoice(audioId, subtitleId);
  }

  Future<void> _menuSelectAudio(String audioId, String currentSubId) async {
    final track = _player.state.tracks.audio
        .where((a) => a.id == audioId)
        .firstOrNull;
    if (track == null) return;
    await _player.setAudioTrack(track);
    await _menuApplyTrackChange(audioId, currentSubId);
  }

  Future<bool> _menuSubtitlesOff(String audioId) async {
    final applied = await _setSubtitleTrackWithDiagnostics(
      mk.SubtitleTrack.no(),
      source: 'player-menu-off',
    );
    if (!applied) return false;
    _selectedStremioSubtitleId = null;
    await _menuApplyTrackChange(audioId, 'no');
    return true;
  }

  Future<bool> _menuSelectEmbeddedSubtitle(String subId, String audioId) async {
    final track = _player.state.tracks.subtitle
        .where((s) => s.id == subId)
        .firstOrNull;
    if (track == null) {
      _showSubtitleFailureMessage(
        'That subtitle track is no longer available. Try another track.',
      );
      return false;
    }
    final applied = await _setSubtitleTrackWithDiagnostics(
      track,
      source: 'player-menu-embedded',
    );
    if (!applied) return false;
    _selectedStremioSubtitleId = null;
    await _menuApplyTrackChange(audioId, subId);
    return true;
  }

  /// Returns false when the download/apply failed+ßuÁ‚ùÁT the panel keeps the
  /// previous selection (and its sync offset) in that case.
  Future<bool> _menuSelectAddonSubtitle(
    StremioSubtitle sub,
    String audioId,
  ) async {
    // Playback continues behind the menu: if the content switches while the
    // download is in flight (auto-advance, zap), applying the stale subtitle
    // would attach it"È›y¯ßy‘ and persist its ids+ßuÁ‚ùÁT against the NEW item.
    final token = _addonSubtitleFetchToken;
    try {
      final filePath = await _downloadStremioSubtitleToTempFile(sub);
      if (filePath == null) {
        _showSubtitleFailureMessage(
          'Couldn∫w^~)ﬁut load subtitles. Check your connection or try another track.',
        );
        return false;
      }
      if (token != _addonSubtitleFetchToken || !mounted) {
        return false;
      }
      final track = mk.SubtitleTrack.uri(
        filePath,
        title: sub.displayName,
        language: sub.lang,
      );
      final applied = await _applyExternalSubtitleTrack(track);
      if (!applied) return false;
      if (token != _addonSubtitleFetchToken || !mounted) return false;
      _selectedStremioSubtitleId = sub.id;
      _setActiveExternalSubtitlePath(filePath);
      await _menuApplyTrackChange(audioId, 'stremio:${sub.id}');
      return true;
    } catch (e) {
      debugPrint('PlayerMenu: subtitle apply failed - $e');
      _showSubtitleFailureMessage(
        'CouldnÈ›y¯ßyŸt apply subtitles. Try another embedded or online track.',
      );
      return false;
    }
  }

  Future<bool> _applyStremioSubtitleFromTracksSheet(StremioSubtitle sub) async {
    final token = _addonSubtitleFetchToken;
    try {
      final filePath = await _downloadStremioSubtitleToTempFile(sub);
      if (filePath == null) {
        _showSubtitleFailureMessage(
          'Couldn∫w^~)ﬁut load subtitles. Check your connection or try another track.',
        );
        return false;
      }
      if (token != _addonSubtitleFetchToken || !mounted) {
        return false;
      }
      final applied = await _applyExternalSubtitleTrack(
        mk.SubtitleTrack.uri(
          filePath,
          title: sub.displayName,
          language: sub.lang,
        ),
      );
      if (!applied) return false;
      if (token != _addonSubtitleFetchToken || !mounted) return false;
      _setActiveExternalSubtitlePath(filePath);
      return true;
    } catch (e) {
      debugPrint('TracksSheet: subtitle apply failed - $e');
      _showSubtitleFailureMessage(
        'Couldn∫w^~)ﬁut apply subtitles. Try another embedded or online track.',
      );
      return false;
    }
  }

  Widget _buildPlayerMenuPanel() {
    final audios = _player.state.tracks.audio
        .where((a) => a.id.toLowerCase() != 'no')
        .toList(growable: false);
    final embedded = embeddedSubtitleTracks(_player.state.tracks.subtitle);
    final selectedSub = _selectedStremioSubtitleId != null
        ? 'stremio:$_selectedStremioSubtitleId'
        : _player.state.track.subtitle.id;
    // Captured, not read live: cache write-back must be keyed to the identity
    // the menu opened with (an identity fix re-keys through its own path).
    final cacheKey = _menuCacheKey;

    return PlayerMenuPanel(
      key: _playerMenuKey,
      initialSection: _playerMenuInitialSection,
      onClose: _hidePlayerMenu,
      // mpv's `auto` pseudo-entry heads the list, labeled for what it is+ßuÁ‚ùÁT
      // and kept, because persisting 'auto' is the only way to un-pin a
      // stored explicit track for this title (restore treats a stored 'auto'
      // as "use the default selection"). Real tracks are numbered without it
      // so the file's first stream still reads "Track 1".
      audioTracks: LanguageMapper.audioTrackOptions(
        audios,
        (id, label) => PlayerMenuTrackOption(id, label),
      ),
      selectedAudioId: _player.state.track.audio.id,
      onAudioSelected: _menuSelectAudio,
      audioPassthrough: !kIsWeb && Platform.isAndroid
          ? _audioPassthroughEnabled
          : null,
      onAudioPassthroughChanged: !kIsWeb && Platform.isAndroid
          ? _setAudioPassthroughLive
          : null,
      embeddedSubtitles: [
        for (final (i, s) in embedded.indexed)
          PlayerMenuTrackOption(s.id, LanguageMapper.labelForTrack(s, i)),
      ],
      selectedSubtitleId: selectedSub,
      onSubtitlesOff: _menuSubtitlesOff,
      onEmbeddedSubtitleSelected: _menuSelectEmbeddedSubtitle,
      onAddonSubtitleSelected: _menuSelectAddonSubtitle,
      onSubtitleTrackChanged: _resetSubtitleSyncOffset,
      contentImdbId: _menuImdbId,
      contentType: _menuContentType,
      contentSeason: _menuSeason,
      contentEpisode: _menuEpisode,
      cachedAddonSlots: _menuCachedSlots,
      onAddonSlotsFetched: (slots) {
        if (cacheKey == null) return;
        if (_cachedSubtitleKey != null && _cachedSubtitleKey != cacheKey) {
          return;
        }
        _cachedAddonSlots = slots;
        _cachedStremioSubtitles = AddonSubtitleSlot.flatten(slots);
        _cachedSubtitleKey = cacheKey;
      },
      onIdentifyTitle: _identifyTitleAndFetchSubtitles,
      subtitleIdentityLabel: _subtitleIdentityLabelForSheet(),
      onSubtitleStyleChanged: _onSubtitleStyleChanged,
      onSyncRequested: _showSyncOverlayPanel,
      externalAudioChannels:
          _effectiveIptvChannels ?? widget.iptvChannels ?? const <IptvChannel>[],
      selectedExternalAudioUrl: _externalIptvAudioUrl,
      onExternalAudioPickerRequested: _showExternalAudioPicker,
      onExternalAudioRemove: _removeExternalIptvAudio,
      showSpeed: !_iptvZapBannerOwnsIdentity,
      speed: _playbackSpeed,
      onSpeedSelected: _setPlaybackSpeed,
      aspectMode: _aspectMode,
      onAspectSelected: _setAspectModeDirect,
      sleepMode: _sleepTimerMode,
      sleepArmedMinutes: _sleepTimerArmedMinutes,
      sleepMinutesLeft: _sleepTimerMinutesLeft,
      allowEndOfItem: _currentIptvChannel?.isLive != true,
      onSleepSelected: _applySleepTimerSelection,
      hasPlaylist:
          (_activePlaylist != null && _activePlaylist!.isNotEmpty) ||
          _canFetchEpisodes,
      continuousShuffle: _continuousShuffleEnabled,
      onShuffleOnce: () {
        _hidePlayerMenu();
        unawaited(_playRandomOnce(disableContinuousShuffle: true));
      },
      onShuffleContinuousToggle: () => unawaited(_toggleContinuousShuffle()),
    );
  }

  /// Reset subtitle-related state when switching content.
  void _resetSubtitleState() {
    _cachedStremioSubtitles = null;
    _cachedAddonSlots = null;
    _cachedSubtitleKey = null;
    _selectedStremioSubtitleId = null;
    _manualContentImdbId = null;
    _manualContentType = null;
    _manualContentSeason = null;
    _manualContentEpisode = null;
    _manualSubtitleDisplayLabel = null;
    _embeddedSubtitleApplied = false;
    _userManuallySelectedSubtitle = false;
    _trackPreferencesReadyForAddonSubtitles = false;
    _addonSubtitleFetchToken++;
    _subtitleDiagnosticGeneration++;
    _activeSubtitleApplyAttempt = null;
    _cleanupTempSubtitleFilesSync();
    _setActiveExternalSubtitlePath(null);
    _showSyncOverlay = false;
    // The menu's subtitle pane is keyed to the outgoing item's identity.
    _showPlayerMenu = false;
    // Content changed: the previous item's sync offset no longer applies.
    _resetSubtitleSyncOffset();
  }

  /// Restore audio and subtitle track preferences
  Future<void> _restoreTrackPreferences() async {
    // Capture token to detect if content changes during async operations
    final restoreToken = _addonSubtitleFetchToken;

    try {
      debugPrint(
        'SubAuto: _restoreTrackPreferences entered (token=$restoreToken)',
      );
      // Wait for subtitle tracks to be parsed from the media file
      // media_kit initially only has 'auto' and 'no' placeholder tracks
      await _waitForSubtitleTracks(token: restoreToken);

      if (restoreToken != _addonSubtitleFetchToken) {
        debugPrint(
          'SubAuto: restore aborted after track wait (content changed)',
        );
        return;
      }

      final seriesPlaylist = _seriesPlaylist;
      Map<String, dynamic>? trackPreferences;

      if (seriesPlaylist != null && seriesPlaylist.isSeries) {
        // For series content, get preferences for the entire series
        trackPreferences = await StorageService.getSeriesTrackPreferences(
          seriesTitle: seriesPlaylist.seriesTitle ?? 'Unknown Series',
        );
      } else {
        // For non-series content, get preferences for this specific video
        final videoTitle = widget.title.isNotEmpty
            ? widget.title
            : 'Unknown Video';
        trackPreferences = await StorageService.getVideoTrackPreferences(
          videoTitle: videoTitle,
        );
      }

      // Bail out if content changed during preferences fetch
      if (restoreToken != _addonSubtitleFetchToken) {
        debugPrint(
          'SubAuto: restore aborted (content changed during prefs fetch)',
        );
        return;
      }

      final subTracksNow = _player.state.tracks.subtitle
          .map((t) => '${t.id}/${t.language}/${t.title}')
          .toList();
      debugPrint(
        'SubAuto: restore start+ßuÁ‚ùÁT prefs=${trackPreferences == null ? 'NONE' : trackPreferences.toString()} '
        'subtitleTracks=$subTracksNow currentSub=${_player.state.track.subtitle.id}',
      );

      bool subtitleApplied = false;

      if (trackPreferences != null) {
        final audioTrackId = trackPreferences['audioTrackId'] as String?;
        final subtitleTrackId = trackPreferences['subtitleTrackId'] as String?;

        // Apply audio track preference"È›y¯ßy‘ only if the stored id exists in
        // THIS file (mirrors the subtitle branch). Prefs are keyed by title
        // and store bare mpv ordinals, so a different release of the same
        // title can carry the ordinal elsewhere; the old fallback landed on
        // tracks.audio.first, which is the 'auto' pseudo-track.
        if (audioTrackId != null &&
            audioTrackId.isNotEmpty &&
            audioTrackId != 'auto') {
          final audioTrack = _player.state.tracks.audio
              .where((track) => track.id == audioTrackId)
              .firstOrNull;
          if (audioTrack != null) {
            await _player.setAudioTrack(audioTrack);
          } else {
            await _applyDefaultAudioLanguage();
          }
        } else {
          // No stored audio preference - apply default audio language setting
          await _applyDefaultAudioLanguage();
        }

        // Bail out if content changed during audio track application
        if (restoreToken != _addonSubtitleFetchToken) return;

        // Apply subtitle track preference. A stored 'auto' is mpv's default
        // placeholder"È›y¯ßy‘ persisted whenever the user changed AUDIO without
        // ever picking a subtitle"È›y¯ßy‘ not an explicit subtitle choice. Honoring
        // it would mark an embedded subtitle as applied (mpv 'auto' shows the
        // file's default track, often English) and block addon auto-select of
        // the preferred language. Mirror the audio branch's 'auto' guard and
        // fall through to the default-language path instead.
        if (subtitleTrackId != null &&
            subtitleTrackId.isNotEmpty &&
            subtitleTrackId != 'auto') {
          final tracks = _player.state.tracks;
          // Check if the stored track actually exists in this video
          final trackExists = tracks.subtitle.any(
            (t) =>
                t.id == subtitleTrackId && !isAppManagedAddonSubtitleTrack(t),
          );
          if (trackExists) {
            final subtitleTrack = tracks.subtitle.firstWhere(
              (track) =>
                  track.id == subtitleTrackId &&
                  !isAppManagedAddonSubtitleTrack(track),
            );
            // A stored pick that CONFLICTS with the current global default
            // language is stale"È›y¯ßy‘ it predates the user changing the setting
            // (the ids are bare mpv ordinals, so it can't be trusted across
            // setting changes). Let the default-language path win instead:
            // embedded match first, else addon auto-select. Stored 'no'
            // (explicit off for this series) is always honored.
            final defaultLang =
                await StorageService.getDefaultSubtitleLanguage();
            final conflictsWithDefault =
                subtitleTrackId != 'no' &&
                defaultLang != null &&
                (defaultLang == 'off' ||
                    !(LanguageMapper.matchesLanguage(
                          defaultLang,
                          subtitleTrack.language,
                        ) ||
                        LanguageMapper.matchesLanguage(
                          defaultLang,
                          subtitleTrack.title,
                        )));
            if (conflictsWithDefault) {
              debugPrint(
                'SubAuto: stored track id=$subtitleTrackId '
                '(lang=${subtitleTrack.language}/${subtitleTrack.title}) '
                'conflicts with default=$defaultLang ∫w^~)ﬁv default-language path',
              );
              subtitleApplied = await _applyDefaultSubtitleLanguage();
            } else {
              debugPrint(
                'SubAuto: applying STORED subtitle track id=$subtitleTrackId '
                '(lang=${subtitleTrack.language}/${subtitleTrack.title})"È›y¯ßy‘ blocks addon auto-select',
              );
              subtitleApplied = await _setSubtitleTrackWithDiagnostics(
                subtitleTrack,
                source: 'restore-stored-embedded',
              );
            }
          } else {
            // Stored track doesn't exist in this video - fall through to default
            debugPrint(
              'SubAuto: stored subtitle id=$subtitleTrackId not in this file+ßuÁ‚ùÁR default-language path',
            );
            subtitleApplied = await _applyDefaultSubtitleLanguage();
          }
        } else {
          // No stored subtitle preference - apply default subtitle language setting
          debugPrint(
            'SubAuto: stored subtitle id=$subtitleTrackId treated as no-choice ∫w^~)ﬁv default-language path',
          );
          subtitleApplied = await _applyDefaultSubtitleLanguage();
        }
      } else {
        // No track preferences at all - apply default language settings
        debugPrint('SubAuto: no stored prefs ∫w^~)ﬁv default-language path');
        await _applyDefaultAudioLanguage();
        subtitleApplied = await _applyDefaultSubtitleLanguage();
      }

      // IPTV series: the language-based memory wins over the per-title ordinal
      // / global default applied above (episodes are separate files whose track
      // orderings differ, so only language carries). No-op off a series episode.
      // No switch is in flight on the initial open, so the current ticket is a
      // valid generation for the staleness guard.
      if (_isIptvSeriesContext) {
        await _applyIptvAudioPreference(_iptvSwitchTicket);
      }

      // Final check before applying state
      if (restoreToken != _addonSubtitleFetchToken) {
        debugPrint('SubAuto: restore aborted post-apply (content changed)');
        return;
      }

      // Track if embedded subtitle was applied for addon fallback
      _embeddedSubtitleApplied = subtitleApplied;
      _trackPreferencesReadyForAddonSubtitles = true;
      debugPrint(
        'SubAuto: restore done ∫w^~)ﬁt embeddedSubtitleApplied=$subtitleApplied"È›y¯ßy“ running addon auto-select',
      );

      // Always fetch Stremio addon subtitles proactively (like Android TV)
      // Auto-selection will only happen if no embedded subtitle was applied
      _fetchAndMaybeAutoSelectAddonSubtitle();
    } catch (e) {
      debugPrint('SubAuto: restore FAILED with exception: $e');
    }
  }

  /// Apply default audio language from settings (when no stored preference exists)
  Future<void> _applyDefaultAudioLanguage() async {
    try {
      final defaultLang = await StorageService.getDefaultAudioLanguage();
      if (defaultLang == null) {
        // No preference set - do nothing, let player use its default
        return;
      }

      final tracks = _player.state.tracks;
      if (tracks.audio.isEmpty) return;

      // If mpv's own selection (via the `alang` set at configure time)
      // already matches the preference, keep it: mpv's matcher weighs the
      // default/forced dispositions, so on a file with a normal and a
      // commentary track in the same language it lands on the right one"È›y¯ßy‘
      // the first-match loop below would overwrite that with whichever
      // matching track enumerates first.
      final platform = _player.platform;
      if (platform is mk.NativePlayer) {
        try {
          final currentLang = await platform.getProperty(
            'current-tracks/audio/lang',
          );
          if (LanguageMapper.matchesLanguage(defaultLang, currentLang)) {
            return;
          }
        } catch (_) {
          // Property unanswered ∫w^~)ﬁt fall through to the metadata matcher.
        }
      }

      // Find an audio track matching the preferred language using robust matching
      mk.AudioTrack? matchingTrack;
      for (final track in tracks.audio) {
        if (LanguageMapper.matchesLanguage(defaultLang, track.language)) {
          matchingTrack = track;
          break;
        }
        // Also check title field as some tracks store language there
        if (LanguageMapper.matchesLanguage(defaultLang, track.title)) {
          matchingTrack = track;
          break;
        }
      }

      if (matchingTrack != null) {
        await _player.setAudioTrack(matchingTrack);
      }
    } catch (e) {
      // Silently fail - audio preference is non-critical
    }
  }

  /// Apply default subtitle language from settings (when no stored preference exists)
  /// Returns true if an embedded subtitle was found and applied, false otherwise.
  Future<bool> _applyDefaultSubtitleLanguage({
    bool ignoreSourcePriority = false,
  }) async {
    final token = _addonSubtitleFetchToken;
    try {
      final defaultLang = await StorageService.getDefaultSubtitleLanguage();
      debugPrint('SubAuto: defaultSubtitleLanguage setting = $defaultLang');
      if (token != _addonSubtitleFetchToken || _userManuallySelectedSubtitle) {
        return false;
      }
      if (!ignoreSourcePriority && defaultLang != 'off') {
        final order = await StorageService.getSubtitleSourcePriority();
        if (token != _addonSubtitleFetchToken ||
            _userManuallySelectedSubtitle) {
          return false;
        }
        if (order.first != SubtitleSourcePriority.embedded) return false;
      }
      if (defaultLang == null) {
        var selectedId = _player.state.track.subtitle.id;
        final platform = _player.platform;
        if (platform is mk.NativePlayer) {
          try {
            // Dart may still report "auto" while mpv has selected a real sid.
            selectedId = await platform.getProperty('sid');
          } catch (_) {
            // Fall back to media_kit's reported selection.
          }
        }
        if (token != _addonSubtitleFetchToken ||
            _userManuallySelectedSubtitle) {
          return false;
        }
        final track = subtitleWithoutLanguagePreference(
          _player.state.tracks.subtitle,
          selectedId: selectedId,
        );
        if (track == null) return false;
        return _setSubtitleTrackWithDiagnostics(
          track,
          source: 'no-preference-embedded',
        );
      }

      final tracks = _player.state.tracks;

      if (defaultLang == 'off') {
        // Explicitly disable subtitles
        final applied = await _setSubtitleTrackWithDiagnostics(
          mk.SubtitleTrack.no(),
          source: 'default-language-off',
        );
        return applied; // User explicitly disabled, don't try addon
      }

      // Find a subtitle track matching the preferred language using robust matching
      // This handles ISO 639-1, ISO 639-2, regional variants, and language names
      mk.SubtitleTrack? matchingTrack;
      for (final track in tracks.subtitle) {
        if (isAppManagedAddonSubtitleTrack(track)) continue;
        if (LanguageMapper.matchesLanguage(defaultLang, track.language)) {
          matchingTrack = track;
          break;
        }
        // Also check title field as some tracks store language there
        if (LanguageMapper.matchesLanguage(defaultLang, track.title)) {
          matchingTrack = track;
          break;
        }
      }

      if (matchingTrack != null) {
        debugPrint(
          'SubAuto: matched EMBEDDED track id=${matchingTrack.id} lang=${matchingTrack.language} title=${matchingTrack.title} ∫w^~)ﬁt applying',
        );
        return _setSubtitleTrackWithDiagnostics(
          matchingTrack,
          source: 'default-language-embedded',
        );
      }
      debugPrint(
        'SubAuto: no $defaultLang embedded track ∫w^~)ﬁv returning false (addon auto-select may run)',
      );
      return false;
    } catch (e) {
      // Silently fail - subtitle preference is non-critical
      debugPrint('SubAuto: _applyDefaultSubtitleLanguage FAILED: $e');
      return false;
    }
  }

  /// Download an addon subtitle's raw bytes and write them to a temp file.
  ///
  /// Returning a file path (rather than a pre-decoded string) lets libmpv
  /// auto-detect the character encoding via its `sub-codepage=auto` default,
  /// which correctly handles GBK, Big5, EUC-KR, Windows-125x, etc. Pre-decoding
  /// via `http.Response.body` would silently corrupt non-UTF-8 subtitle files.
  Future<String?> _downloadStremioSubtitleToTempFile(
    StremioSubtitle sub,
  ) async {
    try {
      final uri = Uri.parse(sub.url);
      final dir = await getTemporaryDirectory();
      final stem = externalSubtitleCacheStem(sub.url);
      for (final ext in const [
        'srt',
        'vtt',
        'ass',
        'ssa',
        'ttml',
        'xml',
        'sub',
      ]) {
        final cached = File('${dir.path}/stremio_sub_$stem.$ext');
        if (cached.existsSync()) {
          final cachedLength = cached.lengthSync();
          if (cachedLength > 0 && cachedLength <= maxDecodedSubtitleBytes) {
            _tempSubtitleFiles.add(cached.path);
            return cached.path;
          }
          cached.deleteSync();
        }
      }

      final client = http.Client();
      late http.StreamedResponse response;
      try {
        response = await client
            .send(http.Request('GET', uri))
            .timeout(const Duration(seconds: 15));
        final declaredLength = response.contentLength;
        if (declaredLength != null &&
            declaredLength > maxSubtitleResponseBytes) {
          debugPrint(
            'VideoPlayer: Subtitle download rejected: '
            '$declaredLength bytes exceeds limit',
          );
          return null;
        }
        if (response.statusCode != 200) {
          debugPrint(
            'VideoPlayer: Subtitle download failed: HTTP ${response.statusCode}',
          );
          return null;
        }

        final responseBytes = await readBoundedSubtitleResponse(
          response.stream,
        ).timeout(const Duration(seconds: 15));
        final payload = prepareExternalSubtitlePayload(responseBytes, uri);
        final file = File('${dir.path}/stremio_sub_$stem.${payload.extension}');
        final partial = File('${file.path}.part');
        await partial.writeAsBytes(payload.bytes, flush: true);
        if (file.existsSync()) file.deleteSync();
        await partial.rename(file.path);
        _tempSubtitleFiles.add(file.path);
        debugPrint(
          'VideoPlayer: Subtitle written to temp file: ${file.path} '
          '(${payload.bytes.length} bytes)',
        );
        return file.path;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('VideoPlayer: Subtitle download/write failed: $e');
      return null;
    }
  }

  /// Load a replacement first, then unload older addon tracks. A malformed
  /// replacement therefore leaves the currently working subtitle untouched.
  Future<bool> _applyExternalSubtitleTrack(mk.SubtitleTrack track) async {
    // Track IDs are small mpv ordinals and may be reused by the next media.
    // Keep the content generation with this operation so a delayed apply can
    // never remove a same-numbered subtitle from newly opened content.
    final contentToken = _addonSubtitleFetchToken;
    final oldExternalIds = _player.state.tracks.subtitle
        .where(isAppManagedAddonSubtitleTrack)
        .map((subtitle) => subtitle.id)
        .toList(growable: false);

    final applied = await _setSubtitleTrackWithDiagnostics(
      track,
      source: 'addon-external',
    );
    if (!applied) return false;

    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      for (final id in oldExternalIds) {
        if (!mounted || contentToken != _addonSubtitleFetchToken) {
          debugPrint(
            'VideoPlayer: Content changed during addon subtitle cleanup; '
            'stopping before track $id',
          );
          return false;
        }
        try {
          await platform.command(['sub-remove', id]);
        } catch (e) {
          debugPrint('VideoPlayer: Failed to unload external subtitle $id: $e');
        }
      }
    }
    return true;
  }

  /// Delete any temp subtitle files we've written. Called from dispose.
  void _cleanupTempSubtitleFilesSync() {
    for (final path in _tempSubtitleFiles) {
      try {
        File(path).deleteSync();
      } catch (e) {
        debugPrint('VideoPlayer: Failed to delete temp subtitle $path: $e');
      }
    }
    _tempSubtitleFiles.clear();
  }

  /// Fetch Stremio addon subtitles proactively and auto-select if no embedded subtitle was applied.
  /// This mirrors the Android TV behavior where subtitles are always fetched on playback start.
  Future<void> _fetchAndMaybeAutoSelectAddonSubtitle() async {
    // Capture token at start to detect if content changes during async operations
    final fetchToken = _addonSubtitleFetchToken;

    try {
      // Get content info for Stremio subtitle fetch
      final seriesPlaylist = _seriesPlaylist;
      String? imdbId;
      String contentType;
      int? season;
      int? episode;

      if (_manualContentImdbId != null && _manualContentImdbId!.isNotEmpty) {
        imdbId = _manualContentImdbId;
        contentType = _manualContentType == 'series' ? 'series' : 'movie';
        if (contentType == 'series') {
          season = _manualContentSeason;
          episode = _manualContentEpisode;
          if ((season == null || episode == null) &&
              seriesPlaylist != null &&
              seriesPlaylist.isSeries) {
            final currentEp = _findSeriesEpisodeForCurrentIndex(seriesPlaylist);
            season ??= currentEp?.seriesInfo.season;
            episode ??= currentEp?.seriesInfo.episode;
          }
          season ??= _currentStremioTvContentSeason ?? widget.contentSeason;
          episode ??= _currentStremioTvContentEpisode ?? widget.contentEpisode;
        }
      } else if (seriesPlaylist != null && seriesPlaylist.isSeries) {
        imdbId = seriesPlaylist.imdbId ?? _effectiveContentImdbId;
        contentType = 'series';
        // Get current episode info from playlist using current index
        final currentEp = _findSeriesEpisodeForCurrentIndex(seriesPlaylist);
        if (currentEp != null) {
          season = currentEp.seriesInfo.season;
          episode = currentEp.seriesInfo.episode;
        }
      } else {
        // Use widget's content IMDB ID or single file IMDB ID
        imdbId = _effectiveContentImdbId ?? _singleFileImdbId;
        // Single-file series playback: use widget params for S/E
        if (_effectiveContentType == 'series' &&
            _effectiveContentSeason != null &&
            _effectiveContentEpisode != null) {
          contentType = 'series';
          season = _effectiveContentSeason;
          episode = _effectiveContentEpisode;
        } else {
          contentType = 'movie';
        }
      }

      // Need IMDB ID to fetch Stremio subtitles
      if (imdbId == null || imdbId.isEmpty) {
        await _applySubtitleSourcePriority(
          const [],
          fetchToken,
          discoveryReady: false,
        );
        return;
      }
      debugPrint(
        'SubAuto: addon auto-select start ∫w^~)ﬁt imdb=$imdbId type=$contentType s=$season e=$episode',
      );

      // Build cache key
      final cacheKey = season != null && episode != null
          ? '$imdbId:$season:$episode'
          : imdbId;

      // Check if we have cached subtitles
      List<StremioSubtitle> subtitles;
      if (_cachedSubtitleKey == cacheKey && _cachedStremioSubtitles != null) {
        subtitles = _cachedStremioSubtitles!;
        debugPrint(
          'VideoPlayer: Using ${subtitles.length} cached addon subtitles',
        );
      } else {
        // Fetch Stremio subtitles proactively (per-addon slots, so the
        // sheet's addon groups are warm when opened)
        debugPrint('VideoPlayer: Fetching addon subtitles (IMDB: $imdbId)');
        final slots = await StremioSubtitleService.instance.fetchSubtitleSlots(
          type: contentType,
          imdbId: imdbId,
          season: season,
          episode: episode,
          onUpdate: (slots) {
            if (!mounted || fetchToken != _addonSubtitleFetchToken) return;
            unawaited(_applySubtitleSourcePriority(slots, fetchToken));
          },
        );
        subtitles = AddonSubtitleSlot.flatten(slots);

        // Check if content changed during fetch
        if (fetchToken != _addonSubtitleFetchToken) {
          debugPrint(
            'VideoPlayer: Content changed during addon subtitle fetch, discarding results',
          );
          return;
        }

        // Cache the results
        _cachedStremioSubtitles = subtitles;
        _cachedAddonSlots = slots;
        _cachedSubtitleKey = cacheKey;
        debugPrint(
          'VideoPlayer: Fetched and cached ${subtitles.length} addon subtitles',
        );
      }

      await _applySubtitleSourcePriority(
        _cachedAddonSlots ?? const [],
        fetchToken,
      );
    } catch (e) {
      debugPrint('SubAuto: auto-select FAILED with exception: $e');
    }
  }

  Future<void> _applySubtitleSourcePriority(
    List<AddonSubtitleSlot> slots,
    int token, {
    bool discoveryReady = true,
  }) async {
    if (!mounted || token != _addonSubtitleFetchToken) return;
    await _subtitlePrioritySelectionQueue.submit(
      SubtitlePriorityUpdate(token, slots, discoveryReady: discoveryReady),
      _applySubtitlePriorityUpdate,
    );
  }

  Future<void> _applySubtitlePriorityUpdate(
    SubtitlePriorityUpdate update,
  ) async {
    bool valid() =>
        mounted &&
        update.token == _addonSubtitleFetchToken &&
        _trackPreferencesReadyForAddonSubtitles &&
        !_embeddedSubtitleApplied &&
        !_userManuallySelectedSubtitle &&
        _selectedStremioSubtitleId == null;
    if (!valid()) return;
    try {
      final language = await StorageService.getDefaultSubtitleLanguage();
      final saved = await StorageService.getSubtitleSourcePriority();
      String? selectedPath;
      final result = await selectSubtitleBySourcePriority(
        saved: saved,
        language: language,
        slots: update.slots,
        discoveryReady: update.discoveryReady,
        isCurrent: valid,
        tryEmbedded: () async {
          // A manual title search explicitly asks for online subtitles.
          if (_manualContentImdbId?.isNotEmpty == true) return false;
          return _applyDefaultSubtitleLanguage(ignoreSourcePriority: true);
        },
        tryAddon: (sub) async {
          final path = await _downloadStremioSubtitleToTempFile(sub);
          if (!valid() || path == null) return false;
          final applied = await _applyExternalSubtitleTrack(
            mk.SubtitleTrack.uri(
              path,
              title: sub.displayName,
              language: sub.lang,
            ),
          );
          if (applied) selectedPath = path;
          return applied;
        },
      );
      if (!valid() || result == null) return;
      if (result.addon case final sub?) {
        _selectedStremioSubtitleId = sub.id;
        _setActiveExternalSubtitlePath(selectedPath!);
      } else if (!result.provisional) {
        _embeddedSubtitleApplied = true;
      }
    } catch (e) {
      debugPrint('SubAuto: source priority apply failed: $e');
    }
  }

  SeriesEpisode? _findSeriesEpisodeForCurrentIndex(
    SeriesPlaylist seriesPlaylist,
  ) {
    for (final episode in seriesPlaylist.allEpisodes) {
      if (episode.originalIndex == _currentIndex) {
        return episode;
      }
    }
    if (_currentIndex >= 0 &&
        _currentIndex < seriesPlaylist.allEpisodes.length) {
      return seriesPlaylist.allEpisodes[_currentIndex];
    }
    return null;
  }

  Future<void> _persistTrackChoice(String audio, String subtitle) async {
    final attempt = _activeSubtitleApplyAttempt;
    Completer<void>? persistenceDone;
    if (attempt != null &&
        attempt.successReturned &&
        _subtitlePreferenceMatchesAttempt(subtitle, attempt)) {
      attempt.persisted = true;
      attempt.persistedAudioId = audio;
      persistenceDone = Completer<void>();
      attempt.persistenceDone = persistenceDone;
    }
    try {
      final seriesPlaylist = _seriesPlaylist;
      if (seriesPlaylist != null && seriesPlaylist.isSeries) {
        // For series content, save preferences for the entire series
        await StorageService.saveSeriesTrackPreferences(
          seriesTitle: seriesPlaylist.seriesTitle ?? 'Unknown Series',
          audioTrackId: audio,
          subtitleTrackId: subtitle,
        );
      } else {
        // For non-series content, save preferences for this specific video
        final videoTitle = widget.title.isNotEmpty
            ? widget.title
            : 'Unknown Video';
        await StorageService.saveVideoTrackPreferences(
          videoTitle: videoTitle,
          audioTrackId: audio,
          subtitleTrackId: subtitle,
        );
      }
    } catch (e) {
      // Track persistence is best-effort; playback selection still succeeds.
    } finally {
      if (persistenceDone != null && !persistenceDone.isCompleted) {
        persistenceDone.complete();
      }
    }
  }

  static bool _subtitlePreferenceMatchesAttempt(
    String subtitle,
    _SubtitleApplyAttempt attempt,
  ) {
    if (attempt.requested.id == 'no') return subtitle == 'no';
    if (attempt.requested.uri || attempt.requested.data) {
      return subtitle.startsWith('stremio:');
    }
    return subtitle == attempt.requested.id;
  }

  /// Generate a stable hash from filename for non-series playlist state tracking
  String _generateFilenameHash(String filename) {
    // Remove file extension and normalize
    final nameWithoutExt = filename.replaceAll(RegExp(r'\.[^.]*$'), '');
    // Create a simple hash (we could use a proper hash function, but this is sufficient for our needs)
    final hash = nameWithoutExt.hashCode.toString();
    return hash;
  }
}

class _RandomChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RandomChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFCA5A5), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
