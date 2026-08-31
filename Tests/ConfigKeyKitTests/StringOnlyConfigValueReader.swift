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

/// A ``ConfigValueReading`` that supplies **only** strings, so it inherits the protocol's
/// default boolean parsing.
///
/// Exists to pin that default: a reader with no native boolean accessor must still
/// resolve `true`/`1`/`yes` and `false`/`0`/`no`, and must yield `nil` — not `false` —
/// for anything it cannot recognize.
internal struct StringOnlyConfigValueReader: ConfigValueReading {
  internal var strings: [String: String] = [:]
  internal var sourcePriority: [ConfigKeySource] = ConfigKeySource.priority

  internal func makeConfigKey(_ string: String) -> String { string }

  internal func string(
    forKey key: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> String? {
    strings[key]
  }

  internal func int(
    forKey _: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> Int? {
    nil
  }

  internal func double(
    forKey _: String, isSecret _: Bool, fileID _: String, line _: UInt
  ) -> Double? {
    nil
  }
}
