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

  @override
  void initState() {
    super.initState();
    MainPageBridge.homeBoardReady.value = true;
    unawaited(loadPosters());
  }

  Future<void> loadPosters() async {
    try {
      await IptvCatalogDb.open();
      final playlists = await StorageService.getIptvPlaylists(forSettings: false);
      final movieItems = <IptvChannel>[], seriesItems = <IptvChannel>[];
      for (final p in playlists) {
        if (p.isVirtual || p.isLocalFile) continue;
        if (p.isXtreamCodes) {
          final mk = IptvCatalogKey.forPlaylist(p, 'vod');
          final sk = IptvCatalogKey.forPlaylist(p, 'series');
          if (mk != null) {
            final snap = IptvCatalogDb.snapshot(mk);
            if (snap != null) movieItems.addAll(snap.page(offset: 0, limit: 12, live: false).where((c) => (c.logoUrl ?? '').trim().isNotEmpty));
          }
          if (sk != null) {
            final snap = IptvCatalogDb.snapshot(sk);
            if (snap != null) seriesItems.addAll(snap.page(offset: 0, limit: 12, live: false).where((c) => (c.logoUrl ?? '').trim().isNotEmpty));
          }
        } else {
          final key = IptvCatalogKey.forPlaylist(p, 'live');
          if (key == null) continue;
          final snap = IptvCatalogDb.snapshot(key);
          if (snap == null) continue;
          for (final c in snap.page(offset: 0, limit: 40, live: false)) {
            if ((c.logoUrl ?? '').trim().isEmpty) continue;
            if (c.contentType == 'series') seriesItems.add(c);
            else if (c.contentType == 'vod' || (c.duration ?? 0) > 0) movieItems.add(c);
          }
        }
      }
      if (!mounted) return;
      setState(() { movies = movieItems.take(12).toList(); series = seriesItems.take(12).toList(); loading = false; });
    } catch (e) {
      debugPrint('IPTV dashboard posters unavailable: ' + e.runtimeType.toString());
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: LayoutBuilder(builder: (context, box) {
      final landscape = box.maxWidth > box.maxHeight && box.maxHeight < 650;
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
      child: const Icon(Icons.flight_rounded, color: blue, size: 20)),
    const SizedBox(width: 10),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Eagle Stream', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
      Text('LIVE TV · IPTV PREMIUM', style: TextStyle(fontSize: 10, color: muted)),
    ])),
    if (!loading) Text(movies.length.toString() + ' أفلام', style: const TextStyle(color: muted, fontSize: 10)),
  ]);

  Widget hero() {
    final featured = movies.isNotEmpty ? movies.first : null;
    return Container(width: double.infinity, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: blue.withOpacity(.18))),
      child: Stack(fit: StackFit.expand, children: [
        if (featured?.logoUrl != null) Image.network(featured!.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => artwork()) else artwork(),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.04), bg.withOpacity(.96)]))),
        Positioned(right: 14, left: 14, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EAGLE STREAM', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(featured?.name ?? 'استمتع بمحتوى اشتراكك', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => widget.onOpenSection('vod'), icon: const Icon(Icons.play_arrow_rounded, size: 16), label: const Text('استعرض المحتوى'),
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
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(items[i].logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallbackPoster()))),
              const SizedBox(height: 4), Text(items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ]))),
          )),
    ]),
  );

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
