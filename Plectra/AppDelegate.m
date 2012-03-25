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

@implementation AppDelegate

@synthesize window = _window;
@synthesize waveformView = _waveformView;

- (id)init
{
    self = [super init];
    
    if (self) {
        _player = [[Player alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (IBAction)onOpenButtonPressed:(id)sender
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
            NSURL *fileURL = [[NSURL fileURLWithPath:filePath] autorelease];

            [self.waveformView scanFileWithURL:fileURL];
            [_player playFileWithURL:fileURL];
        }
    }

}

@end
