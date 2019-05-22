//
//  VCSelectTheme.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCSelectTheme.h"
//#import "Flurry.h"

@interface VCSelectTheme ()
{
    UITableView*            _mainTableView;
}

@property (nonatomic, retain)   NSArray*  dataArray;
@property (nonatomic, copy)     NSString* currThemeCode;

@end

@implementation VCSelectTheme

@synthesize dataArray;
@synthesize currThemeCode;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.dataArray = [[[ThemeManager sharedThemeManager] getThemeDataArray] copy];
        self.currThemeCode = [[[SettingManager sharedSettingManager] getThemeInfo] objectForKey:@"themeCode"];
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
    self.currThemeCode = nil;
    self.dataArray = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    id themeInfo = [self.dataArray objectAtIndex:indexPath.row];
    
    if ([[themeInfo objectForKey:@"themeCode"] isEqualToString:self.currThemeCode]){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    cell.showCustomBottomLine = YES;
    
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    id langKey = [themeInfo objectForKey:@"themeNameLangKey"];
    if (langKey){
        cell.textLabel.text = NSLocalizedString(langKey, @"主题名字");
    }else{
        cell.textLabel.text = [themeInfo objectForKey:@"themeName"];
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id themeInfo = [self.dataArray objectAtIndex:indexPath.row];
    if (![[themeInfo objectForKey:@"themeCode"] isEqualToString:self.currThemeCode]){
        
        self.currThemeCode = [[themeInfo objectForKey:@"themeCode"] copy];
        NSDictionary *params =
        [NSDictionary dictionaryWithObjectsAndKeys:self.currThemeCode, // Parameter Value
         @"theme", // Parameter Name
         nil];
        //  [统计]
        [OrgUtils logEvents:@"selectTheme" params:params];
        [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_ThemeInfo obj:themeInfo];
        [[ThemeManager sharedThemeManager] switchTheme:self.currThemeCode reload:YES];
        [tableView reloadData];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark- switch theme
- (void)switchTheme
{
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    if (_mainTableView){
        [_mainTableView reloadData];
    }
}

@end
