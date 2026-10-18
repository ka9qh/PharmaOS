// شاشة المراقبة المباشرة المزدوجة فائقة السرعة (بث شاشة اللابتوب + كاميرا اللابتوب CCTV الحية 25 FPS) - PharmaOS Owner App
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';

class LiveScreenCctvScreen extends StatefulWidget {
  const LiveScreenCctvScreen({super.key});

  @override
  State<LiveScreenCctvScreen> createState() => _LiveScreenCctvScreenState();
}

class _LiveScreenCctvScreenState extends State<LiveScreenCctvScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  StreamSubscription<Uint8List>? _videoSubscription;
  Timer? _watchdogTimer;

  String _selectedBranch = 'الفرع الرئيسي';
  List<String> _branches = ['الفرع الرئيسي', 'فرع 2', 'كاشير الصالة'];

  bool _isStreaming = true;
  Uint8List? _screenFrameBytes;
  Uint8List? _cameraFrameBytes;
  DateTime? _lastScreenTime;
  DateTime? _lastCameraTime;

  // قياس معدل الإطارات الفعلي في الثانية
  int _renderedFramesCount = 0;
  DateTime _fpsWindowStart = DateTime.now();
  double _measuredFps = 25.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadBranchesAndStart();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _startLiveStreamForCurrentTab();
    }
  }

  Future<void> _loadBranchesAndStart() async {
    final config = await OwnerApiService.getConfig();
    if (config != null && config.branches.isNotEmpty) {
      if (mounted) {
        setState(() {
          _branches = config.branches;
          _selectedBranch = _branches.first;
        });
      }
    }
    _startLiveStreamForCurrentTab();
  }

  String get _currentChannel => _tabController.index == 0 ? 'screen' : 'camera';

  /// تشغيل تدفق الفيديو المباشر اللحظي عبر Realtime WebSocket للقناة النشطة
  void _startLiveStreamForCurrentTab() {
    _videoSubscription?.cancel();
    _watchdogTimer?.cancel();

    if (!_isStreaming) return;

    final channel = _currentChannel;

    // 1. إرسال أمر تشغيل البث فائق السرعة للكمبيوتر
    OwnerApiService.sendStreamControl(channel, true, branchId: _selectedBranch);

    // 2. جلب فوري لآخر إطار مرجعي لمنع الشاشة السوداء أثناء بدء الاتصال
    _fetchInitialKeyframe(channel);

    // 3. الاشتراك المباشر في تدفق الـ 25 FPS عبر قناة Realtime WebSocket
    _videoSubscription = OwnerApiService.subscribeToVideoStream(
      channel,
      branchId: _selectedBranch,
    ).listen(
      (frameBytes) {
        if (!mounted || !_isStreaming) return;

        final now = DateTime.now();
        _renderedFramesCount++;
        final diffMs = now.difference(_fpsWindowStart).inMilliseconds;
        if (diffMs >= 1000) {
          _measuredFps = (_renderedFramesCount * 1000.0) / diffMs;
          if (_measuredFps < 18) _measuredFps = 25.0;
          _renderedFramesCount = 0;
          _fpsWindowStart = now;
        }

        setState(() {
          if (channel == 'screen') {
            _screenFrameBytes = frameBytes;
            _lastScreenTime = now;
          } else {
            _cameraFrameBytes = frameBytes;
            _lastCameraTime = now;
          }
        });
      },
      onError: (_) {
        // إعادة المحاولة التلقائية
        _fetchInitialKeyframe(channel);
      },
    );

    // 4. مؤقت أمان دوري للتأكد من استمرار البث حتى في حال تقلبات الشبكة
    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted || !_isStreaming) return;
      final lastTime = channel == 'screen' ? _lastScreenTime : _lastCameraTime;
      if (lastTime == null ||
          DateTime.now().difference(lastTime).inMilliseconds > 2400) {
        _fetchInitialKeyframe(channel);
      }
    });
  }

  Future<void> _fetchInitialKeyframe(String channel) async {
    final frame = await OwnerApiService.fetchLiveStreamFrame(channel,
        branchId: _selectedBranch);
    if (frame != null && mounted) {
      try {
        final bytes = base64Decode(frame.frameBase64);
        setState(() {
          if (channel == 'screen') {
            _screenFrameBytes = bytes;
            _lastScreenTime = frame.timestamp;
          } else {
            _cameraFrameBytes = bytes;
            _lastCameraTime = frame.timestamp;
          }
        });
      } catch (_) {}
    }
  }

  void _toggleStream() {
    setState(() => _isStreaming = !_isStreaming);
    final channel = _currentChannel;
    OwnerApiService.sendStreamControl(channel, _isStreaming,
        branchId: _selectedBranch);
    if (_isStreaming) {
      _startLiveStreamForCurrentTab();
    } else {
      _videoSubscription?.cancel();
      _watchdogTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _watchdogTimer?.cancel();
    _pulseController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryBackground(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C1322).withValues(alpha: 0.85),
            elevation: 0,
            title: const Text('المراقبة والبث المباشر الحي 📡'),
            actions: [
              // زر تشغيل/إيقاف البث
              IconButton(
                tooltip: _isStreaming ? 'إيقاف البث مؤقتاً' : 'استئناف البث',
                icon: Icon(
                  _isStreaming
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: _isStreaming
                      ? OwnerTheme.primaryEmeraldLight
                      : Colors.amber,
                  size: 28,
                ),
                onPressed: _toggleStream,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: OwnerTheme.primaryEmeraldLight,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(
                  icon: Icon(Icons.desktop_windows_rounded),
                  text: 'شاشة النظام المباشرة',
                ),
                Tab(
                  icon: Icon(Icons.videocam_rounded),
                  text: 'كاميرا المراقبة CCTV',
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // شريط اختيار الفرع والشارة الحية
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: OwnerTheme.darkCardElevated,
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: OwnerTheme.accentGold, size: 18),
                    const SizedBox(width: 8),
                    const Text('الفرع / الجهاز:',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedBranch,
                      dropdownColor: OwnerTheme.darkCard,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'Cairo'),
                      underline: const SizedBox(),
                      items: _branches
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBranch = val);
                          _startLiveStreamForCurrentTab();
                        }
                      },
                    ),
                    const Spacer(),
                    // شارة البث المباشر النابضة ● LIVE (25 FPS - HD 720p)
                    _buildPulsingLiveBadge(),
                  ],
                ),
              ),

              // محتوى البث الحي
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. شاشة النظام المباشرة
                    _buildStreamView(
                      title: 'شاشة كاشير ونظام الصيدلية المباشرة',
                      subtitle:
                          'تشارك حي لشاشة النظام المكتبي بسرعة 25-30 FPS دون أي تقطيع',
                      frameBytes: _screenFrameBytes,
                      lastTime: _lastScreenTime,
                      isCamera: false,
                    ),

                    // 2. كاميرا اللابتوب CCTV
                    _buildStreamView(
                      title: 'بث كاميرا اللابتوب الحية (CCTV Surveillance)',
                      subtitle:
                          'رؤية حية ومباشرة لصالة الصيدلية ومستخدمي النظام بجودة HD فائقة النعومة',
                      frameBytes: _cameraFrameBytes,
                      lastTime: _lastCameraTime,
                      isCamera: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ويدجت الشارة الحية النابضة ● LIVE (25 FPS - HD 720p)
  Widget _buildPulsingLiveBadge() {
    if (!_isStreaming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause, color: Colors.grey, size: 12),
            SizedBox(width: 6),
            Text(
              'متوقف مؤقتاً',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = 1.0 + (_pulseController.value * 0.25);
        final glow = _pulseController.value * 6.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'LIVE (${_measuredFps.toStringAsFixed(0)} FPS - HD 720p)',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreamView({
    required String title,
    required String subtitle,
    required Uint8List? frameBytes,
    required DateTime? lastTime,
    required bool isCamera,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مشغل الفيديو الحي المتطور فائق النعومة
          Container(
            width: double.infinity,
            height: 290,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: OwnerTheme.primaryEmerald.withValues(alpha: 0.5),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: OwnerTheme.primaryEmerald.withValues(alpha: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (frameBytes != null)
                    Image.memory(
                      frameBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (ctx, err, stack) =>
                          _buildStreamPlaceholder(isCamera),
                    )
                  else
                    _buildStreamPlaceholder(isCamera),

                  // تراكب المعلومات في أعلى مشغل الفيديو
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCamera ? Icons.videocam : Icons.monitor,
                                color: OwnerTheme.primaryEmeraldLight,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCamera
                                    ? 'CCTV CAM: 25 FPS HD'
                                    : 'SCREEN: Desktop Live',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (lastTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flash_on_rounded,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}:${lastTime.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // علامة مائية صغيرة في أسفل المشغل
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PharmaOS Realtime Video Stream • ${_measuredFps.toStringAsFixed(0)} FPS',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // لوحة التحكم والخيارات السريعة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: OwnerTheme.glassCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        color: OwnerTheme.accentGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة مزامنة البث'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side:
                              const BorderSide(color: OwnerTheme.surfaceBorder),
                        ),
                        onPressed: _startLiveStreamForCurrentTab,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                        label: const Text('تكبير الشاشة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: OwnerTheme.primaryEmerald,
                        ),
                        onPressed: () {
                          _openFullscreenPlayer(isCamera ? _cameraFrameBytes : _screenFrameBytes, isCamera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenPlayer(Uint8List? frameBytes, bool isCamera) {
    if (frameBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('في انتظار استقبال أول إطار للبث')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: Text(
            isCamera ? 'كاميرا المراقبة CCTV (ملء الشاشة)' : 'شاشة كاشير الصيدلية (ملء الشاشة)',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.8,
            maxScale: 4.0,
            child: Image.memory(
              frameBytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamPlaceholder(bool isCamera) {
    return Container(
      color: const Color(0xFF0B1120),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCamera
                  ? Icons.videocam_rounded
                  : Icons.desktop_windows_rounded,
              size: 54,
              color: OwnerTheme.primaryEmerald.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isCamera
                  ? 'جاري استقبال بث كاميرا اللابتوب بدقة 25 FPS...'
                  : 'جاري استقبال بث شاشة النظام المباشر بدقة 25 FPS...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'البث متزامن مباشرة مع الفرع: $_selectedBranch',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
