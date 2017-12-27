//
//  ConferenceService.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "ConferenceService.h"
#import "tup_confctrl_interface.h"
#import "tup_confctrl_def.h"
#import "tup_confctrl_interface.h"
#import "tup_conf_basedef.h"
#include <arpa/inet.h>
#import <string.h>
#import "ECConfInfo+StructParase.h"
#import "ConfAttendee+StructParase.h"
#import "ManagerService.h"
#import "ConfData.h"
#import "ECCurrentConfInfo.h"
#import "ConfAttendeeInConf.h"
#import "ConfStatus.h"
#import "Initializer.h"
#import "LoginInfo.h"
#import "LoginServerInfo.h"
#import "DataConfParam.h"
#import "DataConfParam+StructParse.h"
#import "Defines.h"
#import "DataParamSipInfo.h"
#import "AppDelegate.h"

@interface ConferenceService()<TupConfNotifacation>

@property (nonatomic, assign) int confHandle;                     // current confHandle
@property (nonatomic, assign) NSString *dataConfIdWaitConfInfo;   // get current confId
@property (nonatomic, copy)NSString *sipAccount;                  // current sipAccount
@property (nonatomic, copy)NSString *account;                     // current account
@property (nonatomic, strong) NSString *confCtrlUrl;              // recorde dateconf_uri
@property (nonatomic, strong) DataParamSipInfo *dataParam;        // recorde DataParamSipInfo from sipInfo
@property (nonatomic, assign) BOOL isNeedDataConfParam;           // has getDataConfParam or not
@property (nonatomic, strong) NSMutableDictionary *confTokenDic;  // update conference token in SMC
@property (nonatomic, assign) BOOL hasReportMediaxSpeak;          // has reportMediaxSpeak or not in Mediax
@property (nonatomic, assign) BOOL isFirstJumpToRunningView;      // is first jump to runningViewController

@end

@implementation ConferenceService

//creat getter and setter method of delegate
@synthesize delegate;

//creat getter and setter method of isJoinDataConf
@synthesize isJoinDataConf;

//creat getter and setter method of haveJoinAttendeeArray
@synthesize haveJoinAttendeeArray;

//creat getter and setter method of uPortalConfType
@synthesize uPortalConfType;

//creat getter and setter method of selfJoinNumber
@synthesize selfJoinNumber;

//creat getter and setter method of dataConfParamURLDic
@synthesize dataConfParamURLDic;

/**
 *This method is used to get sip account from call service
 *从呼叫业务获取sip账号
 */
-(NSString *)sipAccount
{
    NSString *sipAccount = [ManagerService callService].sipAccount;
    NSArray *array = [sipAccount componentsSeparatedByString:@"@"];
    NSString *shortSipNum = array[0];
    
    return shortSipNum;
}

/**
 *This method is used to get login account from login service
 *从登陆业务获取鉴权登陆账号
 */
- (NSString *)account
{
    LoginInfo *mine = [[ManagerService loginService] obtainCurrentLoginInfo];
    _account = mine.account;
    
    return _account;
}

/**
 *This method is used to init this class， give initial value
 *初始化方法，给变量赋初始值
 */
-(instancetype)init
{
    if (self = [super init])
    {
        [Initializer registerConfCallBack:self]; //注册回调，将回调消息分发代理设置为自己
        self.isJoinDataConf = NO;
        _confHandle = 0;
        self.haveJoinAttendeeArray = [[NSMutableArray alloc] init]; //会议与会者列表
        self.uPortalConfType = CONF_TOPOLOGY_UC;
        _confTokenDic = [[NSMutableDictionary alloc]init];
        _confCtrlUrl = nil;
        _isNeedDataConfParam = YES;
        self.selfJoinNumber = nil;
        self.dataConfParamURLDic = [[NSMutableDictionary alloc]init];
        _hasReportMediaxSpeak = NO;
        _isFirstJumpToRunningView = YES;
    }
    return self;
}

#pragma mark - EC 6.0

/**
 *This method is used to uninit conf
 *会议去初始化
 */
-(void)uninitConfCtrl
{
    tup_confctrl_uninit();
}

/**
 * This method is used to deel conference event callback from service
 * 分发回控业务相关回调
 *@param module TUP_MODULE
 *@param notification Notification
 */
- (void)confModule:(TUP_MODULE)module notication:(Notification *)notification
{
    if (module == CONF_MODULE) {
        [self onRecvTupConferenceNotification:notification];
    }else if (module == CALL_SIP_INFO_MODULE) {
        [self onReceiveTupCallSipInfoNotification:notification];
    }else {
        
    }
}

/**
 *This is a notification from call service, when create a data conf, there will have this notification, it carry some param can use to get big param for data conf
 *创会时如果是数据会议会收到该回调，从中获得小参数去获取数据会议大参数
 */
- (void)onReceiveTupCallSipInfoNotification :(Notification *)notify
{
    DDLogInfo(@"CALL_E_EVT_SERVERCONF_DATACONF_PARAM");
    CALL_S_DATACONF_PARAM *dataConfParam = (CALL_S_DATACONF_PARAM *)notify.data;
    DDLogInfo(@"dataConfParam->acAuthKey: %s,dataConfParam->acCharman: %s,dataConfParam->acCmAddr: %s,dataConfParam->acConfUrl: %s,dataConfParam->acGroupUri: %s,dataConfParam->acPassCode: %s,dataConfParam->acConfctrlRandom: %s,dataConfParam->acDataConfID: %s,dataConfParam->acExtConfType: %s,dataConfParam->ulCallID: %d,dataConfParam->ulConfID: %d",dataConfParam->acAuthKey,dataConfParam->acCharman,dataConfParam->acCmAddr,dataConfParam->acConfUrl,dataConfParam->acGroupUri,dataConfParam->acPassCode,dataConfParam->acConfctrlRandom,dataConfParam->acDataConfID,dataConfParam->acExtConfType,dataConfParam->ulCallID,dataConfParam->ulConfID);
    
    self.dataParam = [DataParamSipInfo paraseFromInfoStruct:dataConfParam];
    
    NSString *confID = [NSString stringWithUTF8String:dataConfParam->acDataConfID];
    DDLogInfo(@"CONFID:%@",confID);
    NSString *confPwd = [NSString stringWithUTF8String:dataConfParam->acPassCode];

    if (!self.selfJoinNumber) {
        self.selfJoinNumber = self.sipAccount;
    }
    
    NSString *confCtrlRandom = [NSString stringWithUTF8String:dataConfParam->acConfctrlRandom];
    //sip info
    if (confID.length > 0) {
        if (_confHandle == 0) {
            BOOL creatHandleResult = [self createConfHandle:confID];
            BOOL subscribeConfResult = [self subscribeConfWithConfId:confID];
            BOOL createConfCtlResult = [self createUportalConfConfCtrlWithConfId:confID pwd:confPwd joinNumber:self.selfJoinNumber confCtrlRandom:confCtrlRandom];
        }
        else {
            if (_isNeedDataConfParam) {
                // 根据不同的解决方案，get data param
                if ([self isUportalMediaXConf]) {
                    [self getConfDataparamsWithType:UportalDataConfParamGetTypeConfIdPassWordRandom
                                        dataConfUrl:_dataParam.dataConfUrl
                                             number:nil
                                                pCd:_dataParam.passCode
                                             confId:_dataParam.dataConfId
                                                pwd:_dataParam.passCode
                                         dataRandom:_dataParam.dataRandom];
                }else if ([self isUportalUSMConf]){
                    [self getConfDataparamsWithType:UportalDataConfParamGetTypePassCode
                                        dataConfUrl:_dataParam.dataConfUrl
                                             number:nil
                                                pCd:_dataParam.passCode
                                             confId:_dataParam.dataConfId
                                                pwd:_dataParam.passCode
                                         dataRandom:_dataParam.dataRandom];
                }else{
                    //empty
                }
            }
            
        }
        
    }
    _dataConfIdWaitConfInfo = confID;
}

/**
 * This method is used to deel conference event notification
 * 处理回控业务回调
 *@param notify
 */
