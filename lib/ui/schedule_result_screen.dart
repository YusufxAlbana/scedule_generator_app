import 'dart:convert';
import 'package:flutter/material.dart';

class ScheduleResultScreen extends StatelessWidget {
  final String scheduleResult;

  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? data;
    bool isJson = false;

    try {
      // Membersihkan markdown wrapper (jika AI membalas pakai block markdown)
      String cleanJson = scheduleResult
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '');
      data = jsonDecode(cleanJson);
      
      // Validasi apakah properti schedule ada
      if (data != null && data.containsKey('schedule')) {
        isJson = true;
      }
    } catch (e) {
      isJson = false;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Calendar",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
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
      body: SafeArea(
        child: isJson
            ? _buildCalendarView(data!)
            : _buildFallbackView(context, scheduleResult),
      ),
    );
  }

  Widget _buildCalendarView(Map<String, dynamic> data) {
    final schedule = List<Map<String, dynamic>>.from(data['schedule'] ?? []);
    final upcoming = List<Map<String, dynamic>>.from(data['upcoming'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  Color(0xFF8121DA), // Deep Purple
                  Color(0xFF4C22DC), // Deep Indigo
                  Color(0xFF1E58E9), // Vibrant Blue
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E58E9).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  "Daily schedule",
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
          
          const SizedBox(height: 40),
          
          // Upcoming Section
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Upcoming",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2E3A42),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...upcoming.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E58E9).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              e['date'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E58E9),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              e['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

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
      color: hasEvent ? Colors.white.withOpacity(0.08) : Colors.transparent, // Highlight aktif lebih kentara
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
                    width: 2.0, // Garis lebih tebal dikit
                    child: Container(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    top: 20, // sejajarkan dengan teks jam
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: hasEvent ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: hasEvent ? null : Border.all(color: Colors.white70, width: 2),
                        boxShadow: hasEvent ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : [],
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
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox(height: 24), // height untuk item kosong
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Jika AI gagal mengembalikan JSON atau ada error parsing
  Widget _buildFallbackView(BuildContext context, String rawText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5), // Light orange/yellow error box
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Oops, format AI tidak sesuai dengan JSON yang diharapkan. Berikut adalah respons mentahnya:",
              style: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(rawText, style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CB8B8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Kembali", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
