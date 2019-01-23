//
//  VCProposalConfirm.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCProposalConfirm.h"
#import "ViewProposalOpInfoCell.h"
#import "BitsharesClientManager.h"
#import "OrgUtils.h"
#import "WalletManager.h"

enum
{
    kVcFeePayingAccount = 0,    //  手续费支付账号（提案发起账号）
    kVcProposalDetails,         //  提案内容
    kVcBtnSubmit,               //  提交按钮
    
    kVcMax
};

@interface VCProposalConfirm ()
{
    BtsppConfirmCallback    _callback;
    BOOL                    _bResultCannelled;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    NSArray*                _dataArray;
    NSArray*                _permissionAccountArray;
    
    EBitsharesOperations    _opcode;
    NSDictionary*           _opdata;
    
    NSDictionary*           _processedOpData;
    
    NSDictionary*           _fee_paying_account;            //  手续费支付账号（提案发起账号）
}

@end

@implementation VCProposalConfirm

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _permissionAccountArray = nil;
    _dataArray = nil;
    _btnCommit = nil;
    _callback = nil;
    _fee_paying_account = nil;
    _processedOpData = nil;
}

- (id)initWithOpcode:(EBitsharesOperations)opcode opdata:(NSDictionary*)opdata callback:(BtsppConfirmCallback)callback
{
    self = [super init];
    if (self) {
        // Custom initialization
        _opcode = opcode;
        _opdata = opdata;
        _callback = callback;
        _bResultCannelled = YES;
        _fee_paying_account = nil;
        _processedOpData = nil;
        _permissionAccountArray = [[WalletManager sharedWalletManager] getFeePayingAccountList:YES];
        if ([_permissionAccountArray count] > 0){
            //  默认第一个
            _fee_paying_account = [_permissionAccountArray firstObject];
        }
    }
    return self;
}

- (void)onCancelButtonClicked:(id)sender
{
    _bResultCannelled = YES;
    [self closeModelViewController:nil];
}

- (void)onQueryGrapheneObjectResponsed:(id)resultHash
{
    _processedOpData = @{
                         @"opcode":@(_opcode),
                         @"opdata":_opdata,
                         @"uidata":[OrgUtils processOpdata2UiData:_opcode opdata:_opdata isproposal:YES]
                         };
    _mainTableView.hidden = NO;
    [_mainTableView reloadData];
}

- (void)queryMissedIds:(NSArray*)ids
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中…")];
    [[[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:ids] then:(^id(id resultHash) {
        [self hideBlockView];
        [self onQueryGrapheneObjectResponsed:resultHash];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils showMessage:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _dataArray = @[];
    
    //  导航条按钮
    [self showLeftButton:NSLocalizedString(@"kBtnCancel", @"取消") action:@selector(onCancelButtonClicked:)];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.hidden = YES;
    [self.view addSubview:_mainTableView];
    
    //  UI - 提交按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kProposalBtnSubmit", @"提交")];
    
    //  查询依赖
    NSMutableDictionary* queryIds = [NSMutableDictionary dictionary];
    [OrgUtils extractObjectID:_opcode opdata:_opdata container:queryIds];
    [self queryMissedIds:[queryIds allKeys]];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  解锁回调
    if (_callback){
        [self delay:^{
            _callback(!_bResultCannelled, _fee_paying_account);
        }];
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    if (!_fee_paying_account){
        [OrgUtils showMessage:NSLocalizedString(@"kProposalSubmitTipsSelectCreator", @"请选择提案创建者账号。")];
        return;
    }
    
    if (![[WalletManager sharedWalletManager] canAuthorizeThePermission:[_fee_paying_account objectForKey:@"active"]]){
        [OrgUtils showMessage:[NSString stringWithFormat:NSLocalizedString(@"kProposalEditTipsNoFeePayingAccountActiveKey", @"没有 %@ 账号的资金私钥，该账号不能用于支付手续费。"), _fee_paying_account[@"name"]]];
        return;
    }
    
    //  确认界面由于时间经过可能又被 lock 了。
    [self GuardWalletUnlocked:^(BOOL unlocked) {
        if (unlocked){
            _bResultCannelled = NO;
            [self closeModelViewController:nil];
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcProposalDetails && _processedOpData){
        return [ViewProposalOpInfoCell getCellHeight:_processedOpData leftOffset:tableView.layoutMargins.left];
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcProposalDetails:
        {
            static NSString* identify = @"id_opinfo_cell";
            ViewProposalOpInfoCell* cell = (ViewProposalOpInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewProposalOpInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.backgroundColor = [UIColor clearColor];
            }
            cell.showCustomBottomLine = YES;
            cell.useLabelFont = YES;
            if (_processedOpData){
                [cell setItem:_processedOpData];
            }
            return cell;
        }
            break;
        case kVcFeePayingAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = NSLocalizedString(@"kProposalLabelCellProposalCreator", @"提案发起者");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            if (_fee_paying_account){
                cell.detailTextLabel.text = [_fee_paying_account objectForKey:@"name"];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
            }else{
                cell.detailTextLabel.text = NSLocalizedString(@"kProposalTipsSelectFeePayingAccount", @"请选择提案发起账号");
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
            }
            return cell;
        }
            break;
        case kVcBtnSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
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
        switch (indexPath.section) {
            case kVcFeePayingAccount:
            {
                [VCCommonLogic showPicker:self
                             object_lists:_permissionAccountArray
                                      key:@"name"
                                    title:NSLocalizedString(@"kProposalTipsSelectFeePayingAccount", @"请选择提案发起账号")
                                 callback:^(id selectItem)
                {
                    _fee_paying_account = selectItem;
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcBtnSubmit:
                [self onCommitCore];
                break;
            default:
                break;
        }
    }];
}

@end
