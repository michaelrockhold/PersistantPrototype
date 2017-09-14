//
//  ExceptionCatcher.h
//  PersistantPrototype
//
//  Created by Michael Rockhold on 9/13/17.
//  Copyright © 2017 ProtoCo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExceptionCatcher : NSObject

+ (BOOL)catchException:(void(^)())tryBlock error:(__autoreleasing NSError **)error;

@end
