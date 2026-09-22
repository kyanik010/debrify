import 'package:flutter/material.dart';

import '../../../models/iptv_playlist.dart';
import 'tv_tappable.dart';

/// Picker for a second IPTV channel used only as the external audio source.
class ExternalAudioSheet extends StatefulWidget {
  final List<IptvChannel> channels;
  final String? currentVideoUrl;
  final String? selectedUrl;
  final Future<void> Function(IptvChannel channel) onSelected;
  final Future<void> Function()? onRemove;
  final double syncSeconds;
  final Future<void> Function(double seconds)? onSyncChanged;

  const ExternalAudioSheet({
    super.key,
    required this.channels,
    required this.currentVideoUrl,
    required this.selectedUrl,
    required this.onSelected,
    required this.onRemove,
    required this.syncSeconds,
    required this.onSyncChanged,
  });

  @override
  State<ExternalAudioSheet> createState() => _ExternalAudioSheetState();
}

class _ExternalAudioSheetState extends State<ExternalAudioSheet> {
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;

  List<IptvChannel> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.channels.where((c) {
      if (c.url == widget.currentVideoUrl) return false;
      if (q.isEmpty) return true;
      return c.searchKey.contains(q);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _select(IptvChannel channel) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSelected(channel);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _syncLabel() {
    if (widget.syncSeconds == 0) return '0.0 s';
    final sign = widget.syncSeconds > 0 ? '+' : '';
    return '\${sign}\${widget.syncSeconds.toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filtered;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'External Audio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.selectedUrl != null && widget.onRemove != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await widget.onRemove!();
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
            if (widget.selectedUrl != null && widget.onSyncChanged != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Audio Sync',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Audio earlier',
                        onPressed: () => widget.onSyncChanged!(widget.syncSeconds - 0.5),
                        icon: const Icon(Icons.remove, color: Colors.white70),
                      ),
                      Text(_syncLabel(), style: const TextStyle(color: Colors.white)),
                      IconButton(
                        tooltip: 'Audio later',
                        onPressed: () => widget.onSyncChanged!(widget.syncSeconds + 0.5),
                        icon: const Icon(Icons.add, color: Colors.white70),
                      ),
                      IconButton(
                        tooltip: 'Reset sync',
                        onPressed: () => widget.onSyncChanged!(0),
                        icon: const Icon(Icons.restart_alt, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search IPTV channels',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: channels.isEmpty
                  ? const Center(
                      child: Text(
                        'No IPTV channels found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: channels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        final selected = channel.url == widget.selectedUrl;
                        return TvTappable(
                          onTap: () => _select(channel),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.white38 : Colors.white10,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.radio_rounded, color: Colors.white54, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        channel.numberedName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (channel.group != null && channel.group!.isNotEmpty)
                                        Text(
                                          channel.group!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle, color: Colors.white),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
