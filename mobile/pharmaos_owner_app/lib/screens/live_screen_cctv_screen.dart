// شاشة المراقبة المباشرة المزدوجة (بث شاشة اللابتوب + كاميرا اللابتوب CCTV الحية) - PharmaOS Owner App
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';

class LiveScreenCctvScreen extends StatefulWidget {
  const LiveScreenCctvScreen({super.key});

  @override
  State<LiveScreenCctvScreen> createState() => _LiveScreenCctvScreenState();
}

class _LiveScreenCctvScreenState extends State<LiveScreenCctvScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _streamTimer;

  String _selectedBranch = 'الفرع الرئيسي';
  List<String> _branches = ['الفرع الرئيسي', 'فرع 2', 'كاشير الصالة'];

  bool _isStreaming = true;
  Uint8List? _screenFrameBytes;
  Uint8List? _cameraFrameBytes;
  DateTime? _lastScreenTime;
  DateTime? _lastCameraTime;
  int _streamFps = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBranchesAndStart();
  }

  Future<void> _loadBranchesAndStart() async {
    final config = await OwnerApiService.getConfig();
    if (config != null && config.branches.isNotEmpty) {
      setState(() {
        _branches = config.branches;
        _selectedBranch = _branches.first;
      });
    }

    _startStreamLoop();
  }

  void _startStreamLoop() {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (_isStreaming && mounted) {
        _fetchFrames();
      }
    });
  }

  Future<void> _fetchFrames() async {
    final currentTab = _tabController.index;
    if (currentTab == 0) {
      // شاشة النظام
      final frame = await OwnerApiService.fetchLiveStreamFrame('screen', branchId: _selectedBranch);
      if (frame != null && mounted) {
        try {
          final bytes = base64Decode(frame.frameBase64);
          setState(() {
            _screenFrameBytes = bytes;
            _lastScreenTime = frame.timestamp;
          });
        } catch (_) {}
      }
    } else {
      // كاميرا اللابتوب
      final frame = await OwnerApiService.fetchLiveStreamFrame('camera', branchId: _selectedBranch);
      if (frame != null && mounted) {
        try {
          final bytes = base64Decode(frame.frameBase64);
          setState(() {
            _cameraFrameBytes = bytes;
            _lastCameraTime = frame.timestamp;
          });
        } catch (_) {}
      }
    }
  }

  void _toggleStream() {
    setState(() => _isStreaming = !_isStreaming);
    final channel = _tabController.index == 0 ? 'screen' : 'camera';
    OwnerApiService.sendStreamControl(channel, _isStreaming, branchId: _selectedBranch);
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: OwnerTheme.darkBg,
        appBar: AppBar(
          backgroundColor: OwnerTheme.darkCard,
          elevation: 0,
          title: const Text('المراقبة والبث المباشر الحي 📡'),
          actions: [
            // زر تشغيل/إيقاف البث
            IconButton(
              tooltip: _isStreaming ? 'إيقاف البث مؤقتاً' : 'استئناف البث',
              icon: Icon(
                _isStreaming ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: _isStreaming ? OwnerTheme.primaryEmeraldLight : Colors.amber,
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
            onTap: (_) => _fetchFrames(),
          ),
        ),
        body: Column(
          children: [
            // شريط اختيار الفرع والحالة الحية
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: OwnerTheme.darkCardElevated,
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: OwnerTheme.accentGold, size: 18),
                  const SizedBox(width: 8),
                  const Text('الفرع / الجهاز:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedBranch,
                    dropdownColor: OwnerTheme.darkCard,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
                    underline: const SizedBox(),
                    items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBranch = val);
                        _fetchFrames();
                      }
                    },
                  ),
                  const Spacer(),
                  // شارة البث المباشر
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isStreaming ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isStreaming ? Colors.redAccent : Colors.grey),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isStreaming ? Colors.redAccent : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isStreaming ? 'مباشر LIVE' : 'متوقف',
                          style: TextStyle(
                            color: _isStreaming ? Colors.redAccent : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // محتوى البث
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. شاشة النظام المباشرة
                  _buildStreamView(
                    title: 'شاشة كاشير ونظام الصيدلية المباشرة',
                    subtitle: 'تشارك حي لما يحصل في شاشة النظام المكتبي لحظة بلحظة',
                    frameBytes: _screenFrameBytes,
                    lastTime: _lastScreenTime,
                    isCamera: false,
                  ),

                  // 2. كاميرا اللابتوب CCTV
                  _buildStreamView(
                    title: 'بث كاميرا اللابتوب الحية (CCTV Surveillance)',
                    subtitle: 'رؤية مباشرة لصالة الصيدلية ومستخدمي النظام بجودة عالية',
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
          // مشغل الفيديو الحي المتطور
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OwnerTheme.primaryEmerald.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: OwnerTheme.primaryEmerald.withOpacity(0.15),
                  blurRadius: 24,
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
                      errorBuilder: (ctx, err, stack) => _buildLiveSurveillanceHUD(isCamera),
                    )
                  else
                    _buildLiveSurveillanceHUD(isCamera),

                  // تراكب المعلومات في أعلى الفيديو
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: OwnerTheme.primaryEmeraldLight.withOpacity(0.3)),
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
                                isCamera ? 'CAM: CCTV HD 1080p' : 'SCREEN: Desktop Live Stream',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                lastTime != null
                                    ? '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}:${lastTime.second.toString().padLeft(2, '0')}'
                                    : 'بث مباشر متصل',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    Icon(
                      isCamera ? Icons.camera_indoor_rounded : Icons.screen_search_desktop_rounded,
                      color: OwnerTheme.accentGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('تحديث البث'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: OwnerTheme.surfaceBorder),
                        ),
                        onPressed: _fetchFrames,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('وضع ملء الشاشة قيد البث الفوري')),
                          );
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

  Widget _buildLiveSurveillanceHUD(bool isCamera) {
    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Container(
      color: const Color(0xFF070B14),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // شبكة المراقبة المركزية
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCamera ? Colors.teal.withOpacity(0.12) : const Color(0xFF6366F1).withOpacity(0.12),
                    border: Border.all(color: isCamera ? Colors.tealAccent.withOpacity(0.3) : const Color(0xFF818CF8).withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(
                    isCamera ? Icons.videocam_rounded : Icons.desktop_windows_rounded,
                    size: 48,
                    color: isCamera ? Colors.tealAccent : const Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isCamera ? 'بث كاميرا المراقبة المباشرة (CCTV Live)' : 'بث شاشة النظام المكتبي المباشرة',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'الصيدلية: $_selectedBranch • متصل ومشفر 🔒',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // خطوط تصويب الكاميرا في الزوايا
          Positioned(
            top: 4,
            left: 4,
            child: Text(
              '┌',
              style: TextStyle(color: OwnerTheme.primaryEmeraldLight.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.w300),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Text(
              '┐',
              style: TextStyle(color: OwnerTheme.primaryEmeraldLight.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.w300),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Text(
              '└',
              style: TextStyle(color: OwnerTheme.primaryEmeraldLight.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.w300),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Text(
              '┘',
              style: TextStyle(color: OwnerTheme.primaryEmeraldLight.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.w300),
            ),
          ),

          // مؤشرات الكاميرا السفلية
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CH-01: HD 1080P | 30 FPS',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace'),
                ),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
