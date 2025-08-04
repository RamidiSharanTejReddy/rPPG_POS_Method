import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';

class MeasuringScreen extends StatelessWidget {
  final CameraController? controller;
  final List<CameraDescription> cameras;
  final VoidCallback onSwitchCamera;
  final double? currentBPM;
  final int seconds;
  final int totalSeconds;
  final String debugLog;
  final VoidCallback? onMeasurementComplete;

  const MeasuringScreen({
    super.key,
    this.controller,
    required this.cameras,
    required this.onSwitchCamera,
    this.currentBPM,
    required this.seconds,
    required this.totalSeconds,
    required this.debugLog,
    this.onMeasurementComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (controller != null && controller!.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  ),
                ),
              if (cameras.length > 1)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.heartGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.heartPink.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: onSwitchCamera,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flip_camera_ios, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Switch Camera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (currentBPM != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.heartGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.heartPink.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Current BPM',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          currentBPM!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cogniBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Time: $seconds/$totalSeconds seconds',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.cogniBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                debugLog,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.cogniBlue.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
