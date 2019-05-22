//
//  VCImportWallet.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCImportWallet.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"

@interface VCImportWallet ()
{
    __weak VCBase*      _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSString*           _importDir;
    GCDWebUploader*     _webServer;
    
    UITableViewBase*    _mainTableView;
    NSArray*            _dataArray;
}

@end

@implementation VCImportWallet

- (void)stopWebServer
{
    if (_webServer){
        [_webServer stop];
        _webServer.delegate = nil;
        _webServer = nil;
    }
}
-(void)dealloc
{
    _owner = nil;
    
    _dataArray = nil;
    _importDir = nil;
    
    [self stopWebServer];
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _importDir = [NSString stringWithFormat:@"%@", [OrgUtils getAppDirWebServerImport]];
    
    //  考虑初始化 webserver
    _webServer = nil;
    
    NSString* tip_message = NSLocalizedString(@"kLoginTipsUnsupportImportWalletFile", @"该手机不支持导入钱包文件。");
    
    if ([[NativeAppDelegate sharedAppDelegate] isNetworkViaWifi])
    {
        //  创建目录
        NSError* error = nil;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:_importDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error){
            //  [统计]
            [OrgUtils logEvents:@"system_error"
                           params:@{@"message":[NSString stringWithFormat:@"createDirectoryAtPath %@", error]}];
            NSLog(@"createDirectoryAtPath error:%@", error);
            tip_message = NSLocalizedString(@"kLoginTipsImportInitError", @"发生未知错误，不能导入钱包，请稍后再试。");
        }else{
            _webServer = [[GCDWebUploader alloc] initWithUploadDirectory:_importDir];
            _webServer.delegate = self;
            _webServer.allowHiddenItems = NO;
            if ([_webServer start]) {
                //  启动 webserver 成功
                tip_message = NSLocalizedString(@"kLoginTipsPleaseInputURL", @"请在电脑端输入以上网址导入钱包BIN文件到手机。");
            }else{
                _webServer.delegate = nil;
                _webServer = nil;
                tip_message = NSLocalizedString(@"kLoginTipsInitWebserverError", @"设备网络异常，暂时不能导入钱包，请稍后再试。");
            }
        }
    }
    else
    {
        tip_message = NSLocalizedString(@"kLoginTipsImportOnlyViaWIFI", @"仅支持在WIFI网络下导入钱包。");
    }
    
    //  UI - 上传地址
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat yOffset = 44;//screenRect.size.height * 0.1;
    
    UILabel* headerUploadAddr = [[UILabel alloc] initWithFrame:CGRectMake(12, yOffset, screenRect.size.width - 24, 44)];
    headerUploadAddr.lineBreakMode = NSLineBreakByWordWrapping;
    headerUploadAddr.numberOfLines = 1;
    headerUploadAddr.contentMode = UIViewContentModeCenter;
    headerUploadAddr.backgroundColor = [UIColor clearColor];
    headerUploadAddr.textColor = [ThemeManager sharedThemeManager].textColorMain;
    headerUploadAddr.textAlignment = NSTextAlignmentCenter;
    headerUploadAddr.font = [UIFont boldSystemFontOfSize:26];
    headerUploadAddr.adjustsFontSizeToFitWidth = YES;
    if (_webServer){
        //  80端口不用显示，浏览器默认打开80端口。
        int port = (int)_webServer.port;
        if (port == 80){
            headerUploadAddr.text = [NSString stringWithFormat:@"%@", [OrgUtils getIPAddress]];
        }else{
            headerUploadAddr.text = [NSString stringWithFormat:@"%@:%d", [OrgUtils getIPAddress], port];
        }
    }else{
        headerUploadAddr.text = NSLocalizedString(@"kLoginTipsOnlyViaWifiMainDesc", @"初始化服务器失败");
    }
    [self.view addSubview:headerUploadAddr];
    
    //  UI - 辅助说明
    UILabel* headerDesc = [[UILabel alloc] initWithFrame:CGRectMake(12, yOffset + 44, screenRect.size.width - 24, 22 * 2)];
    headerDesc.lineBreakMode = NSLineBreakByWordWrapping;
    headerDesc.numberOfLines = 0;
    headerDesc.contentMode = UIViewContentModeCenter;
    headerDesc.backgroundColor = [UIColor clearColor];
    headerDesc.textColor = [ThemeManager sharedThemeManager].textColorMain;
    headerDesc.textAlignment = NSTextAlignmentCenter;
    headerDesc.font = [UIFont boldSystemFontOfSize:14];
    headerDesc.adjustsFontSizeToFitWidth = YES;
    headerDesc.text = tip_message;
    [self.view addSubview:headerDesc];
    
    //  UI - 列表
    _dataArray = [self loadUploadDirFileList];
    yOffset = 2 * yOffset + 44 + 22 * 2;
    CGRect rect = CGRectMake(0, yOffset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - 32 - yOffset - [self heightForBottomSafeArea]);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
}

