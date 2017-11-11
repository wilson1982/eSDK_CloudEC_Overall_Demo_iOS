//
//  CommonUtils.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "CommonUtils.h"
#include <netdb.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <sys/sysctl.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#define CHECKCSTR(str) (((str) == NULL) ? "" : (str))
#define CONSTVALUEZERO               0
#define CONSTVALUEONE                1
#define CONSTVALUETWO                2
#define CONSTVALUETHREE              3
#define ASCNUMZERO                   48
#define ASCNUMNINE                   57
#define ADDRESSBOARD                 128
#define ASCPOINT                     46
#define MAX_PORT        65535

@implementation CommonUtils

/**
 *This method is used to get single instance of this class
 *获取该类唯一实例
 */
+(instancetype)shareInstance
{
    static CommonUtils *_commonUtils = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _commonUtils = [[CommonUtils alloc] init];
    });
    return _commonUtils;
}

/**
 *This method is used to display contact state by image
 *获取联系人状态
 *@param tempEmployee EmployeeEntity value
 *@return image
 */
+(UIImage *)getContactState:(PersonEntity *)tempEmployee
{
    UIImage *stateImage = nil;
    EspaceUserOnlineStatus* onlineStatus = [[TupContactService sharedInstance] onlineStatusForUser:tempEmployee.uiDisplayName];
    
    NSLog(@" onlineStatus =================== %ld",(long)onlineStatus.userStatus);
    if (0 == onlineStatus.userStatus)
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    if (ESpaceUserStatusAvailable == onlineStatus.userStatus)//1
    {
        stateImage = [UIImage imageNamed:@"status_online"];
    }
    if (ESpaceUserStatusBusy == onlineStatus.userStatus)//2
    {
        stateImage = [UIImage imageNamed:@"status_busy"];
    }
    if (ESpaceUserStatusAway == onlineStatus.userStatus)//3
    {
        stateImage = [UIImage imageNamed:@"status_leave"];
    }
    if (ESpaceUserStatusOffline == onlineStatus.userStatus)//4
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    if (ESpaceUserStatusUninteruptable == onlineStatus.userStatus)//5
    {
        stateImage = [UIImage imageNamed:@"status_uninterrupt"];
    }
    if (ESpaceUserStatusUnknown == onlineStatus.userStatus)//5
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    return stateImage;
}

/**
 *This method is used to display current user state by image
 *以图片形式显示用户状态
 *@param tempState ESpaceUserStatus value
 *@return image
 */
+(UIImage *)getSelfUserStateWithType:(ESpaceUserStatus)tempState
{
    UIImage *stateImage = nil;
    if (0 == tempState)
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    if (ESpaceUserStatusAvailable == tempState)//1
    {
        stateImage = [UIImage imageNamed:@"status_online"];
    }
    if (ESpaceUserStatusBusy == tempState)//2
    {
        stateImage = [UIImage imageNamed:@"status_busy"];
    }
    if (ESpaceUserStatusAway == tempState)//3
    {
        stateImage = [UIImage imageNamed:@"status_leave"];
    }
    if (ESpaceUserStatusOffline == tempState)//4
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    if (ESpaceUserStatusUninteruptable == tempState)//5
    {
        stateImage = [UIImage imageNamed:@"status_uninterrupt"];
    }
    if (ESpaceUserStatusUnknown == tempState)//5
    {
        stateImage = [UIImage imageNamed:@"status_away"];
    }
    return stateImage;
}

/**
 *This method is used to display current user state by string
 *以字符串形式显示联系人当前状态
 *@param tempEmployee EmployeeEntity value
 *@return string
 */
+(NSString *)getContactStateString:(PersonEntity *)tempEmployee
{
    NSString *stateImage = @"";
    EspaceUserOnlineStatus* onlineStatus = [[TupContactService sharedInstance] onlineStatusForUser:tempEmployee.uiDisplayName];
    NSLog(@" onlineStatus =================== %ld",(long)onlineStatus.userStatus);
    if (0 == onlineStatus.userStatus)
    {
        stateImage = @"[off line]";
    }
    if (ESpaceUserStatusAvailable == onlineStatus.userStatus)//1
    {
        stateImage = @"[on line]";
    }
    if (ESpaceUserStatusBusy == onlineStatus.userStatus)//2
    {
        stateImage = @"[busy]";
    }
    if (ESpaceUserStatusAway == onlineStatus.userStatus)//3
    {
        stateImage = @"[leave]";
    }
    if (ESpaceUserStatusOffline == onlineStatus.userStatus)//4
    {
        stateImage = @"[off line]";
    }
    if (ESpaceUserStatusUninteruptable == onlineStatus.userStatus)//5
    {
        stateImage = @"[uninterrupt]";
    }
    if (ESpaceUserStatusUnknown == onlineStatus.userStatus)//5
    {
        stateImage = @"[off line]";
    }
    return stateImage;
}

