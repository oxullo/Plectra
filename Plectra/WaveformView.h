//
//  WaveformView.h
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <AudioToolbox/ExtendedAudioFile.h>

extern NSString * const kBNRPlayerSeekRequestNotification;

@interface WaveformView : NSView {
    NSMutableArray *_amplitudes;
    float _maxAbsAmplitude;
    float _lastMouseX;
    NSTrackingArea *_trackingArea;
    double _lastProgress;
    double _lastCurrentTime;
    BOOL _isWaveLoaded;
    double _duration;
}

- (BOOL)scanFileWithURL:(NSURL *)theURL;
- (void)updateProgress:(double)theProgress withCurrentTime:(double)theCurrentTime;
- (void)reset;

@end
