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
    static func parseResponseObject(_ responseObject: Any) throws -> Any
}

extension Array : Parseable {
    public static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let referenceType = self.Element.self as? Parseable.Type {
            if let responseArray = responseObject as? Array<Any> {
                var parsedResponse: Array<Element> = []
                for obj in responseArray {
                    do {
                        let parsedObj = try referenceType.parseResponseObject(obj)
                        parsedResponse.append(parsedObj as! Element)
                    } catch let error {
                        throw error
                    }
                }
                return parsedResponse
            }
        }
        throw BridgeErrorType.parsing
    }
}

extension String: Parseable {
    public static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let resp = responseObject as? String {
            return resp
        }
        throw BridgeErrorType.parsing
    }
}

extension Dictionary: Parseable {
    public static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let resp = responseObject as? Dict {
            return resp
        }
        throw BridgeErrorType.parsing
    }
}

public typealias Dict = Dictionary<String, Any>

public typealias ProcessResults = (shouldContinue: Bool, bridgeError: BridgeErrorType?)

public class GET <ReturnType> : Endpoint<ReturnType> where ReturnType : Parseable {
    public init(_ route: String, before: RequestInterceptorBlock? = nil, after: ResponseInterceptorBlock? = nil, client: Bridge = Bridge.sharedInstance) {
       super.init(route, method: .GET, before: before, after: after, client: client)
    }

    public required init(_ route: String, method verb: HTTPMethod, before: RequestInterceptorBlock?, after: ResponseInterceptorBlock?, client: Bridge) {
        guard verb == .GET else { fatalError("Initializing with non-matching HTTPMethod") }
        super.init(route, method: verb, before: before, after: after, client: client)
    }
}

public class POST <ReturnType> : Endpoint<ReturnType> where ReturnType : Parseable {
    public init(_ route: String, before: RequestInterceptorBlock? = nil, after: ResponseInterceptorBlock? = nil, client: Bridge = Bridge.sharedInstance) {
        super.init(route, method: .POST, before: before, after: after, client: client)
    }

    public required init(_ route: String, method verb: HTTPMethod, before: RequestInterceptorBlock?, after: ResponseInterceptorBlock?, client: Bridge) {
        guard verb == .POST else { fatalError("Initializing with non-matching HTTPMethod") }
        super.init(route, method: verb, before: before, after: after, client: client)
    }
}

public class PUT <ReturnType> : Endpoint<ReturnType> where ReturnType : Parseable {
    public init(_ route: String, before: RequestInterceptorBlock? = nil, after: ResponseInterceptorBlock? = nil, client: Bridge = Bridge.sharedInstance) {
        super.init(route, method: .PUT, before: before, after: after, client: client)
    }

    public required init(_ route: String, method verb: HTTPMethod, before: RequestInterceptorBlock?, after: ResponseInterceptorBlock?, client: Bridge) {
        guard verb == .PUT else { fatalError("Initializing with non-matching HTTPMethod") }
        super.init(route, method: verb, before: before, after: after, client: client)
    }
}

public class DELETE <ReturnType> : Endpoint<ReturnType> where ReturnType : Parseable {
    public init(_ route: String, before: RequestInterceptorBlock? = nil, after: ResponseInterceptorBlock? = nil, client: Bridge = Bridge.sharedInstance) {
        super.init(route, method: .DELETE, before: before, after: after, client: client)
    }

    public required init(_ route: String, method verb: HTTPMethod, before: RequestInterceptorBlock?, after: ResponseInterceptorBlock?, client: Bridge) {
        guard verb == .DELETE else { fatalError("Initializing with non-matching HTTPMethod") }
        super.init(route, method: verb, before: before, after: after, client: client)
    }
}

public class Endpoint <ReturnType>: NSObject, NSCopying where ReturnType : Parseable {
    
    public typealias EndpointSuccess = ((_ response: ReturnType) -> ())
    public typealias EndpointFailure = ((_: NSError, _: Data?, _: URLRequest, _: URLResponse?) -> ())
    
    public typealias RequestInterceptorBlock = ((_: Endpoint<ReturnType>, _: NSMutableURLRequest) -> ())
    public typealias ResponseInterceptorBlock = ((_: Endpoint<ReturnType>, _: HTTPURLResponse?, _: ResponseObject) -> (ProcessResults))
    
    /// The route or relative path of your endpoint
    public var route: String
    
    // The HTTP verb as defined in the `HTTPMethod` enum to access this endpoint with
    public var method: HTTPMethod
    
    // Encoding: JSON only for now. Set in init
    public var encoding: Encoding!
    
    // Accept Cookies
    public var acceptsCookies: Bool = false
    
    // The api client which will be making the requests, currently an AFNetworking shared client
    // but can be replaced with any networking interface layer
    // TODO: Make this interface less dependent on AFNetworking
    public var client: Bridge
    
    // Parameters for this endpoint when executing
    public var params: Dict?
    
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
    var requestInterceptor: RequestInterceptorBlock?
    var responseInterceptor: ResponseInterceptorBlock?
    
    // Meta data for tracking
    public private(set) var tag: String?
    
    public required init(_ route: String, method verb: HTTPMethod, before: RequestInterceptorBlock? = nil, after: ResponseInterceptorBlock? = nil, client: Bridge = Bridge.sharedInstance) {
        self.route = route
        self.method = verb
        self.encoding = .json
        self.client = client
        self.requestInterceptor = before
        self.responseInterceptor = after
    }
    
    /**
    Executes the request defined by this endpoint
    
    :param: id      (optional) ID of the resource you wish to access
    :param: params  (optional) dictionary of parameters to pass with this request
    :param: success closure with the code to be executed on success
    :param: failure closure with the code to be executed on failure
    
    :returns: the `NSURLSessionDataTask` which was executed
    */
    public func execute(_ vars: String..., params: Dict? = nil, tag: String? = nil, success: EndpointSuccess?, failure: EndpointFailure? = nil) {
        
        let executionCopy: Endpoint<ReturnType> = self.copy() as! Endpoint<ReturnType>
        
        executionCopy.identifier = UUID().uuidString
        
        executionCopy.successBlock = success
        executionCopy.failureBlock = failure
        
        executionCopy.params = params
        executionCopy.tag = tag
        
        for varString in vars {
            if let range = executionCopy.route.range(of: "#") {
                executionCopy.route = executionCopy.route.replacingCharacters(in: range, with: varString)
            } else {
                // There are more variables passed in
                // than there are variable markers
            }
        }
        self.client.execute(executionCopy)
    }
    
    
    public func attach(_ property: String, value: Any) -> Endpoint<ReturnType> {
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
    
    // NSCopying protocol
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let endpointCopy = type(of: self).init(self.route, method: self.method, before:self.requestInterceptor, after: self.responseInterceptor, client: self.client)
        endpointCopy.params = self.params
        endpointCopy.properties = self.properties
        return endpointCopy
    }
}

