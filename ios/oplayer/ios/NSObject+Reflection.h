//
//  NSObject+Reflection.h
//  oplayer
//
//  Created by Aonichan on 16/1/28.
//
//

#import <Foundation/Foundation.h>

@interface NSObject(Reflection)

- (NSArray*)getIvarList:(Class)klass;

@end
