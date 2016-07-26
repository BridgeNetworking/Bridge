//: Playground - noun: a place where people can play

import UIKit
import Bridge
import XCPlayground
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


// QUERY: GET request to http://httpbin.org/ip
// RESPONSE: Returns Dictionary<String, AnyObject>

Bridge.sharedInstance.baseURL = URL(string: "http://httpbin.org/")!

GET<Dict>("http://httpbin.org/ip").execute(success: { (response) in
    let ip: Dict = response
})

// This is an example of using variables within your endpoints
// This is useful when you have resource ids
// QUERY: GET request to http://jsonplaceholder.typicode.com/posts/# where '#' is a variable
// RESPONSE: Returns a Post object or a Post collection

Bridge.sharedInstance.baseURL = URL(string: "http://jsonplaceholder.typicode.com/")!

class Post: Parseable {
    var userID: Int?
    var title: String?
    
    static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let dict = responseObject as? Dict {
            let post = Post()
            post.userID = dict["userId"] as? Int
            post.title = dict["title"] as? String
            return post
        } else if let dicts = responseObject as? Array<Dict> {
            var posts = Array<Post>()
            for dict in dicts {
                if let serializedPost = try? Post.parseResponseObject(dict), let post = serializedPost as? Post {
                    posts.append(post)
                }
            }
            return posts
        }
        // If parsing encounters an error, throw enum that conforms to ErrorType.
        throw BridgeErrorType.parsing
    }
}

let postID = "1"
GET<Post>("posts/#").execute(postID, success: { (response) in
    let userID = response.userID
    let title = response.title
})

GET<Array<Post>>("posts").execute("", success: { (response) in
    let posts = response
})

// This is an example of using a custom class as a return type.
// QUERY: GET request to https://api.github.com/users/rawrjustin
// RESPONSE: Returns a User object

class NSUser: NSObject, Parseable {
    var name: String?
    var email: String?
    var pictureURL: URL?
    
    static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let dict = responseObject as? Dict {
            let user = NSUser()
            user.name = dict["name"] as? String
            user.email = dict["email"] as? String
            user.pictureURL = URL(string: dict["avatar_url"] as! String)
            return user
        }
        // If parsing encounters an error, throw enum that conforms to ErrorType.
        throw BridgeErrorType.parsing
    }
}

class User: Parseable {
    var name: String?
    var email: String?
    var pictureURL: URL?
    
    static func parseResponseObject(_ responseObject: Any) throws -> Any {
        if let dict = responseObject as? Dict {
            let user = User()
            user.name = dict["name"] as? String
            user.email = dict["email"] as? String
            user.pictureURL = URL(string: dict["avatar_url"] as! String)
            return user
        }
        // If parsing encounters an error, throw enum that conforms to ErrorType.
        throw BridgeErrorType.parsing
    }
}

GET<NSUser>("https://api.github.com/users/rawrjustin").execute(success: { (user: NSUser) in
    let name = user.name
    let email = user.email
    let url = user.pictureURL
})

GET<User>("https://api.github.com/users/johnny-zumper").execute(success: { (user: User) in
    let name = user.name
    let email = user.email
    let url = user.pictureURL
})