- (void)onRecvTupConferenceNotification:(Notification *)notify
{
    DDLogInfo(@"onReceiveConferenceNotification msgId : %d",notify.msgId);
    switch (notify.msgId)
    {
        case CONFCTRL_E_EVT_END_CONF_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_END_CONF_RESULT");
//            [self restoreConfParamsInitialValue];
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithBool:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_END_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_GET_CONF_INFO_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_GET_CONF_INFO_RESULT result: %d",notify.param1);
            [self handleGetConfInfoResult:notify];
        }
            break;
        case CONFCTRL_E_EVT_GET_CONF_LIST_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_GET_CONF_LIST_RESULT");
            [self handleGetConfListResult:notify];
        }
            break;
        case CONFCTRL_E_EVT_UPORTAL_BOOK_CONF_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_UPORTAL_BOOK_CONF_RESULT result :%d",notify.param1);
            CONFCTRL_S_CONF_LIST_INFO *confListInfo = (CONFCTRL_S_CONF_LIST_INFO *)notify.data;
            BOOL result = notify.param1 == TUP_SUCCESS ? YES : NO;
            ECCurrentConfInfo *currentConfInfo = nil;
            if (confListInfo != NULL)
            {
                currentConfInfo = [[ECCurrentConfInfo alloc] init];
                CONFCTRL_S_CONF_LIST_INFO confInfo = (CONFCTRL_S_CONF_LIST_INFO)confListInfo[0];
                ECConfInfo *ecConfInfo = [ECConfInfo returnECConfInfoWith:confListInfo[0]];
                currentConfInfo.confDetailInfo = ecConfInfo;
                _dataConfIdWaitConfInfo = currentConfInfo.confDetailInfo.conf_id;
                if (strlen(confInfo.token)) {
                    NSString *smcToken = [NSString stringWithUTF8String:confInfo.token];
                    [self updateSMCConfToken:smcToken inConf:currentConfInfo.confDetailInfo.conf_id];
                }
                
            }
            
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithBool:result],
                                         ECCONF_BOOK_CONF_INFO_KEY : currentConfInfo
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_CREATE_RESULT result:resultInfo];
            
            //In CONF_TOPOLOGY_UC ,conf_state from server is CONF_E_CONF_STATE_SCHEDULE .This need evade ,subscribe conference no need to do join conference action immediately;
            //            if (ecConfInfo.conf_state != CONF_E_CONF_STATE_GOING) {
            //                return;
            //            }
            //begin time - now time ,if the result > 0 ,wo think the conference is subscribe conference ,to evade the problem.
            NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy/MM/dd  HH:mm"];
            NSDate *startTime = [formatter dateFromString:currentConfInfo.confDetailInfo.start_time];
            NSInteger confInfoDuration = (NSInteger)[startTime timeIntervalSinceDate:[NSDate date]];
            if (confInfoDuration > 0 ) {
                return;
            }
            
            if (!self.selfJoinNumber) {
                self.selfJoinNumber = self.sipAccount;
            }
            // todo join conference action
            BOOL creatHandleResult = [self createConfHandle:currentConfInfo.confDetailInfo.conf_id];
            BOOL subscribeConfResult = [self subscribeConfWithConfId:currentConfInfo.confDetailInfo.conf_id];
            BOOL createConfCtlResult = [self createUportalConfConfCtrlWithConfId:currentConfInfo.confDetailInfo.conf_id pwd:currentConfInfo.confDetailInfo.chairman_pwd != nil ? currentConfInfo.confDetailInfo.chairman_pwd :currentConfInfo.confDetailInfo.general_pwd joinNumber:self.selfJoinNumber confCtrlRandom:nil];
            
        }
            break;
        case CONFCTRL_E_EVT_SUBSCRIBE_CONF_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_SUBSCRIBE_CONF_RESULT handle: %d, result:%d",notify.param1,notify.param2);
            
        }
            break;
        case CONFCTRL_E_EVT_ATTENDEE_LIST_UPDATE_IND:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_ATTENDEE_LIST_UPDATE_IND");
            CONFCTRL_S_CONF_STATUS *confStatus = (CONFCTRL_S_CONF_STATUS *)notify.data;
            DDLogInfo(@"confStatus->media_type: %x ",confStatus->media_type);
            NSString *mediaType = [NSString stringWithFormat:@"%x",confStatus->media_type];
            NSString *confId = [NSString stringWithUTF8String:confStatus->conf_id];
            DDLogInfo(@"mediaType: %d, _isJoinDataConf: %d",[mediaType intValue],self.isJoinDataConf);
            
            // if media type has data conference ,obtain conference detail info than get data conference params in its callBack.
            if (([mediaType intValue] == 11 || [mediaType intValue] == 13) && _confHandle >= 0)
            {
                if (!self.isJoinDataConf)
                {
                    DDLogInfo(@"mediaType-----: %d, _isJoinDataConf----: %d",[mediaType intValue],self.isJoinDataConf);
                    self.isJoinDataConf = YES;
                    _dataConfIdWaitConfInfo = confId;
                    [self obtainConferenceDetailInfoWithConfId:confId Page:1 pageSize:10];
                }
            }else{
                self.isJoinDataConf = NO;
            }
            
            [self handleAttendeeUpdateNotify:notify];
            
        }
            break;
        case CONFCTRL_E_EVT_ADD_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_ADD_ATTENDEE_RESULT result is : %d",notify.param2);
            BOOL result = TUP_SUCCESS == notify.param2 ? YES : NO;
            DDLogInfo(@"result is :%d",result);
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithBool:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_ADD_ATTENDEE_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_MUTE_CONF_RESULT:
        {
            TUP_BOOL *resultBool = (TUP_BOOL *)notify.data;
            DDLogInfo(@"CONFCTRL_E_EVT_MUTE_CONF_RESULT result : %d, mute: %d",notify.param2,resultBool[0]);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_MUTE_KEY: [NSNumber numberWithBool:resultBool[0]],
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_MUTE_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_DEL_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_DEL_ATTENDEE_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_DELETE_ATTENDEE_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_HANGUP_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_HANGUP_ATTENDEE_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_HANGUP_ATTENDEE_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_FLOOR_ATTENDEE_IND:
        {
            //Speaker report in this place
            DDLogInfo(@"CONFCTRL_E_EVT_FLOOR_ATTENDEE_IND handle is : %d",notify.param1);
            CONFCTRL_S_FLOOR_ATTENDEE_INFO *floorAttendee = (CONFCTRL_S_FLOOR_ATTENDEE_INFO *)notify.data;
            CONFCTRL_S_SPEAKER *speakers = floorAttendee->speakers;
            NSMutableArray *tempArray = [[NSMutableArray alloc] init];
            for (int i =0; i< floorAttendee->num_of_speaker; i++)
            {
                DDLogInfo(@"speakers[i].number :%s,speakers[i].is_speaking :%d",speakers[i].number,speakers[i].is_speaking);
                ConfCtrlSpeaker *speaker = [[ConfCtrlSpeaker alloc] init];
                speaker.number = [NSString stringWithUTF8String:speakers[i].number];
                speaker.is_speaking = speakers[i].is_speaking;
                speaker.speaking_volume = speakers[i].speaking_volume;
                [tempArray addObject:speaker];
            }
            
            NSDictionary *resultInfo = @{
                                         ECCONF_SPEAKERLIST_KEY : [NSArray arrayWithArray:tempArray]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_SPEAKER_LIST result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_HANDUP_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_HANDUP_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_RAISEHAND_ATTENDEE_RESULT result:resultInfo];
            
        }
            break;
        case CONFCTRL_E_EVT_MUTE_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_MUTE_ATTENDEE_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_MUTE_ATTENDEE_RESULT result:resultInfo];
            
        }
            break;
        case CONFCTRL_E_EVT_REALSE_CHAIRMAN_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_REALSE_CHAIRMAN_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_RELEASE_CHAIRMAN_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_REQ_CHAIRMAN_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_REQ_CHAIRMAN_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_REQUEST_CHAIRMAN_RESULT result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_LOCK_CONF_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_LOCK_CONF_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_LOCK_STATUS_CHANGE result:resultInfo];
        }
            break;
        case CONFCTRL_E_EVT_CALL_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_CALL_ATTENDEE_RESULT result is : %d",notify.param2);
        }
            break;
        case CONFCTRL_E_EVT_REQUEST_CONF_RIGHT_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_REQUEST_CONF_RIGHT_RESULT result is : %d",notify.param2);
            CONFCTRL_S_REQUEST_CONFCTRL_RIGHT_RESULT *data = (CONFCTRL_S_REQUEST_CONFCTRL_RIGHT_RESULT *)notify.data;
            if (data != NULL) {
                if (strlen(data->dateconf_uri) > 0) {
                    _confCtrlUrl = [NSString stringWithUTF8String:data->dateconf_uri];
                }
            }
            
            // get data params
            if (_dataParam) {
                if ([self isUportalMediaXConf]) {
                    [self getConfDataparamsWithType:UportalDataConfParamGetTypeConfIdPassWordRandom
                                        dataConfUrl:_dataParam.dataConfUrl
                                             number:nil
                                                pCd:_dataParam.passCode
                                             confId:_dataParam.dataConfId
                                                pwd:_dataParam.passCode
                                         dataRandom:_dataParam.dataRandom];
                }else if ([self isUportalUSMConf]){
                    [self getConfDataparamsWithType:UportalDataConfParamGetTypePassCode
                                        dataConfUrl:_dataParam.dataConfUrl
                                             number:nil
                                                pCd:_dataParam.passCode
                                             confId:_dataParam.dataConfId
                                                pwd:_dataParam.passCode
                                         dataRandom:_dataParam.dataRandom];
                }else{
                    //empty
                }
                self.dataParam = nil;
            }
        }
        case CONFCTRL_E_EVT_SET_CONF_MODE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_SET_CONF_MODE_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:EC_SET_CONF_MODE_NOTIFY
                                                                    object:nil
                                                                  userInfo:@{ECCONF_RESULT_KEY : [NSNumber numberWithBool:result]}];
            });
        }
            break;
        case CONFCTRL_E_EVT_BROADCAST_ATTENDEE_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_BROADCAST_ATTENDEE_RESULT result: %d", notify.param2);
        }
            break;
        default:
            break;
    }
    if (notify.msgId == CONFCTRL_E_EVT_UPGRADE_CONF_RESULT || notify.msgId == CONFCTRL_E_EVT_DATACONF_PARAMS_RESULT)
    {
        [self handleUpgradeToDataConferenceNotify:notify];
    }
}

