//
//  VCScanPrivateKey.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanPrivateKey.h"
#import "BitsharesClientManager.h"

enum
{
    kVcSectionBaseInfo = 0,
    kVcsectionWalletPassword,
    kVcSectionSubmit,
    
    kVcSectionMax
};

@interface VCScanPrivateKey ()
{
    NSString*               _priKey;
    NSString*               _pubKey;
    NSDictionary*           _fullAccountData;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    MyTextField*            _tf_wallet_password;
    
    NSArray*                _dataArray;
}

@end

@implementation VCScanPrivateKey

-(void)dealloc
{
    if (_tf_wallet_password){
        _tf_wallet_password.delegate = nil;
        _tf_wallet_password = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _btnCommit = nil;
}

- (id)initWithPriKey:(NSString*)priKey pubKey:(NSString*)pubKey fullAccountData:(NSDictionary*)fullAccountData;
{
    self = [super init];
    if (self) {
        _priKey = priKey;
        _pubKey = pubKey;
        _fullAccountData = fullAccountData;
    }
    return self;
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    if (button.tag == 1) {
        [OrgUtils showMessage:NSLocalizedString(@"kLoginRegTipsWalletPasswordFormat", @"8位以上字符，且必须包含大小写和数字。")];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    id account = [_fullAccountData objectForKey:@"account"];
    assert(account);
    
    NSMutableArray* priKeyTypeArray = [NSMutableArray array];
    id owner_key_auths = [[account objectForKey:@"owner"] objectForKey:@"key_auths"];
    if (owner_key_auths && [owner_key_auths count] > 0){
        for (id pair in owner_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeOwner", @"账号私钥")];
                break;
            }
        }
    }
    id active_key_auths = [[account objectForKey:@"active"] objectForKey:@"key_auths"];
    if (active_key_auths && [active_key_auths count] > 0){
        for (id pair in active_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeActive", @"资金私钥")];
                break;
            }
        }
    }
    id memo_key = [[account objectForKey:@"options"] objectForKey:@"memo_key"];
    if (memo_key && [memo_key isEqualToString:_pubKey]){
        [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeMemo", @"备注私钥")];
    }
    assert([priKeyTypeArray count] > 0);
    
    _dataArray = @[
                   @{@"name":@"ID", @"value":[account objectForKey:@"id"]},
                   @{@"name":NSLocalizedString(@"kAccount", @"账号"), @"value":[account objectForKey:@"name"]},
                   @{@"name":NSLocalizedString(@"kVcScanResultPriKeyTypeTitle", @"私钥类型"), @"value":[priKeyTypeArray componentsJoinedByString:@" "], @"highlight":@YES},
                   ];
    
    CGRect rect = [self makeTextFieldRect];
    
    //  wallet password
    _tf_wallet_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                     placeholder:NSLocalizedString(@"kLoginTipsPlaceholderWalletPassword", @"8位以上钱包文件密码")
                                          action:@selector(onTipButtonClicked:) tag:1];
    _tf_wallet_password.secureTextEntry = YES;
    _tf_wallet_password.updateClearButtonTintColor = YES;
    _tf_wallet_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_wallet_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_wallet_password.placeholder
                                                                                attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                             NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  TODO:fowallet多语言
    //  多种情况：
    //  1 - 尚未登录（直接采用私钥+钱包密码登录）
    //  2 - 已经用密码模式登录（升级到钱包模式并导入）
    //  3 - 已经钱包模式（直接导入）
    //  4 - 私钥已经存在（不处理）
    switch ([[WalletManager sharedWalletManager] getWalletMode]) {
        case kwmNoWallet:
            
            break;
        case kwmPasswordOnlyMode:
            break;
            
        default:
            break;
    }
    
//    kwmNoWallet = 0,            //  无钱包
//    kwmPasswordOnlyMode,        //  普通密码模式
//    kwmPasswordWithWallet,      //  密码登录+钱包模式
//    kwmPrivateKeyWithWallet,    //  活跃私钥+钱包模式
//    kwmFullWalletMode,          //  完整钱包模式（兼容官方客户端的钱包格式）
//    kwmBrainKeyWithWallet       //  助记词+钱包模式
    
    //  TODO:多语言
    _btnCommit = [self createCellLableButton:@"立即导入"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    [self endInput];
    
    //  确认界面由于时间经过可能又被 lock 了。
    [self GuardWalletUnlocked:^(BOOL unlocked) {
//        if (unlocked){
//            _bResultCannelled = NO;
//            [self closeModelViewController:nil];
//        }
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
    return kVcSectionMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSectionBaseInfo)
        return [_dataArray count];
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSectionBaseInfo:
        {
            id item = [_dataArray objectAtIndex:indexPath.row];
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = [item objectForKey:@"name"];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.detailTextLabel.text = [item objectForKey:@"value"];
            if ([[item objectForKey:@"highlight"] boolValue]){
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
            }else{
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            }
            return cell;
        }
            break;
        case kVcsectionWalletPassword:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"kLoginCellWalletPassword", @"钱包密码 ");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryView = _tf_wallet_password;
            return cell;
        }
            break;
        case kVcSectionSubmit:
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
    
    if (indexPath.section == kVcSectionSubmit){
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onCommitCore];
        }];
    }
}

- (void)endInput
{
    [self.view endEditing:YES];
    [_tf_wallet_password safeResignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    [self endInput];
    return YES;
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
