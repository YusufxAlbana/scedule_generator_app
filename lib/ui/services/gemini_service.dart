import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key dibaca dari --dart-define (aman, tidak hardcode!)
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Gunakan model stabil terbaru
  static const String model = "gemini-2.5-flash";

  // Endpoint resmi Gemini generateContent
  static String get baseUrl =>
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent";

  // Bangun prompt dari data tugas
  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    final taskList = tasks.map((t) {
      return "- ${t['name']} (Durasi: ${t['duration']} menit, Prioritas: ${t['priority']})";
    }).join('\n');

    return """
Buatkan jadwal harian berdasarkan data berikut:
$taskList

ATURAN WAJIB:
1. Setiap aktivitas HANYA BOLEH MUNCUL 1 KALI. JANGAN mengulang!
2. Urutkan prioritas (Tinggi → Sedang → Rendah).
3. Sisipkan istirahat 10-15 menit tiap 1-2 jam.
4. Mulai jam 08:00 pagi.
5. Beri tips produktivitas SINGKAT (maks 2 kalimat).

FORMAT OUTPUT WAJIB JSON (TANPA backticks, TANPA markdown, HANYA JSON murni):
{"schedule":[{"time":"08:00","endTime":"09:00","title":"Nama Aktivitas","subtitle":"60 menit • Tinggi","hasEvent":true,"priority":"Tinggi"},{"time":"09:00","endTime":"09:15","title":"Istirahat","subtitle":"15 menit","hasEvent":false,"priority":"-"}],"tips":"Tips singkat di sini."}

PENTING: Output HANYA JSON valid. Tidak ada teks lain sebelum atau sesudah JSON. Tidak ada backticks. Tidak ada code block.
""";
  }

  static Future<String> generateSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      // Bangun prompt dari data tugas
      final prompt = _buildPrompt(tasks);

      // Siapkan URL dengan API key sebagai query param
      final url = Uri.parse('$baseUrl?key=$apiKey');

      // Body request sesuai spec resmi Gemini
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        // Optional: tambah konfigurasi (temperature, maxOutputTokens, dll)
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 4096,
        },
      };

      // Kirim POST request
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // Handle response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["candidates"] != null &&
            data["candidates"].isNotEmpty &&
            data["candidates"][0]["content"] != null &&
            data["candidates"][0]["content"]["parts"] != null &&
            data["candidates"][0]["content"]["parts"].isNotEmpty) {
          String responseText = data["candidates"][0]["content"]["parts"][0]["text"] as String;
          // Bersihkan code block markdown jika Gemini tetap mengembalikannya
          // Karena flutter_markdown akan merender code block sebagai teks biasa (tidak jadi tabel)
          responseText = responseText.replaceAll(RegExp(r'```markdown\s*', caseSensitive: false), '');
          responseText = responseText.replaceAll(RegExp(r'```\s*'), '');
          return responseText;
        }
        return "Tidak ada jadwal yang dihasilkan dari AI.";
      } else {
        print("API Error - Status: ${response.statusCode}, Body: ${response.body}");
        if (response.statusCode == 429) {
          throw Exception("Rate limit tercapai (429). Tunggu beberapa menit atau upgrade quota.");
        }
        if (response.statusCode == 401) {
          throw Exception("API key tidak valid (401). Periksa key Anda.");
        }
        if (response.statusCode == 400) {
          throw Exception("Request salah format (400): ${response.body}");
        }
        throw Exception("Gagal memanggil Gemini API (Code: ${response.statusCode})");
      }
    } catch (e) {
      print("Exception saat generate schedule: $e");
      throw Exception("Error saat generate jadwal: $e");
    }
  }
}