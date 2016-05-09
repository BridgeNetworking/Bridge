//
//  Encoding.swift
//  Rentals
//
//  Created by Justin Huang on 7/28/15.
//  Copyright (c) 2015 Zumper. All rights reserved.
//

import Foundation

public enum Encoding {
    case JSON
    
    
    public func encode(mutableRequest: NSMutableURLRequest, parameters: Dictionary<String, AnyObject>?) throws -> NSMutableURLRequest {
        
        if parameters == nil {
            return mutableRequest
        }
        
        switch self {
        case .JSON:
            switch HTTPMethod(rawValue: mutableRequest.HTTPMethod)! {
            case .GET, .DELETE:
                // Encode params in the URL of the request
                let mappedParameters: Array<(key: String, value: String)> = (parameters!).map({ (key, value) in
                    if let collection = value as? [AnyObject] {
                        return (key, self.escapeString("\(key)") + "=" + (collection.reduce("", combine: { $0 + ($0.characters.isEmpty ? "" : ",") + self.escapeString("\($1)")})))
                    } else {
                        return (key, self.escapeString("\(key)") + "=" + self.escapeString("\(value)") )
                    }
                })
                let flattenedString = mappedParameters.reduce("", combine: { $0 + $1.1 + "&" } )
                
                // Append the leading `?` character for url encoded requests
                // and drop the trailing `&` from the reduce
                let queryString = "?" + String(flattenedString.characters.dropLast())
                
                let baseURL = mutableRequest.URL
                mutableRequest.URL = NSURL(string: queryString, relativeToURL: baseURL)
                
            case .POST, .PUT:
                
                // Encode params in the HTTP body of the request
                if NSJSONSerialization.isValidJSONObject(parameters!) {
                    do {
                        let data = try NSJSONSerialization.dataWithJSONObject(parameters!, options: [])
                        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        mutableRequest.HTTPBody = data
                    } catch let error {
                        throw error
                    }
                } else {
                    // `parameters` is not a valid JSON object
                    throw BridgeErrorType.Encoding
                }
            }
        }
        
        return mutableRequest
    }
    
    public func serialize(data: NSData) throws -> ResponseObject {
        switch self {
        case .JSON:
            let serializedObject: AnyObject?
            do {
                serializedObject = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                throw BridgeErrorType.Serializing
            }
            if let object = serializedObject as? Array<AnyObject> {
                return ResponseObject.JSONArray(object)
            } else if let object = serializedObject as? Dict {
                return ResponseObject.JSONDict(object)
            }
        }
        throw BridgeErrorType.Serializing
    }
    
    func escapeString(string: String) -> String {
        let allowedDelimiters = ":#[]@!$&'()*+,;="
        let customAllowedSet = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
        customAllowedSet.removeCharactersInString(allowedDelimiters)
        
        let escapedString = string.stringByAddingPercentEncodingWithAllowedCharacters(customAllowedSet)
        return escapedString!
    }
    
    public func serializeToString(data: NSData) -> String? {
        switch self {
        case .JSON:
            return String(data: data, encoding: NSUTF8StringEncoding)
        }
    }
}

public enum ResponseObject {
    case JSONArray(Array<AnyObject>)
    case JSONDict(Dict)
    
    public func rawValue() -> AnyObject {
        switch self {
        case .JSONArray(let arrayValue):
            return arrayValue
        case .JSONDict(let dictionaryValue):
            return dictionaryValue
        }
    }
    
    public subscript(key: String) -> AnyObject? {
        switch self {
        case .JSONDict(let dictionaryValue):
            return dictionaryValue[key]
        default:
            return nil
        }
    }
    
}