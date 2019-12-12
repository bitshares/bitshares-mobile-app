//
//  VCOtcMcAssetTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAssetTransfer.h"
#import "ViewOtcMcAssetSwitchCell.h"
#import "ViewTipsInfoCell.h"
#import "OtcManager.h"

enum
{
    kVcSecFromTo = 0,       //  FROM TO信息CELL
    kVcSecTransferCoin,     //  划转币种
    kVcSecAmount,           //  划转数量
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

@interface VCOtcMcAssetTransfer ()
{
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    NSDictionary*           _balance_info;
    NSDictionary*           _merchant_detail;
    NSMutableDictionary*    _argsFromTo;
    
    UITableViewBase*        _mainTableView;
    UITableViewCellBase*    _cellAssetAvailable;
    MyTextField*            _tf_amount;
    
    ViewTipsInfoCell*       _cell_tips;
    ViewBlockLabel*         _lbCommit;
}

@end

@implementation VCOtcMcAssetTransfer

-(void)dealloc
{
    _balance_info = nil;
    _cellAssetAvailable = nil;
    _auth_info = nil;
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

- (id)initWithAuthInfo:(id)auth_info
             user_type:(EOtcUserType)user_type
       merchant_detail:(id)merchant_detail
          balance_info:(id)balance_info
           transfer_in:(BOOL)transfer_in
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        _balance_info = balance_info;
        _argsFromTo = [NSMutableDictionary dictionary];
        if (transfer_in) {
            //  个人到商家
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"btsAccount"] forKey:@"from"];
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"otcAccount"] forKey:@"to"];
            [_argsFromTo setObject:@NO forKey:@"bFromIsMerchant"];
        } else {
            //  商家到个人
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"otcAccount"] forKey:@"from"];
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"btsAccount"] forKey:@"to"];
            [_argsFromTo setObject:@YES forKey:@"bFromIsMerchant"];
        }
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (UIView*)genTailerView:(NSString*)asset_symbol action:(NSString*)action tag:(NSInteger)tag
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat fHeight = 31.0f;
    CGFloat fSpace = 12.0f;
    
    UIView* tailer_view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel* lbAsset = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:13] superview:tailer_view];
    UILabel* lbSpace = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:tailer_view];
    lbAsset.text = asset_symbol;
    lbSpace.text = @"|";//TODO:2.9
    lbAsset.textColor = theme.textColorMain;
    lbSpace.textColor = theme.textColorGray;
    lbAsset.textAlignment = NSTextAlignmentRight;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:action forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onButtonTailerClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    btn.tag = tag;
    
    //  设置 frame
    CGSize size1 = [UITableViewCellBase auxSizeWithText:btn.titleLabel.text font:btn.titleLabel.font maxsize:CGSizeMake(9999, 9999)];
    CGSize size2 = [UITableViewCellBase auxSizeWithText:lbSpace.text font:lbSpace.font maxsize:CGSizeMake(9999, 9999)];
    CGSize size3 = [UITableViewCellBase auxSizeWithText:lbAsset.text font:lbAsset.font maxsize:CGSizeMake(9999, 9999)];
    
    CGFloat fWidth = size1.width + size2.width + size3.width + fSpace * 3;
    
    tailer_view.frame = CGRectMake(0, 0, fWidth, fHeight);
    lbAsset.frame = CGRectMake(fSpace * 1, 0, size3.width, fHeight);
    lbSpace.frame = CGRectMake(fSpace * 2 + size3.width, 0, size2.width, fHeight);
    btn.frame = CGRectMake(fSpace * 3 + size3.width + size2.width, 0, size1.width, fHeight);
    
    [tailer_view addSubview:lbAsset];
    [tailer_view addSubview:lbSpace];
    [tailer_view addSubview:btn];
    
    return tailer_view;
}

- (void)onButtonTailerClicked:(UIButton*)sender
{
    //  TODO:2.9
}

