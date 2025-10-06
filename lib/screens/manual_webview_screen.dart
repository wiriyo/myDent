import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ManualWebViewScreen extends StatefulWidget {
  const ManualWebViewScreen({super.key});

  @override
  State<ManualWebViewScreen> createState() => _ManualWebViewScreenState();
}

class _ManualWebViewScreenState extends State<ManualWebViewScreen> {
  static const _manualUrl =
      'https://wiriyo.github.io/mydentManual/';
  static const _fallbackManualUrl =
      'https://knotty-willow-631.notion.site/MyDent-27b36a949fc480f7ab30f8c13fcd4a4a';

  late final WebViewController _controller;
  int _loadProgress = 0;
  String? _lastError;
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _loadProgress = progress),
          onPageStarted: (_) => setState(() => _lastError = null),
          onPageFinished: (_) => setState(() => _loadProgress = 100),
          onWebResourceError: (error) {
            _handleWebError(error);
          },
        ),
      )
      ..loadRequest(Uri.parse(_manualUrl));
  }

  void _handleRefresh() {
    setState(() {
      _lastError = null;
      _usingFallback = false;
      _loadProgress = 0;
    });
    _controller.loadRequest(Uri.parse(_manualUrl));
  }

  void _handleWebError(WebResourceError error) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (!_usingFallback) {
      setState(() {
        _usingFallback = true;
        _loadProgress = 0;
        _lastError = null;
      });
      _controller.loadRequest(Uri.parse(_fallbackManualUrl));
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('กำลังเปิดคู่มือฉบับสำรอง เนื่องจากโหลด GitHub Pages ไม่สำเร็จ'),
        ),
      );
      return;
    }

    setState(() => _lastError = error.description);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถโหลดคู่มือสำรองได้: ${error.description}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
        title: const Text('คู่มือการใช้งาน'),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loadProgress < 100)
              LinearProgressIndicator(
                value: _loadProgress / 100,
                minHeight: 4,
                color: theme.primaryColor,
                backgroundColor: const Color(0xFFFBEAFF),
              ),
            if (_usingFallback)
              Container(
                width: double.infinity,
                color: const Color(0xFFFCF0FF),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Text(
                  'โหลด GitHub Pages ไม่สำเร็จ – กำลังแสดงคู่มือจาก Notion แทน',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (_lastError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'เกิดข้อผิดพลาด',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_lastError!),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _handleRefresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF47FA1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองอีกครั้ง'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
