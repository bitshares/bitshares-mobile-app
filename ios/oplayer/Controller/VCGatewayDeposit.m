//
//  VCGatewayDeposit.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCGatewayDeposit.h"
#import "ViewAddrMemoInfoCell.h"
#import "ViewTipsInfoCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"
#import "SGQRCodeObtain.h"
#import "GatewayAssetItemData.h"

enum
{
    kVcSubQRcode = 0,       //  地址二维码
    kVcSubAddress,          //  地址
    kVcSubMemo,             //  备注（可选）
    
    kVcSubMax
};

@interface VCGatewayDeposit ()
{
    NSDictionary*           _fullAccountData;
    NSDictionary*           _depositAddrItem;
    NSDictionary*           _depositAssetItem;
    
    NSString*               _depositMemoData;
    
    UITableViewBase*        _mainTableView;
    
    CGFloat                 _fQrSize;
    UIImageView*            _qrImageView;
    ViewTipsInfoCell*       _cellTips;
    NSMutableArray*         _dataArray;
}

@end

@implementation VCGatewayDeposit

-(void)dealloc
{
    _depositMemoData = nil;
    _fullAccountData = nil;
    _depositAddrItem = nil;
    _depositAssetItem = nil;
    _dataArray = nil;
    _cellTips = nil;
    _qrImageView = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithUserFullInfo:(id)fullAccountData depositAddrItem:(id)depositAddrItem depositAssetItem:(id)depositAssetItem
{
    self = [super init];
    if (self) {
        // Custom initialization
        _dataArray = [NSMutableArray array];
        assert(fullAccountData && depositAddrItem && depositAssetItem);
        _fullAccountData = fullAccountData;
        _depositAddrItem = depositAddrItem;
        _depositAssetItem = depositAssetItem;
        //  获取 memo
        _depositMemoData = [depositAddrItem objectForKey:@"inputMemo"];
        if (!_depositMemoData || [_depositMemoData isKindOfClass:[NSNull class]]){
            _depositMemoData = nil;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据源
    [_dataArray addObject:@{@"type": @(kVcSubQRcode)}];
    [_dataArray addObject:@{@"type": @(kVcSubAddress)}];
    if (_depositMemoData){
        [_dataArray addObject:@{@"type": @(kVcSubMemo)}];
    }
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 地址二维码
    CGFloat fWidth = self.view.bounds.size.width;
    _fQrSize = (int)(fWidth * 2.0 / 5.0f);
    UIImage* qrImage = [SGQRCodeObtain generateQRCodeWithData:[_depositAddrItem objectForKey:@"inputAddress"]
                                                         size:_fQrSize];
    _qrImageView = [[UIImageView alloc] initWithImage:qrImage];
    _qrImageView.frame = CGRectMake((fWidth - _fQrSize) / 2, 0, _fQrSize, _fQrSize);
    
    //  UI - 提示信息
    GatewayAssetItemData* appext = [_depositAssetItem objectForKey:@"kAppExt"];
    assert(appext);
    NSMutableArray* msgArray = [NSMutableArray array];
    [msgArray addObject:NSLocalizedString(@"kVcDWTipsImportantTitle", @"【重要】")];
    //  min deposit value
    id inputCoinType = [[_depositAddrItem objectForKey:@"inputCoinType"] uppercaseString];
    id minAmount = appext.depositMinAmount;
    if (minAmount && ![minAmount isEqualToString:@""]){
        [msgArray addObject:[NSString stringWithFormat:NSLocalizedString(@"kVcDWTipsMinDepositAmount", @"最小充币数量：%@%@。小于最小数量将无法入账且无法退回。\n"), minAmount, inputCoinType]];
    }
    //  sec tips
    [msgArray addObject:[NSString stringWithFormat:NSLocalizedString(@"kVcDWTipsDepositMatchAsset", @"请将您的%@资产充入上述地址，禁止向上述地址充入非%@资产，否则资产将不可找回。"), inputCoinType, inputCoinType]];
    //  confirm tips
    id confirm_block_number = appext.confirm_block_number;
    if (confirm_block_number && ![confirm_block_number isEqualToString:@""]){
        [msgArray addObject:[NSString stringWithFormat:NSLocalizedString(@"kVcDWTipsNetworkConfirmWithN", @"您充币到上述地址后，需要等待网络确认，%@次网络确认后到账。\n"), confirm_block_number]];
    }else{
        [msgArray addObject:NSLocalizedString(@"kVcDWTipsNetworkConfirm", @"您充币到上述地址后，请耐性等待网络确认。\n")];
    }
    //  default tips
    [msgArray addObject:NSLocalizedString(@"kVcDWTipsFindCustomService", @"如有任何问题，请联系网关客服。")];
    
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:[msgArray componentsJoinedByString:@"\n"]];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0){
        return [_dataArray count];
    }else{
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0){
        switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
            case kVcSubQRcode:
                return _fQrSize + 12.0f;
            default:
                break;
        }
        CGFloat baseHeight = 20.0 + 26 * 2;
        return baseHeight;
    }else{
        return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
    }
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
    if (indexPath.section == 0){
        switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
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
            case kVcSubAddress:
            {
                ViewAddrMemoInfoCell* cell = [[ViewAddrMemoInfoCell alloc] initWithTitleText:NSLocalizedString(@"kVcDWCellBtnCopyAddr", @"复制地址")
                                                                                   valueText:[_depositAddrItem objectForKey:@"inputAddress"]];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            case kVcSubMemo:
            {
                ViewAddrMemoInfoCell* cell = [[ViewAddrMemoInfoCell alloc] initWithTitleText:NSLocalizedString(@"kVcDWCellBtnCopyMemo", @"复制备注(TAG)")
                                                                                   valueText:_depositMemoData];
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
    }else{
        return _cellTips;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //  复制内容
    if (indexPath.section == 0){
        switch ([[_dataArray objectAtIndex:indexPath.row][@"type"] integerValue]) {
            case kVcSubAddress:
            {
                [UIPasteboard generalPasteboard].string = [_depositAddrItem objectForKey:@"inputAddress"];
                [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsCopyAddrOK", @"地址已复制")];
            }
                break;
            case kVcSubMemo:
            {
                [UIPasteboard generalPasteboard].string = _depositMemoData;
                [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsCopyMemoOK", @"备注已复制")];
            }
                break;
            default:
                break;
        }
    }
}

@end
