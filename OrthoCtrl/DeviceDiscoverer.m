//
//  DeviceDiscoverer.m
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DeviceDiscoverer.h"

#include <sys/types.h>
#include <arpa/inet.h>

@interface DeviceDiscoverer ()

@property NSNetServiceBrowser*  browser;
@property NSMutableArray*       resolving;

@end

@implementation DeviceDiscoverer

- (DeviceDiscoverer*) init
{
    self = [super init];
    if (self != nil)
    {
        self.browser   = [[NSNetServiceBrowser alloc] init];
        self.resolving = [NSMutableArray arrayWithCapacity:8];
        self.devices   = [NSMutableDictionary dictionaryWithCapacity:8];
        
        self.browser.delegate = self;
    }
    
    return self;
}

- (void) start
{
    NSLog(@"Starting device discovery");
    [self.browser searchForServicesOfType:@"_od11._tcp." inDomain:@"local."];
}


#pragma mark - Browser delegate methods

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)theBrowser
{
    NSLog(@"netServiceBrowserWillSearch:\n");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)theBrowser didNotSearch:(NSDictionary *)theErrors
{
    NSLog(@"netServiceBrowser:didNotSearch: %@", theErrors);
}

- (void)netServiceBrowser:
(NSNetServiceBrowser *)aNetServiceBrowser
           didFindService:
(NSNetService *)theService
               moreComing:
(BOOL)moreComing
{
    NSLog(@"netServiceBrowser:didFindService: %@", theService);
    
    [self.resolving addObject:theService];
    theService.delegate = self;
    [theService resolveWithTimeout:5.0];
}

- (void)netServiceBrowser:
(NSNetServiceBrowser *)aNetServiceBrowser
         didRemoveService:
(NSNetService *)theService
               moreComing:
(BOOL)moreComing
{
    NSLog(@"netServiceBrowser:didRemoveService: %@", theService);
    
    Device* device = [self.devices objectForKey:theService.name];
    
    if (device != nil)
    {
        [self.devices removeObjectForKey:theService.name];
        [self.delegate findDevices:self didLooseDevice:device];
    }
    else
    {
        NSLog(@"%@ removed without being found ?", theService.name);
    }
}

// NSNetServiceDelegate

- (void)netServiceWillResolve:(NSNetService *)theService
{
    NSLog(@"netServiceWillResolve");
}

- (void)netServiceDidResolveAddress:(NSNetService *)theService
{
    NSUInteger nAddresses = [[theService addresses] count];

    NSLog(@"netServiceDidResolveAddress: %@ nAddresses == %lu", theService, (unsigned long)nAddresses);
        
    if (nAddresses != 0)
    {
        Device* device = [[Device alloc] init:theService];
        
        [self.resolving removeObject:theService];
        [self.devices setObject:device forKey:theService.name];
        [self.delegate findDevices:self didFindDevice:device];
    }
    else
    {
        Device* device = [self.devices objectForKey:theService.name];
        
        if (device != nil)
        {
            NSLog(@"device %@ now has 0 addresses !", theService.name);
        }
        else
        {
            NSLog(@"resolve failed ? %@ has 0 addresses", theService.name);
        }
    }
}

- (void)netService:(NSNetService *)theService didNotResolve:(NSDictionary *)theErrors
{
    NSLog(@"netService:didNotResolve: %@ %@", theService, theErrors);
    
    [self.resolving removeObject:theService];
}


@end
