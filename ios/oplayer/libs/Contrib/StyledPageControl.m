//
//  PageControl.m
//  UniversalTemplate
//
//  Created by Lex Lee on 7/20/12.
//  Copyright (c) 2012 ChinaNet. All rights reserved.
//

#import "StyledPageControl.h"


@implementation StyledPageControl
@synthesize _numberOfPages, _currentPage, hidesForSinglePage;
@synthesize coreNormalColor, coreSelectedColor;
@synthesize strokeNormalColor, strokeSelectedColor;
@synthesize _pageControlStyle, _strokeWidth, diameter, gapWidth;
@synthesize thumbImage, selectedThumbImage;
@synthesize delegate;

#define TAP_VIEW_TAG 12700
#define COLOR_GRAYISHBLUE [UIColor colorWithRed:128/255.0 green:130/255.0 blue:133/255.0 alpha:1]
#define COLOR_GRAY [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1]

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setBackgroundColor:[UIColor clearColor]];
        
        self._strokeWidth = 2;
        self.gapWidth = 10;
        self.diameter = 12;
        self._pageControlStyle = PageControlStyleDefault;
    }
    return self;
}

- (void)onTapped:(UITapGestureRecognizer*)gesture
{
    self._currentPage = [gesture view].tag - TAP_VIEW_TAG;
    if ([self.delegate respondsToSelector:@selector(StyledPageControl:didSelectItemAtIndex:)])
    {
        [self.delegate StyledPageControl:self didSelectItemAtIndex:_currentPage];
    }
    [self setNeedsDisplay];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)drawRect:(CGRect)rect
{
    UIColor *_coreNormalColor, *_coreSelectedColor, *_strokeNormalColor, *_strokeSelectedColor;
    
    if (self.coreNormalColor) _coreNormalColor = self.coreNormalColor;
    else _coreNormalColor = COLOR_GRAYISHBLUE;
    
    if (self.coreSelectedColor) _coreSelectedColor = self.coreSelectedColor;
    else
    {
        if (self._pageControlStyle==PageControlStyleStrokedCircle || self._pageControlStyle==PageControlStyleWithPageNumber)
        {
            _coreSelectedColor = COLOR_GRAYISHBLUE;
        }
        else
        {
            _coreSelectedColor = COLOR_GRAY;
        }
    }
    
    if (self.strokeNormalColor) _strokeNormalColor = self.strokeNormalColor;
    else 
    {
        if (self._pageControlStyle==PageControlStyleDefault && self.coreNormalColor)
        {
            _strokeNormalColor = self.coreNormalColor;
        }
        else
        {
            _strokeNormalColor = COLOR_GRAYISHBLUE;
        }
        
    }
    
    if (self.strokeSelectedColor) _strokeSelectedColor = self.strokeSelectedColor;
    else
    {
        if (self._pageControlStyle==PageControlStyleStrokedCircle || self._pageControlStyle==PageControlStyleWithPageNumber)
        {
            _strokeSelectedColor = COLOR_GRAYISHBLUE;
        }
        else if (self._pageControlStyle==PageControlStyleDefault && self.coreSelectedColor)
        {
            _strokeSelectedColor = self.coreSelectedColor;
        }
        else
        {
            _strokeSelectedColor = COLOR_GRAY;
        }
    }
    
    // Drawing code
    if (hidesForSinglePage && self._numberOfPages==1)
	{
		return;
	}
	
	CGContextRef myContext = UIGraphicsGetCurrentContext();
	
	int gap = self.gapWidth;
    float _diameter = self.diameter - 2*self._strokeWidth;
    
    if (self.pageControlStyle==PageControlStyleThumb)
    {
        if (self.thumbImage && self.selectedThumbImage)
        {
            _diameter = self.thumbImage.size.width;
        }
    }
	
	int total_width = self._numberOfPages*_diameter + (self._numberOfPages-1)*gap;
	
	if (total_width>self.frame.size.width)
	{
		while (total_width>self.frame.size.width)
		{
			_diameter -= 2;
			gap = _diameter + 2;
			while (total_width>self.frame.size.width) 
			{
				gap -= 1;
				total_width = self._numberOfPages*_diameter + (self._numberOfPages-1)*gap;
				
				if (gap==2)
				{
					break;
					total_width = self._numberOfPages*_diameter + (self._numberOfPages-1)*gap;
				}
			}
			
			if (_diameter==2)
			{
				break;
				total_width = self._numberOfPages*_diameter + (self._numberOfPages-1)*gap;
			}
		}
		
		
	}
	
    for (UIView *aView in self.subviews)
    {
        [aView removeFromSuperview];
    }
    
	int i;
	for (i=0; i<self._numberOfPages; i++)
	{
		int x = (self.frame.size.width-total_width)/2 + i*(_diameter+gap);
        CGRect dotRect = CGRectMake(x,(self.frame.size.height-_diameter)/2,_diameter,_diameter);
        
        // add tap view for tap
        UIView *tapView = [[UIView alloc] initWithFrame:CGRectMake(x-gapWidth/2, 0, _diameter+gapWidth, self.frame.size.height)];
        tapView.tag = TAP_VIEW_TAG+i;
        tapView.backgroundColor = [UIColor clearColor];
        tapView.userInteractionEnabled = YES;
        [self addSubview:tapView];
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped:)];
        [tapView addGestureRecognizer:tapGestureRecognizer];
