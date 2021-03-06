//
//  Device.m
//  OrthoCtrl
//
//  Created by Sebastian Wallin on 2016-10-14.
//  Copyright © 2016 Sebastian Wallin. All rights reserved.
//

#import "Device.h"

#include <sys/types.h>
#include <arpa/inet.h>

@implementation Device

- (Device*) init:(NSNetService *)service
{
    self = [super init];
    self.pendingVolumeUpdate = -1;
    self.isPlaying = false;
    self.groupNames = [[NSMutableDictionary alloc] init];
    self.speakers = [[NSMutableDictionary alloc] init];
    self.ipString = nil;
    
    if (self != nil)
    {
        self.service = service;
        [self setIPs];
    }
    
    return self;
}

- (NSNetService*) getService
{
    return self.service;
}

- (void) setIPs
{

    for (NSData* myData in self.service.addresses)
    {
        NSString *addressString;
        struct sockaddr *addressGeneric;
        
        addressGeneric = (struct sockaddr *) [myData bytes];
        
        switch( addressGeneric->sa_family ) {
            case AF_INET: {
                char dest[INET_ADDRSTRLEN];
                self.ipv4 = (struct sockaddr_in *) [myData bytes];
                // TODO: Only handles IPv4
                self.ipString = [NSString stringWithFormat: @"%s", inet_ntop(AF_INET, &self.ipv4->sin_addr, dest, sizeof dest)];
                addressString = [NSString stringWithFormat: @"IP4: %@", self.ipString];
            }
                break;
                
            case AF_INET6: {
                char dest[INET6_ADDRSTRLEN];
                self.ipv6 = (struct sockaddr_in6 *) [myData bytes];
                addressString = [NSString stringWithFormat: @"IP6: %s", inet_ntop(AF_INET6, &self.ipv6->sin6_addr, dest, sizeof dest)];
            }
                break;
            default:
                addressString=@"Unknown family";
                break;
        }
        NSLog(@"Client Address: %@",addressString);
    }
}

- (JFRWebSocket*) createSocket
{
    char dest[INET_ADDRSTRLEN];
    // TODO: this only handles IPv4
    const char* ip = inet_ntop(AF_INET, &self.ipv4->sin_addr, dest, sizeof dest);
    NSString* url = [NSString stringWithFormat:@"ws://%s/ws", ip];
    
    //NSString *url = @"ws://127.0.0.1:8001/ws";
    
    return [[JFRWebSocket alloc] initWithURL:[NSURL URLWithString:url] protocols:@[@"chat",@"superchat"]];
}

- (void) connect
{
    [self disconnect];
    if (self.socket == nil) {
        self.socket = [self createSocket];
    }
    
    self.socket.delegate = self;
    [self.socket connect];
    [self startTimer];
}

- (void) disconnect
{
    if (self.socket != nil && self.socket.isConnected) {
        [self.socket disconnect];
    }
    self.socket = nil;
    [self.timer invalidate];
    
}

- (void) startTimer
{
    if (self.timer != nil && self.timer.isValid) {
        [self.timer invalidate];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self
                                                selector:@selector(ping) userInfo:nil repeats:YES];

}

#pragma mark - Actions


- (void) decreaseVolume
{
    NSLog(@"decreaseVolume");
    [self websocketWriteString:@"{ \"amount\": -4, \"action\": \"group_change_volume\" }"];
}

- (void) increaseVolume
{
    NSLog(@"increaseVolume");
    [self websocketWriteString:@"{ \"amount\": 4, \"action\": \"group_change_volume\" }"];
}

- (void) updateVolume:(int)volume
{
    if (volume == self.volume) {
        return;
    }
    NSLog(@"setVolume, %d", volume);
    if (self.isUpdatingVolume) {
        self.pendingVolumeUpdate = volume;
    }
    else {
        NSString* payload = [NSString stringWithFormat:@"{ \"vol\": %d, \"action\": \"group_set_volume\" }", volume];
        self.isUpdatingVolume = true;
        [self websocketWriteString:payload];
    }
}

- (void) skipToNextTrack
{
    [self websocketWriteString:@"{ \"action\": \"track_skip_to_next\" }"];
}

- (void) skipToPreviousTrack
{
    [self websocketWriteString:@"{ \"action\": \"track_skip_to_prev\" }"];
}

- (void) stopPlayback
{
    [self websocketWriteString:@"{ \"action\": \"playback_stop\" }"];
}

