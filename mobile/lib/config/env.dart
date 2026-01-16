/// Environment configuration
/// Cập nhật các giá trị này trước khi build
class Env {
  // Supabase Configuration
  static const String supabaseUrl = 'https://gaprsacsrfrlvmdvagoj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_uwsW7owDxtlfhpyANr-hxw_pi57JFcd';
  
  // Backend API URL
  // Đổi thành IP máy tính nếu test trên thiết bị thật
  // Ví dụ: 'http://192.168.1.100:3000/api'
  static const String apiUrl = 'http://10.0.2.2:3000/api'; // Android Emulator
  // static const String apiUrl = 'http://localhost:3000/api'; // iOS Simulator
}
