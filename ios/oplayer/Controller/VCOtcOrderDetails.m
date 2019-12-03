//
//  VCOtcOrderDetails.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcOrderDetails.h"
#import "OrgUtils.h"

#import "ViewOtcOrderDetailStatus.h"
#import "ViewOtcOrderDetailBasicInfo.h"
#import "ViewOtcPaymentIconAndTextCell.h"
#import "ViewTipsInfoCell.h"

#import "OtcManager.h"

enum
{
    kVcSecOrderStatus = 0,  //  状态信息
    kVcSecOrderInfo,        //  订单基本信息：价格单价等
    kvcSecPaymentInfo,      //  收付款信息（用户买入时需要显示）
    kVcSecOrderDetailInfo,  //  订单详细信息：商家名、订单号等
    kVcSecCellTips,         //  转账时：附加系统提示
};

enum
{
    kVcSubMerchantRealName = 0, //  商家实名
    kVcSubMerchantNickName,     //  商家昵称
    kVcSubOrderID,              //  订单号
    kVcSubOrderTime,            //  下单日期
    kVcSubPaymentMethod,        //  付款方式 or 收款方式
    
    kVcSubPaymentTipsSameName,  //  相同名字账号付款提示
    kVcSubPaymentMethodSelect,  //  选择收款方式
    kVcSubPaymentRealName,      //  收款人
    kVcSubPaymentAccount,       //  收款账号（银行卡号、微信支付宝账号等）
    kVcSubPaymentBankName,      //  银行名（银行卡存在）
    kVcSubPaymentQrCode,        //  二维码（支付宝微信可能存在）
};

@interface VCOtcOrderDetails ()
{
    NSDictionary*           _orderDetails;
    NSDictionary*           _authInfos;                 //  可能为空，一般需要付款时才存在。
    NSDictionary*           _statusInfos;
    
    NSDictionary*           _currSelectedPaymentMethod; //  买单情况下，当前选中的卖家收款方式。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _sectionDataArray;
    ViewTipsInfoCell*       _cell_tips;                 //
    NSMutableArray*         _btnArray;
}

@end

@implementation VCOtcOrderDetails

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _sectionDataArray = nil;
    _orderDetails = nil;
    _authInfos = nil;
    _btnArray = nil;
    _currSelectedPaymentMethod = nil;
}

- (id)initWithOrder:(id)order details:(id)order_details auth:(id)auth_info
{
    self = [super init];
    if (self) {
        _orderDetails = order_details;
        _authInfos = auth_info;
        _sectionDataArray = [NSMutableArray array];
        _btnArray = [NSMutableArray array];
        _cell_tips = nil;
        _statusInfos = [OtcManager auxGenUserOrderStatusAndActions:order_details];
        _currSelectedPaymentMethod = nil;
        [self _initUIData];
    }
    return self;
}

- (id)_genPaymentRows:(id)payment_info target_array:(NSMutableArray*)target_array
{
    assert(payment_info);
    [target_array removeAllObjects];
    
    _currSelectedPaymentMethod = payment_info;
    [target_array addObject:@(kVcSubPaymentTipsSameName)];
    [target_array addObject:@(kVcSubPaymentMethodSelect)];
    [target_array addObject:@(kVcSubPaymentRealName)];
    [target_array addObject:@(kVcSubPaymentAccount)];
    
    if ([[payment_info objectForKey:@"type"] integerValue] == eopmt_bankcard) {
        //  开户银行
        NSString* bankName = [payment_info objectForKey:@"bankName"];
        if (bankName && ![bankName isEqualToString:@""]) {
            [target_array addObject:@(kVcSubPaymentBankName)];
        }
    } else {
        //  收款二维码
        NSString* qrCode = [payment_info objectForKey:@"qrCode"];
        if (qrCode && ![qrCode isEqualToString:@""]) {
            [target_array addObject:@(kVcSubPaymentQrCode)];
        }
    }
    
    return target_array;
}

/*
 *  (private) 动态初始化UI需要显示的字段信息按钮等数据。
 */
