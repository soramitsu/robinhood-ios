/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum HttpMethod: String {
    case get
    case post
    case put
    case delete
}

public enum HttpContentType: String {
    case json = "application/json"
}

public enum HttpHeaderKey: String {
    case contentType = "Content-Type"
    case authorization = "Authorization"
}
