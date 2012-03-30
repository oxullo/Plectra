//
//  AppDelegate.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WaveformView;
@class Player;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSButton *button;
    Player *_player;
    NSTimer *_progressUpdateTimer;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformView *waveformView;

- (IBAction)onPlayPauseButtonPressed:(id)sender;
- (IBAction)onOpenMenuSelected:(id)sender;
- (void)updateCurrentTime:(NSTimer *)aNotification;

@end
