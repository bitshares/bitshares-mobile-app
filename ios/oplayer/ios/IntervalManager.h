//
//  IntervalManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  调用间隔管理

#import <Foundation/Foundation.h>

@interface IntervalManager : NSObject

+ (IntervalManager*)sharedIntervalManager;

- (void)releaseLock:(id)obj;

/**
 *  调用间隔管理，避免点击速度过快，cell事件触发两次，比如push两次vc等BUG。
 */
- (void)callBodyWithFixedInterval:(id)obj body:(void (^)())body;
- (void)callBodyWithInterval:(id)obj interval:(NSTimeInterval)interval body:(void (^)())body;

@end