- (void)_initUIData
{
    //  clean
    [_sectionDataArray removeAllObjects];
    [_btnArray removeAllObjects];
    
    //  UI - 订单基本状态
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderStatus)}];
    
    //  UI - 订单金额等基本信息
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderInfo)}];
    
    //  UI - 付款信息
    id payMethod = [_orderDetails objectForKey:@"payMethod"];
    if (payMethod && [payMethod isKindOfClass:[NSArray class]] && [payMethod count] > 0) {
        [_sectionDataArray addObject:@{@"type":@(kvcSecPaymentInfo),
                                       @"rows":[self _genPaymentRows:[payMethod firstObject] target_array:[NSMutableArray array]]}];
    }
    
    //  UI - 订单详细信息（订单号等）
    //  TODO:2.9 test  data
    id orderDetailRows = [[[NSMutableArray array] ruby_apply:^(id obj) {
        [obj addObject:@(kVcSubMerchantRealName)];
        [obj addObject:@(kVcSubMerchantNickName)];
        [obj addObject:@(kVcSubOrderID)];
        [obj addObject:@(kVcSubOrderTime)];
        //  TODO:2.9
        NSString* payAccount = [_orderDetails objectForKey:@"payAccount"];
        if (payAccount && ![payAccount isEqualToString:@""]) {
            [obj addObject:@(kVcSubPaymentMethod)];
        }
    }] copy];
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderDetailInfo), @"rows":orderDetailRows}];

    //  提示 TODO:2.9
    if ([[_statusInfos objectForKey:@"show_remark"] boolValue]) {
        if (!_cell_tips) {
            NSMutableArray* tips_array = [NSMutableArray array];
            NSString* remark = [_orderDetails objectForKey:@"remark"];
            if (remark && [remark isKindOfClass:[NSString class]] && ![remark isEqualToString:@""]) {
                [tips_array addObject:[NSString stringWithFormat:@"商家：%@", remark]];
            }
            [tips_array addObject:@"系统：在转账过程中请勿备注BTC、USDT等信息，防止汇款被拦截、银行卡被冻结等问题。"];
            
            _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[NSString stringWithFormat:@"%@", [tips_array componentsJoinedByString:@"\n\n"]]];
            _cell_tips.hideBottomLine = YES;
            _cell_tips.hideTopLine = YES;
            _cell_tips.backgroundColor = [UIColor clearColor];
        }
        [_sectionDataArray addObject:@{@"type":@(kVcSecCellTips)}];
    } else {
        _cell_tips = nil;
    }

    //  UI - 底部按钮数据
    id actions = [_statusInfos objectForKey:@"actions"];
    if (actions && [actions count] > 0) {
        [_btnArray addObjectsFromArray:actions];
    }
}

- (void)_refreshUI:(id)new_order_detail
{
    
}

/*
 *  (private) 执行更新订单。确认付款/取消订单/商家退款（用户收到退款后取消订单）等
 */
