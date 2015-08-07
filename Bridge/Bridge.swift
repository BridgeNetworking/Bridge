//
//  Bridge.swift
//  Rentals
//
//  Created by Justin Huang on 3/19/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import UIKit

public class Bridge {
    public var responseBridges: Array<ResponseBridge> = []
    public var requestBridges: Array<RequestBridge> = []
    public var tasksByTag: NSMapTable = NSMapTable(keyOptions: NSPointerFunctionsOptions.StrongMemory, valueOptions: NSPointerFunctionsOptions.WeakMemory)
    
    // Debug Settings
    var debugMode: Bool = false
    
    public var baseURL: NSURL?
    
    let session: NSURLSession = {
        var sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfig.HTTPAdditionalHeaders = ["Content-Type": "application/json"]
        
        var urlSession = NSURLSession(configuration: sessionConfig)
        return urlSession
    }()
    
    public static let sharedInstance: Bridge = {
        return Bridge()
        }()
    
    public func cancelWithTag(tag: String) {
        let cancelKeys = NSMutableSet()
        let enumerator = self.tasksByTag.keyEnumerator()
        while let key: AnyObject = enumerator.nextObject() {
            if let k = key as? String {
                if (k.hasPrefix(tag)) {
                    cancelKeys.addObject(key)
                }
            }
        }
        
        for key in cancelKeys {
            if let k = key as? String {
                if let task = self.tasksByTag.objectForKey(k) as? NSURLSessionDataTask {
                    task.cancel()
                }
            }
        }
    }
    
    public func enableDebugLogging() {
        self.debugMode = true
    }
    
    public func execute(endpoint: Endpoint) -> NSURLSessionDataTask {
        let dataTask = requestDataTask(endpoint)
        
        if debugMode {
            print("Making request to: \(endpoint.method.rawValue) \(endpoint.requestPath())")
            if let requestParams = endpoint.params {
                print("with parameters: \(requestParams.description)")
            }
        }
        
        dataTask.resume()
        return dataTask
    }
    
