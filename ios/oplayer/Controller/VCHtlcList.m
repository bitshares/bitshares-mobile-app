//
//  VCHtlcList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCHtlcList.h"
#import "VCHtlcTransfer.h"
#import "BitsharesClientManager.h"
#import "ViewActionsCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

enum
{
    kMySideFrom = 0,                //  我是付款方
    kMySideTo,                      //  我是收款方
    kMySideOther                    //  我吃吃瓜群众（仅查看别人的合约信息）
};

enum
{
    kHtlcActionTypeRedeem = 0,      //  提取（兑换）
    kHtlcActionTypeCreate,          //  创建（部署）副本合约
    kHtlcActionTypeExtendExpiry     //  扩展有效期
};

enum
{
    kVcSubFromAndTo = 0,
    kVcSubAssetAmount,
    kVcSubPreimageLengthAndHashType,
    kVcSubPreimageHash,
    kVcSubActions,
    
    kVcSubMax
};

@interface VCHtlcList ()
{
    NSDictionary*           _fullAccountInfo;
    
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCHtlcList

-(void)dealloc
{
    _owner = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _fullAccountInfo = nil;
}

- (id)initWithOwner:(VCBase*)owner fullAccountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self){
        _owner = owner;
        _fullAccountInfo = accountInfo;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryUserHTLCsResponsed:(NSArray*)data_array
{
    //  更新数据
    [_dataArray removeAllObjects];
    
    if (data_array && [data_array isKindOfClass:[NSArray class]] && [data_array count] > 0){
        id my_id = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
        for (id htlc in data_array) {
            id transfer = [htlc objectForKey:@"transfer"];
            assert(transfer);
            NSInteger side = kMySideOther;
            if (my_id){
                if ([my_id isEqualToString:[transfer objectForKey:@"from"]]){
                    side = kMySideFrom;
                }else if ([my_id isEqualToString:[transfer objectForKey:@"to"]]){
                    side = kMySideTo;
                }
            }
            id m_htlc = [htlc mutableCopy];
            [m_htlc setObject:@(side) forKey:@"kSide"];
            [_dataArray addObject:[m_htlc copy]];
        }
    }
    
    //  根据ID降序排列
    if ([_dataArray count] > 0){
        [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger id1 = [[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            NSInteger id2 = [[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            return id2 - id1;
        })];
    }
    
    //  更新显示
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

/**
 *  (private) 查询账号关联的HTLC对象信息（包含FROM和TO）。
 */
- (WsPromise*)_queryUserHTLCObjectList
{
    id account = [_fullAccountInfo objectForKey:@"account"];
    id uid = [account objectForKey:@"id"];
    assert(uid);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    if ([_fullAccountInfo objectForKey:@"htlcs"]){
        //  3.0.1 之后版本添加了获取HTLC相关API，full accounts也包含了HTLC对象信息。直接查询账号信息即可。
        return [[chainMgr queryFullAccountInfo:uid] then:(^id(id full_data) {
            return [full_data objectForKey:@"htlcs"];
        })];
    }else{
        //  3.0.1 及其之前版本，获取HTLC的接口尚未完成。full accounts也未包含HTLC对象信息。这里直接从账号明细里获取。但存在缺陷。
        //  TODO：特别注意：如果API节点配置的账户历史明细太低，可能漏掉部分HTLC对象。又或者用户的账号交易记录太多，HTLC对象也可能被漏掉 。
        id stop = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
        id start = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
        GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
        
        return [[api_history exec:@"get_account_history_operations" params:@[uid, @(ebo_htlc_create), stop, start, @100]] then:(^id(id data_array) {
            NSMutableDictionary* htlc_id_hash = [NSMutableDictionary dictionary];
            if (data_array && [data_array isKindOfClass:[NSArray class]] && [data_array count] > 0){
                for (id op_history in data_array) {
                    id new_object_id = [OrgUtils extractNewObjectIDFromOperationResult:[op_history objectForKey:@"result"]];
                    if (new_object_id){
                        [htlc_id_hash setObject:@YES forKey:new_object_id];
                    }
                }
            }
            return [[chainMgr queryAllGrapheneObjectsSkipCache:[htlc_id_hash allKeys]] then:(^id(id data_hash) {
                return [data_hash allValues];
            })];
        })];
    }
}

- (void)queryUserHTLCs
{
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[self _queryUserHTLCObjectList] then:(^id(id htlcs) {
        NSMutableDictionary* query_ids = [NSMutableDictionary dictionary];
        //{
        //    conditions =         {
        //        "hash_lock" =             {
        //            "preimage_hash" =                 (
        //                                               2,
        //                                               9464eddceb9e42e757d935e035b2029da01aef237aa98c0f9adb92ee93de8ee0
        //                                               );
        //            "preimage_size" = 64;
        //        };
        //        "time_lock" =             {
        //            expiration = "2019-05-08T11:34:57";
        //        };
        //    };
        //    id = "1.16.62";
        //    transfer =         {
        //        amount = 100000;
        //        "asset_id" = "1.3.0";
        //        from = "1.2.23173";
        //        to = "1.2.23083";
        //    };
        //};
        if (htlcs && [htlcs isKindOfClass:[NSArray class]]){
            for (id htlc in htlcs) {
                id transfer = [htlc objectForKey:@"transfer"];
                assert(transfer);
                [query_ids setObject:@YES forKey:[transfer objectForKey:@"from"]];
                [query_ids setObject:@YES forKey:[transfer objectForKey:@"to"]];
                [query_ids setObject:@YES forKey:[transfer objectForKey:@"asset_id"]];
            }
        }
        //  查询 & 缓存
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        id p1 = [chainMgr queryAllGrapheneObjects:[query_ids allKeys]];
        id p2 = [chainMgr queryGlobalProperties];
        return [[WsPromise all:@[p1, p2]] then:(^id(id data) {
            [_owner hideBlockView];
            [self onQueryUserHTLCsResponsed:htlcs];
            return nil;
        })];
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcHtlcNoAnyObjects", @"没有任何HTLC合约信息")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([[[_dataArray objectAtIndex:section] objectForKey:@"kSide"] integerValue] == kMySideOther){
        return kVcSubMax - 1;
    }
    return kVcSubMax;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    id htlc = [_dataArray objectAtIndex:section];
    
    CGFloat fWidth = self.view.bounds.size.width;
    CGFloat xOffset = tableView.layoutMargins.left;
    
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = theme.appBackColor;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 28)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = theme.textColorMain;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.text = [NSString stringWithFormat:@"%@. #%@ ", @(section + 1), htlc[@"id"]];
    
    UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 28)];
    dateLabel.textColor = theme.textColorGray;
    dateLabel.textAlignment = NSTextAlignmentRight;
    dateLabel.backgroundColor = [UIColor clearColor];
    dateLabel.font = [UIFont systemFontOfSize:13];
    
    dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcOrderExpired", @"%@过期"),
                      [OrgUtils fmtLimitOrderTimeShowString:[[[htlc objectForKey:@"conditions"] objectForKey:@"time_lock"] objectForKey:@"expiration"]]];
    
    [myView addSubview:titleLabel];
    [myView addSubview:dateLabel];
    
    return myView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 28.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 16.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [UIColor clearColor];
    return myView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == kVcSubActions){
        return tableView.rowHeight;
    }
    return 32.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    
    id htlc = [_dataArray objectAtIndex:indexPath.section];
    
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    cell.textLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    switch (indexPath.row) {
        case kVcSubFromAndTo:
        {
            cell.textLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListCellFrom", @"付款账号 ")
                                                                                     value:[[chainMgr getChainObjectByID:[[htlc objectForKey:@"transfer"] objectForKey:@"from"]] objectForKey:@"name"]
                                                                                titleColor:theme.textColorNormal
                                                                                valueColor:theme.textColorMain];
            
            
            cell.detailTextLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListCellTo", @"收款账号 ")
                                                                                           value:[[chainMgr getChainObjectByID:[[htlc objectForKey:@"transfer"] objectForKey:@"to"]] objectForKey:@"name"]
                                                                                      titleColor:theme.textColorNormal
                                                                                      valueColor:theme.textColorMain];
        }
            break;
        case kVcSubAssetAmount:
        {
            BOOL isPay = [_fullAccountInfo[@"account"][@"id"] isEqualToString:[[htlc objectForKey:@"transfer"] objectForKey:@"from"]];
            if (isPay){
                cell.textLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListTransferDir", @"转账类型 ")
                                                                                         value:NSLocalizedString(@"kVcHtlcListTransferDirPayment", @"付款")
                                                                                    titleColor:theme.textColorNormal
                                                                                    valueColor:theme.sellColor];
            }else{
                cell.textLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListTransferDir", @"转账类型 ")
                                                                                         value:NSLocalizedString(@"kVcHtlcListTransferDirIncome", @"收款")
                                                                                    titleColor:theme.textColorNormal
                                                                                    valueColor:theme.buyColor];
            }
            cell.detailTextLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListTransferAmount", @"转账金额 ")
                                                                                           value:[OrgUtils formatAssetAmountItem:[htlc objectForKey:@"transfer"]]
                                                                                      titleColor:theme.textColorNormal
                                                                                      valueColor:theme.textColorMain];
        }
            break;
        case kVcSubPreimageLengthAndHashType:
        {
            id size = [[[htlc objectForKey:@"conditions"] objectForKey:@"hash_lock"] objectForKey:@"preimage_size"];
            
            cell.textLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListPreimageLength", @"原像长度 ")
                                                                                     value:[NSString stringWithFormat:@"%@", size]
                                                                                titleColor:theme.textColorNormal
                                                                                valueColor:theme.textColorMain];
            
            
            NSInteger hash_type = [[[[[htlc objectForKey:@"conditions"] objectForKey:@"hash_lock"] objectForKey:@"preimage_hash"] firstObject] integerValue];
            NSString* hash_type_str = [NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListHashTypeValueUnknown", @"未知类型 %@"), @(hash_type)];
            switch (hash_type) {
                case EBHHT_RMD160:
                    hash_type_str = @"RIPEMD160";
                    break;
                case EBHHT_SHA1:
                    hash_type_str = @"SHA1";
                    break;
                case EBHHT_SHA256:
                    hash_type_str = @"SHA256";
                    break;
                default:
                    break;
            }
            
            cell.detailTextLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListHashType", @"哈希类型 ")
                                                                                           value:hash_type_str
                                                                                      titleColor:theme.textColorNormal
                                                                                      valueColor:theme.textColorMain];
        }
            break;
        case kVcSubPreimageHash:
        {
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            
            NSString* have_value = [[[[htlc objectForKey:@"conditions"] objectForKey:@"hash_lock"] objectForKey:@"preimage_hash"] lastObject];
            cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            cell.textLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kVcHtlcListHashValue", @"原像哈希 ")
                                                                                     value:[have_value uppercaseString]
                                                                                titleColor:theme.textColorNormal
                                                                                valueColor:theme.textColorMain];
            cell.showCustomBottomLine = YES;
        }
            break;
        case kVcSubActions:
        {
            static NSString* identify = @"id_htlc_actions_cell";
            ViewActionsCell* cell = (ViewActionsCell *)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                id buttons;
                switch ([[htlc objectForKey:@"kSide"] integerValue]) {
                    case kMySideFrom:
                    {
                        buttons = @[
                                    @{@"name":NSLocalizedString(@"kVcHtlcListBtnExtend", @"延长有效期"), @"type":@(kHtlcActionTypeExtendExpiry)},
                                    ];
                    }
                        break;
                    case kMySideTo:
                    {
                        buttons = @[
                                    @{@"name":NSLocalizedString(@"kVcHtlcListBtnRedeem", @"提取"), @"type":@(kHtlcActionTypeRedeem)},
                                    @{@"name":NSLocalizedString(@"kVcHtlcListBtnCreate", @"部署"), @"type":@(kHtlcActionTypeCreate)},
                                    ];
                    }
                        break;
                    default:
                        assert(false);
                        break;
                }
                cell = [[ViewActionsCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify buttons:buttons];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.backgroundColor = [UIColor clearColor];
            }
            cell.showCustomBottomLine = YES;
            cell.user_tag = indexPath.section;
            cell.button_delegate = self;
            [cell setItem:htlc];
            return cell;
        }
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.row)
        {
            case kVcSubPreimageHash:
            {
                id htlc = [_dataArray objectAtIndex:indexPath.section];
                NSString* have_value = [[[[[htlc objectForKey:@"conditions"] objectForKey:@"hash_lock"] objectForKey:@"preimage_hash"] lastObject] uppercaseString];
                [UIPasteboard generalPasteboard].string = [have_value copy];
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListCopyPreimageHashOK", @"原像哈希：%@ 已复制。"), have_value]];
            }
                break;
            default:
                break;
        }
    }];
}

