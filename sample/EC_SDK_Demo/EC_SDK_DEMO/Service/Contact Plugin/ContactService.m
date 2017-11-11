//
//  ContactService.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "Initializer.h"
#import "ContactService.h"
#import "LoginServerInfo.h"
#import "SearchParam.h"
#import "SearchResultInfo.h"
#import "DeptInfo.h"
#import "ContactInfo.h"

#import <UIKit/UIKit.h>
#import "tup_eaddr_def.h"
#import "tup_eaddr_interface.h"
#import <TUPIOSSDK/EmployeeEntity.h>
#import <TUPIOSSDK/eSpaceDBService.h>
#import <TUPIOSSDK/ESpaceImageCache.h>

#define SIZE52 CGSizeMake(52, 52)
#define SIZE120 CGSizeMake(120, 120)
#define SIZE320 CGSizeMake(320, 320)

#define ICON_PATH [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingString:@"/TUPC60log/contact/icon"]

NSString *const TUP_CONTACT_EVENT_RESULT_KEY        = @"TUP_CONTACT_EVENT_RESULT_KEY";
NSString *const TUP_CONTACT_KEY                     = @"TUP_CONTACT_KEY";
NSString *const TUP_DEPARTMENT_KEY                  = @"TUP_DEPARTMENT_KEY";
NSString *const TUP_DEPARTMENT_RESULT_KEY           = @"TUP_DEPARTMENT_RESULT_KEY";
NSString *const TUP_CONTACT_HEADERIMG_KEY           = @"TUP_CONTACT_HEADERIMG_KEY";
NSString *const TUP_SYS_ICON_ID_KEY                 = @"TUP_SYS_ICON_ID_KEY";
NSString *const TUP_ICON_FILE_KEY                   = @"TUP_ICON_FILE_KEY";

@interface ContactService ()<ContactNotification>

@end

@implementation ContactService
@synthesize delegate = _delegate;

/**
 * This method is used to init this class
 * 初始化该类
 */
- (instancetype)init
{
    self = [super init];
    if (self) {
        // 设置联系人回调的delegate
        [Initializer registerContactCallBack:self];
    }
    return self;
}

/**
 * This method is used to config contact uportal server info
 * 配置服务器信息
 *@param info                      Indicates uportal info, see TUPLoginServerInfo value
 *                                 鉴权结果返回信息，参考TUPLoginServerInfo
 *@param token                     Indicates token
 *                                 鉴权凭证
 *@return YES if succeed, NO if failed
 */
- (BOOL)configUportalInfo:(LoginServerInfo *)info token:(NSString *)token
{
    TUP_EADDR_S_UPORTAL_CONFIG *uportalConfig = (TUP_EADDR_S_UPORTAL_CONFIG *)malloc(sizeof(TUP_EADDR_S_UPORTAL_CONFIG));
    memset(uportalConfig, 0, sizeof(TUP_EADDR_S_UPORTAL_CONFIG));
    
    // 使用uPortal鉴权地址
    NSString *serAddrUrl = [NSString stringWithFormat:@"https://%@",info.authServer];
    strcpy(uportalConfig->acServerAddr, [serAddrUrl UTF8String]);

    NSString *iconPath = ICON_PATH;
    NSString *deptFilePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingString:@"/TUPC60log/contact/deptFile"];
    strcpy(uportalConfig->acIconFilePath, [iconPath UTF8String]);
    strcpy(uportalConfig->acDeptFilePath, [deptFilePath UTF8String]);
    strcpy(uportalConfig->acToken, [token UTF8String]);
    
    uportalConfig->enType = EADDR_E_TYPE_EC6X;
    uportalConfig->ulVerifyMode = 0;
    uportalConfig->ulPageItemMax = PAGE_ITEM_SIZE; //config the number of contacts searched by corporate directory per page
    
    TUP_RESULT result = tup_eaddr_config(uportalConfig);
    DDLogInfo(@"tup_eaddr_config result: %d",result);
    free(uportalConfig);
    return result == TUP_SUCCESS ? YES : NO;
}

/**
 * This method is used to deel contact event callback from service
 * 分发联系人业务相关回调
 *@param module TUP_MODULE
 *@param notification Notification
 */
