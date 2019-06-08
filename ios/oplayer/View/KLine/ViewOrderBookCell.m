//
//  ViewOrderBookCell.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewOrderBookCell.h"
#import "UITableViewBase.h"
#import "ViewBidAskCell.h"
#import "Extension.h"
#import "ChainObjectManager.h"

@interface ViewOrderBookCell()
{
    TradingPair*                _tradingPair;
    
    NSInteger                   _showOrderMaxNumber;    //  盘口 显示挂单行数
    CGFloat                     _showOrderLineHeight;   //  盘口 挂单行高
    CGFloat                     _cellTotalHeight;
    
    UITableViewBase*            _bidTableView;
    UITableViewBase*            _askTableView;
    
    NSMutableArray*             _bidDataArray;
    NSMutableArray*             _askDataArray;
}

@end

@implementation ViewOrderBookCell

@synthesize cellTotalHeight = _cellTotalHeight;

- (void)dealloc
{
}

- (id)initWithTradingPair:(TradingPair*)tradingPair
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        _tradingPair = tradingPair;
        
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.hideTopLine = YES;
        self.hideBottomLine = YES;
        
        self.backgroundColor = [UIColor clearColor];
        
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _bidDataArray = [NSMutableArray array];
        _askDataArray = [NSMutableArray array];
        
        id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
        _showOrderMaxNumber = [[parameters objectForKey:@"order_book_num_kline"] integerValue] + 1;
        _showOrderLineHeight = 32.0f;   //  TODO:fowallet constants
        _cellTotalHeight = _showOrderMaxNumber * _showOrderLineHeight;
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        
        //  买卖盘口
        CGRect bidRect = CGRectMake(0, 0, screenRect.size.width/2.0f, _cellTotalHeight);
        _bidTableView = [[UITableViewBase alloc] initWithFrame:bidRect style:UITableViewStylePlain];
        _bidTableView.userInteractionEnabled = NO;
        _bidTableView.delegate = self;
        _bidTableView.dataSource = self;
        _bidTableView.showsVerticalScrollIndicator = NO;
        _bidTableView.scrollEnabled = NO;
        _bidTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
        _bidTableView.backgroundColor = [UIColor clearColor];
        [self addSubview:_bidTableView];
        _bidTableView.hideAllLines = YES;
        
        CGRect askRect = CGRectMake(screenRect.size.width/2.0f, 0, screenRect.size.width/2.0f, _cellTotalHeight);
        _askTableView = [[UITableViewBase alloc] initWithFrame:askRect style:UITableViewStylePlain];
        _askTableView.userInteractionEnabled = NO;
        _askTableView.delegate = self;
        _askTableView.dataSource = self;
        _askTableView.showsVerticalScrollIndicator = NO;
        _askTableView.scrollEnabled = NO;
        _askTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
        _askTableView.backgroundColor = [UIColor clearColor];
        [self addSubview:_askTableView];
        _askTableView.hideAllLines = YES;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}

- (void)onQueryOrderBookResponsed:(id)order_book
{
    assert(order_book);
    
    [_bidDataArray removeAllObjects];
    [_bidDataArray addObjectsFromArray:[order_book objectForKey:@"bids"]];
    
    [_askDataArray removeAllObjects];
    [_askDataArray addObjectsFromArray:[order_book objectForKey:@"asks"]];
    
    [_bidTableView reloadData];
    [_askTableView reloadData];
}

#pragma mark- for UITableViewDelegate

- (NSMutableArray*)getDataArrayFromTableView:(UITableView*)tableView
{
    return tableView == _bidTableView ? _bidDataArray : _askDataArray;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _showOrderMaxNumber;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _showOrderLineHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL isbuy = tableView == _bidTableView;
    
    ViewBidAskCell* cell = nil;
    
    if (isbuy)
    {
        static NSString* bid_identify = @"id_bid_identify";
        
        cell = (ViewBidAskCell *)[tableView dequeueReusableCellWithIdentifier:bid_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:bid_identify isbuy:isbuy];
            //            cell.backgroundColor = [ThemeManager sharedThemeManager].contentBackColor;
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else
    {
        static NSString* ask_identify = @"id_ask_identify";
        
        cell = (ViewBidAskCell *)[tableView dequeueReusableCellWithIdentifier:ask_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ask_identify isbuy:isbuy];
            //            cell.backgroundColor = [ThemeManager sharedThemeManager].contentBackColor;
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    //  REMARK：这个最大值只取前5行的最大值，即使数据有20行甚至更多。
    double _bid_max_sum = 0;
    double _ask_max_sum = 0;
    NSInteger realShowNum = _showOrderMaxNumber - 1;
    if ([_bidDataArray count] >= realShowNum){
        _bid_max_sum = [[[_bidDataArray objectAtIndex:realShowNum - 1] objectForKey:@"sum"] doubleValue];
    }else if ([_bidDataArray count] > 0){
        _bid_max_sum = [[[_bidDataArray lastObject] objectForKey:@"sum"] doubleValue];
    }
    if ([_askDataArray count] >= realShowNum){
        _ask_max_sum = [[[_askDataArray objectAtIndex:realShowNum - 1] objectForKey:@"sum"] doubleValue];
    }else if ([_askDataArray count] > 0){
        _ask_max_sum = [[[_askDataArray lastObject] objectForKey:@"sum"] doubleValue];
    }
    cell.numPrecision = _tradingPair.numPrecision;
    cell.displayPrecision = _tradingPair.displayPrecision;
    [cell setRowID:indexPath.row maxSum:fmax(_bid_max_sum, _ask_max_sum)];
    if (indexPath.row != 0){
        NSDictionary* data = [[self getDataArrayFromTableView:tableView] safeObjectAtIndex:indexPath.row - 1];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [cell setItem:data];
    }else{
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

@end
