//
//  PageControl.h
//  UniversalTemplate
//
//  Created by Lex Lee on 7/20/12.
//  Copyright (c) 2012 ChinaNet. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StyledPageControl;

typedef enum
{
    PageControlStyleDefault = 0,
    PageControlStyleStrokedCircle = 1,
    PageControlStylePressed1 = 2,
    PageControlStylePressed2 = 3,
    PageControlStyleWithPageNumber = 4,
    PageControlStyleThumb = 5
} PageControlStyle;

@protocol StyledPageControlDelegate <NSObject>
@optional
-(void)StyledPageControl:(StyledPageControl*)pageControl didSelectItemAtIndex:(NSInteger)index;
@end

@interface StyledPageControl : UIControl
{
    int _currentPage, _numberOfPages;
    BOOL hidesForSinglePage;
    UIColor *coreNormalColor, *coreSelectedColor;
    UIColor *strokeNormalColor, *strokeSelectedColor;
    PageControlStyle _pageControlStyle;
    int _strokeWidth, diameter, gapWidth;
//    id<StyledPageControlDelegate> delegate;
}

@property (nonatomic, assign) id<StyledPageControlDelegate> delegate;
@property (nonatomic, retain) UIColor *coreNormalColor, *coreSelectedColor;
@property (nonatomic, retain) UIColor *strokeNormalColor, *strokeSelectedColor;
@property (nonatomic, assign) int _currentPage, _numberOfPages;
@property (nonatomic, assign) BOOL hidesForSinglePage;
@property (nonatomic, assign) PageControlStyle _pageControlStyle;
@property (nonatomic, assign) int _strokeWidth, diameter, gapWidth;
@property (nonatomic, retain) UIImage *thumbImage, *selectedThumbImage;

- (void)setCurrentPage:(int)page;
- (int)currentPage;
- (void)setNumberOfPages:(int)numOfPages;
- (int)numberOfPages;
- (PageControlStyle)pageControlStyle;
- (void)setPageControlStyle:(PageControlStyle)style;

@end

/* test code
 
 self.pageControl = [[StyledPageControl alloc] initWithFrame:CGRectZero];
 [self.pageControl setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
 [self.contentView addSubview:self.pageControl];
 [self.pageControl release];
 
 [cell.pageControl setNumberOfPages:10];
 [cell.pageControl setCurrentPage:5];
 
 if (indexPath.section==0)
 {
 [cell.pageControl setPageControlStyle:PageControlStyleDefault]; 
 if (indexPath.row==0)
 {
 // default style without changes
 }
 else if (indexPath.row==1)
 {
 // change color
 [cell.pageControl setCoreNormalColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1]];
 [cell.pageControl setCoreSelectedColor:[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1]];
 }
 else if (indexPath.row==2)
 {
 // change gap width
 [cell.pageControl setGapWidth:5];
 // change diameter
 [cell.pageControl setDiameter:9];
 }
 }
 else if (indexPath.section==1)
 {
 [cell.pageControl setPageControlStyle:PageControlStyleStrokedCircle];
 }
 else if (indexPath.section==2)
 {
 [cell.pageControl setPageControlStyle:PageControlStylePressed1];
 [cell.pageControl setBackgroundColor:[UIColor darkGrayColor]];
 }
 else if (indexPath.section==3)
 {
 [cell.pageControl setPageControlStyle:PageControlStylePressed2];
 [cell.pageControl setBackgroundColor:[UIColor darkGrayColor]];
 }
 else if (indexPath.section==4)
 {
 [cell.pageControl setPageControlStyle:PageControlStyleWithPageNumber];
 [cell.pageControl setNumberOfPages:14];
 }
 else if (indexPath.section==5)
 {
 [cell.pageControl setPageControlStyle:PageControlStyleThumb];
 [cell.pageControl setThumbImage:[UIImage imageNamed:@"pagecontrol-thumb-normal.png"]];
 [cell.pageControl setSelectedThumbImage:[UIImage imageNamed:@"pagecontrol-thumb-selected.png"]];
 [cell.pageControl setNumberOfPages:10];
 }
 */
