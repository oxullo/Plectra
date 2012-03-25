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

@interface Player : NSObject {
    PlayerInfo *_playerInfo;
    AudioQueueRef _queue;
}

- (void)playFileWithURL:(NSURL *)theURL;
- (void)stop;

@end
