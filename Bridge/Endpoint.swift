//
//  Endpoint.swift
//  Rentals
//
//  Created by Justin Huang on 7/28/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import Foundation


// MARK: - Endpoint
public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

public typealias EndpointSuccess = ((response: AnyObject?) -> ())
public typealias EndpointFailure = ((error: NSError?) -> ())

public typealias RequestBridgeBlock = ((endpoint: Endpoint, mutableRequest: NSMutableURLRequest) -> ())
public typealias ResponseBridgeBlock = ((endpoint: Endpoint, response: NSHTTPURLResponse?, inout responseObject: AnyObject?) -> ())
public typealias EndpointCompletion = ((response: AnyObject?, error: NSError?) -> ())

public class Endpoint: NSObject, NSCopying {
    /// The route or relative path of your endpoint
    public var route: String
    
    // The HTTP verb as defined in the `HTTPMethod` enum to access this endpoint with
    public var method: HTTPMethod
    
    // Encoding: JSON only for now
    public var encoding: Encoding = .JSON
    
    // The api client which will be making the requests, currently an AFNetworking shared client
    // but can be replaced with any networking interface layer
    // TODO: Make this interface less dependent on AFNetworking
    public var client: Bridge
    
    // Parameters for this endpoint when executing
    public var params: Dictionary<String, AnyObject>?
    
    // Unique identifier for each endpoint
    // TODO: Spec if still needed.
    var identifier = NSUUID().UUIDString
    
    // User defined properties
    private var properties: Dictionary<String, Any> = [:]
    
    // MARK: Properties for spawned copies
    
    // Incrementing request ID to identify each request that's executed.
    // A new endpoint copy is spawned from this endpoint to create a new request
    // each time this endpoint is executed.
    public var requestId: Int = 1
    
    // Completion Closures
    public private(set) var successBlock: EndpointSuccess?
    public private(set) var failureBlock: EndpointFailure?
    
    // Endpoint Specific Bridges and Bridge exemptions
    var requestBridge: RequestBridgeBlock?
    var responseBridge: ResponseBridgeBlock?
    
    // Meta data for tracking
    public private(set) var tag: String?
    
    public required init(_ route: String, method verb: HTTPMethod, client: Bridge) {
        self.route = route
        self.method = verb
        self.client = client
    }
    
    /**
    Executes the request defined by this endpoint
    
    - parameter id:      (optional) ID of the resource you wish to access
    - parameter params:  (optional) dictionary of parameters to pass with this request
    - parameter success: closure with the code to be executed on success
    - parameter failure: closure with the code to be executed on failure
    
    - returns: the `NSURLSessionDataTask` which was executed
    */
    public func execute(id: String? = nil, params: Dictionary<String, AnyObject>? = nil, tag: String? = nil, success: EndpointSuccess?, failure: EndpointFailure?) -> NSURLSessionDataTask {
        
        let executionCopy = self.copy() as! Endpoint
        
        executionCopy.successBlock = success
        executionCopy.failureBlock = failure
        
        executionCopy.params = params
        executionCopy.requestId = nextRequestId()
        executionCopy.tag = tag
        
        if let resourceId = id {
            executionCopy.route = executionCopy.route.stringByReplacingOccurrencesOfString("#", withString: resourceId, options: .LiteralSearch, range: nil)
        }
        return self.client.execute(executionCopy)
    }
    
    
    public func attach(property: String, value: Any) -> Self {
        self.properties[property] = value
        return self
    }
    
    public subscript(property: String) -> Any? {
        get {
            return self.properties[property]
        }
        set {
            self.properties[property] = newValue
        }
    }
    
    /**
    Gets the next availble unique requestID
    Request ID = 1 belongs to the original endpoint definition
    
    - returns: Int representing the request ID of an executed request
    */
    func nextRequestId() -> Int {
        var newRequestId: Int = 0
        
        let synchronousQueue = dispatch_queue_create("com.zumper.requestIdQueue", nil)
        dispatch_sync(synchronousQueue) {
            newRequestId = self.requestId
            self.requestId += 1
        }
        
        return newRequestId
    }
    
    
    /**
    Endpoint specific request Bridges
    
    - parameter requestBlock: block
    */
    public func before(requestBlock: RequestBridgeBlock) -> Self {
        self.requestBridge = requestBlock
        return self
    }
    
    /**
    Endpoint specific response Bridges
    
    - parameter requestBlock: block
    */
    public func after(responseBlock: ResponseBridgeBlock) -> Self {
        self.responseBridge = responseBlock
        return self
    }
    
    func requestPath() -> String {
        return self.client.baseURL != nil ? self.client.baseURL!.absoluteString + self.route : self.route
    }
    
    // NSCopying protocol
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let endpointCopy = self.dynamicType.init(self.route, method: self.method, client: self.client)
        endpointCopy.params = self.params
        endpointCopy.identifier = self.identifier
        endpointCopy.properties = self.properties
        return endpointCopy
    }
}


// MARK: - Printable

extension Endpoint {
    override public var description: String {
        get {
            var desc: String
            desc = super.description + newLine()
            
            desc += method.rawValue + space() + requestPath() + newLine()
            
            if let requestParameters = params {
                desc += "params: " + requestParameters.description + newLine()
            }
            
            if !properties.isEmpty {
                desc += "User defined properties: " + properties.description + newLine()
            }
            
            if let requestTag = tag {
                desc += "Request Tag: " + requestTag + newLine()
            }
            return desc
        }
    }
    
    func space() -> String {
        return " "
    }
    
    func newLine() -> String {
        return "\n"
    }
}

extension Endpoint: CustomDebugStringConvertible {
    
}