/**
 *This method is used to transform UTC date to local date
 *将UTC时间转为本地时间
 @param utcDate UTC date
 @return string
 */
+(NSString *)getLocalDateFormateUTCDate:(NSString *)utcDate
{
//    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//    //输入格式
//    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
//    //    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
//    //    [dateFormatter setTimeZone:timeZone];
//    NSString *dateString = [dateFormatter stringFromDate:utcDate];
//    NSLog(@"dateString-- :%@",dateString);
//    return dateString;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //input
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    NSDate *dateFormatted = [dateFormatter dateFromString:utcDate];
    //output
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    [dateFormatter setTimeZone:localTimeZone];
    NSString *dateString = [dateFormatter stringFromDate:dateFormatted];
    return dateString;
}

/**
 *This method is used to save user config
 *保存用户数据
 *@param anyValue value
 *@param key destination string
 */
+(void)userDefaultSaveValue:(id)anyValue forKey:(NSString *)key
{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setObject:anyValue forKey:key];
    [userDefault synchronize];
}

+(id)getUserDefaultValueWithKey:(NSString *)key
{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    id anyValue = [userDefault objectForKey:key];
    return anyValue;
}

/**
 *This method is used to encode string with base64
 *按base64对字符串进行编码
 *@param text destination string
 *@return string
 */
+ (NSString *)base64StringFromText:(NSString *)text
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [data base64EncodedStringWithOptions:0];
    return base64String;
}

/**
 *This method is used to decode string from base64
 *对base64编码的字符串进行解码
 *@param base64 destination string
 *@return string
 */
+ (NSString *)textFromBase64String:(NSString *)base64
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text;
}

/**
 *This method is used to check is VPN connect or not
 *检查vpn是否连接
 *@return YES or NO
 */
+(BOOL)checkIsVPNConnect
{
    NSDictionary *addresses = [CommonUtils getIPAddresses];
    DDLogInfo(@"all addresses: %@", addresses);
    NSString *pppIpv4 = addresses[@"ppp0/ipv4"];
    DDLogInfo(@"pppIpv4:%@",pppIpv4);
    DDLogInfo(@"current have ppp0:%d",pppIpv4.length > 0 ? YES : NO);
    return pppIpv4.length > 0 ? YES : NO;
}

/**
 *This method is used to get local IP address
 *获取本地ip地址
 @param isVpnAddress YES or NO
 @return YES or NO
 */
+(NSString *)getLocalIpAddressWithIsVPN:(BOOL)isVpnAddress
{
    NSString *tempIP = @"";
    if (isVpnAddress)
    {
        NSDictionary *addresses = [CommonUtils getIPAddresses];
        NSString *pppIpv4 = addresses[@"ppp0/ipv4"];
        tempIP = pppIpv4;
        DDLogInfo(@"pppipv4: %@",pppIpv4);
    }
    else
    {
        tempIP = [CommonUtils getIPAddress:YES];
    }
    DDLogInfo(@"tempIP---- :%@",tempIP);
    return tempIP;
}

/**
 *This method is used to get ip address
 *获取ip地址
 */
+ (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [CommonUtils getIPAddresses];
    NSLog(@"addresses: %@", addresses);
    NSString *pppIpv4 = addresses[@"ppp0/ipv4"];
    NSLog(@"pppIpv4:%@",pppIpv4);
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         //筛选出IP地址格式
         if([CommonUtils isValidateIP:address])
         {
             *stop = YES;
         }
     } ];
    
    if ([address length] == 0)
    {
        address = [CommonUtils getIPAddresses][@"en1/ipv4"];
    }
    NSLog(@"address:%@",address);
    return address ? address : @"0.0.0.0";
}

/**
 *This method is used to judge whether ip address is valid
 *判断ip地址是否有效
 */
