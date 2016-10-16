//
//  AppDelegate.m
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-02-21.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

// {
//     "description": "Set the volume to an absolute value",
//     "type": "object",
//     "properties": {
//         "action": {
//             "enum": [
//                      "group_set_volume"
//                      ],
//             "type": "string"
//         },
//         "vol": {
//             "type": "number",
//             "minimum": 0,
//             "maximum": 100
//         }
//     },
//     "required": [
//                  "action",
//                  "vol"
//                  ],
//     "additionalProperties": false
// },
// {
//     "description": "Make a relative volume change",
//     "type": "object",
//     "properties": {
//         "action": {
//             "enum": [
//                      "group_change_volume"
//                      ],
//             "type": "string"
//         },
//         "amount": {
//             "type": "number",
//             "minimum": -100,
//             "maximum": 100
//         }
//     },
//     "required": [
//                  "action",
//                  "amount"
//                  ],
//     "additionalProperties": false
// }


#import "AppDelegate.h"
#import "DeviceDiscoverer.h"
#import "Device.h"
#include <sys/types.h>
#include <arpa/inet.h>

@interface AppDelegate ()

@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;
//@property (nonatomic, strong, readwrite) JFRWebSocket *socket;
@property (nonatomic, readwrite) NSString *url;
@property Device* selectedDevice;
@property DeviceDiscoverer*     disco;

@end

@class FindServices;
@class Service;

@protocol FindServicesDelegate <NSObject>

- (void)findServices:(FindServices*)theFindServices didFindService:(Service*)theService;

- (void)findServices:(FindServices*)theFindServices didLoseService:(Service*)theService;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self startDiscovery];
    [self setupStatusItem];
    [self registerHotkeys];
}

#pragma mark - Bonjour

- (void) startDiscovery
{
    self.disco = [[DeviceDiscoverer alloc] init];
    self.disco.delegate = self;
    [self.disco start];
}

- (void) connectDevice: (Device*) device
{
    NSLog(@"connecting to device: %@", device.service.name);
    if (self.selectedDevice != nil) {
        [self.selectedDevice disconnect];
        self.selectedDevice.delegate = nil;
    }
    self.selectedDevice = device;
    
    self.selectedDevice.delegate = self;
    [self.selectedDevice connect];
}

- (void)findDevices:(DeviceDiscoverer*)devices didFindDevice:(Device*)device
{
    NSLog(@"Found device");
    // Automatically connect to first found device
    if (self.selectedDevice == nil) {
        [self connectDevice:device];
    }
    [self updateStatusItemMenu];
}

- (void)findDevices:(DeviceDiscoverer*)devices didLooseDevice:(Device*)device
{
    NSLog(@"Lost device");
    if (self.selectedDevice == device) {
        [device disconnect];
        self.selectedDevice = nil;
    }
    [self updateStatusItemMenu];
}

#pragma mark - Hotkeys

- (void) registerHotkeys
{
    if(![DDHotKeyCenter.sharedHotKeyCenter registerHotKeyWithKeyCode:35
                                                       modifierFlags:(NSControlKeyMask | NSAlternateKeyMask)
                                                              target:self
                                                              action:@selector(hotkeyWithEvent:object:)
                                                              object:@"Volume Up"]) {
        NSLog(@"failed to register hotkey.");
    }
    else {
        NSLog(@"registered hotkey - volume up");
    }
    
    
    if(![DDHotKeyCenter.sharedHotKeyCenter registerHotKeyWithKeyCode:45
                                                       modifierFlags:(NSControlKeyMask | NSAlternateKeyMask)
                                                              target:self
                                                              action:@selector(hotkeyWithEvent:object:)
                                                              object:@"Volume Down"]) {
        NSLog(@"failed to register hotkey.");
    }
    else {
        NSLog(@"registered hotkey - volume down");
    }
}

- (void) hotkeyWithEvent:(NSEvent *)hkEvent object:(id)anObject {
    NSLog(@"%@ Hotkey Pressed",(NSString*)anObject);
    BOOL isVolumeUp = [(NSString*)anObject isEqualToString:@"Volume Up"];
    BOOL isVolumeDown = [(NSString*)anObject isEqualToString:@"Volume Down"];
    
    if (self.selectedDevice) {
        if (isVolumeDown) {
            [self decreaseVolume:anObject];
        }
        if (isVolumeUp) {
            [self increaseVolume:anObject];
        }
    }
}

#pragma mark - Status menu

- (void) setupStatusItem
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"ortho"];
    
    [self updateStatusItemMenu];
}

- (void)updateStatusItemMenu
{
    NSMenu *menu = [[NSMenu alloc] init];
    NSMutableDictionary*  devices = [self.disco devices];

    NSMenuItem* volUp   = [menu addItemWithTitle:@"Volume up" action:nil keyEquivalent:@"p"];
    NSMenuItem* volDown = [menu addItemWithTitle:@"Volume down" action:nil keyEquivalent:@"n"];
    [volUp setKeyEquivalentModifierMask: NSAlternateKeyMask | NSControlKeyMask];
    [volDown setKeyEquivalentModifierMask: NSAlternateKeyMask | NSControlKeyMask];
    if (devices.count > 0) {
        [volUp setAction:@selector(increaseVolume:)];
        [volDown setAction:@selector(decreaseVolume:)];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    Device* device = nil;
    for (NSString* key in devices)
    {
        device = [devices objectForKey:key];
        NSMenuItem* item = [menu addItemWithTitle:device.service.name action:@selector(selectDevice:) keyEquivalent:@""];
        [item setRepresentedObject:device];
        if (device == self.selectedDevice && self.selectedDevice.isConnected) {
            [item setState:NSOnState];
        }
    }
    if (devices.count == 0) {
        [menu addItemWithTitle:@"No speakers found" action:nil keyEquivalent:@""];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    
    self.statusItem.menu = menu;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    if (self.selectedDevice.isConnected) {
        [self.selectedDevice disconnect];
    }
}

#pragma mark - Websocket

- (void) deviceDidConnect:(Device*)device
{
    NSLog(@"device is connected");
    [self updateStatusItemMenu];
}

- (void) deviceDidDisconnect:(Device*)device
{
    NSLog(@"device is disconnected:");
    [self updateStatusItemMenu];
}

- (void) websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)text
{
    //NSLog(@"%@",text);
}

#pragma mark - Menu actions

- (void) increaseVolume:(id)sender
{
    if (self.selectedDevice != nil) {
        [self.selectedDevice increaseVolume];
    }
}

- (void) decreaseVolume:(id)sender
{
    if (self.selectedDevice != nil) {
        [self.selectedDevice decreaseVolume];
    }
}

- (void) selectDevice:(id)sender
{
    Device* device = [sender representedObject];
    [self connectDevice:device];
}


@end