- (void)contactModule:(TUP_MODULE)module notification:(Notification *)notification {
    if (CONTACT_MODULE == module) {
        switch (notification.msgId) {
                // 联系人搜索结果
            case TUP_EADDR_E_HANDLE_PERSONINFO: {
                DDLogInfo(@"TUP_EADDR_E_HANDLE_PERSONINFO");
                TUP_EADDR_S_SEARCH_CONTACTOR_RESULT *searchContactorResult = (TUP_EADDR_S_SEARCH_CONTACTOR_RESULT *)notification.data;
                if (searchContactorResult == NULL) {
                    DDLogWarn(@"handleSearchContact result is empty.");
                    return;
                }
                BOOL result = searchContactorResult->ret == TUP_SUCCESS ? YES : NO;
                int pageIndex = searchContactorResult->ulPage;
                
                TUP_EADDR_S_CONTACTOR_INFO *pstContactorInfo = searchContactorResult->pstContactorInfo;
                NSMutableArray *contactArray = [[NSMutableArray alloc] init];
                // 搜索到的联系人结果放入联系人数组，传递给界面使用
                for (int i = 0; i< searchContactorResult->ulTotalNum; i++) {
                    
                    int lastTotal = searchContactorResult->ulTotalNum - PAGE_ITEM_SIZE*(pageIndex-1);
                    int endIndex = (lastTotal < PAGE_ITEM_SIZE) ? lastTotal : PAGE_ITEM_SIZE ;
                    if (i == endIndex) {
                        NSDictionary *resultInfo = @{TUP_CONTACT_EVENT_RESULT_KEY : [NSNumber numberWithBool:result],
                                                     TUP_CONTACT_KEY:contactArray};
                        [self respondsContactDelegateWithType:CONTACT_E_SEARCH_CONTACT_RESULT result:resultInfo];
                        return;
                    }
                    ContactInfo *contactInfo = [ContactInfo contactInfoTransformFrom:pstContactorInfo[i]];
                    DDLogInfo(@"contactInfo.personName: %@",contactInfo.personName);
                    [contactArray addObject:contactInfo];
                }
                NSDictionary *resultInfo = @{TUP_CONTACT_EVENT_RESULT_KEY : [NSNumber numberWithBool:result],
                                             TUP_CONTACT_KEY:contactArray};
                [self respondsContactDelegateWithType:CONTACT_E_SEARCH_CONTACT_RESULT result:resultInfo];
            }
                break;
                
            case TUP_EADDR_E_HANDLE_BUTT: {
                DDLogInfo(@"TUP_EADDR_E_HANDLE_BUTT");
            }
                break;
                // 联系人头像搜索结果
            case TUP_EADDR_E_HANDLE_ICON: {
                DDLogInfo(@"TUP_EADDR_E_HANDLE_ICON");
                TUP_EADDR_S_GETICON_RESULT *getIconResult = (TUP_EADDR_S_SEARCH_DEPT_RESULT *)notification.data;
                BOOL result = getIconResult->ret == TUP_SUCCESS ? YES : NO;
                int sysIconID = getIconResult->ulSysIconID;
                NSString *acIconFile = [NSString stringWithUTF8String:getIconResult->acIconFile];
                
                NSDictionary *resultInfo = @{TUP_CONTACT_EVENT_RESULT_KEY : [NSNumber numberWithBool:result],
                                             TUP_SYS_ICON_ID_KEY : [NSString stringWithFormat:@"%d", sysIconID],
                                             TUP_ICON_FILE_KEY : [NSString stringWithFormat:@"%@%@", ICON_PATH, acIconFile]};
                [self respondsContactDelegateWithType:CONTACT_E_SEARCH_GET_ICON_RESULT result:resultInfo];
            }
                break;
                // 联系人部门搜索结果
            case TUP_EADDR_E_HANDLE_DEPTINFO: {
                DDLogInfo(@"TUP_EADDR_E_HANDLE_DEPTINFO");
                TUP_EADDR_S_SEARCH_DEPT_RESULT *searchDeptResult = (TUP_EADDR_S_SEARCH_DEPT_RESULT *)notification.data;
                SearchResultInfo *info = [SearchResultInfo resultInfoTransformFrom:searchDeptResult];
                BOOL result = searchDeptResult->ret == TUP_SUCCESS ? YES : NO;
                DDLogInfo(@"Search department result: %d", result);
                TUP_EADDR_S_DEPT_INFO* pstDeptInfo = searchDeptResult->pstDeptInfo;
                
                NSMutableArray *deptArray = [[NSMutableArray alloc] init];
                // 部门搜索结果放入部门数组，传递给界面使用
                for (int i = 0; i<searchDeptResult->ulItemNum; i++) {
                    DDLogInfo(@"Search department result: deptID:(%s) dept name(%s) parentID(%s)", pstDeptInfo[i].deptId, pstDeptInfo[i].deptName, pstDeptInfo[i].parentId);
                    DeptInfo *detpInfo = [DeptInfo deptInfoTransformFrom:pstDeptInfo[i]];
                    [deptArray addObject:detpInfo];
                }
                
                NSDictionary *resultInfo = @{TUP_CONTACT_EVENT_RESULT_KEY : [NSNumber numberWithBool:result],
                                             TUP_DEPARTMENT_KEY : deptArray,
                                             TUP_DEPARTMENT_RESULT_KEY : info };
                [self respondsContactDelegateWithType:CONTACT_E_SEARCH_DEPARTMENT_RESULT result:resultInfo];
            }
                break;
                
            default:
                break;
        }
    }
}