- (void)_execUpdateOrderCore:(id)payAccount payChannel:(id)payChannel type:(EOtcOrderUpdateType)type
{
    assert(payAccount);
    assert(payChannel);
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc updateUserOrder:_orderDetails[@"userAccount"]
                  order_id:_orderDetails[@"orderId"]
                payAccount:payAccount
                payChannel:payChannel
                      type:type] then:^id(id data) {
        //  更新状态成功、刷新界面。
        return [[otc queryUserOrderDetails:_orderDetails[@"userAccount"] order_id:_orderDetails[@"orderId"]] then:^id(id details_responsed) {
            //  获取新订单数据成功
            [self hideBlockView];
            [self _refreshUI:[details_responsed objectForKey:@"data"]];
            return nil;
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

/*
 *  (private) 执行转币
 */
- (void)_execTransferCore
{
    //  TODO:2.9
}

- (void)onButtomButtonClicked:(UIButton*)sender
{
    switch (sender.tag) {
        case eooot_transfer:
        {
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"如果您已转币，请不要重复操作，若系统长时间未确认请联系客服。是否继续？"
                                                                   withTitle:@"确认转币"
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                     [self _execTransferCore];
                 }
             }];
        }
            break;
        case eooot_contact_customer_service:
        {
            //  TODO:2.9
            [OrgUtils makeToast:[NSString stringWithFormat:@"客服 buttom clicked %@", @(sender.tag)]];
        }
            break;
        case eooot_confirm_received_money:
        {
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"我确认已登录收款账户查看，并核对收款无误。是否放行？"
                                                                   withTitle:@"确认放行"
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                     [self _execUpdateOrderCore:_orderDetails[@"payAccount"]
                                     payChannel:_orderDetails[@"payChannel"]
                                           type:eoout_to_received_money];
                 }
             }];
        }
            break;
            
        case eooot_cancel_order:
        {
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"※ 如果您已经付款给商家，请不要取消订单！！！\n\n注：若用户当日累计取消3笔订单，会限制当日下单功能。是否继续？"
                                                                   withTitle:@"确认取消订单"
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                     [self _execUpdateOrderCore:_currSelectedPaymentMethod[@"account"]
                                     payChannel:_currSelectedPaymentMethod[@"type"]
                                           type:eoout_to_cancel];
                 }
             }];
        }
            break;
        case eooot_confirm_paid:
        {
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"我确认已按要求付款给商家。\n注：恶意点击将会被冻结账号。\n是否继续？"
                                                                   withTitle:@"确认付款"
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                    [self _execUpdateOrderCore:_currSelectedPaymentMethod[@"account"]
                                    payChannel:_currSelectedPaymentMethod[@"type"]
                                          type:eoout_to_paied];
                 }
             }];
        }
            break;
        case eooot_confirm_received_refunded:
        {
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"我确认已登录原付款账户查看，并核对退款无误。是否继续？"
                                                                   withTitle:@"确认收到退款"
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                     [self _execUpdateOrderCore:_orderDetails[@"payAccount"]
                                     payChannel:_orderDetails[@"payChannel"]
                                           type:eoout_to_refunded_confirm];
                 }
             }];
        }
            break;
        default:
            break;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 主表格
    CGFloat fBottomButtonsViewHeight = 60.0f;
    CGRect tableRect = [_btnArray count] > 0 ? [self rectWithoutNaviWithOffset:fBottomButtonsViewHeight] : [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:tableRect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 底部按钮
    if ([_btnArray count] > 0) {
        assert([_btnArray count] <= 2);
        UIView* pBottomView = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                                       tableRect.size.height,
                                                                       tableRect.size.width,
                                                                       fBottomButtonsViewHeight + [self heightForBottomSafeArea])];
        [self.view addSubview:pBottomView];
        pBottomView.backgroundColor = theme.tabBarColor;
        CGFloat fBottomTotalWidth = tableRect.size.width;
        CGFloat fBtnBorderWidth = 12.0f;                                    //  边距
        CGFloat fTotalSpace = ([_btnArray count] + 1) * fBtnBorderWidth;    //  总间隔（2边+中间按钮间隔）
        CGFloat fBtnHeight = 38.0f;                                         //  按钮高度
        
        NSInteger btnIndex = 0;
        CGFloat fBtnOffsetX = fBtnBorderWidth;
        for (id btnInfo in _btnArray) {
            CGFloat fBtnWidth;
            if ([_btnArray count] == 1) {
                fBtnWidth = fBottomTotalWidth - fTotalSpace;                //  1个按钮 100%
            } else {
                if (btnIndex == 0) {
                    fBtnWidth = (fBottomTotalWidth - fTotalSpace) * 0.4;    //  2个按钮的第一个按钮
                } else {
                    fBtnWidth = (fBottomTotalWidth - fTotalSpace) * 0.6;    //  2个按钮的第二个按钮
                }
            }
            
            UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            btn.tag = [[btnInfo objectForKey:@"type"] integerValue];
            btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
            //  TODO:2.9
            switch (btn.tag) {
                //  卖单
                case eooot_transfer:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnTransfer", @"立即转币") forState:UIControlStateNormal];
                    break;
                case eooot_contact_customer_service:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnCustomerService", @"联系客服") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_received_money:
                    [btn setTitle:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOtcOdBtnConfirmReceivedMoney", @"放行"), _orderDetails[@"assetSymbol"]] forState:UIControlStateNormal];
                    break;
                //  买单
                case eooot_cancel_order:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnCancelOrder", @"取消订单") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_paid:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnConfirmPaid", @"我已付款成功") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_received_refunded:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnConfirmReceivedRefunded", @"我已收到退款") forState:UIControlStateNormal];
                    break;
                default:
                    break;
            }
            [btn setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
            btn.userInteractionEnabled = YES;
            [btn addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            btn.frame = CGRectMake(fBtnOffsetX, (fBottomButtonsViewHeight  - fBtnHeight) / 2, fBtnWidth, fBtnHeight);
            btn.backgroundColor = [btnInfo objectForKey:@"color"];
            [pBottomView addSubview:btn];
            
            fBtnOffsetX += fBtnWidth + fBtnBorderWidth;
            ++btnIndex;
        }
    }
}

