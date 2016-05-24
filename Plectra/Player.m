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

@implementation Player

- (id)init {
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] init];
    }
    return self;
}

- (double)currentTime
{
    return CMTimeGetSeconds([_player currentTime]);
}

- (double)duration
{
    AVPlayerItem *playerItem = [_player currentItem];
    
    if ([playerItem status] == AVPlayerItemStatusReadyToPlay) {
        return CMTimeGetSeconds([[playerItem asset] duration]);
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
    if (_player.currentItem.status != AVPlayerItemStatusReadyToPlay) {
        return kPlayerEmpty;
    } else {
        if (_player.rate == 0) {
            if ([self currentTime] == [self duration]) {
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
    [_player play];
}

- (void)pause
{
    [_player pause];
}

- (void)seek:(double)time
{
    [_player seekToTime:CMTimeMakeWithSeconds(time, 1000)
        toleranceBefore:kCMTimeZero
         toleranceAfter:kCMTimeZero];
}

- (void)loadURL:(NSURL *)fileURL
{
//    if ([_player currentItem]) {
//        [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                        name:AVPlayerItemDidPlayToEndTimeNotification
//                                                      object:[_player currentItem]];
//    }
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:fileURL];
    [_player replaceCurrentItemWithPlayerItem:playerItem];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(handlePlaybackEnded:)
//                                                 name:AVPlayerItemDidPlayToEndTimeNotification
//                                               object:playerItem];
}

@end
