import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/iptv_playlist.dart';
import '../../services/iptv_service.dart';
import '../../services/storage_service.dart';
import '../../services/xtream_codes_service.dart';

/// Activation gate.
///
/// Previously rendered `assets/eagle-x2-design-v4.html` inside an Android
/// WebView. On Android TV the WebView platform view takes the native input
/// focus, so D-pad / OK / Back never reach Flutter and the page cannot be
/// operated with a remote (only a mouse works). This is now a native Flutter
/// widget tree with the same design, so Flutter's own focus system handles the
/// remote. The logo and QR images are still read from the same HTML asset
/// (embedded base64), so no new binary files are needed. Device-ID and
/// activation logic are unchanged.
class ActivationEntryScreen extends StatefulWidget {
  const ActivationEntryScreen({super.key, required this.activatedBuilder});

  final WidgetBuilder activatedBuilder;

  @override
  State<ActivationEntryScreen> createState() => _ActivationEntryScreenState();
}

class _ActivationEntryScreenState extends State<ActivationEntryScreen> {
  static const _supabaseUrl = 'https://gyadzfbfxayifwrpevuq.supabase.co';
  static const _publishableKey = 'sb_publishable_sOK57WGfBcTE75ArdZSmiQ_htG1tn-H';
  static const _managedPlaylistId = 'eagle-x-managed-iptv';

  static const _pg = Color(0xFF0B0F1A);
  static const _brass = Color(0xFFC8A45A);
  static const _brass2 = Color(0xFFE6C982);
  static const _txt = Color(0xFFEEF1F7);
  static const _mut = Color(0xFF94A3BF);

  // Same messages the old HTML page showed for each status.
  static const _statusMessages = <String, String>{
    'active': 'تم تفعيل الجهاز بنجاح',
    'pending': 'الجهاز بانتظار اعتماد المشرف من لوحة التحكم',
    'expired': 'انتهت صلاحية التفعيل؛ يرجى مراجعة الدعم',
    'suspended': 'تم إيقاف هذا الجهاز؛ يرجى مراجعة الدعم',
    'not_found': 'تم عرض معرّف الجهاز؛ أضف الجهاز والاشتراك من لوحة التحكم',
    'offline': 'تعذر الاتصال للتحقق من التفعيل؛ حاول مرة أخرى',
  };

