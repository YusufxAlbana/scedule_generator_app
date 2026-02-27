import 'dart:ui';
import 'package:flutter/material.dart';

import 'services/gemini_service.dart'; // Service untuk memanggil AI
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Menyimpan daftar tugas dalam bentuk List of Map
  final List<Map<String, dynamic>> tasks = [];
  // Controller untuk mengambil input dari TextField
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority; // Menyimpan nilai dropdown
  bool isLoading = false; // Status loading saat proses AI berjalan
  
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40), // Pelan banget
    )..repeat(); // Looping non stop
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    // Controller harus dibersihkan agar tidak memory leak
    taskController.dispose();
    durationController.dispose();
    super.dispose();
  }

  void _addTask() {
    // Validasi sederhana: semua field harus terisi
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        // Tambahkan data ke list
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
        });
      });
      // Reset form setelah input berhasil
      taskController.clear();
      durationController.clear();
      setState(() => priority = null);
    }
  }

  void _generateSchedule() async {
    // Jika belum ada tugas, tampilkan peringatan
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Harap tambahkan tugas dulu!")),
      );
      return;
    }
    setState(() => isLoading = true); // Aktifkan loading
    try {
      // Proses asynchronous ke AI service
      String schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return; // Pastikan widget masih aktif
      // Navigasi ke halaman hasil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      // Tampilkan error jika gagal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      // Loading dimatikan baik sukses maupun gagal
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Doodle Motif (PNG) - Animated Scrolling
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: AnimatedBuilder(
                animation: _bgAnimationController,
                builder: (context, child) {
                  return Container(
                     decoration: BoxDecoration(
                        image: DecorationImage(
                          image: const AssetImage('assets/images/doodle_pattern.png'),
                          fit: BoxFit.none,
                          repeat: ImageRepeat.repeat,
                          // Animasi berjalan perlahan dari atas ke bawah
                          alignment: FractionalOffset(0.0, _bgAnimationController.value),
                        ),
                     ),
                  );
                },
              ),
            ),
          ),
          // Latar belakang header gradient vibrant
          Container(
            height: 220,
            width: double.infinity,
            decoration: const BoxDecoration(
               gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8121DA), // Deep Purple
                  Color(0xFF4C22DC), // Deep Indigo
                  Color(0xFF1E58E9), // Vibrant Blue
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
          // Ornamen di dalam Header
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                // Judul
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 24),
                  child: Center(
                    child: Text(
                      "AI Schedule Generator",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                
                // Card Utama Form Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 40,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF8121DA).withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Input Nama Tugas
                      _buildTextField(
                        controller: taskController,
                        label: "Nama Tugas",
                        icon: Icons.assignment_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Input Durasi
                          Expanded(
                            flex: 12,
                            child: _buildTextField(
                              controller: durationController,
                              label: "Durasi (Menit)",
                              icon: Icons.timer_outlined,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Dropdown Prioritas
                          Expanded(
                            flex: 13,
                            child: _buildDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Tombol Tambah
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
                                color: const Color(0xFF1E58E9).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                            label: const Text(
                              "Tambah ke Daftar",
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
                    ],
                  ),
                ),
                  ),
                ),
                ),
                const SizedBox(height: 24),
                
                // List Tugas
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.80),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.10),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF8121DA).withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8121DA).withOpacity(0.12),
                                        const Color(0xFF4C22DC).withOpacity(0.08),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_turned_in_rounded,
                                    size: 64,
                                    color: Color(0xFF6B21DA),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Belum ada tugas",
                                  style: TextStyle(
                                    color: Colors.grey.shade800, 
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Mulai tambahkan tugas pertamamu!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                                ),
                              ],
                            ),
                            ),
                                ),
                              ),
                            ),
                          )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Dismissible(
                              key: Key(task['name'] + index.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade600, size: 28),
                              ),
                              onDismissed: (_) => setState(() => tasks.removeAt(index)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {},
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Indikator Warna Prioritas (Lebih mencolok)
                                        Container(
                                          width: 12,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _getColor(task['priority']),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF2E3A42),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${task['duration']} Menit",
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getColor(task['priority']).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      task['priority'],
                                                      style: TextStyle(
                                                        color: _getColor(task['priority']),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 22),
                                          onPressed: () => setState(() => tasks.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            ),
          )
        ],
      ),
      // FAB Custom dengan Gradient dan Shadow
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8121DA), Color(0xFF1E58E9)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E58E9).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isLoading ? null : _generateSchedule,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isLoading ? "Memproses..." : "Buat Jadwal AI",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2E3A42)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 6),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E58E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF1E58E9), size: 18),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: priority,
        dropdownColor: Colors.white,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        icon: const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E58E9), size: 20),
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2E3A42)),
        decoration: InputDecoration(
          labelText: "Prioritas",
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E58E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded, color: Color(0xFF1E58E9), size: 18),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        isExpanded: true, // IMPORTANT: to prevent text overflow in dropdown
        items: ["Tinggi", "Sedang", "Rendah"].map((e) {
          return DropdownMenuItem(
            value: e,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                   Container(
                     width: 8,
                     height: 8,
                     decoration: BoxDecoration(
                       color: _getColor(e),
                       shape: BoxShape.circle,
                     ),
                   ),
                   const SizedBox(width: 12),
                   Text(e, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (val) => setState(() => priority = val),
      ),
    );
  }

  // get color
  Color _getColor(String priority) {
    if (priority == "Tinggi") return const Color(0xFFE53935);
    if (priority == "Sedang") return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }
}

class _BackgroundDoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E5FF).withOpacity(0.5) // Sangat soft purple/blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..color = const Color(0xFFE0E5FF).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Doodle 1: Gelombang abstrak di bawah kiri
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(
        size.width * 0.2, size.height * 0.6, size.width * 0.4, size.height * 0.75);
    path1.quadraticBezierTo(
        size.width * 0.6, size.height * 0.9, size.width * 0.3, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paintFill);

    // Doodle 2: Lingkaran-lingkaran kecil tersebar
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.4), 8, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.45), 4, paintFill);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.35), 6, paint);

    // Doodle 3: Bentuk silang (+) / Bintang
    _drawCross(canvas, Offset(size.width * 0.75, size.height * 0.8), paint, 12);
    _drawCross(canvas, Offset(size.width * 0.2, size.height * 0.5), paint, 8);
    _drawCross(canvas, Offset(size.width * 0.9, size.height * 0.6), paint, 10);

    // Doodle 4: Garis zig zag
    final path2 = Path();
    path2.moveTo(size.width * 0.8, size.height * 0.9);
    path2.lineTo(size.width * 0.85, size.height * 0.88);
    path2.lineTo(size.width * 0.82, size.height * 0.85);
    path2.lineTo(size.width * 0.88, size.height * 0.83);
    canvas.drawPath(path2, paint);
    
    // Doodle 5: Semi-circle
    canvas.drawArc(
        Rect.fromCircle(center: Offset(0, size.height * 0.4), radius: 40),
        -1.57,
        3.14,
        false,
        paint);
  }

  void _drawCross(Canvas canvas, Offset center, Paint paint, double size) {
    canvas.drawLine(
        Offset(center.dx - size, center.dy), Offset(center.dx + size, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx, center.dy - size), Offset(center.dx, center.dy + size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}