//        [tapGestureRecognizer release];
        
//        [tapView release];
        
        if (self._pageControlStyle==PageControlStyleDefault)
        {
            if (i==_currentPage)
            {
                CGContextSetFillColorWithColor(myContext, [_coreSelectedColor CGColor]);
                CGContextFillEllipseInRect(myContext, dotRect);
                CGContextSetStrokeColorWithColor(myContext, [_strokeSelectedColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
            else
            {
                CGContextSetFillColorWithColor(myContext, [_coreNormalColor CGColor]);
                CGContextFillEllipseInRect(myContext, dotRect);
                CGContextSetStrokeColorWithColor(myContext, [_strokeNormalColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
        }
        else if (self._pageControlStyle==PageControlStyleStrokedCircle)
        {
            CGContextSetLineWidth(myContext, self._strokeWidth);
            if (i==_currentPage)
            {
                CGContextSetFillColorWithColor(myContext, [_coreSelectedColor CGColor]);
                CGContextFillEllipseInRect(myContext, dotRect);
                CGContextSetStrokeColorWithColor(myContext, [_strokeSelectedColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
            else
            {
                CGContextSetStrokeColorWithColor(myContext, [_strokeNormalColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
        }
        else if (self._pageControlStyle==PageControlStyleWithPageNumber)
        {
            CGContextSetLineWidth(myContext, self._strokeWidth);
            if (i==_currentPage)
            {
                int _currentPageDiameter = _diameter*1.6;
                x = (self.frame.size.width-total_width)/2 + i*(_diameter+gap) - (_currentPageDiameter-_diameter)/2;
                CGContextSetFillColorWithColor(myContext, [_coreSelectedColor CGColor]);
                CGContextFillEllipseInRect(myContext, CGRectMake(x,(self.frame.size.height-_currentPageDiameter)/2,_currentPageDiameter,_currentPageDiameter));
                CGContextSetStrokeColorWithColor(myContext, [_strokeSelectedColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, CGRectMake(x,(self.frame.size.height-_currentPageDiameter)/2,_currentPageDiameter,_currentPageDiameter));
            
                NSString *pageNumber = [NSString stringWithFormat:@"%i", i+1];
                CGContextSetFillColorWithColor(myContext, [[UIColor whiteColor] CGColor]);
                [pageNumber drawInRect:CGRectMake(x,(self.frame.size.height-_currentPageDiameter)/2-1,_currentPageDiameter,_currentPageDiameter) withFont:[UIFont systemFontOfSize:_currentPageDiameter-2] lineBreakMode:UILineBreakModeCharacterWrap alignment:UITextAlignmentCenter];
            }
            else
            {
                CGContextSetStrokeColorWithColor(myContext, [_strokeNormalColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
        }
        else if (self._pageControlStyle==PageControlStylePressed1 || self._pageControlStyle==PageControlStylePressed2)
        {
            if (self._pageControlStyle==PageControlStylePressed1)
            {
                CGContextSetFillColorWithColor(myContext, [[UIColor colorWithRed:0 green:0 blue:0 alpha:1] CGColor]);
                CGContextFillEllipseInRect(myContext, CGRectMake(x,(self.frame.size.height-_diameter)/2-1,_diameter,_diameter));
            }
            else if (self._pageControlStyle==PageControlStylePressed2)
            {
                CGContextSetFillColorWithColor(myContext, [[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1] CGColor]);
                CGContextFillEllipseInRect(myContext, CGRectMake(x,(self.frame.size.height-_diameter)/2+1,_diameter,_diameter));
            }
            
            
            if (i==_currentPage)
            {
                CGContextSetFillColorWithColor(myContext, [_coreSelectedColor CGColor]);
                CGContextFillEllipseInRect(myContext, dotRect);
                CGContextSetStrokeColorWithColor(myContext, [_strokeSelectedColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
            else
            {
                CGContextSetFillColorWithColor(myContext, [_coreNormalColor CGColor]);
                CGContextFillEllipseInRect(myContext, dotRect);
                CGContextSetStrokeColorWithColor(myContext, [_strokeNormalColor CGColor]);
                CGContextStrokeEllipseInRect(myContext, dotRect);
            }
        }
        else if (self.pageControlStyle==PageControlStyleThumb)
        {
            if (self.thumbImage && self.selectedThumbImage)
            {
                if (i==_currentPage)
                {
                    [self.selectedThumbImage drawInRect:dotRect];
                }
                else
                {
                    [self.thumbImage drawInRect:dotRect];
                }
            }
        }
	}
}


- (void)dealloc
{
    self.coreSelectedColor = nil;
    self.coreNormalColor = nil;
    self.strokeNormalColor = nil;
    self.strokeSelectedColor = nil;
    
//    [super dealloc];
}

- (PageControlStyle)pageControlStyle
{
    return self._pageControlStyle;
}

- (void)setPageControlStyle:(PageControlStyle)style
{
    self._pageControlStyle = style;
    [self setNeedsDisplay];
}

- (void)setCurrentPage:(int)page
{
    self._currentPage = page;
    [self setNeedsDisplay];
}

- (int)currentPage
{
    return self._currentPage;
}

- (void)setNumberOfPages:(int)numOfPages
{
    self._numberOfPages = numOfPages;
    [self setNeedsDisplay];
}

- (int)numberOfPages
{
    return self._numberOfPages;
}

@end
