//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "WaveformView.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize waveformView = _waveformView;

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
            [self.waveformView scanFile:filePath];
        }
    }

}

@end
