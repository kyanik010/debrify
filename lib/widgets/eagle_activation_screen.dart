import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eagle X activation/pass UI transplanted from StreamVault Build #14.
///
/// This widget is presentation-only: it does not change Debrify's IPTV,
/// subtitle, player, or External Audio flows.
class EagleActivationScreen extends StatefulWidget {
  const EagleActivationScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<EagleActivationScreen> createState() => _EagleActivationScreenState();
}

class _EagleActivationScreenState extends State<EagleActivationScreen> {
  static const _idKey = 'eagle_x_activation_id';
  String? _activationId;

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  Future<void> _loadId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      final bytes = List<int>.generate(9, (_) => Random.secure().nextInt(256));
      id = 'EX-' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      await prefs.setString(_idKey, id);
    }
    if (mounted) setState(() => _activationId = id);
  }

  Future<void> _copyId() async {
    final id = _activationId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ معرّف الجهاز')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _activationId ?? 'جاري إنشاء المعرّف...';
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth >= 600;
        return ColoredBox(
          color: _PassColors.bg,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 900 : 380,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _PassColors.brass.withOpacity(.22),
                      ),
                    ),
                    child: landscape
                        ? IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 105,
                                  child: _PassHead(activationId: id),
                                ),
                                Expanded(
                                  flex: 115,
                                  child: _PassBody(onStart: widget.onStart),
                                ),
                                Expanded(
                                  flex: 90,
                                  child: _PassStub(landscape: true),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _PassHead(activationId: id),
                              _PassBody(onStart: widget.onStart),
                              const _PassStub(),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PassColors {
  static const bg = Color(0xFF0B0F1A);
  static const mid = Color(0xFF0E1422);
  static const light = Color(0xFF1B273F);
  static const ctaTop = Color(0xFF2A3A5E);
  static const brass = Color(0xFFC8A45A);
  static const brassSoft = Color(0xFFE6C982);
  static const text = Color(0xFFEEF1F7);
  static const muted = Color(0xFF94A3BF);
  static const dash = Color(0xFF3A4A6A);
}

class _PassHead extends StatelessWidget {
  const _PassHead({required this.activationId});

  final String activationId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_PassColors.light, _PassColors.mid, _PassColors.bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/eagle_x_activation_logo.png',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
          ),
          const Text(
            'Eagle X',
            style: TextStyle(
              color: _PassColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _PassColors.brass.withOpacity(.35),
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ID : $activationId',
                    style: const TextStyle(
                      color: _PassColors.brassSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: activationId.startsWith('جاري') ? null : () {
                      Clipboard.setData(ClipboardData(text: activationId));
                    },
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: _PassColors.brassSoft,
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'نسخ',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassBody extends StatelessWidget {
  const _PassBody({this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      color: _PassColors.mid,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: _PassColors.brassSoft, size: 22),
              const SizedBox(width: 8),
              const Text(
                'مرحباً بك',
                style: TextStyle(
                  color: _PassColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'لديك فترة تجريبية مجانية لمدة 7 أيام',
            textAlign: TextAlign.center,
            style: TextStyle(color: _PassColors.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          const Text(
            '7 أيام',
            style: TextStyle(
              color: _PassColors.brassSoft,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_PassColors.ctaTop, _PassColors.light],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _PassColors.brass.withOpacity(.45),
                ),
              ),
              child: TextButton(
                onPressed: onStart,
                style: TextButton.styleFrom(
                  foregroundColor: _PassColors.brassSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'اضغط هنا لتبدأ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassStub extends StatelessWidget {
  const _PassStub({this.landscape = false});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: landscape ? 0 : 190),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: _PassColors.light,
        border: landscape
            ? Border(
                right: BorderSide(
                  color: _PassColors.dash,
                  width: 1,
                ),
              )
            : Border(
                top: BorderSide(
                  color: _PassColors.dash,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'لتفعيل التطبيق أو الحصول على اشتراك IPTV\n'
            'تواصل مع الدعم عبر مسح رمز QR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _PassColors.muted,
              fontSize: 12.5,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _PassColors.brass, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/images/eagle_x_support_qr.png',
                width: 124,
                height: 124,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
