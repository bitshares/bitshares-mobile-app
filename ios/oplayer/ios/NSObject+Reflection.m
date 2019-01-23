//
//  NSObject+Reflection.m
//  oplayer
//
//  Created by Aonichan on 16/1/28.
//
//

#import <objc/runtime.h>
#import "NSObject+Reflection.h"

@implementation NSObject(Reflection)

-(NSArray*)getIvarList:(Class)klass
{
    NSMutableArray* retv = [NSMutableArray array];
    
    unsigned int numIvars = 0;
    Ivar * ivars = class_copyIvarList([self class], &numIvars);
    for(int i = 0; i < numIvars; i++) {
        Ivar ivar = ivars[i];
        const char* type = ivar_getTypeEncoding(ivar);
        if (!type || *type != *@encode(id)){
            continue;
        }
        id obj = object_getIvar(self, ivar);
        if (obj && [obj isKindOfClass:klass]){
            [retv addObject:obj];
        }
    }
    free(ivars);
    
    return [retv copy];
}

@end
