//
//  SecretRecordingReader.swift
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

/// A ``ConfigValueReading`` that records the `isSecret` flag it was passed for
/// each resolved key, so tests can assert that a key's secrecy is forwarded to
/// the underlying reader. Backed by a reference type so reads (which are
/// non-mutating) can capture state.
internal final class SecretRecordingReader: ConfigValueReading {
  /// The `isSecret` value most recently observed for each per-source key string.
  internal private(set) var capturedSecrets: [String: Bool] = [:]

  internal func makeConfigKey(_ string: String) -> String { string }

  internal func string(
    forKey key: String, isSecret: Bool, fileID _: String, line _: UInt
  ) -> String? {
    capturedSecrets[key] = isSecret
    return nil
  }

  internal func int(
    forKey key: String, isSecret: Bool, fileID _: String, line _: UInt
  ) -> Int? {
    capturedSecrets[key] = isSecret
    return nil
  }

  internal func double(
    forKey key: String, isSecret: Bool, fileID _: String, line _: UInt
  ) -> Double? {
    capturedSecrets[key] = isSecret
    return nil
  }
}
