# Bridge [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Bridge.svg)](https://img.shields.io/cocoapods/v/Bridge.svg)

Simple Typed JSON HTTP Networking in Swift 4.0

#### GET
```swift
GET<Dict>("http://httpbin.org/ip").execute(success: { (response) in
    let ip: Dict = response
})

let postID = "1"
GET<Dict>("http://jsonplaceholder.typicode.com/posts/#").execute(postID, success: { (response) in
    let post: Dict = response
})
```

#### POST
```swift
let userComment = ["justin": "wow this is cool"]
let endpoint = POST<[String: AnyObject]>("https://api.bridge.com/comments")
endpoint.execute(params: userComment, success: { (commentResponse: [String: AnyObject]) -> () in
    // Handle success
}, failure: { (error, data, request, response) in
    // Handle failure
})
```


## Interceptors

The power of Bridge is that it lets you create custom "Interceptors" to intercept process your requests before they are sent off to the internets, or to intercept and process your responses before they are returned to the caller's success block.

Attach custom headers based on the endpoint, write retry handling, write authentication handlers, use method tunneling. Interceptors allow Bridge to be extremely extensible to your project needs.

```swift
/**
*  Conform to the `ResponseInterceptor` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol ResponseInterceptor {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest)
}

/**
*  Conform to the `ResponseInterceptor` protocol to work with data after
*  the request is returned with a response.
*/
public protocol ResponseInterceptor {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> ProcessResults
}

```
Examples:
- [Retry](https://gist.github.com/rawrjustin/1e35c5998a53a987b23d) (Retries requests on response if not 2xx code)
- [Model Cache](https://gist.github.com/rawrjustin/7331da16d6e637db20dc) (Caches objects on response)
- [Method Tunneling]() (Changes the HTTP Verb)


## Object Serialization
Bridge is implemented using generics which allow you to serialize to objects as long as your objects conform to the `Parseable` protocol.

```swift
public protocol Parseable {
    static func parseResponseObject(responseObject: AnyObject) throws -> AnyObject
}
```

It is left completely up to the developer on how you want to implement the `Parseable` protocol. You can manually create and serialize your objects:

```swift
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
```

Or you can also serialize them using whatever serialization libraries you like. [This gist](https://gist.github.com/rawrjustin/79f5186717fbc38c0b617a390ab9c0f0) is an example of out out-of-box working solution for [Mantle](https://github.com/Mantle/Mantle) if you're already using Mantle models. *No code change* is required to your Mantle models.

Once models are setup, making calls are as simple as:
```swift
let endpoint = GET<GithubUser>("https://api.github.com/users/rawrjustin")
endpoint.execute(success: { (user: GithubUser) in
    print(user)
})

let endpoint = GET<Array<GithubUser>>("https://api.github.com/users")
endpoint.execute(success: { (users: Array<GithubUser>) in
    print(users)
}, failure: { (error: NSError?) in
    print(error)
})
```

## Advanced Features

#### Base URL
You can set the base url of your Bridge client
```swift
Bridge.sharedInstance.baseURL = "http://api.github.com"
GET<GithubUser>("/users/rawrjustin") // expands to http://api.github.com/users/rawrjustin
```

#### Cancellation by Tag
Easily cancel any requests tagged with an identifier.
```swift
Bridge.sharedInstance.cancelWithTag("DebouncedSearch")
```

#### Variable endpoints
Similar to how Rails maps :id for resources, `#` is used as the character where a variable would be inserted into the path.

`GET<Dict>("/photos/#")` will map to `/photos/1` if you pass in `1` in the first variadic parameter when you call execute(). You can have multiple variables, they will be mapped in order respectively.

#### Additional HTTP headers

#### Endpoint Specific Interceptors

## Requirements
 - iOS 8.0+
 - Swift 4.0

## Installation

[Cocoapods](http://cocoapods.org/)

```
pod 'Bridge', '0.4.3'
```

[Carthage](https://github.com/Carthage/Carthage)

```
github "rawrjustin/Bridge"
```

## License
Bridge is [licensed](https://github.com/rawrjustin/Bridge/blob/master/LICENSE.md) under MIT license.  

## Questions?

Open an [issue](https://github.com/rawrjustin/Bridge/issues)