/**
 *  事件 - 用户点击提交按钮
 */
-(void)gotoSubmitCore
{
    //  TODO:otc
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_sectionDataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id secInfos = [_sectionDataArray objectAtIndex:section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        case kVcSecOrderInfo:
        case kVcSecCellTips:
            return 1;
        default:
            break;
    }
    return [[secInfos objectForKey:@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        case kVcSecOrderInfo:
            return 80.0f;
        case kVcSecCellTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    //  默认值
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

- (void)onCopyButtonClicked:(UIButton*)sender
{
    //  TODO:2.9
    [OrgUtils makeToast:[NSString stringWithFormat:@"copy clicked: %@", @(sender.tag)]];
}

- (UIButton*)genCopyButton:(NSInteger)tag
{
    //  TODO:2.9 icon???
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage imageNamed:@"iconPmBankCard"];
    CGSize btn_size = btn_image.size;
    [btn setBackgroundImage:btn_image forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onCopyButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.frame = CGRectMake(0, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
//    btn.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
    btn.tag = tag;
    return btn;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        {
            ViewOtcOrderDetailStatus* cell = [[ViewOtcOrderDetailStatus alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_statusInfos];
            return cell;
        }
            break;
        case kVcSecOrderInfo:
        {
            ViewOtcOrderDetailBasicInfo* cell = [[ViewOtcOrderDetailBasicInfo alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_orderDetails];
            return cell;
        }
            break;
        case kVcSecOrderDetailInfo:
        case kvcSecPaymentInfo:
        {
            NSInteger rowType = [[[secInfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
            
            //  REMARK：付款方式单独样式的 view
            if (rowType == kVcSubPaymentMethod) {
                ViewOtcPaymentIconAndTextCell* cell = [[ViewOtcPaymentIconAndTextCell alloc] init];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.showCustomBottomLine = YES;
                cell.bUserSell = [[_statusInfos objectForKey:@"sell"] boolValue];
                [cell setItem:_orderDetails];
                return cell;
            }
            
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.textLabel.textColor = theme.textColorNormal;
            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.detailTextLabel.textColor = theme.textColorMain;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            
            switch (rowType) {
                case kVcSubMerchantRealName:
                {
                    cell.textLabel.text = @"商家姓名";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"payRealName"] ?: @"";
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubMerchantNickName:
                {
                    cell.textLabel.text = @"商家昵称";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"merchantsNickname"] ?: @"";
                }
                    break;
                case kVcSubOrderID:
                {
                    cell.textLabel.text = @"订单编号";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"orderId"] ?: @"";
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubOrderTime:
                {
                    cell.textLabel.text = @"下单日期";
                    cell.detailTextLabel.text = [OtcManager fmtOrderDetailTime:[_orderDetails objectForKey:@"ctime"]];
                }
                    break;
                    
                case kVcSubPaymentTipsSameName:
                {
                    assert(_currSelectedPaymentMethod);
                    //  TODO:2.9 lang
                    
                    NSString* realname = nil;
                    if (_authInfos) {
                        realname = [_authInfos optString:@"realName"];
                    }
                    if (realname && realname.length >= 2) {
                        realname = [NSString stringWithFormat:@"*%@", [realname substringFromIndex:1]];
                    }
                    if (realname) {
                        realname = [NSString stringWithFormat:@"(%@)", realname];
                    }
                    
                    id pminfos = [OtcManager auxGenPaymentMethodInfos:_currSelectedPaymentMethod[@"account"]
                                                                 type:_currSelectedPaymentMethod[@"type"]
                                                             bankname:nil];
                    
                    NSString* finalString;
                    NSString* colorString;
                    if (realname) {
                        finalString = [NSString stringWithFormat:@"请使用本人%@的%@向以下账户自行转账", realname, [pminfos objectForKey:@"name"]];
                        colorString = realname;
                    } else {
                        finalString = [NSString stringWithFormat:@"请使用本人名字的%@向以下账户自行转账", [pminfos objectForKey:@"name"]];
                        colorString = @"本人名字";
                    }
                    
                    //  着色显示
                    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
                    NSRange range = [finalString rangeOfString:colorString];
                    [attrString addAttribute:NSForegroundColorAttributeName
                                       value:theme.sellColor
                                       range:range];
                    cell.textLabel.attributedText = attrString;
                }
                    break;
                case kVcSubPaymentMethodSelect:
                {
                    assert(_currSelectedPaymentMethod);
                    
                    id pminfos = [OtcManager auxGenPaymentMethodInfos:_currSelectedPaymentMethod[@"account"]
                                                                 type:_currSelectedPaymentMethod[@"type"]
                                                             bankname:_currSelectedPaymentMethod[@"bankName"]];
                    
                    cell.imageView.image = [UIImage imageNamed:pminfos[@"icon"]];
                    cell.textLabel.text = pminfos[@"name"];
                    
                    //  多种方式可选
                    if ([[_orderDetails objectForKey:@"payMethod"] count] > 1) {
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    }
                    
                    cell.detailTextLabel.text = @"点此切换付款方式";
                    cell.detailTextLabel.textColor = theme.textColorGray;
                }
                    break;
                case kVcSubPaymentRealName:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = @"收款人";
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"realName"];
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubPaymentAccount:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = @"收款账号";
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"account"];
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubPaymentBankName:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = @"开户银行";
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"bankName"];
                }
                    break;
                case kVcSubPaymentQrCode:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = @"收款二维码";
                    //  TODO:2.9。大图显示
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"qrCode"];
                }
                    break;
                default:
                    assert(false);
                    break;
            }
            
            return cell;
        }
            break;
        case kVcSecCellTips:
        {
            assert(_cell_tips);
            return _cell_tips;
        }
            break;
        default:
            assert(false);
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
        switch ([[secInfos objectForKey:@"type"] integerValue]) {
            case kvcSecPaymentInfo:
            {
                id rowInfos = [[secInfos objectForKey:@"rows"] objectAtIndex:indexPath.row];
                switch ([rowInfos integerValue]) {
                    case kVcSubPaymentMethodSelect:
                        [self _onSelectPaymentMethodClicked];
                        break;
                    default:
                        break;
                }
            }
                break;
            default:
                break;
        }
    }];
}

