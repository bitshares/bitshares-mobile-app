//
//  VCProposalAuthorizeEdit.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCProposalAuthorizeEdit.h"
#import "ViewProposalAuthorizedStatusCell.h"
#import "BitsharesClientManager.h"
#import "OrgUtils.h"

enum
{
    kVcAuthorizeList = 0,       //  权限实体列表
    kVcTargetAccount,           //  操作的目标账号
    kVcFeePayingAccount,        //  手续费支付账号
    kVcBtnSubmit,               //  提交按钮
    
    kVcMax
};

@interface VCProposalAuthorizeEdit ()
{
    BOOL                    _isRemove;
    BtsppApproveCallback    _callback;
    BOOL                    _bResultCannelled;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    NSArray*                _dataArray;
    NSArray*                _permissionAccountArray;
    
    NSDictionary*           _proposal;
    
    NSDictionary*           _fee_paying_account;            //  手续费支付账号（提案发起账号）
    NSDictionary*           _target_account;
}

@end

@implementation VCProposalAuthorizeEdit

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _permissionAccountArray = nil;
    _dataArray = nil;
    _btnCommit = nil;
    _callback = nil;
    _fee_paying_account = nil;
    _target_account = nil;
}

- (id)initWithProposal:(id)proposal isRemove:(BOOL)isRemove dataArray:(NSArray*)dataArray callback:(BtsppApproveCallback)callback
{
    self = [super init];
    if (self) {
        // Custom initialization
        _proposal = proposal;
        _isRemove = isRemove;
        _dataArray = dataArray;
        _callback = callback;
        _bResultCannelled = YES;
        _fee_paying_account = nil;
        assert([_dataArray count] > 0);
        //  REMARK：如果只有1个权限实体，则默认选择，2个以上让用户选择。
        if ([_dataArray count] == 1){
            _target_account = [_dataArray firstObject];
        }else{
            _target_account = nil;
        }
        _permissionAccountArray = [[WalletManager sharedWalletManager] getFeePayingAccountList:YES];
        if ([_permissionAccountArray count] > 0){
            //  默认第一个
            _fee_paying_account = [_permissionAccountArray firstObject];
        }
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
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    CGFloat offfset = 0;//headerAccountName.bounds.size.height;
    CGRect rect = CGRectMake(0, offfset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offfset);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  UI - 提交按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kProposalBtnSubmit", @"提交")];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  解锁回调
    if (_callback){
        [self delay:^{
            _callback(!_bResultCannelled, _fee_paying_account, _target_account);
        }];
    }
}

- (NSString*)getSelectTargetAccountTipMessage
{
    if (_isRemove){
        return NSLocalizedString(@"kProposalEditSelectRemoveApproval", @"请选择移除授权账号");
    }else{
        return NSLocalizedString(@"kProposalEditSelectAddApproval", @"请选择添加授权账号");
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    if (!_target_account){
        [OrgUtils showMessage:[self getSelectTargetAccountTipMessage]];
        return;
    }
    if (!_fee_paying_account){
        [OrgUtils showMessage:NSLocalizedString(@"kProposalEditTipsSelectFeePayingAccount", @"请选择手续费支付账号。")];
        return;
    }
    if (![[WalletManager sharedWalletManager] canAuthorizeThePermission:[_fee_paying_account objectForKey:@"active"]]){
        [OrgUtils showMessage:[NSString stringWithFormat:NSLocalizedString(@"kProposalEditTipsNoFeePayingAccountActiveKey", @"没有 %@ 的账号资金私钥，该账号不能用于支付手续费。"), _fee_paying_account[@"name"]]];
        return;
    }
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
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcAuthorizeList){
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcAuthorizeList && indexPath.row == 1){
        id kProcessedData = [_proposal objectForKey:@"kProcessedData"];
        assert(kProcessedData);
        id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
        return 4.0 + 22 * [needAuthorizeHash count];
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcAuthorizeList:
        {
            if (indexPath.row == 0){
                //  获取数据
                id kProcessedData = [_proposal objectForKey:@"kProcessedData"];
                assert(kProcessedData);
                NSInteger passThreshold = [[kProcessedData objectForKey:@"passThreshold"] integerValue];
                NSInteger currThreshold = [[kProcessedData objectForKey:@"currThreshold"] integerValue];
                CGFloat thresholdPercent = [[kProcessedData objectForKey:@"thresholdPercent"] floatValue];
                
                UIColor* detailColor = [ThemeManager sharedThemeManager].textColorMain;
                
                //  动态添加or移除多情况下，更新阈值进度和百分比。
                if (_target_account){
                    id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
                    id item = [needAuthorizeHash objectForKey:_target_account[@"key"]];
                    assert(item);
                    NSInteger threshold = [[item objectForKey:@"threshold"] integerValue];
                    if (_isRemove){
                        currThreshold -= threshold;
                        assert(currThreshold >= 0);
                        detailColor = [ThemeManager sharedThemeManager].sellColor;
                    }else{
                        currThreshold += threshold;
                        detailColor = [ThemeManager sharedThemeManager].buyColor;
                    }
                    thresholdPercent = currThreshold * 100.0f / (CGFloat)passThreshold;
                    if (currThreshold < passThreshold){
                        thresholdPercent = fminf(thresholdPercent, 99.0f);
                    }
                    if (currThreshold > 0){
                        thresholdPercent = fmaxf(thresholdPercent, 1.0f);
                    }
                }
                
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kProposalCellProgress", @"授权进度 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%2d%% (%d/%d)", (int)thresholdPercent, (int)currThreshold, (int)passThreshold];
                cell.detailTextLabel.textColor = detailColor;
                return cell;
            }else{
                static NSString* identify = @"id_proposal_authorized_status_cell";
                ViewProposalAuthorizedStatusCell* cell = (ViewProposalAuthorizedStatusCell *)[tableView dequeueReusableCellWithIdentifier:identify];
                if (!cell)
                {
                    cell = [[ViewProposalAuthorizedStatusCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.backgroundColor = [UIColor clearColor];
                }
                cell.showCustomBottomLine = YES;
                if (_target_account){
                    cell.dynamicInfos = @{@"remove":@(_isRemove), @"key":_target_account[@"key"]};
                }else{
                    cell.dynamicInfos = nil;
                }
                [cell setItem:_proposal];
                return cell;
            }
        }
            break;
        case kVcTargetAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            if (_isRemove){
                cell.textLabel.text = NSLocalizedString(@"kProposalEditCellRemoveApprover", @"移除授权");
            }else{
                cell.textLabel.text = NSLocalizedString(@"kProposalEditCellAddApprover", @"添加授权");
            }
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            if (_target_account){
                cell.detailTextLabel.text = [_target_account objectForKey:@"name"];
                if (_isRemove){
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].sellColor;
                }else{
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                }
            }else{
                cell.detailTextLabel.text = [self getSelectTargetAccountTipMessage];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
            }
            return cell;
        }
            break;
        case kVcFeePayingAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = NSLocalizedString(@"kProposalEditCellPayAccount", @"支付账号");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            if (_fee_paying_account){
                cell.detailTextLabel.text = [_fee_paying_account objectForKey:@"name"];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            }else{
                cell.detailTextLabel.text = NSLocalizedString(@"kProposalEditTipsSelectFeePayingAccount", @"请选择手续费支付账号。");
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
            }
            return cell;
        }
            break;
        case kVcBtnSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcTargetAccount:
            {
                [VcUtils showPicker:self
                       object_lists:_dataArray
                                key:@"name"
                              title:[self getSelectTargetAccountTipMessage]
                           callback:^(id selectItem)
                 {
                    _target_account = selectItem;
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcFeePayingAccount:
            {
                [VcUtils showPicker:self
                       object_lists:_permissionAccountArray
                                key:@"name"
                              title:NSLocalizedString(@"kProposalEditTipsSelectFeePayingAccount", @"请选择手续费支付账号。")
                           callback:^(id selectItem)
                 {
                    _fee_paying_account = selectItem;
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcBtnSubmit:
                [self onCommitCore];
                break;
            default:
                break;
        }
    }];
}

@end
