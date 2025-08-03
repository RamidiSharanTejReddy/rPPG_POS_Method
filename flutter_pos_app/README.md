# Flutter POS App

This Flutter application implements the Point of Sale (POS) technique, capturing video frames at 30 frames per second and averaging the POS values collected every second for a 30-second video.

## Project Structure

```
flutter_pos_app
├── lib
│   ├── main.dart
│   ├── pos
│   │   ├── pos_processor.dart
│   │   └── pos_utils.dart
│   ├── video
│   │   ├── video_capture.dart
│   │   └── frame_processor.dart
│   └── widgets
│       └── pos_display.dart
├── pubspec.yaml
└── README.md
```

## Features

- Capture video at 30 frames per second.
- Process frames to calculate POS values.
- Average POS values every second for a duration of 30 seconds.
- Display averaged POS values in a user-friendly interface.

## Setup Instructions

1. Clone the repository:
   ```
   git clone <repository-url>
   ```

2. Navigate to the project directory:
   ```
   cd flutter_pos_app
   ```

3. Install the dependencies:
   ```
   flutter pub get
   ```

4. Run the application:
   ```
   flutter run
   ```

## Usage Guidelines

- Ensure that the device has camera permissions enabled.
- Follow the on-screen instructions to start capturing video.
- The averaged POS values will be displayed after processing the video.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.