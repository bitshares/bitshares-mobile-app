//
//  VCBlindAccountImport.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindAccountImport.h"

#import "ViewAdvTextFieldCell.h"

enum
{
    kVcSecAliasName = 0,
    kVcSecBlindPassword,
    kVcSecAction,
    
    kVcSecMax
};

@interface VCBlindAccountImport ()
{
    UITableViewBase*        _mainTableView;
    
    ViewAdvTextFieldCell*   _cell_alias_name;
    ViewAdvTextFieldCell*   _cell_password;
    
    ViewBlockLabel*         _lbCommit;
    
    WsPromiseObject*        _result_promise;
}

@end

@implementation VCBlindAccountImport

-(void)dealloc
{
    _cell_alias_name = nil;
    _cell_password = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 别名输入
    _cell_alias_name = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kVcStCellTitleAliasName", @"别名")
                                                       placeholder:NSLocalizedString(@"kVcStPlaceholderInputAliasName", @"为隐私账户设置一个别名")];
    
    //  UI - 密码输入
    _cell_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kVcStCellTitleBlindAccountBrainKey", @"密码")
                                                     placeholder:NSLocalizedString(@"kVcStPlaceholderBlindAccountBrainKey", @"请输入隐私账户密码")];
    
    //  UI - 列表
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcStBtnImportNow", @"导入")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self endInput];
    return YES;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecAliasName) {
        return _cell_alias_name.cellHeight;
    } else if (indexPath.section == kVcSecBlindPassword) {
        return _cell_password.cellHeight;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecAliasName:
            return _cell_alias_name;
            
        case kVcSecBlindPassword:
            return _cell_password;
            
        case kVcSecAction:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSecAction){
            [self onSubmitClicked];
        }
    }];
}

- (void)onSubmitClicked
{
    [self endInput];
    
    id str_alias_name = [NSString trim:_cell_alias_name.mainTextfield.text];
    id str_password = [NSString trim:_cell_password.mainTextfield.text];
    
    [VcUtils processImportBlindAccount:self alias_name:str_alias_name password:str_password success_callback:^(id blind_account) {
        assert(blind_account);
        //  导入成功
        if (_result_promise) {
            [_result_promise resolve:blind_account];
        }
        [self closeOrPopViewController];
    }];
}

- (void)endInput
{
    [self.view endEditing:YES];
    [_cell_alias_name endInput];
    [_cell_password endInput];
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
