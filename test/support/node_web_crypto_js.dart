// JavaScript implementation of the Node Web Crypto harness shim.
//
// See `node_web_crypto.dart` for the full explanation. This file only runs
// when compiled to JavaScript or WebAssembly; the `_isNode` guard keeps it
// inert in browsers.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _globalThis;

@JS('globalThis.process')
external JSObject? get _nodeProcess;

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getOwnPropertyDescriptor(
  JSObject target,
  JSString property,
);

@JS('Object.defineProperty')
external JSObject _defineProperty(
  JSObject target,
  JSString property,
  JSObject descriptor,
);

bool get _isNode {
  final process = _nodeProcess;
  if (process == null) {
    return false;
  }
  final versions = process['versions'];
  if (versions == null) {
    return false;
  }
  return (versions as JSObject)['node'] != null;
}

/// Re-exposes Node's genuine `globalThis.crypto` as a writable data property.
///
/// No-op on the Dart VM, in browsers, when `crypto` is absent, or when the
/// property is already a data property. Under Node it makes the `self` object
/// created by `node_preamble` inherit a working `crypto`, so dart2js's
/// `Random.secure()` reaches the real Web Crypto implementation.
void repairNodeWebCrypto() {
  if (!_isNode) {
    return;
  }
  final global = _globalThis;
  final crypto = global['crypto'];
  if (crypto == null) {
    return;
  }
  final existing = _getOwnPropertyDescriptor(global, 'crypto'.toJS);
  if (existing != null && existing['value'] != null) {
    return;
  }
  final descriptor = JSObject()
    ..['value'] = crypto
    ..['configurable'] = true.toJS
    ..['writable'] = true.toJS;
  _defineProperty(global, 'crypto'.toJS, descriptor);
}