/**
 *  提取/扩展/部署等按钮点击。
 */
- (void)onButtonClicked:(ViewActionsCell*)cell infos:(id)infos
{
    id htlc = [_dataArray objectAtIndex:cell.user_tag];
    assert(htlc);
    switch ([[infos objectForKey:@"type"] integerValue]) {
        case kHtlcActionTypeCreate:
            [self _onHtlcActionCreateClicked:htlc];
            break;
        case kHtlcActionTypeRedeem:
            [self _onHtlcActionRedeemClicked:htlc];
            break;
        case kHtlcActionTypeExtendExpiry:
            [self _onHtlcActionExtendExpiryClicked:htlc];
            break;
        default:
            break;
    }
}

- (void)_gotoCreateHTLC:(id)htlc fullaccountdata:(id)fullaccountdata
{
    id to_id = [[htlc objectForKey:@"transfer"] objectForKey:@"from"];
    id to_name = [[[ChainObjectManager sharedChainObjectManager] getChainObjectByID:to_id] objectForKey:@"name"];
    assert(to_name);
    VCHtlcTransfer* vc = [[VCHtlcTransfer alloc] initWithUserFullInfo:fullaccountdata
                                                                 mode:EDM_HASHCODE
                                                         havePreimage:NO
                                                             ref_htlc:htlc
                                                               ref_to:@{@"id":to_id, @"name":to_name}];
    vc.title = NSLocalizedString(@"kVcTitleCreateSubHTLC", @"部署副合约");
    [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (void)_onHtlcActionCreateClicked:(id)htlc
{
    if ([[WalletManager sharedWalletManager] isMyselfAccount:_fullAccountInfo[@"account"][@"name"]]){
        [self _gotoCreateHTLC:htlc fullaccountdata:_fullAccountInfo];
    }else{
        [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
        id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
        [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
            [_owner hideBlockView];
            [self _gotoCreateHTLC:htlc fullaccountdata:[data objectAtIndex:0]];
            return nil;
        })] catch:(^id(id error) {
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }
}

- (void)_onHtlcActionRedeemClicked:(id)htlc preimage:(NSString*)preimage
{
    if ([self isStringEmpty:preimage])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kVcHtlcListTipsInputValidPreimage", @"请输入有效的原像信息。")];
        return;
    }

    //  构造请求
    id opaccount = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(opaccount);
    id account_id = [opaccount objectForKey:@"id"];
    assert(account_id);
    id htlc_id = [htlc objectForKey:@"id"];
    assert(htlc_id);
    
    id op = @{
              @"fee":@{
                      @"amount":@0,
                      @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID,
                      },
              @"htlc_id":htlc_id,
              @"redeemer":account_id,
              @"preimage":[preimage dataUsingEncoding:NSUTF8StringEncoding]
              };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_htlc_redeem
                       using_owner_authority:NO
                    invoke_proposal_callback:NO
                                      opdata:op
                                   opaccount:opaccount
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] htlcRedeem:op] then:(^id(id transaction_confirmation) {
             [_owner hideBlockView];
             [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListTipsRedeemOK", @"HTLC合约 %@ 提取成功。"), htlc_id]];
             //  [统计]
             [OrgUtils logEvents:@"txHtlcRedeemFullOK" params:@{@"redeemer":account_id, @"htlc_id":htlc_id}];
             //  刷新
             [self queryUserHTLCs];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txHtlcRedeemFailed" params:@{@"redeemer":account_id, @"htlc_id":htlc_id}];
             return nil;
         })];
     }];
}

