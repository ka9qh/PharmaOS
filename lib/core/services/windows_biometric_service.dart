import 'dart:io';
import 'package:flutter/foundation.dart';

class WindowsBiometricService {
  static bool? _cachedAvailability;

  /// التحقق من توفر حساس البصمة أو Windows Hello في النظام
  static Future<bool> isBiometricAvailable() async {
    if (!Platform.isWindows) return false;
    if (_cachedAvailability != null) return _cachedAvailability!;

    try {
      const psScript = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.Runtime.WindowsRuntime") | Out-Null
\$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.IsGenericMethod } | Select-Object -First 1
\$asyncOp = [Windows.Security.Credentials.UI.UserConsentVerifier, Windows.Security.Credentials.UI, ContentType = WindowsRuntime]::CheckAvailabilityAsync()
\$asTask = \$asTaskGeneric.MakeGenericMethod([Windows.Security.Credentials.UI.UserConsentVerifierAvailability])
\$task = \$asTask.Invoke(\$null, @(\$asyncOp))
\$task.Wait()
Write-Output \$task.Result.ToString()
''';
      final process = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', '-'],
      );
      process.stdin.writeln(psScript);
      await process.stdin.close();

      final out = await process.stdout.transform(const SystemEncoding().decoder).join();
      final output = out.trim();
      final isAvailable = output == 'Available';
      _cachedAvailability = isAvailable;
      return isAvailable;
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
      _cachedAvailability = false;
      return false;
    }
  }

  /// طلب التحقق بالبصمة من نظام الويندوز وجلب نافذة البصمة للمقدمة فوراً
  static Future<bool> authenticate({
    String reason = 'تسجيل الدخول إلى نظام فارما أو إس (PharmaOS)',
  }) async {
    if (!Platform.isWindows) return false;

    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final psScript = '''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public class WinHelper {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_SHOWWINDOW = 0x0040;

    public static void WatchAndBringToFront() {
        new Thread(() => {
            for (int i = 0; i < 40; i++) {
                Thread.Sleep(80);
                IntPtr hwnd = FindWindow("Credential Dialog Xaml Host", null);
                if (hwnd == IntPtr.Zero) {
                    hwnd = FindWindow(null, "Windows Security");
                }
                if (hwnd == IntPtr.Zero) {
                    hwnd = FindWindow(null, "أمان Windows");
                }
                if (hwnd != IntPtr.Zero) {
                    SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
                    SetForegroundWindow(hwnd);
                    break;
                }
            }
        }).Start();
    }
}
"@

[WinHelper]::WatchAndBringToFront()

[System.Reflection.Assembly]::LoadWithPartialName("System.Runtime.WindowsRuntime") | Out-Null
\$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.IsGenericMethod } | Select-Object -First 1
\$asyncOp = [Windows.Security.Credentials.UI.UserConsentVerifier, Windows.Security.Credentials.UI, ContentType = WindowsRuntime]::RequestVerificationAsync('$reason')
\$asTask = \$asTaskGeneric.MakeGenericMethod([Windows.Security.Credentials.UI.UserConsentVerificationResult])
\$task = \$asTask.Invoke(\$null, @(\$asyncOp))
\$task.Wait()
Write-Output \$task.Result.ToString()
''';
      final process = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', '-'],
      );
      process.stdin.writeln(psScript);
      await process.stdin.close();

      final out = await process.stdout.transform(const SystemEncoding().decoder).join();
      final output = out.trim();
      debugPrint('Biometric result: $output');
      return output == 'Verified';
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}