+ (BOOL)isValidateIP:(NSString *)ipAddress
{
    if (ipAddress.length == 0)
    {
        return NO;
    }
    NSString *urlRegEx = @"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:urlRegEx options:0 error:&error];
    
    if (regex != nil)
    {
        NSTextCheckingResult *firstMatch=[regex firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
        
        if (firstMatch)
        {
            NSRange resultRange = [firstMatch rangeAtIndex:0];
            NSString *result=[ipAddress substringWithRange:resultRange];
            DDLogInfo(@"isValidatIP result:%@",result);
            return YES;
        }
    }
    return NO;
}

/**
 *This method is used to get ip address
 *获取ip地址
 */
+ (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces))
    {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next)
        {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ )
            {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6))
            {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET)
                {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN))
                    {
                        type = IP_ADDR_IPv4;
                    }
                }
                else
                {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN))
                    {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type)
                {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

/**
 *This method is used to get domain from number
 *获取域名
 */
+(NSString*)domainFromNumber:(NSString*)number
{
    if ([number length] <= 0)
    {
        return @"";
    }
    
    NSRange range = [number rangeOfString:@"@"];
    
    if (range.length != 0)
    {
        range = NSMakeRange(range.location + 1, [number length] - range.location - 1);
        return [number substringWithRange:range];
    }
    else
    {
        return @"";
    }
}

/**
 *This method is used to remove domain field
 *移除域名字段
 */
+ (NSString*)removeDomainField:(NSString*)inString
{
    if ([inString length] <= 0)
    {
        return inString;
    }
    
    NSRange range = [inString rangeOfString:@"@"];
    
    if (range.length != 0)
    {
        range = NSMakeRange(0, range.location);
        return [inString substringWithRange:range];
    }
    else
    {
        return inString;
    }
}

/**
 *This method is used to add domain field
 *增加域名字段
 */
+ (NSString*)addDomainField:(NSString*)inString domain:(NSString*)domain
{
    if (([inString length] <= 0) || ([domain length] <= 0))
        return inString;
    
    return [NSString stringWithFormat:@"%@@%@", inString, domain];
}

/**
 *This method is used to check string format whether is pure number and characters
 *检查字符串是否为纯数字和单词
 *@param string destination string
 *@return YES or NO
 */
+(BOOL)isPureNumberAndCharacters:(NSString *)string
{
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]];
    if(string.length > 0)
    {
        return NO;
    }
    return YES;
}

/**
 *This method is used to check string is empty or not
 *判断字符串是否为非空
 *@param string destination string
 *@return YES or NO
 */
+(BOOL)checkIsNotEmptyString:(NSString *)string
{
    BOOL isNotEmpty = NO;
    if (string == nil || string == NULL || [string isEqualToString:@""])
    {
        isNotEmpty = NO;
    }
    else
    {
        isNotEmpty = YES;
    }
    return isNotEmpty;
}

/**
 *This method is used to get string not nil
 *获取非nil的字符串
 */
+ (NSString *)notNilString:(NSString *)inString
{
    return inString == nil ? @"" : inString;
}

/**
 *This method is used to get local ip address
 *获取本地ip地址
 */
+(NSString *)getLocalIpAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        temp_addr = interfaces;
        NSMutableDictionary *addressDic = [[NSMutableDictionary alloc] init];
        while (temp_addr != NULL)
        {
            if( temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                NSString *addressName = [[NSString stringWithUTF8String:CHECKCSTR(temp_addr->ifa_name)] lowercaseString];
                NSString *addressIp = [NSString stringWithUTF8String:CHECKCSTR(inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr))];
                if([addressName length]==0 || [addressIp length]==0)
                {
                    NSLog(@"Login: name or ip is empty, name = %@, ip = %@",addressName, addressIp);
                    continue;
                }
                [addressDic setObject:addressIp forKey:addressName];
            }
            
            temp_addr = temp_addr->ifa_next;
        }
        
        NSString *wifiConnectionAd = [addressDic objectForKey:@"en0"]; //from wifi
        NSString *wifiConnectionAd1 = [addressDic objectForKey:@"en1"]; //from wifi
        NSString *cellPhoneConnectionAd = [addressDic objectForKey:@"pdp_ip0"]; //from cell phone connection
        if ([wifiConnectionAd length]!=0)
        {
            address = wifiConnectionAd;
        }
        else if ([cellPhoneConnectionAd length]!=0)  //from cellphone connection
        {
            address = cellPhoneConnectionAd;
        }
        else if ([wifiConnectionAd1 length] != 0)
        {
            address = wifiConnectionAd1;
        }
        else
        {
            address = nil;
        }
    }
    freeifaddrs(interfaces);
    return address;

}

