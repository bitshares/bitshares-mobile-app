//
//  ViewBackground.m
//  oplayer
//
//  Created by SYALON on 13-11-26.
//
//

#import "ViewBackground.h"
#import "MyNavigationController.h"

@interface ViewBackground()
{
    MyNavigationController* _owner;
}

@end

@implementation ViewBackground

- (void)dealloc
{
    [_owner clearBackgroundView];
}

- (id)initWithFrame:(CGRect)frame owner:(MyNavigationController*)pOwner
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _owner = pOwner;
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

@end
