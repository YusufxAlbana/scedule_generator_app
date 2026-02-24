import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - GANTI dengan milikmu (jangan hardcode di production!)
  static const String apiKey = "AIzaSyAlsKqYlTOP-NLi2HSVZzqZbmof8JQoAlE";

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
Minta tolong buatkan jadwal harian berdasarkan data berikut:
$taskList

ATURAN WAJIB (HARUS DIIKUTI):
1. Setiap aktivitas HANYA BOLEH MUNCUL 1 KALI di jadwal. JANGAN mengulang aktivitas yang sama berkali-kali!
2. Urutkan prioritas (Tinggi → Sedang → Rendah).
3. Sisipkan istirahat 10-15 mnt tiap 1-2 jam.
4. Mulai jam 08:00 pagi.
5. Output HANYA BEBERAPA KATA pembuka, lalu langsung TABEL MARKDOWN. JANGAN gunakan backticks (```) atau code block!
6. Kolo tabel WAJIB: Waktu, Aktivitas, Durasi, Prioritas.
7. SINGKAT & PADAT! Tips produktivitas di bawah tabel MAKSIMAL HANYA 2 KALIMAT PENDEK. Jangan buat poin-poin panjang!
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