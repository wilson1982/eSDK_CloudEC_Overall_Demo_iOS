//
//  SearchResultInfo.h
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import <Foundation/Foundation.h>
#import "tup_eaddr_def.h"

@interface SearchResultInfo : NSObject

@property (assign, nonatomic) int ret;                    // result number
@property (assign, nonatomic) int ulSeqNo;                // sequence number
@property (assign, nonatomic) int ulItemNum;              // item number
@property (copy, nonatomic) NSString *acSearchDepId;      // searching department id


/**
 This method is used to transform TUP_EADDR_S_SEARCH_DEPT_RESULT data to SearchResultInfo data

 @param result TUP_EADDR_S_SEARCH_DEPT_RESULT
 @return SearchResultInfo
 */
+ (SearchResultInfo *)resultInfoTransformFrom:(TUP_EADDR_S_SEARCH_DEPT_RESULT *)result;

@end
