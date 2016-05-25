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

typedef NS_ENUM(unsigned int, PlayerState) {
    kPlayerEmpty,
    kPlayerIdle,
    kPlayerPlaying,
    kPlayerPaused,
    kPlayerPlaybackFinished
};


@interface Player : NSObject {
    AVPlayer *_avPlayer;    
}

@property (readonly) double currentTime;
@property (readonly) double duration;
@property (readonly) double progress;

@property (readonly) PlayerState state;
- (void)pause;
- (void)play;
- (void)seek:(double)time;
- (void)loadURL:(NSURL *)fileURL;

@end
