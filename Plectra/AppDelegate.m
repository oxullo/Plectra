//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012-2016 bRAiNRAPERS.org. All rights reserved.
//

#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>

#import "AppDelegate.h"
#import "WaveformView.h"

@interface AppDelegate (private)

- (void)handlePlayerChangedState:(NSNotification *)note;
- (void)handleWaveformViewSeekRequest:(NSNotification *)note;
@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize waveformView = _waveformView;
@synthesize player;

- (void)dealloc
{
    [super dealloc];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [self setPlayer:[[[AVPlayer alloc] init] autorelease]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWaveformViewSeekRequest:) name:kBNRPlayerSeekRequestNotification object:nil];

    _progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];
}

- (void)handleWaveformViewSeekRequest:(NSNotification *)note
{
    NSDictionary *userInfo = note.userInfo;
    NSNumber *seekTime = [userInfo objectForKey:@"seekTime"];
    
    NSLog(@"Seek requested: %@", seekTime);

    [self setCurrentTime:[seekTime doubleValue]];
}

- (void)handlePlaybackEnded:(NSNotification *)note
{
    [self.playPauseButton setImage:[NSImage imageNamed:@"icon_play.png"]];
}

- (void)openURL:(NSURL *)fileURL
{
    [_window setTitle:[fileURL lastPathComponent]];

    [_waveformView scanFileWithURL:fileURL];
    
    if ([player currentItem]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                              name:AVPlayerItemDidPlayToEndTimeNotification
                                              object:[player currentItem]];
    }

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:fileURL];
    [player replaceCurrentItemWithPlayerItem:playerItem];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackEnded:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];

    [player play];
    [self.playPauseButton setImage:[NSImage imageNamed:@"icon_pause.png"]];
}

- (void)openFileRequest
{
    NSURL *fileURL;
    NSOpenPanel *oOpnPnl = [NSOpenPanel openPanel];
    NSInteger nResult = [oOpnPnl runModal];
    if ( nResult == NSFileHandlingPanelOKButton ) {
        fileURL = [[oOpnPnl URL] retain];
        NSFileManager *oFM = [NSFileManager defaultManager];
        if ( [oFM fileExistsAtPath:[fileURL path]] != YES ) {
            NSBeep();
        } else {
            [self openURL:fileURL];
        }
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    NSLog(@"openFile(%@)", filename);

    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:filename];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self openURL:fileURL];
    });
    

    return YES;
}

- (IBAction)onPlayPauseButtonPressed:(id)sender
{
    if (player.currentItem.status != AVPlayerItemStatusReadyToPlay) {
        [self openFileRequest];
    } else {
        if (self.player.rate == 0) {
            if ([self currentTime] == [self duration]) {
                [self setCurrentTime:0];
            }
            [player play];
            [self.playPauseButton setImage:[NSImage imageNamed:@"icon_pause.png"]];
        } else {
            [player pause];
            [self.playPauseButton setImage:[NSImage imageNamed:@"icon_play.png"]];
        }
    }
}

- (IBAction)onOpenMenuSelected:(id)sender
{
    [self openFileRequest];
}

- (void)updateProgress:(NSTimer *)aNotification
{
    if (player.currentItem.status == AVPlayerItemStatusReadyToPlay && [self duration] > 0) {
        [_waveformView updateProgress:[self currentTime] / [self duration] withCurrentTime:[self currentTime]];
    }
}

- (double)currentTime
{
    return CMTimeGetSeconds([player currentTime]);
}

- (void)setCurrentTime:(double)time
{
    [player seekToTime:CMTimeMakeWithSeconds(time, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (double)duration
{
    AVPlayerItem *playerItem = [player currentItem];
    
    if ([playerItem status] == AVPlayerItemStatusReadyToPlay) {
        return CMTimeGetSeconds([[playerItem asset] duration]);
    } else {
        return 0.f;
    }
}

@end
