//
//  Bridge.swift
//  Rentals
//
//  Created by Justin Huang on 3/19/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import UIKit

public class Bridge {
    public var responseInterceptors: Array<ResponseInterceptor> = []
    public var requestInterceptors: Array<RequestInterceptor> = []
    public var tasksByTag: NSMapTable = NSMapTable(keyOptions: NSPointerFunctionsOptions.StrongMemory, valueOptions: NSPointerFunctionsOptions.WeakMemory)
    
    // Debug Settings
    var debugMode: Bool = true
    var acceptableStatusCodes = Set<Int>(200...299)
    
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
    
    func execute<ReturnType>(endpoint: Endpoint<ReturnType>) {
        let mutableRequest = NSMutableURLRequest(URL: NSURL(string: endpoint.route, relativeToURL: self.baseURL)!)
        mutableRequest.HTTPShouldHandleCookies = false
        mutableRequest.HTTPMethod = endpoint.method.rawValue
        
        do {
            var request = try endpoint.encoding.encode(mutableRequest, parameters: endpoint.params)
            
            // Process all custom serialization through Bridges
            request = processRequestInterceptors(endpoint, mutableRequest: &request)
            let dataTask = self.createDataTask(endpoint, request: request)
            
            if self.debugMode {
                print("Making request to: \(endpoint.method.rawValue) \(endpoint.requestPath())")
                if let requestParams = endpoint.params {
                    print("with parameters: \(requestParams.description)")
                }
            }
            
            dataTask.resume()
            
        } catch let error {
            
            // Encoding Error
            let request = mutableRequest.copy() as! NSURLRequest
            endpoint.failureBlock?(error: error as NSError, data: nil, request: request, response: nil)
        }
    }
    
    func createDataTask<ReturnType>(endpoint: Endpoint<ReturnType>, request: NSMutableURLRequest) -> NSURLSessionDataTask {
        var dataTask: NSURLSessionDataTask
        dataTask = Bridge.sharedInstance.session.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, err: NSError?) -> Void in
            do {
                if let error = err {
                    if (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) {
                        throw BridgeErrorType.Cancelled
                    } else {
                        throw error as ErrorType
                    }
                }
                
                let responseObject = try endpoint.encoding.serialize(data!)
                
                if let serializedObject = try self.processResponse(endpoint, responseObject: responseObject, response: response, error: err) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        if self.debugMode {
                            print("Request Completed with response: \(response!)")
                            print("\(serializedObject)")
                            if let returnData = data {
                                if let dataString = endpoint.encoding.serializeToString(returnData) {
                                    print("\(dataString)")
                                }
                            }
                        }
                        
                        endpoint.successBlock?(response: serializedObject)
                    })
                }
            } catch let error {
                
                // handle failure block with serialization error and return
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    if self.debugMode {
                        print("Request Failed with errorType: \(error)")
                        if let returnData = data {
                            if let dataString = endpoint.encoding.serializeToString(returnData) {
                                print("\(dataString)")
                            }
                        }
                    }
                    
                    let request = request.copy() as! NSURLRequest
                    endpoint.failureBlock?(error: error as NSError, data: data, request: request, response: response)
                })
            }
        })
        
        // Set task object to be tracked if a non nil tag is provided
        if let tag = endpoint.tag {
            self.tasksByTag.setObject(dataTask, forKey: "\(tag)-\(dataTask.taskIdentifier)")
        }
        
        return dataTask
    }
    
    func processResponse<ReturnType>(endpoint: Endpoint<ReturnType>, responseObject: ResponseObject, response: NSURLResponse?, error: NSError?) throws -> ReturnType? {
        
        let processResults = self.processResponseInterceptors(endpoint, response: response as? NSHTTPURLResponse, responseObject: responseObject)
        
        // If there was an error from a response bridge, throw the error
        if let errorFromResults = processResults.bridgeError {
            throw errorFromResults
        }
        
        // If we should not continue this particular execution, return nil
        guard processResults.shouldContinue else {
            return nil
        }
        
        // If the HTTP response does not cast as a NSHTTPURLResponse, throw an internal error
        guard let httpResponse = response as? NSHTTPURLResponse else {
            throw BridgeErrorType.Internal
        }
        
        // Check if status code is an acceptable one, or else it's still considered as an error
        guard self.acceptableStatusCodes.contains(httpResponse.statusCode) else {
            throw BridgeErrorType.Server
        }
        
        // Try to return serialized object otherwise.
        let serializedObject = try ReturnType.parseResponseObject(responseObject.rawValue()) as! ReturnType
        return serializedObject
    }
    
    
    func attemptCustomResponseInterceptor<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults {
        if let after = endpoint.responseInterceptor {
            return after(endpoint: endpoint, response: response, responseObject: responseObject)
        } else {
            return ProcessResults(true, nil)
        }
    }
    
    func processResponseInterceptors<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults {
        for Bridge in self.responseInterceptors {
            let processResults = Bridge.process(endpoint, response: response, responseObject: responseObject)
            let shouldContinueProcessing = (processResults.bridgeError != nil || processResults.shouldContinue)
            if !shouldContinueProcessing {
                return processResults
            }
        }
        
        // Finally check and execute custom endpoint Bridges if any are attached
        return attemptCustomResponseInterceptor(endpoint, response: response, responseObject: responseObject)
    }
    
    func processRequestInterceptors<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest) -> NSMutableURLRequest {
        var processedRequest: NSMutableURLRequest = mutableRequest.mutableCopy() as! NSMutableURLRequest
        for Bridge in self.requestInterceptors {
            Bridge.process(endpoint, mutableRequest: &processedRequest)
        }
        return processedRequest
    }
}

// MARK - Bridges

typealias EndpointIdentifier = String

/**
*  Conform to the `RequestInterceptor` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol RequestInterceptor {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest)
}

/**
*  Conform to the `ResponseInterceptor` protocol to work with data after
*  the request is returned with a response. `responseObject` is a pointer
*  to the resposne object that your endpoint has responded with and can
*  be modified or replaced.
*/
public protocol ResponseInterceptor {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults
}

public enum BridgeErrorType: ErrorType {
    case Internal
    case Encoding
    case Serializing
    case Parsing
    case Server
    case Cancelled
}


