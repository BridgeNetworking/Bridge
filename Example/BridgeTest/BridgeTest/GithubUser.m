//
//  GithubUser.m
//  BridgeTest
//
//  Created by Justin Huang on 8/7/15.
//  Copyright © 2015 Zumper. All rights reserved.
//

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
