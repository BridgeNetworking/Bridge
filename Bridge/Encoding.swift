//
//  Encoding.swift
//  Rentals
//
//  Created by Justin Huang on 7/28/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import Foundation

public enum Encoding {
    case json
    
    
    public func encode(_ mutableRequest: NSMutableURLRequest, parameters: Dict?) throws -> NSMutableURLRequest {
        
        guard let parameters = parameters else {
            return mutableRequest
        }
        
        switch self {
        case .json:
            switch HTTPMethod(rawValue: mutableRequest.httpMethod)! {
            case .GET, .DELETE:
                
                // Encode params in the URL of the request
                let mappedParameters: Array<(key: String, value: String)> = (parameters).map({ (key, value) in
                    if let collection = value as? [Any] {
                        return (key, self.escapeString("\(key)") + "=" + (collection.reduce("", { $0 + ($0.characters.isEmpty ? "" : ",") + self.escapeString("\($1)")})))
                    } else {
                        return (key, self.escapeString("\(key)") + "=" + self.escapeString("\(value)") )
                    }
                })
                let flattenedString = mappedParameters.reduce("", { $0 + $1.1 + "&" } )
                
                // Append the leading `?` character for url encoded requests
                // and drop the trailing `&` from the reduce
                let queryString = "?" + String(flattenedString.characters.dropLast())
                
                let baseURL = mutableRequest.url
                mutableRequest.url = URL(string: queryString, relativeTo: baseURL!)
                
            case .POST, .PUT:
                
                // Encode params in the HTTP body of the request
                if JSONSerialization.isValidJSONObject(parameters) {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
                        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        mutableRequest.httpBody = data
                    } catch let error {
                        throw error
                    }
                } else {
                    // `parameters` is not a valid JSON object
                    throw BridgeErrorType.encoding
                }
            }
        }
        
        return mutableRequest
    }
    
    public func serialize(_ data: Data) throws -> ResponseObject {
        switch self {
        case .json:
            let serializedObject: Any?
            do {
                serializedObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            } catch {
                throw BridgeErrorType.serializing
            }
            if let object = serializedObject as? Array<Any> {
                return ResponseObject.jsonArray(object)
            } else if let object = serializedObject as? Dict {
                return ResponseObject.jsonDict(object)
            }
        }
        throw BridgeErrorType.serializing
    }
    
    func escapeString(_ string: String) -> String {
        let allowedDelimiters: String = ":#[]@!$&'()*+,;="
        var customAllowedSet = CharacterSet.urlQueryAllowed
        customAllowedSet.remove(charactersIn: allowedDelimiters)
        
        let escapedString = string.addingPercentEncoding(withAllowedCharacters: customAllowedSet)
        return escapedString!
    }
    
    public func serializeToString(_ data: Data) -> String? {
        switch self {
        case .json:
            return String(data: data, encoding: String.Encoding.utf8)
        }
    }
}

public enum ResponseObject {
    case jsonArray(Array<Any>)
    case jsonDict(Dict)
    
    public func rawValue() -> Any {
        switch self {
        case .jsonArray(let arrayValue):
            return arrayValue as Any
        case .jsonDict(let dictionaryValue):
            return dictionaryValue as Any
        }
    }
    
    public subscript(key: String) -> Any? {
        switch self {
        case .jsonDict(let dictionaryValue):
            return dictionaryValue[key]
        default:
            return nil
        }
    }
    
}
