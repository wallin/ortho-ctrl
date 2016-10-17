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
        int port=0;
        struct sockaddr *addressGeneric;
        
        addressGeneric = (struct sockaddr *) [myData bytes];
        
        switch( addressGeneric->sa_family ) {
            case AF_INET: {
                struct sockaddr_in *ip4;
                char dest[INET_ADDRSTRLEN];
                self.ipv4 = (struct sockaddr_in *) [myData bytes];
                port = ntohs(ip4->sin_port);
                addressString = [NSString stringWithFormat: @"IP4: %s Port: %d", inet_ntop(AF_INET, &self.ipv4->sin_addr, dest, sizeof dest),port];
            }
                break;
                
            case AF_INET6: {
                struct sockaddr_in6 *ip6;
                char dest[INET6_ADDRSTRLEN];
                self.ipv6 = (struct sockaddr_in6 *) [myData bytes];
                port = ntohs(ip6->sin6_port);
                addressString = [NSString stringWithFormat: @"IP6: %s Port: %d",  inet_ntop(AF_INET6, &self.ipv6->sin6_addr, dest, sizeof dest),port];
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
    if (self.socket.isConnected) {
        [self.socket writeString:@"{ \"amount\": -4, \"action\": \"group_change_volume\" }"];
    }
}

- (void) increaseVolume
{
    NSLog(@"increaseVolume");
    if (self.socket.isConnected) {
        [self.socket writeString:@"{ \"amount\": 4, \"action\": \"group_change_volume\" }"];
    }
}

- (void) updateVolume:(int)volume
{
    NSLog(@"setVolume, %d", volume);
    if (self.socket.isConnected) {
        NSString* payload = [NSString stringWithFormat:@"{ \"vol\": %d, \"action\": \"group_set_volume\" }", volume];
        [self.socket writeString:payload];
    }
}

- (void) ping
{
    NSLog(@"ping");
    if (self.socket.isConnected) {
        [self.socket writeString:@"{ \"value\": 1234, \"action\": \"speaker_ping\" }"];
    }
}

#pragma mark - Websocket

- (void) websocketDidConnect:(JFRWebSocket*)socket
{
    NSLog(@"websocket is connected:");
    [self.socket writeString:@"{\"protocol_major_version\":0,\"protocol_minor_version\":4,\"action\":\"global_join\"}"];
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
    if (response == nil) {
        response = [json valueForKey:@"update"];
    }
    NSLog(@"received message: %@", response);
    
    NSArray* responses = @[@"global_joined", @"group_volume_changed"];
    NSUInteger match = [responses indexOfObject:response];
    switch (match) {
        case 0:
            [self.socket writeString:@"{\"color_index\":3,\"name\":\"guest\", \"uid\":\"uid-12345\", \"realtime_data\":true ,\"action\":\"group_join\"}"];
            break;
        case 1:
            self.volume = [json valueForKey:@"vol"];
            NSLog(@"new volume: %@", self.volume);
            break;
        default:
            break;
    }
    
}

@end
