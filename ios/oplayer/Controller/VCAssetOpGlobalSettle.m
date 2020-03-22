//
//  VCAssetOpGlobalSettle.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpGlobalSettle.h"
#import "ViewAdvTextFieldCell.h"

#import "VCSearchNetwork.h"
#import "ViewTipsInfoCell.h"

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecPrice,            //  价格
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

@interface VCAssetOpGlobalSettle ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前选中资产
    NSDictionary*               _bitasset_data;
    
    UITableViewBase*            _mainTableView;
    ViewAdvTextFieldCell*       _cell_price;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbCommit;
}

@end

@implementation VCAssetOpGlobalSettle

-(void)dealloc
{
    _result_promise = nil;
    _cell_price = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _lbCommit = nil;
    _bitasset_data = nil;
    _curr_selected_asset = nil;
}

- (id)initWithCurrAsset:(id)curr_asset bitasset_data:(id)bitasset_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        assert(curr_asset && bitasset_data);
        _result_promise = result_promise;
        _curr_selected_asset = curr_asset;
        _bitasset_data = bitasset_data;
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (NSString*)genTransferTipsMessage
{
    return NSLocalizedString(@"kVcAssetOpGsUiTips", @"【温馨提示】\n全局清算会以指定价格强制关闭所有债仓，此操作不可逆，请谨慎操作。");
}

- (void)onPriceTailerButtonClicked:(UIButton*)sender
{
    //  REMARK：tag为水平控件索引值，第一个为 asset name、第二个为 ｜
    if (sender.tag == 2) {
        //  真值
        _cell_price.mainTextfield.text = @"1";
    } else {
        //  假值
        _cell_price.mainTextfield.text = @"0";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    id back_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:_bitasset_data[@"options"][@"short_backing_asset"]];
    assert(back_asset);
    //  UI - 价格输入框
    _cell_price = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kVcAssetOpGsCellTitlePrice", @"价格")
                                                  placeholder:NSLocalizedString(@"kVcAssetOpGsCellPlaceholderPrice", @"请输入全局清算价格")
                                             decimalPrecision:8];
    if ([[_bitasset_data objectForKey:@"is_prediction_market"] boolValue]) {
        //  预测市场 添加快捷按钮 0 和 1。
        [_cell_price genTailerAssetNameAndButtons:back_asset[@"symbol"]
                                     button_names:@[NSLocalizedString(@"kVcAssetOpGsCellTailerBtnPmAsTrue", @"预测为真"),
                                                    NSLocalizedString(@"kVcAssetOpGsCellTailerBtnPmAsFalse", @"预测为假")]
                                           target:self action:@selector(onPriceTailerButtonClicked:)];
    } else {
        [_cell_price genTailerAssetName:back_asset[@"symbol"]];
    }
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcAssetOpGsSubmitBtnName", @"全局清算")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_cell_price endInput];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecOpAsst) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecPrice:
            return _cell_price.cellHeight;
        case kVcSecTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
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
    switch (indexPath.section) {
        case kVcSecOpAsst:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAsset", @"资产");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.textLabel.text = [_curr_selected_asset objectForKey:@"symbol"];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.textColor = theme.textColorGray;
            }
            return cell;
        }
            break;
        case kVcSecPrice:
            return _cell_price;
            
        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSubmitClicked
{
    id str_price = _cell_price.mainTextfield.text;
    if (!str_price || [str_price isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpGsSubmitTipsPleaseInputPrice", @"请输入全局清算价格。")];
        return;
    }
    
    id n_price = [OrgUtils auxGetStringDecimalNumberValue:_cell_price.mainTextfield.text];
    
    id back_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:_bitasset_data[@"options"][@"short_backing_asset"]];
    assert(back_asset);
    
    id value = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpGsSubmitAskForGs", @"您确认以 %@ %@/%@ 的价格发起全局清算吗？\n\n※ 此操作不可逆，请谨慎操作。"),
                n_price, back_asset[@"symbol"], _curr_selected_asset[@"symbol"]];;
    
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAssetGlobalSettleCore:n_price back_asset:back_asset];
                }
            }];
        }
    }];
}

/*
 *  (private) 执行全局清算操作
 */
- (void)_execAssetGlobalSettleCore:(NSDecimalNumber*)n_price back_asset:(NSDictionary*)back_asset
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    
    NSInteger precision_back_asset = [[back_asset objectForKey:@"precision"] integerValue];
    NSInteger precision_settle_asset = [[_curr_selected_asset objectForKey:@"precision"] integerValue];
    
    //  REMARK：价格精度保留最低8位小数
    NSInteger final_back_precision = MAX(precision_back_asset, 8);
    id n_amount_back = [NSString stringWithFormat:@"%@", [n_price decimalNumberByMultiplyingByPowerOf10:final_back_precision]];
    
    //  待清算资产精度 = 自身精度 + 背书资产额外增加的精度(>=0)。
    NSInteger final_settle_precision = precision_settle_asset + (final_back_precision - precision_back_asset);
    id n_amount_settle = [NSString stringWithFormat:@"%@", [[NSDecimalNumber one] decimalNumberByMultiplyingByPowerOf10:final_settle_precision]];
    assert([n_amount_settle unsignedLongLongValue] > 0);
    
    //  构造OP
    id op = @{
        @"fee":@{@"amount":@0, @"asset_id":chainMgr.grapheneCoreAssetID},
        @"issuer":op_account[@"id"],
        @"asset_to_settle":_curr_selected_asset[@"id"],
        @"settle_price":@{
                @"base":@{@"asset_id":_curr_selected_asset[@"id"], @"amount":@([n_amount_settle unsignedLongLongValue])},
                @"quote":@{@"asset_id":back_asset[@"id"], @"amount":@([n_amount_back unsignedLongLongValue])}
        },
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_asset_global_settle
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:op_account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] assetGlobalSettle:op] then:(^id(id data) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpGsSubmitTipsOK", @"全局清算成功。")];
            //  [统计]
            [OrgUtils logEvents:@"txAssetGlobalSettleFullOK" params:@{@"account":op_account[@"id"]}];
            //  返回上一个界面并刷新
            if (_result_promise) {
                [_result_promise resolve:@YES];
            }
            [self closeOrPopViewController];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txAssetGlobalSettleFailed" params:@{@"account":op_account[@"id"]}];
            return nil;
        })];
    }];
}

@end
