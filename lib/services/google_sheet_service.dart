import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple helper to fetch key/value pairs from a publicly published Google
/// Sheets CSV export. The sheet should contain two columns: `key` and `value`.
class GoogleSheetService {
  /// Fetch CSV from a public Google Sheets export URL and parse into a map.
  /// Example CSV URL: https://docs.google.com/spreadsheets/d/<SHEET_ID>/export?format=csv&gid=<GID>
  static Future<Map<String, String>> fetchKeyValueCsv(String csvUrl) async {
    final resp = await http.get(Uri.parse(csvUrl));
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch sheet: ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final body = resp.body;
    // Simple CSV parsing: split lines, then split by comma; assume header present
    final lines = const LineSplitter().convert(body).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return {};

    // Determine header positions by splitting first line
    final header = _splitCsvLine(lines.first);
    final keyIndex = header.indexWhere((h) => h.toLowerCase().trim() == 'key');
    final valueIndex = header.indexWhere((h) => h.toLowerCase().trim() == 'value');

    final Map<String, String> result = {};
    for (var i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.isEmpty) continue;
      final k = (keyIndex >= 0 && keyIndex < cols.length) ? cols[keyIndex].trim() : (cols.isNotEmpty ? cols[0].trim() : '');
      final v = (valueIndex >= 0 && valueIndex < cols.length) ? cols[valueIndex].trim() : (cols.length > 1 ? cols[1].trim() : '');
      if (k.isNotEmpty) result[k] = v;
    }

    return result;
  }

  // Very small CSV splitter that handles quoted values and commas.
  static List<String> _splitCsvLine(String line) {
    final List<String> out = [];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        // Toggle quote state; handle double quotes as escaped quote
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    out.add(buffer.toString());
    return out;
  }
}
