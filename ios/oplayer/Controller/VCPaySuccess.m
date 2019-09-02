//
//  VCPaySuccess.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCPaySuccess.h"
#import "NativeAppDelegate.h"
#import "AppCacheManager.h"

@interface VCPaySuccess ()
{
    NSArray*                _trx_result;
    NSDictionary*           _to_account;
    NSString*               _amount_string;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
}

@end

@implementation VCPaySuccess

- (id)initWithResult:(NSArray*)trx_result to_account:(NSDictionary*)to_account amount_string:(NSString*)amount_string
{
    self = [super init];
    if (self) {
        assert(trx_result);
        assert(to_account);
        _trx_result = trx_result;
        _to_account = to_account;
        _amount_string = amount_string;
    }
    return self;
}

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _btnCommit = nil;
    _trx_result = nil;
    _to_account = nil;
    _amount_string = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    //  关于图标
    CGFloat fOffset = 16.0f;
    UIImage* image = [UIImage templateImageNamed:@"paysuccess"];
    UIImageView* iconView = [[UIImageView alloc] initWithImage:image];
    iconView.frame = CGRectMake((screenRect.size.width - image.size.width) / 2.0f, fOffset, image.size.width, image.size.height);
    [self.view addSubview:iconView];
    
    fOffset += image.size.height;
    UILabel* paylabel = [[UILabel alloc] initWithFrame:CGRectMake(0, fOffset, screenRect.size.width, 44)];
    paylabel.lineBreakMode = NSLineBreakByTruncatingTail;
    paylabel.numberOfLines = 1;
    paylabel.backgroundColor = [UIColor clearColor];
    paylabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
    paylabel.textAlignment = NSTextAlignmentCenter;
    paylabel.font = [UIFont systemFontOfSize:18];
    paylabel.text = NSLocalizedString(@"kVcScanResultTipsPaySuccess", @"支付成功");
    [self.view addSubview:paylabel];
    
    fOffset += 80.0f;
    UILabel* amount = [[UILabel alloc] initWithFrame:CGRectMake(0, fOffset, screenRect.size.width, 48)];
    amount.lineBreakMode = NSLineBreakByTruncatingTail;
    amount.numberOfLines = 1;
    amount.backgroundColor = [UIColor clearColor];
    amount.textColor = [ThemeManager sharedThemeManager].textColorMain;
    amount.textAlignment = NSTextAlignmentCenter;
    amount.font = [UIFont boldSystemFontOfSize:32];
    amount.text = _amount_string ?: @"";
    [self.view addSubview:amount];
    
    CGFloat offset = fOffset + 48 + 16;
    _mainTableView = [[UITableViewBase alloc] initWithFrame:CGRectMake(0, offset,
                                                                       screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offset)
                                                      style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcScanResultPaySuccessBtnDone", @"完成")];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 2;
    else
        return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            switch (indexPath.row) {
                case 0:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    cell.textLabel.textColor = theme.textColorMain;
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPaySuccessLabelTo", @"收款方");
                    cell.detailTextLabel.text = [_to_account objectForKey:@"name"] ?: @"";
                    cell.detailTextLabel.textColor = theme.buyColor;
                    return cell;
                }
                    break;
                case 1:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    cell.textLabel.textColor = theme.textColorMain;
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPaySuccessLabelTrxID", @"交易ID");
                    cell.detailTextLabel.text = [[_trx_result objectAtIndex:0] objectForKey:@"id"] ?: @"";
                    cell.detailTextLabel.textColor = theme.textColorMain;
                    return cell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 1:
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
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                [self _onReceiverClicked];
            } else {
                [self _onTrxIdClicked];
            }
        } else {
            [self _onButtonDoneClicked];
        }
    }];
}

-(void)_onButtonDoneClicked
{
    [self closeOrPopViewController];
}

- (void)_onReceiverClicked
{
    id to = [_to_account objectForKey:@"id"] ?: @"";
    if (to && ![to isEqualToString:@""]){
        [VCCommonLogic viewUserAssets:self account:to];
    }
}

- (void)_onTrxIdClicked
{
    id trx_id = [[_trx_result objectAtIndex:0] objectForKey:@"id"] ?: @"";
    if (trx_id && ![trx_id isEqualToString:@""]){
        [OrgUtils safariOpenURL:[NSString stringWithFormat:@"https://bts.ai/tx/%@", trx_id]];
    }
}

@end
