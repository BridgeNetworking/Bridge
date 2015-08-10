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
    var debugMode: Bool = true
    
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
    
    func execute<ReturnType>(endpoint: Endpoint<ReturnType>) -> NSURLSessionDataTask {
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
    
    func requestDataTask<ReturnType>(endpoint: Endpoint<ReturnType>) -> NSURLSessionDataTask {
        var mutableRequest = NSMutableURLRequest(URL: NSURL(string: endpoint.route, relativeToURL: self.baseURL)!)
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
        request = processRequestBridges(endpoint, mutableRequest: &request)
        
        
        var dataTask: NSURLSessionDataTask
        dataTask = Bridge.sharedInstance.session.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, err: NSError?) -> Void in
            if let responseObject = endpoint.encoding.serialize(data!).0 {
                let serializedObject = ReturnType().parseResponseObject(responseObject.rawValue()) as! ReturnType
                if self.processResponseBridges(endpoint, response: response as? NSHTTPURLResponse, responseObject: responseObject, error: err) {
                    if err != nil {
                        if self.debugMode {
                            print("Request Failed with error: \(err)")
                        }
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            endpoint.failureBlock?(error: err)
                        })
                    } else {
                        if self.debugMode {
                            print("Request Completed with response: \(response!)")
                            print("\(serializedObject)")
                        }
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            endpoint.successBlock?(response: serializedObject)
                        })
                    }
                }
                return
            }
            
        })
        
        // Set task object to be tracked if a non nil tag is provided
        if let tag = endpoint.tag {
            self.tasksByTag.setObject(dataTask, forKey: "\(tag)-\(dataTask.taskIdentifier)")
        }
        
        return dataTask
    }
    
    
    func attemptCustomResponseBridges<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> Bool {
        if endpoint.responseBridge != nil {
            if (endpoint.responseBridge?(endpoint: endpoint, response: response, responseObject: responseObject) != nil) {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    func processResponseBridges<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject, error: NSError?) -> Bool {
        var continueResponseHandling: Bool
        
        if let err = error {
            if (err.domain == NSURLErrorDomain && err.code != NSURLErrorCancelled) {
                // request was cancelled so don't try process any Bridges
                return true
            }
        }
        
        for Bridge in self.responseBridges {
            continueResponseHandling = Bridge.process(endpoint, response: response, responseObject: responseObject)
            if !continueResponseHandling {
                return false
            }
        }
        
        // Finally check and execute custom endpoint Bridges if any are attached
        return attemptCustomResponseBridges(endpoint, response: response, responseObject: responseObject)
    }
    
    func processRequestBridges<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest) -> NSMutableURLRequest {
        var processedRequest: NSMutableURLRequest = mutableRequest.mutableCopy() as! NSMutableURLRequest
        for Bridge in self.requestBridges {
            Bridge.process(endpoint, mutableRequest: &processedRequest)
        }
        return processedRequest
    }
}



// MARK - Bridges

typealias EndpointIdentifier = String

/**
*  Conform to the `RequestBridge` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol RequestBridge {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest)
}

/**
*  Conform to the `ResponseBridge` protocol to work with data after
*  the request is returned with a response. `responseObject` is a pointer
*  to the resposne object that your endpoint has responded with and can
*  be modified or replaced.
*/
public protocol ResponseBridge {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> Bool
}


