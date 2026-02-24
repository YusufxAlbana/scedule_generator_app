import 'package:flutter/material.dart';
import 'services/gemini_service.dart'; // Service untuk memanggil AI
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Menyimpan daftar tugas dalam bentuk List of Map
  final List<Map<String, dynamic>> tasks = [];
  // Controller untuk mengambil input dari TextField
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority; // Menyimpan nilai dropdown
  bool isLoading = false; // Status loading saat proses AI berjalan

  @override
  void dispose() {
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
          // Latar belakang header biru
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF3F51B5), // Warna biru mirip gambar
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Judul
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 20),
                  child: Center(
                    child: Text(
                      "AI Schedule Generator",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                
                // Card Utama Form Input
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      // Input Nama Tugas
                      _buildTextField(
                        controller: taskController,
                        label: "Nama Tugas",
                        icon: Icons.assignment_outlined,
                      ),
                      const SizedBox(height: 14),
                      
                      Row(
                        children: [
                          // Input Durasi
                          Expanded(
                            child: _buildTextField(
                              controller: durationController,
                              label: "Durasi (Menit)",
                              icon: Icons.timer_outlined,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Dropdown Prioritas
                          Expanded(
                            child: _buildDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Tombol Tambah
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: TextButton.icon(
                          onPressed: _addTask,
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF5C6AC4)),
                          label: const Text(
                            "Tambah ke Daftar",
                            style: TextStyle(
                              color: Color(0xFF5C6AC4),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF4F5FB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // List Tugas
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Belum ada tugas.",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tambahkan tugas di atas!",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                              const SizedBox(height: 80), // Biar agak ke tengah
                            ],
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
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.delete, color: Colors.red.shade600),
                              ),
                              onDismissed: (_) => setState(() => tasks.removeAt(index)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {},
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    child: Row(
                                      children: [
                                        // Indikator Warna
                                        Container(
                                          width: 4,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: _getColor(task['priority']),
                                            borderRadius: BorderRadius.circular(4),
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
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${task['duration']} Menit • Prioritas ${task['priority']}",
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
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
          )
        ],
      ),
      // FAB Custom
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: Material(
          color: const Color(0xFFE5E7FF), // Warna ungu muda/biru muda pastel
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E285D)),
                        )
                      : const Icon(Icons.auto_awesome, color: Color(0xFF1E285D), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    isLoading ? "Memproses..." : "Buat Jadwal AI",
                    style: const TextStyle(
                      color: Color(0xFF1E285D), // Warna biru tua
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
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
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade700, size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // Kotak nyaris tegas seperti gambar
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: priority,
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: "Prioritas",
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(Icons.flag, color: Colors.grey.shade700, size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      items: ["Tinggi", "Sedang", "Rendah"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) => setState(() => priority = val),
    );
  }

  // get color
  Color _getColor(String priority) {
    if (priority == "Tinggi") return const Color(0xFFE53935);
    if (priority == "Sedang") return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }
}