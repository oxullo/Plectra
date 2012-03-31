//
//  Player.h
//  Plectra
//
//  Created by OXullo Intersecans on 25/03/12.
//  Copyright (c) 2012 brainrapers.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef enum PlayerState
{
    PLAYER_EMPTY,
    PLAYER_PAUSED,
    PLAYER_PLAYING,
    PLAYER_ERROR
} PlayerState;

extern NSString * const kBNRPlayerChangedStateNotification;

@interface Player : NSObject {
    AudioFileID _playbackFile; // reference to your output file
    SInt64 _packetPosition; // current packet index in output file
    UInt32 _numPacketsToRead; // number of packets to read from file
    AudioStreamPacketDescription *_packetDescs; // array of packet descriptions for read buffer
    Boolean _isDone; // playback has completed
    
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
