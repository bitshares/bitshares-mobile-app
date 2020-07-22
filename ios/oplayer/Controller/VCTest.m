//
//  VCTest.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCTest.h"

#import "NativeAppDelegate.h"
#import "VCBtsppSdkWebView.h"

@interface VCTest ()
{
    UITableView*    _mainTableView;
    NSArray*        _textArray;
}

@end

@implementation VCTest

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        // Custom initialization
        _textArray = [[NSArray alloc] initWithObjects:@"test", nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutTabbar] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_textArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identify = @"vctestview";
    
    UITableViewCellBase* cell = (UITableViewCellBase*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = [_textArray objectAtIndex:indexPath.row];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.row) {
        case 0:
        {
            VCBtsppSdkWebView* vc = [[VCBtsppSdkWebView alloc] initWithUrl:@"http://btspp.io/test/test01.html"];
            [self pushViewController:vc vctitle:@"测试webview" backtitle:kVcDefaultBackTitleName];
        }
            break;
        default:
            break;
    }
}

@end
