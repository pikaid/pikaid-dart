// Test-only JSON-Lines adapter for the official PikaID conformance suite.
//
// This bridge is not part of the published package. It reads one request per
// line on stdin, delegates every operation to the public `package:pikaid`
// API, and writes exactly one response object per line to stdout. Diagnostics
// go to stderr only.
//
// Usage (from the official suite checkout):
//   python3 tools/run_adapter.py --automated-only -- \
//       dart run /path/to/pikaid-dart/tool/official_conformance_adapter.dart
//
// The adapter deliberately contains no encoder, decoder, validator or random
// number generator of its own. `csprng_failure_injection` uses the package's
// documented `PikaidRandomSource` seam so the production CSPRNG path fails
// closed instead of silently falling back.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';

/// Protocol version reported by `hello`.
const int _protocolVersion = 1;

/// Capabilities this bridge genuinely maps onto the public API.
const List<String> _capabilities = <String>[
  'generate_string',
  'text_to_binary',
  'binary_to_text',
  'boolean_validation',
  'format_only_validation',
  'parse_components',
  'parse_datetime',
  'generate_with_timestamp',
  'generate_binary',
  'generate_binary_with_timestamp',
  'public_compare',
  'csprng_failure_injection',
];

final RegExp _lowerHex = RegExp(r'^[0-9a-f]{34}$');

/// Runs the adapter until stdin closes.
Future<void> main() async {
  final randomSource = _SwitchableRandomSource();
  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }
    stdout.write('${jsonEncode(_handle(line, randomSource))}\n');
    await stdout.flush();
  }
}

/// Handles one request line and returns exactly one response envelope.
Map<String, Object?> _handle(
    String line, _SwitchableRandomSource randomSource) {
  Object? requestId = 0;
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      return _error(
          requestId, 'internal_error', 'request must be a JSON object');
    }
    final id = decoded['request_id'];
    if (id is! int) {
      return _error(
          requestId, 'internal_error', 'request_id must be an integer');
    }
    requestId = id;

    final operation = decoded['operation'];
    if (operation is! String) {
      return _error(requestId, 'invalid_input', 'operation must be a string');
    }
    final arguments = decoded['arguments'];
    if (arguments is! Map<String, Object?>) {
      return _error(requestId, 'invalid_input', 'arguments must be an object');
    }

    return _success(
      requestId,
      _dispatch(operation, arguments, randomSource),
    );
  } on _UnsupportedOperation catch (error) {
    return _error(requestId, 'unsupported_operation', error.message);
  } on PikaidEntropyException catch (error) {
    return _error(requestId, 'entropy_unavailable', error.message);
  } on FormatException catch (error) {
    return _error(requestId, 'invalid_input', error.message);
  } on RangeError catch (error) {
    return _error(
      requestId,
      'invalid_input',
      _errorMessage(error.message, error),
    );
  } on ArgumentError catch (error) {
    return _error(
      requestId,
      'invalid_input',
      _errorMessage(error.message, error),
    );
  } catch (error) {
    // Anything else is an unexpected failure. Converting it to invalid_input
    // would hide a crash from the suite's strict rejection checks.
    return _error(requestId, 'internal_error', error.toString());
  }
}

