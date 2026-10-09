import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/iptv_playlist.dart';
import '../../services/iptv_service.dart';
import '../../services/storage_service.dart';
import '../../services/xtream_codes_service.dart';

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

  late final WebViewController _controller;
  String _deviceId = '';
  String _deviceIdError = '';
  bool _pageReady = false;
  bool _checking = false;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0F1A))
      ..addJavaScriptChannel(
        'ActivationBridge',
        onMessageReceived: (message) {
          if (message.message == 'refresh') {
            _refreshActivation();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            if (!mounted || _pageReady) return;
            _pageReady = true;
            await _setPageState('pending', 'بانتظار التحقق من حالة التفعيل');
            if (mounted) await _refreshActivation();
          },
        ),
      );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final resolvedId = await _resolveDeviceId();
      if (!mounted) return;
      setState(() {
        _deviceId = resolvedId;
        _deviceIdError = '';
      });
      await _controller.loadFlutterAsset('assets/eagle-x2-design-v4.html');
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

  Future<void> _setPageState(String status, String message) async {
    if (!_pageReady) return;
    try {
      await _controller.runJavaScript(
        'window.setDeviceId(${jsonEncode(_deviceId)});'
        'window.setActivationState(${jsonEncode(status)}, ${jsonEncode(message)});',
      );
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    if (_activated) return widget.activatedBuilder(context);
    if (_deviceIdError.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phonelink_erase_outlined,
                    color: Color(0xFFE6C982),
                    size: 44,
                  ),
                  const SizedBox(height: 16),
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
                  FilledButton(
                    onPressed: _initialize,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: _deviceId.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE6C982),
                strokeWidth: 2.5,
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
