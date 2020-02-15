//
//  VCSelectApiNode.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCSelectApiNode.h"
#import "GrapheneConnection.h"

@interface VCSelectApiNode ()
{
    UITableView*            _mainTableView;
    
    NSArray*                _dataArray;
    NSString*               _currEstimateAssetSymbol;
}

@end

@implementation VCSelectApiNode

- (id)init
{
    self = [super init];
    if (self) {
        id network_infos = [[ChainObjectManager sharedChainObjectManager] getCfgNetWorkInfos];
        assert(network_infos);
        _dataArray = [network_infos objectForKey:@"ws_node_list"];
        
        _currEstimateAssetSymbol = [[[SettingManager sharedSettingManager] getEstimateAssetSymbol] copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;

    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    _mainTableView.tintColor = [ThemeManager sharedThemeManager].tintColor;
}

- (void)dealloc
{
    _currEstimateAssetSymbol = nil;
    _dataArray = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    id node = [_dataArray objectAtIndex:indexPath.row];
//    NSString* estimateAssetSymbol = [estimateAsset objectForKey:@"symbol"];
//    if ([estimateAssetSymbol isEqualToString:_currEstimateAssetSymbol]){
//        cell.accessoryType = UITableViewCellAccessoryCheckmark;
//    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
//    }
    cell.showCustomBottomLine = YES;
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = node[@"location"];
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    cell.detailTextLabel.text = node[@"url"];
    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    id estimateAssetSymbol = [[_dataArray objectAtIndex:indexPath.row] objectForKey:@"symbol"];
//    if (![estimateAssetSymbol isEqualToString:_currEstimateAssetSymbol]){
//        _currEstimateAssetSymbol = [estimateAssetSymbol copy];
//        //  [统计]
//        [OrgUtils logEvents:@"selectSstimateAsset" params:@{@"symbol":_currEstimateAssetSymbol}];
//        [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_EstimateAssetSymbol obj:_currEstimateAssetSymbol];
//        [tableView reloadData];
//    }
//    else
//    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [self onNodeClicked:[_dataArray objectAtIndex:indexPath.row]];
    }];
    
//    }
}

- (void)onNodeClicked:(id)node
{
    //  TODO:5.0
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    GrapheneConnection* conn = [[GrapheneConnection alloc] initWithNode:node[@"url"] max_retry_num:2 connect_timeout:10];
    [[conn run_connection] then:^id(id success) {
        if ([success boolValue]) {
            
            [[[conn.api_db exec:@"get_objects" params:@[@[BTS_DYNAMIC_GLOBAL_PROPERTIES_ID]]] then:^id(id data_array) {
                [self hideBlockView];
                
                id obj = [data_array firstObject];
                
                [conn close_connection];
                [OrgUtils makeToast:[NSString stringWithFormat:@"连接测试成功，最新区块时间。%@", obj[@"time"]]];
                
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [conn close_connection];
                
                [OrgUtils makeToast:@"连接测试成功，响应很慢。"];
                
                return nil;
            }];
            
        } else {
            [self hideBlockView];
            [OrgUtils makeToast:@"连接失败。"];
        }
        return nil;
    }];
}

@end
