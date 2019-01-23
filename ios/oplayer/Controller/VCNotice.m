//
//  VCAbout.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCNotice.h"
#import "NativeAppDelegate.h"

@interface VCNotice ()
{
    NSArray* notice;
}

@end

@implementation VCNotice

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithNotice:(NSArray*)data
{
    self = [super init];
    if (self) {
        notice = [[NSArray alloc] initWithArray:data];
    }
    return self;
}

-(void)dealloc
{
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    UITextView* tv_main;
    tv_main = [[UITextView alloc] initWithFrame:[self rectWithoutNavi]];
    tv_main.dataDetectorTypes = UIDataDetectorTypeAll;
    [tv_main setFont:[UIFont systemFontOfSize:16]];
    [self.view addSubview:tv_main];
//    [tv_main release];
    tv_main.editable = NO;
    
    //  设置公告内容
    tv_main.text = [notice objectAtIndex:4];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
