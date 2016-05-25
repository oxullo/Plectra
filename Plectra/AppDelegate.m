/*
 Plectra - no-frills audio player
 
 Copyright (C) 2012-2016  OXullo Intersecans <x@brainrapers.org>
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */

#import "AppDelegate.h"
#import "WaveformView.h"

@interface AppDelegate (private)

- (void)handlePlayerChangedState:(NSNotification *)note;
- (void)handleWaveformViewSeekRequest:(NSNotification *)note;
@end

@implementation AppDelegate


- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    _player = [[Player alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWaveformViewSeekRequest:)
                                                 name:kBNRPlayerSeekRequestNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlaybackEnded:)
                                                 name:kPlayerPlaybackEndedNotification object:nil];

    _progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                            target:self
                                                          selector:@selector(updateProgress:)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleWaveformViewSeekRequest:(NSNotification *)note
{
    NSDictionary *userInfo = note.userInfo;
    NSNumber *seekTime = userInfo[@"seekTime"];
    
    NSLog(@"Seek requested: %@", seekTime);

    [_player seek:seekTime.doubleValue];
}

- (void)handlePlaybackEnded:(NSNotification *)note
{
    (self.playPauseButton).image = [NSImage imageNamed:@"icon_play"];
}

- (void)openURL:(NSURL *)fileURL
{
    _window.title = fileURL.lastPathComponent;

    [_waveformView scanFileWithURL:fileURL];
    
    [_player loadURL:fileURL];
    [_player play];
    
    (self.playPauseButton).image = [NSImage imageNamed:@"icon_pause"];
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];
}

- (void)openFileRequest
{
    NSURL *fileURL;
    NSOpenPanel *oOpnPnl = [NSOpenPanel openPanel];
    NSInteger nResult = [oOpnPnl runModal];
    if ( nResult == NSFileHandlingPanelOKButton ) {
        fileURL = oOpnPnl.URL;
        NSFileManager *oFM = [NSFileManager defaultManager];
        if ( [oFM fileExistsAtPath:fileURL.path] != YES ) {
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
    
    [self openURL:fileURL];

    return YES;
}

- (IBAction)onPlayPauseButtonPressed:(id)sender
{
    switch (_player.state) {
        case kPlayerEmpty:
            [self openFileRequest];
            break;
        
        case kPlayerPlaybackFinished:
            [_player seek:0];
        
        case kPlayerPaused:
            [_player play];
            (self.playPauseButton).image = [NSImage imageNamed:@"icon_pause"];
            break;
        
        case kPlayerPlaying:
            [_player pause];
            (self.playPauseButton).image = [NSImage imageNamed:@"icon_play"];
            break;
            
        default:
            break;
    }
}

- (IBAction)onOpenMenuSelected:(id)sender
{
    [self openFileRequest];
}

- (void)updateProgress:(NSTimer *)aNotification
{
    if (_player.state == kPlayerPlaying) {
        [_waveformView updateProgress:_player.progress
                      withCurrentTime:_player.currentTime];
    }
}


@end
