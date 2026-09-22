import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final catalog = arguments.isEmpty ? Directory.current.path : arguments.first;
  final externalRequests = File('$catalog${Platform.pathSeparator}external_requests.csv');
  final client = HttpClient();
  final request = await client.openUrl(
    'PUT',
    Uri.parse('http://127.0.0.1:9222/json/new?about:blank'),
  );
  final response = await request.close();
  final target = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
  final socket = await WebSocket.connect(target['webSocketDebuggerUrl'] as String);
  var commandId = 0;
  var blocked = false;
  final done = Completer<void>();

  void send(String method, [Map<String, dynamic>? params]) {
    commandId += 1;
    socket.add(jsonEncode({'id': commandId, 'method': method, 'params': params ?? {}}));
  }

  socket.listen((dynamic event) {
    final message = jsonDecode(event as String) as Map<String, dynamic>;
    if (message['method'] != 'Fetch.requestPaused') return;
    final params = message['params'] as Map<String, dynamic>;
    final requestData = params['request'] as Map<String, dynamic>;
    final url = requestData['url'] as String;
    final uri = Uri.parse(url);
    final allowed = uri.scheme == 'data' || uri.scheme == 'blob' || uri.host == '127.0.0.1' || uri.host == 'localhost';
    if (allowed) {
      send('Fetch.continueRequest', {'requestId': params['requestId']});
      return;
    }
    blocked = true;
    externalRequests.writeAsStringSync(
      'CDP_NETWORK_ISOLATION,"$url",${requestData['method']},${params['resourceType']},blocked,non_loopback_browser_request\n',
      mode: FileMode.append,
    );
    send('Fetch.failRequest', {'requestId': params['requestId'], 'errorReason': 'BlockedByClient'});
    if (!done.isCompleted) done.complete();
  });

  send('Page.enable');
  send('Network.enable');
  send('Fetch.enable', {
    'patterns': [
      {'urlPattern': '*'},
    ],
  });
  send('Page.navigate', {'url': 'https://example.com/ui-audit-network-proof'});
  await done.future.timeout(const Duration(seconds: 8));
  send('Page.close');
  await socket.close();
  client.close(force: true);
  if (!blocked) {
    throw StateError('The external browser request was not blocked.');
  }
  stdout.writeln('cdp_external_request=BLOCKED');
}
