//
//  NativeMethodExtension.h
//  oplayer
//
//  Created by Aonichan on 16/3/23.
//
//

#import <Foundation/Foundation.h>

#pragma mark- NSString
/**
 *  扩展字符串类方法
 */
@interface NSString(MethodExtension)

/**
 *  str 是否包含指定字符串 sub
 */
+ (BOOL)isIncludedString:(NSString*)str value:(NSString*)sub;

/**
 *  去除头部尾部空白字符
 */
+ (NSString*)trim:(NSString*)str;

@end

#pragma mark- UITextField
/**
 *  扩展UITextField类方法
 */
@interface UITextField(MethodExtension)

- (void)safeResignFirstResponder;

@end

#pragma mark- UITextView
/**
 *  扩展UITextView类方法
 */
@interface UITextView(MethodExtension)

- (void)safeResignFirstResponder;

@end
