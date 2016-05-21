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

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [self setPlayer:[[AVPlayer alloc] init]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(handleWaveformViewSeekRequest:)
                                          name:kBNRPlayerSeekRequestNotification object:nil];

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
    NSNumber *seekTime = [userInfo objectForKey:@"seekTime"];
    
    NSLog(@"Seek requested: %@", seekTime);

    [self setCurrentTime:[seekTime doubleValue]];
}

- (void)handlePlaybackEnded:(NSNotification *)note
{
    [self.playPauseButton setImage:[NSImage imageNamed:@"icon_play"]];
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
    [self.playPauseButton setImage:[NSImage imageNamed:@"icon_pause"]];
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];
}

- (void)openFileRequest
{
    NSURL *fileURL;
    NSOpenPanel *oOpnPnl = [NSOpenPanel openPanel];
    NSInteger nResult = [oOpnPnl runModal];
    if ( nResult == NSFileHandlingPanelOKButton ) {
        fileURL = [oOpnPnl URL];
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
            [self.playPauseButton setImage:[NSImage imageNamed:@"icon_pause"]];
        } else {
            [player pause];
            [self.playPauseButton setImage:[NSImage imageNamed:@"icon_play"]];
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
        [_waveformView updateProgress:[self currentTime] / [self duration]
                       withCurrentTime:[self currentTime]];
    }
}

- (double)currentTime
{
    return CMTimeGetSeconds([player currentTime]);
}

- (void)setCurrentTime:(double)time
{
    [player seekToTime:CMTimeMakeWithSeconds(time, 1000)
                toleranceBefore:kCMTimeZero
                toleranceAfter:kCMTimeZero];
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
