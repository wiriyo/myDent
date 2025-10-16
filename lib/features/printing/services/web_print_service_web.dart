// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> Function(Uint8List bytes) createWebPrintService() {
  return (Uint8List bytes) async {
    final base64Png = base64Encode(bytes);

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>MyDent Thermal Print</title>
  <style>
    @page { size: 80mm auto; margin: 0; }
    html, body { margin: 0; padding: 0; background: #ffffff; }
    body { display: flex; justify-content: center; }
    img {
      width: 80mm;
      max-width: 100%;
      display: block;
      margin: 0;
      padding: 0;
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
    .page-break { page-break-after: always; height: 0; }
    @media print {
      html, body { margin: 0; padding: 0; }
      img { width: 80mm; }
    }
  </style>
</head>
<body>
  <img id="receipt-image" src="data:image/png;base64,$base64Png" alt="receipt"/>
  <div class="page-break"></div>
  <script>
    (function() {
      const img = document.getElementById('receipt-image');
      const trigger = function() {
        window.focus();
        window.print();
        setTimeout(function() { window.close(); }, 300);
      };
      if (!img) {
        trigger();
        return;
      }
      if (img.complete) {
        trigger();
      } else {
        img.addEventListener('load', trigger, { once: true });
        img.addEventListener('error', trigger, { once: true });
      }
    })();
  </script>
</body>
</html>
''';

    final html.Blob blob = html.Blob(<String>[htmlContent], 'text/html');
    final String url = html.Url.createObjectUrlFromBlob(blob);

    // ignore: unnecessary_nullable_for_final_variable_declarations
    final html.WindowBase? popup = html.window.open(url, '_blank');
    if (popup == null) {
      html.Url.revokeObjectUrl(url);
      throw StateError('ไม่สามารถเปิดหน้าต่างพิมพ์ได้');
    }

    if (popup is html.Window) {
      popup.onUnload.first.then((_) => html.Url.revokeObjectUrl(url));
    }
  };
}
