//
//  DataShareViewController.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "EAGLView.h"
#import "ManagerService.h"
#import "ChatMsg.h"
#import "DataConferenceService.h"
#import "DataShareViewController.h"
#import "VideoShareViewController.h"
#import "DataConferenceInterface.h"
#import "ConfChatViewController.h"

#define MAXSCALE 4.0
#define MINSCALE 1.0

#define GO_TO_VIDEO_SHARE_BTN_H_DIS_TO_RIGHT 5
#define GO_TO_VIDEO_SHARE_BTN_HEIGHT 28
#define GO_TO_VIDEO_SHARE_BTN_WIDTH 28

#define CONFOPERATION_VIEW_REAL_HEIGHT_LANDSCAPE 66        //实际高度(底部操作按钮视图,横屏)
#define CONFREMIND_LABLE_WIDTH 203 //滑动提示框的宽
#define CONFREMIND_LABLE_HEIGHT 20 //滑动提示框的高
#define CONFREMIND_LABLE_DISTANECE 20 //提示框距离底部视图的距离
#define CONFRENIND_LABLE_TEXTFOUNT 11.0 //提示框字体大小
#define CONFREMIND_HANDLE_DISTANCE 40 //提示图片到两边的距离
#define CONFPAGECTRL_DISTANCE  58// 页码提示到顶部的距离

@interface DataShareZoomView : UIScrollView<UIScrollViewDelegate>
@property (nonatomic, strong)UIView *zoomView;
@property (nonatomic, strong)UIView *defaultView;
@end

@implementation DataShareZoomView
- (instancetype)initWithFrame:(CGRect)frame andZoomView:(UIView *)zoomView anDefaultView:(UIView *)defaultView
{
    if (self = [super initWithFrame:frame])
    {
        self.minimumZoomScale = MINSCALE;
        self.maximumZoomScale = MAXSCALE;
        self.bouncesZoom = YES;
        self.zoomView = zoomView;
        self.defaultView = defaultView;
        [self addSubview:defaultView];
        [self addSubview:zoomView];
        self.delegate = self;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
    }
    return self;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return _zoomView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    if (scrollView.zoomScale <= 1.0)
    {
        //辅流缩小小于最小缩放比例，辅流视图始终位于屏幕中央
        CGFloat centerX = self.bounds.size.width/2.0;
        CGFloat centerY = self.bounds.size.height/2.0;
        [self.zoomView setCenter:CGPointMake(centerX, centerY)];
    }
    self.defaultView.center = self.zoomView.center;
}


@end

@interface DataShareViewController ()<UIScrollViewDelegate, DataConferenceServiceDelegate>

@property (nonatomic,strong) UIScrollView *contentView;
@property (nonatomic,strong) UIImageView * shareImageView;
@property (nonatomic,strong) UIButton* videoShareBtn;
@property (nonatomic,strong) UIButton* chatBtn;
@property (nonatomic,strong) UIImageView *videoShareImageView;
@property (nonatomic,strong) EAGLView *bfcpVideoView;
@property (nonatomic,strong) EAGLView *dataBfcpVideoView;
@property (nonatomic,strong) DataShareZoomView *zoomViewImageShare;
@property (nonatomic,strong) DataShareZoomView *zoomViewBfcp;
@property (nonatomic,strong) DataShareZoomView *zoomViewDataBfcp;


@end

@implementation DataShareViewController

- (instancetype)initWithConfInfo:(ConfStatus *)confInfo
{
    self = [super initWithConfInfo:confInfo];
    if (self) {
        
    }
    return self;
}

