//
//  Player.h
//  Plectra
//
//  Created by OXullo Intersecans on 25/03/12.
//  Copyright (c) 2012 brainrapers.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef struct PlayerInfo {
    AudioFileID                 playbackFile; // reference to your output file
    SInt64                      packetPosition; // current packet index in output file
    UInt32                      numPacketsToRead; // number of packets to read from file
    AudioStreamPacketDescription *packetDescs; // array of packet descriptions for read buffer
    Boolean                     isDone; // playback has completed
} PlayerInfo;

typedef enum PlayerState
{
    PLAYER_EMPTY,
    PLAYER_PAUSED,
    PLAYER_PLAYING,
    PLAYER_ERROR
} PlayerState;

extern NSString * const kBNRPlayerChangedStateNotification;

@interface Player : NSObject {
    PlayerInfo *_playerInfo;
    AudioQueueRef _queue;
    PlayerState _state;
    double _lastProgress;
    AudioStreamBasicDescription _dataFormat;
    double _duration;
}

@property (nonatomic, readonly) PlayerState state;
@property (readonly) double currentTime;
@property (readonly) double duration;

- (void)playFileWithURL:(NSURL *)theURL;
- (void)pause;
- (void)resume;
- (void)reset;

@end
