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


#import "WaveformView.h"

#define LogPoint(POINT) NSLog(@"%s: (%0.0f, %0.0f)",\
#POINT, POINT.x, POINT.y)

#define LogSize(SIZE) NSLog(@"%s: %0.0f x %0.0f",\
#SIZE, SIZE.width, SIZE.height)

#define LogRect(RECT) NSLog(@"%s: (%0.0f, %0.0f) %0.0f x %0.0f",\
#RECT, RECT.origin.x, RECT.origin.y,\
RECT.size.width, RECT.size.height)

#define AUDIOBUFFER_SIZE    32768

NSString * const kBNRPlayerSeekRequestNotification = @"WaveformViewSeekRequest";

@interface WaveformView (private)

- (void)notifySeekAtPos:(double)xPos;
- (void)dumpFormatInfo:(AudioStreamBasicDescription)inputFormat;
- (void)fetchSongDuration:(NSURL *)theURL;
- (void)drawMiddleLine;
- (void)drawWaveform;
- (void)drawMouseCursor;
- (void)drawCurrentTimeText:(double)theTime atPos:(NSPoint)thePos;
- (void)drawProgressBlock;

@end


@implementation WaveformView

#pragma mark - Instance methods overrides

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _amplitudes = [[NSMutableArray alloc] init];
        _maxAbsAmplitude = 0.0;
        _lastMouseX = -1;
        _isWaveLoaded = NO;
    }
    
    return self;
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow {
    // In order to receive spam-level mouse notifications such as motion, is advisable
    // to create a NSTrackingArea which relays the wanted events to the view
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                 options: (NSTrackingMouseMoved |
                                                           NSTrackingMouseEnteredAndExited |
                                                           NSTrackingActiveAlways)
                                                 owner:self
                                                 userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)dealloc {
    [self removeTrackingArea:_trackingArea];
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

- (void)mouseExited:(NSEvent *)theEvent {
    if (_isWaveLoaded) {
        _lastMouseX = -1;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    if (_isWaveLoaded) {
        NSPoint eventLocation = [theEvent locationInWindow];
        NSPoint center = [self convertPoint:eventLocation fromView:nil];
        _lastMouseX = center.x;
        
        // TODO: inform the view of the dirty region, avoiding a complete redraw
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [self mouseMoved:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (_isWaveLoaded) {
        NSPoint eventLocation = [theEvent locationInWindow];
        NSPoint center = [self convertPoint:eventLocation fromView:nil];
        
        [self notifySeekAtPos:center.x];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    // fill background
    [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0f] set];
    NSFrameRectWithWidth([self bounds], 1.0);
    
    [self drawMiddleLine];
    [self drawWaveform];
    [self drawMouseCursor];
    [self drawProgressBlock];
}

#pragma mark - Public methods

- (BOOL) scanFileWithURL:(NSURL *)theURL
{
    [self fetchSongDuration:theURL];
    
    ExtAudioFileRef	audioFileRef;
    
    NSLog(@"Attempt to open %@", theURL);
	OSStatus err = ExtAudioFileOpenURL((__bridge CFURLRef)theURL, &audioFileRef);
    
	if (err) {
		NSLog(@"ExtAudioFileOpenURL failed.(err=%d)\n", err);
		return NO;
    }
    
    UInt32 nSize = sizeof(SInt64);
    SInt64	framesCount;
	err = ExtAudioFileGetProperty(audioFileRef,
                                  kExtAudioFileProperty_FileLengthFrames,
								  &nSize,
								  &framesCount);
	if (err) {
		NSLog(@"ExtAudioFileGetProperty failed.(err=%d)\n", err);
		return NO;
	}
	NSLog(@"Frame Count = %d\n", (int)framesCount);
    
    AudioStreamBasicDescription inputFormat;
	
    nSize = sizeof(AudioStreamBasicDescription);
    
	err = ExtAudioFileGetProperty(audioFileRef,
								  kExtAudioFileProperty_FileDataFormat,
								  &nSize,
								  &inputFormat);
	if (err) {
		NSLog(@"ExtAudioFileGetProperty failed.(err=%d)\n", err);
		return NO;
	}
    
    [self dumpFormatInfo:inputFormat];
    
    AudioStreamBasicDescription clientFormat = inputFormat;
    
    clientFormat.mFormatID = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    clientFormat.mBitsPerChannel = 32;
    clientFormat.mBytesPerFrame = 8;
    clientFormat.mFramesPerPacket = 1;
    clientFormat.mBytesPerPacket = 8;
    
	nSize = sizeof(AudioStreamBasicDescription);
	err = ExtAudioFileSetProperty(audioFileRef,
								  kExtAudioFileProperty_ClientDataFormat, 
								  nSize,
								  &clientFormat);
	if(err){
		NSLog(@"kExtAudioFileProperty_ClientDataFormat failed.(err=%d)\n", err);
		return NO;
	}

	char srcBuffer[AUDIOBUFFER_SIZE];
    
    AudioBufferList fillBufList;
    fillBufList.mNumberBuffers = 1;
    fillBufList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
    fillBufList.mBuffers[0].mDataByteSize = AUDIOBUFFER_SIZE;
    fillBufList.mBuffers[0].mData = srcBuffer;
    
    // TODO: something definitely smarter than this
    SInt64 step = framesCount / [self bounds].size.width;
    
    [self reset];
    
    for (SInt64 i=1; i < framesCount; i+=step) {
        // move to position
        err = ExtAudioFileSeek(audioFileRef, i);
        
        if(err) {
            NSLog(@"ExtAudioFileSeek failed. (err=%d)", err);
            return NO;
        }
        
        // get value
        UInt32 s = 1; // number of frames to read
        err = ExtAudioFileRead(audioFileRef, &s, &fillBufList);

        if(err) {
            NSLog(@"ExtAudioFileRead failed. (err=%d)", err);
            return NO;
        }
        
        AudioBuffer audioBuffer = fillBufList.mBuffers[0];
        Float32 *frame = audioBuffer.mData;
        Float32 val = frame[0];
        
        if (fabs(val) > _maxAbsAmplitude) {
            _maxAbsAmplitude = fabs(val);
        }
        
        [_amplitudes addObject:[NSNumber numberWithFloat:val]];
    }
    
    ExtAudioFileDispose(audioFileRef);
    
    _lastProgress = 0.0;
    _lastCurrentTime = 0.0;
    _isWaveLoaded = YES;
    
    return YES;
}

- (void)updateProgress:(double)theProgress withCurrentTime:(double)theCurrentTime
{
    _lastProgress = theProgress;
    _lastCurrentTime = theCurrentTime;
    [self setNeedsDisplay:YES];
}

- (void)reset
{
    [_amplitudes removeAllObjects];
    _maxAbsAmplitude = 0.0;
    [self setNeedsDisplay:YES];
}


#pragma mark - Private methods

- (void)dumpFormatInfo:(AudioStreamBasicDescription)inputFormat
{
    NSLog(@"mSampleRate=%f\n", inputFormat.mSampleRate);
	NSLog(@"mFormatID=0x%x\n", inputFormat.mFormatID);
	NSLog(@"mSampleRate=%d\n", inputFormat.mFormatFlags);
	NSLog(@"mBytesPerPacket=%d\n", inputFormat.mBytesPerPacket);
	NSLog(@"mFramesPerPacket=%d\n", inputFormat.mFramesPerPacket);
	NSLog(@"mBytesPerFrame=%d\n", inputFormat.mBytesPerFrame);
	NSLog(@"mChannelsPerFrame=%d\n", inputFormat.mChannelsPerFrame);
	NSLog(@"mBitsPerChannel=%d\n", inputFormat.mBitsPerChannel);
}

- (void)notifySeekAtPos:(double)xPos
{
    NSNumber *seekTime = [[NSNumber alloc] initWithDouble:xPos / [self bounds].size.width * _duration];
    NSDictionary *seekTimeDict = [NSDictionary dictionaryWithObject:seekTime
                                                                        forKey:@"seekTime"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kBNRPlayerSeekRequestNotification
                                                object:self
                                                userInfo:seekTimeDict];
}

// TODO: duplicated code, to be integrated among WaveformView and Player
- (void)fetchSongDuration:(NSURL *)theURL
{
    AudioFileID audioFileID;
    
    AudioFileOpenURL((__bridge CFURLRef _Nonnull)(theURL), kAudioFileReadPermission, 0, &audioFileID);
    
    UInt32 thePropSize = sizeof(_duration);
    OSStatus err = AudioFileGetProperty(audioFileID, kAudioFilePropertyEstimatedDuration,
                                        &thePropSize, &_duration);
    
    NSAssert(err == 0, @"AudioFileGetProperty() failed");
    
    NSLog(@"Detected duration: %f", _duration);
    
    AudioFileClose(audioFileID);
}

- (void)drawMiddleLine
{
    [[NSColor grayColor] set];
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:1];
    [path moveToPoint:NSMakePoint(0, [self bounds].size.height / 2)];
    [path lineToPoint:NSMakePoint([self bounds].size.width, [self bounds].size.height / 2)];
    [path stroke];
}

- (void)drawWaveform
{
    [[NSColor blackColor] set]; 
    
    NSBezierPath *wavePath = [NSBezierPath bezierPath];
    [wavePath setLineWidth:1];
    
    for (int i=0 ; i < [_amplitudes count] ; ++i) {
        float ampl = [[_amplitudes objectAtIndex:i] floatValue];
        float y = ampl / _maxAbsAmplitude * [self bounds].size.height / 2;
        
        [wavePath moveToPoint:NSMakePoint(i, -y + [self bounds].size.height / 2)];
        [wavePath lineToPoint:NSMakePoint(i, y + [self bounds].size.height / 2)];
    }
    [wavePath stroke];
}

- (void)drawMouseCursor
{
    if (_lastMouseX > -1) {
        NSBezierPath *cursorPath = [NSBezierPath bezierPath];
        [cursorPath setLineWidth:1];
        [[NSColor redColor] set];
        [cursorPath moveToPoint:NSMakePoint(_lastMouseX, 0)];
        [cursorPath lineToPoint:NSMakePoint(_lastMouseX, [self bounds].size.height)];
        [cursorPath stroke];
        
        [self drawCurrentTimeText:_lastMouseX / [self bounds].size.width * _duration
                  atPos:NSMakePoint(_lastMouseX, 60)];
    }
}

- (void)drawCurrentTimeText:(double)theTime atPos:(NSPoint)thePos
{
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont
                    fontWithName:@"Helvetica" size:8], NSFontAttributeName,[NSColor blackColor],
                                NSForegroundColorAttributeName, nil];
    
    int hours, minutes, seconds, millis;
    
    millis = (int)(theTime * 100) % 100;
    seconds = (int)theTime;
    hours = seconds / 3600;
    minutes = (seconds - (hours*3600)) / 60;
    seconds = seconds % 60;
    
    NSString *s;
    
    if (hours > 0) {
        s = [NSString stringWithFormat:@"%02d:%02d:%02d:%02d", hours, minutes, seconds, millis];
    } else {
        s = [NSString stringWithFormat:@"%02d:%02d:%02d", minutes, seconds, millis];
    }
    
    NSAttributedString *currentText=[[NSAttributedString alloc] initWithString:s
                                                                    attributes:attributes];
    
    NSSize attrSize = [currentText size];
    double xTextPos;
    
    if (thePos.x + attrSize.width > [self bounds].size.width) {
        xTextPos = thePos.x - attrSize.width - 3;
    } else {
        xTextPos = thePos.x + 3;
    }
    
    [[[NSColor whiteColor] colorWithAlphaComponent:0.7] set];
    NSRectFillUsingOperation(NSMakeRect(xTextPos, thePos.y, attrSize.width, attrSize.height),
                             NSCompositeSourceAtop);
    [currentText drawAtPoint:NSMakePoint(xTextPos, thePos.y)];
}

- (void)drawProgressBlock
{
    if (_lastProgress > 0.0) {
        NSBezierPath *cursorPath = [NSBezierPath bezierPath];
        [cursorPath setLineWidth:0.5];
        [[NSColor redColor] set];
        double xCursorPos = [self bounds].size.width * _lastProgress;
        [cursorPath moveToPoint:NSMakePoint(xCursorPos, 0)];
        [cursorPath lineToPoint:NSMakePoint(xCursorPos, [self bounds].size.height)];
        [cursorPath stroke];
        
        [[[NSColor redColor] colorWithAlphaComponent:0.1] set];
        NSRectFillUsingOperation(NSMakeRect(0, 0, xCursorPos, [self bounds].size.height),
                                 NSCompositeSourceAtop);
        
        if (_lastCurrentTime > 0.0) {
            [self drawCurrentTimeText:_lastCurrentTime atPos:NSMakePoint(xCursorPos, 0)];
        }
    }
}

@end
