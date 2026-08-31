//
//  ConfigValueReading+Bool.swift
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

internal import Foundation

// swiftlint:disable discouraged_optional_boolean
extension ConfigValueReading {
  /// Parses a boolean from the reader's string value.
  ///
  /// `true` / `1` / `yes` and `false` / `0` / `no` are recognized, case-insensitively.
  /// Anything else — including an empty value — yields `nil`, so resolution falls through
  /// to the next source and ultimately to the key's default. An unrecognized value must
  /// not be treated as `false`: a typo would then silently *disable* a flag rather than
  /// being ignored.
  public func bool(
    forKey key: Key,
    isSecret: Bool,
    fileID: String,
    line: UInt
  ) -> Bool? {
    guard
      let value = string(forKey: key, isSecret: isSecret, fileID: fileID, line: line)
    else {
      return nil
    }
    switch value.lowercased().trimmingCharacters(in: .whitespaces) {
    case "true", "1", "yes":
      return true
    case "false", "0", "no":
      return false
    default:
      return nil
    }
  }
}
// swiftlint:enable discouraged_optional_boolean
