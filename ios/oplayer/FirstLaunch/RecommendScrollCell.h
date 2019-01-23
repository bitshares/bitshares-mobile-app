//
//  SGFocusImageFrame.h
//  ScrollViewLoop
//
//  Created by Vincent Tang on 13-7-18.
//  Copyright (c) 2013年 Vincent Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StyledPageControl.h"

@class RecommendScrollCell;

#pragma mark - RecommendScrollCell
@protocol RecommendScrollCellDelegate <NSObject>
@optional
- (void)foucusImageFrame:(RecommendScrollCell *)imageFrame didSelectItem:(id)item;
- (void)foucusImageFrame:(RecommendScrollCell *)imageFrame currentItem:(int)index;

@end


@interface RecommendScrollCell : UIView <UIGestureRecognizerDelegate, UIScrollViewDelegate, StyledPageControlDelegate>
{
    BOOL _isAutoPlay;
}
- (id)initWithFrame:(CGRect)frame delegate:(id<RecommendScrollCellDelegate>)delegate imageItems:(NSArray *)items isAuto:(BOOL)isAuto;
- (id)initWithFrame:(CGRect)frame delegate:(id<RecommendScrollCellDelegate>)delegate imageItems:(NSArray *)items;
- (void)scrollToIndex:(int)aIndex;

@property (nonatomic, assign) id<RecommendScrollCellDelegate> delegate;

@end
