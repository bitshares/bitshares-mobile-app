//
//  VCAssetOpStakeVote.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpStakeVote.h"
#import "VCSearchNetwork.h"
#import "ViewTipsInfoCell.h"

//  #ticket.hpp
enum ticket_type
{
  liquid            = 0,
  lock_180_days     = 1,
  lock_360_days     = 2,
  lock_720_days     = 3,
  lock_forever      = 4,
  TICKET_TYPE_COUNT = 5
};

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecLockType,         //  锁仓类型
    kVcSecAmount,           //  锁仓数量
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

@interface VCAssetOpStakeVote ()
{
    WsPromiseObject*            _result_promise;
    
    NSInteger                   _ticket_type;           //  锁仓类型
    
    NSDictionary*               _curr_asset;            //  当前资产
    NSDictionary*               _full_account_data;     //  REMARK：提取手续费池等部分操作该参数为nil。
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    ViewTextFieldAmountCell*    _tf_amount;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbCommit;
}

@end

@implementation VCAssetOpStakeVote

-(void)dealloc
{
    _result_promise = nil;
    _nCurrBalance = nil;
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _ticket_type = liquid;
        _result_promise = result_promise;
        _curr_asset = curr_asset;
        _full_account_data = full_account_data;
        [self _auxGenCurrBalanceAndBalanceAsset];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

/*
 *  (private) 生成当前余额 以及 余额对应的资产。
 */
- (void)_auxGenCurrBalanceAndBalanceAsset
{
    assert(_full_account_data);
    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
}

- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_curr_asset objectForKey:@"symbol"];
    if (not_enough) {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@(%@)",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol,
                           NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
        [_tf_amount drawUI_titleValue:value color:theme.tintColor];
    } else {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol];
        [_tf_amount drawUI_titleValue:value color:theme.textColorMain];
    }
}

- (NSString*)genTransferTipsMessage
{
    return NSLocalizedString(@"kVcAssetOpStakeVoteUiTips", @"关于锁仓的描述信息");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 数量输入框
    _tf_amount = [[ViewTextFieldAmountCell alloc] initWithTitle:NSLocalizedString(@"kOtcMcAssetTransferCellLabelAmount", @"数量")
                                                    placeholder:NSLocalizedString(@"kVcAssetOpStakeVoteCellPlaceholderAmount", @"请输入锁仓数量")
                                                         tailer:[_curr_asset objectForKey:@"symbol"]];
    _tf_amount.delegate = self;
    [self _drawUI_Balance:NO];
    
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
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcAssetOpStakeVoteBtnName", @"创建锁仓")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount endInput];
}

#pragma mark- for UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[_curr_asset objectForKey:@"precision"] integerValue]];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecOpAsst || section == kVcSecLockType) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
        case kVcSecLockType:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecAmount:
            return 28.0f + 44.0f;
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

+ (NSString*)getTicketTypeDesc:(NSInteger)ticket_type
{
    switch (ticket_type) {
        case lock_180_days:
            return NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeDesc180", @"180天");
        case lock_360_days:
            return NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeDesc360", @"360天");
        case lock_720_days:
            return NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeDesc720", @"720天");
        case lock_forever:
            return NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeDescForever", @"永久");
        default:
            break;
    }
    return @"";
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
                //  REMARK：这里显示选中资产名称，而不是余额资产名称。
                cell.textLabel.text = [_curr_asset objectForKey:@"symbol"];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.textColor = theme.textColorGray;
            }
            return cell;
        }
            break;
        case kVcSecLockType:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kVcAssetOpStakeVoteCellTitleTicketType", @"类型");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                if (_ticket_type == liquid) {
                    cell.textLabel.text = NSLocalizedString(@"kVcAssetOpStakeVoteCellValueLiquid", @"请选择锁仓类型");
                    cell.textLabel.textColor = theme.textColorGray;
                } else {
                    cell.textLabel.text = [[self class] getTicketTypeDesc:_ticket_type];
                    cell.textLabel.textColor = theme.textColorMain;
                }
            }
            return cell;
        }
            break;
        case kVcSecAmount:
            return _tf_amount;
            
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
            case kVcSecOpAsst:
                [self onSelectAssetClicked];
                break;
            case kVcSecLockType:
                [self onSelectTicketType];
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSelectAssetClicked
{
    //  REMARK:6.2 只支持锁BTS，不用切换。
    
    //  TODO:4.0 考虑默认备选列表？
//    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:kSearchType callback:^(id asset_info) {
//        if (asset_info){
//            NSString* new_id = [asset_info objectForKey:@"id"];
//            NSString* old_id = [_curr_asset objectForKey:@"id"];
//            if (![new_id isEqualToString:old_id]) {
//                _curr_asset = asset_info;
//                //  切换资产后重新输入
//                [self _auxGenCurrBalanceAndBalanceAsset];
//                [_tf_amount clearInputTextValue];
//                [_tf_amount drawUI_newTailer:[_curr_asset objectForKey:@"symbol"]];
//                [self _drawUI_Balance:NO];
//                [_mainTableView reloadData];
//            }
//        }
//    }];
//
//    [self pushViewController:vc
//                     vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
//                   backtitle:kVcDefaultBackTitleName];
}

