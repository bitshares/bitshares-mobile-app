//
//  VCNewAccountPassword.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCNewAccountPassword.h"
#import "ViewTipsInfoCell.h"
#import "ViewNewPasswordCell.h"
#import "VCNewAccountPasswordConfirm.h"

enum
{
    kVcNewPassword = 0,
    kVcSubmit,
    kVcCellTips,
    
    kVcMax
};

enum
{
    kVcSubNewPasswordTitle = 0,
    kVcSubNewPasswordContent,
    
    kVcSubMax,
};

@interface VCNewAccountPassword ()
{
    UITableView *                   _mainTableView;
    UITableViewCellBase*            _cellTitle;
    ViewNewPasswordCell*            _passwordContent;
    
    EBitsharesAccountPasswordLang   _currPasswordLang;
    
    ViewBlockLabel*                 _lbSubmit;
    ViewTipsInfoCell*               _cellTips;
}

@end

@implementation VCNewAccountPassword

-(void)dealloc
{
    _cellTitle = nil;
    _lbSubmit = nil;
    _cellTips = nil;
    _passwordContent = nil;
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
        //  REMARK：根据当前语言决定默认密码语言。
        NSString* pass_lang_string = NSLocalizedString(@"kEditPasswordDefaultPasswordLang", @"default password lang string");
        if (pass_lang_string && [pass_lang_string isEqualToString:@"zh"]) {
            _currPasswordLang = ebap_lang_zh;
        } else {
            _currPasswordLang = ebap_lang_en;
        }
    }
    return self;
}

/*
 *  (private) 处理密码生成
 */
- (void)processGeneratePassword
{
    id new_words;
    if (_currPasswordLang == ebap_lang_zh) {
        new_words = [WalletManager randomGenerateChineseWord_N16];
    } else {
        new_words = [WalletManager randomGenerateEnglishWord_N32];
    }
    [_passwordContent updateWithNewContent:new_words lang:_currPasswordLang];
}

/*
 *  (private) 切换密码语言。
 */
- (void)onSwitchPasswordLangButtonClicked:(UIButton*)sender
{
    //  切换
    if (_currPasswordLang == ebap_lang_zh) {
        _currPasswordLang = ebap_lang_en;
    } else {
        _currPasswordLang = ebap_lang_zh;
    }
    //  刷新切换按钮
    UIButton* btn = (UIButton*)_cellTitle.accessoryView;
    assert(btn);
    [btn updateTitleWithoutAnimation:[self switchPasswordLangButtonString]];
    //  刷新描述信息
    [_cellTips updateLabelText:[self getCellTipsMessage]];
    //  生成密码
    [self processGeneratePassword];
    [_mainTableView reloadData];
}

- (NSString*)switchPasswordLangButtonString
{
    return _currPasswordLang == ebap_lang_zh ? NSLocalizedString(@"kEditPasswordSwitchToEnPassword", @"切换英文密码") : NSLocalizedString(@"kEditPasswordSwitchToZhPassword", @"切换中文密码");
}

- (NSString*)getCellTipsMessage
{
    return [NSString stringWithFormat:NSLocalizedString(@"kEditPasswordUiSecTips", @"【温馨提示】\n请勿复制、拍照、截图。\n请使用纸笔按照从左到右、从上到下的顺序依次记录以上 %@ 个字符组成的密码，并妥善保存。丢失后将无法找回。"), @(_currPasswordLang == ebap_lang_zh ? 16 : 32)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    _cellTitle = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellTitle.backgroundColor = [UIColor clearColor];
    _cellTitle.hideBottomLine = YES;
    _cellTitle.accessoryType = UITableViewCellAccessoryNone;
    _cellTitle.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellTitle.textLabel.text = NSLocalizedString(@"kEditPasswordCellTitleYourNewPassword", @"您的新密码");
    _cellTitle.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellTitle.textLabel.textColor = theme.textColorMain;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:[self switchPasswordLangButtonString] forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onSwitchPasswordLangButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    btn.frame = CGRectMake(0, 0, 130, 31);
    _cellTitle.accessoryView = btn;
    
    //  UI - 当前密码
    _passwordContent = [[ViewNewPasswordCell alloc] init];
    [self processGeneratePassword];
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kEditPasswordBtnNext", @"下一步")];
    
    //  提示
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:[self getCellTipsMessage]];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
}

/*
 *  (private) 转到下一步
 */
- (void)onSubmitClicked
{
    VCNewAccountPasswordConfirm* vc = [[VCNewAccountPasswordConfirm alloc] initWithPassword:_passwordContent.current_password
                                                                                   passlang:_currPasswordLang];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleEditPasswordConfirm", @"验证密码") backtitle:kVcDefaultBackTitleName];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcNewPassword:
        {
            if (indexPath.row == kVcSubNewPasswordContent) {
                return 8 + 28 * 2 + 8;
            }
        }
            break;
        case kVcCellTips:
            return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
            
        default:
            break;
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcNewPassword:
            return kVcSubMax;
        default:
            break;
    }
    return 1;
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
        case kVcNewPassword:
        {
            switch (indexPath.row) {
                case kVcSubNewPasswordTitle:
                    return _cellTitle;
                    
                case kVcSubNewPasswordContent:
                    return _passwordContent;
                    
                default:
                    assert(false);
                    break;
            }
        }
            break;
        case kVcSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcCellTips:
            return _cellTips;
        default:
            break;
    }
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSubmit){
            [self onSubmitClicked];
        }
    }];
}

@end
