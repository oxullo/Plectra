//
//  AppDelegate.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WaveformView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformView *waveformView;

- (IBAction)onOpenButtonPressed:(id)sender;

@end
