/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum NetworkBaseError: Error {
    case invalidUrl
    case badSerialization
    case badDeserialization
    case unexpectedEmptyData
    case unexpectedResponseObject
}

public enum NetworkResponseError: Error {
    case invalidParameters
    case resourceNotFound
    case authorizationError
    case internalServerError
    case unexpectedStatusCode

    static func createFrom(statusCode: Int) -> NetworkResponseError? {
        switch statusCode {
        case 200:
            return nil
        case 400:
            return NetworkResponseError.invalidParameters
        case 401:
            return NetworkResponseError.authorizationError
        case 404:
            return NetworkResponseError.resourceNotFound
        case 500:
            return NetworkResponseError.internalServerError
        default:
            return NetworkResponseError.unexpectedStatusCode
        }
    }
}
