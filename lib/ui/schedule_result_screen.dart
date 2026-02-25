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
                  Color(0xFF7DE2D1), // Cyan muda / Mint
                  Color(0xFF4CB8B8), // Teal agak gelap
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  "Daily schedule",
                  style: TextStyle(
                    color: Color(0xFF1F4A4A), // Dark teal
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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
          
          const SizedBox(height: 32),
          
          // Upcoming Section
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: upcoming.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            e['date'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E3A42),
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
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
      color: hasEvent ? Colors.black.withOpacity(0.08) : Colors.transparent,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time Column
            SizedBox(
              width: 70,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: hasEvent ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: hasEvent ? FontWeight.w800 : FontWeight.w500,
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
              width: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: isFirst ? 22 : 0,
                    bottom: isLast ? 22 : 0,
                    width: 1.5,
                    child: Container(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    top: 20, // sejajarkan dengan teks jam
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 18, bottom: 18, right: 16),
                child: hasEvent
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF1F4A4A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
