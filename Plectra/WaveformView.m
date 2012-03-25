//
//  WaveformView.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WaveformView.h"

#define LogPoint(POINT) NSLog(@"%s: (%0.0f, %0.0f)",\
#POINT, POINT.x, POINT.y)

#define LogSize(SIZE) NSLog(@"%s: %0.0f x %0.0f",\
#SIZE, SIZE.width, SIZE.height)

#define LogRect(RECT) NSLog(@"%s: (%0.0f, %0.0f) %0.0f x %0.0f",\
#RECT, RECT.origin.x, RECT.origin.y,\
RECT.size.width, RECT.size.height)

#define SUBSAMPLE_SAMPLES   800
#define AUDIOBUFFER_SIZE    32768


@implementation WaveformView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _amplitudes = [[NSMutableArray alloc] init];
        _maxAbsAmplitude = 0.0;
        _lastMouseX = -1;
    }
    
    return self;
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow {
    // In order to receive spam-level mouse notifications such as motion, is advisable
    // to create a NSTrackingArea which relays the wanted events to the view
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)dealloc {
    [super dealloc];
    [self removeTrackingArea:_trackingArea];
    [_trackingArea release];
}

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

- (BOOL) scanFileWithURL:(NSURL *)theURL
{
    ExtAudioFileRef	audioFileRef;
    
    NSLog(@"Attempt to open %@", theURL);
	OSStatus err = ExtAudioFileOpenURL((CFURLRef)theURL, &audioFileRef);
    
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
    
    SInt64 step = framesCount / SUBSAMPLE_SAMPLES;
    
    [_amplitudes removeAllObjects];
    _maxAbsAmplitude = 0.0;
    
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
    
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    /*
    // fill background
    [[NSColor whiteColor] set];
    NSRectFill ([self bounds]);
    */
    
    [[NSColor grayColor] set];

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:1];
    [path moveToPoint:NSMakePoint(0, [self bounds].size.height / 2)];
    [path lineToPoint:NSMakePoint([self bounds].size.width, [self bounds].size.height / 2)];
    [path stroke];

    [[NSColor blackColor] set]; 

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica" size:8], NSFontAttributeName,[NSColor blackColor], NSForegroundColorAttributeName, nil];
    
    NSBezierPath *wavePath = [NSBezierPath bezierPath];
    [wavePath setLineWidth:1];
    
    for (int i=0 ; i < [_amplitudes count] ; ++i) {
        float ampl = [[_amplitudes objectAtIndex:i] floatValue];
        float y = ampl / _maxAbsAmplitude * [self bounds].size.height / 2;

        [wavePath moveToPoint:NSMakePoint(i, -y + [self bounds].size.height / 2)];
        [wavePath lineToPoint:NSMakePoint(i, y + [self bounds].size.height / 2)];
        
        if (i % 50 == 0) {
            NSString *s = [NSString stringWithFormat:@"%d", i];
            NSAttributedString *currentText=[[NSAttributedString alloc] initWithString:s attributes: attributes];
            
            NSSize attrSize = [currentText size];
            [currentText drawAtPoint:NSMakePoint(i - attrSize.width / 2, 0)];
            [currentText release];
        }
    }
    [wavePath stroke];
    
    if (_lastMouseX > -1) {
        NSBezierPath *cursorPath = [NSBezierPath bezierPath];
        [cursorPath setLineWidth:1];
        [[NSColor redColor] set];
        [cursorPath moveToPoint:NSMakePoint(_lastMouseX, 0)];
        [cursorPath lineToPoint:NSMakePoint(_lastMouseX, [self bounds].size.height)];
        [cursorPath stroke];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    _lastMouseX = -1;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSPoint eventLocation = [theEvent locationInWindow];
    NSPoint center = [self convertPoint:eventLocation fromView:nil];
    _lastMouseX = center.x;

    // TODO: inform the view of the dirty region, avoiding a complete redraw
    [self setNeedsDisplay:YES];
}

@end
