//
//  ECSConfInfo+StructParase.h
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "ECConfInfo.h"
#import "tup_confctrl_def.h"

@interface ECConfInfo (StructParase)
+(ECConfInfo *)returnECConfInfoWith:(CONFCTRL_S_CONF_LIST_INFO)confListInfo;
@end
