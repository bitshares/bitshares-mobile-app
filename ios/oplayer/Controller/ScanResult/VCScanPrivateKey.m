//
//  VCScanPrivateKey.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanPrivateKey.h"
#import "BitsharesClientManager.h"

@interface VCScanPrivateKey ()
{
    NSString*               _priKey;
    NSString*               _pubKey;
    NSDictionary*           _fullAccountData;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    NSArray*                _dataArray;
}

@end

@implementation VCScanPrivateKey

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _btnCommit = nil;
}

- (id)initWithPriKey:(NSString*)priKey pubKey:(NSString*)pubKey fullAccountData:(NSDictionary*)fullAccountData;
{
    self = [super init];
    if (self) {
        _priKey = priKey;
        _pubKey = pubKey;
        _fullAccountData = fullAccountData;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    id account = [_fullAccountData objectForKey:@"account"];
    assert(account);
    
    NSMutableArray* priKeyTypeArray = [NSMutableArray array];
    id owner_key_auths = [[account objectForKey:@"owner"] objectForKey:@"key_auths"];
    if (owner_key_auths && [owner_key_auths count] > 0){
        for (id pair in owner_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:@"账号私钥"];
                break;
            }
        }
    }
    id active_key_auths = [[account objectForKey:@"active"] objectForKey:@"key_auths"];
    if (active_key_auths && [active_key_auths count] > 0){
        for (id pair in active_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:@"资金私钥"];
                break;
            }
        }
    }
    id memo_key = [[account objectForKey:@"options"] objectForKey:@"memo_key"];
    if (memo_key && [memo_key isEqualToString:_pubKey]){
        [priKeyTypeArray addObject:@"备注私钥"];
    }
    assert([priKeyTypeArray count] > 0);
    
    _dataArray = @[
                   @{@"name":@"ID", @"value":[account objectForKey:@"id"]},
                   @{@"name":@"账号", @"value":[account objectForKey:@"name"]},
                   @{@"name":@"私钥类型", @"value":[priKeyTypeArray componentsJoinedByString:@" "], @"highlight":@YES},
                   ];
    
//    CGRect screenRect = [[UIScreen mainScreen] bounds];
//    UILabel* headerAccountName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, 44)];
//    headerAccountName.lineBreakMode = NSLineBreakByWordWrapping;
//    headerAccountName.numberOfLines = 1;
//    headerAccountName.contentMode = UIViewContentModeCenter;
//    headerAccountName.backgroundColor = [UIColor clearColor];
//    headerAccountName.textColor = [ThemeManager sharedThemeManager].buyColor;
//    headerAccountName.textAlignment = NSTextAlignmentCenter;
//    headerAccountName.font = [UIFont boldSystemFontOfSize:26];
//    headerAccountName.text = @"转账";//TODO:fowallet 交易类型
//    [self.view addSubview:headerAccountName];
//    [self rectWithoutNavi]
//    CGFloat offfset = headerAccountName.bounds.size.height;
//    CGRect rect = CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offfset);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  TODO:fowallet多语言
    _btnCommit = [self createCellLableButton:@"立即导入"];
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    //  确认界面由于时间经过可能又被 lock 了。
    [self GuardWalletUnlocked:^(BOOL unlocked) {
//        if (unlocked){
//            _bResultCannelled = NO;
//            [self closeModelViewController:nil];
//        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return [_dataArray count];
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        id item = [_dataArray objectAtIndex:indexPath.row];
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.backgroundColor = [UIColor clearColor];
        cell.showCustomBottomLine = YES;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = [item objectForKey:@"name"];
        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        cell.detailTextLabel.text = [item objectForKey:@"value"];
        if ([[item objectForKey:@"highlight"] boolValue]){
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
        }else{
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        }
        return cell;
    }else{
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1){
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onCommitCore];
        }];
    }
}

@end
