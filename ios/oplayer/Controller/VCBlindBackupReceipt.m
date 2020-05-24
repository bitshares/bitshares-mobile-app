//
//  VCBlindBackupReceipt.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindBackupReceipt.h"
#import "ViewAddrMemoInfoCell.h"
#import "ViewTipsInfoCell.h"
#import "OrgUtils.h"
#import "SGQRCodeObtain.h"

#import "VCStealthTransferHelper.h"

enum
{
    kVcSecReceipt = 0,
    kVcSecActions,
    kVcSecTips,
    
    kVcSecMax
};

enum
{
    kVcSubSuccessTips = 0,  //  转账成功提示
    kVcSubQRcode,           //  二维码
    kVcSubReceipt,          //  收据
    
    kVcSubMax
};

@interface VCBlindBackupReceipt ()
{
    NSDictionary*           _transaction_confirmation;
    NSString*               _blind_receipt_string;
    UITableViewBase*        _mainTableView;
    
    CGFloat                 _fQrSize;
    UIImageView*            _qrImageView;
    ViewTipsInfoCell*       _cellTips;
    NSMutableArray*         _dataArray;
    
    ViewBlockLabel*         _btnCommit;
}

@end

@implementation VCBlindBackupReceipt

-(void)dealloc
{
    _transaction_confirmation = nil;
    _dataArray = nil;
    _cellTips = nil;
    _qrImageView = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _btnCommit = nil;
}

- (id)initWithTrxResult:(NSArray*)transaction_confirmation_list
{
    self = [super init];
    if (self) {
        // Custom initialization
        _dataArray = [NSMutableArray array];
        assert(transaction_confirmation_list && [transaction_confirmation_list count] > 0);
        _transaction_confirmation = [transaction_confirmation_list objectAtIndex:0];
        assert(_transaction_confirmation);
        //  生成隐私转账收据信息
        _blind_receipt_string = [[@{kAppBlindReceiptBlockNum: _transaction_confirmation[@"block_num"]} to_json:YES] base58_encode];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    [self showLeftButton:NSLocalizedString(@"kVcScanResultPaySuccessBtnDone", @"完成") action:@selector(_onButtonDoneClicked)];
    
    //  初始化数据源
    [_dataArray addObject:@{@"type": @(kVcSubSuccessTips)}];
    [_dataArray addObject:@{@"type": @(kVcSubQRcode)}];
    [_dataArray addObject:@{@"type": @(kVcSubReceipt)}];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 二维码
    CGFloat fWidth = self.view.bounds.size.width;
    _fQrSize = (int)(fWidth * 0.5f);
    UIImage* qrImage = [SGQRCodeObtain generateQRCodeWithData:_blind_receipt_string
                                                         size:_fQrSize];
    _qrImageView = [[UIImageView alloc] initWithImage:qrImage];
    _qrImageView.frame = CGRectMake((fWidth - _fQrSize) / 2, 0, _fQrSize, _fQrSize);
    
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kVcStTipUiBackupYourReceipt", @"【温馨提示】\n1、隐私收据是隐私转账唯一收款凭证，请务必妥善保管。\n2、请复制收据信息或截图保存。\n3、隐私转账后，收款方需尽快导入收据信息以确认转账成功。\n4、如果您是给他人进行隐私账户，转账后请主动提交收据信息给目标用户。")];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
    
    //  按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcScanResultPaySuccessBtnDone", @"完成")];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecReceipt){
        return [_dataArray count];
    }else{
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecReceipt:
        {
            switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
                case kVcSubSuccessTips:
                    return 64.0f;
                case kVcSubQRcode:
                    return _fQrSize + 12.0f;
                default:
                    break;
            }
            CGFloat baseHeight = 20.0 + 26 * 2;
            return baseHeight;
        }
            break;
        case kVcSecTips:
            return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
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
    return 20.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecReceipt:
        {
            switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
                case kVcSubSuccessTips:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcStLabelPleaseBackupYourReceiptText", @"隐私转账成功，请妥善保管以下收据信息！");
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
                    cell.backgroundColor = [UIColor clearColor];
                    cell.textLabel.font = [UIFont systemFontOfSize:13];
                    return cell;
                }
                    break;
                case kVcSubQRcode:
                {
                    if (_qrImageView.superview){
                        [_qrImageView removeFromSuperview];
                    }
                    
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    [cell addSubview:_qrImageView];
                    return cell;
                }
                    break;
                case kVcSubReceipt:
                {
                    ViewAddrMemoInfoCell* cell = [[ViewAddrMemoInfoCell alloc] initWithTitleText:NSLocalizedString(@"kVcStCellButtonNameCopyReceipt", @"复制收据(可截图)")
                                                                                       valueText:_blind_receipt_string];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                default:
                    break;
            }
            assert(false);
            return nil;
        }
            break;
        case kVcSecActions:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcSecTips:
            return _cellTips;
        default:
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case kVcSecReceipt:
        {
            //  复制内容
            switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
                case kVcSubReceipt:
                {
                    [UIPasteboard generalPasteboard].string = [_blind_receipt_string copy];
                    [OrgUtils makeToast:NSLocalizedString(@"kVcStTipReceiptBackupCopied", @"收据已复制。")];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcSecActions:
            [self _onButtonDoneClicked];
            break;
        default:
            break;
    }
}

-(void)_onButtonDoneClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kVcStTipAskConfrimForCloseBackupReceiptUI", @"提取隐私资产需要收据信息，请确认您已备份好以上收据，可截图保存。")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self closeOrPopViewController];
        }
    }];
}

@end