/**
 *This method is used to handle upgrade to data conference notification
 *升级数据会议回调处理
 */
-(void)handleUpgradeToDataConferenceNotify:(Notification *)notify
{
    switch (notify.msgId)
    {
        case CONFCTRL_E_EVT_UPGRADE_CONF_RESULT:
        {
            DDLogInfo(@"CONFCTRL_E_EVT_UPGRADE_CONF_RESULT result is : %d",notify.param2);
            BOOL result = notify.param2 == TUP_SUCCESS ? YES : NO;
            NSDictionary *resultInfo = @{
                                         ECCONF_RESULT_KEY : [NSNumber numberWithInt:result]
                                         };
            [self respondsECConferenceDelegateWithType:CONF_E_UPGRADE_RESULT result:resultInfo];
            if (!self.isJoinDataConf)
            {
                self.isJoinDataConf = YES;
            }
            
        }
            break;
        case CONFCTRL_E_EVT_DATACONF_PARAMS_RESULT:  //if get data param success, this notify will carry param info
        {
            DDLogInfo(@"CONFCTRL_E_EVT_DATACONF_PARAMS_RESULT result is : %d",notify.param1);
            CONFCTRL_S_DATACONF_PARAMS *dataConfParams = (CONFCTRL_S_DATACONF_PARAMS *)notify.data;
            if (!dataConfParams || notify.param1 != TUP_SUCCESS) {
                DDLogInfo(@"upgrade to data conference failed");
                return;
            }
            
            _isNeedDataConfParam = NO;
            DataConfParam *tupDataConfParams = [DataConfParam transformFromTupStruct:dataConfParams];
            // join data conference
            [[ManagerService dataConfService] joinDataConfWithParams:tupDataConfParams];
        }
            break;
        default:
            break;
    }
}

/**
 *This method is used to handle conf info update notification
 *处理会议信息改变上报的回调
 */
