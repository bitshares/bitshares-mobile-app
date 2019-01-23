//
//  SGFocusImageFrame.m
//  ScrollViewLoop
//
//  Created by Vincent Tang on 13-7-18.
//  Copyright (c) 2013年 Vincent Tang. All rights reserved.
//

#import "RecommendScrollCell.h"
#import <objc/runtime.h>
#import "ThemeManager.h"

@interface RecommendScrollCell () {
    CGFloat         _fItemWidth;
    UIScrollView *_scrollView;
    UIPageControl *_pageControl;
    StyledPageControl*  _stylePageControl;
}

- (void)setupViews;
- (void)switchFocusImageItems;
@end

static NSString *SG_FOCUS_ITEM_ASS_KEY = @"RecommendScrollview";

static CGFloat SWITCH_FOCUS_PICTURE_INTERVAL = 5.0; //switch interval time

@implementation RecommendScrollCell
@synthesize delegate = _delegate;

- (id)initWithFrame:(CGRect)frame delegate:(id<RecommendScrollCellDelegate>)delegate imageItems:(NSArray *)items isAuto:(BOOL)isAuto
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _fItemWidth = [[UIScreen mainScreen] bounds].size.width;
        
        NSMutableArray *imageItems = [NSMutableArray arrayWithArray:items];
        objc_setAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY, imageItems, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        _isAutoPlay = isAuto;
        [self setupViews];
        
        [self setDelegate:delegate];
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame delegate:(id<RecommendScrollCellDelegate>)delegate imageItems:(NSArray *)items
{
    return [self initWithFrame:frame delegate:delegate imageItems:items isAuto:YES];
}

- (void)dealloc
{
    objc_setAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _scrollView.delegate = nil;
}


#pragma mark - private methods
- (void)setupViews
{
    NSArray *imageItems = objc_getAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY);
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.scrollsToTop = NO;
    float space = 0;
//    CGSize size = CGSizeMake(320, 0);
  
    _stylePageControl = [[StyledPageControl alloc] initWithFrame:CGRectMake(0, self.bounds.size.height-32, self.bounds.size.width, 32)];
    _stylePageControl.delegate = self;
    _stylePageControl.userInteractionEnabled = NO;
    [_stylePageControl setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [_stylePageControl setPageControlStyle:PageControlStyleWithPageNumber];
    [_stylePageControl setNumberOfPages:(int)[imageItems count]];
    [_stylePageControl setCurrentPage:0];
    
    _stylePageControl.coreNormalColor = [ThemeManager sharedThemeManager].textColorGray;
    _stylePageControl.coreSelectedColor = [ThemeManager sharedThemeManager].textColorNormal;
    _stylePageControl.strokeNormalColor = [ThemeManager sharedThemeManager].textColorNormal;
    _stylePageControl.strokeSelectedColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    [self addSubview:_scrollView];
    [self addSubview:_stylePageControl];
    
    /*
     _scrollView.layer.cornerRadius = 10;
     _scrollView.layer.borderWidth = 1 ;
     _scrollView.layer.borderColor = [[UIColor lightGrayColor ] CGColor];
     */
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.directionalLockEnabled = YES;
    
    _scrollView.delegate = self;
    
    // single tap gesture recognizer
    UITapGestureRecognizer *tapGestureRecognize = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureRecognizer:)];
    tapGestureRecognize.delegate = self;
    tapGestureRecognize.numberOfTapsRequired = 1;
    tapGestureRecognize.cancelsTouchesInView = NO;
    [_scrollView addGestureRecognizer:tapGestureRecognize];
    //  禁止某方向滚动 ios7 bug
//    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * imageItems.count, _scrollView.frame.size.height);
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * imageItems.count, 0);
    
    for (int i = 0; i < imageItems.count; i++) {
        UIView* item = [imageItems objectAtIndex:i];
        item.frame = CGRectMake(i * _scrollView.frame.size.width+space, space, _scrollView.frame.size.width-space*2, _scrollView.frame.size.height-2*space);
        [_scrollView addSubview:item];
    }
}

- (void)switchFocusImageItems
{
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(switchFocusImageItems) object:nil];
    
    CGFloat targetX = _scrollView.contentOffset.x + _scrollView.frame.size.width;
    NSArray *imageItems = objc_getAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY);
    targetX = (int)(targetX/_fItemWidth) * _fItemWidth;
    [self moveToTargetPosition:targetX];
    
    if ([imageItems count]>1 && _isAutoPlay)
    {
        [self performSelector:@selector(switchFocusImageItems) withObject:nil afterDelay:SWITCH_FOCUS_PICTURE_INTERVAL];
    }
    
}

- (void)singleTapGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    NSLog(@"%s", __FUNCTION__);
    NSArray *imageItems = objc_getAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY);
    int page = (int)(_scrollView.contentOffset.x / _scrollView.frame.size.width);
    if (page > -1 && page < imageItems.count) {
        id item = [imageItems objectAtIndex:page];
        if ([self.delegate respondsToSelector:@selector(foucusImageFrame:didSelectItem:)]) {
            [self.delegate foucusImageFrame:self didSelectItem:item];
        }
    }
}

- (void)moveToTargetPosition:(CGFloat)targetX
{
    BOOL animated = YES;
    //    NSLog(@"moveToTargetPosition : %f" , targetX);
    [_scrollView setContentOffset:CGPointMake(targetX, 0) animated:animated];
}
#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
//    float targetX = scrollView.contentOffset.x;
//    NSArray *imageItems = objc_getAssociatedObject(self, (const void *)SG_FOCUS_ITEM_ASS_KEY);
//    if ([imageItems count]>=3)
//    {
//        if (targetX >= _fItemWidth * ([imageItems count] -1)) {
//            targetX = _fItemWidth;
//            [_scrollView setContentOffset:CGPointMake(targetX, 0) animated:NO];
//        }
//        else if(targetX <= 0)
//        {
//            targetX = _fItemWidth *([imageItems count]-2);
//            [_scrollView setContentOffset:CGPointMake(targetX, 0) animated:NO];
//        }
//    }
    int page = (_scrollView.contentOffset.x+_fItemWidth/2.0) / _fItemWidth;
    
    //    NSLog(@"%f %d",_scrollView.contentOffset.x,page);
//    if ([imageItems count] > 1)
//    {
//        page --;
//        if (page >= _stylePageControl.numberOfPages)
//        {
//            page = 0;
//        }else if(page <0)
//        {
//            page = _stylePageControl.numberOfPages -1;
//        }
//    }
    if (page!= _stylePageControl.currentPage)
    {
        if ([self.delegate respondsToSelector:@selector(foucusImageFrame:currentItem:)])
        {
            [self.delegate foucusImageFrame:self currentItem:page];
        }
    }
    [_stylePageControl setCurrentPage:page];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        CGFloat targetX = _scrollView.contentOffset.x + _scrollView.frame.size.width;
        targetX = (int)(targetX/_fItemWidth) * _fItemWidth;
        [self moveToTargetPosition:targetX];
    }
}


- (void)scrollToIndex:(int)aIndex
{
    NSArray *imageItems = objc_getAssociatedObject(self, (__bridge const void *)SG_FOCUS_ITEM_ASS_KEY);
    if ([imageItems count]>1)
    {
        if (aIndex >= ([imageItems count]-2))
        {
            aIndex = (int)[imageItems count]-3;
        }
        [self moveToTargetPosition:_fItemWidth*(aIndex+1)];
    }else
    {
        [self moveToTargetPosition:0];
    }
    [self scrollViewDidScroll:_scrollView];
    
}
@end
