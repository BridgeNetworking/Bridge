//
//  AppDelegate.swift
//  BridgeTest
//
//  Created by Justin Huang on 8/6/15.
//  Copyright © 2015 Zumper. All rights reserved.
//

import UIKit
import Bridge

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        let endpoint = Endpoint<GithubUser>("https://api.github.com/users/johnny-zumper", method: .GET)
        endpoint.execute(
            tag: ":user",
            success: { (response) in
                print(response)
            },
            failure: { (error, data, request, response) in
                print("error: \(error) \ndata:\(data) \nrequest:\(request) \nresponse:\(response)")
        })
//        Bridge.sharedInstance.cancelWithTag(":user")
        
        let listEndpoint = Endpoint<Array<GithubUser>>("https://api.github.com/users", method: .GET)
        listEndpoint.execute(
            tag: ":users",
            success: { (response) in
                print(response)
            },
            failure: { (error, data, request, response) in
                print("error: \(error) \ndata:\(data) \nrequest:\(request) \nresponse:\(response)")
        })
//        Bridge.sharedInstance.cancelWithTag(":users")

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}

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
