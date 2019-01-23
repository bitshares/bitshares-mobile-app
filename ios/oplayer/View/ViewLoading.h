//
//  ViewLoading.h
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import <UIKit/UIKit.h>

@interface ViewLoading : UIView

- (id)initWithText:(NSString*)pText;

@property (nonatomic, readonly) UIActivityIndicatorView*    activityView;
@property (nonatomic, readonly) UILabel*                    textLabel;

@end
