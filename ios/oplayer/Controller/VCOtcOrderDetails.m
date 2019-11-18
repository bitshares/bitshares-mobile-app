//
//  VCOtcOrderDetails.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcOrderDetails.h"
#import "OrgUtils.h"

@interface VCOtcOrderDetails ()
{
    UITableViewBase*        _mainTableView;
}

@end

@implementation VCOtcOrderDetails

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 主表格
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
}

/**
 *  事件 - 用户点击提交按钮
 */
-(void)gotoSubmitCore
{
    //  TODO:otc
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//    if (section == kVcFormData)
//        return kVcSubMax;
//    else
        return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    //  默认值
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
//    if (section != kVcSubmit){
//        return 0.01f;
//    }
    return 20.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    if (indexPath.section == kVcFormData)
//    {
//        switch (indexPath.row) {
//            case kVcSubNameTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"姓名";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubName:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_name];
//                return cell;
//            }
//                break;
//            case kVcSubIDNumberTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"身份证号";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubIDNumber:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_idnumber];
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            case kVcSubPhoneNumberTitle:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.hideBottomLine = YES;
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                cell.textLabel.text = @"联系方式";//TODO:otc
//                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
//                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//                return cell;
//            }
//                break;
//            case kVcSubPhoneNumber:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_phonenumber];
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            case kVcSubSmsCode:
//            {
//                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//                cell.backgroundColor = [UIColor clearColor];
//                cell.accessoryType = UITableViewCellAccessoryNone;
//                cell.selectionStyle = UITableViewCellSelectionStyleNone;
//                [_mainTableView attachTextfieldToCell:cell tf:_tf_smscode];//TODO:
//                cell.hideTopLine = YES;
//                cell.hideBottomLine = YES;
//                return cell;
//            }
//                break;
//            default:
//                assert(false);
//                break;
//        }
//    }else if (indexPath.section == kVcCellTips){
//        return _cell_tips;
//    } else {
//        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
//        cell.accessoryType = UITableViewCellAccessoryNone;
//        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
//        cell.hideBottomLine = YES;
//        cell.hideTopLine = YES;
//        cell.backgroundColor = [UIColor clearColor];
//        [self addLabelButtonToCell:_goto_submit cell:cell leftEdge:tableView.layoutMargins.left];
//        return cell;
//    }
//
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    if (indexPath.section == kVcSubmit){
//        //  表单行为按钮点击
//        [self resignAllFirstResponder];
//        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//            [self delay:^{
//                [self gotoSubmitCore];
//            }];
//        }];
//    }
}

@end
