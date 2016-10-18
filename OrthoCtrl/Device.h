//
//  Device.h
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JFRWebSocket.h"
#import "DeviceDelegate.h"

#include <sys/types.h>
#include <arpa/inet.h>

@interface Device : NSObject
@property NSNetService* service;
@property struct sockaddr_in* ipv4;
@property struct sockaddr_in6* ipv6;
@property JFRWebSocket* socket;
@property NSTimer* timer;
@property (weak) id<DeviceDelegate> delegate;
@property BOOL isConnected;
@property int volume;

- (Device*) init: (NSNetService*) service;

- (JFRWebSocket*) createSocket;

- (void) connect;
- (void) disconnect;

- (void) decreaseVolume;
- (void) increaseVolume;
- (void) updateVolume: (int) volume;

@end
