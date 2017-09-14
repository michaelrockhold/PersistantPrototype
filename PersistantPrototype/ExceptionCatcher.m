//
//  ExceptionCatcher.m
//  PersistantPrototype
//
//  Created by Michael Rockhold on 9/13/17.
//  Copyright © 2017 ProtoCo. All rights reserved.
//

#import "ExceptionCatcher.h"

@implementation ExceptionCatcher

+ (BOOL)catchException:(void(^)())tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}

@end
