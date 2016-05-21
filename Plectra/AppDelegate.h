//
//  AppDelegate.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012-2016 bRAiNRAPERS.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVPlayer.h>

@class WaveformView;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSButton *button;
    AVPlayer *player;
    NSTimer *_progressUpdateTimer;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformView *waveformView;
@property (assign) IBOutlet NSButton *playPauseButton;
@property (retain) AVPlayer *player;
@property (assign) double currentTime;
@property (readonly) double duration;


- (IBAction)onPlayPauseButtonPressed:(id)sender;
- (IBAction)onOpenMenuSelected:(id)sender;
- (void)updateProgress:(NSTimer *)aNotification;

@end
