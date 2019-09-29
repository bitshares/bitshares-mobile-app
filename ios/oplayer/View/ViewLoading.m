//
//  ViewLoading.m
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import "ViewLoading.h"
#import "ThemeManager.h"

@interface ViewLoading ()
{
    UIActivityIndicatorView*    _activityView;
    UILabel*                    _lbText;
}

@end

@implementation ViewLoading

@synthesize activityView = _activityView;
@synthesize textLabel = _lbText;

- (void)dealloc
{
    if (_activityView)
    {
        [_activityView stopAnimating];
        _activityView = nil;
    }
}

- (id)initWithText:(NSString*)pText
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
        _activityView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
//        [_activityView setActivityIndicatorViewStyle: UIActivityIndicatorViewStyleGray];
        _activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;//TODO:fowallet 根据主题风格色调决定颜色
        [self addSubview:_activityView];
//        [_activityView release];
        [_activityView startAnimating];
        
        _lbText = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbText.textAlignment = NSTextAlignmentCenter;
        _lbText.textColor = [ThemeManager sharedThemeManager].textColorGray;
        _lbText.font = [UIFont systemFontOfSize:16];
        _lbText.text = pText;
        [self addSubview:_lbText];
//        [_lbText release];
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

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!self.superview)
        return;
    
    self.frame = self.superview.bounds;
    
    CGSize size = self.bounds.size;
    size = [_lbText.text sizeWithFont:_lbText.font constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat xoffset = (self.bounds.size.width - size.width - 32) / 2.0f;
    _activityView.frame = CGRectMake(xoffset, 0, 32, self.bounds.size.height);
//    _activityView.center = CGPointMake(xoffset + 16, self.bounds.size.height / 2.0f);
    _lbText.frame = CGRectMake(xoffset + 32, (self.bounds.size.height - size.height) / 2.0f, size.width, size.height);
}

@end
