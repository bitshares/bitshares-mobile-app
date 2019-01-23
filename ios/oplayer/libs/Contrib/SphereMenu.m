//
//  SphereMenu.m
//  SphereMenu
//
//  Created by Tu You on 14-8-24.
//  Copyright (c) 2014年 TU YOU. All rights reserved.
//

// 版权属于原作者
// http://code4app.com (cn) http://code4app.net (en)
// 发布代码于最专业的源码分享网站: Code4App.com

#import "SphereMenu.h"

//  位置修正时候动画时间
static const CGFloat correctPosAnimationDuration = 0.2f;
//  位置修正时四周最小边框值
static const CGFloat correctPosBorderWidth = 30.0f;

static const CGFloat kAngleOffset = M_PI_2 / 2;
static const CGFloat kSphereLength = 60;
static const float kSphereDamping = 0.3;

@interface SphereMenu () <UICollisionBehaviorDelegate>

@property (assign, nonatomic) NSInteger startAnimationIndex;
@property (strong, nonatomic) NSTimer* startAnimationTimer;
@property (strong, nonatomic) NSMutableArray* startImageList;
@property (assign, nonatomic) NSUInteger count ;
@property (strong, nonatomic) UIImageView *start;
@property (strong, nonatomic) NSArray *images;
@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) NSMutableArray *positions;

// animator and behaviors
@property (strong, nonatomic) UIDynamicAnimator *animator;
@property (strong, nonatomic) UICollisionBehavior *collision;
@property (strong, nonatomic) UIDynamicItemBehavior *itemBehavior;
@property (strong, nonatomic) NSMutableArray *snaps;
@property (strong, nonatomic) NSMutableArray *taps;

@property (strong, nonatomic) UITapGestureRecognizer *tapOnStart;
@property (strong, nonatomic) UIPanGestureRecognizer *panOnStart;

@property (strong, nonatomic) id<UIDynamicItem> bumper;
@property (assign, nonatomic) BOOL expanded;

@property (assign, nonatomic) BOOL startPanning;

@end


@implementation SphereMenu

- (void)dealloc
{
    [self stopAnimation];
    self.startImageList = nil;
}

- (instancetype)initWithStartPoint:(CGPoint)startPoint
                  startImagePrefix:(NSString *)startImagePrefix
                  startImageNumber:(NSInteger)startImageNumber
                     submenuImages:(NSArray *)images
{
    if (self = [super init]) {
        self.startAnimationIndex = 0;
        self.startAnimationTimer = nil;
        
        self.startImageList = [NSMutableArray array];
        for (NSInteger i = 1; i <= startImageNumber; ++i) {
            [self.startImageList addObject:[UIImage imageNamed:[NSString stringWithFormat:@"%@_%@", startImagePrefix, @(i)]]];
        }
        
        UIImage* startImage = [self.startImageList firstObject];
        
        self.bounds = CGRectMake(0, 0, startImage.size.width, startImage.size.height);
        self.center = startPoint;
        
        self.images = images;
        self.count = self.images.count;
        self.start = [[UIImageView alloc] initWithImage:[self.startImageList firstObject]];
        self.start.userInteractionEnabled = YES;
        self.tapOnStart = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(startTapped:)];
        self.panOnStart = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(startPanned:)];
        [self.start addGestureRecognizer:self.panOnStart];
        [self.start addGestureRecognizer:self.tapOnStart];
        [self addSubview:self.start];
    }
    return self;
}

#pragma mark- for start animation
- (void)refreshStartFrameImage
{
    self.start.image = [self.startImageList objectAtIndex:self.startAnimationIndex % [self.startImageList count]];
}

- (void)onAniTimerHandler
{
    self.startAnimationIndex += 1;
    [self refreshStartFrameImage];
}

- (BOOL)isStartAnimationShowing
{
    return self.startAnimationTimer != nil;
}

- (void)startAnimation
{
    if ([self isStartAnimationShowing]){
        return;
    }
    
    self.startAnimationIndex = 0;
    [self refreshStartFrameImage];
    self.startAnimationIndex = -1;
    //  REMARK：动画速度
    self.startAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:0.12f target:self selector:@selector(onAniTimerHandler) userInfo:nil repeats:YES];
    [self.startAnimationTimer fire];
}

- (void)stopAnimation
{
    if (self.startAnimationTimer)
    {
        [self.startAnimationTimer invalidate];
        self.startAnimationTimer = nil;
        self.startAnimationIndex = 0;
        [self refreshStartFrameImage];
    }
}

- (void)bringToTop
{
    for (UIImageView* item in self.items) {
        [self.superview bringSubviewToFront:item];
    }
    [self.superview bringSubviewToFront:self];
}

- (void)setVisible:(BOOL)visible
{
    self.hidden = !visible;
    for (UIImageView* item in self.items) {
        item.hidden = !visible;
    }
}

