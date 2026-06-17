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

  /// Builds a native ``Key`` from a resolved per-source key string.
  func makeConfigKey(_ string: String) -> Key

  /// Reads a string value for the native key, or `nil` if absent.
  func string(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> String?

  /// Reads an integer value for the native key, or `nil` if absent.
  func int(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> Int?

  /// Reads a double value for the native key, or `nil` if absent.
  func double(forKey key: Key, isSecret: Bool, fileID: String, line: UInt) -> Double?
}

extension ConfigValueReading {
  /// Reads a required string value: CLI → ENV → the key's default.
  public func read(_ key: ConfigKey<String>) -> String {
    resolvedString(key) ?? key.defaultValue
  }

  /// Reads a required double value: CLI → ENV → the key's default.
  public func read(_ key: ConfigKey<Double>) -> Double {
    resolvedDouble(key) ?? key.defaultValue
  }

  /// Reads a required boolean value.
  ///
  /// - CLI: flag presence indicates `true` (e.g. `--verbose`).
  /// - ENV: accepts `true` / `1` / `yes` (case-insensitive); empty is absent.
  /// - Otherwise the key's default.
  public func read(_ key: ConfigKey<Bool>) -> Bool {
    if let cli = key.key(for: .commandLine),
      string(forKey: makeConfigKey(cli), isSecret: false, fileID: #fileID, line: #line) != nil
    {
      return true
    }
    if let env = key.key(for: .environment),
      let value = string(
        forKey: makeConfigKey(env), isSecret: false, fileID: #fileID, line: #line
      )
    {
      let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
      return normalized == "true" || normalized == "1" || normalized == "yes"
    }
    return key.defaultValue
  }

  /// Reads an optional string value: CLI → ENV → `nil`.
  public func read(_ key: OptionalConfigKey<String>) -> String? {
    resolvedString(key)
  }

  /// Reads an optional integer value: CLI → ENV → `nil`.
  public func read(_ key: OptionalConfigKey<Int>) -> Int? {
    resolvedInt(key)
  }

  /// Reads an optional double value: CLI → ENV → `nil`.
  public func read(_ key: OptionalConfigKey<Double>) -> Double? {
    resolvedDouble(key)
  }

  /// Reads an optional ISO8601 date value: CLI → ENV → `nil`.
  public func read(_ key: OptionalConfigKey<Date>) -> Date? {
    guard let value = resolvedString(key) else {
      return nil
    }
    return ISO8601DateFormatter().date(from: value)
  }

  // MARK: - Source-precedence resolution

  private func resolvedString(_ key: any ConfigurationKey) -> String? {
    for source in ConfigKeySource.allCases {
      guard let keyString = key.key(for: source) else { continue }
      if let value = string(
        forKey: makeConfigKey(keyString), isSecret: false, fileID: #fileID, line: #line
      ) {
        return value
      }
    }
    return nil
  }

  private func resolvedInt(_ key: any ConfigurationKey) -> Int? {
    for source in ConfigKeySource.allCases {
      guard let keyString = key.key(for: source) else { continue }
      if let value = int(
        forKey: makeConfigKey(keyString), isSecret: false, fileID: #fileID, line: #line
      ) {
        return value
      }
    }
    return nil
  }

  private func resolvedDouble(_ key: any ConfigurationKey) -> Double? {
    for source in ConfigKeySource.allCases {
      guard let keyString = key.key(for: source) else { continue }
      if let value = double(
        forKey: makeConfigKey(keyString), isSecret: false, fileID: #fileID, line: #line
      ) {
        return value
      }
    }
    return nil
  }
}
