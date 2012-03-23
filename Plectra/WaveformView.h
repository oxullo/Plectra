//
//  WaveformView.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <AudioToolbox/ExtendedAudioFile.h>

@interface WaveformView : NSView {
    NSMutableArray *amplitudes;
    float maxAmpl;
}

- (BOOL) openFile:(NSString *)theFile;

@end
