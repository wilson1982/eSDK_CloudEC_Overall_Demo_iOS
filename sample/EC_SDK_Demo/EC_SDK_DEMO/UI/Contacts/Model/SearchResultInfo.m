//
//  SearchResultInfo.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "SearchResultInfo.h"

@implementation SearchResultInfo

+ (SearchResultInfo *)resultInfoTransformFrom:(TUP_EADDR_S_SEARCH_DEPT_RESULT *)result
{
    SearchResultInfo *info = [[SearchResultInfo alloc] init];
    info.ret                  = result->ret;
    info.ulItemNum            = result->ulItemNum;
    info.ulSeqNo              = result->ulSeqNo;
    info.acSearchDepId        = [NSString stringWithUTF8String:result->acSearchDepId];
    
    return info;
}

@end
