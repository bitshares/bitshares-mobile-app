//
//  VCSelectApiNode.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCSelectApiNode.h"
#import "VCAddNewApiNode.h"
#import "ViewApiNodeCell.h"
#import "GrapheneConnection.h"

enum
{
    kActionOpSwitch = 0,    //  切换到该节点
    kActionOpRemoveNode,    //  移除该节点（仅自定义节点可移除）
    kActionOpCopyURL,       //  复制节点URL
};

@interface VCSelectApiNode ()
{
    UITableView*            _mainTableView;
    
    NSMutableArray*         _dataArray;
    NSMutableDictionary*    _user_config;
}

@end

@implementation VCSelectApiNode

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _user_config = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray array];
        id network_infos = [[ChainObjectManager sharedChainObjectManager] getCfgNetWorkInfos];
        assert(network_infos);
        [_dataArray addObjectsFromArray:[network_infos objectForKey:@"ws_node_list"]];
        id user_config = [[SettingManager sharedSettingManager] getUseConfig:kSettingKey_ApiNode];
        if (user_config) {
            _user_config = [user_config mutableCopy];
            id list = [_user_config objectForKey:kSettingKey_ApiNode_CustomList];
            if (list) {
                [_dataArray addObjectsFromArray:list];
            }
        } else {
            _user_config = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

/*
 *  (private) 新增API节点
 */
- (void)onAddNewAssetClicked
{
    NSMutableDictionary* url_hash = [NSMutableDictionary dictionary];
    for (id node in _dataArray) {
        [url_hash setObject:@YES forKey:[node objectForKey:@"url"]];
    }
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCAddNewApiNode* vc = [[VCAddNewApiNode alloc] initWithUrlHash:[url_hash copy] result_promise:result_promise];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleNewApiNode", @"添加节点") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id new_node) {
        if (new_node) {
            assert(![url_hash objectForKey:[new_node objectForKey:@"url"]]);
            //  添加到列表
            id list = [_user_config objectForKey:kSettingKey_ApiNode_CustomList];
            NSMutableArray* mlist = list ? [list mutableCopy] : [NSMutableArray array];
            [mlist addObject:new_node];
            [_user_config setObject:[mlist copy] forKey:kSettingKey_ApiNode_CustomList];
            [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_ApiNode obj:[_user_config copy]];
            //  刷新UI
            [_dataArray addObject:new_node];
            [_mainTableView reloadData];
        }
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewAssetClicked)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    _mainTableView.tintColor = [ThemeManager sharedThemeManager].tintColor;
}

- (BOOL)isCurrentSelected:(NSIndexPath*)indexPath
{
    id current_node = [_user_config objectForKey:kSettingKey_ApiNode_Current];
    if (current_node) {
        id node = indexPath.row == 0 ? nil : [_dataArray objectAtIndex:indexPath.row - 1];
        return indexPath.row != 0 && [[current_node objectForKey:@"url"] isEqualToString:[node objectForKey:@"url"]];
    } else {
        return indexPath.row == 0;
    }
}

