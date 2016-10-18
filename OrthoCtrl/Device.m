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
                struct sockaddr_in *ip4;
                char dest[INET_ADDRSTRLEN];
                self.ipv4 = (struct sockaddr_in *) [myData bytes];
                addressString = [NSString stringWithFormat: @"IP4: %s", inet_ntop(AF_INET, &self.ipv4->sin_addr, dest, sizeof dest)];
            }
                break;
                
            case AF_INET6: {
                struct sockaddr_in6 *ip6;
                char dest[INET6_ADDRSTRLEN];
                self.ipv6 = (struct sockaddr_in6 *) [myData bytes];
                addressString = [NSString stringWithFormat: @"IP6: %s",  inet_ntop(AF_INET6, &self.ipv6->sin6_addr, dest, sizeof dest)];
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
    NSLog(@"setVolume, %d", volume);
    NSString* payload = [NSString stringWithFormat:@"{ \"vol\": %d, \"action\": \"group_set_volume\" }", volume];
    [self websocketWriteString:payload];
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

- (void) handleResponse:(NSString*) response json: (NSDictionary*) json
{
    NSLog(@"received response: %@", response);
    
    NSArray* responses = @[@"global_joined", @"group_joined"];
    NSUInteger match = [responses indexOfObject:response];
    NSArray* state = nil;
    
    switch (match) {
        case 0:
            [self joinGroup];
            break;
        case 1:
            state = [json objectForKey:@"state"];
            for (NSDictionary* item in state) {
                [self handleUpdate:[item valueForKey:@"update"] json: item];
            }
            break;
        default:
            break;
    }
}

- (void) handleUpdate:(NSString*) update json: (NSDictionary*) json
{
    NSLog(@"received update: %@", update);
    
    NSArray* updates = @[@"group_volume_changed"];
    NSUInteger match = [updates indexOfObject:update];

    switch (match) {
        case 0:
            self.volume = [[json valueForKey:@"vol"] intValue];
            NSLog(@"new volume: %d", self.volume);
            break;
            
        default:
            break;
    }
}
@end
