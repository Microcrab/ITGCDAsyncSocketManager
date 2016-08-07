//
//  ITGCDSocketManager.h
//  ServerAndMusicDemo
//
//  Created by pengchengwu on 16/7/13.
//  Copyright © 2016年 pengchengwu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
@class ITGCDSocketManagerServerInfo;

#define ITGCDSocketManagerSetObject(dict,object,type) [dict setObject:object forKey:[NSNumber numberWithUnsignedShort:type]]
#define ITGCDSocketManagerFetchObject(dict,type) [dict objectForKey:[NSNumber numberWithUnsignedShort:type]]
#define ITGCDSocketManagerRemoveObject(dict,type) [dict removeObjectForKey:[NSNumber numberWithUnsignedShort:type]]
#define ITGCDSocketManagerNoticeDidReceiveData(openPortType) [NSString stringWithFormat:@"ITGCDSocketManagerNoticeDidReceiveData%hu",openPortType]

typedef NS_ENUM(uint16_t, ITServerType) {
    ITServerTypeIntretech,
    ITServerTypeNoneCenter,
    ITServerTypeCarMap,
};

typedef NS_ENUM(uint16_t, ITOpenPortType) {
    ITOpenPortTypeSTMusic = 2015,
    ITOpenPortTypeB,
    ITOpenPortTypeC,
    ITOpenPortTypeD,
};

@interface ITGCDSocketManager : NSObject

@property (nonatomic, strong) NSMutableDictionary<NSNumber *,ITGCDSocketManagerServerInfo *> * serverInfoDict;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,GCDAsyncSocket *> * serverSocketsDict;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,GCDAsyncSocket *> * listenerSocketsDict;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,GCDAsyncSocket *> * clientSocketsDict;
@property (nonatomic, assign, getter=isServerRunning) BOOL serverRunning;

+ (instancetype)sharedInstance;

- (void)connectToServer:(ITServerType)serverType host:(NSString*)host port:(uint16_t)port;

- (void)disconnectWithServer:(ITServerType)serverType;

- (void)disconnectWithAllServer;

- (BOOL)openServerWithPort:(ITOpenPortType)portType;

- (BOOL)openServerWithPorts:(ITOpenPortType)portType,...;

- (void)closeServerWithPort:(ITOpenPortType)portType;

- (void)closeServerWithPorts:(ITOpenPortType)portType,...;

- (void)closeServerWithAllPorts;

- (BOOL)sendDataToServer:(ITServerType)serverType data:(NSData *)data;

- (BOOL)sendDataToClient:(ITOpenPortType)portType data:(NSData *)data;

@end

@interface ITGCDSocketManagerServerInfo : NSObject

@property (nonatomic, assign) ITServerType serverType;
@property (nonatomic, copy) NSString * host;
@property (nonatomic, assign) ITOpenPortType port;

+ (instancetype)configWithServer:(ITServerType)serverType host:(NSString *)host port:(ITOpenPortType)port;

@end

@interface ITGCDSocketManagerClientInfo : NSObject

@property (nonatomic, assign) ITOpenPortType portType;
@property (nonatomic, strong) NSData * receivedData;

+ (instancetype)configWithClient:(ITOpenPortType)portType receivedData:(NSData *)receivedData;

@end
