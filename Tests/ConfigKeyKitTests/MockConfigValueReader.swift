//
//  MockConfigValueReader.swift
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

@testable import ConfigKeyKit

/// Dict-backed ``ConfigValueReading`` keyed by the exact per-source key strings
/// that `ConfigKey` / `OptionalConfigKey` produce, so the shared `read(_:)`
/// resolution can be exercised without any configuration framework.
internal struct MockConfigValueReader: ConfigValueReading {
  internal var strings: [String: String] = [:]
  internal var ints: [String: Int] = [:]
  internal var doubles: [String: Double] = [:]

  internal func makeConfigKey(_ string: String) -> String { string }

  internal func string(
    forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> String? {
    strings[key]
  }

  internal func int(
    forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> Int? {
    ints[key]
  }

  internal func double(
    forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> Double? {
    doubles[key]
  }
}