-(void)handleAttendeeUpdateNotify:(Notification *)notify
{
    CONFCTRL_S_CONF_STATUS *confStatusStruct = (CONFCTRL_S_CONF_STATUS *)notify.data;
    ConfStatus *confStatus  = [[ConfStatus alloc] init];
    confStatus.num_of_participant = confStatusStruct->num_of_participant;
    confStatus.size = confStatusStruct->size;
    NSString *mediaType = [NSString stringWithFormat:@"%x",confStatusStruct->media_type];
    DDLogInfo(@"mediaType :%@",mediaType);
    confStatus.media_type = [self transformByUportalMediaType:confStatusStruct->media_type];
    DDLogInfo(@"confStatus mediaType :%d",confStatus.media_type);
    confStatus.conf_state = (EC_E_CONF_STATE)confStatusStruct->conf_state;
    confStatus.conf_id = [NSString stringWithUTF8String:confStatusStruct->conf_id];
    confStatus.createor = [NSString stringWithUTF8String:confStatusStruct->createor];
    confStatus.subject = [NSString stringWithUTF8String:confStatusStruct->subject];
    confStatus.record_status = confStatusStruct->record_status;
    confStatus.lock_state = confStatusStruct->lock_state;
    confStatus.is_all_mute = confStatusStruct->is_all_mute;
    CONFCTRL_S_PARTICIPANT *participants = confStatusStruct->participants;
    
    // update conference attendee status
    
    // attendee in haveJoinAttendeeArray
    [self.haveJoinAttendeeArray enumerateObjectsUsingBlock:^(ConfAttendeeInConf* attendee, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL isAttendeeInConf = NO;;
        for (int i = 0; i<confStatusStruct->num_of_participant; i++)
        {
            CONFCTRL_S_PARTICIPANT participant = participants[i];
            if ([attendee.number isEqualToString:[NSString stringWithUTF8String:participant.number]]) {
                attendee.name = [NSString stringWithUTF8String:participant.name];
                attendee.number = [NSString stringWithUTF8String:participant.number];
                attendee.participant_id = [NSString stringWithUTF8String:participant.participant_id];
                attendee.is_deaf = (participant.is_deaf == TUP_TRUE);
                attendee.is_mute = (participant.is_mute == TUP_TRUE);
                attendee.hand_state = (participant.hand_state == TUP_TRUE);
                attendee.role = (CONFCTRL_CONF_ROLE)participant.role;
                attendee.state = (ATTENDEE_STATUS_TYPE)participant.state;
                attendee.type = (EC_CONF_MEDIATYPE)participant.media_type;
                isAttendeeInConf = YES;
                break;
            }
        }
        //if attendee is not in participants ,update to leave conf.
        if (!isAttendeeInConf) {
            attendee.state = ATTENDEE_STATUS_LEAVED;
            attendee.role = CONF_ROLE_ATTENDEE;
            attendee.hand_state = NO;
            attendee.is_mute = NO;
        }
    }];
    BOOL isSelfLeaveConf = YES;
    BOOL isNeedRemoveCallView = NO;
    // new attendee
    for (int i = 0; i<confStatusStruct->num_of_participant; i++)
    {
        __block BOOL isExist = NO;
        CONFCTRL_S_PARTICIPANT participant = participants[i];
        [self.haveJoinAttendeeArray enumerateObjectsUsingBlock:^(ConfAttendeeInConf* attendee, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([attendee.number isEqualToString:[NSString stringWithUTF8String:participant.number]]) {
                isExist = YES;
                *stop = YES;
            }
        }];
        
        if (!isExist) {
            ConfAttendeeInConf *addAttendee = [[ConfAttendeeInConf alloc] init];
            addAttendee.name = [NSString stringWithUTF8String:participant.name];
            addAttendee.number = [NSString stringWithUTF8String:participant.number];
            addAttendee.participant_id = [NSString stringWithUTF8String:participant.participant_id];
            addAttendee.is_deaf = (participant.is_deaf == TUP_TRUE);
            addAttendee.is_mute = (participant.is_mute == TUP_TRUE);
            addAttendee.hand_state = (participant.hand_state == TUP_TRUE);
            addAttendee.role = (CONFCTRL_CONF_ROLE)participant.role;
            addAttendee.state = (ATTENDEE_STATUS_TYPE)participant.state;
            addAttendee.type = (EC_CONF_MEDIATYPE)participant.media_type;
            
            [self.haveJoinAttendeeArray addObject:addAttendee];
        }
        
        if ([self.selfJoinNumber isEqualToString:[NSString stringWithUTF8String:participant.number]]) {
            // if conference'uPortalConfType is CONF_TOPOLOGY_MEDIAX and self role is CONFCTRL_E_CONF_ROLE_CHAIRMAN ,need to open report function ,only once time;
            if (participant.role == CONFCTRL_E_CONF_ROLE_CHAIRMAN && [self isUportalMediaXConf] && !_hasReportMediaxSpeak) {
                _hasReportMediaxSpeak = YES;
                [self configMediaxSpeakReport];
            }
            DDLogInfo(@"isSelfLeaveConf,participant.state:%d,participant.number:%d",participant.state,participant.number);
            if (participant.state != ATTENDEE_STATUS_NO_EXIST && participant.state != ATTENDEE_STATUS_LEAVED) {
                isSelfLeaveConf = NO;
                if (participant.state == ATTENDEE_STATUS_IN_CONF) {
                    // 如果自己已经在会议中，且呼叫界面还在，则移除呼叫界面（规避拨号入会，呼叫界面未移除问题场景）
                    isNeedRemoveCallView = YES;
                }
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        // go conference
        DDLogInfo(@"goConferenceRunView,confStatusStruct->conf_state :%d, isSelfLeaveConf:%d", confStatusStruct->conf_state, isSelfLeaveConf);
        if (!isSelfLeaveConf && confStatus.conf_state == CONF_STATE_GOING) {
            [self goConferenceRunView:confStatus needRemoveCallView:isNeedRemoveCallView];
        }
        
        confStatus.participants = self.haveJoinAttendeeArray;
        NSDictionary *resultInfo = @{
                                     ECCONF_ATTENDEE_UPDATE_KEY: confStatus
                                     };
        [self respondsECConferenceDelegateWithType:CONF_E_ATTENDEE_UPDATE_INFO result:resultInfo];
    });
}

/**
 *This method is used to get EC_CONF_MEDIATYPE enum value by param mediaType
 *根据传入的会议类型int值获取会议类型枚举值
 */
- (EC_CONF_MEDIATYPE)transformByUportalMediaType:(TUP_UINT32)mediaType {
    EC_CONF_MEDIATYPE type = CONF_MEDIATYPE_VOICE;
    switch (mediaType) {
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE:
            type = CONF_MEDIATYPE_VOICE;
            break;
            
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VIDEO:
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_HDVIDEO:
            type = CONF_MEDIATYPE_VIDEO;
            break;
            
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA:
            type = CONF_MEDIATYPE_DATA;
            break;
            
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VIDEO | CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA:
        case CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_HDVIDEO | CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA:
            type = CONF_MEDIATYPE_VIDEO_DATA;
            break;
            
        default:
            break;
    }
    return type;
}

/**
 *This method is used to handle get conf info result notification
 *处理获取会议信息结果回调
 */
-(void)handleGetConfInfoResult:(Notification *)notify
{
    DDLogInfo(@"CONFCTRL_E_EVT_GET_CONF_INFO_RESULT");
    CONFCTRL_S_GET_CONF_INFO_RESULT *confInfo = (CONFCTRL_S_GET_CONF_INFO_RESULT*)notify.data;

    if (notify.param1 != TUP_SUCCESS)
    {
        DDLogInfo(@"Get Conf Info Result if failed");
        NSDictionary *resultInfo = @{
                                     ECCONF_RESULT_KEY : [NSNumber numberWithBool:NO]
                                     };
        [self respondsECConferenceDelegateWithType:CONF_E_CURRENTCONF_DETAIL result:resultInfo];
        return;
    }
    if (!confInfo)
    {
        DDLogInfo(@"confInfo is nil");
        return;
    }
    CONFCTRL_S_CONF_LIST_INFO confListInfo = confInfo->conf_list_info;
    
    DDLogInfo(@"conf_id : %s, conf_subject : %s, media_type: %d,size:%d,scheduser_name:%s,scheduser_number:%s, start_time:%s, end_time:%s, conf_state: %d, confListInfo.chairman_pwd : %s",confListInfo.conf_id,confListInfo.conf_subject,confListInfo.media_type,confListInfo.size,confListInfo.scheduser_name,confListInfo.scheduser_number,confListInfo.start_time,confListInfo.end_time,confListInfo.conf_state,confListInfo.chairman_pwd);
    
    DDLogInfo(@"num_of_addendee :%d",confInfo->num_of_addendee);
    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    CONFCTRL_S_ATTENDEE* attendee = confInfo->attendee;
    for (int i = 0; i< confInfo->num_of_addendee; i++)
    {
        DDLogInfo(@"attendee->name :%s,attendee->number: %s",attendee[i].name,attendee[i].number);
        ConfAttendee *confAttendee = [ConfAttendee returnConfAttendeeWith:attendee[i]];
        [tempArray addObject:confAttendee];
    }
    
    ECCurrentConfInfo *currentConfInfo = [[ECCurrentConfInfo alloc] init];
    ECConfInfo *ecConfInfo = [ECConfInfo returnECConfInfoWith:confListInfo];
    currentConfInfo.confDetailInfo = ecConfInfo;
    currentConfInfo.attendeeArray = [NSArray arrayWithArray:tempArray];
    NSString *confID = ecConfInfo.conf_id;
    
    if (strlen(confListInfo.token)) {
        NSString *smcToken = [NSString stringWithUTF8String:confListInfo.token];
        [self updateSMCConfToken:smcToken inConf:confID];
    }
    // selfJoinNumber is not sipAccount,get confDataParams from here.
    BOOL needGetParam = NO;
    if (self.selfJoinNumber && self.selfJoinNumber.length > 0) {
        if (![self.selfJoinNumber isEqualToString:self.sipAccount]) {
            needGetParam = YES;
        }
    }
    
    //judge whether is data conf,if it's data conf, invoke interface to get big param
    if (self.isJoinDataConf && [confID isEqualToString:_dataConfIdWaitConfInfo] && _isNeedDataConfParam && needGetParam)
    {
        NSString *pwd = [self isUportalSMCConf] ? currentConfInfo.confDetailInfo.general_pwd : currentConfInfo.confDetailInfo.chairman_pwd;
        if (!self.selfJoinNumber) {
            self.selfJoinNumber = self.sipAccount;
        }
        DDLogInfo(@"getdataConf,handleGetConfInfoResult");
        if ([self isUportalMediaXConf]) {
            [self getConfDataparamsWithType:UportalDataConfParamGetTypeConfIdPassWord dataConfUrl:nil number:nil pCd:nil confId:confID pwd:pwd dataRandom:nil];
        }else if ([self isUportalSMCConf]){
            [self getConfDataparamsWithType:UportalDataConfParamGetTypePassCode dataConfUrl:nil number:self.selfJoinNumber pCd:pwd confId:confID pwd:nil dataRandom:nil];
        }else{
            [self getConfDataparamsWithType:UportalDataConfParamGetTypePassCode dataConfUrl:nil number:self.selfJoinNumber pCd:pwd confId:confID pwd:nil dataRandom:nil];
        }
        
        _dataConfIdWaitConfInfo = nil;
    }
    NSDictionary *resultInfo = @{
                                 ECCONF_CURRENTCONF_DETAIL_KEY : currentConfInfo,
                                 ECCONF_RESULT_KEY : [NSNumber numberWithBool:YES]
                                 };
    //post current conf info detail to UI
    [self respondsECConferenceDelegateWithType:CONF_E_CURRENTCONF_DETAIL result:resultInfo];
}

/**
 *This method is used to handle get conf list result notification, if success refresh UI page
 *处理获取会议列表回调，如果成功，刷新UI页面
 */
-(void)handleGetConfListResult:(Notification *)notify
{
    DDLogInfo(@"result: %d",notify.param1);
    CONFCTRL_S_GET_CONF_LIST_RESULT *confListInfoResult = (CONFCTRL_S_GET_CONF_LIST_RESULT*)notify.data;
    DDLogInfo(@"confListInfoResult->current_count----- :%d total_count-- :%d",confListInfoResult->current_count,confListInfoResult->total_count);
    CONFCTRL_S_CONF_LIST_INFO *confList = confListInfoResult->conf_list_info;
    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    for (int i = 0; i< confListInfoResult->current_count; i++)
    {
        ECConfInfo *confInfo = [ECConfInfo returnECConfInfoWith:confList[i]];
        if (confInfo.conf_state != CONF_E_CONF_STATE_DESTROYED)
        {
            [tempArray addObject:confInfo];
        }
    }
    NSDictionary *resultInfo = @{
                                 ECCONF_LIST_KEY : tempArray
                                 };
    [self respondsECConferenceDelegateWithType:CONF_E_GET_CONFLIST result:resultInfo];
}

/**
 *This method is used to switch to the conf running page
 *切换到正在召开的会议页面
 */
-(void)goConferenceRunView:(ConfStatus *)confStatus needRemoveCallView:(BOOL)needRemoveCallWindow
{
    if (needRemoveCallWindow) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TUP_CALL_REMOVE_CALL_VIEW_NOTIFY object:nil];
    }
    if(_isFirstJumpToRunningView){
        _isFirstJumpToRunningView = NO;
        [AppDelegate goConference:confStatus];
    }
}

#pragma mark  public
/**
 * This method is used to set conference server params
 * 设置会议服务器信息
 *@param address server address
 *@param port server port
 *@param token get token from uportal login
 */
-(void)configConferenceCtrlWithServerAddress:(NSString *)address port:(int)port token:(NSString *)token
{
    if (0 == address.length || 0 == token.length)
    {
        return;
    }
    int ret = tup_confctrl_set_conf_env_type(CONFCTRL_E_CONF_ENV_CONVERGENT_MEETING);
    DDLogInfo(@"tup_confctrl_set_conf_env_type result: %d",ret);
    CONFCTRL_S_SERVER_PARA *serverParam = (CONFCTRL_S_SERVER_PARA *)malloc(sizeof(CONFCTRL_S_SERVER_PARA));
    memset_s(serverParam, sizeof(CONFCTRL_S_SERVER_PARA), 0, sizeof(CONFCTRL_S_SERVER_PARA));
    strcpy(serverParam->server_addr, [address UTF8String]);
    serverParam->port = (TUP_INT32)port;
    int result = tup_confctrl_set_server_params(serverParam);
    DDLogInfo(@"tup_confctrl_set_server_params result : %d",result);
    free(serverParam);
    [self configToken:token];
}

/**
 * This method is used to set token
 * 设置鉴权token
 *@param token get token from uportal login
 *@return YES or NO
 */