- (void)commonSetup
{
    self.items = [NSMutableArray array];
    self.positions = [NSMutableArray array];
    self.snaps = [NSMutableArray array];

    // setup the items
    for (int i = 0; i < self.count; i++) {
        UIImageView *item = [[UIImageView alloc] initWithImage:self.images[i]];
        item.userInteractionEnabled = YES;
        [self.superview addSubview:item];
        
        CGPoint position = [self centerForSphereAtIndex:i];
        item.center = self.center;
        [self.positions addObject:[NSValue valueWithCGPoint:position]];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        [item addGestureRecognizer:tap];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
        [item addGestureRecognizer:pan];
        
        [self.items addObject:item];
    }
    
//    [self.superview bringSubviewToFront:self];
    [self bringToTop];
    
    // setup animator and behavior
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.superview];
    
    self.collision = [[UICollisionBehavior alloc] initWithItems:self.items];
    self.collision.translatesReferenceBoundsIntoBoundary = YES;
    self.collision.collisionDelegate = self;
    
    for (int i = 0; i < self.count; i++) {
        UISnapBehavior *snap = [[UISnapBehavior alloc] initWithItem:self.items[i] snapToPoint:self.center];
        snap.damping = kSphereDamping;
        [self.snaps addObject:snap];
    }
    
    self.itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:self.items];
    self.itemBehavior.allowsRotation = NO;
    self.itemBehavior.elasticity = 1.2;
    self.itemBehavior.density = 0.5;
    self.itemBehavior.angularResistance = 5;
    self.itemBehavior.resistance = 10;
    self.itemBehavior.elasticity = 0.8;
    self.itemBehavior.friction = 0.5;
}

- (void)didMoveToSuperview
{
    [self commonSetup];
}

- (void)removeFromSuperview
{
    for (int i = 0; i < self.count; i++) {
        [self.items[i] removeFromSuperview];
    }
    
    [super removeFromSuperview];
}

/**
 *  计算按钮弹出方向
 */
- (CGFloat)calcPopDirection
{
    NSInteger screen_width = [[UIScreen mainScreen] bounds].size.width;
    NSInteger screen_height = [[UIScreen mainScreen] bounds].size.height;
    
    if (self.center.x <= screen_width / 2)
    {
        if (self.center.y <= screen_height / 2)
        {
            //  右下
            return M_PI / 4.0f;
        }
        else
        {
            //  右上
            return 7 * M_PI / 4.0f;
        }
    }
    else
    {
        if (self.center.y <= screen_height / 2)
        {
            //  左下
            return 3 * M_PI / 4.0f;
        }
        else
        {
            //  左上
            return 5 * M_PI / 4.0f;
        }
    }
}

- (CGPoint)centerForSphereAtIndex:(int)index
{
    //  REMARK：0度是右边水平方向，顺时针增加。
//    CGFloat firstAngle = M_PI + (M_PI_2 - kAngleOffset) + index * kAngleOffset;
    CGFloat firstAngle = [self calcPopDirection] + index * kAngleOffset;;
    CGPoint startPoint = self.center;
    CGFloat x = startPoint.x + cos(firstAngle) * kSphereLength;
    CGFloat y = startPoint.y + sin(firstAngle) * kSphereLength;
    CGPoint position = CGPointMake(x, y);
    return position;
}

- (void)tapped:(UITapGestureRecognizer *)gesture
{
    NSLog(@"icon tapped: %d", (int)self.startPanning);
    
    //  拖拽中不处理点击
    if (self.startPanning){
        return;
    }
    
    NSUInteger index = [self.taps indexOfObject:gesture];
    if ([self.delegate respondsToSelector:@selector(sphereDidSelected:)]) {
        [self.delegate sphereDidSelected:(int)index];
    }
    
    //  关闭
    [self shrinkSubmenu];
    self.expanded = NO;
    NSLog(@"self.expanded: %d", (int)self.expanded);
}

- (void)startTapped:(UITapGestureRecognizer *)gesture
{
    NSLog(@"start tapped: %d", (int)self.startPanning);
    
    //  拖拽中不处理点击
    if (self.startPanning){
        return;
    }
    
    [self.animator removeBehavior:self.collision];
    [self.animator removeBehavior:self.itemBehavior];
    [self removeSnapBehaviors];
    
    if (self.expanded) {
        [self shrinkSubmenu];
    } else {
        [self expandSubmenu];
    }
    
    self.expanded = !self.expanded;
    NSLog(@"self.expanded: %d", (int)self.expanded);
}

/**
 *  中心图标拖拽结束后重置按钮位置等
 */
- (void)onStartPannedFinishCore:(CGPoint)location
{
    for (int i = 0; i < self.count; i++) {
        [self.items[i] setHidden:NO];
        [self.items[i] setCenter:location];
    }
    
    //  中心图标拖拽之后重置行为icon弹出的位置
    [self.positions removeAllObjects];
    for (int i = 0; i < self.count; i++) {
        CGPoint position = [self centerForSphereAtIndex:i];
        [self.positions addObject:[NSValue valueWithCGPoint:position]];
    }
    
    //  拖拽结束标记
    self.startPanning = NO;
}

