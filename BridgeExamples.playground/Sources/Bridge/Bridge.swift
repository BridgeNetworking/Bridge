//
//  Bridge.swift
//  Rentals
//
//  Created by Justin Huang on 3/19/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import Foundation

public class Bridge: NSObject, URLSessionDelegate {
    public var responseInterceptors: Array<ResponseInterceptor> = []
    public var requestInterceptors: Array<RequestInterceptor> = []
    public var tasksByTag: NSMapTable<NSString, AnyObject> = NSMapTable<NSString, AnyObject>(keyOptions: NSPointerFunctions.Options(), valueOptions: NSPointerFunctions.Options.weakMemory)
    static let tasksLockQueue: DispatchQueue = DispatchQueue(label: "com.Bridge.TasksByTagLockQueue", attributes: [])

    // Debug Settings
    public var isDebugMode: Bool = false
    
    private let acceptableStatusCodes = Set<Int>(200...299)
    public var baseURL: URL?
    
    private lazy var session: URLSession = {
        var sessionConfig: URLSessionConfiguration = .default
        sessionConfig.httpAdditionalHeaders = ["Content-Type": "application/json"]
        
        let urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        return urlSession
        }()
    
    public static let sharedInstance: Bridge = {
        return Bridge()
    }()
    
    public func cancelWithTag(_ tag: String) {
        Bridge.tasksLockQueue.sync {
            let cancelKeys = NSMutableSet()
            let enumerator = self.tasksByTag.keyEnumerator()
            while let key: Any = enumerator.nextObject() {
                if let k = key as? String {
                    
                    // Can cancel batches of calls with the same prefix
                    // i.e. Home:Profile, Home:Stream, Home:Favorites
                    if (k.hasPrefix(tag)) {
                        cancelKeys.add(key)
                    }
                }
            }
            
            for key in cancelKeys {
                if let k = key as? String {
                    if let task = self.tasksByTag.object(forKey: NSString(string: k)) as? URLSessionDataTask {
                        task.cancel()
                    }
                }
            }
        }
    }
    
    internal func execute<ReturnType>(_ endpoint: Endpoint<ReturnType>) {
        let mutableRequest = NSMutableURLRequest(url: URL(string: endpoint.route, relativeTo: self.baseURL!)!)
        mutableRequest.httpShouldHandleCookies = endpoint.acceptsCookies
        mutableRequest.httpMethod = endpoint.method.rawValue
        
        do {
            var request = try endpoint.encoding.encode(mutableRequest, parameters: endpoint.params)
            
            // Process all custom serialization through Bridges
            request = processRequestInterceptors(endpoint, mutableRequest: &request)
            let dataTask = self.createDataTask(endpoint, request: request.copy() as! URLRequest)
            
            if self.isDebugMode {
                print("Making request to: \(endpoint.method.rawValue) \(endpoint.requestPath())")
                if let requestParams = endpoint.params {
                    print("with parameters: \(requestParams.description)")
                }
            }
            
            dataTask.resume()
            
        } catch let error {
            
            // Encoding Error
            let request = mutableRequest.copy() as! URLRequest
            endpoint.failureBlock?(error as NSError, nil, request, nil)
        }
    }
    
