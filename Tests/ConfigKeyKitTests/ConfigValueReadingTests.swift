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

  @Test("sourcePriority override: ENV wins over CLI when reversed")
  internal func sourcePriorityOverride() throws {
    let cli = try #require(key.key(for: .commandLine))
    let env = try #require(key.key(for: .environment))
    let reader = MockConfigValueReader(
      strings: [cli: "from-cli", env: "from-env"],
      sourcePriority: [.environment, .commandLine]
    )
    #expect(reader.read(key) == "from-env")
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

  @Test("Required int: CLI wins, ENV fallback, default when absent")
  internal func requiredInt() throws {
    let intKey = ConfigKey("episode-number", envPrefix: "BRIGHTDIGIT", default: -1)
    let cli = try #require(intKey.key(for: .commandLine))
    let env = try #require(intKey.key(for: .environment))
    #expect(MockConfigValueReader(ints: [cli: 1, env: 2]).read(intKey) == 1)
    #expect(MockConfigValueReader(ints: [env: 2]).read(intKey) == 2)
    #expect(MockConfigValueReader().read(intKey) == -1)
  }

  @Test("Optional bool: CLI presence true, ENV truthy, nil when absent")
  internal func optionalBool() throws {
    let boolKey = OptionalConfigKey<Bool>("verbose", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(boolKey.key(for: .commandLine))
    let env = try #require(boolKey.key(for: .environment))
    #expect(MockConfigValueReader(strings: [cli: ""]).read(boolKey) == true)
    #expect(MockConfigValueReader(strings: [env: "yes"]).read(boolKey) == true)
    #expect(MockConfigValueReader(strings: [env: "false"]).read(boolKey) == false)
    #expect(MockConfigValueReader().read(boolKey) == nil)
  }

  @Test("Required bool honors sourcePriority: ENV value wins over CLI flag when reversed")
  internal func boolReversedPriority() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let cli = try #require(boolKey.key(for: .commandLine))
    let env = try #require(boolKey.key(for: .environment))
    // CLI flag present (true) and ENV explicitly "false": precedence decides.
    let forward = MockConfigValueReader(strings: [cli: "", env: "false"])
    #expect(forward.read(boolKey) == true)
    let reversed = MockConfigValueReader(
      strings: [cli: "", env: "false"],
      sourcePriority: [.environment, .commandLine]
    )
    #expect(reversed.read(boolKey) == false)
  }

  @Test("Required bool: empty ENV is treated as absent, default used")
  internal func boolEmptyENVUsesDefault() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    let env = try #require(boolKey.key(for: .environment))
    #expect(MockConfigValueReader(strings: [env: ""]).read(boolKey) == true)
    #expect(MockConfigValueReader(strings: [env: "   "]).read(boolKey) == true)
  }

  @Test("Optional date: falls through to next source when higher precedence fails to parse")
  internal func optionalDateParseFallthrough() throws {
    let dateKey = OptionalConfigKey<Date>("published-at", envPrefix: "BRIGHTDIGIT")
    let iso = "2026-06-17T00:00:00Z"
    let cli = try #require(dateKey.key(for: .commandLine))
    let env = try #require(dateKey.key(for: .environment))
    let reader = MockConfigValueReader(strings: [cli: "not-a-date", env: iso])
    #expect(reader.read(dateKey) == ISO8601DateFormatter().date(from: iso))
  }

  @Test("Optional date: custom parser handles a non-ISO format")
  internal func optionalDateCustomParser() throws {
    let dateKey = OptionalConfigKey<Date>("published-at", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(dateKey.key(for: .commandLine))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let reader = MockConfigValueReader(strings: [cli: "2026-06-17"])
    #expect(
      reader.read(dateKey, parsing: formatter.date(from:)) == formatter.date(from: "2026-06-17"))
  }

  @Test("Generic parse: falls through to next source when transform fails")
  internal func genericParseFallthrough() throws {
    let intKey = OptionalConfigKey<Int>("episode-number", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(intKey.key(for: .commandLine))
    let env = try #require(intKey.key(for: .environment))
    let reader = MockConfigValueReader(strings: [cli: "not-an-int", env: "7"])
    #expect(reader.read(intKey, parsing: { Int($0) }) == 7)
  }

  @Test("Generic parse: parses an arbitrary type (URL)")
  internal func genericParseURL() throws {
    let urlKey = OptionalConfigKey<URL>("endpoint", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(urlKey.key(for: .commandLine))
    let reader = MockConfigValueReader(strings: [cli: "https://example.com"])
    #expect(reader.read(urlKey, parsing: { URL(string: $0) }) == URL(string: "https://example.com"))
    #expect(MockConfigValueReader().read(urlKey, parsing: { URL(string: $0) }) == nil)
  }

  @Test("isSecret is forwarded to the reader")
  internal func isSecretForwarded() throws {
    let secretKey = ConfigKey("api.token", envPrefix: "BRIGHTDIGIT", default: "", isSecret: true)
    let plainKey = ConfigKey("base-url", envPrefix: "BRIGHTDIGIT", default: "")
    let cliSecret = try #require(secretKey.key(for: .commandLine))
    let cliPlain = try #require(plainKey.key(for: .commandLine))
    let reader = SecretRecordingReader()
    _ = reader.read(secretKey)
    _ = reader.read(plainKey)
    #expect(reader.capturedSecrets[cliSecret] == true)
    #expect(reader.capturedSecrets[cliPlain] == false)
  }
}
