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
@property (nonatomic, readwrite) NSString *url;
@property Device* selectedDevice;
@property DeviceDiscoverer* disco;

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
    // http://boredzo.org/blog/wp-content/uploads/2007/05/IMTx-virtual-keycodes.pdf
    NSArray* keys = @[
                      @[@35, @"Volume Up"],
                      @[@45, @"Volume Down"],
                      @[@3, @"Next Track"],
                      @[@11, @"Prev Track"],
                      @[@46, @"Toggle Playback"]
                    ];
    
    for (NSArray* key in keys) {
        if(![DDHotKeyCenter.sharedHotKeyCenter registerHotKeyWithKeyCode:[key[0] integerValue]
                                                           modifierFlags:(NSControlKeyMask | NSAlternateKeyMask)
                                                                  target:self
                                                                  action:@selector(hotkeyWithEvent:object:)
                                                                  object:key[1]]) {
            NSLog(@"failed to register hotkey.");
        }
        else {
            NSLog(@"registered hotkey - %@", key[1]);
        }
    }
}

- (void) hotkeyWithEvent:(NSEvent *)hkEvent object:(id)anObject {
    NSLog(@"%@ Hotkey Pressed",(NSString*)anObject);
    
    if (!self.selectedDevice) {
        return;
    }
    
    NSArray* items = @[@"Volume Up", @"Volume Down", @"Next Track", @"Prev Track", @"Toggle Playback"];
    NSUInteger match = [items indexOfObject:(NSString*)anObject];
    
    switch (match) {
        case 0:
            [self.selectedDevice increaseVolume];
            break;
        case 1:
            [self.selectedDevice decreaseVolume];
            break;
        case 2:
            [self.selectedDevice skipToNextTrack];
            break;
        case 3:
            [self.selectedDevice skipToPreviousTrack];
            break;
        case 4:
            [self.selectedDevice togglePlayback];

            break;

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

    
    double volumeValue = 0;
    if (self.selectedDevice != nil) {
        volumeValue = self.selectedDevice.volume;
    }
    [menu addItemWithTitle:@"Volume:" action:nil keyEquivalent:@""];
    NSSlider* volumeSlider = [NSSlider sliderWithValue:volumeValue minValue:0 maxValue:100 target:nil action:nil];
    volumeSlider.frame = CGRectMake(20, 0, 150.0, 25.0);
    NSMenuItem* volumeItem = [[NSMenuItem alloc] init];
    [volumeItem setIndentationLevel:2];
    NSView* volumeView = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 180, 25)];
    [volumeView addSubview:volumeSlider];
    [volumeItem setView:volumeView];
    [menu addItem:volumeItem];
    if (self.selectedDevice) {
        [volumeSlider setAction:@selector(setVolume:)];
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

#pragma mark - Device

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

- (void) deviceDidUpdateVolume:(Device*)device
{
    [self updateStatusItemMenu];
}

#pragma mark - Menu actions


- (void) setVolume:(NSSlider*)slider
{
    int requestedVolume = [slider intValue];
    if (self.selectedDevice != nil) {
        NSLog(@"requested volume: %d (was %d)", requestedVolume, self.selectedDevice.volume);
        [self.selectedDevice updateVolume:requestedVolume];
    }
}

- (void) selectDevice:(id)sender
{
    Device* device = [sender representedObject];
    [self connectDevice:device];
}


@end
