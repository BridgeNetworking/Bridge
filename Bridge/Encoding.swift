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
    
    
    public func encode(mutableRequest: NSMutableURLRequest, parameters: Dictionary<String, AnyObject>?) -> (NSMutableURLRequest, NSError?) {
        
        if parameters == nil {
            return (mutableRequest, nil)
        }
        
        
        var error: NSError? = nil
        
        switch self {
        case .JSON:
            switch HTTPMethod(rawValue: mutableRequest.HTTPMethod)! {
            case .GET, .DELETE:
                // Encode params in the URL of the request
                let mappedParameters = (parameters!).map({ (key, value) in (key, self.escapeString("\(key)") + "=" + self.escapeString("\(value)") ) })
                var flattenedString = mappedParameters.reduce("", combine: { $0 + $1.1 + "&" } )
                
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
                    } catch let error1 as NSError {
                        error = error1
                    }
                } else {
                    // `parameters` is not a valid JSON object
                    return (mutableRequest, error)
                }
            }
        }
        
        return (mutableRequest, nil)
    }
    
    public func serialize(response: NSURLResponse, data: NSData) -> (AnyObject?, NSError?) {
        switch self {
        case .JSON:
            var error: NSError?
            let serializedObject: AnyObject?
            do {
                serializedObject = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let error1 as NSError {
                error = error1
                serializedObject = nil
            }
            return (serializedObject, error)
        }
    }
    
    func escapeString(string: String) -> String {
        let allowedDelimiters = ":#[]@!$&'()*+,;="
        let customAllowedSet =  NSCharacterSet(charactersInString: allowedDelimiters).invertedSet
        let escapedString = string.stringByAddingPercentEncodingWithAllowedCharacters(customAllowedSet)
        return escapedString!
    }
}