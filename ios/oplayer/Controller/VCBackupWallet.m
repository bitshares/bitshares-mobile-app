//
//  VCBackupWallet.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBackupWallet.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"

@interface VCBackupWallet ()
{
    NSString*           _importDir;
    GCDWebUploader*     _webServer;
    
    UILabel*            _label;
    UITableViewBase*    _mainTableView;
    NSArray*            _dataArray;
}

@end

@implementation VCBackupWallet

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
    _dataArray = nil;
    _importDir = nil;
    _label = nil;
    [self stopWebServer];
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _label = nil;
    _webServer = nil;
    
    NSString* tip_message = NSLocalizedString(@"kBackupMobilePhoneNotSupported", @"该手机不支持备份钱包文件。");
    
    if ([[NativeAppDelegate sharedAppDelegate] isNetworkViaWifi])
    {
        _importDir = [NSString stringWithFormat:@"%@", [OrgUtils getAppDirWebServerImport]];
        
        //  到处钱包文件
        if (![[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:YES]){
            //  [统计]
            [OrgUtils logEvents:@"system_error" params:@{@"message":@"backupwallet to webdir failed."}];
            NSLog(@"backup wallet to webdir failed...");
        }
        
        //  创建目录
        NSError* error = nil;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:_importDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error){
            //  [统计]
            [OrgUtils logEvents:@"system_error"
                           params:@{@"message":[NSString stringWithFormat:@"createDirectoryAtPath %@", error]}];
            NSLog(@"createDirectoryAtPath error:%@", error);
            tip_message = NSLocalizedString(@"kBackupInitUnknownError", @"发生未知错误，不能备份钱包，请稍后再试。");
        }else{
            _webServer = [[GCDWebUploader alloc] initWithUploadDirectory:_importDir];
            _webServer.delegate = self;
            _webServer.allowHiddenItems = NO;
            
            if ([_webServer start]) {
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
                //  80端口不用显示，浏览器默认打开80端口。
                int port = (int)_webServer.port;
                if (port == 80){
                    headerUploadAddr.text = [NSString stringWithFormat:@"%@", [OrgUtils getIPAddress]];
                }else{
                    headerUploadAddr.text = [NSString stringWithFormat:@"%@:%d", [OrgUtils getIPAddress], port];
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
                headerDesc.text = NSLocalizedString(@"kBackupPleaseInputURL", @"请在电脑端输入以上网址下载钱包BIN文件备份到安全的地方。");
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
            } else {
                _webServer.delegate = nil;
                _webServer = nil;
                tip_message = NSLocalizedString(@"kBackupInitWebserverError", @"设备网络异常，暂时不能备份钱包，请稍后再试。");
            }
        }
    }
    else
    {
        tip_message = NSLocalizedString(@"kBackupWalletOnlyViaWIFI", @"仅支持在WIFI网络下备份钱包。");
    }
    
    //  没启动 webserver 则显示提示信息
    if (!_webServer){
        assert(tip_message);
        _label = [[UILabel alloc] initWithFrame:[self rectWithoutNaviAndTab]];
        _label.lineBreakMode = NSLineBreakByWordWrapping;
        _label.numberOfLines = 1;
        _label.contentMode = UIViewContentModeCenter;
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [UIFont boldSystemFontOfSize:13];
        _label.textColor = [ThemeManager sharedThemeManager].textColorGray;
        _label.adjustsFontSizeToFitWidth = YES;
        [self.view addSubview:_label];
        _label.text = tip_message;
    }
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
        if (_webServer.allowHiddenItems || ![item hasPrefix:@"."]) {
            NSString* fullPath = [_importDir stringByAppendingPathComponent:item];
            NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
            NSString* type = [attributes objectForKey:NSFileType];
            if ([type isEqualToString:NSFileTypeRegular]) {
                [dataArray addObject:[@{
                                        @"path" : fullPath,
                                        @"name" : item,
                                        @"size" : (NSNumber*)[attributes objectForKey:NSFileSize],
                                        @"download":@(NO)
                                        } mutableCopy]];
            }
        }
    }
    
    return [dataArray copy];
}

#pragma mark- GCDWebUploaderDelegate
- (void)webUploader:(GCDWebUploader*)uploader didDownloadFileAtPath:(NSString*)path
{
    NSLog(@"[DOWNLOAD] %@", path);
    if (path && _dataArray){
        for (id item in _dataArray) {
            if ([[item objectForKey:@"path"] isEqualToString:path]){
                item[@"download"] = @YES;
                [_mainTableView reloadData];
                break;
            }
        }
    }
}

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
    titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kBackupTipsWalletFiles", @"该设备钱包文件(%@个)"), @([_dataArray count])];
    
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
    id item = [_dataArray objectAtIndex:indexPath.row];
    cell.textLabel.text = [item objectForKey:@"name"];
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    if ([[item objectForKey:@"download"] boolValue]){
        cell.detailTextLabel.text = NSLocalizedString(@"kBackupDownloaded", @"已下载");
        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
    }else{
        cell.detailTextLabel.text = @"";
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
