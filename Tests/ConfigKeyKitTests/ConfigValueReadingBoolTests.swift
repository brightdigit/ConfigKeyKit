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

import Testing

@testable import ConfigKeyKit

/// Boolean resolution across sources.
///
/// Split from the main suite because booleans are the one type whose resolution differs
/// per reader: one with a native boolean accessor (``MockConfigValueReader``, as
/// `ConfigReader` is) sees a valueless command-line flag, while one supplying only
/// strings (``StringOnlyConfigValueReader``) falls back to the protocol's parsing.
@Suite("ConfigValueReading: booleans")
internal struct ConfigValueReadingBoolTests {
  @Test("Required bool: CLI flag presence is true")
  internal func boolCLIPresence() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let cli = try #require(boolKey.key(for: .commandLine))
    let reader = MockConfigValueReader(bools: [cli: true])
    #expect(reader.read(boolKey) == true)
  }

  @Test("Required bool: an explicit CLI false is honored, not overridden by presence")
  internal func boolCLIExplicitFalse() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    let cli = try #require(boolKey.key(for: .commandLine))
    #expect(MockConfigValueReader(bools: [cli: false]).read(boolKey) == false)
  }

  @Test(
    "Required bool: ENV truthy strings, via the string-parsing default",
    arguments: [
      ("true", true), ("1", true), ("YES", true), ("yes", true),
      ("false", false), ("0", false), ("no", false), ("NO", false),
    ]
  )
  internal func boolENVParsing(value: String, expected: Bool) throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let env = try #require(boolKey.key(for: .environment))
    let reader = StringOnlyConfigValueReader(strings: [env: value])
    #expect(reader.read(boolKey) == expected)
  }

  @Test(
    "Required bool: an unrecognized value is ignored, never coerced to false",
    arguments: ["banana", "on", "off", "ture", "2"]
  )
  internal func boolUnrecognizedFallsThrough(value: String) throws {
    // Regression: these used to resolve as `false`, so a typo silently *disabled* a
    // flag whose default was `true` instead of being ignored.
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    let env = try #require(boolKey.key(for: .environment))
    #expect(StringOnlyConfigValueReader(strings: [env: value]).read(boolKey) == true)

    let optionalKey = OptionalConfigKey<Bool>("verbose", envPrefix: "BRIGHTDIGIT")
    let optionalEnv = try #require(optionalKey.key(for: .environment))
    #expect(StringOnlyConfigValueReader(strings: [optionalEnv: value]).read(optionalKey) == nil)
  }

  @Test("Required bool: default when absent")
  internal func boolDefault() {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    #expect(MockConfigValueReader().read(boolKey) == true)
  }

  @Test("Optional bool: CLI presence true, ENV truthy, nil when absent")
  internal func optionalBool() throws {
    let boolKey = OptionalConfigKey<Bool>("verbose", envPrefix: "BRIGHTDIGIT")
    let cli = try #require(boolKey.key(for: .commandLine))
    let env = try #require(boolKey.key(for: .environment))
    #expect(MockConfigValueReader(bools: [cli: true]).read(boolKey) == true)
    #expect(StringOnlyConfigValueReader(strings: [env: "yes"]).read(boolKey) == true)
    #expect(StringOnlyConfigValueReader(strings: [env: "false"]).read(boolKey) == false)
    #expect(MockConfigValueReader().read(boolKey) == nil)
  }

  @Test("Required bool honors sourcePriority: ENV value wins over CLI flag when reversed")
  internal func boolReversedPriority() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: false)
    let cli = try #require(boolKey.key(for: .commandLine))
    let env = try #require(boolKey.key(for: .environment))
    // CLI flag present (true) and ENV explicitly "false": precedence decides.
    let forward = MockConfigValueReader(bools: [cli: true, env: false])
    #expect(forward.read(boolKey) == true)
    let reversed = MockConfigValueReader(
      bools: [cli: true, env: false],
      sourcePriority: [.environment, .commandLine]
    )
    #expect(reversed.read(boolKey) == false)
  }

  @Test("Required bool: empty ENV is treated as absent, default used")
  internal func boolEmptyENVUsesDefault() throws {
    let boolKey = ConfigKey("verbose", envPrefix: "BRIGHTDIGIT", default: true)
    let env = try #require(boolKey.key(for: .environment))
    #expect(StringOnlyConfigValueReader(strings: [env: ""]).read(boolKey) == true)
    #expect(StringOnlyConfigValueReader(strings: [env: "   "]).read(boolKey) == true)
  }
}
