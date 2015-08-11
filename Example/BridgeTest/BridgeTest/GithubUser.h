//
//  GithubUser.h
//  BridgeTest
//
//  Created by Justin Huang on 8/7/15.
//  Copyright © 2015 Zumper. All rights reserved.
//

#import <Mantle/Mantle.h>

@interface GithubUser : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSNumber *id;
@property (nonatomic, copy) NSURL *avatarURL;
@property (nonatomic, copy) NSString *name;

@end
