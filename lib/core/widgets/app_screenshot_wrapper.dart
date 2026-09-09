// غلاف النظام الشامل: التقاط الشاشة المكتبي (Screenshots Engine) - PharmaOS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/screenshot_service.dart';
import '../../app/app_router.dart';

class AppScreenshotWrapper extends StatefulWidget {
  final Widget child;
  const AppScreenshotWrapper({super.key, required this.child});

  @override
  State<AppScreenshotWrapper> createState() => _AppScreenshotWrapperState();
}

class _CaptureIntent extends Intent {
  const _CaptureIntent();
}

class _AppScreenshotWrapperState extends State<AppScreenshotWrapper> {
  @override
  void initState() {
    super.initState();
    ScreenshotService.init();
  }

  void _capture() {
    final targetCtx = AppRouter.rootNavigatorKey.currentContext ?? context;
    ScreenshotService.captureAndSave(targetCtx);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f9): const _CaptureIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS):
            const _CaptureIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CaptureIntent: CallbackAction<_CaptureIntent>(
            onInvoke: (_) => _capture(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: RepaintBoundary(
            key: ScreenshotService.globalBoundaryKey,
            child: Stack(
              children: [
                widget.child,

                // الزر العائم لالتقاط الشاشة
                ValueListenableBuilder<bool>(
                  valueListenable: ScreenshotService.floatingButtonNotifier,
                  builder: (context, showScreenshot, _) {
                    if (!showScreenshot) return const SizedBox.shrink();

                    return Positioned(
                      bottom: 24,
                      right: 24,
                      child: Material(
                        elevation: 6,
                        shape: const CircleBorder(),
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _capture,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E293B),
                              border: Border.all(color: Colors.tealAccent.withOpacity(0.7), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.camera_alt_outlined, color: Colors.tealAccent, size: 20),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
