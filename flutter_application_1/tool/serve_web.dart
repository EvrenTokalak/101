import 'dart:async';
import 'dart:io';

const mimeTypes = {
  'html': 'text/html; charset=utf-8',
  'js': 'application/javascript',
  'css': 'text/css',
  'json': 'application/json',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'wasm': 'application/wasm',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
};

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 7358 : int.parse(arguments[0]);
  final root = Directory(arguments.length > 1 ? arguments[1] : 'build/web')
      .resolveSymbolicLinksSync();
  if (!File('$root/index.html').existsSync()) {
    throw StateError('Missing web build: $root/index.html');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Serving $root at http://localhost:$port/');
  await for (final request in server) {
    unawaited(serve(request, root));
  }
}

Future<void> serve(HttpRequest request, String root) async {
  try {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      return;
    }
    final relative = request.uri.path.replaceFirst(RegExp(r'^/+'), '');
    File? selected;
    // Flutter output can retain percent escapes in asset filenames.
    for (final path in [relative, Uri.decodeComponent(relative)]) {
      final candidate = File('$root/${path.isEmpty ? 'index.html' : path}');
      if (!await candidate.exists()) continue;
      final resolved = await candidate.resolveSymbolicLinks();
      if (!resolved.toLowerCase().startsWith(
        '$root${Platform.pathSeparator}'.toLowerCase(),
      )) {
        request.response.statusCode = HttpStatus.forbidden;
        return;
      }
      selected = File(resolved);
      break;
    }
    if (selected == null) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    final extension = selected.path.split('.').last.toLowerCase();
    request.response.headers.set(HttpHeaders.contentTypeHeader,
        mimeTypes[extension] ?? 'application/octet-stream');
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.contentLength = await selected.length();
    if (request.method == 'GET') {
      await request.response.addStream(selected.openRead());
    }
  } on SocketException {
    // A disconnected client must not stop the server.
  } on HttpException {
    // Interrupted responses do not affect other requests.
  } catch (error) {
    request.response.statusCode = HttpStatus.badRequest;
    stderr.writeln(error);
  } finally {
    try {
      await request.response.close();
    } on Exception {
      // The browser may already have disconnected.
    }
  }
}
