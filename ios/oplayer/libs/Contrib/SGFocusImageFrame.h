//
//  SGFocusImageFrame.h
//  ScrollViewLoop
//
//  Created by Vincent Tang on 13-7-18.
//  Copyright (c) 2013年 Vincent Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StyledPageControl.h"

@class SGFocusImageFrame;

#pragma mark - SGFocusImageFrameDelegate
@protocol SGFocusImageFrameDelegate <NSObject>
@optional
- (void)foucusImageFrame:(SGFocusImageFrame *)imageFrame didSelectItem:(id)item;
- (void)foucusImageFrame:(SGFocusImageFrame *)imageFrame currentItem:(int)index;

@end


@interface SGFocusImageFrame : UIView <UIGestureRecognizerDelegate, UIScrollViewDelegate, StyledPageControlDelegate>
{
    BOOL _isAutoPlay;
}
- (id)initWithFrame:(CGRect)frame delegate:(id<SGFocusImageFrameDelegate>)delegate imageItems:(NSArray *)items isAuto:(BOOL)isAuto;
- (id)initWithFrame:(CGRect)frame delegate:(id<SGFocusImageFrameDelegate>)delegate imageItems:(NSArray *)items;
- (void)scrollToIndex:(int)aIndex;
- (void)switchFocusImageItems;

@property (nonatomic, assign) id<SGFocusImageFrameDelegate> delegate;

@end
