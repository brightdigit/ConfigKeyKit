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

@Suite("ConfigValueReading Tests")
internal struct ConfigValueReadingTests {
  private let key = ConfigKey("base-url", envPrefix: "BRIGHTDIGIT", default: "default-url")

  @Test("Required string: CLI wins over ENV")
  internal func requiredStringCLIPrecedence() throws {
    let cli = try #require(key.key(for: .commandLine))
    let env = try #require(key.key(for: .environment))
    let reader = MockConfigValueReader(strings: [cli: "from-cli", env: "from-env"])
    #expect(reader.read(key) == "from-cli")
  }

  @Test("Required string: ENV used when CLI absent")
  internal func requiredStringENVFallback() throws {
    let env = try #require(key.key(for: .environment))
    let reader = MockConfigValueReader(strings: [env: "from-env"])
    #expect(reader.read(key) == "from-env")
  }

  @Test("Required string: default used when neither source present")
  internal func requiredStringDefault() {
    #expect(MockConfigValueReader().read(key) == "default-url")
  }

  @Test("Required bool: CLI flag presence is true")
  internal func boolCLIPresence() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let cli = try #require(boolKey.key(for: .commandLine))
    let reader = MockConfigValueReader(strings: [cli: ""])
    #expect(reader.read(boolKey) == true)
  }

  @Test(
    "Required bool: ENV truthy strings",
    arguments: [("true", true), ("1", true), ("YES", true), ("false", false), ("0", false)]
  )
  internal func boolENVParsing(value: String, expected: Bool) throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let env = try #require(boolKey.key(for: .environment))
    let reader = MockConfigValueReader(strings: [env: value])
    #expect(reader.read(boolKey) == expected)
  }

  @Test("Required bool: default when absent")
  internal func boolDefault() {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    #expect(MockConfigValueReader().read(boolKey) == true)
  }

  @Test("Optional int: parsed with precedence, nil when absent")
  internal func optionalInt() throws {
    let intKey = OptionalConfigKey<Int>("episode-number", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(intKey.key(for: .commandLine))
    let reader = MockConfigValueReader(ints: [cli: 42])
    #expect(reader.read(intKey) == 42)
    #expect(MockConfigValueReader().read(intKey) == nil)
  }

  @Test("Optional double: parsed, nil when absent")
  internal func optionalDouble() throws {
    let doubleKey = OptionalConfigKey<Double>("min-interval", envPrefix: "BRIGHTDIGIT")
    let env = try #require(doubleKey.key(for: .environment))
    let reader = MockConfigValueReader(doubles: [env: 1.5])
    #expect(reader.read(doubleKey) == 1.5)
    #expect(MockConfigValueReader().read(doubleKey) == nil)
  }

  @Test("Optional string: nil when absent")
  internal func optionalStringNil() {
    let optKey = OptionalConfigKey<String>("episode-title", envPrefix: "BRIGHTDIGIT")
    #expect(MockConfigValueReader().read(optKey) == nil)
  }

  @Test("Optional date: ISO8601 parsed from value")
  internal func optionalDate() throws {
    let dateKey = OptionalConfigKey<Date>("published-at", envPrefix: "BRIGHTDIGIT")
    let iso = "2026-06-17T00:00:00Z"
    let cli = try #require(dateKey.key(for: .commandLine))
    let reader = MockConfigValueReader(strings: [cli: iso])
    #expect(reader.read(dateKey) == ISO8601DateFormatter().date(from: iso))
    #expect(MockConfigValueReader().read(dateKey) == nil)
  }
}
