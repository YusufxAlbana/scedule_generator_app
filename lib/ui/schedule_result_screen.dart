import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScheduleResultScreen extends StatelessWidget {
  final String scheduleResult;

  const ScheduleResultScreen({super.key, required this.scheduleResult});

  // Coba extract JSON dari response (bisa ada teks sebelum/sesudah JSON)
  Map<String, dynamic>? _tryParseJson(String raw) {
    // Bersihkan code block markdown
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Coba langsung parse
    try {
      final data = jsonDecode(cleaned);
      if (data is Map<String, dynamic> && data.containsKey('schedule')) {
        return data;
      }
    } catch (_) {}

    // Coba extract JSON object dari dalam teks
    final jsonMatch = RegExp(r'\{[\s\S]*"schedule"[\s\S]*\}').firstMatch(cleaned);
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
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final tableLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('|') && line.endsWith('|')) {
        // Skip separator lines like |---|---|
        if (RegExp(r'^\|[\s\-:]+\|$').hasMatch(line.replaceAll(' ', ''))) continue;
        tableLines.add(line);
      }
    }

    if (tableLines.length < 2) return []; // Butuh minimal header + 1 data row

    // Parse header
    final headers = tableLines[0]
        .split('|')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    // Parse data rows
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

  // Extract tips dari teks setelah tabel
  String _extractTips(String raw) {
    final lines = raw.split('\n');
    final tipLines = <String>[];
    bool afterTable = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (afterTable && trimmed.isNotEmpty && !trimmed.startsWith('|')) {
        tipLines.add(trimmed);
      }
      if (trimmed.startsWith('|') && !RegExp(r'^\|[\s\-:]+\|$').hasMatch(trimmed.replaceAll(' ', ''))) {
        afterTable = true;
      }
    }

    return tipLines.join(' ').trim();
  }

  // Build readable text for clipboard
  String _buildCopyText(Map<String, dynamic> data) {
    final schedule = List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final tips = data['tips'] as String? ?? '';

    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal Harian');
    buffer.writeln('═══════════════════════');

    for (final item in schedule) {
      if (item['hasEvent'] == true) {
        buffer.writeln('${item['time']} - ${item['endTime']}  │  ${item['title']}');
        if (item['subtitle'] != null && (item['subtitle'] as String).isNotEmpty) {
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

  String _buildCopyTextFromTable(List<Map<String, String>> rows, String tips) {
    final buffer = StringBuffer();
    buffer.writeln('📅 Jadwal Harian');
    buffer.writeln('═══════════════════════');

    for (final row in rows) {
      final waktu = row['waktu'] ?? row['time'] ?? '';
      final aktivitas = row['aktivitas'] ?? row['activity'] ?? row['title'] ?? '';
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

  @override
  Widget build(BuildContext context) {
    // Coba parse JSON
    final jsonData = _tryParseJson(scheduleResult);

    // Kalau JSON berhasil
    if (jsonData != null) {
      return _buildScaffold(
        context,
        body: _buildCalendarView(context, jsonData),
      );
    }

    // Fallback: coba parse markdown table
    final tableRows = _parseMarkdownTable(scheduleResult);
    if (tableRows.isNotEmpty) {
      return _buildScaffold(
        context,
        body: _buildMarkdownTableView(context, tableRows),
      );
    }

    // Terakhir: tampilkan raw text dengan formatting yang lebih baik
    return _buildScaffold(
      context,
      body: _buildFallbackView(context, scheduleResult),
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  // ============= JSON CALENDAR VIEW =============
  Widget _buildCalendarView(BuildContext context, Map<String, dynamic> data) {
    final schedule = List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final tips = data['tips'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const Text(
                  "📅 Daily Schedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Timeline List
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

          // Copy & Back Buttons
          _buildActionButtons(context, () {
            Clipboard.setData(ClipboardData(text: _buildCopyText(data)));
            _showCopiedSnackbar(context);
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============= MARKDOWN TABLE VIEW =============
  Widget _buildMarkdownTableView(BuildContext context, List<Map<String, String>> rows) {
    final tips = _extractTips(scheduleResult);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule Card
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
                const Text(
                  "📅 Daily Schedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Table Rows as Timeline
                ...rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final waktu = row['waktu'] ?? row['time'] ?? '';
                  final aktivitas = row['aktivitas'] ?? row['activity'] ?? row['title'] ?? '';
                  final durasi = row['durasi'] ?? row['duration'] ?? '';
                  final prioritas = row['prioritas'] ?? row['priority'] ?? '';
                  final isIstirahat = aktivitas.toLowerCase().contains('istirahat') ||
                      aktivitas.toLowerCase().contains('break');

                  // Parse time range
                  String startTime = waktu;
                  String endTime = '';
                  if (waktu.contains('–') || waktu.contains('-')) {
                    final parts = waktu.split(RegExp(r'[–\-]'));
                    startTime = parts[0].trim();
                    endTime = parts.length > 1 ? parts[1].trim() : '';
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

          // Copy & Back Buttons
          _buildActionButtons(context, () {
            Clipboard.setData(ClipboardData(text: _buildCopyTextFromTable(rows, tips)));
            _showCopiedSnackbar(context);
          }),

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
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFF4E5),
                  const Color(0xFFFFF9F0),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              children: [
                const Text("⚠️", style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
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

          // Raw text in card
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
              style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF2E3A42)),
            ),
          ),
          const SizedBox(height: 24),

          // Copy & Back Buttons
          _buildActionButtons(context, () {
            Clipboard.setData(ClipboardData(text: rawText));
            _showCopiedSnackbar(context);
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ============= SHARED WIDGETS =============

  Widget _buildActionButtons(BuildContext context, VoidCallback onCopy) {
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
              icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.white),
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
              side: const BorderSide(color: Color(0xFF4C22DC), width: 1.5),
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
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                padding: const EdgeInsets.only(left: 20, top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: hasEvent ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: hasEvent ? FontWeight.w800 : FontWeight.w600,
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
                        color: hasEvent ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: hasEvent ? null : Border.all(color: Colors.white70, width: 2),
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
                padding: const EdgeInsets.only(left: 12, top: 18, bottom: 18, right: 16),
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
