//
//  CallService.mm
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "CallService.h"
#import "CallInfo+StructParase.h"
#import "CallData.h"
#include <netdb.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#import "ManagerService.h"
#include <string.h>
#import "call_interface.h"
#import "call_advanced_interface.h"
#import "tup_ctd_def.h"
#import "tup_ctd_interface.h"
//#import "securec.h"
#import <UIKit/UIKit.h>
#import "Initializer.h"
#import "CallSessionModifyInfo.h"
#import "IPTConfig.h"
#import "LoginInfo.h"
#import "CommonUtils.h"
#import "CallLogMessage.h"

NSString *const NTF_AUDIOROUTE_CHANGED = @"NTF_AUDIOROUTE_CHANGED";

#define CHECKCSTR(str) (((str) == NULL) ? "" : (str))

#define CALLINFO_CALLNUMBER_KEY @"CALLINFO_CALLNUMBER_KEY"
#define CALLINFO_SIPNUMBER_KEY  @"CALLINFO_SIPNUMBER_KEY"

#define USER_AGENT_UC @"eSpace Mobile"

@interface CallService()<TupCallNotifacation>
{
    int _playHandle;
}

/**
 *Indicates local view
 *本地画面
 */
@property (nonatomic, strong)id localView;

/**
 *Indicates remote view
 *远端画面
 */
@property (nonatomic, strong)id remoteView;

/**
 *Indicates camera index, 1:front camera; 0:back camera
 *摄像头序号， 1为前置摄像头，0为后置摄像头
 */
@property (nonatomic,assign)CameraIndex cameraCaptureIndex;

/**
 *Indicates camera rotation, 0：90 1：180 2：270 3：360
 *摄像头方向，0：90 1：180 2：270 3：360
 */
@property (nonatomic,assign)NSInteger cameraRotation;

/**
 *Indicates video preview
 *视频预览
 */
@property (nonatomic, strong)id videoPreview;

/**
 *Indicates ctd call id
 *点击呼叫的呼叫id
 */
@property (nonatomic, assign)int ctdCallId;

/**
 *Indicates dictionary used to record callInfo,key:callID,value:callInfo
 *用于存储呼叫信息的词典
 */
@property (nonatomic,strong)NSMutableDictionary<NSString* , CallInfo*> *tupCallInfoDic;

/**
 *Indicates authorize token
 *鉴权token
 */
@property (nonatomic, copy)NSString *token;

@end

@implementation CallService

//creat getter and setter method of delegate
@synthesize delegate;

//creat getter and setter method of sipAccount
@synthesize sipAccount;

//creat getter and setter method of isShowTupBfcp
@synthesize isShowTupBfcp;

//creat getter and setter method of iptDelegate
@synthesize iptDelegate;

/**
 *This method is used to creat single instance of this class
 *创建该类的单例
 */
+(instancetype)shareInstance
{
    static CallService *_tupCallService = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tupCallService = [[CallService alloc] init];
    });
    return _tupCallService;
}

/**
 *This method is used to init this class
 *初始化该类
 */
-(instancetype)init
{
    if (self = [super init])
    {
        [Initializer registerCallCallBack:self];
        _cameraRotation = 0;
        _cameraCaptureIndex = CameraIndexFront;
        _tupCallInfoDic = [NSMutableDictionary dictionary];
        _playHandle = -1;
        self.isShowTupBfcp = NO;
    }
    return self;
}

/**
 * This method is used to get call info with confId
 * 用confid获取呼叫信息
 *@param confId              Indicates conference Id
 *                           会议id
 *@return call Info          Return call info
 *                           返回值为呼叫信息
 *@return YES or NO
 */
- (CallInfo *)callInfoWithConfId:(NSString *)confId
{
    NSArray *array = [_tupCallInfoDic allValues];
    for (CallInfo *info in array) {
        if ([info.serverConfId isEqualToString:confId]) {
            return info;
        }
    }
    return nil;
}

/**
 * This method is used to hang up all call.
 * 挂断所有呼叫
 */
- (void)hangupAllCall
{
    NSArray *array = [_tupCallInfoDic allValues];
    for (CallInfo *info in array) {
        [self closeCall:info.stateInfo.callId];
    }
}

/**
 * This method is used to config bussiness token
 * 配置业务token
 *@param sipAccount         Indicates sip account
 *                          sip账号
 *@param token              Indicates token
 *                          鉴权token
 */
- (void)configBussinessAccount:(NSString *)sipAccount
                         token:(NSString *)token
{
    if (token.length > 0 || token != nil) {
        self.token = token;
    }
    if (sipAccount.length > 0 || sipAccount != nil) {
        self.sipAccount = sipAccount;
    }
}

/**
 * This method is used to deel call event callback from service
 * 分发呼叫业务相关回调
 *@param module TUP_MODULE
 *@param notification Notification
 */
- (void)callModule:(TUP_MODULE)module notication:(Notification *)notification
{
    if (module == CALL_SIP_MODULE) {
        [self onRecvCallNotification:notification];
    }
    else {
        [self onRecvCTDNotification:notification];
    }
}

/**
 *This method is used to deel ctd notification
 *处理ctd回调业务
 *@param notify
 */
-(void)onRecvCTDNotification:(Notification *)notify
{
    switch (notify.msgId)
    {
        case CTD_E_EVT_START_CALL_RESULT:
        {
            DDLogInfo(@"CTD_E_EVT_START_CALL_RESULT callId: %d ,result: %d",notify.param1,notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         TUP_CTD_CALL_RESULT_KEY : [NSNumber numberWithBool:result]
                                         };
            [self respondsCTDDelegateWithType:CTD_CALL_RESULT result:resultInfo];
        }
            break;
        case CTD_E_EVT_END_CALL_RESULT:
        {
            DDLogInfo(@"CTD_E_EVT_END_CALL_RESULT callId: %d ,result: %d",notify.param1,notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         TUP_CTD_CALL_RESULT_KEY : [NSNumber numberWithBool:result]
                                         };
            [self respondsCTDDelegateWithType:CTD_CALL_END_RESULT result:resultInfo];
        }
            break;
        case CTD_E_EVT_CALL_STATUS_NOTIFY:
        {
            DDLogInfo(@"CTD_E_EVT_CALL_STATUS_NOTIFY callId: %d ,status: %d",notify.param1,notify.param2);
            CTD_E_CALL_STATE state =(CTD_E_CALL_STATE)notify.param2;
            NSDictionary *resultInfo = @{
                                         TUP_CTD_CALL_STATE_KEY : [NSNumber numberWithInt:state]
                                         };
            [self respondsCTDDelegateWithType:CTD_CALL_STATE result:resultInfo];
        }
            break;
        default:
            break;
    }
}

/**
 *This method is used to deel call notification
 *处理call回调业务
 *@param notify
 */
