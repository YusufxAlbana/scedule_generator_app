import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;

/// Hasil export: sukses dengan jumlah event, atau error message.
class CalendarExportResult {
  final bool success;
  final int eventsCreated;
  final String? errorMessage;

  CalendarExportResult.success(this.eventsCreated)
      : success = true,
        errorMessage = null;

  CalendarExportResult.failure(this.errorMessage)
      : success = false,
        eventsCreated = 0;
}

/// Info calendar untuk picker.
class CalendarInfo {
  final String id;
  final String summary;
  final bool isPrimary;

  CalendarInfo({required this.id, required this.summary, this.isPrimary = false});
}

/// Service untuk export jadwal (dari hasil AI) ke Google Calendar.
/// Mendukung Flutter Web dengan OAuth 2.0 Client ID.
/// Memerlukan konfigurasi di Google Cloud Console (lihat CALENDAR_SETUP.md).
class CalendarExportService {
  static final List<String> _scopes = [cal.CalendarApi.calendarScope];

  /// Client ID untuk web — harus sama dengan yang di index.html meta tag.
  static const String _webClientId =
      '814490780202-g3g6coa3qbhs8if33qe6fea7bjr4hgim.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    clientId: _webClientId, // Wajib untuk Flutter Web
  );

  // ======================== PARSING ========================

  /// Parse raw response AI (JSON dengan "schedule" array) ke struktur data.
  /// Mengembalikan null jika tidak bisa parse.
  static Map<String, dynamic>? parseScheduleJson(String raw) {
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    try {
      final data = jsonDecode(cleaned);
      if (data is Map<String, dynamic> && data.containsKey('schedule')) {
        return data;
      }
    } catch (_) {}
    final jsonMatch =
        RegExp(r'\{[\s\S]*"schedule"[\s\S]*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      try {
        final data = jsonDecode(jsonMatch.group(0)!);
        if (data is Map<String, dynamic> && data.containsKey('schedule')) {
          return data;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Parse markdown table rows menjadi List<cal.Event>.
  /// Mendukung format: | Waktu | Aktivitas | Durasi | Prioritas |
  static List<cal.Event> parseMarkdownTableToEvents(
    String raw, {
    String timeZone = 'Asia/Jakarta',
    DateTime? baseDate,
  }) {
    final base = baseDate ?? DateTime.now();
    final lines =
        raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final tableLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('|') && line.endsWith('|')) {
        // Skip separator lines like |---|---|
        if (RegExp(r'^\|[\s\-:]+\|$').hasMatch(line.replaceAll(' ', ''))) {
          continue;
        }
        tableLines.add(line);
      }
    }

    if (tableLines.length < 2) return []; // Butuh minimal header + 1 data row

    // Parse header
    final headers = tableLines[0]
        .split('|')
        .map((h) => h.trim().toLowerCase())
        .where((h) => h.isNotEmpty)
        .toList();

    final events = <cal.Event>[];

    for (int i = 1; i < tableLines.length; i++) {
      final cells = tableLines[i]
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();

      final row = <String, String>{};
      for (int j = 0; j < headers.length && j < cells.length; j++) {
        row[headers[j]] = cells[j];
      }

      // Cari kolom waktu
      final waktu = row['waktu'] ?? row['time'] ?? row['jam'] ?? '';
      final aktivitas = row['aktivitas'] ??
          row['activity'] ??
          row['title'] ??
          row['kegiatan'] ??
          '';
      final durasi = row['durasi'] ?? row['duration'] ?? '';
      final prioritas = row['prioritas'] ?? row['priority'] ?? '';

      if (waktu.isEmpty || aktivitas.isEmpty) continue;

      // Skip istirahat/break items
      final isIstirahat = aktivitas.toLowerCase().contains('istirahat') ||
          aktivitas.toLowerCase().contains('break');
      if (isIstirahat) continue;

      // Parse time range: "08:00 - 09:00" atau "08:00–09:00"
      String startTimeStr = waktu;
      String endTimeStr = '';
      if (waktu.contains('–') || waktu.contains('-')) {
        final parts = waktu.split(RegExp(r'[–\-]'));
        startTimeStr = parts[0].trim();
        endTimeStr = parts.length > 1 ? parts[1].trim() : '';
      }

      final start = _parseTimeToDateTime(base, startTimeStr);
      if (start == null) continue;

      DateTime? end;
      if (endTimeStr.isNotEmpty) {
        end = _parseTimeToDateTime(base, endTimeStr);
      }

      // Kalau endTime tidak ada, estimasi dari durasi
      if (end == null || !end.isAfter(start)) {
        final durasiMinutes = _parseDurationMinutes(durasi);
        end = start.add(Duration(minutes: durasiMinutes > 0 ? durasiMinutes : 60));
      }

      final startEdt = cal.EventDateTime()
        ..dateTime = start
        ..timeZone = timeZone;
      final endEdt = cal.EventDateTime()
        ..dateTime = end
        ..timeZone = timeZone;

      final event = cal.Event()
        ..summary = aktivitas
        ..description = 'Durasi: $durasi • Prioritas: $prioritas'
        ..start = startEdt
        ..end = endEdt;
      events.add(event);
    }

    return events;
  }

  /// Coba parse durasi dari string seperti "60 menit", "1 jam", "30"
  static int _parseDurationMinutes(String durasi) {
    if (durasi.isEmpty) return 0;
    final numMatch = RegExp(r'(\d+)').firstMatch(durasi);
    if (numMatch == null) return 0;
    final num = int.parse(numMatch.group(1)!);
    if (durasi.toLowerCase().contains('jam') ||
        durasi.toLowerCase().contains('hour')) {
      return num * 60;
    }
    return num; // Anggap menit
  }

  /// Konversi satu item jadwal (dari JSON) + baseDate menjadi [cal.Event].
  static cal.Event? scheduleItemToCalendarEvent(
    Map<String, dynamic> item,
    DateTime baseDate,
    String timeZone,
  ) {
    final hasEvent = item['hasEvent'] == true;
    final title = (item['title'] as String?)?.trim() ?? '';
    if (title.isEmpty && !hasEvent) return null;

    final timeStr = (item['time'] as String?)?.trim() ?? '';
    final endTimeStr = (item['endTime'] as String?)?.trim() ?? '';
    if (timeStr.isEmpty) return null;

    final start = _parseTimeToDateTime(baseDate, timeStr);
    final end = _parseTimeToDateTime(baseDate, endTimeStr);
    if (start == null || end == null || !end.isAfter(start)) return null;

    final startEdt = cal.EventDateTime()
      ..dateTime = start
      ..timeZone = timeZone;
    final endEdt = cal.EventDateTime()
      ..dateTime = end
      ..timeZone = timeZone;

    final event = cal.Event()
      ..summary = title.isEmpty ? 'Istirahat' : title
      ..description = (item['subtitle'] as String?)?.trim()
      ..start = startEdt
      ..end = endEdt;
    return event;
  }

  /// Parse tanggal dari string seperti "Senin, 2 Mar 2025" atau gunakan [fallback].
  static DateTime parseScheduleDate(String? dateStr, DateTime fallback) {
    if (dateStr == null || dateStr.trim().isEmpty) return fallback;
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mei': 5, 'jun': 6,
      'jul': 7, 'agu': 8, 'agt': 8, 'sep': 9, 'okt': 10, 'nov': 11, 'des': 12,
    };
    final part = dateStr
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    int? day, month, year;
    for (final p in part) {
      final d = int.tryParse(p);
      if (d != null && d >= 1 && d <= 31 && year == null) day = d;
      if (d != null && d >= 2000 && d <= 2100) year = d;
      if (p.length >= 3) {
        final m = months[p.toLowerCase().substring(0, 3)];
        if (m != null) month = m;
      }
    }
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
    return fallback;
  }

  static DateTime? _parseTimeToDateTime(DateTime base, String timeStr) {
    final parts =
        timeStr.split(RegExp(r'[:\s]')).map((s) => int.tryParse(s)).toList();
    if (parts.length >= 2 && parts[0] != null && parts[1] != null) {
      final h = parts[0]!.clamp(0, 23);
      final m = parts[1]!.clamp(0, 59);
      return DateTime(base.year, base.month, base.day, h, m);
    }
    if (parts.length == 1 && parts[0] != null) {
      final h = parts[0]!.clamp(0, 23);
      return DateTime(base.year, base.month, base.day, h, 0);
    }
    return null;
  }

  /// Build list [cal.Event] dari JSON schedule. Hanya item dengan hasEvent atau title tidak kosong.
  static List<cal.Event> scheduleJsonToEvents(
    Map<String, dynamic> data, {
    String timeZone = 'Asia/Jakarta',
  }) {
    final schedule =
        List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final dateStr = data['date'] as String?;
    final baseDate = parseScheduleDate(dateStr, DateTime.now());
    final events = <cal.Event>[];
    for (final item in schedule) {
      final event = scheduleItemToCalendarEvent(item, baseDate, timeZone);
      if (event != null) events.add(event);
    }
    return events;
  }

  // ======================== AUTH ========================

  /// Cek apakah user sudah pernah login (silent sign-in).
  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Sign in dengan Google. Return true jika berhasil, false jika dibatalkan user.
  static Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return false;
    }
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // ======================== CALENDAR LIST ========================

  /// Dapatkan authenticated HTTP client.
  static Future<http.Client?> _getAuthClient() async {
    http.Client? client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      final signedIn = await signIn();
      if (!signedIn) return null;
      client = await _googleSignIn.authenticatedClient();
    }
    return client;
  }

  /// Ambil daftar calendars milik user (untuk picker).
  static Future<List<CalendarInfo>> getCalendarList() async {
    final client = await _getAuthClient();
    if (client == null) return [];

    try {
      final calendarApi = cal.CalendarApi(client);
      final calList = await calendarApi.calendarList.list();
      final items = calList.items ?? [];
      return items.map((item) {
        return CalendarInfo(
          id: item.id ?? 'primary',
          summary: item.summary ?? 'Untitled',
          isPrimary: item.primary ?? false,
        );
      }).toList();
    } catch (e) {
      print('Error fetching calendar list: $e');
      return [];
    } finally {
      client.close();
    }
  }

  // ======================== EXPORT ========================

  /// Export jadwal (raw string dari AI) ke Google Calendar.
  /// Sekarang mendukung JSON schedule DAN markdown table.
  /// [calendarId]: 'primary' atau ID calendar lain.
  /// Mengembalikan [CalendarExportResult].
  static Future<CalendarExportResult> exportToCalendar(
    String scheduleResult, {
    String calendarId = 'primary',
    String timeZone = 'Asia/Jakarta',
  }) async {
    // Coba parse JSON dulu
    List<cal.Event> events = [];

    final data = parseScheduleJson(scheduleResult);
    if (data != null) {
      events = scheduleJsonToEvents(data, timeZone: timeZone);
    }

    // Fallback: coba parse markdown table
    if (events.isEmpty) {
      events = parseMarkdownTableToEvents(
        scheduleResult,
        timeZone: timeZone,
        baseDate: DateTime.now(),
      );
    }

    if (events.isEmpty) {
      return CalendarExportResult.failure(
        'Jadwal tidak bisa dibaca. Pastikan format hasil AI berisi jadwal (JSON dengan "schedule" atau tabel Markdown).',
      );
    }

    http.Client? client;
    try {
      client = await _getAuthClient();
      if (client == null) {
        return CalendarExportResult.failure('Login Google dibatalkan.');
      }

      final calendarApi = cal.CalendarApi(client);
      int created = 0;
      for (final event in events) {
        await calendarApi.events.insert(event, calendarId);
        created++;
      }
      return CalendarExportResult.success(created);
    } on cal.DetailedApiRequestError catch (e) {
      final msg = e.message ?? e.status;
      if (e.status == 403) {
        return CalendarExportResult.failure(
          'Akses ditolak (403). Pastikan:\n'
          '• Google Calendar API sudah di-enable di Cloud Console\n'
          '• OAuth consent screen punya scope Calendar\n'
          '• Anda pakai akun Google yang benar',
        );
      }
      if (e.status == 401) {
        // Token expired, coba sign out dan minta login lagi
        await signOut();
        return CalendarExportResult.failure(
          'Sesi login sudah kadaluarsa. Silakan coba export lagi untuk login ulang.',
        );
      }
      return CalendarExportResult.failure('Google Calendar API: $msg');
    } catch (e) {
      return CalendarExportResult.failure(e.toString());
    } finally {
      client?.close();
    }
  }
}
