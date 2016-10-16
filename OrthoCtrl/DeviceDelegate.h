//
//  DeviceDelegate.h
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#ifndef DeviceDelegate_h
#define DeviceDelegate_h

# import "Device.h"

@class Device;

@protocol DeviceDelegate <NSObject>

- (void)deviceDidConnect:(Device*)device;

- (void)deviceDidDisconnect:(Device*)device;

@end

#endif /* DeviceDelegate_h */
