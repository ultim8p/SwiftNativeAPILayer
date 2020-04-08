//
//  APIExample.swift
//  CracksJournal
//
//  Created by Guerson on 2020-04-08.
//  Copyright © 2020 Guerson. All rights reserved.
//

import Foundation


/// API Class encharged of executing all api requests.
/// - parameter rest: Response type, this is the class that the response should be converted to. Ex: User.self. The class should conform to Codable protocol.
/// - parameter url: Request url.
/// - parameter params: The body of the request. The class should conform to Codable protocol.
/// - parameter method: POST, PUT, DELETE, GET, etc...
/// - parameter handler: Function called after the request completes the DataTask.
/// There are many advantages on having a single API request method and controlling what happens on this method. Ex: We can add authentication headers or parameters that all requests need without having lots of duplicated call on each API call.
class APIRequest {
    func performRequest<R: Codable, P: Codable>(rest: R.Type, url: String, parms: P?, heads: [String: String]?, method: RIRequestMethod, handler: APIResponse<R>.RIRequestHandler?) -> URLSessionDataTask {
        
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let requestUrl: URL = URL.init(string: encodedUrl!)!
        var request: URLRequest = URLRequest.init(url: requestUrl)
        request.httpMethod = method.rawValue
        
        if let heads = heads {
            for (key, value) in heads {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Accept-Encoding", forHTTPHeaderField: "gzip")
        
        if let parms = parms {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .mongoStrategy
            if let jsonBody = try? encoder.encode(parms) {
                request.httpBody = jsonBody
            } else {
                let error = NSError(domain: "com.rise.risefit", code: 0, userInfo: [NSLocalizedDescriptionKey: "ERR: RIRequest Unable to parse params to JSON"])
                var resObj: RIResp<R> = RIResp()
                resObj.error = error
                handler?(resObj)
            }
        }
        
        
        let configurarion = URLSessionConfiguration.default
        let session = URLSession(configuration: configurarion, delegate: nil, delegateQueue: nil)
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                var resObj: RIResp<R> = RIResp()
                let isSuccess = response?.isSuccess() ?? false
                resObj.setFor(status: response?.statusCode() ?? 0)
                
                if let data = data {
                    let decoder = JSONDecoder()
                    do {
                        /// If res is succes parse success response object
                        if isSuccess {
                            let obj = try decoder.decode(rest, from: data)
                            resObj.data = obj
                        }
                            /// If not success try to parse an errorObject
                        else {
                            let errObj = try decoder.decode(RFApiError.self, from: data)
                            resObj.apiErr = errObj
                            print("RIReq: Assigning api error Url: \(url)")
                            errObj.printObj()
                        }
                    } catch {
                        print("RIReqErr: Error parsing res \(error)")
                        resObj.error = error
                    }
                    handler?(resObj)
                } else if let error = error {
                    resObj.error = error
                    handler?(resObj)
                } else {
                    let unknownError = NSError(domain: "api.request.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "ERR: RIRequest DataTask Unknown error"])
                    resObj.error = unknownError
                    handler?(resObj)
                }
            }
        }
        task.resume()
        
        return task
        
    }
}


/// Object returned for a network request.
/// data is the object returned by the API in case of a successfull response.
/// in case of an error, the error parameter will contain the API error.
struct APIResponse<T: Codable> {
    
    typealias RIRequestHandler = (_ response: RIResp<T>) -> Void
    
    var data: T?
    var error: Error?
    
}


/// Model Protocol. All model objects must conform to this protocol.
/// This example requires an id field but we can add all fields we require on out model layer. This is very helpful to extend the Model class and add functionality to all of our objects.
protocol Model: Codable {
    var id: String? { get set}
}

/// Example of Model protocol extension. This function checks wheater two model objects are equal by comparing their id parameter.
extension Model {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard let lhsId = lhs.id, let rhsId = rhs.id else { return false }
        return lhsId == rhsId
    }
}



/// Example of a User model in our project.
/// Note: This is all the implementation we need in order to convert to JSON data, by extending Model: Codable protocol we inherit the ability to convert to JSON object.
/// Node: We can add nested models really easy as long as the objects conform to Codable as well.
struct User: Model {
    var id: String?
    var name: String?
    
    var friends: [User]?
    
    var userType: UserType?
}

enum UserType: String, Codable {
    case free
    case premium
}
