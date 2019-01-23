#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

typedef enum {
    DirectionPangestureRecognizerVertical,
    DirectionPanGestureRecognizerHorizontal
} DirectionPangestureRecognizerDirection;

@interface DirectionPanGestureRecognizer : UIPanGestureRecognizer {
    BOOL _drag;
    int _moveX;
    int _moveY;
    DirectionPangestureRecognizerDirection _direction;
}

@property (nonatomic, assign) DirectionPangestureRecognizerDirection direction;

@end