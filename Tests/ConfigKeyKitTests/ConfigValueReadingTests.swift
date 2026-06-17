//
//  ConfigValueReadingTests.swift
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

import Foundation
import Testing

@testable import ConfigKeyKit

/// Dict-backed mock reader, keyed by the exact per-source key strings that
/// `ConfigKey`/`OptionalConfigKey` produce. No configuration framework needed.
private struct MockReader: ConfigValueReading {
  var strings: [String: String] = [:]
  var ints: [String: Int] = [:]
  var doubles: [String: Double] = [:]

  func makeConfigKey(_ string: String) -> String { string }

  func string(forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt) -> String? {
    strings[key]
  }

  func int(forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt) -> Int? {
    ints[key]
  }

  func double(forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt) -> Double? {
    doubles[key]
  }
}

@Suite("ConfigValueReading Tests")
internal struct ConfigValueReadingTests {
  private let key = ConfigKey("base-url", envPrefix: "BRIGHTDIGIT", default: "default-url")
  private var cliKey: String { key.key(for: .commandLine)! }
  private var envKey: String { key.key(for: .environment)! }

  @Test("Required string: CLI wins over ENV")
  internal func requiredStringCLIPrecedence() {
    let reader = MockReader(strings: [cliKey: "from-cli", envKey: "from-env"])
    #expect(reader.read(key) == "from-cli")
  }

  @Test("Required string: ENV used when CLI absent")
  internal func requiredStringENVFallback() {
    let reader = MockReader(strings: [envKey: "from-env"])
    #expect(reader.read(key) == "from-env")
  }

  @Test("Required string: default used when neither source present")
  internal func requiredStringDefault() {
    let reader = MockReader()
    #expect(reader.read(key) == "default-url")
  }

  @Test("Required bool: CLI flag presence is true")
  internal func boolCLIPresence() {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let reader = MockReader(strings: [boolKey.key(for: .commandLine)!: ""])
    #expect(reader.read(boolKey) == true)
  }

  @Test(
    "Required bool: ENV truthy strings",
    arguments: [("true", true), ("1", true), ("YES", true), ("false", false), ("0", false)]
  )
  internal func boolENVParsing(value: String, expected: Bool) {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let reader = MockReader(strings: [boolKey.key(for: .environment)!: value])
    #expect(reader.read(boolKey) == expected)
  }

  @Test("Required bool: default when absent")
  internal func boolDefault() {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    #expect(MockReader().read(boolKey) == true)
  }

  @Test("Optional int: parsed with precedence, nil when absent")
  internal func optionalInt() {
    let intKey = OptionalConfigKey<Int>("episode-number", envPrefix: "BRIGHTDIGIT")
    let reader = MockReader(ints: [intKey.key(for: .commandLine)!: 42])
    #expect(reader.read(intKey) == 42)
    #expect(MockReader().read(intKey) == nil)
  }

  @Test("Optional double: parsed, nil when absent")
  internal func optionalDouble() {
    let doubleKey = OptionalConfigKey<Double>("min-interval", envPrefix: "BRIGHTDIGIT")
    let reader = MockReader(doubles: [doubleKey.key(for: .environment)!: 1.5])
    #expect(reader.read(doubleKey) == 1.5)
    #expect(MockReader().read(doubleKey) == nil)
  }

  @Test("Optional string: nil when absent")
  internal func optionalStringNil() {
    let optKey = OptionalConfigKey<String>("episode-title", envPrefix: "BRIGHTDIGIT")
    #expect(MockReader().read(optKey) == nil)
  }

  @Test("Optional date: ISO8601 parsed from value")
  internal func optionalDate() {
    let dateKey = OptionalConfigKey<Date>("published-at", envPrefix: "BRIGHTDIGIT")
    let iso = "2026-06-17T00:00:00Z"
    let reader = MockReader(strings: [dateKey.key(for: .commandLine)!: iso])
    #expect(reader.read(dateKey) == ISO8601DateFormatter().date(from: iso))
    #expect(MockReader().read(dateKey) == nil)
  }
}
