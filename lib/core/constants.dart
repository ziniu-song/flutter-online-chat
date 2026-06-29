class AppConstants {
  // Android 模拟器访问宿主机使用 10.0.2.2
  // iOS 模拟器可改成 http://127.0.0.1:5000
  // 真机需要改成电脑局域网 IP，例如 http://192.168.1.8:5000
  static const String baseUrl = 'http://172.16.247.2:5000';
  static const String apiBaseUrl = '$baseUrl/api';
}