import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';

/// Handles OAuth flow differently per platform:
/// - Windows: opens browser, starts localhost:9876 HTTP server to catch callback
/// - iOS: opens browser, catches callback via deep link (phantom://)
class OAuthHandler {
  static const _callbackPort = 9876;

  /// Start OAuth flow for a platform. Returns the auth result or null on cancel.
  Future<Map<String, dynamic>?> startOAuth(String platform) async {
    // Get the authorization URL from the backend
    final resp = await ApiClient().get('/auth/$platform/connect');
    final authUrl = resp.data['authorization_url'] as String?;
    if (authUrl == null) return null;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _desktopOAuth(authUrl, platform);
    } else {
      return _mobileOAuth(authUrl, platform);
    }
  }

  /// Desktop: localhost HTTP server catches the OAuth callback.
  Future<Map<String, dynamic>?> _desktopOAuth(String authUrl, String platform) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, _callbackPort);

      // Open browser
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);

      // Wait for callback (timeout 5 min)
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('OAuth timed out'),
      );

      final code = request.uri.queryParameters['code'];
      final state = request.uri.queryParameters['state'];

      // Send success page to browser
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
        <html><body style="background:#0a0a0a;color:#fff;font-family:Arial;display:flex;
          align-items:center;justify-content:center;height:100vh;margin:0;">
          <div style="text-align:center">
            <h1 style="color:#7B2FF7">Connected!</h1>
            <p>You can close this tab and return to Phantom.</p>
          </div>
        </body></html>
      ''');
      await request.response.close();
      await server.close();

      if (code == null || state == null) return null;

      // Forward to backend callback
      final callbackResp = await ApiClient().get(
        '/auth/$platform/callback',
        params: {'code': code, 'state': state},
      );
      return callbackResp.data as Map<String, dynamic>;
    } catch (e) {
      await server?.close();
      return null;
    }
  }

  /// Mobile: opens Safari/Chrome, relies on deep link callback.
  Future<Map<String, dynamic>?> _mobileOAuth(String authUrl, String platform) async {
    await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
    // The callback will come through the GoRouter deep link handler
    // Return null here — the router handles the result
    return null;
  }
}
