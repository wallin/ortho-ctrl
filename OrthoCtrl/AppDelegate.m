//
//  AppDelegate.m
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-02-21.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;
@property (nonatomic, strong, readwrite) JFRWebSocket *socket;
@property (nonatomic, readwrite) NSString *url;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    //self.url = @"ws://localhost:8001/ws";
    NSString* ip = [self fetchDeviceURL];
    
    if (ip == nil) {
        // TODO
        NSLog(@"No device found, exiting");
        return;
    }
    
    NSString* url = [NSString stringWithFormat:@"ws://%@/ws", ip];
    
    self.url = url;
    
    self.socket = [[JFRWebSocket alloc] initWithURL:[NSURL URLWithString:self.url] protocols:@[@"chat",@"superchat"]];
    self.socket.delegate = self;
    
    [NSTimer scheduledTimerWithTimeInterval:5.0 target:self
                                   selector:@selector(pingDevice) userInfo:nil repeats:YES];

    
    [self setupStatusItem];
    [self registerHotkeys];
    [self.socket connect];
}

- (NSString*) fetchDeviceURL
{
    NSLog(@"Attempting to get device IP");
    NSURL *url = [NSURL URLWithString:@"http:/www.orthoplay.com"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // Regexp 'window\.speakers_list\s*=\s*\[(.*)\]'
    
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"window\\.speakers_list\\s*=\\s*\\[\"(.*)\"\\]"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    NSTextCheckingResult *match = [regex firstMatchInString:ret
                                                    options:0
                                                      range:NSMakeRange(0, [ret length])];
    if (match) {
        NSRange matchRange = [match rangeAtIndex:1];
        NSString *subString = [ret substringWithRange:matchRange];
        NSLog(@"Device IP found: %@", subString);
        return subString;
    }
    return nil;
}

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
    
    if (self.socket.isConnected) {
        if (isVolumeDown) {
            [self decreaseVolume:anObject];
        }
        if (isVolumeUp) {
            [self increaseVolume:anObject];
        }
    }
}


- (void) setupStatusItem
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"ortho"];
    
    [self updateStatusItemMenu];
}

- (void)updateStatusItemMenu
{
    NSMenu *menu = [[NSMenu alloc] init];
    if ( self.socket.isConnected ) {
        [menu addItemWithTitle:@"Connected" action:@selector(increaseVolume:) keyEquivalent:@""];
    }
    else {
        [menu addItemWithTitle:@"Disconnected" action:@selector(increaseVolume:) keyEquivalent:@""];
    }
        
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Volume up" action:@selector(increaseVolume:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Volume down" action:@selector(decreaseVolume:) keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    
    self.statusItem.menu = menu;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    if (self.socket.isConnected) {
        [self.socket disconnect];
    }
}

#pragma mark - Device actions

- (void) pingDevice
{
    if (self.socket.isConnected) {
        [self.socket writeString:@"{ \"value\": 1234, \"action\": \"speaker_ping\" }"];
    }
}

#pragma mark - Websocket

- (void) websocketDidConnect:(JFRWebSocket*)socket
{
    NSLog(@"websocket is connected:");
    [self.socket writeString:@"{\"protocol_major_version\":0,\"protocol_minor_version\":4,\"action\":\"global_join\"}"];
    [self.socket writeString:@"{\"color_index\":3,\"name\":\"guest\", \"uid\":\"uid-12345\", \"realtime_data\":true ,\"action\":\"group_join\"}"];
    [self updateStatusItemMenu];
}

- (void) websocketDidDisconnect:(JFRWebSocket*)socket error:(NSError*)error
{
    [self updateStatusItemMenu];
    NSLog(@"websocket is disconnected: %@",[error localizedDescription]);
}

- (void) websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)text
{
    //NSLog(@"%@",text);
}

#pragma mark - Menu actions

- (void) increaseVolume:(id)sender
{
    [self.socket writeString:@"{ \"amount\": 4, \"action\": \"group_change_volume\" }"];
}

- (void) decreaseVolume:(id)sender
{
    [self.socket writeString:@"{ \"amount\": -4, \"action\": \"group_change_volume\" }"];
}

@end
