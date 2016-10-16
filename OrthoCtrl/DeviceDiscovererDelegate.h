//
//  DeviceDiscovererDelegate.h
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#ifndef DeviceDiscovererDelegate_h
#define DeviceDiscovererDelegate_h

# import "Device.h"

@class DeviceDiscoverer;

@protocol DeviceDiscovererDelegate <NSObject>

- (void)findDevices:(DeviceDiscoverer*)devices didFindDevice:(Device*)device;

- (void)findDevices:(DeviceDiscoverer*)devices didLooseDevice:(Device*)device;

@end

#endif /* DeviceDiscovererDelegate_h */
