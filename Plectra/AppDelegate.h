//
//  AppDelegate.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerItem.h>

@class WaveformView;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSButton *button;
    NSTimer *_progressUpdateTimer;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformView *waveformView;
@property (nonatomic, retain) AVPlayer *player;

- (IBAction)onPlayPauseButtonPressed:(id)sender;
- (IBAction)onOpenMenuSelected:(id)sender;
- (void)updateProgress:(NSTimer *)aNotification;

@end
