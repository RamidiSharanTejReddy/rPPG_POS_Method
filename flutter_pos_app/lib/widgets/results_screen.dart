import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final double heartRate;
  final int breathCount;
  final VoidCallback onReset;

  const ResultsScreen({
    Key? key,
    required this.heartRate,
    required this.breathCount,
    required this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, color: Colors.red, size: 80),
          const SizedBox(height: 24),
          Text(
            'Results',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            'Heart Rate: ${heartRate.toStringAsFixed(1)} BPM',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Breath Count: $breathCount',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onReset,
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}