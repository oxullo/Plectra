//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setPlayer:[[[AVPlayer alloc] init] autorelease]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWaveformViewSeekRequest:) name:kBNRPlayerSeekRequestNotification object:nil];
    
    _progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];
}

/*
- (void)handlePlayerChangedState:(NSNotification *)note
{
    NSLog(@"Player changed state to %d", _player.state);
    switch (_player.state) {
        case PLAYER_PLAYING:
            [button setImage:[NSImage imageNamed:@"icon_pause.png"]];
            break;

        case PLAYER_EMPTY:
            [_window setTitle:@"Plectra"];
            [_waveformView reset];

        case PLAYER_STOPPED:
        case PLAYER_PAUSED:
            [button setImage:[NSImage imageNamed:@"icon_play.png"]];
            break;
            
        default:
            break;
    }
}
*/

- (void)handleWaveformViewSeekRequest:(NSNotification *)note
{
    NSDictionary *userInfo = note.userInfo;
    NSNumber *seekTime = [userInfo objectForKey:@"seekTime"];
    
    NSLog(@"Seek requested: %@", seekTime);

    [self setCurrentTime:[seekTime doubleValue]];
}

- (void)openURL:(NSURL *)fileURL
{
    [_window setTitle:[fileURL lastPathComponent]];

    [_waveformView scanFileWithURL:fileURL];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:fileURL];
    [player replaceCurrentItemWithPlayerItem:playerItem];

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
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:filename];
    NSLog(@"Opening file: %@", filename);

    [self openURL:fileURL];

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
