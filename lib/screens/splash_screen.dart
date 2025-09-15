import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/clinic_settings_service.dart';
import '../services/logo_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/clinic_context.dart';
import '../config/clinic_defaults.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _bgController;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnim = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoController.forward();

    _bgController = AnimationController(vsync: this, duration: const Duration(milliseconds: 15000))
      ..repeat(reverse: true);

    // Try to show cached logo immediately, then update from settings if available
    _loadCachedThenRemote();
  }

  Future<void> _loadCachedThenRemote() async {
    try {
      final cached = await LogoCacheService.load();
      if (mounted && cached != null) {
        setState(() => _logoBytes = cached);
      }
    } catch (_) {}
    await _loadClinicLogo();
  }

  Future<void> _loadClinicLogo() async {
    try {
      final svc = ClinicSettingsService();
      // Use active clinic id if available; otherwise fallback to last saved id
      String? id = ClinicContext.activeClinicId;
      if (id == null || id.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          id = prefs.getString('mydent.lastClinicId');
        } catch (_) {}
      }
      final data = await svc.getClinicInfo(clinicId: id);
      final url = (data?['logoUrl'] as String?)?.trim();
      if (url != null && url.isNotEmpty) {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200 && mounted) {
          final bytes = resp.bodyBytes;
          setState(() => _logoBytes = bytes);
          // Save to cache for next launch
          await LogoCacheService.save(bytes);
        }
      }
    } catch (_) {
      // ignore errors; we will just show default logo
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FC),
      body: Stack(
        children: [
          // Soft gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF5FC), Color(0xFFEFE0FF)],
              ),
            ),
          ),
          // Floating pastel bubbles
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              double t = _bgController.value;
              return Stack(
                children: [
                  _bubble(
                    size: size,
                    dx: 0.15 + 0.02 * sin(t * pi * 2),
                    dy: 0.2 + 0.02 * cos(t * pi * 2),
                    color: const Color(0xFFBEE1FF).withOpacity(0.5),
                    radius: 80,
                  ),
                  _bubble(
                    size: size,
                    dx: 0.85 + 0.02 * cos(t * pi * 2),
                    dy: 0.25 + 0.02 * sin(t * pi * 2),
                    color: const Color(0xFFF9D1FF).withOpacity(0.5),
                    radius: 70,
                  ),
                  _bubble(
                    size: size,
                    dx: 0.8 + 0.02 * sin(t * pi * 2),
                    dy: 0.85 + 0.02 * cos(t * pi * 2),
                    color: const Color(0xFFC9F0E1).withOpacity(0.5),
                    radius: 90,
                  ),
                  _bubble(
                    size: size,
                    dx: 0.2 + 0.02 * cos(t * pi * 2),
                    dy: 0.8 + 0.02 * sin(t * pi * 2),
                    color: const Color(0xFFFFE5C8).withOpacity(0.55),
                    radius: 60,
                  ),
                ],
              );
            },
          ),
          // Center logo + app name
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(_scaleAnim),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: _logoBytes != null
                          ? Image.memory(_logoBytes!, width: 200, height: 200, filterQuality: FilterQuality.medium)
                          : Image.asset(ClinicDefaults.defaultLogoAsset, width: 200, height: 200),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MyDent',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6A4DBA),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dental Clinic Assistant',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9C88C3),
                        fontFamily: 'Poppins',
                      ),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _bubble({required Size size, required double dx, required double dy, required Color color, required double radius}) {
    return Align(
      alignment: Alignment(dx * 2 - 1, dy * 2 - 1),
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          ],
        ),
      ),
    );
  }
}
