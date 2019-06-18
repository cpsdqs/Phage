//
//  PhageCoreTests.swift
//  PhageCoreTests
//
//  Created by cpsdqs on 2019-06-17.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import XCTest
@testable import PhageCore

class PhageCoreTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCSSParsing() {
        let a = """
hello { world { @document { this should be ignored } } }

@document {
    this should not be ignored
}
#test {}
@-moz-document url(http://example.com) {
    neither should this
}
@document url-prefix("test\\""), url('a') {
    nor this
}
"""
        let ar = parseCSSFileSections(a)
        XCTAssertEqual(ar[0].rules.count, 0)
        XCTAssertEqual(ar[0].contents.trimmingCharacters(in: .whitespacesAndNewlines), "this should not be ignored")
        XCTAssertEqual(ar[1].rules.count, 1)
        XCTAssertEqual(ar[1].rules[0], .exact("http://example.com"))
        XCTAssertEqual(ar[1].contents.trimmingCharacters(in: .whitespacesAndNewlines), "neither should this")
        XCTAssertEqual(ar[2].rules.count, 2)
        XCTAssertEqual(ar[2].rules[0], .prefix("test\""))
        XCTAssertEqual(ar[2].rules[1], .exact("a"))
        XCTAssertEqual(ar[2].contents.trimmingCharacters(in: .whitespacesAndNewlines), "nor this")
    }

}
