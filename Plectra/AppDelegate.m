//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

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

- (id)init
{
    self = [super init];
    
    if (self) {
        player = nil;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWaveformViewSeekRequest:) name:kBNRPlayerSeekRequestNotification object:nil];

        _progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];

    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

    [self.player seekToTime:CMTimeMakeWithSeconds([seekTime doubleValue], 60000)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void)openURL:(NSURL *)fileURL
{
    [_window setTitle:[fileURL lastPathComponent]];

    [_waveformView scanFileWithURL:fileURL];
    self.player = [AVPlayer playerWithURL:fileURL];

    [self.player play];
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
    if (self.player == nil) {
        [self openFileRequest];
    } else {
        if (self.player.rate == 0) {
            if (CMTimeGetSeconds(self.player.currentTime) == CMTimeGetSeconds(self.player.currentItem.asset.duration)) {
                [self.player seekToTime:CMTimeMakeWithSeconds(0.f, 60000)];
            }
            [self.player play];
            [self.playPauseButton setImage:[NSImage imageNamed:@"icon_pause.png"]];
        } else {
            [self.player pause];
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
    if (self.player != nil) {
        double currentTime = CMTimeGetSeconds(self.player.currentTime);
        double totalDuration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
        
        if (totalDuration != 0) {
            [_waveformView updateProgress:currentTime / totalDuration withCurrentTime:currentTime];
        }
    }
}

@end