- (void)dataConferenceEventCallback:(TUP_DATA_CONFERENCE_EVENT_TYPE)conferenceEvent result:(NSDictionary *)resultDictionary {
    NSDictionary *resultInfo = resultDictionary[TUP_DATACONF_CALLBACK_RESULT_KEY];
    switch (conferenceEvent)
    {
        case DATA_CONFERENCE_END:
        case DATA_CONFERENCE_LEAVE:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[ManagerService dataConfService].remoteCameraInfos removeAllObjects];
                [[ManagerService dataConfService].localCameraInfos removeAllObjects];
                [[ManagerService confService] restoreConfParamsInitialValue];
                [self goToConfListViewController];
            });
            break;
        }
        case DATACONF_RECEIVE_SHARE_DATA:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogInfo(@"UILOG: DATACONF_RECEIVE_SHARE_DATA");
                [self showShareView:resultInfo];
            });
            break;
        }
        case DATACONF_SHARE_STOP:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogInfo(@"UILOG: DATACONF_SHARE_STOP");
                [self removeShareView];
            });
            break;
        }
        case DATACONF_USER_LEAVE:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *leaveUserName = resultInfo[DATACONF_USER_LEAVE_KEY];
                DDLogInfo(@"user %@ leave",leaveUserName);
            });
            break;
        }
        case DATACONF_GET_HOST:
        {
            DDLogInfo(@"DATACONF_GET_HOST number: %@", self.selfNumber);
            break;
        }
        case DATACONF_GET_PERSENT:
        {
            DDLogInfo(@"DATACONF_GET_PERSENT number: %@", self.selfNumber);
            break;
        }
        case DATACONF_SET_HOST_RESULT:
        {
            DDLogInfo(@"DATACONF_SET_HOST_RESULT");
            BOOL result = [resultInfo[UCCONF_SET_HOST_RESULT_KEY] boolValue];
            if (!result) {
                [self showMessage:@"Fali to set host role!"];
            }
            break;
        }
        case DATACONF_SET_PERSENTER_RESULT:
        {
            DDLogInfo(@"DATACONF_SET_PERSENTER_RESULT");
            BOOL result = [resultInfo[UCCONF_SET_PERSENTER_RESULT_KEY] boolValue];
            if (!result) {
                [self showMessage:@"Fali to set persenter role!"];
            }
            break;
        }
        case DATACONF_HOST_CHANGE:
        {
            DDLogInfo(@"hoster change number: %d", [resultInfo[UCCONF_NEWHOST_KEY] intValue]);
            break;
        }
        case DATACONF_PERSENTER_CHANGE:
        {
            DDLogInfo(@"presenter change number: %d", [resultInfo[UCCONF_NEWPERSENTER_KEY] intValue]);
            break;
        }
        case DATACONF_BFCP_SHARE:
        {
            DDLogInfo(@"DATACONF_BFCP_SHARE");
            [self dealDataBfcpShow];
        }
        default:
            break;
    }
}
//CALL_E_EVT_DATA_FRAMESIZE_CHANGE
- (void)tupBfcpShowDeals
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isShowBfcp = [ManagerService callService].isShowTupBfcp;
        if (isShowBfcp) {
            if (weakSelf.zoomViewBfcp.superview) {
                [weakSelf.zoomViewBfcp removeFromSuperview];
            }
            [weakSelf.contentView addSubview:weakSelf.zoomViewBfcp];
            
            [self showMessage:@"Starting sharing…"];
        }else {
            weakSelf.zoomViewBfcp.zoomScale = 1.0f;
            [weakSelf presentToActiveView];
        }
    });
}

- (void)dealDataBfcpShow {
    __weak typeof(self) weakSelf = self;
        BOOL isShowBfcp = [ManagerService dataConfService].isDataBFCPShow;
        if (isShowBfcp) {
            if (weakSelf.zoomViewDataBfcp.superview) {
                [weakSelf.zoomViewDataBfcp removeFromSuperview];
            }
            [weakSelf.contentView addSubview:weakSelf.zoomViewDataBfcp];
            [[ManagerService dataConfService] playBfcpVideoView:weakSelf.dataBfcpVideoView];
            
            [weakSelf.contentView setContentSize:CGSizeMake([weakSelf selfViewWidth] * 2, 0.0)];
            [weakSelf.contentView setContentOffset:CGPointMake([self selfViewWidth], 0.0) animated:YES];
            
            [weakSelf showMessage:@"Starting sharing…"];
        }
        else {
            if (weakSelf.zoomViewDataBfcp) {
                weakSelf.zoomViewDataBfcp = nil;
            }
            [weakSelf.contentView setContentSize:CGSizeMake([weakSelf selfViewWidth], 0.0)];
            [[ManagerService dataConfService] stopBfcpVideoView];
            
        }
        weakSelf.dataBfcpVideoView.hidden = !isShowBfcp;
}

- (void)presentToActiveView
{
    BOOL hasVideo = NO;
    BOOL hasShareData = NO;
    
    if (hasShareData) {
        self.contentView.contentSize = CGSizeMake([self selfViewWidth], 0.0);
    }
    else{
        if (hasVideo) {
            [self gotoVideoShareViewControllerBtnClicked:nil];
        }else{
            [self.navigationController popViewControllerAnimated:NO];
        }
    }
}

-(void)showShareView:(NSDictionary *)shareDataDic {
    UIImage *shareImage = shareDataDic[DATACONF_SHARE_DATA_KEY];
    self.zoomViewImageShare.defaultView.hidden = YES;
    self.shareImageView.image = shareImage;
}

