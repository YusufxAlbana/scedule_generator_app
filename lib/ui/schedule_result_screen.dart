import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/calendar_export_service.dart';

class ScheduleResultScreen extends StatefulWidget {
  final String scheduleResult;

  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isExporting = false;
  String _selectedCalendarId = 'primary';
  String _selectedCalendarName = 'Primary Calendar';
  List<CalendarInfo>? _cachedCalendars;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Coba extract JSON dari response (bisa ada teks sebelum/sesudah JSON)
  Map<String, dynamic>? _tryParseJson(String raw) {
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

  // Parse markdown table menjadi list of maps
  List<Map<String, String>> _parseMarkdownTable(String raw) {
    final lines =
        raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final tableLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('|') && line.endsWith('|')) {
        if (RegExp(r'^\|[\s\-:]+\|$').hasMatch(line.replaceAll(' ', ''))) {
          continue;
        }
        tableLines.add(line);
      }
    }

    if (tableLines.length < 2) return [];

    final headers = tableLines[0]
        .split('|')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    final rows = <Map<String, String>>[];
    for (int i = 1; i < tableLines.length; i++) {
      final cells = tableLines[i]
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();

      final row = <String, String>{};
      for (int j = 0; j < headers.length && j < cells.length; j++) {
        row[headers[j].toLowerCase()] = cells[j];
      }
      rows.add(row);
    }