/// Maps [operation] onto the public package API.
Object? _dispatch(
  String operation,
  Map<String, Object?> arguments,
  _SwitchableRandomSource randomSource,
) {
  switch (operation) {
    case 'hello':
      return <String, Object?>{
        'protocol_version': _protocolVersion,
        'capabilities': _capabilities,
      };
    case 'generate_string':
      return Pikaid.generate(randomSource: randomSource).toString();
    case 'text_to_binary':
      return _toHex(Pikaid.parse(_textArgument(arguments)).toBinary());
    case 'binary_to_text':
      return Pikaid.fromBinary(_binaryArgument(arguments)).toString();
    case 'boolean_validation':
      return Pikaid.isValid(_textArgument(arguments));
    case 'format_only_validation':
      return Pikaid.isWellFormed(_textArgument(arguments));
    case 'parse_components':
      final parsed = Pikaid.parse(_textArgument(arguments));
      return <String, Object?>{
        'timestamp_seconds': parsed.timestamp,
        'randomness_hex': parsed.randomnessHex,
        'datetime_utc': _formatUtc(parsed.timestamp),
      };
    case 'generate_with_timestamp':
      return Pikaid.generateAt(
        _timestampArgument(arguments),
        randomSource: randomSource,
      ).toString();
    case 'generate_binary':
      return _toHex(Pikaid.generateBinary(randomSource: randomSource));
    case 'generate_binary_with_timestamp':
      return _toHex(
        Pikaid.generateBinaryAt(
          _timestampArgument(arguments),
          randomSource: randomSource,
        ),
      );
    case 'public_compare':
      final a = Pikaid.parse(_textArgument(arguments, 'a'));
      final b = Pikaid.parse(_textArgument(arguments, 'b'));
      return a.compareTo(b);
    case 'inject_fault':
      return _injectFault(arguments, randomSource);
    default:
      throw _UnsupportedOperation(operation);
  }
}

String _textArgument(Map<String, Object?> arguments, [String name = 'text']) {
  final value = arguments[name];
  if (value is! String) {
    throw FormatException('$name must be a string');
  }
  return value;
}

int _timestampArgument(Map<String, Object?> arguments) {
  final value = arguments['timestamp_seconds'];
  if (value is! int) {
    throw const FormatException('timestamp_seconds must be an integer');
  }
  return value;
}

Uint8List _binaryArgument(Map<String, Object?> arguments) {
  final value = arguments['binary_hex'];
  if (value is! String) {
    throw const FormatException('binary_hex must be a string');
  }
  if (!_lowerHex.hasMatch(value)) {
    throw const FormatException(
      'binary_hex must be exactly 34 lowercase hexadecimal digits',
    );
  }
  final bytes = Uint8List(17);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

Map<String, Object?> _injectFault(
  Map<String, Object?> arguments,
  _SwitchableRandomSource randomSource,
) {
  final fault = arguments['fault'];
  if (fault is! String || fault != 'csprng_failure') {
    throw const FormatException('unknown fault; expected csprng_failure');
  }
  final active = arguments['active'];
  if (active is! bool) {
    throw const FormatException('active must be a boolean');
  }
  randomSource.failing = active;
  return <String, Object?>{'fault': fault, 'active': active};
}

String _toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Formats [seconds] exactly like Python's
/// `datetime.fromtimestamp(seconds, timezone.utc).isoformat()` without a
/// fractional part: `YYYY-MM-DDTHH:MM:SSZ`.
String _formatUtc(int seconds) {
  final value = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  );
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$year-$month-${day}T$hour:$minute:${second}Z';
}

Map<String, Object?> _success(Object? requestId, Object? value) =>
    <String, Object?>{'request_id': requestId, 'ok': true, 'value': value};

Map<String, Object?> _error(
  Object? requestId,
  String category,
  String message,
) =>
    <String, Object?>{
      'request_id': requestId,
      'ok': false,
      'error': <String, Object?>{'category': category, 'message': message},
    };

/// Returns a nonempty diagnostic for an argument/range failure.
String _errorMessage(Object? message, Object fallback) {
  if (message is String && message.isNotEmpty) {
    return message;
  }
  return fallback.toString();
}

/// The requested capability is not implemented by this bridge.
final class _UnsupportedOperation implements Exception {
  _UnsupportedOperation(this.operation);

  final String operation;

  String get message => 'unsupported operation: $operation';
}

/// A random source that can be forced to fail, delegating to the real
/// production CSPRNG while the fault is inactive.
final class _SwitchableRandomSource implements PikaidRandomSource {
  _SwitchableRandomSource();

  final PikaidRandomSource _delegate = const SecurePikaidRandomSource();

  /// When true, every generation path must fail closed with
  /// `entropy_unavailable`.
  bool failing = false;

  @override
  void fillBytes(Uint8List destination) {
    if (failing) {
      throw const PikaidEntropyException('injected CSPRNG failure');
    }
    _delegate.fillBytes(destination);
  }
}
