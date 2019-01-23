//
//  VCTransactionConfirm.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransactionConfirm.h"
#import "BitsharesClientManager.h"

@interface VCTransactionConfirm ()
{
    BtsppConfirmCallback    _callback;
    BOOL                    _bResultCannelled;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    NSArray*                _dataArray;
    
    NSDictionary*           _transfer_args;
}

@end

@implementation VCTransactionConfirm

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _btnCommit = nil;
    _callback = nil;
}

- (id)initWithTransferArgs:(NSDictionary*)transfer_args callback:(BtsppConfirmCallback)callback
{
    self = [super init];
    if (self) {
        // Custom initialization
        _transfer_args = transfer_args;
        _callback = callback;
        _bResultCannelled = YES;
    }
    return self;
}

- (void)onCancelButtonClicked:(id)sender
{
    _bResultCannelled = YES;
    [self closeModelViewController:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导航条按钮
    [self showLeftButton:NSLocalizedString(@"kBtnCancel", @"取消") action:@selector(onCancelButtonClicked:)];
    
//    [_transfer_args setObject:n_amount forKey:@"kAmount"];
//    [_transfer_args setObject:n_fee_cost forKey:@"kFeeCost"];
//    [_transfer_args setObject:op forKey:@"kOpData"];            //  传递过去，避免再次构造。
//    if (memo){
//        [_transfer_args setObject:memo forKey:@"kMemo"];
//    }
//
    //  TODO:fowallet 各种交易，提示确认内容不同，待处理。目前仅支持转账 TODO:
    id asset = [_transfer_args objectForKey:@"asset"];
    id n_amount = [_transfer_args objectForKey:@"kAmount"];
    id fee_cost = [_transfer_args objectForKey:@"kFeeCost"];
    id fee_asset = [_transfer_args objectForKey:@"fee_asset"];
    assert(asset);
    assert(n_amount);
    assert(fee_cost);
    assert(fee_asset);
    _dataArray = @[
                   @{@"name":NSLocalizedString(@"kVcConfirmTipFrom", @"来自"), @"value":_transfer_args[@"from"][@"name"]},
                   @{@"name":NSLocalizedString(@"kVcConfirmTipTo", @"发往"), @"value":_transfer_args[@"to"][@"name"], @"highlight":@YES},
                   @{@"name":NSLocalizedString(@"kVcConfirmTipAmount", @"数量"), @"value":[NSString stringWithFormat:@"%@%@", n_amount, asset[@"symbol"]]},
                   @{@"name":NSLocalizedString(@"kVcConfirmTipMemo", @"备注"), @"value":[_transfer_args objectForKey:@"kMemo"] ? : @""},
                   @{@"name":NSLocalizedString(@"kVcConfirmTipFee", @"手续费"), @"value":[NSString stringWithFormat:@"%@%@", fee_cost, fee_asset[@"symbol"]]},
                   ];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    UILabel* headerAccountName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, 44)];
    headerAccountName.lineBreakMode = NSLineBreakByWordWrapping;
    headerAccountName.numberOfLines = 1;
    headerAccountName.contentMode = UIViewContentModeCenter;
    headerAccountName.backgroundColor = [UIColor clearColor];
    headerAccountName.textColor = [ThemeManager sharedThemeManager].buyColor;
    headerAccountName.textAlignment = NSTextAlignmentCenter;
    headerAccountName.font = [UIFont boldSystemFontOfSize:26];
    headerAccountName.text = NSLocalizedString(@"kVcConfirmTypeTransfer", @"转账");//TODO:fowallet 交易类型
    [self.view addSubview:headerAccountName];
    
    CGFloat offfset = headerAccountName.bounds.size.height;
    CGRect rect = CGRectMake(0, offfset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offfset);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcConfirmSubmitOK", @"确定")];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  解锁回调
    if (_callback){
        [self delay:^{
            _callback(!_bResultCannelled);
        }];
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    //  确认界面由于时间经过可能又被 lock 了。
    [self GuardWalletUnlocked:^(BOOL unlocked) {
        if (unlocked){
            _bResultCannelled = NO;
            [self closeModelViewController:nil];
        }
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

//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return tableView.sectionHeaderHeight;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    if (section == 0){
//        return 20.0f;
//    }
//    return tableView.sectionFooterHeight;
//}

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
