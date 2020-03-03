//
//  VCSlideControllerBase.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCSlideControllerBase.h"

#import "MyScrollView.h"

#import "OrgUtils.h"
#import "MBProgressHUDSingleton.h"
#import "ThemeManager.h"

@interface VCSlideControllerBase ()
{
    NSMutableArray*             _slideButtonArrays;
    
    MyScrollView*               _mainScrollView;
    UITapGestureRecognizer*     _pSpaceTapGesture;
    UIView*                     _navView;
    UILabel*                    _sliderLabel;
    
    NSInteger                   _currentSelectedTag;
}

@end

@implementation VCSlideControllerBase

-(void)dealloc
{
    if (_pSpaceTapGesture) {
        _pSpaceTapGesture.delegate = nil;
        _pSpaceTapGesture = nil;
    }
    if (_mainScrollView){
        _mainScrollView.delegate = nil;
        _mainScrollView = nil;
    }
    _slideButtonArrays = nil;
    _subvcArrays = nil;
    _navView = nil;
    _sliderLabel = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark- foreground & background event notification

- (NSInteger)getTitleDefaultSelectedIndex
{
    //  REMARK：子类可覆盖
    return 1;
}

- (NSArray*)getTitleStringArray
{
    //  REMARK：子类实现
    return nil;
}

- (NSArray*)getSubPageVCArray
{
    //  REMARK：子类实现
    return nil;
}

- (void)initUI
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat kScreenWidth = screenRect.size.width;
    
    _slideButtonArrays = [NSMutableArray array];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    _navView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, 32)];
    _navView.backgroundColor = theme.navigationBarBackColor;
    
    //  REMARK：默认选中tag
    _currentSelectedTag = [self getTitleDefaultSelectedIndex];
    NSInteger tag = 1;
    
    id ary = [self getTitleStringArray];
    
    for (id name in ary) {
        CGFloat cellWidth = kScreenWidth/[ary count];
        UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(cellWidth*(tag-1), 0, cellWidth, _navView.frame.size.height);
        btn.selected = tag == _currentSelectedTag;
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        
        //  普通颜色 和 选中颜色
        [btn setTitleColor:theme.textColorMain forState:UIControlStateNormal];
//        [btn setTitleColor:theme.textColorHighlight forState:UIControlStateSelected];
        [btn addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.tag = tag;
        
        [_navView addSubview:btn];
        tag+=1;
        
        [_slideButtonArrays addObject:btn];
    }
    UIButton* selected = [self theSeletedBtn];
    assert(selected);
    _sliderLabel = [[UILabel alloc]initWithFrame:CGRectMake(selected.frame.origin.x, 32-2, kScreenWidth/[ary count], 4)];
    _sliderLabel.backgroundColor = theme.tintColor;
    [_navView addSubview:_sliderLabel];
    [self.view addSubview:_navView];
}

- (void)setMainScrollView
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    CGFloat kScreenWidth = screenRect.size.width;
    CGFloat kScreenHeight = screenRect.size.height;
    
    _mainScrollView = [[MyScrollView alloc]initWithFrame:CGRectMake(0, 32, kScreenWidth, kScreenHeight-[self heightForTabBar])];
    _mainScrollView.delegate = self;
    _mainScrollView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    _mainScrollView.pagingEnabled = YES;
    _mainScrollView.showsHorizontalScrollIndicator = NO;
    _mainScrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_mainScrollView];
    
    _subvcArrays = [self getSubPageVCArray];
    
    for (int i = 0; i < _subvcArrays.count; i++){
        //  添加背景，把三个VC的view贴到_mainScrollView上面
        UIView* pageView = [[UIView alloc]initWithFrame:CGRectMake(kScreenWidth * i, 0, _mainScrollView.frame.size.width, _mainScrollView.frame.size.height)];
        VCBase* vc = [_subvcArrays objectAtIndex:i];
        [pageView addSubview:vc.view];
        [_mainScrollView addSubview:pageView];
    }
    _mainScrollView.contentSize = CGSizeMake(kScreenWidth * (_subvcArrays.count), 0);
    //  默认偏移
    _mainScrollView.contentOffset = CGPointMake(kScreenWidth * (_currentSelectedTag - 1), 0);
    
    //  初始化默认值
    _enableTapSpaceEndInput = NO;
    _pSpaceTapGesture = nil;
}

- (void)setEnableTapSpaceEndInput:(BOOL)enableTapSpaceEndInput
{
    _enableTapSpaceEndInput = enableTapSpaceEndInput;
    if (_enableTapSpaceEndInput) {
        //  添加手势
        if (!_pSpaceTapGesture) {
            _pSpaceTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSpaceTap:)];
            _pSpaceTapGesture.delegate = self;
            [_mainScrollView addGestureRecognizer:_pSpaceTapGesture];
        }
    } else {
        //  移除手势
        if (_pSpaceTapGesture) {
            [_mainScrollView removeGestureRecognizer:_pSpaceTapGesture];
            _pSpaceTapGesture.delegate = nil;
            _pSpaceTapGesture = nil;
        }
    }
}

