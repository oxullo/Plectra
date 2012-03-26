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

@interface AppDelegate ()

- (void)handlePlayerChangedState:(NSNotification *)note;
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
    switch (_player.state) {
        case PLAYER_PLAYING:
            [button setImage:[NSImage imageNamed:@"icon_pause.png"]];
            break;

        case PLAYER_PAUSED:
            [button setImage:[NSImage imageNamed:@"icon_play.png"]];
            break;
            
        default:
            break;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (IBAction)onPlayPauseButtonPressed:(id)sender
{
    switch (_player.state) {
        case PLAYER_EMPTY:
        {
            NSString *filePath;
            NSOpenPanel *oOpnPnl = [NSOpenPanel openPanel];
            NSInteger nResult = [oOpnPnl runModalForTypes:nil];
            if ( nResult == NSFileHandlingPanelOKButton ) {
                filePath = [[oOpnPnl filenames] objectAtIndex:0];
                NSFileManager *oFM = [NSFileManager defaultManager];
                if ( [oFM fileExistsAtPath:filePath] != YES ) {
                    NSBeep();
                } else {
                    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
                    
                    [self.waveformView scanFileWithURL:fileURL];
                    [_player playFileWithURL:fileURL];
                }
            }
            break;
        }
        
        case PLAYER_PAUSED:
            [_player resume];
            break;
        
        case PLAYER_PLAYING:
            [_player pause];
            break;
        
        case PLAYER_ERROR:
            NSAssert(NO, @"bomb");
            break;
    }
}

@end
