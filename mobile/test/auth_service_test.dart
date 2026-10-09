import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_health_fitness_mobile/core/api_service.dart';
import 'package:smart_health_fitness_mobile/core/app_config.dart';
import 'package:smart_health_fitness_mobile/features/auth/auth_service.dart';
import 'package:smart_health_fitness_mobile/features/auth/token_store.dart';

const userJson = {
  'id': 'user-id',
  'firstName': 'Mert',
  'lastName': 'Test',
  'email': 'mert@example.test',
  'roles': ['User'],
  'phoneNumber': null,
  'birthDate': null,
  'gender': null,
  'heightCm': null,
};

Map<String, dynamic> tokens(String suffix, {bool expired = false}) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'expiresAt': DateTime.now()
      .toUtc()
      .add(Duration(minutes: expired ? -5 : 15))
      .toIso8601String(),
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

ApiService makeApi(Future<http.Response> Function(http.Request) handler) {
  final config = AppConfig('https://api.example.test');
  return ApiService(
    config,
    TokenStore(server: config.apiBaseUrl.toString()),
    client: MockClient(handler),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('register sends only documented fields and does not sign in', () async {
    final auth = AuthService(
      makeApi((request) async {
        expect(request.url.path, '/api/auth/register');
        expect(jsonDecode(request.body), {
          'firstName': 'Mert',
          'lastName': 'Test',
          'email': 'mert@example.test',
          'password': '  Password123!  ',
        });
        expect(request.headers.containsKey('Authorization'), isFalse);
        return jsonResponse(userJson, 201);
      }),
    );
    addTearDown(auth.dispose);
    await auth.restoreSession();
    await auth.register(
      firstName: ' Mert ',
      lastName: 'Test ',
      email: ' mert@example.test ',
      password: '  Password123!  ',
    );
    expect(auth.status, AuthStatus.signedOut);
    expect(await auth.api.tokenStore.read(), isNull);
  });

  test('login uses me, saves a pair and restores on a new service', () async {
    Future<http.Response> handler(http.Request request) async {
      if (request.url.path == '/api/auth/login') {
        return jsonResponse({...tokens('first'), 'user': userJson});
      }
      expect(request.url.path, '/api/users/me');
      expect(request.headers['Authorization'], 'Bearer access-first');
      return jsonResponse(userJson);
    }

    final auth = AuthService(makeApi(handler));
    addTearDown(auth.dispose);
    await auth.login('mert@example.test', 'Password123!');
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.user!.roles, ['User']);
    final restored = AuthService(makeApi(handler));
    addTearDown(restored.dispose);
    await restored.restoreSession();
    expect(restored.status, AuthStatus.signedIn);
    expect(restored.user!.email, userJson['email']);
  });

  test('expired token with simultaneous me requests refreshes once', () async {
    var refreshCount = 0;
    final api = makeApi((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCount++;
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-old'});
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonResponse(tokens('new'));
      }
      expect(request.headers['Authorization'], 'Bearer access-new');
      return jsonResponse(userJson);
    });
    addTearDown(api.close);
    await api.saveSession(tokens('old', expired: true));
    await Future.wait([api.get('/api/users/me'), api.get('/api/users/me')]);
    expect(refreshCount, 1);
    expect((await api.tokenStore.read())!.refreshToken, 'refresh-new');
  });

  test(
    'web-only role cannot enter mobile Home and session is removed',
    () async {
      final auth = AuthService(
        makeApi((request) async {
          if (request.url.path == '/api/auth/login') {
            return jsonResponse({
              ...tokens('trainer'),
              'user': {
                ...userJson,
                'roles': ['Trainer'],
              },
            });
          }
          if (request.url.path == '/api/auth/logout') {
            return http.Response('', 204);
          }
          return jsonResponse({
            ...userJson,
            'roles': ['Trainer'],
          });
        }),
      );
      addTearDown(auth.dispose);
      await auth.restoreSession();
      await expectLater(
        auth.login('mert@example.test', 'Password123!'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      expect(auth.status, AuthStatus.signedOut);
      expect(await auth.api.tokenStore.read(), isNull);
    },
  );

  test('401 retries once with refreshed credentials', () async {
    var meCount = 0;
    var refreshCount = 0;
    final api = makeApi((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCount++;
        return jsonResponse(tokens('new'));
      }
      meCount++;
      return request.headers['Authorization'] == 'Bearer access-old'
          ? jsonResponse({'title': 'Unauthorized'}, 401)
          : jsonResponse(userJson);
    });
    addTearDown(api.close);
    await api.saveSession(tokens('old'));
    expect((await api.get('/api/users/me'))['id'], 'user-id');
    expect(meCount, 2);
    expect(refreshCount, 1);
  });

  test('invalid refresh clears tokens and returns to login', () async {
    final auth = AuthService(
      makeApi(
        (request) async =>
            jsonResponse({'title': 'Invalid or expired refresh token'}, 401),
      ),
    );
    addTearDown(auth.dispose);
    await auth.api.saveSession(tokens('old', expired: true));
    await auth.restoreSession();
    expect(auth.status, AuthStatus.signedOut);
    expect(await auth.api.tokenStore.read(), isNull);
    expect(auth.notice, contains('Oturum sona erdi'));
  });

  test('network error preserves stored session and offers retry', () async {
    final auth = AuthService(
      makeApi((request) async => throw http.ClientException('offline')),
    );
    addTearDown(auth.dispose);
    await auth.api.saveSession(tokens('old', expired: true));
    await auth.restoreSession();
    expect(auth.status, AuthStatus.retry);
    expect((await auth.api.tokenStore.read())!.refreshToken, 'refresh-old');
  });

  test('server 503 preserves session and is not a validation error', () async {
    final auth = AuthService(
      makeApi((request) async => jsonResponse({'title': 'Unavailable'}, 503)),
    );
    addTearDown(auth.dispose);
    await auth.api.saveSession(tokens('old'));
    await auth.restoreSession();
    expect(auth.status, AuthStatus.retry);
    expect(auth.api.hasSession, isTrue);
  });

  test(
    'logout after renewal revokes new refresh token and removes pair',
    () async {
      final api = makeApi((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return jsonResponse(tokens('new'));
        }
        expect(request.url.path, '/api/auth/logout');
        expect(request.headers['Authorization'], 'Bearer access-new');
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-new'});
        return http.Response('', 204);
      });
      addTearDown(api.close);
      await api.saveSession(tokens('old', expired: true));
      expect(await api.logout(), isTrue);
      expect(api.hasSession, isFalse);
      expect(await api.tokenStore.read(), isNull);
    },
  );

  test('offline logout still clears local session and warns', () async {
    final auth = AuthService(
      makeApi((request) async => throw http.ClientException('offline')),
    );
    addTearDown(auth.dispose);
    await auth.api.saveSession(tokens('old'));
    await auth.logout();
    expect(auth.status, AuthStatus.signedOut);
    expect(await auth.api.tokenStore.read(), isNull);
    expect(auth.notice, contains('Sunucuda oturum kapatılamadı'));
  });

  test('late refresh cannot resurrect a cleared session', () async {
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final api = makeApi((request) {
      sent.complete();
      return response.future;
    });
    addTearDown(api.close);
    await api.saveSession(tokens('old'));
    final pending = api.refreshSession();
    final check = expectLater(pending, throwsA(isA<ApiException>()));
    await sent.future;
    await api.clearSession();
    response.complete(jsonResponse(tokens('new')));
    await check;
    expect(await api.tokenStore.read(), isNull);
    expect(api.hasSession, isFalse);
  });

  test(
    'ProblemDetails retains field errors and translates known auth errors',
    () async {
      final api = makeApi(
        (request) async => jsonResponse({
          'title': 'Validation failed',
          'errors': {
            'email': ['Email invalid.'],
          },
        }, 400),
      );
      addTearDown(api.close);
      await expectLater(
        api.post('/api/auth/register', {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldErrors['email'],
            'email',
            'Email invalid.',
          ),
        ),
      );
      final loginApi = makeApi(
        (request) async =>
            jsonResponse({'title': 'Invalid email or password'}, 401),
      );
      addTearDown(loginApi.close);
      await expectLater(
        loginApi.post('/api/auth/login', {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'E-posta veya şifre hatalı.',
          ),
        ),
      );
    },
  );

  test('tokens for one server cannot be reused on another', () async {
    final store = TokenStore(server: 'https://first.example/');
    await store.write(TokenPair.fromJson(tokens('first')));
    expect(await TokenStore(server: 'https://second.example/').read(), isNull);
  });

  test('configuration requires explicit origin and release HTTPS', () {
    for (final url in [
      '',
      'not-a-url',
      'https://x.test/api',
      'https://user:pass@x.test',
      'https://x.test?secret=x',
    ]) {
      expect(() => AppConfig(url), throwsFormatException);
    }
    expect(
      () => AppConfig('http://10.0.2.2:5000', allowHttp: false),
      throwsFormatException,
    );
    expect(
      AppConfig('http://10.0.2.2:5000', allowHttp: true).apiBaseUrl.host,
      '10.0.2.2',
    );
  });
}