- (void) startPlayback
{
    [self websocketWriteString:@"{ \"action\": \"playback_start\" }"];
}

- (void) togglePlayback
{
    if (self.isPlaying) {
        [self stopPlayback];
    }
    else {
        [self startPlayback];
    }
}

- (void) ping
{
    NSLog(@"ping");
    [self websocketWriteString:@"{ \"value\": 1234, \"action\": \"speaker_ping\" }"];
}

- (void) joinGlobal
{
    [self websocketWriteString:@"{\"protocol_major_version\":0,\"protocol_minor_version\":4,\"action\":\"global_join\"}"];
}

- (void) joinGroup
{
    [self websocketWriteString:@"{\"color_index\":3,\"name\":\"guest\", \"uid\":\"uid-12345\", \"realtime_data\":true ,\"action\":\"group_join\"}"];
}

#pragma mark - Websocket

- (void) websocketWriteString: (NSString*) text
{
    if (self.socket.isConnected) {
        [self.socket writeString:text];
    }
}

- (void) websocketDidConnect:(JFRWebSocket*)socket
{
    NSLog(@"websocket is connected:");
    [self joinGlobal];
    self.isConnected = true;
    [self.delegate deviceDidConnect:self];
}

- (void) websocketDidDisconnect:(JFRWebSocket*)socket error:(NSError*)error
{
    NSLog(@"websocket is disconnected: %@",[error localizedDescription]);
    self.isConnected = false;
    [self.delegate deviceDidDisconnect:self];
}

- (void) websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)message
{
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:nil error:nil];
    if (json == nil)
    {
        NSLog(@"Error parsing JSON message");
        return;
    }
    NSString *response = [json valueForKey:@"response"];
    // No response, but check for update
    if (response != nil) {
        [self handleResponse:response json:json];
    }
    else {
        response = [json valueForKey:@"update"];
        [self handleUpdate:response json:json];
    }
}

# pragma mark - Response handlers

- (void) handleResponse:(NSString*) response json: (NSDictionary*) json
{
    NSLog(@"received response: %@", response);
    
    NSArray* responses = @[@"global_joined", @"group_joined"];
    NSUInteger match = [responses indexOfObject:response];
    
    switch (match) {
        case 0:
            [self handleStateUpdates:[json objectForKey:@"state"]];
            [self.delegate deviceDidGetGlobalState:self];
            [self joinGroup];
            break;
        case 1:
            [self handleStateUpdates:[json objectForKey:@"state"]];
            break;
        default:
            break;
    }
}

- (void) handleStateUpdates:(NSArray*) state
{
    if (state != nil) {
        for (NSDictionary* item in state) {
            [self handleUpdate:[item valueForKey:@"update"] json: item];
        }
    }
}

// Generic handler for commands present in the `state` key
- (void) handleUpdate:(NSString*) update json: (NSDictionary*) json
{
    NSLog(@"received update: %@", update);
    
    NSArray* updates = @[@"group_volume_changed", @"playback_state_changed", @"speaker_group", @"speaker_added"];
    NSUInteger match = [updates indexOfObject:update];

    switch (match) {
        case 0:
            self.volume = [[json valueForKey:@"vol"] intValue];
            NSLog(@"new volume: %d", self.volume);
            self.isUpdatingVolume = false;
            [self.delegate deviceDidUpdateVolume: self];
            // Check if pending volume update
            if (self.pendingVolumeUpdate >= 0) {
                [self updateVolume:self.pendingVolumeUpdate];
                self.pendingVolumeUpdate = -1;
            }
            break;
        case 1:
            self.isPlaying = [[json valueForKey:@"playing"] boolValue];
            NSLog(@"playback state changed. playing: %d", self.isPlaying);
            break;
        case 2:
            // Save a list of group names from the global state, indexed by group_id
            [self.groupNames setValue:[json valueForKey:@"group_name"] forKey:[json valueForKey:@"group_id"]];
            NSLog(@"groups: %@", self.groupNames);
            break;
        case 3: {
            // Save a list of speakers connected to this group, indexed by IPv4. This way we can map
            // IP to group name later.
            NSDictionary* speaker = [json objectForKey:@"speaker"];
            [self.speakers setValue:speaker forKey:[speaker valueForKey:@"ip"]];
        }
            break;
        default:
            break;
    }
}
@end
