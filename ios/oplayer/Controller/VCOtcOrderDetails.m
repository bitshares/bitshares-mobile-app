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

#import "OtcManager.h"

enum
{
    kVcSecOrderStatus = 0,  //  状态信息
    kVcSecOrderInfo,        //  订单基本信息：价格单价等
    kvcSecPaymentInfo,      //  收付款信息（用户买入时需要显示）
    kVcSecOrderDetailInfo,  //  订单详细信息：商家名、订单号等
};

enum
{
    kVcSubMerchantRealName = 0, //  商家实名
    kVcSubMerchantNickName,     //  商家昵称
    kVcSubOrderID,              //  订单号
    kVcSubOrderTime,            //  下单日期
    kVcSubRemark,               //  订单附加信息（备注信息）
    
    kVcSubPaymentMethod,        //  收款方式
    kVcSubPaymentRealName,      //  收款人
    kVcSubPaymentAccount,       //  收款账号（银行卡号、微信支付宝账号等）
};

@interface VCOtcOrderDetails ()
{
    NSDictionary*           _orderBasic;
    NSDictionary*           _orderDetails;
    BOOL                    _bUserSell;         //  是否是卖单
    NSDictionary*           _statusInfos;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _sectionDataArray;
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
    _sectionDataArray = nil;
    _orderBasic = nil;
    _orderDetails = nil;
    _btnArray = nil;
}

- (id)initWithOrder:(id)order details:(id)order_details
{
    self = [super init];
    if (self) {
        _orderBasic = order;
        _orderDetails = order_details;
        _sectionDataArray = [NSMutableArray array];
        _bUserSell = [[_orderDetails objectForKey:@"type"] integerValue] == eoot_data_sell;
        _btnArray = [NSMutableArray array];
        _statusInfos = [OtcManager genUserOrderStatusAndActions:order_details];
        [self _initUIData];
    }
    return self;
}

/*
 *  (private) 动态初始化UI需要显示的字段信息按钮等数据。
 */
- (void)_initUIData
{
    [_sectionDataArray removeAllObjects];
    [_btnArray removeAllObjects];
    
    //  TODO:2.9
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderStatus)}];
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderInfo)}];
    //  TODO:2.9 test  data
    id orderDetailRows = [[[NSMutableArray array] ruby_apply:^(id obj) {
        [obj addObject:@(kVcSubMerchantRealName)];
        [obj addObject:@(kVcSubMerchantNickName)];
        [obj addObject:@(kVcSubOrderID)];
        [obj addObject:@(kVcSubOrderTime)];
        if ([[_statusInfos objectForKey:@"show_remark"] boolValue]) {
            [obj addObject:@(kVcSubRemark)];
        }
    }] copy];
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderDetailInfo), @"rows":orderDetailRows}];

    //  底部按钮数据
    id actions = [_statusInfos objectForKey:@"actions"];
    if (actions && [actions count] > 0) {
        [_btnArray addObjectsFromArray:actions];
    }
}

- (void)onButtomButtonClicked:(UIButton*)sender
{
    //  TODO:2.9
    [OrgUtils makeToast:[NSString stringWithFormat:@"buttom clicked %@", @(sender.tag)]];
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
                case eooot_transfer:
                    [btn setTitle:@"立即转币" forState:UIControlStateNormal];
                    break;
                case eooot_contact_customer_service:
                    [btn setTitle:@"联系客服" forState:UIControlStateNormal];
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
            return 1;
        default:
            break;
    }
    return [[secInfos objectForKey:@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([[[_sectionDataArray objectAtIndex:indexPath.section] objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        case kVcSecOrderInfo:
            return 80.0f;
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
        {
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
//            kVcSubMerchantRealName = 0, //  商家实名
//            kVcSubMerchantNickName,     //  商家昵称
//            kVcSubOrderID,              //  订单号
//            kVcSubOrderTime,            //  下单日期
//            kVcSubRemark,               //  订单附加信息（备注信息）
//
//            kVcSubPaymentMethod,        //  收款方式
//            kVcSubPaymentRealName,      //  收款人
//            kVcSubPaymentAccount,       //  收款账号（银行卡号、微信支付宝账号等）
            id rowInfos = [[secInfos objectForKey:@"rows"] objectAtIndex:indexPath.row];
            switch ([rowInfos integerValue]) {
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
                    cell.textLabel.text = @"订单号";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"orderId"] ?: @"";
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubOrderTime:
                {
                    cell.textLabel.text = @"下单日期";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"ctime"] ?: @"";
                }
                    break;
                    
                case kVcSubRemark:
                {
                    cell.textLabel.text = @"备注";
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"remark"] ?: @"";
                }
                    break;
                case kVcSubPaymentMethod:
                {
                    cell.textLabel.text = @"收款方式";
                    cell.detailTextLabel.text = @"xxsdfsf";//TODO:2.9
                }
                    break;
                case kVcSubPaymentRealName:
                {
                    cell.textLabel.text = @"收款人";
                    cell.detailTextLabel.text = @"xxxxx";//TODO:2.9
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                case kVcSubPaymentAccount:
                {
                    cell.textLabel.text = @"收款账号";
                    cell.detailTextLabel.text = @"xxxx";//TODO:2.9
                    cell.accessoryView = [self genCopyButton:indexPath.row];
                }
                    break;
                default:
                    assert(false);
                    break;
            }
            
            return cell;
        }
            break;
        default:
            assert(false);
            break;
    }
//    return nil;
    
//    if (indexPath.section == kVcFormData)
//    {
//        switch (indexPath.row) {
//            case kVcSubNameTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"姓名";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubName:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_name];
//                return cell;
//            }
//                break;
//            case kVcSubIDNumberTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"身份证号";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubIDNumber:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_idnumber];
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            case kVcSubPhoneNumberTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"联系方式";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubPhoneNumber:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_phonenumber];
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            case kVcSubSmsCode:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_smscode];//TODO:
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            default:
//                assert(false);
//                break;
//        }
//    }else if (indexPath.section == kVcCellTips){
//        return _cell_tips;
//    } else {
//        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//        cell.accessoryType = UITableViewCellAccessoryNone;
//        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
//        cell.hideBottomLine = YES;
//        cell.hideTopLine = YES;
//        cell.backgroundColor = [UIColor clearColor];
//        [self addLabelButtonToCell:_goto_submit cell:cell leftEdge:tableView.layoutMargins.left];
//        return cell;
//    }
//
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    if (indexPath.section == kVcSubmit){
//        //  表单行为按钮点击
//        [self resignAllFirstResponder];
//        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//            [self delay:^{
//                [self gotoSubmitCore];
//            }];
//        }];
//    }
}

@end
