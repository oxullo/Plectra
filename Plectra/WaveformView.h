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
    NSMutableArray *_amplitudes;
    float _maxAbsAmplitude;
    float _lastMouseX;

@private
    NSTrackingArea *_trackingArea;
}

- (BOOL) scanFile:(NSString *)filePath;

@end