- (void)onSelectTicketType
{
    [self endInput];
    
    id items = @[
        @{@"title":NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeList180", @"锁仓180天"),
          @"type":@(lock_180_days)},
        @{@"title":NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeList360", @"锁仓360天"),
          @"type":@(lock_360_days)},
        @{@"title":NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeList720", @"锁仓720天"),
          @"type":@(lock_720_days)},
        @{@"title":NSLocalizedString(@"kVcAssetOpStakeVoteTicketTypeListForever", @"永久锁仓"),
          @"type":@(lock_forever)},
    ];
    
    NSInteger defaultIndex = 0;
    NSInteger index = 0;
    for (id item in items) {
        if ([[item objectForKey:@"type"] integerValue] == _ticket_type) {
            defaultIndex = index;
            break;
        }
        ++index;
    }
    
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:nil
                                                             items:items
                                                           itemkey:@"title"
                                                      defaultIndex:defaultIndex] then:(^id(id result) {
        if (result){
            NSInteger type = [[result objectForKey:@"type"] integerValue];
            if (type != _ticket_type) {
                _ticket_type = type;
                [_mainTableView reloadData];
            }
        }
        return nil;
    })];
}

- (void)onSubmitClicked
{
    if (_ticket_type == liquid) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpStakeVoteSubmitTipsPleaseSelectTicketType", @"请选择锁仓类型。")];
        return;
    }
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpStakeVoteSubmitTipsPleaseInputAmount", @"请输入锁仓数量。")];
        return;
    }
    
    if ([_nCurrBalance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    //  二次确认
    id value = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpStakeVoteSubmitAskForCreateTicket", @"您确认锁仓 %@ %@ 吗？\n\n锁仓时间：%@\n\n※ 此操作会导致资产临时或永久锁定，请谨慎操作。"),
                n_amount, _curr_asset[@"symbol"], [[self class] getTicketTypeDesc:_ticket_type]];
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAssetStakeVoteCore:n_amount];
                }
            }];
        }
    }];
}

/*
 *  (private) 执行锁仓投票
 */
- (void)_execAssetStakeVoteCore:(NSDecimalNumber*)n_amount
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[_curr_asset[@"precision"] integerValue]]];
    id op = @{
        @"fee":@{@"amount":@0, @"asset_id":chainMgr.grapheneCoreAssetID},
        @"account":op_account[@"id"],
        @"target_type":@(_ticket_type),
        @"amount":@{@"amount":@([n_amount_pow unsignedLongLongValue]), @"asset_id":_curr_asset[@"id"]}
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_ticket_create
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:op_account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] ticketCreate:op] then:(^id(id data) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpStakeVoteSubmitTipOK", @"创建锁仓成功。")];
            //  [统计]
            [OrgUtils logEvents:@"txAssetStakeVoteFullOK" params:@{@"account":op_account[@"id"]}];
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
            [OrgUtils logEvents:@"txAssetStakeVoteFailed" params:@{@"account":op_account[@"id"]}];
            return nil;
        })];
    }];
}

#pragma mark- for ViewTextFieldAmountCellDelegate
- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue
{
    [self onAmountChanged:newValue];
}

- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onTailerClicked:(UIButton*)sender
{
    [_tf_amount setInputTextValue:[OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO]];
    [self onAmountChanged:nil];
}

/**
 *  (private) 划转数量发生变化。
 */
- (void)onAmountChanged:(NSDecimalNumber*)newValue
{
    if (!newValue) {
        newValue = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    }
    [self _drawUI_Balance:[_nCurrBalance compare:newValue] < 0];
}

@end