-(void)onRecvCallNotification:(Notification *)notify
{
    switch (notify.msgId)
    {
        case CALL_E_EVT_CALL_STARTCALL_RESULT:
        {
            DDLogInfo(@"recv call notify :CALL_E_EVT_CALL_STARTCALL_RESULT :%d",notify.param2);
            break;
        }
        case CALL_E_EVT_CALL_INCOMMING:
        {
            DDLogInfo(@"recv call notify :CALL_E_EVT_CALL_INCOMMING callid:%d",notify.param1);
            CALL_S_CALL_INFO *callInfo = (CALL_S_CALL_INFO *)notify.data;
            CallInfo *tupCallInfo = [CallInfo transfromFromCallInfoStract:callInfo];
            TUP_RESULT ret = tup_call_alerting_call((TUP_UINT32)tupCallInfo.stateInfo.callId);
            DDLogInfo(@"tup_call_alerting_call,ret is %d",ret);
            [self resetUCVideoOrientAndIndexWithCallId:0];
            
            NSString *callId = [NSString stringWithFormat:@"%d", tupCallInfo.stateInfo.callId];
            [_tupCallInfoDic setObject:tupCallInfo forKey:callId];
            NSDictionary *resultInfo = @{
                                         TUP_CALL_INFO_KEY : tupCallInfo
                                         };
            [self respondsCallDelegateWithType:CALL_INCOMMING result:resultInfo]; //post incoming call info to UI
            
            CallLogMessage *callLogMessage = [[CallLogMessage alloc]init];
            callLogMessage.calleePhoneNumber = tupCallInfo.stateInfo.callNum;
            callLogMessage.durationTime = 0;
            callLogMessage.startTime = [self nowTimeString];
            callLogMessage.callLogType = MissedCall;
            callLogMessage.callId = tupCallInfo.stateInfo.callId;
            callLogMessage.isConnected = NO;
            if (!tupCallInfo.isFocus) {  //write call log message to local file
                NSMutableArray *array = [[NSMutableArray alloc]init];
                if ([self loadLocalCallHistoryData].count > 0) {
                    array = [self loadLocalCallHistoryData];
                }
                [array addObject:callLogMessage];
                [self writeToLocalFileWith:array];
            }
            break;
        }
        case CALL_E_EVT_CALL_RINGBACK:
        {
            DDLogInfo(@"recv call notify :CALL_E_EVT_CALL_RINGBACK");
            CALL_S_CALL_INFO *callInfo = (CALL_S_CALL_INFO *)notify.data;
            CallInfo *tupCallInfo = [CallInfo transfromFromCallInfoStract:callInfo];
            CALL_S_CALL_STATE_INFO stCallStateInfo = callInfo->stCallStateInfo;
            int isPlay = stCallStateInfo.bHaveSDP;
            NSString *callId = [NSString stringWithFormat:@"%d", tupCallInfo.stateInfo.callId];
            [_tupCallInfoDic setObject:tupCallInfo forKey:callId];
            NSDictionary *resultInfo = @{
                                         TUP_CALL_RINGBACK_KEY : [NSNumber numberWithInt:isPlay]
                                         };
            [self respondsCallDelegateWithType:CALL_RINGBACK result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_OUTGOING:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_OUTGOING");
            CALL_S_CALL_INFO *callInfo = (CALL_S_CALL_INFO *)notify.data;
            CallInfo *tupCallInfo = [CallInfo transfromFromCallInfoStract:callInfo];
            NSString *callId = [NSString stringWithFormat:@"%d", tupCallInfo.stateInfo.callId];
            [_tupCallInfoDic setObject:tupCallInfo forKey:callId];
            NSDictionary *resultInfo = @{
                                         TUP_CALL_INFO_KEY : tupCallInfo
                                         };
            [self respondsCallDelegateWithType:CALL_OUTGOING result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_CONNECTED:
        {
            DDLogInfo(@"Call_Log: recv call notify :CALL_E_EVT_CALL_CONNECTED");
            CALL_S_CALL_INFO *callInfo = (CALL_S_CALL_INFO *)notify.data;
            CallInfo *tupCallInfo = [CallInfo transfromFromCallInfoStract:callInfo];
            NSString *callId = [NSString stringWithFormat:@"%d", tupCallInfo.stateInfo.callId];
            [_tupCallInfoDic setObject:tupCallInfo forKey:callId];
            NSDictionary *resultInfo = @{
                                         TUP_CALL_INFO_KEY : tupCallInfo
                                         };
            [self respondsCallDelegateWithType:CALL_CONNECT result:resultInfo];
            
            if ([self loadLocalCallHistoryData].count > 0) {
                NSArray *array = [self loadLocalCallHistoryData];
                for (CallLogMessage *message in array) {
                    if (message.callId == tupCallInfo.stateInfo.callId) {
                        if (message.callLogType == MissedCall) {
                            message.callLogType = ReceivedCall;
                        }
                        message.isConnected = YES;
                        [self writeToLocalFileWith:array];
                        break;
                    }
                }
            }
            break;
        }
        case CALL_E_EVT_CALL_ENDED:
        {
            DDLogInfo(@"Call_Log: recv call notify :CALL_E_EVT_CALL_ENDED");
            CALL_S_CALL_INFO *callInfo = (CALL_S_CALL_INFO *)notify.data;
            CallInfo *tupCallInfo = [CallInfo transfromFromCallInfoStract:callInfo];
            NSDictionary *resultInfo = @{
                                         TUP_CALL_INFO_KEY : tupCallInfo
                                         };
            [self respondsCallDelegateWithType:CALL_CLOSE result:resultInfo];
            
            NSString *callId = [NSString stringWithFormat:@"%d", tupCallInfo.stateInfo.callId];
            [_tupCallInfoDic removeObjectForKey:callId];
            
            self.isShowTupBfcp = NO;
            
            if ([self loadLocalCallHistoryData].count > 0) {
                NSArray *array = [self loadLocalCallHistoryData];
                for (CallLogMessage *message in array) {
                    if (message.callId == tupCallInfo.stateInfo.callId) {
                        if (message.callLogType != MissedCall && message.isConnected) {
                            NSDate *date = [NSDate date];
                            NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
                            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                            NSTimeZone *timeZone = [NSTimeZone localTimeZone];
                            [formatter setTimeZone:timeZone];
                            NSTimeInterval timeInterval = [date timeIntervalSinceDate:[formatter dateFromString:message.startTime]];
                            message.durationTime = timeInterval;
                            [self writeToLocalFileWith:array];
                        }
                        break;
                    }
                }
                
            }
            
            // TODO: CHENZHIQIAN
            //            if ([ManagerService confService].isJoinDataConf)
            //            {
            //                [[ManagerService confService] restoreConfParamsInitialValue];
            //            }
            break;
        }
        case CALL_E_EVT_REFRESH_VIEW:
        {
            [self respondsCallDelegateWithType:CALL_VIEW_REFRESH result:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:TUP_CALL_REFRESH_VIEW_NOTIFY
                                                                object:[NSNumber numberWithUnsignedInteger:notify.param1]
                                                              userInfo:nil];
            break;
        }
        case CALL_E_EVT_DECODE_SUCCESS:
        {
            CALL_S_DECODE_SUCCESS *decodeSuccess = (CALL_S_DECODE_SUCCESS *)notify.data;
            
            if (decodeSuccess->enMeidaType == CALL_E_DECODE_SUCCESS_VIDEO)
            {
                DDLogInfo(@"Call_Log:video decode success.");
                [self respondsCallDelegateWithType:CALL_DECDOE_SUCCESS result:nil];
                return;
            }
            if (decodeSuccess->enMeidaType == CALL_E_DECODE_SUCCESS_DATA)
            {
                DDLogInfo(@"BFCP_Log: data decode success.");
                return;
            }
            DDLogInfo(@"mediaDecodeSuccess,not video or data decode success.");
            [[NSNotificationCenter defaultCenter] postNotificationName:TUP_CALL_DECODE_SUCCESS_NOTIFY
                                                                object:[NSNumber numberWithUnsignedInteger:notify.param1]
                                                              userInfo:nil];
            
            break;
        }
        case CALL_E_EVT_SESSION_MODIFIED:
        {
            DDLogInfo(@"Call_Log: call revice CALL_E_EVT_SESSION_MODIFIED callId:%d",notify.param1);
            CALL_S_SESSION_MODIFIED *session = (CALL_S_SESSION_MODIFIED *)notify.data;
            if (!session)
            {
                DDLogInfo(@"session is nil");
                return;
            }
            CallSessionModifyInfo *modifyInfo = [CallSessionModifyInfo initWithCallSessionModified:session];

            // update callInfo
            NSString *callIdKey = [NSString stringWithFormat:@"%d", modifyInfo.callId];
            CallInfo *callInfo = [_tupCallInfoDic objectForKey:callIdKey];
            callInfo.orientType = modifyInfo.orientType;
            if (modifyInfo.videoSendMode == CALL_MEDIA_SENDMODE_SENDRECV
                && callInfo.stateInfo.callType != CALL_VIDEO) {
                callInfo.stateInfo.callType = CALL_VIDEO;
            }
            else if (modifyInfo.videoSendMode == CALL_MEDIA_SENDMODE_INACTIVE
                     && callInfo.stateInfo.callType == CALL_VIDEO) {
                callInfo.stateInfo.callType = CALL_AUDIO;
            }
            
            [self respondsCallDelegateWithType:CALL_SESSION_MODIFIED result:@{TUP_CALL_SESSION_MODIFIED_KEY : modifyInfo}];
            break;
        }
        case CALL_E_EVT_CALL_MODIFY_VIDEO_RESULT:
        {
            DDLogInfo(@"Call_Log: call revice CALL_E_EVT_CALL_MODIFY_VIDEO_RESULT result : %d",notify.param2);
            CALL_S_MODIFY_VIDEO_RESULT *modifyInfo = (CALL_S_MODIFY_VIDEO_RESULT *)notify.data;
            DDLogInfo(@"callInfo->ulCallID :%d,callInfo->bIsVideo :%d,callInfo->ulOrientType :%d,callInfo->ulResult: %d",modifyInfo->ulCallID,modifyInfo->bIsVideo,modifyInfo->ulOrientType,modifyInfo->ulResult);
            NSString *callId = [NSString stringWithFormat:@"%d",notify.param1];
            TUP_UINT32 result = modifyInfo->ulResult;
            BOOL callModifyResult = result == TUP_SUCCESS ? YES : NO;
            TUP_BOOL isVideo = modifyInfo->bIsVideo;
            CALL_VIDEO_OPERATION_TYPE videoOperationType = CALL_VIDEO_OPERATION_TYPE_NOCONTROL;
            if (callModifyResult)
            {
                DDLogInfo(@"Call_Log: call session modified success");
                videoOperationType = TUP_TRUE == isVideo ? CALL_VIDEO_OPERATION_TYPE_UPGRADE : CALL_VIDEO_OPERATION_TYPE_DOWNGRADE;
            }
            DDLogInfo(@"Call_Log: call callModifyResult is %i",callModifyResult);
            TUP_UINT32 videoOrient = modifyInfo->ulOrientType;
            
            // update callInfo
            NSString *callIdKey = [NSString stringWithFormat:@"%d", modifyInfo->ulCallID];
            CallInfo *callInfo = [_tupCallInfoDic objectForKey:callIdKey];
            callInfo.stateInfo.callType = TUP_TRUE == isVideo ? CALL_VIDEO : CALL_AUDIO;
            callInfo.orientType = videoOrient;
            
            NSDictionary *callModifyVideoInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 callId,CALL_ID,
                                                 [NSNumber numberWithInt:videoOperationType],CALL_VIDEO_OPERATION,
                                                 [NSNumber numberWithBool:callModifyResult],CALL_VIDEO_OPERATION_RESULT,
                                                 [NSNumber numberWithInt:videoOrient], CALL_VIDEO_ORIENT_KEY,
                                                 nil];
            [self respondsCallDelegateWithType:CALL_MODIFY_VIDEO_RESULT result:callModifyVideoInfo];
            break;
        }
        case CALL_E_EVT_CALL_ADD_VIDEO:
        {
            NSString *callId = [NSString stringWithFormat:@"%d",notify.param1];
            NSDictionary *callUpgradePassiveInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    callId,CALL_ID,
                                                    nil];
            [self respondsCallDelegateWithType:CALL_UPGRADE_VIDEO_PASSIVE result:callUpgradePassiveInfo];
            DDLogInfo(@"Call_Log: call revice CALL_E_EVT_CALL_ADD_VIDEO");
            break;
        }
        case CALL_E_EVT_CALL_DEL_VIDEO:
        {
            NSString *callId = [NSString stringWithFormat:@"%d",notify.param1];
            NSDictionary *callDowngradePassiveInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      callId,CALL_ID,
                                                      nil];
            [self respondsCallDelegateWithType:CALL_DOWNGRADE_VIDEO_PASSIVE result:callDowngradePassiveInfo];
            DDLogInfo(@"Call_Log: call CALL_E_EVT_CALL_DEL_VIDEO");
            break;
        }
        case CALL_E_EVT_REFER_NOTIFY:
        {
            [self respondsCallDelegateWithType:CALL_REFER_NOTIFY result:nil];
            break;
        }
        case CALL_E_EVT_MOBILE_ROUTE_CHANGE:
        {
            DDLogInfo(@"CALL_E_EVT_MOBILE_ROUTE_CHANGE");
            ROUTE_TYPE currentRoute = (ROUTE_TYPE)notify.param2;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NTF_AUDIOROUTE_CHANGED object:nil userInfo:@{AUDIO_ROUTE_KEY : @(currentRoute)}];
            });
            break;
        }
        case CALL_E_EVT_SERVERCONF_DATACONF_PARAM:
        {
            CALL_S_DATACONF_PARAM *dataConfParam = (CALL_S_DATACONF_PARAM *)notify.data;
            NSString *callIdKey = [NSString stringWithFormat:@"%d", dataConfParam->ulCallID];
            CallInfo *callInfo = [_tupCallInfoDic objectForKey:callIdKey];
            callInfo.serverConfId = [NSString stringWithUTF8String:dataConfParam->acDataConfID];
            break;
        }
        case CALL_E_EVT_DATA_FRAMESIZE_CHANGE:
        {
            DDLogInfo(@"CALL_E_EVT_DATA_FRAMESIZE_CHANGE");
            self.isShowTupBfcp = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TupBfcpDealMessage" object:nil];
            break;
        }
        case CALL_E_EVT_DATA_STOPPED:
        {
            DDLogInfo(@"CALL_E_EVT_DATA_STOPPED");
            self.isShowTupBfcp = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TupBfcpDealMessage" object:nil];
            break;
        }
        case CALL_E_EVT_DATA_START_ERR:
        {
            DDLogInfo(@"CALL_E_EVT_DATA_START_ERR");
            break;
        }
        case CALL_E_EVT_NEW_SERVICE_RIGHT:
        {
            CALL_S_SERVICERIGHT_CFG *serviceRightCFG = (CALL_S_SERVICERIGHT_CFG *)notify.data;
            IPTConfig *iptConfig = [IPTConfig sharedInstance];
            for(int i=0; i<CALL_E_SERVICE_RIGHT_TYPE_BUTT;i++){
                if(i == CALL_E_SERVICE_RIGHT_TYPE_DONOTDISTURB){
                    iptConfig.hasDNDRight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isDNDRegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
                if(i == CALL_E_SERVICE_RIGHT_TYPE_CALL_WAIT){
                    iptConfig.hasCWRight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isCWRegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
                if(i == CALL_E_SERVICE_RIGHT_TYPE_CALLFORWARDING_UNCONDITIONAL){
                    iptConfig.hasCFURight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isCFURegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
                if(i == CALL_E_SERVICE_RIGHT_TYPE_CALLFORWARDING_ONBUSY){
                    iptConfig.hasCFBRight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isCFBRegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
                if(i == CALL_E_SERVICE_RIGHT_TYPE_CALLFORWARDING_NOREPLY){
                    iptConfig.hasCFNARight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isCFNARegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
                if(i == CALL_E_SERVICE_RIGHT_TYPE_CALLFORWARDING_OFFLINE){
                    iptConfig.hasCFNRRight = serviceRightCFG->astSrvInfo[i].ulRight;
                    iptConfig.isCFNRRegister = serviceRightCFG->astSrvInfo[i].ulRegister;
                }
            }
            CALL_S_SERVICE_PARAM* serviceParam = &serviceRightCFG->stServiceParam;
            iptConfig.cfuNumber = [NSString stringWithUTF8String:serviceParam->acCallForwardUnconditionNum];
            iptConfig.cfbNumber = [NSString stringWithUTF8String:serviceParam->acCallForwardOnBusyNum];
            iptConfig.cfnaNumber = [NSString stringWithUTF8String:serviceParam->acCallForwardNoReplyNum];
            iptConfig.cfnrNumber = [NSString stringWithUTF8String:serviceParam->acCallForwardOfflineNum];
            
            LoginInfo *mineLoginInfo = [[ManagerService loginService] obtainCurrentLoginInfo];
            NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:iptConfig]; //将iptConfig实例序列化，以便保存
            DDLogInfo(@"........%@",mineLoginInfo.account);
            NSDictionary *dicInfo = @{
                                      @"ACCOUNT" : mineLoginInfo.account,
                                      @"IPT" : archiveCarPriceData
                                      };
            NSMutableArray *mutArray;
            NSArray *orginalArray;
            if ([[CommonUtils getUserDefaultValueWithKey:@"iptConfig"] isKindOfClass:[NSArray class]])
            {
                orginalArray= [CommonUtils getUserDefaultValueWithKey:@"iptConfig"];
                mutArray = [NSMutableArray arrayWithArray:orginalArray];
            }
            else
            {
                mutArray = [[NSMutableArray alloc] init];
            }
            if (orginalArray.count > 0)
            {
                for (NSDictionary *tempDic in orginalArray)
                {
                    NSString *account = tempDic[@"ACCOUNT"];
                    DDLogInfo(@",,,,,,,,,%@",account);
                    if ([account isEqualToString:mineLoginInfo.account]) //如果该账号已存在保存的配置，先删除
                    {
                        [mutArray removeObject:tempDic];
                    }
                }
                [mutArray addObject:dicInfo];
            }
            else
            {
                [mutArray addObject:dicInfo];
            }
            [CommonUtils userDefaultSaveValue:[NSArray arrayWithArray:mutArray] forKey:@"iptConfig"];
            break;
        }
            
        default:
            break;
    }
    if (notify.msgId>=CALL_E_EVT_CALL_HOLD_SUCCESS && notify.msgId<=CALL_E_EVT_CALL_UNHOLD_FAILED)
    {
        [self handleCallHoldNotify:notify];
    }
    if (notify.msgId>=CALL_E_EVT_CALL_BLD_TRANSFER_RECV_SUC_RSP && notify.msgId<=CALL_E_EVT_SET_IPT_SERVICE_FAILED)
    {
        [self handleTransferNotify:notify];
    }
}

/**
 *This method is used to deel call transfer notification
 *处理转移业务回调
 *@param notify
 */
-(void)handleTransferNotify:(Notification *)notify
{
    DDLogInfo(@"handleTransferNotify id:%d",notify.msgId);
    switch (notify.msgId)
    {
        case CALL_E_EVT_CALL_BLD_TRANSFER_RECV_SUC_RSP:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_BLD_TRANSFER_RECV_SUC_RSP");
            break;
        }
        case CALL_E_EVT_CALL_BLD_TRANSFER_SUCCESS:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_BLD_TRANSFER_SUCCESS");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_TRANSFER_RESULT_KEY:[NSNumber numberWithBool:YES]
                                         };
            [self respondsCallDelegateWithType:CALL_TRANSFER_RESULT result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_BLD_TRANSFER_FAILED:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_BLD_TRANSFER_FAILED");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_TRANSFER_RESULT_KEY:[NSNumber numberWithBool:NO]
                                         };
            [self respondsCallDelegateWithType:CALL_TRANSFER_RESULT result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_DIVERT_FAILED:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_DIVERT_FAILED");
            [self respondsCallDelegateWithType:CALL_DIVERT_FAILED result:nil];
            break;
        }
            
        case CALL_E_EVT_SET_IPT_SERVICE_SUCCESS:
        {
            CALL_E_SERVICE_CALL_TYPE serviceCallType = (CALL_E_SERVICE_CALL_TYPE)notify.param1;
            IPTConfigType type = [self getIPTConfigType:serviceCallType];
            if([self.iptDelegate respondsToSelector:@selector(iptConfigCallBack:result:)]){
                [self.iptDelegate iptConfigCallBack:type result:YES];
            }
            break;
        }
        case CALL_E_EVT_SET_IPT_SERVICE_FAILED:
        {
            CALL_E_SERVICE_CALL_TYPE serviceCallType = (CALL_E_SERVICE_CALL_TYPE)notify.param1;
            IPTConfigType type = [self getIPTConfigType:serviceCallType];
            DDLogInfo(@"Call_Log: CALL_E_EVT_SET_IPT_SERVICE_FAILED service : %d",serviceCallType);
            if ([self.iptDelegate respondsToSelector:@selector(iptConfigCallBack:result:)]) {
                [self.iptDelegate iptConfigCallBack:type result:NO];
            }
            break;
        }
        default:
            break;
    }
}

