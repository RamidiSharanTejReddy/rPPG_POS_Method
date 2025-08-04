import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';
import '../pos_processor.dart';
import '../widgets/breathing_screen.dart';
import '../widgets/measuring_screen.dart';
import '../widgets/results_screen.dart';
import '../theme/app_theme.dart';

enum MeasurementState { idle, measuring, breath, finished }

// Cognizant brand theme
class CognizantTheme {
  static const Color primaryBlue = Color(0xFF0033A1);
  static const Color secondaryBlue = Color(0xFF2B74FF);
  static const Color accentPink = Color(0xFFFF6B8B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color white = Colors.white;
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, secondaryBlue],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, Color(0xFFFF96AB)],
  );

  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w300,
    letterSpacing: 1.2,
    color: white,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: primaryBlue,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Animation control
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Measurement state
  MeasurementState _state = MeasurementState.idle;
  bool _isMeasuring = false;
  String _debugLog = '';
  
  // Breathing measurements
  int _breathCount = 0;
  int _breathSeconds = 0;
  static const int _breathTotalSeconds = 30;
  Timer? _breathTimer;

  // Heart rate measurements
  final POSProcessor _processor = POSProcessor();
  List<double> _bpmList = [];
  double? _currentBPM;
  double? _averageBPM;
  int _seconds = 0;
  static const int _totalSeconds = 30;
  int _frameCount = 0;

  // Camera control
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _initCameras();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    int rearCameraIdx = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back
    );
    if (rearCameraIdx != -1) {
      await _initCamera(rearCameraIdx);
    } else {
      await _initCamera(0);
    }
  }

  Future<void> _initCamera(int cameraIdx) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    
    _controller = CameraController(
      _cameras[cameraIdx], 
      ResolutionPreset.low,
      enableAudio: false,
    );
    
    await _controller!.initialize();
    setState(() {
      _selectedCameraIdx = cameraIdx;
    });
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    int newIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _initCamera(newIdx);
  }

  Future<void> _toggleTorch(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      setState(() {
        _isTorchOn = on;
      });
    } catch (e) {
      // Handle torch errors silently
    }
  }

  void _startMeasurement() async {
    if (_isMeasuring) return;
    
    setState(() {
      _state = MeasurementState.measuring;
      _bpmList.clear();
      _seconds = 0;
      _currentBPM = null;
      _averageBPM = null;
      _debugLog = '';
    });
    
    await _toggleTorch(true);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: CognizantTheme.background,
        title: Text('Place Your Finger',
            style: TextStyle(color: CognizantTheme.primaryBlue)),
        content: const Text(
          'Please place your finger gently on the camera lens',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: CognizantTheme.primaryBlue)),
          ),
        ],
      ),
    );

    _isMeasuring = true;
    _controller!.startImageStream(_processFrame);
  }

  bool _processingFrame = false;
  void _processFrame(CameraImage image) async {
    if (_state != MeasurementState.measuring || 
        !_isMeasuring || 
        _processingFrame) return;
        
    _processingFrame = true;
    
    try {
      double r = 0, g = 0, b = 0;
      int count = 0;
      
      for (int y = 0; y < image.planes[0].bytes.length; y += 32) {
        r += image.planes[0].bytes[y].toDouble();
        g += image.planes[0].bytes[y + 1].toDouble();
        b += image.planes[0].bytes[y + 2].toDouble();
        count++;
      }
      
      r /= count;
      g /= count;
      b /= count;
      
      _processor.addFrame(r, g, b);
      _frameCount++;

      String log = 'Frame: $_frameCount, Values: ${_processor.posValues.length}, '
          'Time: $_seconds s, BPM: ${_currentBPM?.toStringAsFixed(1) ?? "-"}';
      setState(() {
        _debugLog = log;
      });

      if (_processor.posValues.length == 64) {
        double? bpm;
        String bpmDebug = '';
        
        try {
          bpm = _processor.calculateBPM(debug: (info) {
            bpmDebug = info;
          });
        } catch (e) {
          bpmDebug = 'Error: $e';
        }

        setState(() {
          if (bpm != null && bpm <= 110) {
            _currentBPM = bpm;
            _bpmList.add(bpm);
          }
          _seconds += 2;
          _debugLog = log + '\n' + bpmDebug;
        });

        _processor.posValues.clear();
        
        if (_seconds >= _totalSeconds) {
          _isMeasuring = false;
          _finishMeasurement();
        }
      }
    } catch (e) {
      setState(() {
        _debugLog = 'Error: $e';
      });
    } finally {
      _processingFrame = false;
    }
  }

  void _finishMeasurement() async {
    await _toggleTorch(false);
    await _controller?.stopImageStream();
    setState(() {
      _state = MeasurementState.breath;
      _averageBPM = _processor.averageBPM(_bpmList);
    });
  }

  void _resetState() {
    setState(() {
      _state = MeasurementState.idle;
      _breathCount = 0;
      _breathSeconds = 0;
      _breathTimer?.cancel();
      _currentBPM = null;
      _bpmList.clear();
      _averageBPM = null;
      _debugLog = '';
    });
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognizantTheme.background,
      appBar: AppBar(
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: CognizantTheme.primaryGradient),
        ),
        title: Text('Health Monitor', style: CognizantTheme.headingStyle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_state) {
      case MeasurementState.idle:
        return _buildWelcomeScreen();
      case MeasurementState.measuring:
        return MeasuringScreen(
          key: const ValueKey('measuring'),
          controller: _controller,
          cameras: _cameras,
          onSwitchCamera: _switchCamera,
          currentBPM: _currentBPM,
          seconds: _seconds,
          totalSeconds: _totalSeconds,
          debugLog: _debugLog,
          onMeasurementComplete: () {
            setState(() {
              _state = MeasurementState.breath;
            });
          },
        );
      case MeasurementState.breath:
        return BreathingScreen(
          key: const ValueKey('breathing'),
          breathCount: _breathCount,
          onBreathingComplete: () {
            setState(() {
              _state = MeasurementState.finished;
            });
          },
        );
      case MeasurementState.finished:
        return Container(
          key: const ValueKey('results'),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ResultsScreen(
            heartRate: _currentBPM ?? 0,
            breathCount: _breathCount,
            onReset: _resetState,
          ),
        );
    }
  }

  Widget _buildWelcomeScreen() {
    return Container(
      key: const ValueKey('welcome'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => CognizantTheme.accentGradient.createShader(bounds),
            child: const Icon(Icons.favorite, size: 120),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: CognizantTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CognizantTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Welcome to Health Monitor',
              style: CognizantTheme.headingStyle.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Let\'s measure your heart rate and breathing',
            style: CognizantTheme.bodyStyle.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) {
              _animationController.reverse();
              _startMeasurement();
            },
            onTapCancel: () => _animationController.reverse(),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: CognizantTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CognizantTheme.primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Start Measurement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