#pragma mark- aux method

- (void)refreshTableView
{
    _dataArray = [self loadUploadDirFileList];
    [_mainTableView reloadData];
}

- (NSArray*)loadUploadDirFileList
{
    NSError* error = nil;
    NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_importDir error:&error];
    if (!contents || error){
        return @[];
    }
    NSMutableArray* dataArray = [NSMutableArray array];
    
    for (NSString* item in [contents sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        if (!_webServer || _webServer.allowHiddenItems || ![item hasPrefix:@"."]) {
            NSString* fullPath = [_importDir stringByAppendingPathComponent:item];
            NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
            NSString* type = [attributes objectForKey:NSFileType];
            if ([type isEqualToString:NSFileTypeRegular]) {
                [dataArray addObject:@{
                                       @"path" : fullPath,
                                       @"name" : item,
                                       @"size" : (NSNumber*)[attributes objectForKey:NSFileSize]
                                       }];
            }
        }
    }
    
    return [dataArray copy];
}

#pragma mark- GCDWebUploaderDelegate

- (void)webUploader:(GCDWebUploader*)uploader didUploadFileAtPath:(NSString*)path {
    NSLog(@"[UPLOAD] %@", path);
    [self refreshTableView];
}

- (void)webUploader:(GCDWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    NSLog(@"[MOVE] %@ -> %@", fromPath, toPath);
    [self refreshTableView];
}

- (void)webUploader:(GCDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path {
    NSLog(@"[DELETE] %@", path);
    [self refreshTableView];
}

- (void)webUploader:(GCDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path {
    NSLog(@"[CREATE] %@", path);
    [self refreshTableView];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
//    
//    return baseHeight;
//}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    CGFloat fWidth = self.view.bounds.size.width;
    
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];    //  REMARK：12 和 ViewMarketTickerInfoCell 里控件边距一致。
    titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    if (_webServer){
        titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLoginTipsReceivedFileNumber", @"收到的文件(%@个)"), @([_dataArray count])];
    }else{
        titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLoginTipsLocalWalletFileNumber", @"本机钱包文件(%@个)"), @([_dataArray count])];
    }
    [myView addSubview:titleLabel];
    
    return myView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    [dataArray addObject:@{
//                           @"path" : fullPath,
//                           @"name" : item,
//                           @"size" : (NSNumber*)[attributes objectForKey:NSFileSize]
//                           }];
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = [[_dataArray objectAtIndex:indexPath.row] objectForKey:@"name"];
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    cell.detailTextLabel.text = NSLocalizedString(@"kLoginCellClickImport", @"点击导入");
    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id item = [_dataArray objectAtIndex:indexPath.row];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kLoginTipsImportWalletTitle", @"导入钱包")
                                                          withTitle:nil
                                                        placeholder:NSLocalizedString(@"unlockTipsPleaseInputWalletPassword", @"请输入钱包密码")
                                                         ispassword:YES
                                                                 ok:NSLocalizedString(@"kLoginBtnImportNow", @"立即导入")
                                                         completion:^(NSInteger buttonIndex, NSString *tfvalue) {
                                                             if (buttonIndex != 0){
                                                                 [self processImportWalletCore:tfvalue fileitem:item];
                                                             }
                                                         }];
    }];
}