-(BOOL)configToken:(NSString *)token
{
    int setTokenResult = tup_confctrl_set_token([token UTF8String]);
    DDLogInfo(@"tup_confctrl_set_token result : %d, token : %@",setTokenResult,token);
    return setTokenResult == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to create conference
 * 创会
 *@param attendeeArray one or more attendees
 *@param mediaType EC_CONF_MEDIATYPE value
 *@return YES or NO
 */
-(BOOL)tupConfctrlBookConf:(NSArray *)attendeeArray mediaType:(EC_CONF_MEDIATYPE)mediaType startTime:(NSDate *)startTime confLen:(int)confLen subject:(NSString *)subject
{
    CONFCTRL_S_BOOK_CONF_INFO_UPORTAL *bookConfInfoUportal = (CONFCTRL_S_BOOK_CONF_INFO_UPORTAL *)malloc(sizeof(CONFCTRL_S_BOOK_CONF_INFO_UPORTAL));
    memset_s(bookConfInfoUportal, sizeof(CONFCTRL_S_BOOK_CONF_INFO_UPORTAL), 0, sizeof(CONFCTRL_S_BOOK_CONF_INFO_UPORTAL));
    strcpy(bookConfInfoUportal->subject, [subject UTF8String]);
    bookConfInfoUportal->conf_type = CONFCTRL_E_CONF_TYPE_NORMAL;
    bookConfInfoUportal->conf_len = 30;
    
    bookConfInfoUportal->media_type = [self uPortalConfMediaTypeByESpaceMediaType:mediaType];

    if (attendeeArray.count == 0)
    {
        bookConfInfoUportal->size = 5;
        bookConfInfoUportal->num_of_attendee = 0;
        bookConfInfoUportal->attendee = NULL;
    }
    else
    {
        bookConfInfoUportal->size = (TUP_UINT32)attendeeArray.count * 2;
        bookConfInfoUportal->num_of_attendee = (TUP_UINT32)attendeeArray.count;
        bookConfInfoUportal->attendee = [self returnAttendeeWithArray:attendeeArray withMediaType:mediaType];
    }
    if (startTime != nil)
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        NSString *startTimeStr = [dateFormatter stringFromDate:startTime];
        NSString *utcStr = [self getUTCFormateLocalDate:startTimeStr];
        DDLogInfo(@"start time : %@, utc time: %@",startTimeStr,utcStr);
        strcpy(bookConfInfoUportal->start_time, [utcStr UTF8String]);
        
        bookConfInfoUportal->conf_len = confLen;
        
    }
    
    TUP_RESULT ret = tup_confctrl_book_conf(bookConfInfoUportal);
    DDLogInfo(@"tup_confctrl_book_conf result : %d",ret);
    free(bookConfInfoUportal);
    return ret == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to transform local date to UTC date
 *将本地时间转换为UTC时间
 */
-(NSString *)getUTCFormateLocalDate:(NSString *)localDate
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //input
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSDate *dateFormatted = [dateFormatter dateFromString:localDate];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    //output
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSString *dateString = [dateFormatter stringFromDate:dateFormatted];
    return dateString;
}

/**
 * This method is used to create conference
 * 创会
 *@param attendeeArray one or more attendees
 *@param mediaType EC_CONF_MEDIATYPE value
 *@return YES or NO
 */
-(BOOL)createConferenceWithAttendee:(NSArray *)attendeeArray mediaType:(EC_CONF_MEDIATYPE)mediaType subject:(NSString *)subject startTime:(NSDate *)startTime confLen:(int)confLen
{
    return [self tupConfctrlBookConf:attendeeArray mediaType:mediaType startTime:startTime confLen:confLen subject:subject];
}

/**
 *This method is used to give value to struct CONFCTRL_S_ATTENDEE by memberArray
 *用memberArray给结构体CONFCTRL_S_ATTENDEE赋值，为创会时的入参
 */
-(CONFCTRL_S_ATTENDEE *)returnAttendeeWithArray:(NSArray *)memberArray withMediaType:(EC_CONF_MEDIATYPE)mediaType
{
    
    CONFCTRL_S_ATTENDEE *attendee = (CONFCTRL_S_ATTENDEE *)malloc(memberArray.count*sizeof(CONFCTRL_S_ATTENDEE));
    memset_s(attendee, memberArray.count *sizeof(CONFCTRL_S_ATTENDEE), 0, memberArray.count *sizeof(CONFCTRL_S_ATTENDEE));
    for (int i = 0; i<memberArray.count; i++)
    {
        BOOL isNeedInviteSelf = NO;
        ConfAttendee *tempAttendee = memberArray[i];
        strcpy(attendee[i].name, [tempAttendee.name UTF8String]);
        strcpy(attendee[i].number, [tempAttendee.number UTF8String]);
        attendee[i].type = CONFCTRL_E_ATTENDEE_TYPE_NORMAL;
        
        attendee[i].role = (CONFCTRL_E_CONF_ROLE)tempAttendee.role;
        // create conference ,self role is CONF_ROLE_CHAIRMAN.
        if (tempAttendee.role == CONF_ROLE_CHAIRMAN) {
            self.selfJoinNumber = tempAttendee.number;
        }
        //auto invite attendee
        attendee[i].is_auto_invite = YES;
        DDLogInfo(@"attendee is : %s, role : %d, is_auto_invite:%d",attendee[i].number,attendee[i].role,attendee[i].is_auto_invite);
    }
    return attendee;
}


/**
 * This method is used to get conference detail info
 * 获取会议详细信息
 *@param confId conference id
 *@param pageIndex pageIndex default 1
 *@param pageSize pageSize default 10
 *@return YES or NO
 */
