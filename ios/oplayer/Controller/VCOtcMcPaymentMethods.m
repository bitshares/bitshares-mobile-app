//
//  VCOtcMcPaymentMethods.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcPaymentMethods.h"
#import "OtcManager.h"

enum
{
    kVcSubRowAlipay = 0,
    kVcSubRowBankCard,
    
    kVcSubMax
};

@interface VCOtcMcPaymentMethods ()
{
    NSDictionary*           _auth_info;
    NSDictionary*           _merchant_detail;
    UITableViewBase*        _mainTableView;
    NSArray*                _dataArray;
    
    BOOL                    _querying;
    
    BOOL                    _aliPaySwitch;
    BOOL                    _bankcardPaySwitch;
}

@end

@implementation VCOtcMcPaymentMethods

-(void)dealloc
{
    _auth_info = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAuthInfo:(id)auth_info merchant_detail:(id)merchant_detail
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _merchant_detail = merchant_detail;
        _dataArray = nil;
        _querying = YES;
    }
    return self;
}

- (void)onQueryPaymentMethodsResponsed:(id)responsed
{
    id data = [responsed objectForKey:@"data"];
    
    _aliPaySwitch = [[data objectForKey:@"aliPaySwitch"] boolValue];
    _bankcardPaySwitch = [[data objectForKey:@"bankcardPaySwitch"] boolValue];
    
    _querying = NO;
    [self refreshView];
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (void)queryPaymentMethods
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryMerchantPaymentMethods:[otc getCurrentBtsAccount]] then:^id(id data) {
        [self hideBlockView];
        [self onQueryPaymentMethodsResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  数据
    _dataArray = @[
        @(kVcSubRowAlipay), @(kVcSubRowBankCard)
    ];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  查询
    [self queryPaymentMethods];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

#pragma mark- for switch action
- (void)resetSwitchToValue:(UISwitch*)sender value:(BOOL)value
{
    //  重置switch&刷新tableview（不然UISwitch样式不会更新）
    sender.on = value;
    [self refreshView];
}

-(void)onSwitchAction:(UISwitch*)sender
{
    BOOL bSwitchIsOn = sender.on;
    
    id newAliPaySwitch = nil;
    id newBankcardPaySwitch = nil;
    switch (sender.tag) {
        case kVcSubRowAlipay:
        {
            newAliPaySwitch = @(bSwitchIsOn);
            if (!bSwitchIsOn && !_bankcardPaySwitch) {
                [self resetSwitchToValue:sender value:!bSwitchIsOn];
                [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipCannotCloseAll", @"不能同时关闭所有付款方式。")];
                return;
            }
        }
            break;
        case kVcSubRowBankCard:
        {
            newBankcardPaySwitch = @(bSwitchIsOn);
            if (!bSwitchIsOn && !_aliPaySwitch) {
                [self resetSwitchToValue:sender value:!bSwitchIsOn];
                [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipCannotCloseAll", @"不能同时关闭所有付款方式。")];
                return;
            }
        }
            break;
        default:
            break;
    }
    
    //  先解锁
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            OtcManager* otc = [OtcManager sharedOtcManager];
            [[[otc updateMerchantPaymentMethods:[otc getCurrentBtsAccount]
                                   aliPaySwitch:newAliPaySwitch
                              bankcardPaySwitch:newBankcardPaySwitch] then:^id(id data)
              {
                [self hideBlockView];
                if (newAliPaySwitch) {
                    _aliPaySwitch = bSwitchIsOn;
                    if (bSwitchIsOn) {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipEnableAlipay", @"已开启支付宝付款。")];
                    } else {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipDisableAlipay", @"已关闭支付宝付款。")];
                    }
                }
                if (newBankcardPaySwitch) {
                    _bankcardPaySwitch = bSwitchIsOn;
                    if (bSwitchIsOn) {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipEnableBankcardPay", @"已开启银行卡付款。")];
                    } else {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcPmSubmitTipDisableBankcardPay", @"已关闭银行卡付款。")];
                    }
                }
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [otc showOtcError:error];
                [self resetSwitchToValue:sender value:!bSwitchIsOn];
                return nil;
            }];
        } else {
            [self resetSwitchToValue:sender value:!bSwitchIsOn];
        }
    }];
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.showCustomBottomLine = YES;
    cell.textLabel.textColor = theme.textColorMain;
    
    NSInteger rowType = [[_dataArray objectAtIndex:indexPath.section] integerValue];
    
    //  状态开关
    UISwitch* pSwitch = nil;
    if (!_querying) {
        pSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        pSwitch.tintColor = theme.textColorGray;        //  边框颜色
        pSwitch.thumbTintColor = theme.textColorGray;   //  按钮颜色
        pSwitch.onTintColor = theme.textColorHighlight; //  开启时颜色
        pSwitch.tag = rowType;
        [pSwitch addTarget:self action:@selector(onSwitchAction:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = pSwitch;
    }
    
    switch (rowType) {
        case kVcSubRowAlipay:
        {
            if (pSwitch) {
                pSwitch.on = _aliPaySwitch;
            }
            cell.textLabel.text = NSLocalizedString(@"kOtcAdPmNameAlipay", @"支付宝");
            cell.imageView.image = [UIImage imageNamed:@"iconPmAlipay"];
        }
            break;
        case kVcSubRowBankCard:
        {
            if (pSwitch) {
                pSwitch.on = _bankcardPaySwitch;
            }
            cell.textLabel.text = NSLocalizedString(@"kOtcAdPmNameBankCard", @"银行卡");
            cell.imageView.image = [UIImage imageNamed:@"iconPmBankCard"];
        }
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
