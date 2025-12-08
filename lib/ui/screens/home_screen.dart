import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/recording_schedule.dart';
import '../../services/recorder_service.dart';
import '../../services/schedule_service.dart';
import '../../services/zoom_launcher_service.dart';
import '../../services/settings_service.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

import 'package:window_manager/window_manager.dart';
import '../../services/tray_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WindowListener {
  final RecorderService _recorderService = RecorderService();
  final ScheduleService _scheduleService = ScheduleService();
  final ZoomLauncherService _zoomLauncherService = ZoomLauncherService();
  final TrayService _trayService = TrayService();
  
  // Animation for the "breathing" status indicator
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    
    // Initialize services
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeServices();
    });

    // Refresh UI periodically
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeServices() async {
    await SettingsService().initialize();
    await _recorderService.initialize();
    await _scheduleService.initialize();
    _zoomLauncherService.resetAutomationState(); 
    try {
      await _trayService.initialize();
    } catch (e) {
      // Tray might fail in some environments, ignore
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_recorderService.isRecording) {
      bool shouldClose = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recording in Progress'),
          content: const Text('Recording is currently active. Are you sure you want to quit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Quit'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldClose) return;
      await _recorderService.stopRecording();
    }

    if (_trayService.isInitialized) {
      await _trayService.hideWindow();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium Dark Theme Colors
    const Color bgDark = Color(0xFF0F172A); // Slate 900
    const Color cardBg = Color(0xFF1E293B); // Slate 800
    const Color primaryAccent = Color(0xFF6366F1); // Indigo 500
    const Color secondaryAccent = Color(0xFF8B5CF6); // Violet 500
    
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryAccent.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryAccent.withOpacity(0.15),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar / Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SatLecRec',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Automated Lecture Recorder',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                            ),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            ),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.settings_rounded, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Main Status Card
                  _buildStatusCard(cardBg, primaryAccent, secondaryAccent),
                  
                  const SizedBox(height: 24),
                  
                  // Next Schedule Info
                  Text(
                    'Next Session',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNextSessionCard(cardBg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color bg, Color primary, Color secondary) {
    bool isRecording = _recorderService.isRecording;
    
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isRecording 
            ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)] // Red for recording
            : [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isRecording ? Colors.red : primary).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glass overlay
          Positioned.fill(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(24),
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0), // Just for effect
                 child: Container(
                   color: Colors.black.withOpacity(0.1),
                 ),
               ),
             ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(isRecording ? _animation.value : 1.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: isRecording ? 10 * _animation.value : 0,
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRecording ? 'RECORDING LIVE' : 'SYSTEM IDLE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isRecording)
                      const Icon(Icons.radio_button_checked, color: Colors.white, size: 24)
                    else 
                      const Icon(Icons.check_circle_outline, color: Colors.white54, size: 24),
                  ],
                ),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecording ? 'Recording in Progress' : 'Ready for Saturday',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRecording 
                        ? 'Capturing Monitor 2 & System Audio' 
                        : 'Waiting for scheduled time...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayOfWeek(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  Widget _buildNextSessionCard(Color bg) {
    final nextSchedule = _scheduleService.getNextSchedule();
    
    if (nextSchedule == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            'No upcoming sessions scheduled.',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
        ),
      );
    }

    final schedule = nextSchedule.schedule;
    final nextExecution = nextSchedule.nextExecution;
    final remaining = nextExecution.difference(DateTime.now());
    
    // Formatting remaining time
    String remainingText = '';
    if (remaining.inDays > 0) {
      remainingText = '${remaining.inDays} days';
    } else if (remaining.inHours > 0) {
      remainingText = '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      remainingText = '${remaining.inMinutes}m';
    } else {
      remainingText = '${remaining.inSeconds}s';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nextExecution.day.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getDayOfWeek(nextExecution.weekday),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.indigoAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${schedule.startTimeFormatted} (${schedule.durationMinutes} min)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Starts in $remainingText',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
