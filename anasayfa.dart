// Eski menü taslağı bu klasördeydi. Oynanabilir uygulama alt projededir.
// Bu dosyayı çalıştırmak, alt projedeki Flutter uygulamasını başlatır.
import 'dart:io';

Future<void> main(List<String> args) async {
  final project = Directory.fromUri(
    Platform.script.resolve('flutter_application_1/'),
  );
  final flutter = File.fromUri(
    project.uri.resolve(
      Platform.isWindows ? '.flutter-sdk/bin/flutter.bat' : '.flutter-sdk/bin/flutter',
    ),
  );
  final executable = flutter.existsSync() ? flutter.path : 'flutter';
  final process = await Process.start(
    executable,
    ['run', ...args],
    workingDirectory: project.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
