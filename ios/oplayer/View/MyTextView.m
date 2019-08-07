//
//  MyTextView.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MyTextView.h"
#import "ThemeManager.h"

@interface MyTextView()
{
    NSString*   _placeholder;
    UIColor*    _placeholderColor;
}

@end

@implementation MyTextView

@synthesize placeholder=_placeholder;
@synthesize placeholderColor=_placeholderColor;

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.font = [UIFont systemFontOfSize:17];
        self.placeholderColor = [ThemeManager sharedThemeManager].textColorGray;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidChange:)
                                                     name:UITextViewTextDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (void)textDidChange:(NSNotification*)note
{
    [self setNeedsDisplay];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * 每次调用drawRect:方法，都会将以前画的东西清除掉
 */
- (void)drawRect:(CGRect)rect
{
    if (self.hasText)
        return;
    
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    attrs[NSFontAttributeName] = self.font;
    attrs[NSForegroundColorAttributeName] = self.placeholderColor;
    
    UIEdgeInsets textContainerInset = self.textContainerInset;
    CGFloat lineFragmentPadding = self.textContainer.lineFragmentPadding;
    CGFloat x = lineFragmentPadding + textContainerInset.left + self.layer.borderWidth;
    CGFloat y = textContainerInset.top + self.layer.borderWidth;
    rect.origin.x = x;
    rect.origin.y = y;
    rect.size.width -= 2 * rect.origin.x;
    [self.placeholder drawInRect:rect withAttributes:attrs];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self setNeedsDisplay];
}

#pragma mark - setter
- (void)setPlaceholder:(NSString*)placeholder
{
    _placeholder = [placeholder copy];
    [self setNeedsDisplay];
}

- (void)setPlaceholderColor:(UIColor*)placeholderColor
{
    _placeholderColor = placeholderColor;
    [self setNeedsDisplay];
}

- (void)setFont:(UIFont*)font
{
    [super setFont:font];
    [self setNeedsDisplay];
}

- (void)setText:(NSString*)text
{
    [super setText:text];
    [self setNeedsDisplay];
}

- (void)setAttributedText:(NSAttributedString*)attributedText
{
    [super setAttributedText:attributedText];
    [self setNeedsDisplay];
}

@end
