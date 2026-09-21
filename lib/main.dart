import 'package:flutter/material.dart';

import 'models/iptv_playlist.dart';
import 'screens/video_player_screen.dart';
import 'services/xtream_codes_service.dart';
import 'utils/media_kit_init.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKitInit.ensureInitialized();
  runApp(const DebrifyLiteApp());
}

class DebrifyLiteApp extends StatelessWidget {
  const DebrifyLiteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Debrify Lite',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFF080A0F),
    ),
    home: const XtreamLoginScreen(),
  );
}

class XtreamLoginScreen extends StatefulWidget {
  const XtreamLoginScreen({super.key});
  @override
  State<XtreamLoginScreen> createState() => _XtreamLoginScreenState();
}

class _XtreamLoginScreenState extends State<XtreamLoginScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _normalizeServer(String value) {
    var server = value.trim();
    if (server.isEmpty) return server;
    if (!server.startsWith('http://') && !server.startsWith('https://')) {
      server = 'http://$server';
    }
    while (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }
    return server;
  }

  Future<void> _connect() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final server = _normalizeServer(_server.text);
    final username = _username.text.trim();
    final password = _password.text.trim();

    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل Server URL و Username و Password');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = XtreamCodesService.instance;
      final auth = await service.authenticate(server, username, password);
      if (!auth.success) {
        throw Exception(auth.error ?? 'فشل تسجيل الدخول');
      }

      final result = await service.fetchLiveStreams(server, username, password);
      if (result.hasError) {
        throw Exception(result.error ?? 'تعذر تحميل القنوات');
      }
      if (result.channels.isEmpty) {
        throw Exception('لم يتم العثور على قنوات Live');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiteLiveTvScreen(
            serverUrl: server,
            username: username,
            password: password,
            channels: result.channels,
            categories: result.categories,
            expiry: auth.expDate,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const SizedBox(height: 36),
              const Icon(Icons.live_tv, size: 64),
              const SizedBox(height: 18),
              Text(
                'Debrify Lite',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'IPTV Player • Xtream Codes',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: _decoration('Server URL', Icons.dns),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _username,
                decoration: _decoration('Username', Icons.person),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: _decoration('Password', Icons.lock),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _connect,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('CONNECT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LiteLiveTvScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;
  final List<IptvChannel> channels;
  final List<String> categories;
  final DateTime? expiry;

  const LiteLiveTvScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.channels,
    required this.categories,
    this.expiry,
  });

  @override
  State<LiteLiveTvScreen> createState() => _LiteLiveTvScreenState();
}

class _LiteLiveTvScreenState extends State<LiteLiveTvScreen> {
  String _query = '';
  String? _category;

  List<IptvChannel> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.channels.where((c) {
      final categoryOk = _category == null || c.group == _category;
      final queryOk = q.isEmpty || c.searchKey.contains(q);
      return categoryOk && queryOk;
    }).toList(growable: false);
  }

  void _play(IptvChannel channel) {
    final index = widget.channels.indexOf(channel);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: channel.url,
          title: channel.name,
          showChannelName: true,
          channelName: channel.name,
          channelNumber: channel.channelNumber,
          httpHeaders: channel.playbackHeaders,
          iptvChannels: widget.channels,
          iptvStartIndex: index < 0 ? 0 : index,
          iptvCategories: widget.categories,
          iptvSourceName: 'Xtream',
          iptvContentType: 'live',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('Live TV • ${widget.channels.length}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search channels',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (widget.categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  ...widget.categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) =>
                            setState(() => _category = category),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: channels.isEmpty
                ? const Center(child: Text('No channels found'))
                : ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (_, i) {
                      final channel = channels[i];
                      return ListTile(
                        leading: SizedBox(
                          width: 54,
                          height: 42,
                          child: channel.logoUrl == null
                              ? const Icon(Icons.tv)
                              : Image.network(
                                  channel.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.tv),
                                ),
                        ),
                        title: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          channel.group ?? 'Live',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _play(channel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