- (void)removeShareView {
    self.zoomViewImageShare.defaultView.hidden = NO;
    self.shareImageView.image = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [ManagerService dataConfService].delegate = self;
    
    if ([ManagerService dataConfService].isDataBFCPShow) {
        [self dealDataBfcpShow];
    }
    
    if (self.confStatus.media_type == CONF_MEDIATYPE_VIDEO) {
        if ([ManagerService callService].isShowTupBfcp) {
            [self tupBfcpShowDeals];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.contentView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.scrollEnabled = YES;
    _contentView.showsHorizontalScrollIndicator = NO;
    _contentView.showsVerticalScrollIndicator = NO;
    _contentView.userInteractionEnabled = YES;
    _contentView.multipleTouchEnabled = NO;
    _contentView.delegate = self;
    _contentView.backgroundColor = [UIColor whiteColor];
    
    _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _contentView.pagingEnabled = YES;
    [self.view addSubview:_contentView];
    
    [_contentView addSubview:self.zoomViewImageShare];
    
    UIView* contentView = self.contentView;
    UIView* bottomView = self.bottomView;
    id<UILayoutSupport> top    = self.topLayoutGuide;
    id<UILayoutSupport> bottom = self.bottomLayoutGuide;
    NSDictionary* views = NSDictionaryOfVariableBindings(contentView,bottomView, top, bottom);
    NSArray* contentViewVconstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[top]-0-[contentView]-0-[bottom]"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:views];
    
    NSArray* contentViewHconstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[contentView]|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:views];
    
    [self.view addConstraints:contentViewVconstraints];
    [self.view addConstraints:contentViewHconstraints];
    
    [self.view bringSubviewToFront:self.bottomView];
    [self.view bringSubviewToFront:self.barView];
    
    if ([self isNeedAddVideoBtn]) {
        [self.barView addSubview:self.videoShareBtn];
    }
    
    [self.barView addSubview:self.chatBtn];
    
    [self configBottomViewBtns];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tupBfcpShowDeals) name:@"TupBfcpDealMessage" object:nil];
}

- (BOOL)isNeedAddVideoBtn {
    
    EC_CONF_MEDIATYPE confType = self.confStatus.media_type;
    BOOL isVideoConf = (confType == CONF_MEDIATYPE_VIDEO_DATA);
    BOOL isVideoDataConf = (confType == CONF_MEDIATYPE_VIDEO_DATA);
    BOOL isUSMDataConf = [self isUsmDataConf];
    return isVideoConf || isVideoDataConf || isUSMDataConf;
}

- (void)configBottomViewBtns {
    CGFloat width = [self selfViewWidth];
    
    self.voiceBtn.frame = CGRectMake(width/2-110, 0, 100, 71);
    self.endBtn.frame = CGRectMake(width/2+10, 0, 100, 71);
    
    [self.bottomView addSubview:self.voiceBtn];
    [self.bottomView addSubview:self.endBtn];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIView *)configDefaultTipViewWithImageName:(NSString *)name andTitle:(NSString *)title {
    UIView * defaultTipView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight])];
    defaultTipView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    defaultTipView.backgroundColor = [UIColor clearColor];
    defaultTipView.translatesAutoresizingMaskIntoConstraints = NO;
    
    CGFloat margin = 10.0f;
    CGFloat tipSize = 20.0f;
    
    UIImageView *defaultImg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:name]];
    defaultImg.center = CGPointMake(defaultTipView.center.x, defaultTipView.center.y - margin) ;
    defaultImg.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [defaultTipView addSubview:defaultImg];
    
    UILabel *defaultTip = [[UILabel alloc] initWithFrame:CGRectMake(-(defaultTipView.frame.size.width - defaultImg.frame.size.width)/2,
                                                                    defaultImg.frame.size.height+margin,
                                                                    defaultTipView.frame.size.width,
                                                                    tipSize)];
    
    defaultTip.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    defaultTip.font = [UIFont systemFontOfSize:tipSize];
    defaultTip.textAlignment = NSTextAlignmentCenter;
    defaultTip.text = title;
    defaultTip.textColor = [UIColor lightGrayColor];
    defaultImg.clipsToBounds = NO;
    [defaultImg addSubview:defaultTip];
    
    return defaultTipView;
}

- (DataShareZoomView *)zoomViewDataBfcp {
    if (nil == _zoomViewDataBfcp) {
        _dataBfcpVideoView = [EAGLView getDataConfBFCPView];
        _dataBfcpVideoView.frame = CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight]);
        _zoomViewDataBfcp = [[DataShareZoomView alloc]initWithFrame:CGRectMake([self selfViewWidth], 0.0, [self selfViewWidth], [self selfViewHeight]) andZoomView:_dataBfcpVideoView anDefaultView:nil];
    }
    return _zoomViewDataBfcp;
}

