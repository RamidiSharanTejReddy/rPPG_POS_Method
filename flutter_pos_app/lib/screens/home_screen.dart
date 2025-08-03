import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';
import '../pos_processor.dart';

enum MeasurementState { idle, measuring, finished }

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Frame-based seconds counting (increments by 5 every 64 frames)
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isTorchOn = false;
  MeasurementState _state = MeasurementState.idle;
  final POSProcessor _processor = POSProcessor();
  List<double> _bpmList = [];
  double? _currentBPM;
  double? _averageBPM;
  int _seconds = 0;
  static const int _totalSeconds = 30;
  int _frameCount = 0;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    await _initCamera(_selectedCameraIdx);
  }

  Future<void> _initCamera(int cameraIdx) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(_cameras[cameraIdx], ResolutionPreset.low, enableAudio: false);
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
      // Handle torch errors
    }
  }

  bool _isMeasuring = false;
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
    // Show dialog to ask user to place finger
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Place Finger'),
        content: const Text('Please place your finger on the camera lens.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _isMeasuring = true;
    _controller!.startImageStream(_processFrame);
  }

  void _processFrame(CameraImage image) async {
    if (_state != MeasurementState.measuring || !_isMeasuring) return;
    try {
      // Calculate mean RGB from YUV420
      double r = 0, g = 0, b = 0;
      int count = 0;
      for (int y = 0; y < image.planes[0].bytes.length; y += 4) {
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
      String log = 'Frame: $_frameCount, POS values: ${_processor.posValues.length}, Seconds: $_seconds, BPM: ${_currentBPM?.toStringAsFixed(1) ?? "-"}';
      setState(() {
        _debugLog = log;
      });
      // Only update BPM and seconds every 64 frames (power of 2 for FFT)
      if (_processor.posValues.length == 64) {
        double? bpm;
        String bpmDebug = '';
        print('Calculating BPM from ${_processor.posValues.length} POS values');
        try {
          bpm = _processor.calculateBPM(debug: (info) {
            bpmDebug = info;
          });
        } catch (e) {
          bpmDebug = 'BPM calc error: $e';
        }
        setState(() {
          if (bpm != null && bpm <= 110) {
            _currentBPM = bpm;
            _bpmList.add(bpm);
          } else {
            _currentBPM = null;
          }
          _seconds += 2;
          _debugLog = 'Frame: $_frameCount, POS values: 64, Seconds: $_seconds, BPM: '
            + (_currentBPM?.toStringAsFixed(1) ?? "-") + '\n' + bpmDebug
            + (bpm != null && bpm > 110 ? '\n(BPM > 110 ignored)' : '');
        });
        _processor.posValues.clear();
        if (_seconds >= _totalSeconds) {
          _isMeasuring = false;
          _finishMeasurement();
        }
      }
    } catch (e) {
      setState(() {
        _debugLog = 'Error in frame: ' + e.toString();
      });
    }
  }

  void _finishMeasurement() async {
    await _toggleTorch(false);
    await _controller?.stopImageStream();
    setState(() {
      _state = MeasurementState.finished;
      _averageBPM = _processor.averageBPM(_bpmList);
      _isMeasuring = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS rPPG Demo')),
      body: Center(
        child: _state == MeasurementState.idle
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _startMeasurement,
                    child: const Text('Start Measurement'),
                  ),
                  if (_cameras.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(
                        onPressed: _switchCamera,
                        child: const Text('Switch Camera'),
                      ),
                    ),
                ],
              )
            : _state == MeasurementState.measuring
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Measuring...'),
                      if (_controller != null && _controller!.value.isInitialized)
                        SizedBox(
                          width: 200,
                          height: 300,
                          child: CameraPreview(_controller!),
                        ),
                      if (_cameras.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton(
                            onPressed: _switchCamera,
                            child: const Text('Switch Camera'),
                          ),
                        ),
                      if (_currentBPM != null)
                        Text('Current BPM: ${_currentBPM!.toStringAsFixed(1)}'),
                      Text('Seconds: $_seconds/$_totalSeconds'),
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          height: 120,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _debugLog,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Measurement Finished!'),
                      if (_averageBPM != null)
                        Text('Average BPM: ${_averageBPM!.toStringAsFixed(1)}'),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _state = MeasurementState.idle;
                            _averageBPM = null;
                            _currentBPM = null;
                          });
                        },
                        child: const Text('Restart'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
