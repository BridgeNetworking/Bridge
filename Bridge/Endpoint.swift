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

public protocol Parseable {
    init()
    func parseResponseObject(responseObject: AnyObject) -> AnyObject
}

extension Array : Parseable {
    public static func parseResponseObject(responseObject: AnyObject) -> AnyObject {
        if let referenceType = self.Element.self as? Parseable.Type {
            if let responseArray = responseObject as? Array<AnyObject> {
                let response = responseArray.map({ referenceType.parseResponseObject($0)}).map({ $0 })
                return response
            }
        }
        return Array<AnyObject>() // TODO : implement error handling
    }
}

extension String: Parseable {
    public static func parseResponseObject(responseObject: AnyObject) -> AnyObject {
        if let resp = responseObject as? String {
            return resp
        }
        return "" // TODO : implement error handling
    }
}

extension Dictionary: Parseable {
    public static func parseResponseObject(responseObject: AnyObject) -> AnyObject {
        if let resp = responseObject as? Dictionary<String, AnyObject> {
            return resp
        }
        return Dictionary<String, AnyObject>() // TODO : implement error handling
    }
}

public typealias Dict = Dictionary<String, AnyObject>

public struct Endpoint<ReturnType where ReturnType:Parseable> {
    
    public typealias EndpointSuccess = ((response: ReturnType) -> ())
    public typealias EndpointFailure = ((error: NSError?) -> ())
    
    public typealias RequestBridgeBlock = ((endpoint: Endpoint<ReturnType>, mutableRequest: NSMutableURLRequest) -> ())
    public typealias ResponseBridgeBlock = ((endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> ())
    
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
    
    // UUID for each endpoint
    // TODO: Spec if still needed.
    public var identifier: String?
    
    // User defined properties
    private var properties: Dictionary<String, Any> = [:]
    
    // MARK: Properties for spawned copies
    
    // Completion Closures
    public private(set) var successBlock: EndpointSuccess?
    public private(set) var failureBlock: EndpointFailure?
    
    // Endpoint Specific Bridges and Bridge exemptions
    var requestBridge: RequestBridgeBlock?
    var responseBridge: ResponseBridgeBlock?
    
    // Meta data for tracking
    public private(set) var tag: String?
    
    public init(_ route: String, method verb: HTTPMethod, before: RequestBridgeBlock = { (_,_) in }, after: ResponseBridgeBlock = { (_,_,_) in }, client: Bridge = Bridge.sharedInstance) {
        self.route = route
        self.method = verb
        self.client = client
        self.requestBridge = before
        self.responseBridge = after
    }
    
    /**
    Executes the request defined by this endpoint
    
    :param: id      (optional) ID of the resource you wish to access
    :param: params  (optional) dictionary of parameters to pass with this request
    :param: success closure with the code to be executed on success
    :param: failure closure with the code to be executed on failure
    
    :returns: the `NSURLSessionDataTask` which was executed
    */
    public func execute(id: String? = nil, params: Dictionary<String, AnyObject>? = nil, tag: String? = nil, success: EndpointSuccess?, failure: EndpointFailure? = nil) -> NSURLSessionDataTask {
        
        var executionCopy = self
        
        executionCopy.identifier = self.identifier != nil ? self.identifier : NSUUID().UUIDString
        
        executionCopy.successBlock = success
        executionCopy.failureBlock = failure
        
        executionCopy.params = params
        executionCopy.tag = tag
        
        if let resourceId = id {
            executionCopy.route = executionCopy.route.stringByReplacingOccurrencesOfString("#", withString: resourceId, options: .LiteralSearch, range: nil)
        }
        return self.client.execute(executionCopy)
    }
    
    
    public mutating func attach(property: String, value: Any) -> Endpoint<ReturnType> {
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
    
    public func requestPath() -> String {
        return self.client.baseURL != nil ? self.client.baseURL!.absoluteString + self.route : self.route
    }
}

// MARK: - Printable

extension Endpoint {
    public var description: String {
        get {
            var desc: String = ""
            
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

