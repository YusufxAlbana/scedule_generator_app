import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk fitur copy ke clipboard
import 'package:flutter_markdown/flutter_markdown.dart'; // Untuk render Markdown
import 'package:markdown/markdown.dart' as md; // Tambahkan ini untuk support tabel

class ScheduleResultScreen extends StatelessWidget {
  final String scheduleResult; // Data hasil dari AI
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Hasil Jadwal Optimal",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: "Salin Jadwal",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: scheduleResult));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Jadwal tersalin ke clipboard!"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.indigo.shade800,
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade900,
              Colors.purple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // HEADER INFORMASI (Glassmorphism look)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.orange.shade300, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Jadwal ini disusun otomatis oleh AI berdasarkan prioritas Anda.",
                          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // AREA HASIL (MARKDOWN CARD)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Markdown(
                        data: scheduleResult,
                        selectable: false,
                        extensionSet: md.ExtensionSet.gitHubFlavored,
                        padding: const EdgeInsets.all(24),
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                          h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple),
                          tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
                          tableHeadAlign: TextAlign.left,
                          tablePadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          tableColumnWidth: const FlexColumnWidth(),
                          tableCellsPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // TOMBOL KEMBALI
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo.shade800,
                      elevation: 5,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.refresh_rounded, size: 24),
                    label: const Text("Buat Jadwal Baru"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
