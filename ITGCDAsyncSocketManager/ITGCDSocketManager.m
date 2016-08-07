//
//  ITGCDSocketManager.m
//  ServerAndMusicDemo
//
//  Created by pengchengwu on 16/7/13.
//  Copyright © 2016年 pengchengwu. All rights reserved.
//

#import "ITGCDSocketManager.h"

#define TimeoutOfWrite -1.
#define TimeoutOfRead -1.
#define TimeoutOfReadExtension -1.

@interface ITGCDSocketManager()<GCDAsyncSocketDelegate>

@property (nonatomic, assign) long sendTag;
@property (nonatomic, assign) long receivedTag;
@property (nonatomic, strong) NSData * waitingSendData;
@property (nonatomic, strong) GCDAsyncSocket * waitingSendSock;

@end

@implementation ITGCDSocketManager

+ (instancetype)sharedInstance {
    static dispatch_once_t __singletonToken;
    static ITGCDSocketManager *__singleton__;
    dispatch_once( &__singletonToken, ^{
        __singleton__ = [[self alloc] init];
    } );
    return __singleton__;
}

- (instancetype)init {
    if (self = [super init]) {
//        self.serverRunning = NO;
        self.sendTag = 0;
        self.receivedTag = 0;
    }
    return self;
}

- (GCDAsyncSocket *)initializeAsyncSocket {
    GCDAsyncSocket *sock = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [sock setIPv4PreferredOverIPv6:NO];
    [sock setAutoDisconnectOnClosedReadStream:NO];
    return sock;
}

- (void)connectToServer:(ITServerType)serverType host:(NSString*)host port:(uint16_t)port {
    NSError *error = nil;
    GCDAsyncSocket *serverSock = nil;
    ITGCDSocketManagerSetObject(self.serverInfoDict, [ITGCDSocketManagerServerInfo configWithServer:serverType host:host port:port], serverType);
    if ((serverSock = ITGCDSocketManagerFetchObject(self.serverSocketsDict, serverType))) {
        if (serverSock.isDisconnected) {
            [serverSock connectToHost:host onPort:port error:&error];
        }
    } else {
        serverSock = [self initializeAsyncSocket];
        ITGCDSocketManagerSetObject(self.serverSocketsDict, serverSock, serverType);
        [serverSock connectToHost:host onPort:port error:&error];
    }
}

- (void)disconnectWithServer:(ITServerType)serverType {
    GCDAsyncSocket *serverSock = nil;
    if ((serverSock = ITGCDSocketManagerFetchObject(self.serverSocketsDict, serverType))) {
        if (serverSock.isConnected) {
            [serverSock disconnect];
            ITGCDSocketManagerRemoveObject(self.serverSocketsDict, serverType);
            ITGCDSocketManagerRemoveObject(self.serverInfoDict, serverType);
        }
    }
}

- (void)disconnectWithAllServer {
    for (GCDAsyncSocket *serverSock in [self.serverSocketsDict allValues]) {
        [serverSock disconnect];
    }
    [self.serverSocketsDict removeAllObjects];
    [self.serverInfoDict removeAllObjects];
}

- (BOOL)openServerWithPorts:(ITOpenPortType)portType,... {
    uint16_t followPort;
    va_list argumentList;
    if (portType) {
        BOOL openStatus = YES;
        if (![self openServerWithPort:portType]) {
            openStatus = NO;
        }
        va_start(argumentList, portType);
        while ((followPort = va_arg(argumentList, int))) {
            if (![self openServerWithPort:followPort]) {
                openStatus = NO;
            }
        }
        va_end(argumentList);
        return openStatus;
    }
    return NO;
}

- (BOOL)openServerWithPort:(ITOpenPortType)portType {
    GCDAsyncSocket *listenerSock = [self initializeAsyncSocket];
    NSError *error = nil;
    if(![listenerSock acceptOnPort:portType error:&error]) {
        NSLog(@"%@",[NSString stringWithFormat:@"fail:%@",[error localizedDescription]]);
        return NO;
    } else {
        NSLog(@"%@",[NSString stringWithFormat:@"open port success:%u",listenerSock.localPort]);
        ITGCDSocketManagerSetObject(self.listenerSocketsDict, listenerSock, portType);
//        if (!self.isServerRunning) {
//            self.serverRunning = YES;
//        }
        return YES;
    }
}

- (void)closeServerWithPorts:(ITOpenPortType)portType,... {
    uint16_t followPort;
    va_list argumentList;
    if (portType) {
        [self closeServerWithPort:portType];
        va_start(argumentList, portType);
        while ((followPort = va_arg(argumentList, int))) {
            [self closeServerWithPort:followPort];
        }
        va_end(argumentList);
    }
}

- (void)closeServerWithPort:(ITOpenPortType)portType {
    GCDAsyncSocket *listenerSock = nil;
    GCDAsyncSocket *clientSock = nil;
    if ((clientSock = ITGCDSocketManagerFetchObject(self.clientSocketsDict, portType))) {
        [clientSock disconnect];
        ITGCDSocketManagerRemoveObject(self.clientSocketsDict, portType);
    }
    if ((listenerSock = ITGCDSocketManagerFetchObject(self.listenerSocketsDict, portType))) {
        [listenerSock disconnect];
        ITGCDSocketManagerRemoveObject(self.listenerSocketsDict, portType);
    }
}

