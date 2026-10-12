// إعدادات ومفاتيح الربط بالسيرفر السحابي Supabase - PharmaOS
// نصوص صريحة وثابتة (Hardcoded Constants) لضمان عدم فقدانها في نسخ الـ Release المترجمة

class SupabaseConfig {
  /// رابط مشروع Supabase المعتمد
  static const String url = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';

  /// مفتاح الوصول العام المعتمد (Anon / Publishable Key)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDMzMzEsImV4cCI6MjEwNDQ3OTMzMX0.ldSLO0S-OvUb1RR9ewMkM-COVvlon0-hl6tBh4VsjGA';

  /// مهلة الاتصال الافتراضية المناسبة للإنترنت الضعيف وبطيء الاستجابة
  static const Duration requestTimeout = Duration(seconds: 35);

  /// مهلة الاتصال بالسوكت/المصافحة الأولية
  static const Duration connectionTimeout = Duration(seconds: 30);
}