- (DataShareZoomView *)zoomViewBfcp {
    if (nil == _zoomViewBfcp) {
        _bfcpVideoView = [EAGLView getTupBFCPView];
        _bfcpVideoView.frame = CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight]);
        _zoomViewBfcp = [[DataShareZoomView alloc]initWithFrame:CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight]) andZoomView:_bfcpVideoView anDefaultView:nil];
    }
    return _zoomViewBfcp;
}

- (DataShareZoomView *)zoomViewImageShare {
    if (nil == _zoomViewImageShare) {
        _shareImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight])];
        _shareImageView.contentMode = UIViewContentModeScaleAspectFit;
        _shareImageView.userInteractionEnabled = YES;
        _shareImageView.backgroundColor = [UIColor clearColor];
        
        UIView *defaultView = [self configDefaultTipViewWithImageName:@"shared_data_default" andTitle:@"Data sharing has not started."];
        _zoomViewImageShare = [[DataShareZoomView alloc]initWithFrame:CGRectMake(0.0, 0.0, [self selfViewWidth], [self selfViewHeight]) andZoomView:self.shareImageView anDefaultView:defaultView];
    }
    return _zoomViewImageShare;
}

- (UIButton *)videoShareBtn {
    if (nil == _videoShareBtn) {
        _videoShareImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"enter_videoshare"]
                                                 highlightedImage:[UIImage imageNamed:@"enter_videoshare_highlight"]];
        _videoShareImageView.animationImages = @[[UIImage imageNamed:@"enter_videoshare"],[UIImage imageNamed:@"enter_videoshare1"],
                                                 [UIImage imageNamed:@"enter_videoshare2"],[UIImage imageNamed:@"enter_videoshare3"]];
        _videoShareImageView.animationDuration = 2;
        
        
        CGFloat x = [self selfViewWidth] - GO_TO_VIDEO_SHARE_BTN_H_DIS_TO_RIGHT - GO_TO_VIDEO_SHARE_BTN_WIDTH;
        CGFloat tempBarHeight = self.barView.bounds.size.height == 0 ? 64 : self.barView.bounds.size.height;
        CGFloat y = (tempBarHeight-GO_TO_VIDEO_SHARE_BTN_HEIGHT)/2;
        _videoShareBtn = [[UIButton alloc]initWithFrame:CGRectMake(x,
                                                                   y,
                                                                   GO_TO_VIDEO_SHARE_BTN_WIDTH,
                                                                   GO_TO_VIDEO_SHARE_BTN_HEIGHT)];
        [_videoShareBtn addTarget:self
                           action:@selector(gotoVideoShareViewControllerBtnClicked:)
                 forControlEvents:UIControlEventTouchUpInside];
        [_videoShareBtn addSubview:_videoShareImageView];
    }
    return _videoShareBtn;
}

- (UIButton *)chatBtn {
    if (nil == _chatBtn) {
        _chatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat tempBarHeight = self.barView.bounds.size.height == 0 ? 64 : self.barView.bounds.size.height;
        CGFloat x = [self selfViewWidth] - GO_TO_VIDEO_SHARE_BTN_H_DIS_TO_RIGHT - GO_TO_VIDEO_SHARE_BTN_WIDTH - 54;
        CGFloat y = (tempBarHeight-44)/2;
        [_chatBtn setFrame:CGRectMake(x, y, 44, 44)];
        [_chatBtn addTarget:self action:@selector(showChatView) forControlEvents:UIControlEventTouchUpInside];
        [_chatBtn setImage:[UIImage imageNamed:@"calldetail_chatbutton"] forState:UIControlStateNormal];
    }
    return _chatBtn;
}

- (void)gotoVideoShareViewControllerBtnClicked:(id)sender
{
    NSMutableArray *ary = [NSMutableArray arrayWithArray:[self.navigationController viewControllers]];
    if ([ary containsObject:self]) {
        [ary removeObject:self];
    }
    VideoShareViewController *videoShareCtrl = [[VideoShareViewController alloc] initWithConfInfo:self.confStatus];
    [ary addObject:videoShareCtrl];
    
    [self.navigationController setViewControllers:ary animated:NO];
}

- (void)showChatView
{
    ConfChatViewController *chatCtrl = [[ConfChatViewController alloc] initWithNibName:@"ConfChatViewController" bundle:nil];
    chatCtrl.confAttendees = self.confStatus.participants;
    chatCtrl.selfInfo = self.selfConfInfo;
    [self.navigationController pushViewController:chatCtrl animated:YES];
}

- (void)dealloc {
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
