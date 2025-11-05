import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'package:js/js_util.dart' as js_util;

Future<void> ensureFirebaseWebLoaded() {
  _loader ??= _ensureFirebasePrepared();
  return _loader!;
}

Future<void>? _loader;

Future<void> _ensureFirebasePrepared() async {
  if (js_util.hasProperty(web.window, '__mydentFirebaseReady')) {
    final Object? promise =
        js_util.getProperty(web.window, '__mydentFirebaseReady');
    try {
      if (promise != null) {
        await js_util.promiseToFuture<void>(promise);
      }
    } catch (_) {
      // fall through to local loader
    }
    if (_isFirebaseReady()) {
      return;
    }
  }
  await _loadFirebaseScripts();
}

Future<void> _loadFirebaseScripts() async {
  if (_isFirebaseReady()) {
    return;
  }

  for (final _FirebaseScript script in _firebaseScripts) {
    await _injectScript(script);
  }

  if (!_isFirebaseReady()) {
    throw StateError('Unable to load Firebase JS SDK');
  }
}

bool _isFirebaseReady() {
  try {
    return js_util.hasProperty(web.window, 'firebase');
  } catch (_) {
    return false;
  }
}

Future<void> _injectScript(_FirebaseScript script) async {
  final web.Document document = web.window.document;

  final web.Node? existing = document.querySelector(
    'script[data-mydent-firebase="${script.id}"]',
  );
  if (existing != null) {
    return;
  }

  final web.HTMLScriptElement element =
      document.createElement('script') as web.HTMLScriptElement;
  element
    ..async = false
    ..defer = false
    ..type = 'text/javascript'
    ..src = script.url
    ..setAttribute('data-mydent-firebase', script.id);

  final Completer<void> completer = Completer<void>();

  void handleLoad(JSAny? _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void handleError(JSAny? error) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Failed to load Firebase script ${script.url}: $error'),
      );
    }
  }

  js_util.callMethod<void>(
    element,
    'addEventListener',
    <Object?>['load', js_util.allowInterop(handleLoad)],
  );
  js_util.callMethod<void>(
    element,
    'addEventListener',
    <Object?>['error', js_util.allowInterop(handleError)],
  );

  (document.head ?? document.body ?? document).appendChild(element);

  await completer.future;
}

class _FirebaseScript {
  const _FirebaseScript(this.id, this.url);

  final String id;
  final String url;
}

const List<_FirebaseScript> _firebaseScripts = <_FirebaseScript>[
  _FirebaseScript(
    'firebase-app',
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
  ),
  _FirebaseScript(
    'firebase-auth',
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth-compat.js',
  ),
  _FirebaseScript(
    'firebase-firestore',
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js',
  ),
  _FirebaseScript(
    'firebase-storage',
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-storage-compat.js',
  ),
];
