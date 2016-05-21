/*
 Plectra - no-frills audio player
 
 Copyright (C) 2012-2016  OXullo Intersecans <x@brainrapers.org>
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */


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