/*
 *  (private) 空白处点击
 */
- (void)onSpaceTap:(UITapGestureRecognizer*)tap
{
    [self endInput];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (_pSpaceTapGesture && gestureRecognizer &&
        touch.view &&
        [touch.view findSubview:[ViewBlockLabel class] resursion:YES]) {
        return NO;
    }
    return YES;
}

- (UIButton*)buttonWithTag:(NSInteger)tag
{
    return [_slideButtonArrays objectAtIndex:tag-1];
}

- (VCBase*)currentPage
{
    assert(_currentSelectedTag > 0 && _currentSelectedTag <= [_subvcArrays count]);
    return [_subvcArrays objectAtIndex:_currentSelectedTag - 1];
}

/**
 *  (private) 点击分页滑动控件顶部按钮事件
 */
- (void)sliderAction:(UIButton*)sender
{
    [self resignAllFirstResponder];
    
    [self sliderAnimationWithTag:sender.tag];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    CGFloat kScreenWidth = screenRect.size.width;
    
    [UIView animateWithDuration:0.3 animations:^{
        _mainScrollView.contentOffset = CGPointMake(kScreenWidth * (sender.tag - 1), 0);
    } completion:^(BOOL finished) {
        [self onAnimationDone];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self resignAllFirstResponder];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    CGFloat kScreenWidth = screenRect.size.width;
    
    double index_ = scrollView.contentOffset.x / kScreenWidth;
    [self sliderAnimationWithTag:(int)(index_+0.5)+1];
}

#pragma mark - sliderLabel滑动动画
- (void)sliderAnimationWithTag:(NSInteger)tag
{
    for (UIButton* btn in _slideButtonArrays) {
        btn.selected = NO;
    }
    UIButton* sender = [self buttonWithTag:tag];
    sender.selected = YES;
    
    //  动画
    [UIView animateWithDuration:0.3 animations:^{
        _sliderLabel.frame = CGRectMake(sender.frame.origin.x, _sliderLabel.frame.origin.y, _sliderLabel.frame.size.width, _sliderLabel.frame.size.height);
    } completion:^(BOOL finished) {
        //  TODO：动画完毕后是否改变 title label 字体大小
//        for (UIButton* btn in _slideButtonArrays) {
//            btn.titleLabel.font = [UIFont systemFontOfSize:16];
//        }

//        sender.titleLabel.font = [UIFont systemFontOfSize:18];
    }];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self onAnimationDone];
}

- (UIButton*)theSeletedBtn
{
    for (UIButton* btn in _slideButtonArrays) {
        if (btn.selected){
            return btn;
        }
    }
    return nil;
}

/**
 *  (private) 处理动画完成事件，不管是UIScrollView滑动结束，还是UIButton点击后的滑动事件。
 */
- (void)onAnimationDone
{
    UIButton* selected = [self theSeletedBtn];
    if (!selected){
        return;
    }
    NSLog(@"current: %@, now: %@", @(_currentSelectedTag), @(selected.tag));
    if (selected.tag != _currentSelectedTag){
        _currentSelectedTag = selected.tag;
        
        //  事件
        [self onPageChanged:_currentSelectedTag];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initUI];
    [self setMainScrollView];
}

/**
 *  (protected) 页面切换事件
 */
- (void)onPageChanged:(NSInteger)tag
{
    [self endInput];
    
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    if (_subvcArrays){
        id vc = [_subvcArrays safeObjectAtIndex:tag - 1];
        if (vc){
            if ([vc isKindOfClass:[VCBase class]]){
                VCBase* vc_base = (VCBase*)vc;
                [vc_base onControllerPageChanged];
            }
        }
    }
}

/*
 *  关闭键盘
 */
- (void)endInput
{
    [super endInput];
    if (_subvcArrays){
        for (VCBase* vc in _subvcArrays) {
            if (![vc isKindOfClass:[VCBase class]]) {
                continue;
            }
            [vc endInput];
        }
    }
}

- (void)resignAllFirstResponder
{
    //  REMARK：子类可覆盖
}

#pragma mark- switch theme
- (void)switchTheme
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    _navView.backgroundColor = theme.navigationBarBackColor;
    _sliderLabel.backgroundColor = theme.tintColor;
    _mainScrollView.backgroundColor = theme.appBackColor;
    if (_subvcArrays){
        for (VCBase* vc in _subvcArrays) {
            [vc switchTheme];
        }
    }
    if (_slideButtonArrays){
        for (UIButton* btn in _slideButtonArrays) {
            [btn setTitleColor:theme.textColorMain forState:UIControlStateNormal];
            // [btn setTitleColor:theme.textColorHighlight forState:UIControlStateSelected];
        }
    }
}

@end
