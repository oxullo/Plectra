//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "WaveformView.h"
#import "Player.h"

@interface AppDelegate (private)

- (void)handlePlayerChangedState:(NSNotification *)note;
- (void)handleWaveformViewSeekRequest:(NSNotification *)note;
@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize waveformView = _waveformView;

- (id)init
{
    self = [super init];
    
    if (self) {
        _player = [[Player alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePlayerChangedState:) name:kBNRPlayerChangedStateNotification object:nil];

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

- (void)handleWaveformViewSeekRequest:(NSNotification *)note
{
    NSDictionary *userInfo = note.userInfo;
    NSNumber *seekTime = [userInfo objectForKey:@"seekTime"];
    
    NSLog(@"Seek requested: %@", seekTime);

    [_player seekTo:[seekTime doubleValue]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void)openURL:(NSURL *)fileURL
{
    [_player reset];
    [_window setTitle:[fileURL lastPathComponent]];

    [_waveformView scanFileWithURL:fileURL];
    [_player playFileWithURL:fileURL];
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
    switch (_player.state) {
        case PLAYER_EMPTY:
            [self openFileRequest];
            break;
        
        case PLAYER_STOPPED:
            [_player seekTo:0];
            break;
            
        case PLAYER_PAUSED:
            [_player resume];
            break;
        
        case PLAYER_PLAYING:
            [_player pause];
            break;
        
        default:
            NSLog(@"Unhandled onPlayPauseButtonPressed() while in state %d", _player.state);
    }
}

- (IBAction)onOpenMenuSelected:(id)sender
{
    [self openFileRequest];
}

- (void)updateProgress:(NSTimer *)aNotification
{
    [_waveformView updateProgress:_player.currentTime / _player.duration withCurrentTime:_player.currentTime];
}

@end