#pragma mark- TableView delegate method

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1 + [_dataArray count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 28 * 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.showCustomBottomLine = YES;
        if ([self isCurrentSelected:indexPath]){
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        cell.textLabel.text = NSLocalizedString(@"kSettingApiRandomCell", @"自动选择节点");
        return cell;
    } else {
        static NSString* identify = @"id_api_node_info_cell";
        ViewApiNodeCell* cell = (ViewApiNodeCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell) {
            cell = [[ViewApiNodeCell alloc] init];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.showCustomBottomLine = YES;
        
        if ([self isCurrentSelected:indexPath]){
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.item = [_dataArray objectAtIndex:indexPath.row - 1];
        
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id current_node = [_user_config objectForKey:kSettingKey_ApiNode_Current];
    
    if (indexPath.row == 0) {
        //  当前默认就是随机选择节点，直接返回。
        if (!current_node) {
            return;
        }
        //  准备切换为随机选择
        [[self switchToRandomSelectCore] then:^id(id success) {
            if ([success boolValue]) {
                //  切换成功
                [self onSetNewCurrentNode:nil];
            } else {
                //  重新随机初始化网络失败
                [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            }
            return nil;
        }];
    } else {
        //  点击某个节点
        id node = [_dataArray objectAtIndex:indexPath.row - 1];
        NSMutableArray* oplist = [NSMutableArray array];
        BOOL bCurrentUsingNode = current_node && [[node objectForKey:@"url"] isEqualToString:[current_node objectForKey:@"url"]];
        if (!bCurrentUsingNode) {
            [oplist addObject:@{@"name":NSLocalizedString(@"kSettingApiOpSetAsCurrent", @"设置为当前节点"), @"type":@(kActionOpSwitch)}];
        }
        if ([[node objectForKey:@"_is_custom"] boolValue]) {
            [oplist addObject:@{@"name":NSLocalizedString(@"kSettingApiOpRemoveNode", @"移除节点"), @"type":@(kActionOpRemoveNode)}];
        }
        [oplist addObject:@{@"name":NSLocalizedString(@"kSettingApiOpCopyURL", @"复制链接"), @"type":@(kActionOpCopyURL)}];
        //  显示 - 操作列表
        [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                           message:nil
                                                            cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                             items:oplist
                                                               key:@"name"
                                                          callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
         {
            if (buttonIndex != cancelIndex){
                switch ([[[oplist objectAtIndex:buttonIndex] objectForKey:@"type"] integerValue]) {
                    case kActionOpSwitch:
                    {
                        [self showBlockViewWithTitle:NSLocalizedString(@"kSettingApiSwitchTips", @"正在切换节点…")];
                        [[GrapheneConnection checkNodeStatus:node
                                               max_retry_num:0
                                             connect_timeout:10
                                          return_connect_obj:YES] then:^id(id node_status) {
                            [self hideBlockView];
                            if ([[node_status objectForKey:@"connected"] boolValue]) {
                                //  更新设置
                                [self onSetNewCurrentNode:node];
                                //  更新当前节点
                                [[GrapheneConnectionManager sharedGrapheneConnectionManager] switchTo:[node_status objectForKey:@"conn_obj"]];
                            } else {
                                [OrgUtils makeToast:NSLocalizedString(@"kSettingApiSwitchFailed", @"连接当前节点失败，请稍后再试。")];
                            }
                            return nil;
                        }];
                    }
                        break;
                    case kActionOpRemoveNode:
                    {
                        if (bCurrentUsingNode) {
                            [OrgUtils makeToast:NSLocalizedString(@"kSettingApiRemoveInUsing", @"使用中，请先切换到其他节点。")];
                        } else {
                            [self onActionRemoveNodeClicked:node];
                        }
                    }
                        break;
                    case kActionOpCopyURL:
                    {
                        id value = [node objectForKey:@"url"];
                        [UIPasteboard generalPasteboard].string = [value copy];
                        [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsCopyOK", @"已复制")];
                    }
                        break;
                    default:
                        break;
                }
            }
        }];
    }
}

- (void)onSetNewCurrentNode:(id)node
{
    if (node) {
        //  选择：新节点
        [_user_config setObject:node forKey:kSettingKey_ApiNode_Current];
    } else {
        //  选择：随机 - 移除之前的节点
        [_user_config removeObjectForKey:kSettingKey_ApiNode_Current];
    }
    
    [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_ApiNode obj:[_user_config copy]];
    [_mainTableView reloadData];
}

/*
 *  (private) 切换到 - 随机选择节点，切换成功返回 Promise YES，否则返回 Promise NO。
 */
- (WsPromise*)switchToRandomSelectCore
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [self showBlockViewWithTitle:NSLocalizedString(@"kSettingApiSwitchTips", @"正在切换节点…")];
        GrapheneConnectionManager* connMgr = [[GrapheneConnectionManager alloc] init];
        [[[connMgr Start:YES] then:^id(id success) {
            [self hideBlockView];
            [GrapheneConnectionManager replaceWithNewGrapheneConnectionManager:connMgr];
            resolve(@YES);
            return nil;
        }] catch:^id(id error) {
            [self hideBlockView];
            resolve(@NO);
            return nil;
        }];
    }];
}

/*
 *  (private) 删除节点
 */
- (void)onActionRemoveNodeClicked:(id)remove_node
{
    assert(remove_node);
    NSString* remove_url = [remove_node objectForKey:@"url"];
    NSMutableArray* mlist = [[_user_config objectForKey:kSettingKey_ApiNode_CustomList] mutableCopy];
    assert(mlist);
    for (id node in mlist) {
        if ([[node objectForKey:@"url"] isEqualToString:remove_url]) {
            [mlist removeObject:node];
            //  使用中的节点不可删除。
            assert(![_user_config objectForKey:kSettingKey_ApiNode_Current] ||
                   ![[[_user_config objectForKey:kSettingKey_ApiNode_Current] objectForKey:@"url"] isEqualToString:remove_url]);
            //  保存
            [_user_config setObject:[mlist copy] forKey:kSettingKey_ApiNode_CustomList];
            [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_ApiNode obj:[_user_config copy]];
            break;
        }
    }
    
    //  刷新UI
    [_dataArray removeObject:remove_node];
    [_mainTableView reloadData];
}

@end