- (void)processImportWalletCore:(NSString*)wallet_password fileitem:(NSDictionary*)fileitem
{
    if ([self isStringEmpty:wallet_password])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsPleaseInputPassword", @"请输入密码。")];
        return;
    }
    
    NSData* wallet_bindata = [NSData dataWithContentsOfFile:[fileitem objectForKey:@"path"]];
    if (!wallet_bindata){
        //  输入密码过程中用户删除了文件等情况。
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsReadWalletFailed", @"读取钱包文件失败。")];
        return;
    }
    
    //  加载钱包对象
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    id wallet_object = [walletMgr loadFullWallet:wallet_bindata wallet_password:wallet_password];
    if (!wallet_object){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsInvalidFileOrPassword", @"钱包文件无效或密码不正确。")];
        return;
    }
    
    //  加载成功判断钱包有效性
    id wallet = [[wallet_object objectForKey:@"wallet"] firstObject];
    if (![[wallet objectForKey:@"chain_id"] isEqualToString:chainMgr.grapheneChainID]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsNotBTSWallet", @"该钱包不是Bitshares区块链的钱包。")];
        return;
    }
    
    id linked_accounts = [wallet_object objectForKey:@"linked_accounts"];
    if (!linked_accounts || [linked_accounts count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsWalletIsEmpty", @"该钱包为空钱包，请重选选择。")];
        return;
    }
    id first_account = [linked_accounts firstObject];
    assert(first_account);
    NSString* first_name = [first_account objectForKey:@"name"];
    
    id private_keys = [wallet_object objectForKey:@"private_keys"];
    if ([private_keys count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsWalletNoPrivateKey", @"该钱包不包含密钥信息，请重新选择。")];
        return;
    }
    
    NSMutableArray* pubkey_list = [NSMutableArray array];
    NSMutableDictionary* pubkey_keyitem_hash = [NSMutableDictionary dictionary];
    for (id key_item in private_keys) {
        id pubkey = key_item[@"pubkey"];
        [pubkey_list addObject:pubkey];
        [pubkey_keyitem_hash setObject:key_item forKey:pubkey];
    }
    
    //  查询 Key 详情
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAccountDataHashFromKeys:pubkey_list] then:(^id(id account_data_hash) {
        if ([account_data_hash count] <= 0){
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsWalletIsEmpty", @"该钱包为空钱包，请重选选择。")];
            return nil;
        }
        //  获取当前账号
        NSDictionary* currentAccountData = nil;
        for (id uid in account_data_hash) {
            id account_data = [account_data_hash objectForKey:uid];
            assert(account_data);
            if (!currentAccountData || (first_name && [first_name isEqualToString:account_data[@"name"]])){
                currentAccountData = account_data;
            }
        }
        assert(currentAccountData);
        //  查询当前账号的详细信息
        id current_account_id = [currentAccountData objectForKey:@"id"];
        id current_accout_name = [currentAccountData objectForKey:@"name"];
        assert(current_account_id && current_accout_name);
        return [[chainMgr queryFullAccountInfo:current_account_id] then:(^id(id full_data) {
            [_owner hideBlockView];
            
            if (!full_data || [full_data isKindOfClass:[NSNull class]])
            {
                //  这里的帐号信息应该存在，因为帐号ID是通过 get_key_references 返回的。
                [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsQueryAccountFailed", @"查询帐号信息失败，请稍后再试。")];
                return nil;
            }
            
            //  导入钱包不用验证active权限，允许无权限导入。
            
            //  保存钱包信息
            [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmFullWalletMode
                                                       accountInfo:full_data
                                                       accountName:current_accout_name
                                                     fullWalletBin:wallet_bindata];
            //  导入成功 直接解锁。
            id unlockInfos = [walletMgr unLock:wallet_password];
            assert(unlockInfos &&
                   [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
            //  [统计]
            [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(kwmFullWalletMode), @"desc":@"wallet"}];
            
            //  返回之前先关闭webserver
            [self stopWebServer];
            
            //  返回
            [_owner.myNavigationController tempDisableDragBack];
            [OrgUtils showMessageUseHud:NSLocalizedString(@"kLoginTipsLoginOK", @"登录成功。")
                                   time:1
                                 parent:_owner.navigationController.view
                        completionBlock:^{
                            [_owner.myNavigationController tempEnableDragBack];
                            [_owner.navigationController popViewControllerAnimated:YES];
                        }];
            
            return nil;
        })];
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    })];
}

@end
