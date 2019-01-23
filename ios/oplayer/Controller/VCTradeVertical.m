//
//  VCTradeVertical.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTradeVertical.h"

@implementation VCTradeVerticalSubPage
@end

@interface VCTradeVertical ()
{
}
@end

@implementation VCTradeVertical

- (NSArray*)getTitleStringArray
{
    //  TODO:
//    return @[@"帐号模式", @"助记词", @"私钥", @"钱包模式"];
    return @[@"买入", @"卖出"];
}

- (NSArray*)getSubPageVCArray
{
    return @[[[VCTradeVerticalBuyOrSell alloc] initWithBuyMode:YES], [[VCTradeVerticalBuyOrSell alloc] initWithBuyMode:NO]];
}

@end

@interface VCTradeVerticalBuyOrSell ()
{
    BOOL    _isBuy;
}

@end

@implementation VCTradeVerticalBuyOrSell

- (id)initWithBuyMode:(BOOL)buy
{
    self = [super init];
    if (self) {
        _isBuy = buy;
    }
    return self;
}

-(void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if (_isBuy){
        self.view.backgroundColor = [UIColor redColor];
    }else{
        self.view.backgroundColor = [UIColor greenColor];
    }
}

@end