- (void)closeServerWithAllPorts {
//    if (self.isServerRunning) {
        for (GCDAsyncSocket *clientSock in [self.clientSocketsDict allValues]) {
            [clientSock disconnect];
        }
        for (GCDAsyncSocket *listenerSock in [self.listenerSocketsDict allValues]) {
            [listenerSock disconnect];
        }
        [self.clientSocketsDict removeAllObjects];
        [self.listenerSocketsDict removeAllObjects];
//        self.serverRunning = NO;
//    }
}

- (BOOL)sendDataToServer:(ITServerType)serverType data:(NSData *)data {
    if (nil == data || 0 >= data.length) {
        return NO;
    }
    GCDAsyncSocket *serverSock = nil;
    ITGCDSocketManagerServerInfo *serverInfo = nil;
    if ((serverSock = ITGCDSocketManagerFetchObject(self.serverSocketsDict, serverType))) {
        if (serverSock.isDisconnected) {
            self.waitingSendData = data;
            self.waitingSendSock = serverSock;
            if ((serverInfo = ITGCDSocketManagerFetchObject(self.serverInfoDict, serverType))) {
                [self connectToServer:serverType host:serverInfo.host port:serverInfo.port];
            }
            return NO;
        } else {
            [serverSock writeData:data withTimeout:TimeoutOfWrite tag:self.sendTag++];
            return YES;
        }
    }
    return NO;
}

- (BOOL)sendDataToClient:(ITOpenPortType)portType data:(NSData *)data {
    if (nil == data || 0 >= data.length) {
        return NO;
    }
    GCDAsyncSocket *clientSock = nil;
    if ((clientSock = ITGCDSocketManagerFetchObject(self.clientSocketsDict, portType))) {
        if (clientSock.isConnected) {
            [clientSock writeData:data withTimeout:TimeoutOfWrite tag:self.sendTag++];
            return YES;
        }
    }
    return NO;
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    //此处的sock是listensock,local null:0, connetcted 0.0.0.0:acceptPort
    //newSocket是新生成的sock,local 本地ip:acceptPort, connetcted 对方IP:对方端口号
    NSLog(@"newSocket accept connected %@:%d",newSocket.connectedHost,newSocket.connectedPort);
    NSLog(@"newSocket accept local %@:%d didAccept",newSocket.localHost,newSocket.localPort);
    ITGCDSocketManagerSetObject(self.clientSocketsDict, newSocket, sock.localPort);
    [newSocket readDataWithTimeout:TimeoutOfRead tag:self.receivedTag];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"didConnectToHost:%@,port:%hu",host,port);
    if (sock == self.waitingSendSock) {
        [self sendDataToServer:[[[self.serverSocketsDict allKeysForObject:sock] firstObject] unsignedShortValue] data:self.waitingSendData];
        return;
    }
    [sock readDataWithTimeout:TimeoutOfRead tag:self.receivedTag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    NSLog(@"%@:didDisconnect,%@",sock,[err localizedDescription]);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"didWriteData:%ld",tag);
    [sock readDataWithTimeout:TimeoutOfRead tag:self.receivedTag];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [sock readDataWithTimeout:TimeoutOfRead tag:self.receivedTag];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]postNotificationName:ITGCDSocketManagerNoticeDidReceiveData(sock.localPort) object:[ITGCDSocketManagerClientInfo configWithClient:sock.localPort receivedData:data] userInfo:nil];
    });
}

#pragma mark --GET
- (NSMutableDictionary<NSNumber *,ITGCDSocketManagerServerInfo *> *)serverInfoDict {
    if (_serverInfoDict == nil) {
        _serverInfoDict = [[NSMutableDictionary alloc]initWithCapacity:5];
    }
    return _serverInfoDict;
}

- (NSMutableDictionary<NSNumber *,GCDAsyncSocket *> *)serverSocketsDict {
    if (_serverSocketsDict == nil) {
        _serverSocketsDict = [[NSMutableDictionary alloc]initWithCapacity:5];
    }
    return _serverSocketsDict;
}

- (NSMutableDictionary<NSNumber *,GCDAsyncSocket *> *)listenerSocketsDict {
    if (_listenerSocketsDict == nil) {
        _listenerSocketsDict = [[NSMutableDictionary alloc]initWithCapacity:5];
    }
    return _listenerSocketsDict;
}

- (NSMutableDictionary<NSNumber *,GCDAsyncSocket *> *)clientSocketsDict {
    if (_clientSocketsDict == nil) {
        _clientSocketsDict = [[NSMutableDictionary alloc]initWithCapacity:5];
    }
    return _clientSocketsDict;
}

@end

@implementation ITGCDSocketManagerServerInfo

+ (instancetype)configWithServer:(ITServerType)serverType host:(NSString *)host port:(ITOpenPortType)port {
    ITGCDSocketManagerServerInfo *aServer = [[ITGCDSocketManagerServerInfo alloc]init];
    aServer.serverType = serverType;
    aServer.host = host;
    aServer.port = port;
    return aServer;
}
@end

@implementation ITGCDSocketManagerClientInfo

+ (instancetype)configWithClient:(ITOpenPortType)portType receivedData:(NSData *)receivedData {
    ITGCDSocketManagerClientInfo *aClient = [[ITGCDSocketManagerClientInfo alloc]init];
    aClient.portType = portType;
    aClient.receivedData = receivedData;
    return aClient;
}
@end