    func requestDataTask(endpoint: Endpoint) -> NSURLSessionDataTask {
        let mutableRequest = NSMutableURLRequest(URL: NSURL(string: endpoint.route, relativeToURL: self.baseURL)!)
        mutableRequest.HTTPShouldHandleCookies = false
        mutableRequest.HTTPMethod = endpoint.method.rawValue
        
        let encodingResult: (NSMutableURLRequest, NSError?) = endpoint.encoding.encode(mutableRequest, parameters: endpoint.params)
        
        // If there's an error, just return the data task with a failure
        if let error = encodingResult.1 {
            endpoint.failureBlock?(error: error);
        }
        
        // Get the finished NSMutableURLRequest after parameter encoding
        var request: NSMutableURLRequest = encodingResult.0

        // Process all custom serialization through Bridges
        request = processRequestBridges(endpoint, mutableRequest: request)
        
        var dataTask: NSURLSessionDataTask
        dataTask = Bridge.sharedInstance.session.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, err: NSError?) -> Void in
            if err == nil {
                var responseObject: AnyObject? = endpoint.encoding.serialize(response!, data: data!).0
                if self.processResponseBridges(endpoint, response: response as? NSHTTPURLResponse, responseObject: &responseObject, error: err) {
                    if err != nil {
                        var serializedError = err!
                        if let respDict = responseObject as? Dictionary<String, AnyObject> {
                            // TODO : implement error
//                            serializedError = NSError()
                        }
                        if self.debugMode {
                            print("Request Failed with error: \(serializedError)")
                        }
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            endpoint.failureBlock?(error: serializedError)
                        })
                        
                    } else {
                        if self.debugMode {
                            print("Request Completed with response: \(response!)")
                            print("\(responseObject!)")
                        }
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            endpoint.successBlock?(response: responseObject)
                        })
                    }
                }
            }
        })
        
        // Set task object to be tracked if a non nil tag is provided
        if let tag = endpoint.tag {
           self.tasksByTag.setObject(dataTask, forKey: "\(tag)-\(dataTask.taskIdentifier)")
        }
    
        return dataTask
    }
    
    func attemptCustomResponseBridges(endpoint: Endpoint, response: NSHTTPURLResponse?, inout responseObject: AnyObject?) -> Bool {
        if endpoint.responseBridge != nil {
            if (endpoint.responseBridge?(endpoint: endpoint, response: response, responseObject: &responseObject) != nil) {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    func processResponseBridges(endpoint: Endpoint, response: NSHTTPURLResponse?, inout responseObject: AnyObject?, error: NSError?) -> Bool {
        var continueResponseHandling: Bool
        
        if let err = error {
            if (err.domain == NSURLErrorDomain && err.code != NSURLErrorCancelled) {
                // request was cancelled so don't try process any Bridges
                return true
            }
        }
        
        for Bridge in self.responseBridges {
            continueResponseHandling = Bridge.process(endpoint, response: response, responseObject: &responseObject)
            if !continueResponseHandling {
                return false
            }
        }
        
        // Finally check and execute custom endpoint Bridges if any are attached
        return attemptCustomResponseBridges(endpoint, response: response, responseObject: &responseObject)
    }
    
    func processRequestBridges(endpoint: Endpoint, mutableRequest: NSMutableURLRequest) -> NSMutableURLRequest {
        var processedRequest: NSMutableURLRequest = mutableRequest.mutableCopy() as! NSMutableURLRequest
        for Bridge in self.requestBridges {
            Bridge.process(endpoint, mutableRequest: &processedRequest)
        }
        return processedRequest
    }
}
//
///// Alamofire, refactor as needed
/////************************************************************************************
//
//public enum ParameterEncoding {
//    /**
//    Uses `NSJSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.
//    */
//    case JSON
//    
//    /**
//    Creates a URL request by encoding parameters and applying them onto an existing request.
//    
//    :param: URLRequest The request to have parameters applied
//    :param: parameters The parameters to apply
//    :returns: A tuple containing the constructed request and the error that occurred during parameter encoding, if any.
//    */
//    public func encode(mutableURLRequest: NSMutableURLRequest, parameters: [String: AnyObject]?) -> (NSMutableURLRequest, NSError?) {
//        if parameters == nil {
//            return (mutableURLRequest, nil)
//        }
//        
//        var error: NSError? = nil
//        
//        switch self {
//        case .JSON:
//            // HTTP Verbs to encode parmeters in URL instead of header body
//            func encodesParametersInURL(method: HTTPMethod) -> Bool {
//                switch method {
//                case .GET, .DELETE:
//                    return true
//                case .POST, .PUT:
//                    return false
//                }
//            }
//
//            let method = HTTPMethod(rawValue: mutableURLRequest.HTTPMethod)
//            if method != nil && encodesParametersInURL(method!) {
//                if let URLComponents = NSURLComponents(URL: mutableURLRequest.URL!, resolvingAgainstBaseURL: false) {
//                    URLComponents.percentEncodedQuery = (URLComponents.percentEncodedQuery != nil ? URLComponents.percentEncodedQuery! + "&" : "") + query(parameters!)
//                    mutableURLRequest.URL = URLComponents.URL
//                }
//            } else {
//                let options = NSJSONWritingOptions.allZeros
//                if let data = NSJSONSerialization.dataWithJSONObject(parameters!, options: options, error: &error) {
//                    mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//                    mutableURLRequest.HTTPBody = data
//                }
//            }
//        }
//        
//        return (mutableURLRequest, error)
//    }
//    
//    func queryComponents(key: String, _ value: AnyObject) -> [(String, String)] {
//        var components: [(String, String)] = []
//        if let dictionary = value as? [String: AnyObject] {
//            for (nestedKey, value) in dictionary {
//                components += queryComponents("\(key)[\(nestedKey)]", value)
//            }
//        } else if let array = value as? [AnyObject] {
//            for value in array {
//                components += queryComponents("\(key)[]", value)
//            }
//        } else {
//            components.extend([(escape(key), escape("\(value)"))])
//        }
//        
//        return components
//    }
//    
//    func query(parameters: [String: AnyObject]) -> String {
//        var components: [(String, String)] = []
//        for key in sorted(Array(parameters.keys), <) {
//            let value: AnyObject! = parameters[key]
//            components += queryComponents(key, value)
//        }
//        
//        return join("&", components.map{"\($0)=\($1)"} as [String])
//    }
//    
//    func escape(string: String) -> String {
//        let legalURLCharactersToBeEscaped: CFStringRef = ":/?&=;+!@#$()',*"
//        var nsTypeString = CFURLCreateStringByAddingPercentEscapes(nil, string, nil, legalURLCharactersToBeEscaped, CFStringBuiltInEncodings.UTF8.rawValue) as NSString
//        var swiftString: String = nsTypeString as String
//        return swiftString
//    }
//}

public class GET: Endpoint {
    public init(_ route: String) {
        super.init(route, method: .GET, client: Bridge.sharedInstance)
    }
    
    required public init(_ route: String, method verb: HTTPMethod, client: Bridge) {
        super.init(route, method: .GET, client: Bridge.sharedInstance)
    }
}

public class POST: Endpoint {
    public init(_ route: String) {
        super.init(route, method: .POST, client: Bridge.sharedInstance)
    }
    
    required public init(_ route: String, method verb: HTTPMethod, client: Bridge) {
        super.init(route, method: .POST, client: Bridge.sharedInstance)
    }
}

public class PUT: Endpoint {
    public init(_ route: String) {
        super.init(route, method: .PUT, client: Bridge.sharedInstance)
    }
    
    required public init(_ route: String, method verb: HTTPMethod, client: Bridge) {
        super.init(route, method: .PUT, client: Bridge.sharedInstance)
    }
}

public class DELETE: Endpoint {
    public init(_ route: String) {
        super.init(route, method: .DELETE, client: Bridge.sharedInstance)
    }
    
    required public init(_ route: String, method verb: HTTPMethod, client: Bridge) {
        super.init(route, method: .DELETE, client: Bridge.sharedInstance)
    }
}


// MARK - Bridges

public typealias EndpointIdentifier = String

/**
*  Conform to the `RequestBridge` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol RequestBridge {
     func process(endpoint: Endpoint, inout mutableRequest: NSMutableURLRequest)
}

/**
*  Conform to the `ResponseBridge` protocol to work with data after
*  the request is returned with a response. `responseObject` is a pointer
*  to the resposne object that your endpoint has responded with and can
*  be modified or replaced.
*/
public protocol ResponseBridge {
    func process(endpoint: Endpoint, response: NSHTTPURLResponse?, inout responseObject: AnyObject?) -> Bool
}