/**
 *This method is used to get ipt config type
 *将sdk提供的ipt业务枚举转换为自定义枚举值
 *@param serviceCallType
 */
- (IPTConfigType)getIPTConfigType:(CALL_E_SERVICE_CALL_TYPE) serviceCallType {
    
    IPTConfigType type = IPT_REG_UN;
    
    switch (serviceCallType) {
        case CALL_E_SERVICE_CALL_TYPE_REG_DND:
        {
            type = IPT_REG_DND;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_UNREG_DND:
        {
            type = IPT_UNREG_DND;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_CALL_WAIT_ACTIVE:
        {
            type = IPT_CALL_WAIT_ACTIVE;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_CALL_WAIT_DEACTIVE:
        {
            type = IPT_CALL_WAIT_DEACTIVE;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_UNCONDITION_Active:
        {
            type = IPT_FORWARD_UNCONDITION_Active;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_UNCONDITION_Deactive:
        {
            type = IPT_FORWARD_UNCONDITION_Deactive;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_ONBUSY_Active:
        {
            type = IPT_FORWARD_ONBUSY_Active;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_ONBUSY_Deactive:
        {
            type = IPT_FORWARD_ONBUSY_Deactive;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_NOREPLY_Active:
        {
            type = IPT_FORWARD_NOREPLY_Active;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_NOREPLY_Deactive:
        {
            type = IPT_FORWARD_NOREPLY_Deactive;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_OFFLINE_Active:
        {
            type = IPT_FORWARD_OFFLINE_Active;
            break;
        }
        case CALL_E_SERVICE_CALL_TYPE_FORWARD_OFFLINE_Deactive:
        {
            type = IPT_FORWARD_OFFLINE_Deactive;
            break;
        }
        default:
            break;
    }
    
    return type;
}

/**
 *This method is used to deel call hold notification
 *处理呼叫保持回调业务
 *@param notify
 */
-(void)handleCallHoldNotify:(Notification *)notify
{
    DDLogInfo(@"handleCallHoldNotify id:%d",notify.msgId);
    NSString *callId = [NSString stringWithFormat:@"%d",notify.param1];
    switch (notify.msgId)
    {
        case CALL_E_EVT_CALL_HOLD_SUCCESS:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_HOLD_SUCCESS");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_HOLD_RESULT_KEY:[NSNumber numberWithBool:YES],
                                         CALL_ID : callId
                                         };
            [self respondsCallDelegateWithType:CALL_HOLD_RESULT result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_HOLD_FAILED:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_HOLD_FAILED");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_HOLD_RESULT_KEY:[NSNumber numberWithBool:NO],
                                         CALL_ID : callId
                                         };
            [self respondsCallDelegateWithType:CALL_HOLD_RESULT result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_UNHOLD_SUCCESS:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_UNHOLD_SUCCESS");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_UNHOLD_RESULT_KEY:[NSNumber numberWithBool:YES],
                                         CALL_ID : callId
                                         };
            [self respondsCallDelegateWithType:CALL_UNHOLD_RESULT result:resultInfo];
            break;
        }
        case CALL_E_EVT_CALL_UNHOLD_FAILED:
        {
            DDLogInfo(@"CALL_E_EVT_CALL_UNHOLD_FAILED");
            NSDictionary *resultInfo = @{
                                         TUP_CALL_UNHOLD_RESULT_KEY:[NSNumber numberWithBool:NO],
                                         CALL_ID : callId
                                         };
            [self respondsCallDelegateWithType:CALL_UNHOLD_RESULT result:resultInfo];
            break;
        }
        default:
            break;
    }
}

/**
 *This method is used to get incoming call number
 *获取来电号码
 *@param callInfo
 */
- (NSDictionary*)parseCallNumberForInfo:(CallInfo*)callInfo
{
    NSMutableDictionary* parseDic = [NSMutableDictionary dictionary];
    NSString *comingSipNum = callInfo.stateInfo.callNum;
    NSRange numSearchRange = [comingSipNum rangeOfString:@"@"];
    if (numSearchRange.length > 0)
    {
        comingSipNum = [comingSipNum substringToIndex:numSearchRange.location];
    }
    
    NSString *comingNum = callInfo.telNumTel;
    if (0 == [comingNum length])
    {
        comingNum = comingSipNum;
    }
    NSRange searchRange = [comingNum rangeOfString:@"@"];
    if (searchRange.length > 0)
    {
        comingNum = [comingNum substringToIndex:searchRange.location];
    }
    
    NSRange rangeSearched = [comingNum rangeOfString:@";cpc=ordinary" options:NSCaseInsensitiveSearch];
    if (rangeSearched.length > 0)
    {
        comingNum = [comingNum substringToIndex:rangeSearched.location];
    }
    
    [parseDic setObject:comingNum forKey:CALLINFO_CALLNUMBER_KEY];
    [parseDic setObject:comingSipNum forKey:CALLINFO_SIPNUMBER_KEY];
    
    return parseDic;
}

/**
 *This method is used to alerting call
 *收到来电时通知对方本段已震铃
 */
-(BOOL)callAlerting:(int)callId
{
    TUP_RESULT result = tup_call_alerting_call(callId);
    return result == TUP_SUCCESS ? YES : NO;
}
#pragma mark - Config


/**
 *This method is used to reset video orient and index
 *重设摄像头的方向和序号
 */
- (void)resetUCVideoOrientAndIndexWithCallId:(unsigned int)callid
{
    CALL_S_VIDEO_ORIENT orient;
    orient.ulChoice = 1;
    orient.ulPortrait = 0;
    orient.ulLandscape = 0;
    orient.ulSeascape = 1;
    tup_call_set_video_orient(callid, CameraIndexFront, &orient);
}

/**
 * This method is used to update video window local view
 * 更新视频本地窗口画面
 *@param localVideoView     Indicates local video view
 *                          本地视频视图
 *@param remoteVideoView    Indicates remote video view
 *                          远端视频试图
 *@param bfcpVideoView      Indicates bfcp video view
 *                          bfcp视频试图
 *@param callId             Indicates call id
 *                          呼叫id
 *@return YES or NO
 */
- (BOOL)updateVideoWindowWithLocal:(id)localVideoView
                         andRemote:(id)remoteVideoView
                           andBFCP:(id)bfcpVideoView
                            callId:(unsigned int)callId
{
    CALL_S_VIDEOWND_INFO videoInfo[3];
    memset_s(videoInfo, sizeof(CALL_S_VIDEOWND_INFO) * 2, 0, sizeof(CALL_S_VIDEOWND_INFO) * 2);
    videoInfo[0].ulVideoWndType = CALL_E_VIDEOWND_CALLLOCAL;
    videoInfo[0].ulRender = (TUP_UPTR)localVideoView;
    videoInfo[0].ulDisplayType = 2;
    videoInfo[1].ulVideoWndType = CALL_E_VIDEOWND_CALLREMOTE;
    videoInfo[1].ulRender = (TUP_UPTR)remoteVideoView;
    videoInfo[1].ulDisplayType = 1;
    videoInfo[2].ulVideoWndType = CALL_E_VIDEOWND_CALLDATA;
    videoInfo[2].ulRender = (TUP_UPTR)bfcpVideoView;
    TUP_RESULT ret;
    videoInfo[2].ulDisplayType = 1;
    if (0 < callId) {
        ret = tup_call_update_video_window(3, videoInfo, (TUP_UINT32)callId);;
    }
    else
    {
        ret = tup_call_create_video_window(3, videoInfo);
    }
    
    DDLogInfo(@"Call_Log: tup_call_update_video_window = %@",SDK_CONFIG_RESULT(ret));
    
    [self updateVideoRenderInfoWithVideoIndex:CameraIndexFront withRenderType:CALL_E_VIDEOWND_CALLLOCAL andCallId:callId];
    [self updateVideoRenderInfoWithVideoIndex:CameraIndexFront withRenderType:CALL_E_VIDEOWND_CALLREMOTE andCallId:callId];
    return (TUP_SUCCESS == ret);
}

/**
 * This method is used to open video preview, default open front camera
 * 打开视频预览,默认打开前置摄像头
 *@param cameraIndex         Indicates camera index
 *                           视频摄像头序号
 *@param viewHandler         Indicates view handle
 *                           视图句柄
 *@return YES or NO
 */
- (BOOL)videoPreview:(unsigned int)cameraIndex toView:(id) viewHandler
{
    _videoPreview = viewHandler;
    TUP_RESULT ret = tup_call_open_preview((TUP_UPTR)viewHandler, (TUP_UINT32)cameraIndex);
    DDLogInfo(@"Camera_Log:tup_call_open_preview result is %d", ret);
    
    NSString *tempCallId = nil;
    TUP_RESULT retss = tup_call_set_capture_rotation((TUP_UINT32)[tempCallId integerValue], (TUP_UINT32)1, (TUP_UINT32)0);
    DDLogInfo(@"tup_call_set_capture_rotation result is %d", retss);
    TUP_RESULT retsss = tup_call_set_display_rotation((TUP_UINT32)[tempCallId integerValue], CALL_E_VIDEOWND_CALLLOCAL, (TUP_UINT32)1);
    DDLogInfo(@"tup_call_set_display_rotation result is %d", retsss);
    
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to config video window local view
 * 配置视频本地窗口画面
 *@param localView          Indicates local view
 *                          本地视图
 *@param remoteView         Indicates remote view
 *                          远端试图
 *@param bfcpView           Indicates bfcp view
 *                          bfcp试图
 *@param callId             Indicates call id
 *                          呼叫id
 *@return YES or NO
 */
-(BOOL)configVideoWindowLocalView:(id)localView
                       remoteView:(id)remoteView
                         bfcpView:(id)bfcpView
                           callId:(unsigned int)callId
{
    CALL_S_VIDEOWND_INFO window[3];
    memset_s(window, sizeof(CALL_S_VIDEOWND_INFO)*2, 0, sizeof(CALL_S_VIDEOWND_INFO)*2);
    window[0].ulVideoWndType = CALL_E_VIDEOWND_CALLLOCAL;
    window[0].ulRender = (TUP_UPTR)localView;
    window[0].ulDisplayType = 2;
    window[1].ulVideoWndType = CALL_E_VIDEOWND_CALLREMOTE;
    window[1].ulRender = (TUP_UPTR)remoteView;
    window[1].ulDisplayType = 0;
    window[2].ulVideoWndType = CALL_E_VIDEOWND_CALLDATA;
    window[2].ulRender = (TUP_UPTR)bfcpView;
    window[2].ulDisplayType = 1;
    
    int result = tup_call_set_video_window(3, window, callId);
    DDLogInfo(@"tup_call_set_video_window result is %d", result);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to close video preview
 *关闭视频预览
 */
-(void)stopVideoPreview
{
    tup_call_close_preview();
}

/**
 *This method is used to start EC access number to join conference
 *EC接入码入会
 *@param confid                  Indicates confid
 *                               会议Id
 *@param acceseNum               Indicates accese number
 *                               会议接入码
 *@param psw                     Indicates password
 *                               会议密码
 *@return unsigned int           Return call id, equal zero mean start call fail.
 *                               返回呼叫id,失败返回0
 */
- (unsigned int) startECAccessCallWithConfid:(NSString *)confid AccessNum:(NSString *)acceseNum andPsw:(NSString *)psw
{
    TUP_UINT32 callid = 0;
    CALL_S_CONF_PARAM *confParam = (CALL_S_CONF_PARAM *)malloc(sizeof(CALL_S_CONF_PARAM));
    memset_s(confParam, sizeof(CALL_S_CONF_PARAM), 0, sizeof(CALL_S_CONF_PARAM));
    if (confid.length > 0 && confid != nil) {
        strcpy(confParam->confid, [confid UTF8String]);
    }
    if (psw.length > 0 && psw != nil) {
        strcpy(confParam->conf_paswd, [psw UTF8String]);
    }
    if (acceseNum.length > 0 && acceseNum != nil) {
        strcpy(confParam->access_code, [acceseNum UTF8String]);
    }
    //callType  默认使用CALL_E_CALL_TYPE_IPVIDEO
    TUP_RESULT ret_ex = tup_call_serverconf_access_reservedconf_ex(&callid, CALL_E_CALL_TYPE_IPVIDEO, confParam);
    return callid;
    
}

/**
 *This method is used to start point to point audio call or video call
 *发起音视频呼叫
 *@param number                  Indicates number
 *                               呼叫的号码
 *@param callType audio/video    Indicates call type
 *                               呼叫类型
 *@return unsigned int           Return call id, equal zero mean start call fail.
 *                               返回呼叫id,失败返回0
 */
-(unsigned int)startCallWithNumber:(NSString *)number type:(TUP_CALL_TYPE)callType
{
    if (nil == number || number.length == 0) {
        return 0;
    }
    [self resetUCVideoOrientAndIndexWithCallId:0];
    CALL_E_CALL_TYPE e_callType = (CALL_E_CALL_TYPE)callType;
    TUP_UINT32 callid = 0;
    TUP_RESULT ret = tup_call_start_call(&callid,
                                         e_callType,
                                         (TUP_CHAR*)[number UTF8String]);
    DDLogInfo(@"Call_Log: tup_call_start_call = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    
    if (ret == TUP_SUCCESS) {
        CallLogMessage *callLogMessage = [[CallLogMessage alloc]init];
        callLogMessage.calleePhoneNumber = number;
        callLogMessage.durationTime = 0;
        callLogMessage.startTime = [self nowTimeString];
        callLogMessage.callLogType = OutgointCall;
        callLogMessage.callId = callid;
        callLogMessage.isConnected = NO;
        NSMutableArray *array = [[NSMutableArray alloc]init];
        if ([self loadLocalCallHistoryData].count > 0) {
            array = [self loadLocalCallHistoryData];
        }
        [array addObject:callLogMessage];
        [self writeToLocalFileWith:array];
    }
    
    return callid;
}

/**
 *This method is used to answer the incoming call, select audio or video call
 *接听呼叫
 *@param callType                Indicates call type
 *                               呼叫类型
 *@param callId                  Indicate call id
 *                               呼叫id
 *@return YES or NO
 */
- (BOOL) answerComingCallType:(TUP_CALL_TYPE)callType callId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_accept_call((TUP_UINT32)callId, callType == CALL_AUDIO ? TUP_FALSE : TUP_TRUE);
    DDLogInfo(@"Call_Log:answer call type is %d,result is %d, callid: %d",callType,ret,callId);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to end call
 *结束通话
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES or NO
 */
-(BOOL)closeCall:(unsigned int)callId
{
    TUP_UINT32 callid = (TUP_UINT32)callId;
    TUP_RESULT ret = tup_call_end_call(callid);
    DDLogInfo(@"Call_Log: tup_call_end_call = %d, callid:%d",ret,callId);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to reply request of adding video call
 *回复是否接受音频转视频
 *@param accept                  Indicates whether accept
 *                               是否接受
 *@param callId                  Indicates call id
 *                               呼叫Id
 @return YES is success,NO is fail
 */
-(BOOL)replyAddVideoCallIsAccept:(BOOL)accept callId:(unsigned int)callId
{
    TUP_BOOL isAccept = accept;
    TUP_RESULT ret = tup_call_reply_add_video((TUP_UINT32)callId , isAccept);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to upgrade audio to video call
 *将音频呼叫升级为视频呼叫
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)upgradeAudioToVideoCallWithCallId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_add_video((TUP_UINT32)callId);
    DDLogInfo(@"Call_Log: tup_call_add_video = %d",ret);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to transfer video call to audio call
 *将视频呼叫转为音频呼叫
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)downgradeVideoToAudioCallWithCallId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_del_video((TUP_UINT32)callId);
    DDLogInfo(@"Call_Log: tup_call_del_video = %d",ret);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to rotation camera capture
 * 转换摄像头采集
 *@param ratation                Indicates camera rotation {0,1,2,3}
 *                               旋转摄像头采集
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)rotationCameraCapture:(NSUInteger)ratation callId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_set_capture_rotation((TUP_UINT32)callId , (TUP_UINT32)_cameraCaptureIndex, (TUP_UINT32)ratation);
    DDLogInfo(@"Call_Log: tup_call_set_capture_rotation = %d",ret);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to rotation Video display
 * 旋转摄像头显示
 *@param orientation             Indicates camera orientation
 *                               旋转摄像头采集
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES is success, NO is fail
 */
-(BOOL)rotationVideoDisplay:(NSUInteger)orientation callId:(unsigned int)callId
{
    TUP_RESULT ret_rotation = tup_call_set_display_rotation((TUP_UINT32)callId, CALL_E_VIDEOWND_CALLLOCAL, (TUP_UINT32)orientation);
    DDLogInfo(@"tup_call_set_display_rotation : %d", ret_rotation);
    return (TUP_SUCCESS == ret_rotation);
}

/**
 *This interface is used to set set camera picture
 *设置视频采集文件
 */
-(BOOL)setVideoCaptureFileWithcallId:(unsigned int)callId
{
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"tup_call_closeCramea_img"
                                                          ofType:@"bmp"];
    TUP_RESULT ret = tup_call_set_video_capture_file((TUP_UINT32)callId, (TUP_CHAR *)[imagePath UTF8String]);
    DDLogInfo(@"Call_Log: tup_call_set_video_capture_file = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to switch camera index
 * 切换摄像头
 *@param cameraCaptureIndex      Indicates camera capture index, Fort -1 Back -0
 *                               摄像头序号
 *@param callId                  Indicates call id
 *                               呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)switchCameraIndex:(NSUInteger)cameraCaptureIndex callId:(unsigned int)callId
{
    CALL_S_VIDEO_ORIENT orient;
    orient.ulChoice = 1;
    orient.ulPortrait = 0;
    orient.ulLandscape = 0;
    orient.ulSeascape = 1;
    TUP_RESULT result = tup_call_set_video_orient(callId, cameraCaptureIndex, &orient);
    if (result == TUP_SUCCESS)
    {
        _cameraCaptureIndex = cameraCaptureIndex == 1 ? CameraIndexFront : CameraIndexBack;
    }
    [self updateVideoRenderInfoWithVideoIndex:(CameraIndex)cameraCaptureIndex withRenderType:CALL_E_VIDEOWND_CALLLOCAL andCallId:callId];
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to update video  render info with video index
 *根据摄像头序号更新视频渲染
 */
- (void)updateVideoRenderInfoWithVideoIndex:(CameraIndex)index withRenderType:(CALL_E_VIDEOWND_TYPE)renderType andCallId:(unsigned int)callid
{
    TUP_UINT32 mirrorType = 0;
    TUP_UINT32 displaytype = 0;
    
    //本端视频，displaytype为1，镜像模式根据前后摄像头进行设置
    if (CALL_E_VIDEOWND_CALLLOCAL == renderType)
    {
        //前置镜像模式为2（左右镜像），后置镜像模式为0（不做镜像）
        switch (index) {
            case CameraIndexBack:
            {
                mirrorType = 0;
                break;
            }
            case CameraIndexFront:
            {
                mirrorType = 2;
                break;
            }
            default:
                break;
        }
        
        displaytype = 2;
    }
    //远端视频，镜像模式为0(不做镜像)，显示模式为0（拉伸模式）
    else if (CALL_E_VIDEOWND_CALLREMOTE == renderType)
    {
        mirrorType = 0;
        displaytype = 1;
    }
    else
    {
        DDLogInfo(@"rendertype is not remote or local");
    }
    
    CALL_S_VIDEO_RENDER_INFO info;
    info.enRenderType = renderType;
    info.ulDisplaytype = displaytype;
    info.ulMirrortype = mirrorType;
    TUP_RESULT ret_video_render_info = tup_call_set_video_render(callid, &info);
    DDLogInfo(@"tup_call_set_video_render : %d", ret_video_render_info);
}

/**
 * This method is used to get device list
 * 获取设备列表
 *@param deviceType                 Indicates device type,see CALL_E_DEVICE_TYPE
 *                                  设备类型，参考CALL_E_DEVICE_TYPE
 *@return YES is success,NO is fail
 */
-(BOOL)obtainDeviceListWityType:(DEVICE_TYPE)deviceType
{
    DDLogInfo(@"current device type: %d",deviceType);
    TUP_UINT32 deviceNum = 0;
    CALL_S_DEVICEINFO *deviceInfo;
    TUP_RESULT ret = tup_call_media_get_devices(&deviceNum, deviceInfo, (CALL_E_DEVICE_TYPE)deviceType);
    DDLogInfo(@"Call_Log: tup_call_media_get_devices = %#x,count:%d",ret,deviceNum);
    if (deviceNum>0)
    {
        DDLogInfo(@"again");
        deviceInfo = new CALL_S_DEVICEINFO[deviceNum];
        TUP_RESULT rets = tup_call_media_get_devices(&deviceNum, deviceInfo, (CALL_E_DEVICE_TYPE)deviceType);
        DDLogInfo(@"Call_Log: tup_call_media_get_devices = %#x,count:%d",rets,deviceNum);
        for (int i = 0; i<deviceNum; i++)
        {
            DDLogInfo(@"Call_Log: ulIndex:%d,strName:%s,string:%@",deviceInfo[i].ulIndex,deviceInfo[i].strName,[NSString stringWithUTF8String:deviceInfo[i].strName]);
        }
    }
    delete [] deviceInfo;
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to switch camera open or close
 * 切换摄像头开关
 *@param openCamera               Indicates open camera, YES:open NO:close
 *                                是否打开摄像头
 *@param callId                   Indicates call id
 *                                呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)switchCameraOpen:(BOOL)openCamera callId:(unsigned int)callId
{
    if (openCamera)
    {
        [self videoControlWithCmd:OPEN_AND_START andModule:LOCAL andIsSync:NO callId:callId];
//        [self pauseVideoCapture:NO callId:callId];
        _cameraRotation = 0;
        TUP_RESULT ret = tup_call_set_capture_rotation((TUP_UINT32)callId , (TUP_UINT32)_cameraCaptureIndex, (TUP_UINT32)_cameraRotation);
        DDLogInfo(@"Call_Log: tup_call_set_capture_rotation = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    }
    else
    {
        [self setVideoCaptureFileWithcallId:callId];
        [self videoControlWithCmd:STOP andModule:LOCAL andIsSync:YES callId:callId];
//        [self pauseVideoCapture:YES callId:callId];
    }
    return YES;
}

/**
 *This method is used to control camera close or open
 *控制摄像头的开关
 */
-(BOOL)callVideoControlCameraClose:(BOOL)isCameraClose Module:(EN_VIDEO_OPERATION_MODULE)module callId:(unsigned int)callId
{
    if (isCameraClose)
    {
        [self setVideoCaptureFileWithcallId:callId];
        [self videoControlWithCmd:STOP andModule:LOCAL_AND_REMOTE andIsSync:YES callId:callId];
    }
    else
    {
        //reopen local camera
        _cameraCaptureIndex = CameraIndexFront;
        _cameraRotation = 0;
        [self rotationCameraCapture:_cameraRotation callId:callId];
        [self videoControlWithCmd:OPEN_AND_START andModule:LOCAL_AND_REMOTE andIsSync:YES callId:callId];

    }
    return YES;
}

/**
 *This method is used to control video
 *控制远端和近端的摄像头打开或者关闭
 */
-(void)videoControlWithCmd:(EN_VIDEO_OPERATION)control andModule:(EN_VIDEO_OPERATION_MODULE)module andIsSync:(BOOL)isSync callId:(unsigned int)callId
{
    DDLogInfo(@"videoControlWithCmd :%d module: %d isSync:%d",control,module,isSync);
    CALL_S_VIDEOCONTROL videoControlInfos;
    memset_s(&videoControlInfos, sizeof(CALL_S_VIDEOCONTROL), 0, sizeof(CALL_S_VIDEOCONTROL));
    videoControlInfos.ulCallID = (TUP_UINT32)callId;
    videoControlInfos.ulModule = module;
    videoControlInfos.ulOperation = control;
    videoControlInfos.bIsSync = isSync;
    TUP_RESULT ret = tup_call_video_control(&videoControlInfos);
    DDLogInfo(@"Call_Log: tup_call_video_control result= %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
}

/**
 * This method is used to deal with video streaming, app enter background or foreground
 * 在app前后景切换时,控制视频流
 *@param active                    Indicates active YES: goreground NO: background
 *                                 触发行为
 *@param callId                    Indicates call id
 *                                 呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)controlVideoWhenApplicationResignActive:(BOOL)active callId:(unsigned int)callId
{
    if (active)
    {
        return [self callVideoControlCameraClose:NO Module:LOCAL_AND_REMOTE callId:callId];
    }
    else
    {
        return [self callVideoControlCameraClose:YES Module:LOCAL_AND_REMOTE callId:callId];
    }
}

/**
 * This method is used to play WAV music file
 * 播放wav音乐文件
 *@param filePath                  Indicates file path
 *                                 文件路径
 *@return YES is success,NO is fail
 */
-(BOOL)mediaStartPlayWithFile:(NSString *)filePath
{
    if (_playHandle >= 0)
    {
        return NO;
    }
    TUP_RESULT result = tup_call_media_startplay(0, (TUP_CHAR *)[filePath UTF8String], &_playHandle);
    DDLogInfo(@"Call_Log: tup_call_media_startplay result= %xd , playhandle = %d",result,_playHandle);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to stop play music
 * 停止播放铃音
 *@return YES is success,NO is fail
 */
-(BOOL)mediaStopPlay
{
    TUP_RESULT result = tup_call_media_stopplay(_playHandle);
    _playHandle = -1;
    DDLogInfo(@"Call_Log: tup_call_media_stopplay result= %d",result);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to switch mute micphone
 * 打开或者关闭麦克风
 *@param mute                      Indicates switch microphone, YES is mute,NO is unmute
 *                                 打开或者关闭麦克风
 *@param callId                    Indicates call id
 *                                 呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)muteMic:(BOOL)mute callId:(unsigned int)callId
{
    TUP_RESULT result = tup_call_media_mute_mic(callId , mute);
    DDLogInfo(@"Call_Log: tup_call_media_mute_mic result= %@",(TUP_SUCCESS == result)?@"YES":@"NO");
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to switch mute speak
 * 打开或者关闭扬声器
 *@param mute                      Indicates switch speak, YES is mute,NO is unmute
 *                                 打开或者关闭扬声器
 *@param callId                    Indicates call id
 *                                 呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)muteSpeak:(BOOL)mute callId:(unsigned int)callId
{
    TUP_RESULT result = tup_call_media_mute_speak(callId , mute);
    DDLogInfo(@"Call_Log: tup_call_media_mute_speak result= %@",(TUP_SUCCESS == result)?@"YES":@"NO");
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to pause video capture
 * 暂停视频采集
 *@param pause                     Indicates whether pause video capture, YES: pause NO:recovery
 *                                 是否暂停视频采集
 *@param callId                    Indicates call id
 *                                 呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)pauseVideoCapture:(BOOL)pause callId:(unsigned int)callId
{
    TUP_RESULT result = tup_call_media_mute_video(callId, pause);
    DDLogInfo(@"Call_Log: tup_call_media_mute_video result= %d, pause: %d",result,pause);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to set audio route
 * 设置音频路线
 *@param route                      Indicates audio route, see ROUTE_TYPE enum value
 *                                  音频路线
 *@return YES is success,NO is fail. Call back see NTF_AUDIOROUTE_CHANGED
 */
-(BOOL)configAudioRoute:(ROUTE_TYPE)route
{
    CALL_E_MOBILE_AUIDO_ROUTE audioRoute = (CALL_E_MOBILE_AUIDO_ROUTE)route;
    TUP_RESULT result = tup_call_set_mobile_audio_route(audioRoute);
    DDLogInfo(@"tup_call_set_mobile_audio_route result is %@, audioRoute is :%d",result == TUP_SUCCESS ? @"YES" : @"NO",audioRoute);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to get audio route
 * 获取音频路线
 *@return ROUTE_TYPE
 */
-(ROUTE_TYPE)obtainMobileAudioRoute
{
    CALL_E_MOBILE_AUIDO_ROUTE route;
    TUP_RESULT result = tup_call_get_mobile_audio_route(&route);
    DDLogInfo(@"tup_call_get_mobile_audio_route result is %d, audioRoute is :%d",result,route);
    return (ROUTE_TYPE)route;
}

/**
 * This method is used to send DTMF
 * 发送dtmf
 *@param number                      Indicates dtmf number, 0-9 * #
 *                                   dtmf号码
 *@param callId                      Indicates call id
 *                                   呼叫id
 *@return YES is success,NO is fail
 */
- (BOOL)sendDTMFWithDialNum:(NSString *)number callId:(unsigned int)callId
{
    CALL_E_DTMF_TONE dtmfTone = (CALL_E_DTMF_TONE)[number intValue];
    if ([number isEqualToString:@"*"])
    {
        dtmfTone = CALL_E_DTMFSTAR;
    }
    else if ([number isEqualToString:@"#"])
    {
        dtmfTone = CALL_E_DTMFJIN;
    }
    TUP_UINT32 callid = callId;
    TUP_RESULT ret = tup_call_send_DTMF((TUP_UINT32)callid,(CALL_E_DTMF_TONE)dtmfTone);
    DDLogInfo(@"Call_Log: tup_call_send_DTMF = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    return ret == TUP_SUCCESS ? YES : NO;
}

#pragma mark - IPT
/**
 * This method is used to call is on going, hold this call, not hand up
 * 保持呼叫
 *@param callId                      Indicates call id
 *                                   呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)holdCallWithCallId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_hold_call(callId);
    DDLogInfo(@"Call_Log: tup_call_hold_call = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to unhold call
 * 取消保持呼叫
 *@param callId                      Indicates call id
 *                                   呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)unHoldCallWithCallId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_unhold_call(callId);
    DDLogInfo(@"Call_Log: tup_call_unhold_call = %@",(TUP_SUCCESS == ret)?@"YES":@"NO");
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to blind transfer number
 * 盲转
 *@param number                      Indicates distination number
 *                                   盲转目的地号码
 *@param callId                      Indicates call id
 *                                   呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)blindTransferWithNumber:(NSString *)number callId:(unsigned int)callId
{
    TUP_RESULT ret = tup_call_blind_transfer(callId , [number UTF8String]);
    DDLogInfo(@"Call_Log: tup_call_blind_transfer = %d, number = %@",ret,number);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to divert call
 * 偏转号码
 *@param number                      Indicates distination number
 *                                   偏转目的地号码
 *@param callId                      Indicates call id
 *                                   呼叫id
 *@return YES is success,NO is fail
 */
-(BOOL)divertCallWithNumber:(NSString *)number callId:(unsigned int)callId
{
    
    TUP_RESULT ret = tup_call_divert_call(callId , [number UTF8String]);
    DDLogInfo(@"Call_Log: tup_call_divert_call = %d, number = %@",ret,number);
    return ret == TUP_SUCCESS ? YES : NO;
}


/**
 * This method is used to config DND active code and deactive code
 * 配置免打扰业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configDNDITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_DND, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_DND = %#x",configResult);
}

/**
 * This method is used to config call wait active code and deactive code
 * 配置呼叫等待业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configCallWaitITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_CALLWAIT, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_CALLWAIT = %#x",configResult);
}

/**
 * This method is used to config unconditional forward active code and deactive code
 * 配置无条件前转业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configCFUITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_CFU, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_CFU = %#x",configResult);
}

/**
 * This method is used to config busy forward active code and deactive code
 * 配置遇忙前转业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configCFBITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_CFB, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_CFB = %#x",configResult);
}

/**
 * This method is used to config no reply forward active code and deactive code
 * 配置无应答前转业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configCFNAITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_CFNA, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_CFNA = %#x",configResult);
}

/**
 * This method is used to config offline forward active code and deactive code
 * 配置离线前转业务登记码及去登记码
 *@param activeCode                      Indicates active code
 *                                       登记码
 *@param deactiveCode                    Indicates deactive code
 *                                       去登记码
 */
-(void)configCFNRITPServerWithActiveCode:(NSString *)activeCode deactiveCode:(NSString *)deactiveCode
{
    TUP_RESULT configResult = TUP_FAIL;
    CALL_S_SERVICE_RIGHT_CFG serviceRightCfg;
    memset(&serviceRightCfg, 0, sizeof(serviceRightCfg));
    serviceRightCfg.ulRight = 1;
    strcpy(serviceRightCfg.acActiveAccessCode, [activeCode UTF8String]);
    strcpy(serviceRightCfg.acDeactiveAccessCode, [deactiveCode UTF8String]);
    configResult = tup_call_set_cfg(CALL_D_CFG_SERVRIGHT_CFNR, &serviceRightCfg);
    DDLogInfo(@"Call_Log: CALL_D_CFG_SERVRIGHT_CFNR = %#x",configResult);
}

/**
 * This method is used to set IPT service
 * 设置ipt业务
 *@param serviceType                     Indicates service type, see CALL_E_SERVICE_CALL_TYPE value
 *                                       ipt业务类型，参考CALL_E_SERVICE_CALL_TYPE
 *@param number                          Indicates destination number
 *                                       目标号码
 *@return YES or NO
 */
-(BOOL)setIPTService:(NSInteger)serviceType number:(NSString *)number
{
    TUP_RESULT ret = tup_call_set_IPTservice((CALL_E_SERVICE_CALL_TYPE)serviceType, (void *)[number UTF8String]);
    DDLogInfo(@"Call_Log: tup_call_set_IPTservice = %#x",ret);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used before call hold when your voip call on going,this moment,you have revice a normal call,if you answer the normal call,when you hand up normal call, again call back this mothod after unhold call .
 * 在呼叫中收到一路新的普通呼叫，接听这路普通呼叫后，在原呼叫保持之前调用该接口，在挂断新的这路呼叫后，在恢复保持呼叫之前再次调用该接口
 *@param sendonly                     Indicates YES: release audio resource NO: resume audio resource
 *@return YES is success,NO is fail
 */
-(BOOL)switchMediaSendonlyFree:(BOOL)sendonly
{
    TUP_BOOL tupBool = sendonly == YES ? 1 : 0;
    TUP_RESULT configResult = tup_call_set_cfg(CALL_D_CFG_MEDIA_SENDONLYFREE, &tupBool);
    DDLogInfo(@"Login: tup_call_set_cfg CALL_D_CFG_MEDIA_SENDONLYFREE = %#x, sendonly :%d",configResult,sendonly);
    return configResult == TUP_SUCCESS ? YES : NO;
}

/**
 *[en[This method is used to uninit call service
 * 去初始化呼叫业务
 *@return YES or NO
 */
-(BOOL)unloadCallService
{
    TUP_RESULT result = tup_call_uninit();
    DDLogInfo(@"Call_Log: tup_call_uninit = %#x",result);
    return result == TUP_SUCCESS ? YES : NO;
}

#pragma mark - CTD

/**
 * This method is used to config ctd server address and server port
 * 配置ctd服务器地址和端口号
 *@param serverAddress            Indicates uportal login server address
 *                                服务器地址
 *@param port                     Indicates uportal login server port
 *                                服务器端口号
 *@return YES is success,NO is fail
 */
-(BOOL)ctdConfigServer:(NSString *)serverAddress port:(NSUInteger)port
{
    CTD_S_SERVER_PARA* param = (CTD_S_SERVER_PARA *)malloc(sizeof(CTD_S_SERVER_PARA));
    memset(param, 0, sizeof(CTD_S_SERVER_PARA));
    strcpy(param->server_addr, [serverAddress UTF8String]);
    param->port = (TUP_UINT16)port;
    int result = tup_ctd_set_server_param(param);
    DDLogInfo(@"tup_ctd_set_server_param result: %d",result);
    free(param);
    return TUP_SUCCESS == result ? YES : NO;
}

/**
 *This method is used to config ctd proxy server
 *设置ctd代理服务器
 */
-(BOOL)ctdConfigProxy:(NSString *)serverAddress port:(NSString *)port account:(NSString *)account password:(NSString *)password
{
    CTD_S_PROXY_PARAM* proxy_param = (CTD_S_PROXY_PARAM *)malloc(sizeof(CTD_S_PROXY_PARAM));
    memset(proxy_param, 0, sizeof(CTD_S_PROXY_PARAM));
    strcpy(proxy_param->uri, [serverAddress UTF8String]);
    strcpy(proxy_param->user_name, [account UTF8String]);
    strcpy(proxy_param->password, [password UTF8String]);
    proxy_param->port = [port intValue];
    int result = tup_ctd_set_proxy(proxy_param);
    DDLogInfo(@"tup_ctd_set_proxy result: %d",result);
    free(proxy_param);
    return TUP_SUCCESS == result ? YES : NO;
}

/**
 * This method is used to start CTD call
 * 发起ctd呼叫
 *@param callbackNumber           Indicates ctd callback number
 *                                ctd主叫号码
 *@param callee                   Indicates target number
 *                                ctd被叫号码
 *@return YES is success,NO is fail
 */
-(BOOL)startCTDCallWithCallbackNumber:(NSString *)callbackNumber
                         calleeNumber:(NSString *)callee;
{
    NSArray *array = [self.sipAccount componentsSeparatedByString:@"@"];
    NSString *shortSipNum = array[0];
    CTD_S_CALL_PARAM *param = (CTD_S_CALL_PARAM *)malloc(sizeof(CTD_S_CALL_PARAM));
    memset(param, 0, sizeof(CTD_S_CALL_PARAM));
    strcpy(param->callee_number, [callee UTF8String]);
    strcpy(param->caller_number, [callbackNumber UTF8String]);
    strcpy(param->subscribe_number, [shortSipNum UTF8String]);
    strcpy(param->token, [_token UTF8String]);
    TUP_INT32 ctdCallId;
    int result = tup_ctd_start_call(param, (TUP_UINT32*)&ctdCallId);
    _ctdCallId = ctdCallId;
    DDLogInfo(@"tup_ctd_start_call result: %d",result);
    free(param);
    if (result == TUP_SUCCESS) {
        CallLogMessage *callLogMessage = [[CallLogMessage alloc]init];
        callLogMessage.calleePhoneNumber = callbackNumber;
        callLogMessage.durationTime = 0;
        callLogMessage.startTime = [self nowTimeString];
        callLogMessage.callLogType = OutgointCall;
        callLogMessage.callId = ctdCallId;
        callLogMessage.isConnected = NO;
        NSMutableArray *array = [[NSMutableArray alloc]init];
        if ([self loadLocalCallHistoryData].count > 0) {
            array = [self loadLocalCallHistoryData];
        }
        [array addObject:callLogMessage];
        [self writeToLocalFileWith:array];
    }
    return TUP_SUCCESS == result ? YES : NO;
}

/**
 * This method is used to close ctd call
 * 结束ctd呼叫
 @return YES is success,NO is fail
 */
-(BOOL)endCTDCall
{
    TUP_RESULT ret = tup_ctd_end_call(_ctdCallId);
    DDLogInfo(@"Call_Log: tup_ctd_end_call = %d, callId:%d",ret,_ctdCallId);
    _ctdCallId = 0;
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to uninit ctd service
 *去初始化ctd业务
 */
-(BOOL)unloadCTD
{
    TUP_RESULT result = tup_ctd_uninit();
    DDLogInfo(@"tup_ctd_uninit result: %d",result);
    return TUP_SUCCESS == result ? YES : NO;
}

/**
 *This method is used to post call event call back to UI according to type
 *将呼叫回调事件分发给页面
 */
-(void)respondsCallDelegateWithType:(TUP_CALL_EVENT_TYPE)type result:(NSDictionary *)resultDictionary
{
    if ([self.delegate respondsToSelector:@selector(callEventCallback:result:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate callEventCallback:type result:resultDictionary];
        });
    }
}

/**
 *This method is used to post ctd event call back to UI according to type
 *将ctd回调事件分发给页面
 */
-(void)respondsCTDDelegateWithType:(TUP_CTD_EVENT_TYPE)type result:(NSDictionary *)resultDictionary
{
    if ([self.delegate respondsToSelector:@selector(ctdCallEventCallback:result:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ctdCallEventCallback:type result:resultDictionary];
        });
    }
}

/**
 * This method is used to stop bfcp capability
 * 暂停bfcp能力
 *@param callid                      Indicates call id
 *                                   呼叫id
 */
- (BOOL)stopTupBfcpCapabilityWithCallId:(unsigned int)callid
{
    CALL_S_MEDIA_DIRECTION_MODE directMode;
    memset(&directMode, 0, sizeof(CALL_S_MEDIA_DIRECTION_MODE));
    directMode.audio_dir = CALL_E_MEDIA_SENDMODE_SENDRECV;
    directMode.video_dir = CALL_E_MEDIA_SENDMODE_SENDRECV;
    directMode.aux_dir = CALL_E_MEDIA_SENDMODE_INACTIVE;
    TUP_RESULT ret_call_capability = tup_call_set_call_capability(callid, CALL_E_PROTOCOL_SIP, CALL_E_LOCAL_CAP_DIRECTION, &directMode);

    TUP_RESULT ret_reinvite = tup_call_reinvite(callid);
    DDLogInfo(@"tup_call_reinvite,result:%d",ret_reinvite);
    return (TUP_SUCCESS == ret_reinvite);
}

-(void)dealloc
{
}

#pragma mark - DBPath Deal

/**
 *This method is used to get call history database path, if not exist create it
 *获取呼叫历史记录本地存储路径
 */
- (NSString *)callHistoryDBPath
{
    NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *plistName = [NSString stringWithFormat:@"%@_allHistory.plist",[ManagerService callService].sipAccount];
    NSString *filePath = [logPath stringByAppendingPathComponent:plistName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        if ([[NSFileManager defaultManager] createFileAtPath:filePath
                                                    contents:nil
                                                  attributes:nil]) {
            return filePath;
        }else {
            DDLogWarn(@"create callHistory.plist failed!");
            return nil;
        }
    }
    return filePath;
}

/**
 *This method is used to write message to local file
 *将信息写到本地文件中
 */
- (BOOL)writeToLocalFileWith:(NSArray *)array {
    NSString *path = [self callHistoryDBPath];
    if (path) {
        return [NSKeyedArchiver archiveRootObject:array toFile:path];
    }
    return NO;
}

/**
 *This method is used to local call history data
 *加载呼叫历史记录
 */
- (NSArray *)loadLocalCallHistoryData {
    NSString *path = [self callHistoryDBPath];
    if (path) {
        NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        return array;
    }
    return nil;
}

/**
 *This method is used to get current time as appointed format
 *获取给定格式的当前时间
 */
- (NSString *)nowTimeString
{
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *nowTimeString = [formatter stringFromDate:date];
    return nowTimeString;
}


@end
