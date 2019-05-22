//
//  VCSelectEstimateUnit.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCSelectEstimateUnit.h"

@interface VCSelectEstimateUnit ()
{
    UITableView*            _mainTableView;
    
    NSArray*                _dataArray;
    NSString*               _currEstimateAssetSymbol;
}

@end

@implementation VCSelectEstimateUnit

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _dataArray = [[ChainObjectManager sharedChainObjectManager] getEstimateUnitList];
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
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    id estimateAsset = [_dataArray objectAtIndex:indexPath.row];
    NSString* estimateAssetSymbol = [estimateAsset objectForKey:@"symbol"];
    if ([estimateAssetSymbol isEqualToString:_currEstimateAssetSymbol]){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString([estimateAsset objectForKey:@"namekey"], @"计价单位名称"), estimateAssetSymbol];
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id estimateAssetSymbol = [[_dataArray objectAtIndex:indexPath.row] objectForKey:@"symbol"];
    if (![estimateAssetSymbol isEqualToString:_currEstimateAssetSymbol]){
        _currEstimateAssetSymbol = [estimateAssetSymbol copy];
        //  [统计]
        [OrgUtils logEvents:@"selectSstimateAsset" params:@{@"symbol":_currEstimateAssetSymbol}];
        [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_EstimateAssetSymbol obj:_currEstimateAssetSymbol];
        [tableView reloadData];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

@end
