# Bridge [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Simple Typed JSON HTTP Networking in Swift 2.0

## TODO
- [ ] Documentation
- [ ] Error handling

```
var endpoint = GET<GithubUser>("https://api.github.com/users/whatever")
endpoint.execute(success: { (user: GithubUser) in
    print(user)
})
```


## Bridges

The power of Bridge is that it lets you create custom "Bridges" to process your requests before they are sent off to the internets, or to process your responses before they are returned to the success block.

Attach custom headers based on the endpoint, write retry handling, write authentication handlers, abandon REST and use method tunneling. Bridge is extremely extensible to your needs.

```
/**
*  Conform to the `RequestBridge` protocol for any Bridge that
*  needs to work with or alter a request before it's sent over the wire
*/
public protocol RequestBridge {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, inout mutableRequest: NSMutableURLRequest)
}

/**
*  Conform to the `ResponseBridge` protocol to work with data after
*  the request is returned with a response.
*/
public protocol ResponseBridge {
    func process<ReturnType>(endpoint: Endpoint<ReturnType>, response: NSHTTPURLResponse?, responseObject: ResponseObject) -> Bool
}

```
Examples:
- [Retry]() (Retries requests on response if not 2xx code)
- [Model Cache]() (Caches objects on response)
- [Method Tunneling]() (Changes the HTTP Verb)


## Object Serialization
Bridge is implemented using generics which allow you to serialize to objects as long as your objects conform to the `Parseable` protocol.

```
public protocol Parseable {
    static func parseResponseObject(responseObject: AnyObject) -> AnyObject
}
```

It is left completely up to the developer on how you want to implement the `Parseable` protocol. You can manually serialize your objects:

```
struct User: Parseable {
  var name: String?
  var age: Int?
  var pictureURL: NSURL?

  public static func parseResponseObject(responseObject: AnyObject) -> AnyObject {
      if let dict = responseObject = Dictionary<String, AnyObject> {
        let user = User()
        user.name = dict["name"]
        user.age = dict["age"]
        user.pictureURL = NSURL(string: dict["picture"])
    }
  }
}
```

You can also serialize them using whatever serialization libraries you like. This is an example of out out-of-box working solution for [Mantle](https://github.com/Mantle/Mantle) if you're already using Mantle models. *No code change* is required to your models.

```
// Swift Extension on MTLModel

extension MTLModel: Parseable {

    public static func parseResponseObject(responseObject: AnyObject) -> AnyObject {
        if let JSON = responseObject as? Array<AnyObject> {
            do {
                return try MTLJSONAdapter.modelsOfClass(self, fromJSONArray: JSON) as! [MTLModel]
            } catch {
                print(error)
            }
        } else if let JSON = responseObject as? Dictionary<NSObject, AnyObject> {
            do {
                return MTLJSONAdapter.modelOfClass(self, fromJSONDictionary: JSON) as! MTLModel
            } catch {
                print(error)
            }
        }
        return responseObject
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

## Requirements
 - iOS 8.0+
 - Swift 2.0

## Installation

[Carthage]((https://github.com/Carthage/Carthage)) is the preferred method of installation

just add to your Cartfile:
```
github "rawrjustin/Bridge"
```

## License
Bridge is [licensed](https://github.com/rawrjustin/Bridge/blob/master/LICENSE.md) under MIT license.  

## Questions?

Open an [issue](https://github.com/rawrjustin/Bridge/issues)
