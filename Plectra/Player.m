//
//  Player.m
//  Plectra
//
//  Created by OXullo Intersecans on 24/5/16.
//  Copyright © 2016 OXullo Intersecans. All rights reserved.
//

#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>

#import "Player.h"

NSString * const kPlayerPlaybackEndedNotification = @"PlayerPlaybackEnded";

@implementation Player

- (instancetype)init {
    self = [super init];
    if (self) {
        _avPlayer = [[AVPlayer alloc] init];
    }
    return self;
}

- (double)currentTime
{
    return CMTimeGetSeconds([_avPlayer currentTime]);
}

- (double)duration
{
    AVPlayerItem *playerItem = _avPlayer.currentItem;
    
    if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
        return CMTimeGetSeconds(playerItem.asset.duration);
    } else {
        return 0.f;
    }
}

- (double)progress
{
    if (self.duration) {
        return self.currentTime / self.duration;
    } else {
        return 0;
    }
}

- (PlayerState)state
{
    if (_avPlayer.currentItem.status != AVPlayerItemStatusReadyToPlay) {
        return kPlayerEmpty;
    } else {
        if (_avPlayer.rate == 0) {
            if (self.currentTime == self.duration) {
                return kPlayerPlaybackFinished;
            } else {
                return kPlayerPaused;
            }
        } else {
            return kPlayerPlaying;
        }
    }
}

- (void)play
{
    [_avPlayer play];
}

- (void)pause
{
    [_avPlayer pause];
}

- (void)seek:(double)time
{
    [_avPlayer seekToTime:CMTimeMakeWithSeconds(time, 1000)
        toleranceBefore:kCMTimeZero
         toleranceAfter:kCMTimeZero];
}

- (void)onPlaybackEnded:(NSNotification *)note
{
    NSLog(@"Playback ended");
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerPlaybackEndedNotification
                                                        object:self];
}

- (void)loadURL:(NSURL *)fileURL
{
    if (_avPlayer.currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_avPlayer.currentItem];
    }
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:fileURL];
    [_avPlayer replaceCurrentItemWithPlayerItem:playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlaybackEnded:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}

@end
