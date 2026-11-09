import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';

/// نتيجة شاشة المنبه.
enum AlarmAction { dismiss, snooze }

/// شاشة المنبه بملء الشاشة (مثل منبه الجهاز): الوقت بخط كبير، العنوان،
/// وزرّا "تأجيل 10 دقائق" و"إيقاف"، مع صوت متكرر واهتزاز حتى الاختيار.
class AlarmScreen extends StatefulWidget {
  final AlarmPayload payload;
  final bool playSound;
  const AlarmScreen({super.key, required this.payload, this.playSound = true});

  /// يُعطَّل في الاختبارات الآلية فقط (لا يوجد مشغل صوت هناك).
  static bool enableSound = true;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final Timer _clock;
  Timer? _haptics;
  Timer? _autoStop;
  AudioPlayer? _player;
  DateTime _now = DateTime.now();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
    if (widget.playSound && AlarmScreen.enableSound) _startRinging();
  }

  Future<void> _startRinging() async {
    _haptics = Timer.periodic(
      const Duration(milliseconds: 1600),
      (_) => HapticFeedback.heavyImpact(),
    );
    // يتوقف الرنين تلقائياً بعد 10 دقائق (كما في منبه الجهاز)
    _autoStop = Timer(const Duration(minutes: 10), _stopRinging);
    try {
      final p = _player = AudioPlayer();
      await p.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('sounds/alarm.wav'), volume: 1);
    } catch (e) {
      debugPrint('Alarm sound failed: $e');
    }
  }

  void _stopRinging() {
    _haptics?.cancel();
    _autoStop?.cancel();
    _player?.stop();
  }

  @override
  void dispose() {
    _clock.cancel();
    _stopRinging();
    _player?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _finish(AlarmAction a) {
    _stopRinging();
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final isEvent = p.type == 'event';
    final accent = isEvent ? IosColors.red : IosColors.orange;
    final time = Fmt.time(_now).split(' ');
    return PopScope(
      canPop: false,
      child: AnnotatedRegion(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // خلفية متدرجة داكنة مع توهج ملون
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1B1B3A),
                        const Color(0xFF0B0B12),
                        accent.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -120,
                left: -80,
                right: -80,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Container(
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.25 + 0.2 * _pulse.value),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEvent
                                ? CupertinoIcons.calendar
                                : CupertinoIcons.alarm_fill,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEvent
                                ? 'تنبيه موعد'
                                : (p.type == 'test'
                                      ? 'منبه تجريبي'
                                      : 'تنبيه مهمة'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              time.first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 92,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -3,
                              ),
                            ),
                            if (time.length > 1) ...[
                              const SizedBox(width: 8),
                              Text(
                                time.last,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 26,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${Fmt.weekday(_now)}، ${Fmt.date(_now)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      // بطاقة زجاجية بعنوان التنبيه
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Column(
                              children: [
                                ScaleTransition(
                                  scale: Tween(
                                    begin: 0.92,
                                    end: 1.08,
                                  ).animate(_pulse),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isEvent
                                          ? CupertinoIcons.calendar
                                          : CupertinoIcons.bell_fill,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  p.title.replaceFirst(
                                    RegExp(r'^[📝📅⏰]\s*', unicode: true),
                                    '',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.body,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _AlarmButton(
                        label:
                            'تأجيل ${NotificationService.snoozeMinutes} دقائق',
                        icon: CupertinoIcons.zzz,
                        background: accent,
                        foreground: Colors.white,
                        onTap: () => _finish(AlarmAction.snooze),
                      ),
                      const SizedBox(height: 14),
                      _AlarmButton(
                        label: 'إيقاف',
                        icon: CupertinoIcons.stop_fill,
                        background: Colors.white,
                        foreground: Colors.black,
                        onTap: () => _finish(AlarmAction.dismiss),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  const _AlarmButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 64,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
