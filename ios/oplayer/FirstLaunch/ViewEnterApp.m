//
//  ViewEnterApp.m
//  oplayer
//
//  Created by SYALON on 13-11-14.
//
//

#import "ViewEnterApp.h"
#import "UIDevice+Helper.h"

@implementation ViewEnterApp

- (id)initWithFrame:(CGRect)frame owner:(id)owner
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        //  图片
        UIImageView* backImage = [[UIImageView alloc] initWithFrame:frame];
        [backImage setContentMode:UIViewContentModeScaleAspectFill];
        [backImage setImage:[UIImage imageNamed:@"first3"]];
        [self addSubview:backImage];
        
        //  按钮
        UIButton* btn_login = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage imageNamed:@"firstenterbutton"];
        [btn_login setBackgroundImage:btn_image forState:UIControlStateNormal];
        [btn_login setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn_login.userInteractionEnabled = YES;
        [btn_login addTarget:owner action:@selector(enterApp) forControlEvents:UIControlEventTouchUpInside];
        
        CGSize screen = [UIScreen mainScreen].bounds.size;
        
        CGFloat offset = [UIDevice isRunningOniPad] ? screen.height * 0.9f : screen.height * 0.83f;
        
        btn_login.frame = CGRectMake((frame.size.width - btn_image.size.width) / 2.0, offset, btn_image.size.width, btn_image.size.height);
        [self addSubview:btn_login];
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
