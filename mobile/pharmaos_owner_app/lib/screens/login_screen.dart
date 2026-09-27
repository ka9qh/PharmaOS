// شاشة تسجيل الدخول والربط السحابي بمسح الباركود - PharmaOS Owner App
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/owner_api_service.dart';
import '../theme/owner_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/luxury_app_avatar.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final config = await OwnerApiService.getConfig();
    if (config != null && mounted) {
      // فحص هل الجهاز ما زال نشطاً في السيرفر
      final isActive = await OwnerApiService.isDeviceActive();
      if (!isActive) {
        setState(() {
          _errorMessage = '⛔ تم إيقاف وصول هذا الهاتف من قبل إدارة الصيدلية';
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _processQrScanned(String rawValue) async {
    if (rawValue.trim().isEmpty) return;

    // 1. فحص اتصال الإنترنت قبل البدء
    final isOnline = await OwnerApiService.hasInternetConnection();
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = '';
          _errorMessage = '⚠️ لا يوجد اتصال بالإنترنت في الهاتف!\nيرجى تشغيل شبكة Wi-Fi أو بيانات الهاتف والمحاولة مجدداً.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ الهاتف غير متصل بالإنترنت. يرجى تفعيل Wi-Fi أو البيانات أولاً للربط بالسيرفر.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'جاري التحقق وتسجيل الهاتف في السحابة المشفرة... 🛡️';
    });

    try {
      await OwnerApiService.loginWithActivationKey(rawValue);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = 'تم الربط والتسجيل بنجاح ✅';
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = '';
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// فتح ماسح الباركود وQR Code بالكاميرا مع معالجة كاملة للأجهزة القديمة
  Future<void> _openQrScanner() async {
    setState(() => _errorMessage = null);

    // التحقق من الإنترنت قبل تشغيل الكاميرا
    final isOnline = await OwnerApiService.hasInternetConnection();
    if (!isOnline) {
      if (mounted) {
        _showNoInternetDialog();
      }
      return;
    }

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'وجه الكاميرا نحو باركود الصيدلية',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () {
                        controller.dispose();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'افتح شاشة النظام في الكمبيوتر (الإعدادات > بيانات الترخيص والأجهزة المتصلة) واضغط (عرض باركود الاتصال للمدير).',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ),
              const SizedBox(height: 12),

              // شاشة الكاميرا مع معالجة الخطأ
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: controller,
                        errorBuilder: (context, error, child) {
                          return Container(
                            color: const Color(0xFF1E293B),
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 48),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'تعذر تشغيل الكاميرا تلقائياً على هذا الهاتف',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'يمكنك منح إذن الكاميرا أو استخدام الإدخال اليدوي المباشر لكود الترخيص',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      controller.dispose();
                                      Navigator.pop(ctx);
                                      _openManualEntryDialog();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.edit_note_rounded),
                                    label: const Text('📝 إدخال الكود يدوياً'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final rawValue = barcode.rawValue?.trim();
                            if (rawValue != null && rawValue.isNotEmpty) {
                              controller.dispose();
                              Navigator.pop(ctx);
                              _processQrScanned(rawValue);
                              break;
                            }
                          }
                        },
                      ),
                      // إطار توجيه المسح
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF10B981), width: 3),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // أزرار التحكم والبدائل أسفل الماسح
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // زر الفلاش
                    IconButton.filledTonal(
                      onPressed: () => controller.toggleTorch(),
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                      style: IconButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    const SizedBox(width: 8),
                    // زر قلب الكاميرا
                    IconButton.filledTonal(
                      onPressed: () => controller.switchCamera(),
                      icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    const SizedBox(width: 8),
                    // زر الإدخال اليدوي
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          controller.dispose();
                          Navigator.pop(ctx);
                          _openManualEntryDialog();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF34D399),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.keyboard_rounded, size: 18),
                        label: const Text('إدخال الكود يدوياً', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// حوار تنبيه انقطاع الإنترنت
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text('لا يوجد اتصال بالإنترنت', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'الهاتف غير متصل بالإنترنت حالياً.\n\nيرجى التأكد من تشغيل شبكة Wi-Fi أو بيانات الهاتف المحمول لتتمكن من مسح الباركود والربط بالسيرفر السحابي وقاعدة بيانات الصيدلية.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً، فهمت'),
            ),
          ],
        ),
      ),
    );
  }

  /// حوار إدخال كود الترخيص أو رمز الربط يدوياً
  void _openManualEntryDialog() {
    final textController = TextEditingController(text: 'PHARMAOS-COMMERCIAL-LIFETIME');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFF10B981), size: 26),
              SizedBox(width: 10),
              Text('الربط اليدوي بكود الترخيص', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل كود الترخيص أو الصق النص الكامل المشفر المعروض بنظام الكمبيوتر:',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'PHARMAOS-COMMERCIAL-LIFETIME أو كود JSON...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        textController.text = data.text!.trim();
                      }
                    },
                    icon: const Icon(Icons.paste_rounded, size: 16, color: Color(0xFF34D399)),
                    label: const Text('لصق من الحافظة', style: TextStyle(fontSize: 12, color: Color(0xFF34D399))),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      textController.text = 'PHARMAOS-COMMERCIAL-LIFETIME';
                    },
                    child: const Text('كود الصيدلية الأساسية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('تأكيد والربط السحابي'),
              onPressed: () {
                final text = textController.text.trim();
                Navigator.pop(ctx);
                if (text.isNotEmpty) {
                  _processQrScanned(text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF060913),
        body: LuxuryBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الشعار والأفاتار الفاخر ثلاثي الأبعاد بتأثير متوهج
                    const LuxuryAppAvatar(
                      size: 110,
                      showBadge: true,
                      badgeText: '👑 المدير التنفيذي',
                    ),
                    const SizedBox(height: 20),

                    // العنوان والوصف
                    const Text(
                      'PharmaOS Owner',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'منظومة المراقبة والتحكم المباشر للمدير العام',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // بطاقة تسجيل الدخول الزجاجية
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: OwnerTheme.glassCardDecoration(
                        borderColor: OwnerTheme.primaryEmerald.withOpacity(0.3),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: OwnerTheme.primaryEmerald.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Color(0xFF34D399),
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'الربط السحابي المباشر',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'لربط هذا الهاتف بالصيدلية، تأكد من اتصال الإنترنت ثم صور باركود الاتصال المعروض في نظام الكمبيوتر (الإعدادات > بيانات الترخيص والأجهزة المتصلة).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_isLoading)
                            Column(
                              children: [
                                const CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 3),
                                const SizedBox(height: 14),
                                Text(
                                  _statusText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _openQrScanner,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.camera_alt_rounded, size: 24),
                                label: const Text(
                                  '📷 تصوير باركود الاتصال',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _openManualEntryDialog,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF34D399),
                                  side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.keyboard_rounded, size: 20),
                                label: const Text(
                                  '📝 إدخال كود الترخيص يدوياً',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // مزايا النظام
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFeatureTag(Icons.lock_clock_rounded, 'تشفير شامل 256-bit'),
                        const SizedBox(width: 12),
                        _buildFeatureTag(Icons.cloud_done_rounded, 'ربط تلقائي بالصيدلية'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OwnerTheme.primaryEmeraldLight),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
