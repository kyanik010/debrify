import 'dart:async';
import 'package:flutter/material.dart';
import '../models/iptv_playlist.dart';
import '../services/iptv_catalog_db.dart';
import '../services/iptv_catalog_key.dart';
import '../services/storage_service.dart';
import '../services/main_page_bridge.dart';

class IptvHomeDashboard extends StatefulWidget {
  const IptvHomeDashboard({super.key, required this.onOpenSection});
  final ValueChanged<String> onOpenSection;
  @override
  State<IptvHomeDashboard> createState() => _IptvHomeDashboardState();
}

class _IptvHomeDashboardState extends State<IptvHomeDashboard> {
  static const bg = Color(0xFF0A101D), surface = Color(0x99131B2E);
  static const blue = Color(0xFF3B82F6), muted = Color(0xFF9CA3AF);
  List<IptvChannel> movies = const [], series = const [];
  bool loading = true;

  bool _posterLoadInFlight = false;
  Timer? _posterRefreshTimer;

  Future<void> loadPosters() async {
    if (_posterLoadInFlight) return;
    _posterLoadInFlight = true;
    try {
      await IptvCatalogDb.open();
      final playlists = await StorageService.getIptvPlaylists(forSettings: false);
      final movieItems = <IptvChannel>[];
      final seriesItems = <IptvChannel>[];

      // Walk the cached catalog in bounded pages until we have enough real
      // artwork. Filtering only the first 12/40 rows could falsely show an
      // empty shelf when early provider rows have no poster URL.
      Future<void> collectXtream(
        dynamic snapshot,
        List<IptvChannel> destination,
      ) async {
        var offset = 0;
        while (offset < snapshot.channelCount && destination.length < 12) {
          final page = snapshot.page(offset: offset, limit: 100, live: false);
          if (page.isEmpty) break;
          destination.addAll(
            page.where((channel) => _validArtworkUrl(channel.logoUrl))
                .take(12 - destination.length),
          );
          offset = (offset + page.length).toInt();
        }
      }

      for (final playlist in playlists) {
        if (playlist.isVirtual || playlist.isLocalFile) continue;

        if (playlist.isXtreamCodes) {
          final movieKey = IptvCatalogKey.forPlaylist(playlist, 'vod');
          final seriesKey = IptvCatalogKey.forPlaylist(playlist, 'series');

          if (movieKey != null && movieItems.length < 12) {
            final snapshot = IptvCatalogDb.snapshot(movieKey);
            if (snapshot != null) await collectXtream(snapshot, movieItems);
          }
          if (seriesKey != null && seriesItems.length < 12) {
            final snapshot = IptvCatalogDb.snapshot(seriesKey);
            if (snapshot != null) await collectXtream(snapshot, seriesItems);
          }
        } else {
          final key = IptvCatalogKey.forPlaylist(playlist, 'live');
          if (key == null) continue;
          final snapshot = IptvCatalogDb.snapshot(key);
          if (snapshot == null) continue;

          var offset = 0;
          while (offset < snapshot.channelCount &&
              (movieItems.length < 12 || seriesItems.length < 12)) {
            final page = snapshot.page(offset: offset, limit: 100, live: false);
            if (page.isEmpty) break;
            for (final channel in page) {
              if (!_validArtworkUrl(channel.logoUrl)) continue;
              if (channel.contentType == 'series' && seriesItems.length < 12) {
                seriesItems.add(channel);
              } else if ((channel.contentType == 'vod' ||
                      (channel.duration ?? 0) > 0) &&
                  movieItems.length < 12) {
                movieItems.add(channel);
              }
            }
            offset = (offset + page.length).toInt();
          }
        }
        if (movieItems.length >= 12 && seriesItems.length >= 12) break;
      }

      if (!mounted) return;
      setState(() {
        movies = movieItems.take(12).toList();
        series = seriesItems.take(12).toList();
        loading = false;
      });
    } catch (error) {
      debugPrint('IPTV dashboard posters unavailable: ${error.runtimeType}');
      if (mounted) setState(() => loading = false);
    } finally {
      _posterLoadInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();
    MainPageBridge.homeBoardReady.value = true;
    unawaited(loadPosters());
    // IPTV catalog sync writes to the local database independently of this
    // dashboard's lifecycle. Re-read cached rows periodically so posters that
    // arrive after the dashboard first opens become visible without a restart.
    _posterRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(loadPosters()),
    );
  }

