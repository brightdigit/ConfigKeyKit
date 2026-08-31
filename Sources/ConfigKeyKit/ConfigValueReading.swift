//
//  ConfigValueReading.swift
//  ConfigKeyKit
//
//  Created by Leo Dion.
//  Copyright © 2026 BrightDigit.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

public import Foundation

/// A reader that resolves ``ConfigKey`` / ``OptionalConfigKey`` values across
/// every ``ConfigKeySource`` in precedence order.
///
/// This protocol holds the source-precedence resolution that downstream
/// consumers previously hand-wrote as an `extension ConfigReader { read(_:) }`
/// (see issue #1, "Remove Need for Extension"). The logic lives here, in
/// ConfigKeyKit's Foundation-only core, so it is shared and unit-testable with a
/// trivial mock — no configuration framework required.
///
/// The three primitive requirements mirror the read surface of
/// `swift-configuration`'s `ConfigReader` exactly, so a consumer conforms in a
/// single line:
///
/// ```swift
/// extension ConfigReader: @retroactive ConfigValueReading {
///   public func makeConfigKey(_ s: String) -> Configuration.ConfigKey { .init(s) }
/// }
/// ```
///
/// `string(forKey:isSecret:fileID:line:)`, `int(...)`, and `double(...)` are
/// then witnessed by `ConfigReader`'s own methods, and ``Key`` infers to
/// `Configuration.ConfigKey`.
public protocol ConfigValueReading {
  /// The reader's native key type (e.g. `Configuration.ConfigKey`).
  associatedtype Key

  /// The sources consulted during resolution, in precedence order, highest
  /// first. Defaults to ``ConfigKeySource/priority``; override to resolve a
  /// reader with a different precedence (e.g. environment before command line).
  var sourcePriority: [ConfigKeySource] { get }

  /// Builds a native ``Key`` from a resolved per-source key string.
  func makeConfigKey(_ string: String) -> Key

  /// Reads a string value for the native key, or `nil` if absent.
  func string(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> String?

  /// Reads an integer value for the native key, or `nil` if absent.
  func int(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> Int?

  /// Reads a double value for the native key, or `nil` if absent.
  func double(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> Double?

  /// Reads a boolean value for the native key, or `nil` when this source supplies
  /// nothing usable — absent, empty, or not recognizable as a boolean.
  ///
  /// A default implementation parses the string value, so existing conformers keep
  /// working unchanged. Readers with a native boolean accessor — `ConfigReader` among
  /// them — witness this requirement directly, which matters: a command-line provider
  /// reports a *valueless* flag (`--verbose`) only through its boolean accessor. Its
  /// string accessor returns `nil`, so resolving booleans through strings cannot see
  /// flag presence at all.
  func bool(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> Bool?
}

extension ConfigValueReading {
  /// The sources consulted during resolution, defaulting to
  /// ``ConfigKeySource/priority`` (command line, then environment).
  public var sourcePriority: [ConfigKeySource] { ConfigKeySource.priority }

  // MARK: - Required values

  /// Reads a required string value, consulting sources in ``sourcePriority``
  /// order and falling back to the key's default.
  public func read(_ key: ConfigKey<String>) -> String {
    resolvedString(key) ?? key.defaultValue
  }

  /// Reads a required integer value, consulting sources in ``sourcePriority``
  /// order and falling back to the key's default.
  public func read(_ key: ConfigKey<Int>) -> Int {
    resolvedInt(key) ?? key.defaultValue
  }

  /// Reads a required double value, consulting sources in ``sourcePriority``
  /// order and falling back to the key's default.
  public func read(_ key: ConfigKey<Double>) -> Double {
    resolvedDouble(key) ?? key.defaultValue
  }

  /// Reads a required boolean value, consulting sources in ``sourcePriority``
  /// order and falling back to the key's default.
  ///
  /// - Command line: a present key indicates `true` (flag presence, e.g.
  ///   `--verbose`).
  /// - Other sources: `true` / `1` / `yes` (case-insensitive) are truthy; an
  ///   empty value is treated as absent and the next source is consulted.
  public func read(_ key: ConfigKey<Bool>) -> Bool {
    resolvedBool(key) ?? key.defaultValue
  }

  // MARK: - Optional values

  /// Reads an optional string value, or `nil` if no source provides one.
  public func read(_ key: OptionalConfigKey<String>) -> String? {
    resolvedString(key)
  }

  /// Reads an optional integer value, or `nil` if no source provides one.
  public func read(_ key: OptionalConfigKey<Int>) -> Int? {
    resolvedInt(key)
  }

  /// Reads an optional double value, or `nil` if no source provides one.
  public func read(_ key: OptionalConfigKey<Double>) -> Double? {
    resolvedDouble(key)
  }

  /// Reads an optional boolean value, or `nil` if no source provides one
  /// (same truthiness rules as the required boolean overload).
  public func read(_ key: OptionalConfigKey<Bool>) -> Bool? {
    resolvedBool(key)
  }

  /// Reads an optional value parsed from a source string with `transform`.
  ///
  /// Sources are consulted in ``sourcePriority`` order; the first source whose
  /// string value parses to a non-`nil` result wins. If a higher-precedence
  /// source provides a string that fails to parse, resolution falls through to
  /// the next source.
  public func read<T>(_ key: OptionalConfigKey<T>, parsing transform: (String) -> T?) -> T? {
    for source in sourcePriority {
      guard let keyString = key.key(for: source) else { continue }
      guard
        let value = string(
          forKey: makeConfigKey(keyString), isSecret: key.isSecret, fileID: #fileID, line: #line
        )
      else { continue }
      if let parsed = transform(value) {
        return parsed
      }
    }
    return nil
  }

  /// Reads an optional ISO8601 date value, or `nil` if no source provides a
  /// parseable date.
  ///
  /// Equivalent to `read(_:parsing:)` with an ``ISO8601DateFormatter``. For
  /// other formats, call `read(_:parsing:)` with a custom parser.
  public func read(_ key: OptionalConfigKey<Date>) -> Date? {
    read(key, parsing: { ISO8601DateFormatter().date(from: $0) })
  }

  // MARK: - Source-precedence resolution

  /// Returns the first non-`nil` value produced by `lookup` across the sources
  /// in ``sourcePriority`` order, forwarding the key's secrecy to the reader.
  private func resolved<T>(
    _ key: any ConfigurationKey,
    _ lookup: (Key, Bool) -> T?
  ) -> T? {
    for source in sourcePriority {
      guard let keyString = key.key(for: source) else { continue }
      if let value = lookup(makeConfigKey(keyString), key.isSecret) {
        return value
      }
    }
    return nil
  }

  private func resolvedString(_ key: any ConfigurationKey) -> String? {
    resolved(key) { string(forKey: $0, isSecret: $1, fileID: #fileID, line: #line) }
  }

  private func resolvedInt(_ key: any ConfigurationKey) -> Int? {
    resolved(key) { int(forKey: $0, isSecret: $1, fileID: #fileID, line: #line) }
  }

  private func resolvedDouble(_ key: any ConfigurationKey) -> Double? {
    resolved(key) { double(forKey: $0, isSecret: $1, fileID: #fileID, line: #line) }
  }

  private func resolvedBool(_ key: any ConfigurationKey) -> Bool? {
    resolved(key) { bool(forKey: $0, isSecret: $1, fileID: #fileID, line: #line) }
  }
}

// swiftlint:enable discouraged_optional_boolean
