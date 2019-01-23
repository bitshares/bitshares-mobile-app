//
//  ViewMovableTextView.m
//  oplayer
//
//  Created by SYALON on 13-12-5.
//
//

#import "ViewMovableTextView.h"

@implementation ViewMovableTextView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

//- (void)layoutSubviews;
//{
//    [super layoutSubviews];
//}

- (void) setContentOffset:(CGPoint)s
{
    if (self.frame.size.height >= self.contentSize.height)
        s.y = 0;
    
    [super setContentOffset:s];
}

@end
