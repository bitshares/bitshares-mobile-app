//
//  SCLTextView.m
//  SCLAlertView
//
//  Created by Diogo Autilio on 9/18/15.
//  Copyright © 2015 AnyKey Entertainment. All rights reserved.
//

#import "SCLTextView.h"

#define MIN_HEIGHT 30.0f

@implementation SCLTextView

@synthesize iDecimalPrecision;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.iDecimalPrecision = -1;
    self.frame = CGRectMake(0.0f, 0.0f, 0.0f, MIN_HEIGHT);
    self.returnKeyType = UIReturnKeyDone;
    self.borderStyle = UITextBorderStyleRoundedRect;
    self.autocapitalizationType = UITextAutocapitalizationTypeWords;
    self.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = 1.0f;
}

- (BOOL)isValidAuthorityThreshold:(NSString*)new_string
{
    if (new_string && [new_string length] > 0){
        unichar single = [new_string characterAtIndex:0];
        return single >= '0' && single <= '9';
    }else{
        return YES;
    }
}

@end