/**
 * This method is used to deel contact event callback from service to UI
 * 分发联系人业务相关回调到界面
 *@param type TUP_CONTACT_EVENT_TYPE
 *@param resultDictionary NSDictionary
 */
-(void)respondsContactDelegateWithType:(TUP_CONTACT_EVENT_TYPE)type result:(NSDictionary *)resultDictionary {
    if ([self.delegate respondsToSelector:@selector(contactEventCallback:result:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate contactEventCallback:type result:resultDictionary];
        });
    }
}

/**
 * This method is used to set system head image (0~9) (if completionBlock result is YES, set self head ID with sysIconID)
 * 设置系统头像
 *@param sysIconID                 Indicates system head image ID
 *                                 系统头像id
 *@param completionBlock           Indicates callback(result: set head image result. YES or NO)
 *                                 回调，返回设置头像成功与否
 */
- (void)setSystemHead:(int)sysIconID withCmpletion:(void(^)(BOOL result))completionBlock {
    TUP_RESULT set_sys_result = tup_eaddr_set_sysicon((TUP_UINT32)sysIconID);
    BOOL result = set_sys_result == TUP_SUCCESS;
    if (completionBlock) {
        completionBlock(result);
    }
    if (result) {
        [self setHeadID:[NSString stringWithFormat:@"%d", sysIconID]];
    }
}

/**
 * headId's set method
 * 头像Id 的set方法
 *@param headId NSString
 */
- (void)setHeadID:(NSString *)headId {
    EmployeeEntity *selfEntity = LOCAL_DATA_MANAGER.currentUser;
    selfEntity.headId = headId;
}

/**
 * This method is used to set custom head image (if completionBlock result is YES, set self hedID with headID)
 * 设置自定义头像
 *@param image                     Indicates custom image
 *                                 自定义头像
 *@param completionBlock           Indicates callback(result: set head image result. YES or NO)
 *                                 回调，返回设置头像成功与否
 */
- (void)setHeadImage:(UIImage *)image completion:(void(^)(BOOL result, NSString *headID))completionBlock {
    //自定义头像接口需要上传三种尺寸的图片：52x52   120x120   320x320
    NSData *minImg = [self imgWithSize:SIZE52 image:image];
    NSData *midImg = [self imgWithSize:SIZE120 image:image];
    NSData *maxImg = [self imgWithSize:SIZE320 image:image];
    
    TUP_EADDR_S_ICON* icon_info = (TUP_EADDR_S_ICON*)malloc(sizeof(TUP_EADDR_S_ICON));
    memset(icon_info, 0, sizeof(TUP_EADDR_S_ICON));
    icon_info->pcLargeIcon_data = (TUP_CHAR *)maxImg.bytes;
    icon_info->pcMediumIcon_data = (TUP_CHAR *)midImg.bytes;
    icon_info->pcSmallIcon_data = (TUP_CHAR *)minImg.bytes;
    icon_info->ulLargeIcon_len = (TUP_UINT32)maxImg.length;
    icon_info->ulMediumIcon_len = (TUP_UINT32)midImg.length;
    icon_info->ulSmallIcon_len = (TUP_UINT32)minImg.length;
    
    TUP_CHAR *modifyTime = (TUP_CHAR *)malloc(16);
    memset_s(modifyTime, 16, 0, 16);
    TUP_UINT32 length = 16;
    TUP_RESULT ret_set_eficon = tup_eaddr_set_deficon(icon_info, modifyTime, length);
    free(icon_info);
    // 出参modifyTime时间戳，作为联系人headId
    NSString *mTime = [NSString stringWithUTF8String:modifyTime];
    DDLogInfo(@"set image ret: %d modify time: %@", ret_set_eficon, mTime);
    BOOL result = ret_set_eficon == TUP_SUCCESS;
    if (completionBlock) {
        completionBlock(result, mTime);
    }
    if (result) {
        [self setHeadID:mTime];
    }
}

