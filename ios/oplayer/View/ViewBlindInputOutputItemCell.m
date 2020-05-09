//
//  ViewBlindInputOutputItemCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBlindInputOutputItemCell.h"
#import "ChainObjectManager.h"
#import "ThemeManager.h"
#import "NativeAppDelegate.h"
#import "OrgUtils.h"
#import "Extension.h"

@interface ViewBlindInputOutputItemCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAuthority;           //  隐私输出地址
    UILabel*        _lbAmount;              //  隐私输出数量
    UIButton*       _btnRemove;             //  移除按钮
}

@end

@implementation ViewBlindInputOutputItemCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAmount = nil;
    _lbAuthority = nil;
    _btnRemove = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier vc:(UIViewController*)vc action:(SEL)action
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbAuthority = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAuthority.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAuthority.textAlignment = NSTextAlignmentLeft;
        _lbAuthority.numberOfLines = 1;
        _lbAuthority.backgroundColor = [UIColor clearColor];
        _lbAuthority.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbAuthority];
        
        _lbAmount = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmount.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmount.textAlignment = NSTextAlignmentLeft;
        _lbAmount.numberOfLines = 1;
        _lbAmount.backgroundColor = [UIColor clearColor];
        _lbAmount.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbAmount];
        
        _btnRemove = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnRemove.titleLabel.font = [UIFont systemFontOfSize:14];
        [_btnRemove setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        [_btnRemove addTarget:vc action:action forControlEvents:UIControlEventTouchUpInside];
        _btnRemove.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_btnRemove setTitle:@" " forState:UIControlStateNormal];
        [self addSubview:_btnRemove];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnRemove){
        _btnRemove.tag = tag;
    }
}

-(void)setItem:(NSDictionary*)item
{
    if (_item != item)
    {
        _item = item;
        [self setNeedsDisplay];
        //  REMARK fix ios7 detailTextLabel not show
        if ([NativeAppDelegate systemVersion] < 9)
        {
            [self layoutSubviews];
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28.0f;
    
    if ([[_item objectForKey:@"title"] boolValue]) {
        switch (_itemType) {
            case kBlindItemTypeInput:
                _lbAuthority.text = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellTitleBlindReceiptWithN", @"隐私收据(%@)"),
                                     _item[@"num"]];
                break;
            case kBlindItemTypeOutput:
                _lbAuthority.text = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellTitleBlindAccountWithN", @"隐私账户(%@)"),
                                     _item[@"num"]];
                break;
            default:
                assert(false);
                break;
        }
        _lbAmount.text = NSLocalizedString(@"kVcStCellTitleOutputAmount", @"数量");
        _lbAuthority.textColor = theme.textColorGray;
        _lbAmount.textColor = theme.textColorGray;
        
        [_btnRemove setTitle:NSLocalizedString(@"kVcStCellTitleOperation", @"操作") forState:UIControlStateNormal];
        [_btnRemove setTitleColor:theme.textColorGray forState:UIControlStateNormal];
        _btnRemove.userInteractionEnabled = NO;
    } else {
        
        switch (_itemType) {
            case kBlindItemTypeInput:
            {
                //  获取显示数据
                id decrypted_memo = [_item objectForKey:@"decrypted_memo"];
                assert(decrypted_memo);
                id amount = [decrypted_memo objectForKey:@"amount"];
                uint32_t check = [[decrypted_memo objectForKey:@"check"] unsignedIntValue];
                
                _lbAuthority.text = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellValueReceiptValue", @"收据 #%@"),
                                     [[[NSData dataWithBytes:&check length:sizeof(check)] hex_encode] uppercaseString]];
                _lbAuthority.lineBreakMode = NSLineBreakByTruncatingTail;
                id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
                assert(asset);
                id n_amount = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                                exponent:-[[asset objectForKey:@"precision"] integerValue]
                                                              isNegative:NO];
                
                _lbAmount.text = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
            }
                break;
            case kBlindItemTypeOutput:
            {
                _lbAuthority.text = [_item objectForKey:@"public_key"];
                _lbAuthority.lineBreakMode = NSLineBreakByTruncatingMiddle;
                _lbAmount.text = [OrgUtils formatFloatValue:[_item objectForKey:@"n_amount"] usesGroupingSeparator:NO];
            }
                break;
            default:
                assert(false);
                break;
        }
        
        if ([[_item objectForKey:@"bAutoChange"] boolValue]) {
            [_btnRemove setTitle:NSLocalizedString(@"kVcStCellOperationKindAutoChange", @"自动找零") forState:UIControlStateNormal];
            [_btnRemove setTitleColor:theme.textColorGray forState:UIControlStateNormal];
            _btnRemove.userInteractionEnabled = NO;
            
            _lbAuthority.textColor = theme.textColorGray;
            _lbAmount.textColor = theme.textColorGray;
        } else {
            [_btnRemove setTitle:NSLocalizedString(@"kVcStCellOperationKindRemove", @"移除") forState:UIControlStateNormal];
            [_btnRemove setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
            _btnRemove.userInteractionEnabled = YES;
            
            _lbAuthority.textColor = theme.textColorMain;
            _lbAmount.textColor = theme.textColorMain;
        }
    }
    
    _lbAuthority.frame = CGRectMake(xOffset, yOffset, fWidth * 0.6, fCellHeight);
    _lbAmount.frame = CGRectMake(xOffset + fWidth * 0.6 + 12, yOffset, fWidth, fCellHeight);
    CGFloat fButtonWidth = 72.0f;
    _btnRemove.frame = CGRectMake(self.bounds.size.width - xOffset - fButtonWidth,
                                  (fCellHeight - fLineHeight) / 2.0f, fButtonWidth, fLineHeight);
}

@end