/**
 *This method is used to get ip use by host name
 *通过host name获取ip
 */
+ (NSArray *)getIPWithHostName: (NSString *)hostName
{
    NSMutableArray *hostArrayMul = [[NSMutableArray alloc]init];
    struct addrinfo hints;
    memset_s(&hints, sizeof(hints), 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;        // PF_INET if you want only IPv4 addresses
    hints.ai_protocol = IPPROTO_TCP;
    
    struct addrinfo *addrs, *addr;
    
    getaddrinfo([hostName UTF8String], NULL, &hints, &addrs);
    
    for (addr = addrs; addr; addr = addr->ai_next) {
        
        char host[NI_MAXHOST];
        getnameinfo(addr->ai_addr, addr->ai_addrlen, host, sizeof(host), NULL, 0, NI_NUMERICHOST);
        
        NSString *ipstring = [NSString stringWithCString:host encoding:NSUTF8StringEncoding];
        [hostArrayMul addObject:ipstring];
        
    }
    freeaddrinfo(addrs);
    NSArray *hostArray = [NSArray arrayWithArray:hostArrayMul];
    return hostArray;
    
}

/**
 *This method is used to judge whether is ip4 with string
 *判断是否为ip4字符串
 */
+ (BOOL)isIPV4WithString:(NSString *)ipv4Str
{
    NSString  *urlRegEx =@"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:ipv4Str];
    
}

/**
 *This method is used to judge whether is iphone and before ip4
 *判断是否为iphone并且是否为4代之前Iphone
 */
+ (BOOL)isIPhoneAndBeforeIP4
{
    NSString *device = [CommonUtils getDeviceType];
    if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"] || [[UIDevice currentDevice].model isEqualToString:@"iPod touch"])
    {
        
        if (
            [device rangeOfString:@"iPhone1"].location != NSNotFound
            || [device rangeOfString:@"iPhone2"].location != NSNotFound
            || [device rangeOfString:@"iPhone3"].location != NSNotFound
            || [device rangeOfString:@"iPod1"].location != NSNotFound
            || [device rangeOfString:@"iPod2"].location != NSNotFound
            || [device rangeOfString:@"iPod3"].location != NSNotFound
            || [device rangeOfString:@"iPod4"].location != NSNotFound
            )
        {
            return YES;//IP4
        }
        else
        {
            return NO;//IP4S-5S
        }
    }
    else
    {
        return NO;//IPAD
    }
}

/**
 *This method is used to get device type
 *获取设备类型
 */
+ (NSString *)getDeviceType
{
    size_t size;
    sysctlbyname("hw.machine",NULL,&size,NULL,0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine",machine,&size,NULL,0);
    NSString *deviceType = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return deviceType;
}

/**
 *This method is used to judge whether is iphone and after ip4
 *判断是否为iphone并且是否为4代之后Iphone
 */
+(BOOL)isIPhoneAndAfterIP4
{
    NSString *device = [self getDeviceType];
    if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"] || [[UIDevice currentDevice].model isEqualToString:@"iPod touch"])
    {
        if (
            [device rangeOfString:@"iPhone1"].location != NSNotFound
            || [device rangeOfString:@"iPhone2"].location != NSNotFound
            || [device rangeOfString:@"iPhone3"].location != NSNotFound
            || [device rangeOfString:@"iPod1"].location != NSNotFound
            || [device rangeOfString:@"iPod2"].location != NSNotFound
            || [device rangeOfString:@"iPod3"].location != NSNotFound
            || [device rangeOfString:@"iPod4"].location != NSNotFound)
        {
            return NO;
        }
        else
        {
            return YES;
        }
    }
    else
    {
        return NO;
    }
}

/**
 *This method is used to judge whether is iphone4s
 *判断是否为iphone4s
 */
+ (BOOL)isIPhone4S
{
    NSString *deviceName = [self getDeviceType];
    if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"])
    {
        if ([deviceName rangeOfString:@"iPhone4"].location != NSNotFound)
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    else
    {
        return NO;
    }
}

/**
 *This method is used to judge whether is iphone and after ip6
 *判断是否为iphone并且是否为6代之后Iphone
 */
+(BOOL)isIPhoneAndAfter6
{
    NSString *deviceName = [self getDeviceType];
    if ([deviceName isEqualToString:@"iPhone7,1"] || [deviceName isEqualToString:@"iPhone7,2"])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

/**
 *This method is used to judge whether is ipad mini3 and after air
 *判断是否为air之后的Ipad mini 3
 */
+(BOOL)isIPadMini3_AndAfterAir
{
    NSString *device = [self getDeviceType];
    if ([device isEqualToString:@"iPad4,1"] || [device isEqualToString:@"iPad4,2"] || [device isEqualToString:@"iPad4,3"] || [device isEqualToString:@"iPad4,7"] || [device isEqualToString:@"iPad4,8"] || [device isEqualToString:@"iPad4,9"] || [device isEqualToString:@"iPad5,3"] || [device isEqualToString:@"iPad5,4"])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

/**
 *This method is used to get device version
 *获取设备版本
 */
+ (NSString*)getDeviceVersion
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char*)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

/**
 *This method is used to judge whether ip address for string is valid
 *判断ip地址字符串是否为有效
 */
- (BOOL)fromatValiateForIpStr:(NSString *)ipAdress
{
    unichar letter;
    unsigned short intLetter ;
    BOOL isValidate = YES;
    
    NSUInteger len = ipAdress.length;
    for (int i = CONSTVALUEZERO; i < len; i++)
    {
        letter = [ipAdress characterAtIndex:i];
        intLetter = (unsigned short)letter;
        if((intLetter >= 97&& intLetter <= 122) ||
           (intLetter >= 65&& intLetter <= 90) ||
           (intLetter >= 48&& intLetter <= 57) ||
           (intLetter >= 45&& intLetter <= 46))
            
        {
            if ([ipAdress characterAtIndex:0] == 45 ||
                [ipAdress characterAtIndex:len-1] == 45)
            {
                isValidate = NO;
                break;
            }
        }
        else
        {
            isValidate = NO;
            break;
        }
    }
    return isValidate;
    
}

/**
 *This method is used to judge whether ip address for number is valid
 *判断ip地址是否为有效
 */
- (BOOL)fromatValiateForIpNum:(NSString *)ipAdress
{
    BOOL isValidate = NO;
    
    NSArray *adressArr = [ipAdress componentsSeparatedByString:@"."];
    if ([adressArr count] != 4)
    {
        isValidate = NO;
    }
    else
    {
        for (NSString *tempAdrr in adressArr)
        {
            NSString *te;
            
            te = [tempAdrr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([te isEqualToString:@""])
            {
                isValidate = NO;
                break;
            }
            
            NSInteger tempNun = [te integerValue];
            if (tempNun >255 || tempNun < CONSTVALUEZERO)
            {
                isValidate = NO;
                break;
            }
            else
            {
                isValidate = YES;
            }
            
        }
    }
    return isValidate;
}

/**
 *This method is used to set view controller orientation
 *旋转屏幕
 *@param toOrientation
 */
+ (void)setToOrientation:(UIDeviceOrientation)toOrientation
{
    //旋转到toOrientation方向之前，需要先将系统的orientation方向设置成当前界面的方向,确保触发旋转动作
    if (toOrientation == [[UIDevice currentDevice] orientation] && toOrientation == UIDeviceOrientationPortrait)
    {
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
    }
    else if (toOrientation == [[UIDevice currentDevice] orientation]
             && (toOrientation == UIDeviceOrientationLandscapeLeft || toOrientation == UIDeviceOrientationLandscapeRight))
    {
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:UIDeviceOrientationPortrait] forKey:@"orientation"];
    }
    
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:toOrientation] forKey:@"orientation"];
}

/**
 *This method is used to get Image from disk
 *从图片文件夹获取图片
 *@param imageFile image file path
 *@return image
 */
+ (UIImage *) attachImageFile:(NSString*) imageFile {
    UIImage* image = [[ESpaceImageCache sharedInstance] imageWithKey:imageFile];
    if (image) {
        return image;
    } else {
        NSData* imageData = [[NSFileManager defaultManager] contentsAtPath:imageFile];
        UIImage* image = nil;
        if (imageData) {
            image = [UIImage imageWithData:imageData];
            return image;
        }
    }
    return nil;
}

@end
