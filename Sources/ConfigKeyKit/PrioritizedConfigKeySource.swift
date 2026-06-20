//
//  PrioritizedConfigKeySource.swift
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

/// A `CaseIterable` whose cases carry a precedence order, highest first.
///
/// Conformers expose ``priority`` as the authoritative ordering for resolution,
/// decoupling precedence from the order in which `case`s happen to be declared.
public protocol PrioritizedConfigKeySource: CaseIterable {
  /// The cases in precedence order, highest priority first.
  static var priority: [Self] { get }
}

extension PrioritizedConfigKeySource {
  /// Defaults to declaration order (`Array(allCases)`).
  ///
  /// Conformers that want precedence to be independent of `case` declaration
  /// order should override this with an explicit array.
  public static var priority: [Self] { Array(allCases) }
}
