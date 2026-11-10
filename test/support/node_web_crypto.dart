// Test-harness-only compatibility shim for `dart test -p node`.
//
// `package:test`'s Node runner concatenates `node_preamble` before the
// dart2js output. That preamble does:
//
//     var self = dartNodeIsActuallyNode ? Object.create(globalThis) : globalThis;
//
// dart2js then reads the Web Crypto API through `self.crypto`. On modern Node,
// `globalThis.crypto` is an accessor whose getter brand-checks its receiver
// (`TypeError: Value of "this" must be of type nullish or must be the global
// object`), and `self` is *not* the global object, so the lookup throws and
// `Random.secure()` fails. See node_preamble 2.0.2 `lib/preamble.dart`.
//
// This file runs before any test body when compiled to JavaScript and, only
// under Node, re-exposes the *genuine* `globalThis.crypto` object as a plain
// data property so the inherited lookup from `self` succeeds. It does not
// generate, wrap, mock or weaken entropy: the same Node Web Crypto object is
// used afterwards, and `getRandomValues` is still the only source of bytes.
//
// The shim is a no-op on the Dart VM (stub implementation) and in real
// browsers (the `_isNode` check is false), so browser conformance keeps using
// the untouched native Web Crypto path.

export 'node_web_crypto_stub.dart'
    if (dart.library.js_interop) 'node_web_crypto_js.dart';
