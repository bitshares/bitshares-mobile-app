//
//  VCScanNormalString.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCScanNormalString.h"
#import "NativeAppDelegate.h"
#import "AppCacheManager.h"

@interface VCScanNormalString ()
{
    NSString* _result;
}

@end

@implementation VCScanNormalString

- (id)initWithResult:(NSString*)result
{
    self = [super init];
    if (self) {
        _result = result;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    UITextView* tv_main = [[UITextView alloc] initWithFrame:[self rectWithoutNavi]];
    tv_main.dataDetectorTypes = UIDataDetectorTypeAll;
    [tv_main setFont:[UIFont systemFontOfSize:16]];
    [self.view addSubview:tv_main];
    tv_main.editable = NO;
    tv_main.backgroundColor = [UIColor clearColor];
    tv_main.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    tv_main.text = _result;
}

-(void)dealloc
{
    _result = nil;
}

@end