/**
 * This method is used to draw image to a needed size
 * 压缩图片图片至给定大小
 *@param size  CGSize
 *@param image UIImage
 */
- (NSData *)imgWithSize:(CGSize)size image:(UIImage *)image {
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0,0,size.width,size.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImagePNGRepresentation(newImage);
}

/**
 * This method is used to search corporate directory contacts
 * 搜索联系人信息
 *@param searchParam               Indicates search param, see SearchParam value (Search conditions)
 *                                 用于搜索联系人的参数
 */
- (void)searchContactWithParam:(SearchParam *)searchParam {
    TUP_EADDR_S_SEARCH_PARAM *tupSearchParam = (TUP_EADDR_S_SEARCH_PARAM *)malloc(sizeof(TUP_EADDR_S_SEARCH_PARAM));
    memset(tupSearchParam, 0, sizeof(TUP_EADDR_S_SEARCH_PARAM));
    tupSearchParam->ulExactSearch = searchParam.ulExactSearch;
    tupSearchParam->ulSeqNo = searchParam.ulSeqNo;
    tupSearchParam->ulPageIndex = searchParam.ulPageIndex;
    strcpy(tupSearchParam->acDepId, [searchParam.acDepId UTF8String]);
    strcpy(tupSearchParam->acSearchItem, [searchParam.acSearchItem UTF8String]);
    TUP_RESULT result = tup_eaddr_search_contactor(tupSearchParam);
    DDLogInfo(@"tup_eaddr_search_contactor result: %d",result);
    free(tupSearchParam);
}

/**
 * This method is used to search corporate directory departments list
 * 搜索部门列表
 *@param deptID                    Indicates parent department ID
 *                                 部门id
 */
- (void)searchDeptListWithID:(NSString *)deptID {
    TUP_EADDR_S_DEP_PARAM *pstDep = (TUP_EADDR_S_DEP_PARAM *)malloc(sizeof(TUP_EADDR_S_DEP_PARAM));
    memset(pstDep, 0, sizeof(TUP_EADDR_S_DEP_PARAM));
    strcpy(pstDep->acDepId, [deptID UTF8String]);
    pstDep->ulSeqNo = rand();
    TUP_RESULT result = tup_eaddr_search_department(pstDep);
    DDLogInfo(@"tup_eaddr_search_department result: %d",result);
    free(pstDep);
}

/**
 * This method is used to load contact head image from corporate directory
 * 加载个人头像
 *@param account                   Indicates user account
 *                                 用户账号
 */
- (void)loadPersonHeadIconWithAccount:(NSString *)account {
    TUP_EADDR_S_ICON_PARAM *iconParam = (TUP_EADDR_S_ICON_PARAM *)malloc(sizeof(TUP_EADDR_S_ICON_PARAM));
    memset(iconParam, 0, sizeof(TUP_EADDR_S_ICON_PARAM));
    strcpy(iconParam->acStaffAccount, [account UTF8String]);
    iconParam->ulSeqNo = rand();
    iconParam->enMsgPrio = EADDR_MSG_PRIO_MID; // The priority of loaded head image
    TUP_RESULT result = tup_eaddr_get_usericon(iconParam);
    DDLogInfo(@"tup_eaddr_get_usericon result: %d", result);
    free(iconParam);
}

@end