- (NSString*)genTransferTipsMessage
{
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        return @"【温馨提示】\n从商家账号转账给个人账号，需要平台协同处理，划转成功后请耐心等待。";
    } else {
        return @"【温馨提示】\n从个人账号直接转账给商家账号。";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  初始化UI
    _cellAssetAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellAssetAvailable.backgroundColor = [UIColor clearColor];
    _cellAssetAvailable.hideBottomLine = YES;
    _cellAssetAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellAssetAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellAssetAvailable.textLabel.text = @"数量";
    _cellAssetAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.textLabel.textColor = theme.textColorMain;
    _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"可用 %@ %@", [_balance_info objectForKey:@"available"], [_balance_info objectForKey:@"assetSymbol"]];
    _cellAssetAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.detailTextLabel.textColor = theme.textColorMain;
    
    NSString* placeHolderAmount = @"请输入划转数量";
    _tf_amount = [self createTfWithRect:[self makeTextFieldRectFull] keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
    _tf_amount.updateClearButtonTintColor = YES;
    _tf_amount.showBottomLine = YES;
    _tf_amount.textColor = theme.textColorMain;
    _tf_amount.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAmount
                                                                       attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  绑定输入事件（限制输入）
    [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _tf_amount.rightView = [self genTailerView:[_balance_info objectForKey:@"assetSymbol"] action:@"全部" tag:0];;
    _tf_amount.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  TODO:2.9 msg
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  TODO:2.9
    _lbCommit = [self createCellLableButton:@"划转"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount safeResignFirstResponder];
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:4];//TODO:2.9 pre
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
//    if (textField != _tf_amount){
//        return;
//    }
//
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    
    [self onAmountChanged];
}

/**
 *  (private) 转账数量发生变化。
 */
- (void)onAmountChanged
{
    id str_amount = _tf_amount.text;
//
//    GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
//    NSString* symbol = appext.symbol;
//
//    //  无效输入
//    if (!str_amount || [str_amount isEqualToString:@""]){
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available], symbol];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//        return;
//    }
//
//    //  获取输入的数量
//    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
//
//    //  _n_available < n_amount
//    if ([_n_available compare:n_amount] == NSOrderedAscending){
//        //  数量不足
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@(%@)", [OrgUtils formatFloatValue:_n_available], symbol, NSLocalizedString(@"kVcTransferTipAmountNotEnough", @"数量不足")];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
//    }else{
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available], symbol];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//    }
//
//    [self _refreshFinalValueUI:n_amount];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecTransferCoin || section == kVcSecAmount) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecFromTo:
            return 72.0f;
        case kVcSecTransferCoin:
        case kVcSecAmount:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
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
        case kVcSecFromTo:
        {
            ViewOtcMcAssetSwitchCell* cell = [[ViewOtcMcAssetSwitchCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                                             reuseIdentifier:nil
                                                                                          vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_argsFromTo];
            return cell;
        }
            break;
        case kVcSecTransferCoin:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = @"资产";
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.text = @"USD";
            }
            return cell;
        }
            break;
        case kVcSecAmount:
        {
            if (indexPath.row == 0) {
                return _cellAssetAvailable;
            } else {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_amount];
                cell.accessoryView = _tf_amount;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
        }
            break;
        case kVcSecTips:
        {
            return _cell_tips;
        }
            break;
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
//    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//        id item = [_dataArray objectAtIndex:indexPath.row];
//        assert(item);
//        //  TODO:2.9
////        [self onCellClicked:item];
//    }];
}

#pragma mark- for actions

- (void)onButtonClicked_Switched:(UIButton*)sender
{
    //  TODO:2.9
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        [_argsFromTo setObject:@NO forKey:@"bFromIsMerchant"];
    } else {
        [_argsFromTo setObject:@YES forKey:@"bFromIsMerchant"];
    }
    NSString* tmp = [_argsFromTo objectForKey:@"from"];
    [_argsFromTo setObject:[_argsFromTo objectForKey:@"to"] forKey:@"from"];
    [_argsFromTo setObject:tmp forKey:@"to"];
    [_cell_tips updateLabelText:[self genTransferTipsMessage]];
    //  TODO:2.9
    [_mainTableView reloadData];
}

@end
