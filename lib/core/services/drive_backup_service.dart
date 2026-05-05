// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

class DriveBackupService {
  static const _gasUrl = 'https://script.google.com/macros/s/AKfycbwmRw2CGrZXGQVoWok7j6B4Mbz9aAMk9bhBnmEPagkNdZtE_5h8c7_SaCRfJoUhNDkKlw/exec';

  static const _monthNames = [
    'Styczeń','Luty','Marzec','Kwiecień','Maj','Czerwiec',
    'Lipiec','Sierpień','Wrzesień','Październik','Listopad','Grudzień',
  ];

  static String monthFolder(DateTime dt) => '${_monthNames[dt.month - 1]} ${dt.year}';

  static String buildFilename({
    required String nrDostawy,
    required String dostawcaKod,
    required String dostawcaNazwa,
    required DateTime dt,
    String suffix = '',
  }) {
    final dd  = dt.day.toString().padLeft(2, '0');
    final mm  = dt.month.toString().padLeft(2, '0');
    final hh  = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final base = '$nrDostawy / $dostawcaKod - $dostawcaNazwa $dd.$mm.${dt.year} $hh:$min';
    return suffix.isEmpty ? '$base.pdf' : '$base - $suffix.pdf';
  }

  static void upload(Uint8List pdfBytes, String filename, String month) {
    try {
      final body = jsonEncode({
        'pdf':      base64Encode(pdfBytes),
        'filename': filename,
        'month':    month,
      });
      html.HttpRequest()
        ..open('POST', _gasUrl, async: true)
        ..setRequestHeader('Content-Type', 'text/plain;charset=utf-8')
        ..send(body);
    } catch (_) {
      // fire-and-forget
    }
  }
}
