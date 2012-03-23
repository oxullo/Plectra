//
//  AppDelegate.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize waveformView = _waveformView;

- (void)dealloc
{
    [super dealloc];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
//    NSColor * gray  = [NSColor grayColor];
//    NSColor * white = [NSColor whiteColor];
//	
//    [self.waveformView lockFocus];
//    // fill background
//    [gray set];
//    NSRectFill ( [self.waveformView bounds] );
//    
//    // fill target rect
//    NSRect rect1 = NSMakeRect ( 21,21,210,210 );
//    [white set];
//    NSRectFill ( rect1 );
//    [self.waveformView unlockFocus];
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
            [self.waveformView openFile:filePath];
        }
    }

}

@end
