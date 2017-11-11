//
//  DeptInfo.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "DeptInfo.h"

@implementation DeptInfo

+ (DeptInfo *)deptInfoTransformFrom:(TUP_EADDR_S_DEPT_INFO)deptInfo
{
    DeptInfo *info = [[DeptInfo alloc] init];
    info.deptId       = [NSString stringWithUTF8String:deptInfo.deptId];
    info.parentId     = [NSString stringWithUTF8String:deptInfo.parentId];
    info.deptName     = [NSString stringWithUTF8String:deptInfo.deptName];
    
    return info;
}

@end