    private func createDataTask<ReturnType>(_ endpoint: Endpoint<ReturnType>, request: URLRequest) -> URLSessionDataTask {
        var dataTask: URLSessionDataTask
        dataTask = Bridge.sharedInstance.session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, err: Error?) -> Void in
            do {
                if let error = err as NSError? {
                    if (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) {
                        throw BridgeErrorType.cancelled
                    } else {
                        throw error
                    }
                }
                
                let responseObject = try endpoint.encoding.serialize(data!)
                
                if let serializedObject = try self.processResponse(endpoint, responseObject: responseObject, response: response, error: err as NSError?) {
                    DispatchQueue.main.async(execute: { () -> Void in
                        
                        if self.isDebugMode {
                            print("Request Completed with response: \(response!)")
                            print("\(serializedObject)")
                            if let returnData = data {
                                if let dataString = endpoint.encoding.serializeToString(returnData) {
                                    print("\(dataString)")
                                }
                            }
                        }
                        
                        endpoint.successBlock?(serializedObject)
                    })
                }
            } catch let error {
                
                // handle failure block with serialization error and return
                
                DispatchQueue.main.async(execute: { () -> Void in
                    
                    if self.isDebugMode {
                        print("Request Failed with errorType: \(error)")
                        if let returnData = data {
                            if let dataString = endpoint.encoding.serializeToString(returnData) {
                                print("\(dataString)")
                            }
                        }
                    }
                    
                    endpoint.failureBlock?(error as NSError, data, request, response)
                })
            }
        })
        
        // Set task object to be tracked if a non nil tag is provided
        if let tag = endpoint.tag {
            Bridge.tasksLockQueue.sync {
                let key = NSString(string:"\(tag)-\(dataTask.taskIdentifier)")
                self.tasksByTag.setObject(dataTask, forKey: key)
            }
        }
        
        return dataTask
    }
    
    private func processResponse<ReturnType>(_ endpoint: Endpoint<ReturnType>, responseObject: ResponseObject, response: URLResponse?, error: NSError?) throws -> ReturnType? {
        
        let processResults = self.processResponseInterceptors(endpoint, response: response as? HTTPURLResponse, responseObject: responseObject)
        
        // If there was an error from a response bridge, throw the error
        if let errorFromResults = processResults.bridgeError {
            throw errorFromResults
        }
        
        // If we should not continue this particular execution, return nil
        guard processResults.shouldContinue else {
            return nil
        }
        
        // If the HTTP response does not cast as a NSHTTPURLResponse, throw an internal error
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeErrorType.internal
        }
        
        // Check if status code is an acceptable one, or else it's still considered as an error
        guard self.acceptableStatusCodes.contains(httpResponse.statusCode) else {
            throw BridgeErrorType.server
        }
        
        // Try to return serialized object otherwise.
        let serializedObject = try ReturnType.parseResponseObject(responseObject.rawValue()) as! ReturnType
        return serializedObject
    }
    
    
    private func attemptCustomResponseInterceptor<ReturnType>(_ endpoint: Endpoint<ReturnType>, response: HTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults {
        if let after = endpoint.responseInterceptor {
            return after(endpoint, response, responseObject)
        } else {
            return ProcessResults(true, nil)
        }
    }
    
    private func processResponseInterceptors<ReturnType>(_ endpoint: Endpoint<ReturnType>, response: HTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults {
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
    
    private func processRequestInterceptors<ReturnType>(_ endpoint: Endpoint<ReturnType>, mutableRequest: inout NSMutableURLRequest) -> NSMutableURLRequest {
        var processedRequest: NSMutableURLRequest = mutableRequest.mutableCopy() as! NSMutableURLRequest
        for Bridge in self.requestInterceptors {
            Bridge.process(endpoint, mutableRequest: &processedRequest)
        }
        return processedRequest
    }
    
    // MARK: - URLSessionDelegate
    
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        if self.isDebugMode, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK - Bridges

typealias EndpointIdentifier = String

/**
*  Conform to the `RequestInterceptor` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol RequestInterceptor {
    func process<ReturnType>(_ endpoint: Endpoint<ReturnType>, mutableRequest: inout NSMutableURLRequest)
}

/**
*  Conform to the `ResponseInterceptor` protocol to work with data after
*  the request is returned with a response. `responseObject` is a pointer
*  to the resposne object that your endpoint has responded with and can
*  be modified or replaced.
*/
public protocol ResponseInterceptor {
    func process<ReturnType>(_ endpoint: Endpoint<ReturnType>, response: HTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults
}

public enum BridgeErrorType: Error {
    case `internal`
    case encoding
    case serializing
    case parsing
    case server
    case cancelled
}


