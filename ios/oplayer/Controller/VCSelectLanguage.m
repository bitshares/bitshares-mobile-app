//
//  VCSelectLanguage.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCSelectLanguage.h"
#import "LangManager.h"

@interface VCSelectLanguage ()
{
    UITableView*    _mainTableView;
}

@end

@implementation VCSelectLanguage

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

#pragma mark- TableView delegate method

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[LangManager sharedLangManager].dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    id langInfo = [[LangManager sharedLangManager].dataArray objectAtIndex:indexPath.row];
    
    if ([[langInfo objectForKey:@"langCode"] isEqualToString:[LangManager sharedLangManager].currLangCode]){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    cell.showCustomBottomLine = YES;
    
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    cell.textLabel.text = NSLocalizedString([langInfo objectForKey:@"langNameKey"], @"Language Name");
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id langInfo = [[LangManager sharedLangManager].dataArray objectAtIndex:indexPath.row];
    id langCode = [langInfo objectForKey:@"langCode"];
    if (![[langInfo objectForKey:@"langCode"] isEqualToString:[LangManager sharedLangManager].currLangCode]){
        //  [统计]
        [OrgUtils logEvents:@"selectLanguage" params:@{@"langCode":langCode}];
        [[LangManager sharedLangManager] saveLanguage:langCode];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
//    [self refreshBackButtonText];// refresh @ last vc
    self.title = NSLocalizedString(@"kVcTitleLanguage", @"语言");
    [_mainTableView reloadData];
}

@end