    return rows;
  }

  String _extractTips(String raw) {
    final lines = raw.split('\n');
    final tipLines = <String>[];
    bool afterTable = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (afterTable && trimmed.isNotEmpty && !trimmed.startsWith('|')) {
        tipLines.add(trimmed);
      }
      if (trimmed.startsWith('|') &&
          !RegExp(r'^\|[\s\-:]+\|$')
              .hasMatch(trimmed.replaceAll(' ', ''))) {
        afterTable = true;
      }
    }

    return tipLines.join(' ').trim();
  }

  String _buildCopyText(Map<String, dynamic> data) {
    final schedule =
        List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final tips = data['tips'] as String? ?? '';
    final dateStr = data['date'] as String? ?? 'Hari Ini';

    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal: $dateStr');
    buffer.writeln('═══════════════════════');

    for (final item in schedule) {
      if (item['hasEvent'] == true) {
        buffer.writeln(
            '${item['time']} - ${item['endTime']}  │  ${item['title']}');
        if (item['subtitle'] != null &&
            (item['subtitle'] as String).isNotEmpty) {
          buffer.writeln('   ${item['subtitle']}');
        }
      }
    }

    if (tips.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💡 Tips: $tips');
    }

    return buffer.toString();
  }

  String _buildCopyTextFromTable(
      List<Map<String, String>> rows, String tips) {
    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal Harian');
    buffer.writeln('═══════════════════════');

    for (final row in rows) {
      final waktu = row['waktu'] ?? row['time'] ?? '';
      final aktivitas =
          row['aktivitas'] ?? row['activity'] ?? row['title'] ?? '';
      final durasi = row['durasi'] ?? row['duration'] ?? '';
      final prioritas = row['prioritas'] ?? row['priority'] ?? '';
      buffer.writeln('$waktu  │  $aktivitas ($durasi) [$prioritas]');
    }

    if (tips.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💡 Tips: $tips');
    }

    return buffer.toString();
  }

  /// Cek apakah schedule bisa di-export (JSON atau markdown table)
  bool _canExport() {
    if (CalendarExportService.parseScheduleJson(widget.scheduleResult) !=
        null) {
      return true;
    }
    final tableEvents = CalendarExportService.parseMarkdownTableToEvents(
      widget.scheduleResult,
      baseDate: DateTime.now(),
    );
    return tableEvents.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final jsonData = _tryParseJson(widget.scheduleResult);

    if (jsonData != null) {
      return _buildScaffold(
        context,
        body: _buildCalendarView(context, jsonData),
      );
    }

    final tableRows = _parseMarkdownTable(widget.scheduleResult);
    if (tableRows.isNotEmpty) {
      return _buildScaffold(
        context,
        body: _buildMarkdownTableView(context, tableRows),
      );
    }

    return _buildScaffold(
      context,
      body: _buildFallbackView(context, widget.scheduleResult),
    );
  }

  Widget _buildScaffold(BuildContext context, {required Widget body}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          "Jadwal Harian",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          // Calendar picker button
          IconButton(
            icon: const Icon(Icons.event_note_rounded),
            tooltip: 'Pilih Calendar',
            onPressed: _showCalendarPicker,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Export ke Google Calendar',
            onPressed: _isExporting ? null : () => _runExportToCalendar(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: body,
        ),
      ),
    );
  }

  // ============= CALENDAR PICKER DIALOG =============

  Future<void> _showCalendarPicker() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          elevation: 8,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengambil daftar calendar...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Fetch calendars
    List<CalendarInfo> calendars;
    if (_cachedCalendars != null) {
      calendars = _cachedCalendars!;
    } else {
      calendars = await CalendarExportService.getCalendarList();
      _cachedCalendars = calendars;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Remove loading

    if (calendars.isEmpty) {
      _showErrorDialog(
        context,
        'Tidak bisa mengambil daftar calendar.\n\n'
        'Pastikan Anda sudah login ke akun Google dan memberikan izin Calendar.',
      );
      return;
    }

    // Show picker
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E58E9).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF1E58E9), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pilih Calendar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: calendars.length,
            itemBuilder: (context, index) {
              final cal = calendars[index];
              final isSelected = cal.id == _selectedCalendarId;
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  cal.isPrimary
                      ? Icons.star_rounded
                      : Icons.calendar_today_rounded,
                  color: isSelected
                      ? const Color(0xFF1E58E9)
                      : Colors.grey.shade400,
                  size: 22,
                ),
                title: Text(
                  cal.summary,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1E58E9)
                        : Colors.black87,
                  ),
                ),
                subtitle: cal.isPrimary
                    ? const Text('Primary',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF43A047)))
                    : null,
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1E58E9))
                    : null,
                selected: isSelected,
                selectedTileColor: const Color(0xFF1E58E9).withAlpha(15),
                onTap: () {
                  setState(() {
                    _selectedCalendarId = cal.id;
                    _selectedCalendarName = cal.summary;
                  });
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  // ============= JSON CALENDAR VIEW =============
  Widget _buildCalendarView(
      BuildContext context, Map<String, dynamic> data) {
    final schedule =
        List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final tips = data['tips'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected calendar indicator
          _buildCalendarIndicator(),
          const SizedBox(height: 16),

          // Gradient Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8121DA),
                  Color(0xFF4C22DC),
                  Color(0xFF1E58E9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C22DC).withAlpha(77),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "📅 Jadwal:\n${data['date'] ?? 'Hari Ini'}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    final item = schedule[index];
                    return _buildTimelineTile(
                      time: item['time'] ?? '',
                      endTime: item['endTime'] ?? '',
                      title: item['title'] ?? '',
                      subtitle: item['subtitle'] ?? '',
                      hasEvent: item['hasEvent'] ?? false,
                      isFirst: index == 0,
                      isLast: index == schedule.length - 1,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Tips Section
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("💡", style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tips,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          _buildActionButtons(
            context,
            () {
              Clipboard.setData(
                  ClipboardData(text: _buildCopyText(data)));
              _showCopiedSnackbar(context);
            },
            onExport: () => _runExportToCalendar(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============= MARKDOWN TABLE VIEW =============
  Widget _buildMarkdownTableView(
      BuildContext context, List<Map<String, String>> rows) {
    final tips = _extractTips(widget.scheduleResult);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarIndicator(),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8121DA),
                  Color(0xFF4C22DC),
                  Color(0xFF1E58E9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C22DC).withAlpha(77),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "📅 Jadwal Harian",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final waktu = row['waktu'] ?? row['time'] ?? '';
                  final aktivitas = row['aktivitas'] ??
                      row['activity'] ??
                      row['title'] ??
                      '';
                  final durasi = row['durasi'] ?? row['duration'] ?? '';
                  final prioritas =
                      row['prioritas'] ?? row['priority'] ?? '';
                  final isIstirahat =
                      aktivitas.toLowerCase().contains('istirahat') ||
                          aktivitas.toLowerCase().contains('break');

                  String startTime = waktu;
                  String endTime = '';
                  if (waktu.contains('–') || waktu.contains('-')) {
                    final parts = waktu.split(RegExp(r'[–\-]'));
                    startTime = parts[0].trim();
                    endTime =
                        parts.length > 1 ? parts[1].trim() : '';
                  }

                  return _buildTimelineTile(
                    time: startTime,
                    endTime: endTime,
                    title: aktivitas,
                    subtitle: '$durasi • $prioritas',
                    hasEvent: !isIstirahat,
                    isFirst: index == 0,
                    isLast: index == rows.length - 1,
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),

          if (tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("💡", style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tips,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          _buildActionButtons(
            context,
            () {
              Clipboard.setData(ClipboardData(
                  text: _buildCopyTextFromTable(rows, tips)));
              _showCopiedSnackbar(context);
            },
            onExport: () => _runExportToCalendar(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============= FALLBACK RAW TEXT VIEW =============
  Widget _buildFallbackView(BuildContext context, String rawText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarIndicator(),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4E5), Color(0xFFFFF9F0)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF57C00), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Format AI tidak sesuai. Berikut respons mentahnya:",
                    style: TextStyle(
                      color: Color(0xFFF57C00),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SelectableText(
              rawText,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF2E3A42)),
            ),
          ),
          const SizedBox(height: 24),

          _buildActionButtons(
            context,
            () {
              Clipboard.setData(ClipboardData(text: rawText));
              _showCopiedSnackbar(context);
            },
            onExport: _canExport()
                ? () => _runExportToCalendar(context)
                : null,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============= CALENDAR INDICATOR CHIP =============
  Widget _buildCalendarIndicator() {
    return GestureDetector(
      onTap: _showCalendarPicker,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E58E9).withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1E58E9).withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 16, color: Color(0xFF1E58E9)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Export ke: $_selectedCalendarName',
                style: const TextStyle(
                  color: Color(0xFF1E58E9),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Color(0xFF1E58E9)),
          ],
        ),
      ),
    );
  }

  // ============= EXPORT WITH LOADING =============

  Future<void> _runExportToCalendar(BuildContext context) async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    // Show loading overlay
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E58E9)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mengexport ke Google Calendar...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF2E3A42),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedCalendarName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await CalendarExportService.exportToCalendar(
      widget.scheduleResult,
      calendarId: _selectedCalendarId,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Remove loading dialog

    setState(() => _isExporting = false);

    if (result.success) {
      _showSuccessDialog(context, result.eventsCreated);
    } else {
      _showErrorDialog(context, result.errorMessage ?? 'Export gagal.');
    }
  }

  void _showSuccessDialog(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF43A047), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Berhasil! 🎉',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF2E3A42),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$count acara berhasil ditambahkan\nke "$_selectedCalendarName"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buka Google Calendar untuk melihat jadwal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFE53935), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Export Gagal',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4A5568),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _runExportToCalendar(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E58E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============= SHARED WIDGETS =============

  Widget _buildActionButtons(BuildContext context, VoidCallback onCopy,
      {VoidCallback? onExport}) {
    return Column(
      children: [
        // Copy Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8121DA), Color(0xFF1E58E9)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C22DC).withAlpha(77),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded,
                  size: 20, color: Colors.white),
              label: const Text(
                "Salin Jadwal",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        if (onExport != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: _isExporting
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF1E58E9), width: 1.5),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF1E58E9)),
                        ),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.event_rounded, size: 20),
                    label: const Text(
                      "Export ke Google Calendar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E58E9),
                      side: const BorderSide(
                          color: Color(0xFF1E58E9), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
          ),
        ],
        const SizedBox(height: 12),
        // Back Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text(
              "Kembali",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4C22DC),
              side: const BorderSide(
                  color: Color(0xFF4C22DC), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCopiedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              "Jadwal berhasil disalin! ✨",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============= TIMELINE TILE =============
  Widget _buildTimelineTile({
    required String time,
    required String endTime,
    required String title,
    required String subtitle,
    required bool hasEvent,
    required bool isFirst,
    required bool isLast,
  }) {
    return Container(
      color: hasEvent ? Colors.white.withAlpha(20) : Colors.transparent,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time Column
            SizedBox(
              width: 75,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 20, top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color:
                            hasEvent ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: hasEvent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (hasEvent && endTime.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        endTime,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Line & Dot
            SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: isFirst ? 22 : 0,
                    bottom: isLast ? 22 : 0,
                    width: 2.0,
                    child: Container(
                      color: Colors.white.withAlpha(77),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: hasEvent
                            ? Colors.white
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: hasEvent
                            ? null
                            : Border.all(
                                color: Colors.white70, width: 2),
                        boxShadow: hasEvent
                            ? [
                                BoxShadow(
                                  color: Colors.white.withAlpha(128),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 12, top: 18, bottom: 18, right: 16),
                child: hasEvent
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withAlpha(217),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox(height: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
