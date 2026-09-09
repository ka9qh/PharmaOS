// تشفير والتحقق من كلمات مرور المستخدمين باستخدام BCrypt
// bcrypt يولّد Salt تلقائيًا داخل الـ hash الناتج نفسه، لذا لا حاجة لتخزين Salt منفصل.

import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  PasswordHasher._();

  /// يُنشئ hash آمن لكلمة مرور نصية عادية. يُستخدم عند إنشاء مستخدم جديد
  /// أو عند تغيير كلمة المرور.
  static String hash(String plainPassword) {
    return BCrypt.hashpw(plainPassword, BCrypt.gensalt());
  }

  /// يتحقق من تطابق كلمة مرور نصية عادية مع hash مخزَّن مسبقًا في قاعدة البيانات.
  static bool verify(String plainPassword, String storedHash) {
    try {
      return BCrypt.checkpw(plainPassword, storedHash);
    } catch (_) {
      // hash تالف أو بصيغة غير متوافقة - نتعامل معه كفشل تحقق وليس استثناء ينهار منه التطبيق
      return false;
    }
  }
}