- (void)_onHtlcActionRedeemClicked:(id)htlc
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcHtlcListAskTitleRedeem", @"提取合约")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kVcHtlcListAskPlaceholderRedeem", @"请输入合约原像")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                     completion:^(NSInteger buttonIndex, NSString *tfvalue) {
                                                         if (buttonIndex != 0){
                                                             [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                                                                 if (unlocked){
                                                                     [self _onHtlcActionRedeemClicked:htlc preimage:tfvalue];
                                                                 }
                                                             }];
                                                         }
                                                     }];
}

- (void)_onHtlcActionExtendExpiryClicked:(id)htlc seconds:(NSInteger)seconds
{
    assert(seconds > 0);
    
    //  构造请求
    id opaccount = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(opaccount);
    id account_id = [opaccount objectForKey:@"id"];
    assert(account_id);
    id htlc_id = [htlc objectForKey:@"id"];
    assert(htlc_id);
    
    id op = @{
              @"fee":@{
                      @"amount":@0,
                      @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID,
                      },
              @"htlc_id":htlc_id,
              @"update_issuer":account_id,
              @"seconds_to_add":@(seconds)
              };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_htlc_extend
                       using_owner_authority:NO
                    invoke_proposal_callback:NO
                                      opdata:op
                                   opaccount:opaccount
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] htlcExtend:op] then:(^id(id transaction_confirmation) {
             [_owner hideBlockView];
             [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListTipsExtendOK", @"HTLC合约 %@ 延长有效期成功。"), htlc_id]];
             //  [统计]
             [OrgUtils logEvents:@"txHtlcExtendFullOK" params:@{@"update_issuer":account_id, @"htlc_id":htlc_id}];
             //  刷新
             [self queryUserHTLCs];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txHtlcExtendFailed" params:@{@"update_issuer":account_id, @"htlc_id":htlc_id}];
             return nil;
         })];
     }];
}

