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


@implementation WaveformView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        amplitudes = [[NSMutableArray alloc] init];
        maxAmpl = 0.0;
        xMouse = -1;
    }
    
    return self;
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow {
    // In order to receive spam-level mouse notifications such as motion, is advisable
    // to create a NSTrackingArea which relays the wanted events to the view
    NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (BOOL) openFile:(NSString *)theFile
{
    ExtAudioFileRef	mAudioFileRef;
    SInt64	mFrameCount;
    
    NSURL *oURL = [NSURL fileURLWithPath:theFile];
    NSLog(@"Attempting to open %@", oURL);
	OSStatus err = ExtAudioFileOpenURL( (CFURLRef)oURL, &mAudioFileRef );
    
	if ( err ) {
		NSLog( @"ExtAudioFileOpenURL failed.(err=%d)\n", err );
		return NO;
    }
    
    UInt32 nSize = sizeof(SInt64);
	err = ExtAudioFileGetProperty( mAudioFileRef,
								  kExtAudioFileProperty_FileLengthFrames,
								  &nSize,
								  &mFrameCount );
	if ( err ) {
		NSLog( @"ExtAudioFileGetProperty failed.(err=%d)\n", err );
		return NO;
	}
	NSLog( @"Frame Count = %d\n", (int)mFrameCount );
    
    AudioStreamBasicDescription inputFormat;
	
    nSize = sizeof(AudioStreamBasicDescription);
    
	err = ExtAudioFileGetProperty(mAudioFileRef,
								  kExtAudioFileProperty_FileDataFormat,
								  &nSize,
								  &inputFormat);
	if ( err ) {
		NSLog( @"ExtAudioFileGetProperty failed.(err=%d)\n", err );
		return NO;
	}
    
    NSLog( @"mSampleRate=%f\n", inputFormat.mSampleRate );
	NSLog( @"mFormatID=0x%x\n", inputFormat.mFormatID );
	NSLog( @"mSampleRate=%d\n", inputFormat.mFormatFlags );
	NSLog( @"mBytesPerPacket=%d\n", inputFormat.mBytesPerPacket );
	NSLog( @"mFramesPerPacket=%d\n", inputFormat.mFramesPerPacket );
	NSLog( @"mBytesPerFrame=%d\n", inputFormat.mBytesPerFrame );
	NSLog( @"mChannelsPerFrame=%d\n", inputFormat.mChannelsPerFrame );
	NSLog( @"mBitsPerChannel=%d\n", inputFormat.mBitsPerChannel );
    
    AudioStreamBasicDescription clientFormat = inputFormat;
    
    clientFormat.mFormatID = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    clientFormat.mBitsPerChannel = 32;
    clientFormat.mBytesPerFrame = 8;
    clientFormat.mFramesPerPacket = 1;
    clientFormat.mBytesPerPacket = 8;
    
	nSize = sizeof(AudioStreamBasicDescription);
	err = ExtAudioFileSetProperty(mAudioFileRef,
								  kExtAudioFileProperty_ClientDataFormat, 
								  nSize,
								  &clientFormat);
	if(err){
		NSLog( @"kExtAudioFileProperty_ClientDataFormat failed.(err=%d)\n", err );
		return NO;
	}

    const UInt32 kSrcBufSize = 32768;
	char srcBuffer[kSrcBufSize];
    
    AudioBufferList fillBufList;
    fillBufList.mNumberBuffers = 1;
    fillBufList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
    fillBufList.mBuffers[0].mDataByteSize = kSrcBufSize;
    fillBufList.mBuffers[0].mData = srcBuffer;
    
    SInt64 step = mFrameCount / SUBSAMPLE_SAMPLES;
    
    [amplitudes removeAllObjects];
    maxAmpl = 0.0;
    
    for (SInt64 i=1; i < mFrameCount; i+=step) {
        // move to position
        err = ExtAudioFileSeek(mAudioFileRef, i);
        
        if(err) {
            NSLog(@"ExtAudioFileSeek failed. (err=%d)", err);
            return NO;
        }
        
        SInt64 tell;
        err = ExtAudioFileTell(mAudioFileRef, &tell);
        
        if(err) {
            NSLog(@"ExtAudioFileTell failed. (err=%d)", err);
            return NO;
        }

        //NSLog(@"seek position %lli", tell);
        
        // get value
        UInt32 s = 1; // number of frames to read
        err = ExtAudioFileRead(mAudioFileRef,
                                    &s,
                                    &fillBufList);

        if(err) {
            NSLog(@"ExtAudioFileRead failed. (err=%d)", err);
            return NO;
        }
        
        AudioBuffer audioBuffer = fillBufList.mBuffers[0];
        Float32 *frame = audioBuffer.mData;
        Float32 val = frame[0];
        
        if (fabs(val) > maxAmpl) {
            maxAmpl = fabs(val);
        }
        
        NSNumber *amp = [NSNumber numberWithFloat:val];
        [amplitudes addObject:amp];
        //NSLog(@"value: %f", val);
    }
    NSLog(@"Array size: %d", (int)[amplitudes count]);
    
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    /*
    // fill background
    [[NSColor whiteColor] set];
    NSRectFill ( [self bounds] );
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
    
    for (int i=0 ; i < [amplitudes count] ; ++i) {
        float ampl = [[amplitudes objectAtIndex:i] floatValue];
        float y = ampl / maxAmpl * [self bounds].size.height / 2;

        [wavePath moveToPoint:NSMakePoint(i, -y + [self bounds].size.height / 2)];
        [wavePath lineToPoint:NSMakePoint(i, y + [self bounds].size.height / 2)];
        
        if (i % 50 == 0) {
            NSString *s = [NSString stringWithFormat:@"%d", i];
            NSAttributedString * currentText=[[NSAttributedString alloc] initWithString:s attributes: attributes];
            
            NSSize attrSize = [currentText size];
            [currentText drawAtPoint:NSMakePoint(i - attrSize.width / 2, 0)];
        }
    }
    [wavePath stroke];
    
    if (xMouse > -1) {
        NSBezierPath *cursorPath = [NSBezierPath bezierPath];
        [cursorPath setLineWidth:1];
        [[NSColor redColor] set];
        [cursorPath moveToPoint:NSMakePoint(xMouse, 0)];
        [cursorPath lineToPoint:NSMakePoint(xMouse, [self bounds].size.height)];
        [cursorPath stroke];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    xMouse = -1;
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSPoint eventLocation = [theEvent locationInWindow];
    NSPoint center = [self convertPoint:eventLocation fromView:nil];
    xMouse = center.x;

    // TODO: inform the view of the dirty region, avoiding a complete redraw
    [self setNeedsDisplay:YES];
}

@end
