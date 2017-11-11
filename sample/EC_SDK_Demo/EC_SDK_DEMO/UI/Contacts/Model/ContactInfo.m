//
//  ContactInfo.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "ContactInfo.h"

@implementation ContactInfo

+ (ContactInfo *)contactInfoTransformFrom:(TUP_EADDR_S_CONTACTOR_INFO)contactInfo
{
    ContactInfo *info = [[ContactInfo alloc] init];
    info.staffAccount    = [NSString stringWithUTF8String:contactInfo.StaffAccount];
    info.personName      = [NSString stringWithUTF8String:contactInfo.PersonName];
    info.staffno         = [NSString stringWithUTF8String:contactInfo.Staffno];
    info.terminal        = [NSString stringWithUTF8String:contactInfo.Terminal];
    info.terminal2       = [NSString stringWithUTF8String:contactInfo.Terminal2];
    info.deptName        = [NSString stringWithUTF8String:contactInfo.DeptName];
    info.title           = [NSString stringWithUTF8String:contactInfo.Title];
    info.mobile          = [NSString stringWithUTF8String:contactInfo.Mobile];
    info.homephone       = [NSString stringWithUTF8String:contactInfo.Homephone];
    info.email           = [NSString stringWithUTF8String:contactInfo.Email];
    info.officePhone     = [NSString stringWithUTF8String:contactInfo.OfficePhone];
    info.officePhone2    = [NSString stringWithUTF8String:contactInfo.OfficePhone2];
    info.officePhone3    = [NSString stringWithUTF8String:contactInfo.OfficePhone3];
    info.officePhone4    = [NSString stringWithUTF8String:contactInfo.OfficePhone4];
    info.officePhone5    = [NSString stringWithUTF8String:contactInfo.OfficePhone5];
    info.officePhone6    = [NSString stringWithUTF8String:contactInfo.OfficePhone6];
    info.otherphone      = [NSString stringWithUTF8String:contactInfo.Otherphone];
    info.otherphone2     = [NSString stringWithUTF8String:contactInfo.Otherphone2];
    info.gender          = [NSString stringWithUTF8String:contactInfo.Gender];
    info.zipCode         = [NSString stringWithUTF8String:contactInfo.ZipCode];
    info.address         = [NSString stringWithUTF8String:contactInfo.Address];
    info.signature       = [NSString stringWithUTF8String:contactInfo.Signature];
    
    return info;
}

@end
