# Bridge [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Bridge.svg)](https://img.shields.io/cocoapods/v/Bridge.svg)

Simple Typed JSON HTTP Networking in Swift 2.0

#### GET
```
let endpoint = Endpoint<GithubUser>("https://api.github.com/users/whatever", method: .GET)
endpoint.execute(success: { (user: GithubUser) in
    print(user)
})
```

#### POST
```
let userComment = ["justin": "wow this is cool"]
let endpoint = Endpoint<[String: AnyObject]>("https://api.bridge.com/comments", method: .POST)
endpoint.execute(params: userComment, success: { (commentResponse: [String: AnyObject]) -> () in
    print(response)  // {"success": true}
}, failure: { (error, data, request, response) in
    // Handle failure
})
```


## Interceptors

The power of Bridge is that it lets you create custom "Interceptors" to intercept process your requests before they are sent off to the internets, or to intercept and process your responses before they are returned to the caller's success block.

Attach custom headers based on the endpoint, write retry handling, write authentication handlers, use method tunneling. Interceptors allow Bridge to be extremely extensible to your project needs.

```
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

```
public protocol Parseable {
    static func parseResponseObject(responseObject: AnyObject) throws -> AnyObject
}
```

It is left completely up to the developer on how you want to implement the `Parseable` protocol. You can manually serialize your objects:

```
struct User: Parseable {
  var name: String?
  var age: Int?
  var pictureURL: NSURL?

  public static func parseResponseObject(responseObject: AnyObject) throws -> AnyObject {
      if let dict = responseObject = Dictionary<String, AnyObject> {
        let user = User()
        user.name = dict["name"]
        user.age = dict["age"]
        user.pictureURL = NSURL(string: dict["picture"])
      }
      // If parsing encounters an error, throw enum that conforms to ErrorType.
      throw YourErrorType.Case
  }
}
```

You can also serialize them using whatever serialization libraries you like. This is an example of out out-of-box working solution for [Mantle](https://github.com/Mantle/Mantle) if you're already using Mantle models. *No code change* is required to your models.

```
// Swift Extension on MTLModel

extension MTLModel: Parseable {

    public static func parseResponseObject(responseObject: AnyObject) throws -> AnyObject {
        if let JSON = responseObject as? Array<AnyObject> {
            do {
                return try MTLJSONAdapter.modelsOfClass(self, fromJSONArray: JSON) as! [MTLModel]
            } catch {
                throw BridgeErrorType.Parsing
            }
        } else if let JSON = responseObject as? Dictionary<NSObject, AnyObject> {
            do {
                return try MTLJSONAdapter.modelOfClass(self, fromJSONDictionary: JSON) as! MTLModel
            } catch {
                throw BridgeErrorType.Parsing
            }
        }
        throw BridgeErrorType.Parsing
    }
}

// Objective C Model

#import <Mantle/Mantle.h>

@interface GithubUser : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSNumber *id;
@property (nonatomic, copy) NSURL *avatarURL;
@property (nonatomic, copy) NSString *name;

@end

#import "GithubUser.h"

@implementation GithubUser

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"id": @"id",
             @"login": @"login",
             @"avatarURL": @"avatar_url",
             @"name": @"name"
             };
}

+ (NSValueTransformer *)avatarURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end

```

Once models are setup, making calls are as simple as:
```
let endpoint = Endpoint<GithubUser>("https://api.github.com/users/whatever", method: .GET)
endpoint.execute(success: { (user: GithubUser) in
    print(user)
})

let endpoint = Endpoint<[GithubUser]>("https://api.github.com/users", method: .GET)
endpoint.execute(success: { (users: Array<GithubUser>) in
    print(users)
}, failure: { (error: NSError?) in
    print(error)
})
```

## Advanced Features

#### Cancellation by Tag
Easiily cancel any requests tagged with an identifier.
```
Bridge.sharedInstance.cancelWithTag("DebouncedSearch")
```

#### Additional HTTP headers

#### Endpoint Specific Interceptors

## Requirements
 - iOS 8.0+
 - Swift 2.0

## Installation

[Cocoapods](http://cocoapods.org/)

```
pod 'Bridge', '0.3.3'
```

[Carthage]((https://github.com/Carthage/Carthage))

```
github "rawrjustin/Bridge"
```

## License
Bridge is [licensed](https://github.com/rawrjustin/Bridge/blob/master/LICENSE.md) under MIT license.  

## Questions?

Open an [issue](https://github.com/rawrjustin/Bridge/issues)