  String _deviceId = '';
  String _deviceIdError = '';
  String _message = 'بانتظار التحقق من حالة التفعيل';
  bool _checking = false;
  bool _activated = false;
  Uint8List? _logoBytes;
  Uint8List? _qrBytes;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
    _initialize();
  }

  /// Reads the logo (1st image) and QR (2nd image) embedded as base64 PNGs in
  /// the existing HTML asset. Purely decorative: failure is ignored.
  Future<void> _loadArtwork() async {
    try {
      final html =
          await rootBundle.loadString('assets/eagle-x2-design-v4.html');
      final matches = RegExp(r'<img src="data:image/png;base64,([^"]+)"')
          .allMatches(html)
          .toList();
      if (!mounted) return;
      setState(() {
        if (matches.isNotEmpty) {
          _logoBytes = base64Decode(matches[0].group(1)!);
        }
        if (matches.length > 1) {
          _qrBytes = base64Decode(matches[1].group(1)!);
        }
      });
    } catch (_) {}
  }

  Future<void> _initialize() async {
    try {
      final resolvedId = await _resolveDeviceId();
      if (!mounted) return;
      setState(() {
        _deviceId = resolvedId;
        _deviceIdError = '';
      });
      await _refreshActivation();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceId = '';
        _deviceIdError =
            'تعذّر قراءة معرّف الجهاز الثابت. أعد المحاولة قبل متابعة التفعيل.';
      });
    }
  }

  Future<String> _resolveDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? androidId;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        androidId = await const MethodChannel('debrify/device')
            .invokeMethod<String>('id');
      } catch (_) {
        // Use a previously persisted identifier only if one was generated
        // successfully on this installation before the native read failed.
      }

      if (androidId != null && androidId.trim().isNotEmpty) {
        // Keep the existing Eagle X identifier algorithm unchanged so that
        // already-registered devices continue to match the control panel.
        final digest = sha256.convert(
          utf8.encode('streamvault-device:' + androidId.trim()),
        );
        final token = digest.bytes
            .take(9)
            .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join();
        final generated = 'EV-' + token;
        await prefs.setString('eagle_x_device_identifier_v1', generated);
        return generated;
      }

      final stored = prefs.getString('eagle_x_device_identifier_v1');
      if (stored != null && stored.trim().isNotEmpty) return stored.trim();

      // Never invent a random ID on Android: it could bind the wrong device
      // or create a different record in the admin panel.
      throw StateError('Android device identifier unavailable');
    }

    // Other supported platforms get a one-time persisted app-specific ID.
    final stored = prefs.getString('eagle_x_device_identifier_v1');
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();

    final random = Random.secure();
    final seed = List<int>.generate(24, (_) => random.nextInt(256));
    final token = sha256.convert(seed).toString().substring(0, 18).toUpperCase();
    final generated = 'EV-' + token;
    await prefs.setString('eagle_x_device_identifier_v1', generated);
    return generated;
  }

  /// Same contract as the old JS `setActivationState(status, message)`.
  Future<void> _setPageState(String status, String message) async {
    if (!mounted) return;
    final custom = message.trim();
    setState(() {
      _message = custom.isNotEmpty
          ? custom
          : (_statusMessages[status.toLowerCase()] ??
              _statusMessages['pending']!);
    });
  }

  Future<void> _refreshActivation() async {
    if (_checking || _activated || _deviceId.isEmpty) return;
    _checking = true;
    await _setPageState('pending', 'جارٍ التحقق من حالة التفعيل…');
    try {
      final response = await http
          .post(
            Uri.parse(_supabaseUrl + '/functions/v1/device-status'),
            headers: const {
              'apikey': _publishableKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'device_identifier': _deviceId}),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> payload = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } catch (_) {}

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _setPageState(
          'offline',
          'تعذر التحقق من التفعيل حاليًا؛ حاول مرة أخرى',
        );
        return;
      }

      final status = (payload['status'] ?? 'pending').toString().toLowerCase();
      if (status != 'active') {
        final message = (payload['message'] ?? '').toString();
        await _setPageState(status, message);
        return;
      }

      final source = payload['iptv_source'];
      if (source is! Map<String, dynamic>) {
        await _setPageState(
          'pending',
          'الجهاز مفعّل، لكن بيانات اشتراك IPTV لم تكتمل بعد',
        );
        return;
      }

      await _installManagedPlaylist(source);
      if (!mounted) return;
      setState(() => _activated = true);
    } on FormatException {
      await _setPageState(
        'pending',
        'تم العثور على الاشتراك، لكن تعذر الاتصال بمصدر القنوات. راجع الدعم.',
      );
    } catch (_) {
      await _setPageState(
        'offline',
        'تعذر الاتصال للتحقق من التفعيل؛ حاول مرة أخرى',
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> _installManagedPlaylist(Map<String, dynamic> source) async {
    final type = (source['source_type'] ?? '').toString().toLowerCase();
    final host = (source['host_url'] ?? '').toString().trim();
    final username = (source['username'] ?? '').toString().trim();
    final password = (source['password'] ?? '').toString();
    final m3uUrl = (source['m3u_url'] ?? '').toString().trim();

    final isXtream = type == 'xtream';
    if (isXtream && (host.isEmpty || username.isEmpty || password.isEmpty)) {
      throw const FormatException('Incomplete Xtream IPTV source');
    }
    if (!isXtream && (type != 'm3u' || m3uUrl.isEmpty)) {
      throw const FormatException('Incomplete M3U IPTV source');
    }

    var serverUrl = isXtream ? host : '';
    while (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    if (isXtream) {
      final authentication = await XtreamCodesService.instance.authenticate(
        serverUrl,
        username,
        password,
      );
      if (!authentication.success) {
        throw const FormatException('xtream_source_unreachable');
      }
    } else {
      final validation = await IptvService.instance.fetchPlaylist(
        m3uUrl,
        numberingSourceKey: _managedPlaylistId,
        allowUnbound: true,
      );
      if (validation.hasError || validation.isEmpty) {
        throw const FormatException('m3u_source_unreachable');
      }
    }

    final playlist = IptvPlaylist(
      id: _managedPlaylistId,
      name: 'Eagle X IPTV',
      url: isXtream ? '' : m3uUrl,
      serverUrl: isXtream ? serverUrl : null,
      username: isXtream ? username : null,
      password: isXtream ? password : null,
      addedAt: DateTime.now(),
    );
    final existing = await StorageService.getIptvPlaylists(forSettings: true);
    final updated = <IptvPlaylist>[
      for (final item in existing)
        if (item.id != _managedPlaylistId) item,
      playlist,
    ];
    await StorageService.setIptvPlaylistsAndReload(
      updated,
      forSettings: true,
    );
    await StorageService.setIptvDefaultPlaylist(_managedPlaylistId);
  }

  // ------------------------------------------------------------------ UI ----

  Widget _headSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1),
          radius: 1.3,
          colors: [Color(0xFF1B273F), Color(0xFF0E1422), Color(0xFF0B0F1A)],
          stops: [0, 0.6, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_logoBytes != null)
            Image.memory(_logoBytes!, width: 150, fit: BoxFit.contain),
          const SizedBox(height: 4),
          const Text(
            'Eagle X2',
            style: TextStyle(
              color: Color(0xFFE6EBF5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x55C8A45A)),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'ID : ',
                      style: TextStyle(color: _mut),
                    ),
                    TextSpan(
                      text: _deviceId.isEmpty
                          ? 'بانتظار معرّف الجهاز'
                          : _deviceId,
                      style: const TextStyle(color: _brass2),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodySection() {
    return Container(
      color: const Color(0xFF0E1422),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.star_border_rounded, color: _brass2, size: 22),
              SizedBox(width: 8),
              Text(
                'مرحباً بك',
                style: TextStyle(
                  color: _txt,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _mut, fontSize: 13.5, height: 1.7),
          ),
          const SizedBox(height: 14),
          _TvButton(
            label: 'تحقق من التفعيل',
            autofocus: true,
            onPressed: _refreshActivation,
          ),
        ],
      ),
    );
  }

  Widget _stubSection() {
    const boldStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: _txt,
    );
    return Container(
      color: const Color(0xFF1B273F),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'لتفعيل التطبيق أو الحصول على اشتراك '),
                TextSpan(text: 'IPTV', style: boldStyle),
                TextSpan(text: '\nتواصل مع الدعم عبر مسح رمز '),
                TextSpan(text: 'QR', style: boldStyle),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: _mut, fontSize: 12.5, height: 1.9),
          ),
          if (_qrBytes != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _brass, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_qrBytes!, width: 100, height: 100),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ticket(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wide = size.width >= 680 && size.width > size.height;
    final Widget card = wide
        ? IntrinsicHeight(
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 105, child: _headSection()),
                Expanded(flex: 115, child: _bodySection()),
                Expanded(flex: 90, child: _stubSection()),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_headSection(), _bodySection(), _stubSection()],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 900 : 372),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
          border: Border.all(color: const Color(0x33C8A45A)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activated) return widget.activatedBuilder(context);

    if (_deviceIdError.isNotEmpty) {
      return Scaffold(
        backgroundColor: _pg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعذّر تحديد معرّف الجهاز',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _deviceIdError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB9C0CC)),
                  ),
                  const SizedBox(height: 20),
                  _TvButton(
                    label: 'إعادة المحاولة',
                    autofocus: true,
                    onPressed: _initialize,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pg,
      body: _deviceId.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE6C982),
                strokeWidth: 2.5,
              ),
            )
          : SafeArea(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: _ticket(context),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Remote-friendly button: focusable, shows a thick brass border when focused,
/// and fires on OK / Enter / gamepad A as well as on tap or mouse click.
class _TvButton extends StatefulWidget {
  const _TvButton({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF34476F) : const Color(0xFF2A3A5E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? const Color(0xFFC8A45A) : const Color(0x66C8A45A),
              width: _focused ? 3 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Color(0xFFE6C982),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