- (void)_onHtlcActionExtendExpiryClicked:(id)htlc
{
    id gp = [[ChainObjectManager sharedChainObjectManager] getObjectGlobalProperties];
    assert(gp);
    id extensions = [[gp objectForKey:@"parameters"] objectForKey:@"extensions"];
    if (!extensions || ![extensions isKindOfClass:[NSDictionary class]]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcHtlcListTipsErrorMissParams", @"HTLC相关参数理事会尚未配置，请稍后再试。")];
        return;
    }
    id updatable_htlc_options = [extensions objectForKey:@"updatable_htlc_options"];
    if (!updatable_htlc_options){
        [OrgUtils makeToast:NSLocalizedString(@"kVcHtlcListTipsErrorMissParams", @"HTLC相关参数理事会尚未配置，请稍后再试。")];
        return;
    }
    NSInteger max_timeout_secs = [[updatable_htlc_options objectForKey:@"max_timeout_secs"] integerValue];
    NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval htlc_expiration = [OrgUtils parseBitsharesTimeString:[[[htlc objectForKey:@"conditions"] objectForKey:@"time_lock"] objectForKey:@"expiration"]];
    NSInteger max_add_seconds = max_timeout_secs - (htlc_expiration - now_ts);
    NSInteger max_add_days = max_add_seconds / 86400;
    if (max_add_days <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kVcHtlcListTipsErrorMaxExpire", @"已经达到最长有效期，不能再延长了。")];
        return;
    }
    
    NSMutableArray* list = [NSMutableArray array];
    for (NSInteger day = 1; day <= max_add_days; ++day) {
        [list addObject:@{@"name":[NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListExtendNDayFmt", @"%@天"), @(day)], @"value":@(day)}];
    }
    
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:_owner.navigationController
                                                           message:NSLocalizedString(@"kVcHtlcListTipsSelectExtendDays", @"请选择延长天数")
                                                             items:list
                                                           itemkey:@"name"
                                                      defaultIndex:0] then:(^id(id result) {
        if (result){
            NSInteger extend_day = [[result objectForKey:@"value"] integerValue];
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:[NSString stringWithFormat:NSLocalizedString(@"kVcHtlcListTipsExtendConfirm", @"延长 %@ 天合约的有效期，延长之后不可降低。是否继续？"), @(extend_day)]
                                                                   withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                  completion:^(NSInteger buttonIndex)
             {
                 if (buttonIndex == 1)
                 {
                     //  --- 参数大部分检测合法 执行请求 ---
                     [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                         if (unlocked){
                             [self _onHtlcActionExtendExpiryClicked:htlc seconds:extend_day * 3600 * 24];
                         }
                     }];
                 }
             }];
        }
        return nil;
    })];
}

@end