-(BOOL)obtainConferenceDetailInfoWithConfId:(NSString *)confId Page:(int)pageIndex pageSize:(int)pageSize
{
    if (confId.length == 0)
    {
        DDLogInfo(@"current confId is nil");
        return NO;
    }
    CONFCTRL_S_GET_CONF_INFO confInfo;
    memset(&confInfo, 0, sizeof(CONFCTRL_S_GET_CONF_INFO));
    strcpy(confInfo.conf_id, [confId UTF8String]);
    confInfo.page_index = pageIndex;
    confInfo.page_size = pageSize;
    int getConfInfoRestult = tup_confctrl_get_conf_info(&confInfo);
    DDLogInfo(@"tup_confctrl_get_conf_info result: %d",getConfInfoRestult);
    return getConfInfoRestult == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to get conference list
 * 获取会议列表
 *@param pageIndex pageIndex default 1
 *@param pageSize pageSize default 10
 *@return YES or NO
 */
-(BOOL)obtainConferenceListWithPageIndex:(int)pageIndex pageSize:(int)pageSize
{
    CONFCTRL_S_GET_CONF_LIST conflistInfo;
    memset(&conflistInfo, 0, sizeof(CONFCTRL_S_GET_CONF_LIST));
    conflistInfo.conf_right = CONFCTRL_E_CONFRIGHT_CREATE_JOIN;
    conflistInfo.page_size = pageSize;
    conflistInfo.page_index = pageIndex;
    conflistInfo.include_end = TUP_FALSE;
    int result = tup_confctrl_get_conf_list(&conflistInfo);
    DDLogInfo(@"tup_confctrl_get_conf_list result: %d",result);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to join conference
 * 加入会议
 *@param confInfo conference
 *@param attendeeArray attendees
 *@return YES or NO
 */
-(BOOL)joinConference:(ECConfInfo *)confInfo attendee:(NSArray *)attendeeArray
{
    if (attendeeArray.count == 0 || confInfo == nil) {
        return NO;
    }
    
    _confHandle = 0;
    ConfAttendee *tempAttendee = attendeeArray[0];
    
    // todo join conference action
    BOOL createConfhandleResult = [self createConfHandle:confInfo.conf_id];
    BOOL subscribeConfResult = [self subscribeConfWithConfId:confInfo.conf_id];
    BOOL createConfCtlResult = [self createUportalConfConfCtrlWithConfId:confInfo.conf_id pwd:tempAttendee.role == CONF_ROLE_CHAIRMAN ? confInfo.chairman_pwd : confInfo.general_pwd joinNumber:tempAttendee.number confCtrlRandom:nil];
    if (!createConfhandleResult || !subscribeConfResult || !createConfCtlResult) {
        return NO;
    }
    BOOL result = [self confCtrlAddAttendeeToConfercene:attendeeArray];
    if (result) {
        self.selfJoinNumber = tempAttendee.number;
    }
    return result;
}

/**
 * This method is used to access conference
 * 接入预约会议
 *@param confDetailInfo ECConfInfo value
 *@return YES or NO
 */
-(unsigned int)accessReservedConference:(ECConfInfo *)confDetailInfo
{
    int result = 0;
    if ([self isUportalUSMConf]) {
        TUP_CALL_TYPE callType = CALL_AUDIO;
        if (confDetailInfo.media_type == CONF_MEDIATYPE_VOICE)
        {
            callType = CALL_AUDIO;
        }
        if (confDetailInfo.media_type == CONF_MEDIATYPE_VIDEO || confDetailInfo.media_type == CONF_MEDIATYPE_VIDEO_DATA)
        {
            callType = CALL_VIDEO;
        }
        NSString *accessNum = [NSString stringWithFormat:@"%@*%@#",confDetailInfo.access_number,confDetailInfo.general_pwd];
        result =[[ManagerService callService] startCallWithNumber:accessNum type:callType];
    }else{
        result = [[ManagerService callService] startECAccessCallWithConfid:confDetailInfo.conf_id AccessNum:confDetailInfo.access_number andPsw:confDetailInfo.general_pwd];
    }
    return result;
}

/**
 * This method is used to add attendee to conference
 * 添加与会者到会议中
 @param attendeeArray attendees
 @return YES or NO
 */
-(BOOL)confCtrlAddAttendeeToConfercene:(NSArray *)attendeeArray
{
    if (0 == attendeeArray.count)
    {
        return NO;
    }
    CONFCTRL_S_ADD_ATTENDEES_INFO *attendeeInfo = (CONFCTRL_S_ADD_ATTENDEES_INFO *)malloc( sizeof(CONFCTRL_S_ADD_ATTENDEES_INFO));
    memset_s(attendeeInfo, sizeof(CONFCTRL_S_ADD_ATTENDEES_INFO), 0, sizeof(CONFCTRL_S_ADD_ATTENDEES_INFO));
    attendeeInfo->num_of_attendee = (TUP_UINT32)attendeeArray.count;
    CONFCTRL_S_ATTENDEE *attendee = (CONFCTRL_S_ATTENDEE *)malloc(attendeeArray.count*sizeof(CONFCTRL_S_ATTENDEE));
    memset_s(attendee, attendeeArray.count *sizeof(CONFCTRL_S_ATTENDEE), 0, attendeeArray.count *sizeof(CONFCTRL_S_ATTENDEE));

    for (int i=0; i<attendeeArray.count; i++)
    {
        ConfAttendee *cAttendee = attendeeArray[i];
        strcpy(attendee[i].name, [cAttendee.name UTF8String]);
        strcpy(attendee[i].number, [cAttendee.number UTF8String]);
        if (cAttendee.email.length != 0)
        {
            strcpy(attendee[i].email, [cAttendee.email UTF8String]);
        }
        if (cAttendee.sms.length != 0)
        {
            strcpy(attendee[i].sms, [cAttendee.sms UTF8String]);
        }
        attendee[i].is_mute = cAttendee.is_mute;
        attendee[i].type = (CONFCTRL_E_ATTENDEE_TYPE)cAttendee.type;
        attendee[i].role = (CONFCTRL_E_CONF_ROLE)cAttendee.role;
        DDLogInfo(@"cAttendee number is %@,cAttendee role is %d,attendee[i].role is : %d",cAttendee.number,cAttendee.role,attendee[i].role);
    }
    attendeeInfo->attendee = attendee;
    int result = tup_confctrl_add_attendee(_confHandle, attendeeInfo);
    DDLogInfo(@"tup_confctrl_add_attendee = %d, _confHandle:%d",result,_confHandle);
    free(attendee);
    free(attendeeInfo);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to remove attendee
 * 移除与会者
 *@param attendeeNumber attendee number
 *@return YES or NO
 */
-(BOOL)confCtrlRemoveAttendee:(NSString *)attendeeNumber
{
    int result = tup_confctrl_remove_attendee(_confHandle, (TUP_VOID*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_remove_attendee = %d, _confHandle:%d, attendeeNumber:%@",result,_confHandle,attendeeNumber);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to hang up attendee
 * 挂断与会者
 *@param attendeeNumber attendee number
 *@return YES or NO
 */
-(BOOL)confCtrlHangUpAttendee:(NSString *)attendeeNumber
{
    int result = tup_confctrl_hang_up_attendee(_confHandle, (TUP_VOID*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_hang_up_attendee = %d, _confHandle:%d",result,_confHandle);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to recall attendee
 * 重呼与会者
 *@param attendeeNumber attendee number
 *@return YES or NO
 */
-(BOOL)confCtrlRecallAttendee:(NSString *)attendeeNumber
{
    int result = tup_confctrl_call_attendee(_confHandle, (TUP_VOID*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_call_attendee = %d, _confHandle:%d",result,_confHandle);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to leave conference
 * 离开会议
 *@return YES or NO
 */
-(BOOL)confCtrlLeaveConference
{
    int result = tup_confctrl_leave_conf(_confHandle);
    DDLogInfo(@"tup_confctrl_leave_conf = %d, _confHandle is :%d",result,_confHandle);
    [self restoreConfParamsInitialValue];
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to end conference (chairman)
 * 结束会议
 *@return YES or NO
 */
-(BOOL)confCtrlEndConference
{
    int result = tup_confctrl_end_conf(_confHandle);
    DDLogInfo(@"tup_confctrl_end_conf = %d, _confHandle is :%d",result,_confHandle);
    [self restoreConfParamsInitialValue];
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to dealloc conference params
 * 销毁会议参数信息
 */
-(void)restoreConfParamsInitialValue
{
    DDLogInfo(@"restoreConfParamsInitialValue");
    [_confTokenDic removeAllObjects];
    [self.haveJoinAttendeeArray removeAllObjects];
    [self.dataConfParamURLDic removeAllObjects];
    self.isJoinDataConf = NO;
    _dataConfIdWaitConfInfo = nil;
    _confCtrlUrl = nil;
    _isNeedDataConfParam = YES;
    self.selfJoinNumber = nil;
    self.dataParam = nil;
    _hasReportMediaxSpeak = NO;
    _isFirstJumpToRunningView = YES;
    [self destroyConfHandle];
}


/**
 *This interface is used to destroy conference control handle.
 *销毁会议句柄
 */
-(BOOL)destroyConfHandle
{
    if (_confHandle == 0)
    {
        return NO;
    }
    BOOL result = NO;
    TUP_RESULT ret_destroy_confhandle = tup_confctrl_destroy_conf_handle(_confHandle);
    DDLogInfo(@"destroyConfHandleByConfId result :%d", ret_destroy_confhandle);
    
    result = (TUP_SUCCESS == ret_destroy_confhandle);
    if (result) {
        _confHandle = 0;
    }
    
    return result;
}

/**
 * This method is used to lock conference (chairman)
 * 主席锁定会场
 *@param isLock YES or NO
 *@return YES or NO
 */
-(BOOL)confCtrlLockConference:(BOOL)isLock
{
    TUP_BOOL tupBool = isLock ? 1 : 0;
    int result = tup_confctrl_lockconf(_confHandle, tupBool);
    DDLogInfo(@"tup_confctrl_lockconf = %d, _confHandle is :%d, isLock:%d",result,_confHandle,isLock);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to mute conference (chairman)
 * 主席闭音会场
 *@param isMute YES or NO
 *@return YES or NO
 */
-(BOOL)confCtrlMuteConference:(BOOL)isMute
{
    TUP_BOOL tupBool = isMute ? 1 : 0;
    int result = tup_confctrl_mute_conf(_confHandle, tupBool);
    DDLogInfo(@"tup_confctrl_mute_conf = %d, _confHandle is :%d, isMute:%d",result,_confHandle,isMute);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to mute attendee (chairman)
 * 主席闭音与会者
 *@param attendeeNumber attendee number
 *@param isMute YES or NO
 *@return YES or NO
 */
-(BOOL)confCtrlMuteAttendee:(NSString *)attendeeNumber isMute:(BOOL)isMute
{
    TUP_BOOL tupBool = isMute ? 1 : 0;
    int result = tup_confctrl_mute_attendee(_confHandle, (TUP_VOID*)[attendeeNumber UTF8String], tupBool);
    DDLogInfo(@"tup_confctrl_mute_attendee = %d, _confHandle is :%d, isMute:%d, attendee is :%@",result,_confHandle,isMute,attendeeNumber);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to request chair with password during conf
 *会议中申请成为主席
 */
-(BOOL)confCtrlRequestChairmanWithPassword:(NSString *)password requestMan:(NSString *)attendeeNumber
{
    int result = tup_confctrl_request_chairman(_confHandle,(TUP_CHAR*) [password UTF8String], (TUP_CHAR*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_request_chairman = %d, password is :%@, attendeeNumber:%@",result,password,attendeeNumber);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to release chair during conf
 *会议中主席释放主席权限
 */
-(BOOL)confCtrlReleaseChairmanWithRequestMan:(NSString *)attendeeNumber
{
    int result = tup_confctrl_release_chairman(_confHandle,(TUP_CHAR*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_release_chairman = %d,  attendeeNumber:%@",result,attendeeNumber);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to attendee raise hand
 *会议中与会者举手
 */
-(BOOL)confCtrlRaiseHandsAttendee:(NSString *)attendeeNumber isHandup:(BOOL)handup
{
    TUP_BOOL tupBool = handup ? 1 : 0;
    int result = tup_confctrl_handup(_confHandle, tupBool, (TUP_VOID*)[attendeeNumber UTF8String]);
    DDLogInfo(@"tup_confctrl_handup = %d, attendee is :%@",result,attendeeNumber);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to upgrade audio conference to data conference
 * 语音会议升级为数据会议
 *@param hasVideo whether the conference has video
 *@return YES or NO
 */
-(BOOL)confCtrlVoiceUpgradeToDataConference:(BOOL)hasVideo
{
    CONFCTRL_S_ADD_MEDIA *upgradeParams = (CONFCTRL_S_ADD_MEDIA *)malloc(sizeof(CONFCTRL_S_ADD_MEDIA));
    memset_s(upgradeParams, sizeof(CONFCTRL_S_ADD_MEDIA), 0, sizeof(CONFCTRL_S_ADD_MEDIA));
    TUP_UINT32 media_type = CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE;
    if (hasVideo) {
         media_type = media_type | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VIDEO;
    }
    upgradeParams->media_type = media_type;
    int result = tup_confctrl_upgrade_conf(_confHandle, upgradeParams);
    DDLogInfo(@"tup_confctrl_upgrade_conf = %d",result);
    free(upgradeParams);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 *This method is used to get param info of joining data conference
 *获取数据会议大参数
 */
-(BOOL)getConfDataparamsWithType:(UportalDataConfParamGetType)type
                     dataConfUrl:(NSString *)confUrl
                          number:(NSString *)number
                             pCd:(NSString *)passCode
                          confId:(NSString *)confId
                             pwd:(NSString *)pwd
                      dataRandom:(NSString *)dataRandom
{
    DDLogInfo(@"getConfDataparams:confUrl:%@,number:%@,passCode:%@,confId:%@,pwd:%@,dataRandom:%@",confUrl,number,passCode,confId,pwd,dataRandom);
    NSString *realUrl = nil;
    //get the value of url sequence: 1、CONFCTRL_E_EVT_REQUEST_CONF_RIGHT_RESULT back  2、onReceiveTupCallSipInfoNotification back 3、 login back.
    if (_confCtrlUrl.length > 0) {
        realUrl = _confCtrlUrl;
    }
    if (realUrl == nil || realUrl.length == 0) {
        realUrl = confUrl;
    }
    if (realUrl == nil || realUrl.length == 0) {
        LoginServerInfo *loginServerInfo = [[ManagerService loginService] obtainAccessServerInfo];
        
        realUrl = [NSString stringWithFormat:@"https://%@",loginServerInfo.msParamUri];
    }
    CONFCTRL_S_GET_DATACONF_PARAMS *dataConfParams = (CONFCTRL_S_GET_DATACONF_PARAMS *)malloc(sizeof(CONFCTRL_S_GET_DATACONF_PARAMS));
    memset_s(dataConfParams, sizeof(CONFCTRL_S_GET_DATACONF_PARAMS), 0, sizeof(CONFCTRL_S_GET_DATACONF_PARAMS));
    strcpy(dataConfParams->conf_url, [realUrl UTF8String]);
    
    if ([confId length] > 0) {
        [self.dataConfParamURLDic setObject:realUrl forKey:confId];
    } else {
        DDLogInfo(@"conf id empty!");
    }
    
    if (UportalDataConfParamGetTypePassCode != type &&
        UportalDataConfParamGetTypeConfIdPassWordRandom != type &&
        UportalDataConfParamGetTypeConfIdPassWord != type)
    {
        DDLogInfo(@"error  get type!");
        return NO;
    }
    switch (type) {
        case UportalDataConfParamGetTypePassCode:
            if (number.length > 0)
            {
                strcpy(dataConfParams->sip_num, [number UTF8String]);
            }
            if (passCode.length > 0)
            {
                strcpy(dataConfParams->passcode, [passCode UTF8String]);
            }
            break;
        case UportalDataConfParamGetTypeConfIdPassWord:
            if (confId.length > 0)
            {
                strcpy(dataConfParams->conf_id, [confId UTF8String]);
            }
            if (pwd.length > 0)
            {
                strcpy(dataConfParams->password, [pwd UTF8String]);
            }
            break;
        case UportalDataConfParamGetTypeConfIdPassWordRandom:
            if (confId.length > 0)
            {
                strcpy(dataConfParams->conf_id, [confId UTF8String]);
            }
            
            if (pwd.length > 0)
            {
                strcpy(dataConfParams->password, [pwd UTF8String]);
            }
            
            if (dataRandom.length > 0)
            {
                strcpy(dataConfParams->random, [dataRandom UTF8String]);
            }
            break;
        default:
            break;
    }
    
    dataConfParams->type = (TUP_UINT32)type;
    DDLogInfo(@"confurl is %s, dataConfParams->passcode: %s,dataConfParams->conf_id:%s",dataConfParams->conf_url,dataConfParams->passcode,dataConfParams->conf_id);
    int getConfParamsResult = tup_confctrl_get_dataconf_params(dataConfParams);
    DDLogInfo(@"tup_confctrl_get_dataconf_params result: %d",getConfParamsResult);
    free(dataConfParams);
    return getConfParamsResult == TC_OK ? YES : NO;
}

/**
 * This method is used to raise hand (Attendee)
 * 与会者举手
 *@param raise YES raise hand, NO cancel raise
 *@param attendeeNumber join conference number
 *@return YES or NO
 */
- (BOOL)confCtrlRaiseHand:(BOOL)raise attendeeNumber:(NSString *)attendeeNumber
{
    if (attendeeNumber.length == 0) {
        return NO;
    }
    TUP_BOOL isRaise = raise ? TUP_TRUE : TUP_FALSE;
    TUP_RESULT result = tup_confctrl_handup(_confHandle, isRaise, attendeeNumber.UTF8String);
    return result == TUP_SUCCESS;
}

/**
 * This method is used to release chairman right (chairman)
 * 释放主席权限
 *@param chairNumber chairman number in conference
 *@return YES or NO
 */
- (BOOL)confCtrlReleaseChairman:(NSString *)chairNumber
{
    if (chairNumber.length == 0) {
        return NO;
    }
    TUP_RESULT ret_release_chairman = tup_confctrl_release_chairman(_confHandle, (TUP_CHAR *)[chairNumber UTF8String]);
    return ret_release_chairman == TUP_SUCCESS;
}

/**
 * This method is used to request chairman right (Attendee)
 * 申请主席权限
 *@param chairPwd chairman password
 *@param newChairNumber attendee's number in conference
 *@return YES or NO
 */
- (BOOL)confCtrlRequestChairman:(NSString *)chairPwd number:(NSString *)newChairNumber
{
    if (newChairNumber.length == 0) {
        return NO;
    }
    
    TUP_RESULT ret_request_chairman = tup_confctrl_request_chairman(_confHandle, (TUP_CHAR *)[chairPwd UTF8String], (TUP_CHAR* )[newChairNumber UTF8String]);
    return (TUP_SUCCESS == ret_request_chairman);
}

/**
 *This method is used to post service handle result to UI by delegate
 *将业务处理结果消息通过代理分发给页面进行ui处理
 */
-(void)respondsECConferenceDelegateWithType:(EC_CONF_E_TYPE)type result:(NSDictionary *)resultDictionary
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(ecConferenceEventCallback:result:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ecConferenceEventCallback:type result:resultDictionary];
        });
    }
}

/**
 *This method is used to get media type int value by enum EC_CONF_MEDIATYPE
 *将会议类型EC_CONF_MEDIATYPE枚举值转换为int值
 */
- (TUP_UINT32)uPortalConfMediaTypeByESpaceMediaType:(EC_CONF_MEDIATYPE)type
{
    TUP_UINT32 mediaType = CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE;
    switch (type) {
        case CONF_MEDIATYPE_VOICE:
            break;
        case CONF_MEDIATYPE_DATA:
            mediaType = CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA;
            break;
        case CONF_MEDIATYPE_VIDEO:
            mediaType = CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VIDEO;
            break;
        case CONF_MEDIATYPE_VIDEO_DATA:
            mediaType = CONFCTRL_E_CONF_MEDIATYPE_FLAG_VOICE | CONFCTRL_E_CONF_MEDIATYPE_FLAG_VIDEO | CONFCTRL_E_CONF_MEDIATYPE_FLAG_DATA;
            break;
        default:
            DDLogInfo(@"unknow espace conf media type!");
            break;
    }
    return mediaType;
}

/**
 *This method is used to save token to token dictionary as the key of conf id if con network is SMC
 *smc组网下。将当前token以conf id为键存入token词典
 */
- (void)updateSMCConfToken:(NSString *)confToken inConf:(NSString *)confId
{
    BOOL isSMCConf = self.uPortalConfType == CONF_TOPOLOGY_SMC ? YES : NO;
    if (!isSMCConf)
    {
        DDLogWarn(@"not smc conf, ignore!");
        return;
    }
    if (nil == confToken || 0 == confToken.length || nil == confId || 0 == confId.length)
    {
        DDLogWarn(@"param is empty!");
        return;
    }
    @synchronized (_confTokenDic) {
        if ([_confTokenDic objectForKey:confId])
        {
            DDLogWarn(@"confToken in conf:%@ has already exist!", confId);
        }
        else
        {
            [_confTokenDic setObject:confToken forKey:confId];
        }
    }
}

/**
 *This method is used to get token from dictionary according to conf id
 *从token字典中拿出conf id对应的token
 */
- (NSString *)smcConfTokenByConfId:(NSString *)confId
{
    BOOL isSMCConf = self.uPortalConfType == CONF_TOPOLOGY_SMC ? YES : NO;
    if (!isSMCConf)
    {
        DDLogWarn(@"not smc conf, has no token!");
        return nil;
    }
    if (nil == confId || 0 == confId.length)
    {
        DDLogWarn(@"confId is empty!");
        return nil;
    }
    @synchronized (_confTokenDic) {
        return [_confTokenDic objectForKey:confId];
    }
}

/**
 *This method is used to remove token from dictionary according to conf id
 *从token字典中移除conf id对应的token
 */
- (void)clearSMCConfTokenByConfId:(NSString *)confId
{
    BOOL isSMCConf = self.uPortalConfType == CONF_TOPOLOGY_SMC ? YES : NO;
    if (!isSMCConf)
    {
        DDLogWarn(@"not smc conf, ignore!");
        return;
    }
    if (nil == confId || 0 == confId.length)
    {
        DDLogWarn(@"confId is empty!");
        return;
    }
    @synchronized (_confTokenDic) {
        [_confTokenDic removeObjectForKey:confId];
    }
}

//get mainConfId with confId in CONF_TOPOLOGY_MEDIAX
- (NSString *)mainConfIdByDBConfID:(NSString *)confId
{
    //if uPortalConfType is not CONF_TOPOLOGY_MEDIAX ,use current confId.
    BOOL isMediaXConf = self.uPortalConfType == CONF_TOPOLOGY_MEDIAX ? YES : NO;
    if (!isMediaXConf)
    {
        return confId;
    }
    NSString *mainConfId = confId;
    NSRange range = [confId rangeOfString:@"sub"];
    if (range.length > 0)
    {
        mainConfId = [confId substringToIndex:range.location];
    }
    DDLogInfo(@"confId is:%@, mainConfID is:%@", confId, mainConfId);
    return mainConfId;
}

/**
 * This method is used to create conference handle
 * 创建会议句柄
 *@param confId conference id
 *@return YES or NO
 */
- (BOOL)createConfHandle:(NSString *)confId
{
    if (nil == confId || 0 == confId.length)
    {
        DDLogInfo(@"param is empty!");
        return NO;
    }
    //_confHandle is exist ,no need to create.
    if (_confHandle > 0)
    {
        return YES;
    }
    TUP_RESULT ret_handle_create = TUP_FALSE;
    NSString *confHandleString = nil;
    TUP_UINT32 confHandle = 0;
    ret_handle_create = tup_confctrl_create_conf_handle((TUP_VOID *)[confId UTF8String], &confHandle);
    DDLogInfo(@"tup_confctrl_create_conf_handle,result:%d",ret_handle_create);
    
    if (TUP_SUCCESS == ret_handle_create)
    {
        _confHandle = confHandle;
    }
    return (TUP_SUCCESS == ret_handle_create);
}

/**
 *This method is used to create uportal conference control before join in conference
 *在uportal下加入会议前创建会议回控
 */
- (BOOL)createUportalConfConfCtrlWithConfId:(NSString *)confId
                                        pwd:(NSString *)pwd
                                 joinNumber:(NSString *)joinNumber
                             confCtrlRandom:(NSString *)ctrlRandom
{
    if (nil == confId || 0 == confId.length)
    {
        return NO;
    }
    // get mainConfId
    NSString *mainConfId = [self mainConfIdByDBConfID:confId];

    //the token used to requestConfContrlRight, in CONF_TOPOLOGY_SMC ,use the token from confContrl's token.
    //in other EC_CONF_TOPOLOGY_TYPE,use the token from sipInfo,s ctrlRandom.

    NSString *confCtrlToken = ctrlRandom;
    BOOL isSMCConf = self.uPortalConfType == CONF_TOPOLOGY_SMC ? YES : NO;
    if (isSMCConf)
    {
        NSString *smcConfToken = [self smcConfTokenByConfId:confId];
        if (smcConfToken.length > 0)
        {
            confCtrlToken = smcConfToken;
        }
        else
        {
            DDLogInfo(@"can not find token by conf:%@", confId);
        }
    }
    
    BOOL requestConfRightResult = [self requestMediaXConfControlRightWithConfId:mainConfId
                                                                            pwd:pwd
                                                                         number:joinNumber
                                                                          token:confCtrlToken];
    if (!requestConfRightResult) {
        [self destroyConfHandle];
        BOOL isSMCConf = self.uPortalConfType == CONF_TOPOLOGY_SMC ? YES : NO;
        if (isSMCConf)
        {
            [self clearSMCConfTokenByConfId:confId];
        }
    }
    
    return requestConfRightResult;
}

/**
 *This method is used to create uportal conference control before join in conference
 *在mediaX环境下加入会议前创建会议回控
 */
- (BOOL)requestMediaXConfControlRightWithConfId:(NSString *)confid
                                            pwd:(NSString *)pwd
                                         number:(NSString *)number
                                          token:(NSString *)token
{
    //pwd and token ,can't be empty together.
    if (nil == confid || 0 == confid.length || nil == number || 0 == number.length || (pwd.length == 0 && token.length == 0))
    {
        DDLogInfo(@"requestMediaXConfControlRight param is empty!");
        return NO;
    }
    //get confhandle
    if (_confHandle == 0)
    {
        return NO;
    }

    pwd = (pwd == nil ? @"" : pwd);
    token = (token == nil ? @"" : token);
    
    TUP_RESULT ret_request_confctrl_right = tup_confctrl_request_confctrl_right(_confHandle, [number UTF8String], [pwd UTF8String], [token UTF8String]);
    DDLogInfo(@"ret_request_confctrl_right,result:%d",ret_request_confctrl_right);
    return (ret_request_confctrl_right == TUP_SUCCESS);
    
}

/**
 *This method is used to subscribe conference info(uportal network)
 *uportal组网下订阅会议信息
 */
- (BOOL)subscribeConfWithConfId:(NSString *)confId
{
    if (nil == confId || 0 == confId.length)
    {
        DDLogInfo(@"param is empty!");
        return NO;
    }
    
    if (_confHandle == 0)
    {
        return NO;
    }
    TUP_RESULT ret_subscribe = tup_confctrl_subscribe_conf(_confHandle);
    DDLogInfo(@"tup_confctrl_subscribe_conf,result:%d",ret_subscribe);
    
    return (TUP_SUCCESS == ret_subscribe);
}

/**
 * This method is used to judge whether is uportal mediax conf
 * 判断是否为mediax下的会议
 */
- (BOOL)isUportalMediaXConf
{
    //Mediax conference
    return  (CONF_TOPOLOGY_MEDIAX == self.uPortalConfType);
}

/**
 * This method is used to judge whether is uportal smc conf
 * 判断是否为smc下的会议
 */
- (BOOL)isUportalSMCConf
{
    //SMC conference
    return (CONF_TOPOLOGY_SMC == self.uPortalConfType);
}

/**
 * This method is used to judge whether is uportal UC conf
 * 判断是否为uc下的会议
 */
- (BOOL)isUportalUSMConf
{
    //UC conference
    return (CONF_TOPOLOGY_UC == self.uPortalConfType);
}

/**
 * This method is used to set conf mode
 * 设置会议模式
 */
- (void)setConfMode:(EC_CONF_MODE)mode {
    CONFCTRL_E_CONF_MODE tupMode;
    switch (mode) {
        case EC_CONF_MODE_FIXED:
            tupMode = CONFCTRL_E_CONF_MODE_FIXED;
            break;
        case EC_CONF_MODE_VAS:
            tupMode = CONFCTRL_E_CONF_MODE_VAS;
            break;
        case EC_CONF_MODE_FREE:
            tupMode = CONFCTRL_E_CONF_MODE_FREE;
            break;
        default:
            break;
    }
    
    TUP_RESULT ret_set_conf_mode = tup_confctrl_set_conf_mode(_confHandle, tupMode);
    DDLogInfo(@"ret_set_conf_mode: %d", ret_set_conf_mode);
}

/**
 * This method is used to boardcast attendee
 * 广播与会者
 */
- (void)boardcastAttendee:(NSString *)attendeeNumber isBoardcast:(BOOL)isBoardcast {
    TUP_RESULT ret_boardcast_attendee = tup_confctrl_broadcast_attendee(_confHandle, (TUP_VOID*)[attendeeNumber UTF8String], (isBoardcast ? TUP_TRUE : TUP_FALSE));
    DDLogInfo(@"boardcast attendee number: %@, is boardcast: %d ret: %d", attendeeNumber, isBoardcast, ret_boardcast_attendee);
}

/**
 *This method is used to enable or disable speaker report
 *开启或者关闭发言人上报
 */
- (void)configMediaxSpeakReport
{
    TUP_RESULT result = tup_confctrl_set_speaker_report(_confHandle, TUP_TRUE);
    DDLogInfo(@"tup_confctrl_set_speaker_report, result : %d",result);
}

@end
