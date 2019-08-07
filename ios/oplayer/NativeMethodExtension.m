//
//  NativeMethodExtension.m
//  oplayer
//
//  Created by Aonichan on 16/3/23.
//
//

#import "NativeMethodExtension.h"

#pragma mark- NSString

@implementation NSString(MethodExtension)

+ (BOOL)isIncludedString:(NSString*)str value:(NSString*)sub
{
    if (!str || !sub){
        return NO;
    }
    
    return [str rangeOfString:sub].location != NSNotFound;
}

+ (NSString*)trim:(NSString*)str
{
    if (!str){
        return nil;
    }
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

#pragma mark- UITextField
@implementation UITextField(MethodExtension)

- (void)safeResignFirstResponder
{
    if ([self isFirstResponder]){
        [self resignFirstResponder];
    }
}

@end

#pragma mark- UITextView
@implementation UITextView(MethodExtension)

- (void)safeResignFirstResponder
{
    if ([self isFirstResponder]){
        [self resignFirstResponder];
    }
}

@end
