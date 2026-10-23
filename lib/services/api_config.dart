import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Alamat path file PHP Anda
    const String apiPath = '/API/schedules.php';
    // IP Laptop Anda saat ini
    const String laptopIp = '192.168.1.9';

    if (kIsWeb) {
      // Web menggunakan localhost karena berjalan di browser laptop yang sama dengan server
      return 'http://localhost$apiPath';
    }

    // Untuk Android, iOS, Windows, dll semuanya diarahkan ke IP laptop
    return 'http://$laptopIp$apiPath';
  }
}