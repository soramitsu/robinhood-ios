/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class EndpointBuilderTests: XCTestCase {
    func testQueryParams() {
        // given
        let offset = 10
        let count = 10
        let template = "https://feed.test-1.sora.soramitsu.co.jp/feed?offset={offset}&count={count}"
        let enpointBuilder = EndpointBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildURL(with: Pagination(offset: offset, count: count))

            let expectedUrl = URL(string: "https://feed.test-1.sora.soramitsu.co.jp/feed?offset=\(offset)&count=\(count)")

            XCTAssertEqual(url, expectedUrl)

            let regex = try enpointBuilder.buildRegex()
            let expectedRegex = "https://feed\\.test-1\\.sora\\.soramitsu\\.co\\.jp/feed\\?offset=\(EndpointBuilder.regexReplacement)&count=\(EndpointBuilder.regexReplacement)"
            XCTAssertEqual(regex, expectedRegex)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testPathWithQueryParams() {
        // given
        let template = "https://feed.test-1.sora.soramitsu.co.jp/feed/{id}/like?{likesCount}"
        let enpointBuilder = EndpointBuilder(urlTemplate: template)

        do {
            let feed = createRandomFeed(in: .default)
            let url = try enpointBuilder.buildURL(with: feed)

            let expectedUrl = URL(string: "https://feed.test-1.sora.soramitsu.co.jp/feed/\(feed.identifier)/like?\(feed.likesCount)")

            XCTAssertEqual(url, expectedUrl)

            let regex = try enpointBuilder.buildRegex()
            let expectedRegex = "https://feed\\.test-1\\.sora\\.soramitsu\\.co\\.jp/feed/\(EndpointBuilder.regexReplacement)/like\\?\(EndpointBuilder.regexReplacement)"
            XCTAssertEqual(regex, expectedRegex)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testSingleParameter() {
        // given
        let code = "123213"
        let template = "https://feed.test-1.sora.soramitsu.co.jp/feed/{invitationCode}"
        let enpointBuilder = EndpointBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildParameterURL(code)
            let expectedUrl = URL(string: "https://feed.test-1.sora.soramitsu.co.jp/feed/\(code)")

            XCTAssertEqual(url, expectedUrl)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testUrlEncodingForSingleParameterWithFragmentSymbol() {
        // given
        let asset = "xor#sora"
        let template = "https://feed.test-1.sora.soramitsu.co.jp/transfer?asset={asset}"
        let endpointBuilder = EndpointBuilder(urlTemplate: template).withUrlEncoding(allowedCharset: .alphanumerics)

        do {
            let url = try endpointBuilder.buildParameterURL(asset)
            let expectedUrl = URL(string: "https://feed.test-1.sora.soramitsu.co.jp/transfer?asset=xor%23sora")

            XCTAssertEqual(url, expectedUrl)
        } catch {
            XCTFail("Error \(error)")
        }
    }

    func testUrlEncodingForObjectParameterWithFragmentSymbol() {
        // given
        let template = "https://feed.test-1.sora.soramitsu.co.jp/feed?id={id}"
        let enpointBuilder = EndpointBuilder(urlTemplate: template).withUrlEncoding(allowedCharset: .alphanumerics)

        do {
            var feed = createRandomFeed(in: .default)
            feed.identifier = "user#id"
            let url = try enpointBuilder.buildURL(with: feed)

            let expectedUrl = URL(string: "https://feed.test-1.sora.soramitsu.co.jp/feed?id=user%23id")

            XCTAssertEqual(url, expectedUrl)
        } catch {
            XCTFail("Error: \(error)")
        }
    }
}