  @override
  void dispose() {
    _posterRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: LayoutBuilder(builder: (context, box) {
      final landscape = box.maxWidth > box.maxHeight;
      return landscape ? landscapeBody() : portraitBody();
    })),
  );

  Widget portraitBody() => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header(), const SizedBox(height: 12), SizedBox(height: 140, child: hero()), const SizedBox(height: 14),
      posterSection('أحدث الأفلام', movies, 'vod', height: 150),
      const SizedBox(height: 12),
      for (final s in sections) ...[card(s), const SizedBox(height: 9)],
      footer(),
    ]),
  );

  Widget landscapeBody() => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(children: [
      header(compact: true), const SizedBox(height: 8),
      Expanded(child: Row(textDirection: TextDirection.rtl, children: [
        Expanded(flex: 6, child: Column(children: [
          Expanded(flex: 5, child: hero()), const SizedBox(height: 8),
          Expanded(flex: 4, child: posterSection('أحدث الأفلام', movies, 'vod')),
        ])),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: Column(children: [
          for (final s in sections) Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 7), child: card(s, compact: true))),
        ])),
      ])),
      footer(),
    ]),
  );

  Widget header({bool compact = false}) => Row(textDirection: TextDirection.rtl, children: [
    Container(width: compact ? 34 : 40, height: compact ? 34 : 40,
      decoration: BoxDecoration(color: blue.withOpacity(.12), shape: BoxShape.circle, border: Border.all(color: blue.withOpacity(.35))),
      child: const Icon(Icons.air_rounded, color: blue, size: 20)),
    const SizedBox(width: 10),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Eagle Stream', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('LIVE TV · IPTV PREMIUM', style: TextStyle(fontSize: 10, color: muted)),
        SizedBox(width: 5),
        DecoratedBox(decoration: BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x9910B981), blurRadius: 6)]), child: SizedBox(width: 6, height: 6)),
      ]),
    ])),
    if (!loading) Text(movies.length.toString() + ' أفلام', style: const TextStyle(color: muted, fontSize: 10)),
  ]);

  Widget hero() {
    final featured = movies.isNotEmpty ? movies.first : null;
    return Container(width: double.infinity, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: blue.withOpacity(.18))),
      child: Stack(fit: StackFit.expand, children: [
        if (_validArtworkUrl(featured?.logoUrl)) Image.network(featured!.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => artwork(), loadingBuilder: (context, child, progress) => progress == null ? child : artwork()) else artwork(),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.04), bg.withOpacity(.96)]))),
        Positioned(right: 14, left: 14, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.all(Radius.circular(4))), child: Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 6),
          Text(featured?.name ?? (loading ? 'جارٍ تحميل محتوى الاشتراك…' : 'لا توجد أفلام متاحة في الكتالوج'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => widget.onOpenSection('vod'), icon: const Icon(Icons.play_arrow_rounded, size: 16), label: const Text('شاهد الآن'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: blue.withOpacity(.6)), backgroundColor: blue.withOpacity(.18), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        ])),
      ]),
    );
  }

  Widget artwork() => const DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1B2D50), bg])),
    child: Center(child: Icon(Icons.movie_filter_rounded, size: 54, color: Color(0x553B82F6))),
  );

  Widget posterSection(String title, List<IptvChannel> items, String target, {double? height}) => SizedBox(
    height: height,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(textDirection: TextDirection.rtl, children: [
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => widget.onOpenSection(target), style: TextButton.styleFrom(foregroundColor: const Color(0xFF60A5FA), padding: EdgeInsets.zero, minimumSize: const Size(40, 24)), child: const Text('عرض الكل', style: TextStyle(fontSize: 10))),
      ]),
      const SizedBox(height: 5),
      Expanded(child: loading && items.isEmpty
        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: blue)))
        : items.isEmpty
          ? Container(alignment: Alignment.center, decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)), child: const Text('لا توجد بوسترات متاحة من المصدر', style: TextStyle(color: muted, fontSize: 10)))
          : ListView.separated(scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(width: 96, child: InkWell(onTap: () => widget.onOpenSection(target), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _validArtworkUrl(items[i].logoUrl) ? Image.network(items[i].logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallbackPoster(), loadingBuilder: (context, child, progress) => progress == null ? child : fallbackPoster()) : fallbackPoster())),
              const SizedBox(height: 4), Text(items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ]))),
          )),
    ]),
  );

  bool _validArtworkUrl(String? value) {
    final raw = value?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Widget fallbackPoster() => Container(color: const Color(0xFF131B2E), alignment: Alignment.center, child: const Icon(Icons.movie_outlined, color: muted, size: 24));

  static const sections = <_Section>[
    _Section('channels', 'القنوات', 'القنوات وتصنيفات المصدر', Icons.live_tv_rounded, Color(0xFF3B82F6)),
    _Section('vod', 'الأفلام', 'الأفلام المتاحة في اشتراكك', Icons.movie_rounded, Color(0xFF0EA5E9)),
    _Section('series', 'المسلسلات', 'المسلسلات وتصنيفاتها', Icons.video_library_rounded, Color(0xFF6366F1)),
    _Section('favorites', 'المفضلة', 'العناصر التي حفظتها', Icons.star_rounded, Color(0xFF06B6D4)),
    _Section('settings', 'الإعدادات', 'إعدادات التطبيق ومصادر IPTV', Icons.settings_rounded, Color(0xFF9CA3AF)),
  ];

  Widget card(_Section s, {bool compact = false}) => Material(
    color: surface, borderRadius: BorderRadius.circular(15),
    child: InkWell(onTap: () => widget.onOpenSection(s.id), borderRadius: BorderRadius.circular(15),
      child: Container(padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 4 : 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: blue.withOpacity(.16)), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]),
        child: Row(textDirection: TextDirection.rtl, children: [
          Container(width: compact ? 28 : 34, height: compact ? 28 : 34, decoration: BoxDecoration(color: s.color.withOpacity(.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: s.color.withOpacity(.35))), child: Icon(s.icon, color: s.color, size: compact ? 14 : 17)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.title, style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 14, fontWeight: FontWeight.w800)),
            if (!compact) Text(s.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
          ])),
          Icon(Icons.chevron_left_rounded, size: compact ? 17 : 20, color: muted),
        ]),
      ),
    ),
  );

  Widget footer() => const Padding(padding: EdgeInsets.only(top: 3, bottom: 2), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.graphic_eq_rounded, color: Color(0xFF4B5563), size: 12), SizedBox(width: 5),
    Text('Eagle Stream · IPTV', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
  ]));
}

class _Section {
  const _Section(this.id, this.title, this.subtitle, this.icon, this.color);
  final String id, title, subtitle;
  final IconData icon;
  final Color color;
}