/**
 *  中心图标拖拽结束事件
 */
- (void)onStartPannedFinish:(UIPanGestureRecognizer*)gesture
{
    NSLog(@"main icon panned finished...");
    
    //  拖拽结束
    CGPoint location = [gesture locationInView:self.superview];
    self.center = location;
    
    //  修正判定
    BOOL bCorrectPos = NO;
    CGPoint correct_pos = location;
    CGSize screen_size = [UIScreen mainScreen].bounds.size;
    if (location.x < correctPosBorderWidth){
        bCorrectPos = YES;
        correct_pos.x = correctPosBorderWidth;
    }else if (location.x > screen_size.width - correctPosBorderWidth){
        bCorrectPos = YES;
        correct_pos.x = screen_size.width - correctPosBorderWidth;
    }
    if (location.y < correctPosBorderWidth){
        bCorrectPos = YES;
        correct_pos.y = correctPosBorderWidth;
    }else if (location.y > screen_size.height - correctPosBorderWidth){
        bCorrectPos = YES;
        correct_pos.y = screen_size.height - correctPosBorderWidth;
    }
    
    //  是否进行位置休整
    if (bCorrectPos)
    {
        [UIView animateWithDuration:correctPosAnimationDuration animations:^{
            self.center = correct_pos;
        } completion:^(BOOL finished) {
            [self onStartPannedFinishCore:correct_pos];
        }];
    }
    else
    {
        [self onStartPannedFinishCore:location];
    }
}

- (void)startPanned:(UIPanGestureRecognizer*)gesture
{
    //  展开后禁止拖拽
    if (self.expanded){
        return;
    }
    //  处理拖拽
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.startPanning = YES;
        NSLog(@"main icon panned start...");
        //  清除之前的动画
        [self.animator removeBehavior:self.collision];
        [self.animator removeBehavior:self.itemBehavior];
        [self removeSnapBehaviors];
        
        //  开始拖拽隐藏小图标
        for (int i = 0; i < self.count; i++) {
            [self.items[i] setHidden:YES];
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint location = [gesture locationInView:self.superview];
        self.center = location;
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        [self onStartPannedFinish:gesture];
    }
}

- (void)expandSubmenu
{
    for (int i = 0; i < self.count; i++) {
        [self snapToPostionsWithIndex:i];
    }
}

- (void)shrinkSubmenu
{
    for (int i = 0; i < self.count; i++) {
        [self snapToStartWithIndex:i];
    }
}

- (void)panned:(UIPanGestureRecognizer *)gesture
{
    NSLog(@"icon panned: %d", (int)self.startPanning);
    
    //  拖拽中不处理icon的拖拽
    if (self.startPanning){
        return;
    }
    
    UIView *touchedView = gesture.view;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.animator removeBehavior:self.itemBehavior];
        [self.animator removeBehavior:self.collision];
        [self removeSnapBehaviors];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        touchedView.center = [gesture locationInView:self.superview];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.bumper = touchedView;
        [self.animator addBehavior:self.collision];
        NSUInteger index = [self.items indexOfObject:touchedView];
        
        if (index != NSNotFound) {
            [self snapToPostionsWithIndex:index];
        }
    }
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior endedContactForItem:(id<UIDynamicItem>)item1 withItem:(id<UIDynamicItem>)item2
{
    [self.animator addBehavior:self.itemBehavior];
    
    if (item1 != self.bumper) {
        NSUInteger index = (int)[self.items indexOfObject:item1];
        if (index != NSNotFound) {
            [self snapToPostionsWithIndex:index];
        }
    }
    
    if (item2 != self.bumper) {
        NSUInteger index = (int)[self.items indexOfObject:item2];
        if (index != NSNotFound) {
            [self snapToPostionsWithIndex:index];
        }
    }
}

- (void)snapToStartWithIndex:(NSUInteger)index
{
    UISnapBehavior *snap = [[UISnapBehavior alloc] initWithItem:self.items[index] snapToPoint:self.center];
    snap.damping = kSphereDamping;
    UISnapBehavior *snapToRemove = self.snaps[index];
    self.snaps[index] = snap;
    [self.animator removeBehavior:snapToRemove];
    [self.animator addBehavior:snap];
}

- (void)snapToPostionsWithIndex:(NSUInteger)index
{
    id positionValue = self.positions[index];
    CGPoint position = [positionValue CGPointValue];
    UISnapBehavior *snap = [[UISnapBehavior alloc] initWithItem:self.items[index] snapToPoint:position];
    snap.damping = kSphereDamping;
    UISnapBehavior *snapToRemove = self.snaps[index];
    self.snaps[index] = snap;
    [self.animator removeBehavior:snapToRemove];
    [self.animator addBehavior:snap];
}

- (void)removeSnapBehaviors
{
    [self.snaps enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.animator removeBehavior:obj];
    }];
}

@end
