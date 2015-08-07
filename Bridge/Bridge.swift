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
