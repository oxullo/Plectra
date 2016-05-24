//
//  Player.h
//  Plectra
//
//  Created by OXullo Intersecans on 24/5/16.
//  Copyright © 2016 OXullo Intersecans. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVPlayer.h>

extern NSString * const kPlayerPlaybackEndedNotification;

typedef enum {
    kPlayerEmpty,
    kPlayerIdle,
    kPlayerPlaying,
    kPlayerPaused,
    kPlayerPlaybackFinished
} PlayerState;


@interface Player : NSObject {
    AVPlayer *_player;    
}

@property (readonly) double currentTime;
@property (readonly) double duration;
@property (readonly) double progress;

- (PlayerState)state;
- (void)pause;
- (void)play;
- (void)seek:(double)time;
- (void)loadURL:(NSURL *)fileURL;

@end
