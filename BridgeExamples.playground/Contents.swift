//: Playground - noun: a place where people can play

import UIKit
import Bridge
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true


// QUERY: GET request to http://httpbin.org/ip
// RESPONSE: Returns Dictionary<String, AnyObject>

GET<Dict>("http://httpbin.org/ip").execute(success: { (response) in
    let ip: Dict = response
})

// This is an example of using variables within your endpoints
// This is useful when you have resource ids
// QUERY: GET request to http://jsonplaceholder.typicode.com/posts/# where '#' is a variable
// RESPONSE: Returns a User object


let postID = "1"
GET<Dict>("http://jsonplaceholder.typicode.com/posts/#").execute(postID, success: { (response) in
    let post: Dict = response
})


// This is an example of using a custom class as a return type.
// QUERY: GET request to https://api.github.com/users/rawrjustin
// RESPONSE: Returns a User object

class User: AnyObject, Parseable {
    var name: String?
    var email: String?
    var pictureURL: NSURL?
    
    static func parseResponseObject(responseObject: AnyObject) throws -> AnyObject {
        if let dict = responseObject as? Dictionary<String, AnyObject> {
            let user = User()
            user.name = dict["name"] as? String
            user.email = dict["email"] as? String
            user.pictureURL = NSURL(string: dict["avatar_url"] as! String)
            return user
        }
        // If parsing encounters an error, throw enum that conforms to ErrorType.
        throw BridgeErrorType.Parsing
    }
}


GET<User>("https://api.github.com/users/rawrjustin").execute(success: { (user: User) in
    let name = user.name
    let email = user.email
})