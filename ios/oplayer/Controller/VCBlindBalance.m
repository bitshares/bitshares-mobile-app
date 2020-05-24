//
//  VCBlindBalance.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindBalance.h"
#import "ViewBlindBalanceCell.h"

#import "VCBlindBalanceImport.h"
#import "VCBlindTransfer.h"
#import "VCTransferFromBlind.h"

#import "GraphenePublicKey.h"
#import "GrapheneSerializer.h"
#import "BitsharesClientManager.h"

@interface VCBlindBalance ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCBlindBalance

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self){
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryBlindBalanceAndDependenceResponsed:(id)data_array
{
    [_dataArray removeAllObjects];
    [_dataArray addObjectsFromArray:data_array];
    [self refreshUI:NO];
}

- (void)queryBlindBalanceAndDependence
{
    id data_array = [[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues];
    NSMutableDictionary* ids = [NSMutableDictionary dictionary];
    for (id blind_balance in data_array) {
        [ids setObject:@YES forKey:[[[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"amount"] objectForKey:@"asset_id"]];
    }
    if ([ids count] > 0) {
        [VcUtils simpleRequest:self
                       request:[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:[ids allKeys]]
                      callback:^(id data) {
            [self onQueryBlindBalanceAndDependenceResponsed:data_array];
        }];
    } else {
        [self onQueryBlindBalanceAndDependenceResponsed:data_array];
    }
}

- (void)refreshUI:(BOOL)reload_data
{
    //  获取所有收据数据，收据格式：
    //    @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //    @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //    @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //    @"decrypted_memo": @{
    //        @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //        @"blinding_factor": @"",                                                //  转账用
    //        @"commitment": @"",                                                     //  转账用
    //        @"check": @331,                                                         //  导入check用，显示用。
    //    }
    if (reload_data) {
        [_dataArray removeAllObjects];
        [_dataArray addObjectsFromArray:[[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues]];
    }
    
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    
    //  刷新
    if (!_mainTableView.hidden) {
        [_mainTableView reloadData];
    }
}

- (void)onImportBlindOutputReceipt
{
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCBlindBalanceImport* vc = [[VCBlindBalanceImport alloc] initWithReceipt:nil result_promise:result_promise];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleImportBlindReceipt", @"导入收据") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id dirty) {
        //  刷新UI
        if (dirty && [dirty boolValue]) {
            [self refreshUI:YES];
        }
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onImportBlindOutputReceipt)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcStTipEmptyNoBlindCanImport", @"没有任何隐私收据，可点击右上角导入收据。")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询数据依赖
    [self queryBlindBalanceAndDependence];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_blind_balance_cell";
    ViewBlindBalanceCell* cell = (ViewBlindBalanceCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewBlindBalanceCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.row = indexPath.row;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                           message:nil
                                                            cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                             items:@[NSLocalizedString(@"kVcStBlindBalanceActionTransferFromBlind", @"隐私账户转出"),
                                                                     NSLocalizedString(@"kVcStBlindBalanceActionBlindTransfer", @"隐私转账")]
                                                          callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
         {
            if (buttonIndex != cancelIndex){
                //  REMARK：这里转出or继续隐私转账成功都会clear push到新界面，所以不用刷新该界面自身。
                if (buttonIndex == 0){
                    id blind_balance = [_dataArray objectAtIndex:indexPath.row];
                    VCTransferFromBlind* vc = [[VCTransferFromBlind alloc] initWithBlindBalance:blind_balance];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleTransferFromBlind", @"隐私账户转出")
                                   backtitle:kVcDefaultBackTitleName];
                } else {
                    id blind_balance = [_dataArray objectAtIndex:indexPath.row];
                    VCBlindTransfer* vc = [[VCBlindTransfer alloc] initWithBlindBalance:blind_balance result_promise:nil];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleBlindTransfer", @"隐私转账")
                                   backtitle:kVcDefaultBackTitleName];
                }
            }
        }];
    }];
}

@end
