//
//  CommonUtils.h
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import <Foundation/Foundation.h>
#import "Defines.h"
#import <UIKit/UIKit.h>
#import <TUPIOSSDK/TUPIOSSDK.h>
#import <TUPContactSDK/TUPContactSDK.h>
#import <TUPContactSDK/EmployeeEntity+ServiceObject.h>

@interface CommonUtils : NSObject

/**
 *This method is used to display contact state by image
 *获取联系人状态
 *@param tempEmployee EmployeeEntity value
 *@return image
 */
+(UIImage *)getContactState:(PersonEntity *)tempEmployee;

/**
 *This method is used to display current user state by image
 *以图片形式显示用户当前状态
 *@param tempState ESpaceUserStatus value
 *@return image
 */
+(UIImage *)getSelfUserStateWithType:(ESpaceUserStatus)tempState;

/**
 *This method is used to display current user state by string
 *以字符串形式显示联系人当前状态
 *@param tempEmployee EmployeeEntity value
 *@return string
 */
+(NSString *)getContactStateString:(PersonEntity *)tempEmployee;

/**
 *This method is used to transform UTC date to local date
 *将UTC时间转为本地时间
 @param utcDate UTC date
 @return string
 */
+(NSString *)getLocalDateFormateUTCDate:(NSString *)utcDate;

/**
 *This method is used to encode string with base64
 *按base64对字符串进行编码
 *@param text destination string
 *@return string
 */
+ (NSString *)base64StringFromText:(NSString *)text;

/**
 *This method is used to decode string from base64
 *对base64编码的字符串进行解码
 *@param base64 destination string
 *@return string
 */
+ (NSString *)textFromBase64String:(NSString *)base64;

/**
 *This method is used to check string format whether is pure number and characters
 *检查字符串是否为纯数字和单词
 *@param string destination string
 *@return YES or NO
 */
+(BOOL)isPureNumberAndCharacters:(NSString *)string;

/**
 *This method is used to check string is empty or not
 *判断字符串是否为非空
 *@param string destination string
 *@return YES or NO
 */
+(BOOL)checkIsNotEmptyString:(NSString *)string;

/**
 *This method is used to save user config
 *保存用户数据
 *@param anyValue value
 *@param key destination string
 */
+(void)userDefaultSaveValue:(id)anyValue forKey:(NSString *)key;

/**
 *This method is used to get user default value
 *获取用户存储的值
 @param key key
 @return value
 */
+(id)getUserDefaultValueWithKey:(NSString *)key;

/**
 *This method is used to check is VPN connect or not
 *检查vpn是否连接
 *@return YES or NO
 */
+(BOOL)checkIsVPNConnect;

/**
 *This method is used to get local IP address
 *获取本地ip地址
 @param isVpnAddress YES or NO
 @return YES or NO
 */
+(NSString *)getLocalIpAddressWithIsVPN:(BOOL)isVpnAddress;

/**
 *This method is used to set view controller orientation
 *旋转屏幕
 *@param toOrientation
 */
+ (void)setToOrientation:(UIDeviceOrientation)toOrientation;


/**
 *This method is used to get Image from disk
 *从图片文件夹获取图片
 *@param imageFile image file path
 *@return image
 */
+ (UIImage *) attachImageFile:(NSString*) imageFile;

@end