/*
 *  (private) 事件 - 选择商家收款方式点击
 */
- (void)_onSelectPaymentMethodClicked
{
    id payMethod = [_orderDetails objectForKey:@"payMethod"];
    if ([payMethod count] > 1) {
        id nameList = [payMethod ruby_map:^id(id src) {
            id pminfos = [OtcManager auxGenPaymentMethodInfos:src[@"account"]
                                                         type:src[@"type"]
                                                     bankname:src[@"bankName"]];
            return [pminfos objectForKey:@"name_with_short_account"];
        }];
        [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                           message:@"请选择商家收款方式"
                                                            cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                             items:nameList//@[@"银行卡", @"支付宝"]
                                                          callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
         {
             if (buttonIndex != cancelIndex){
                 id selectedPaymentMethod = [payMethod objectAtIndex:buttonIndex];
                 NSString* new_id = [NSString stringWithFormat:@"%@", selectedPaymentMethod[@"id"]];
                 NSString* old_id = [NSString stringWithFormat:@"%@", _currSelectedPaymentMethod[@"id"]];
                 if (![new_id isEqualToString:old_id]) {
                     // 更新商家收款方式相关字段
                     for (id sec in _sectionDataArray) {
                         if ([[sec objectForKey:@"type"] integerValue] == kvcSecPaymentInfo) {
                             [self _genPaymentRows:selectedPaymentMethod
                                      target_array:[sec objectForKey:@"rows"]];
                             [_mainTableView reloadData];
                             break;
                         }
                     }
                 }
             }
         }];
    }
}

@end
