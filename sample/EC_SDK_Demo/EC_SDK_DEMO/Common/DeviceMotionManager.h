//
//  ESpaceDeviceMotionManager.h
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define ESPACE_DEVICE_ORIENTATION_CHANGED   @"#define ESPACE_DEVICE_ORIENTATION_CHANGED"

@interface DeviceMotionManager : NSObject

+ (instancetype)sharedInstance;

- (void)startDeviceMotionManager;

- (void)stopDeviceMotionManager;

- (BOOL)adjustCamerRotation:(NSUInteger *)cameraRotation
            displayRotation:(NSUInteger *)displayRotation
               byCamerIndex:(NSUInteger)index
       interfaceOrientation:(UIInterfaceOrientation)interface;


@end
