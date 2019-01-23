//
//  VerticalAlignmentLabel.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>

typedef enum
{
    VerticalAlignmentTop = 0,
    VerticalAlignmentMiddle,    //  default
    VerticalAlignmentBottom,
} VerticalAlignment;

@interface VerticalAlignmentLabel : UILabel
{
@private
    VerticalAlignment _verticalAlignment;
}

@property (nonatomic) VerticalAlignment verticalAlignment;

@end
