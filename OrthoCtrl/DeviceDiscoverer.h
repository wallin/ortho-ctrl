//
//  DeviceDiscoverer.h
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#ifndef DeviceDiscoverer_h
#define DeviceDiscoverer_h

#import "DeviceDiscovererDelegate.h"

@interface DeviceDiscoverer : NSObject<NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (weak) id<DeviceDiscovererDelegate> delegate;
@property NSMutableDictionary*  devices;

- (void)start;

@end

#endif /* DeviceDiscoverer_h */
