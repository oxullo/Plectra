//
//  WaveformView.m
//  Plectra
//
//  Created by OXullo Intersecans on 18/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WaveformView.h"

#define	CHANNEL_NUM		1

@implementation WaveformView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        amplitudes = [[NSMutableArray alloc] init];
        maxAmpl = 0.0;
        /*
        for (int i=0 ; i < 500 ; ++i) {
            [amplitudes addObject:[[NSNumber alloc] initWithInt:arc4random() % 100]];
        }
        NSLog(@"Amplitudes : %lu", [amplitudes count]);
         */
    }
    
    return self;
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
    
    /*
	tFormat.mChannelsPerFrame = CHANNEL_NUM;
	
	tFormat.mSampleRate = mSamplingRate;
	tFormat.mFormatFlags = kAudioFormatFlagsCanonical;
	tFormat.mFormatID = kAudioFormatLinearPCM;
	tFormat.mBytesPerPacket = 1;
	tFormat.mFramesPerPacket = 1;
	tFormat.mBytesPerFrame = 1;
	tFormat.mBitsPerChannel = 8;
    */
	
    NSLog( @"mSampleRate=%f\n", inputFormat.mSampleRate );
	NSLog( @"mFormatID=0x%x\n", inputFormat.mFormatID );
	NSLog( @"mSampleRate=%d\n", inputFormat.mFormatFlags );
	NSLog( @"mBytesPerPacket=%d\n", inputFormat.mBytesPerPacket );
	NSLog( @"mFramesPerPacket=%d\n", inputFormat.mFramesPerPacket );
	NSLog( @"mBytesPerFrame=%d\n", inputFormat.mBytesPerFrame );
	NSLog( @"mChannelsPerFrame=%d\n", inputFormat.mChannelsPerFrame );
	NSLog( @"mBitsPerChannel=%d\n", inputFormat.mBitsPerChannel );
    
    AudioStreamBasicDescription clientFormat = inputFormat;
    
    //clientFormat.mSampleRate = 44100.0;
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
    
    SInt64 step = mFrameCount / 1000;
    
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
    /*
    while (1) 
	{	
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = kSrcBufSize;
		fillBufList.mBuffers[0].mData = srcBuffer;
        
		// client format is always linear PCM - so here we determine how many frames of lpcm
		// we can read/write given our buffer size
		UInt32 numFrames = (kSrcBufSize / clientFormat.mBytesPerFrame);
		
		// printf("test %d\n", numFrames);
        
		err = ExtAudioFileRead (infile, &numFrames, &fillBufList);
		XThrowIfError (err, "ExtAudioFileRead");	
		if (!numFrames) {
			// this is our termination condition
			break;
		}
		
		err = ExtAudioFileWrite(outfile, numFrames, &fillBufList);	
		XThrowIfError (err, "ExtAudioFileWrite");	
	}
     */
    
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSLog(@"Redraw, maxAmpl=%f", maxAmpl);

    /*
    // fill background
    [[NSColor whiteColor] set];
    NSRectFill ( [self bounds] );
    */
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:1.5];
    
    [path moveToPoint:NSMakePoint(0, 50)];

    for (int i=0 ; i < [amplitudes count] ; ++i) {
        float ampl = [[amplitudes objectAtIndex:i] floatValue];
        float y = ampl / maxAmpl * 60 + 60;
        //NSLog(@"x=%d y=%f", i, y);
        [path lineToPoint:NSMakePoint(i, y)];
    }

    [[NSColor blackColor] set]; 
    [path stroke];
    
//    // fill target rect
//    NSRect rect1 = NSMakeRect ( 21,21,210,210 );
//    [white set];
//    NSRectFill ( rect1 );
//    
//    NSBezierPath * path = [NSBezierPath bezierPath];
//    [path setLineWidth: 4];
//    
//    NSPoint startPoint = {  21, 21 };
//    NSPoint endPoint   = { 128,128 };
//    
//    [path  moveToPoint: startPoint];	
//    
//    [path curveToPoint: endPoint
//         controlPoint1: NSMakePoint ( 128, 21 )
//         controlPoint2: NSMakePoint (  21,128 )];
//    
//    [[NSColor whiteColor] set];
//    [path fill];
//    
//    [[NSColor grayColor] set]; 
//    [path stroke];
}


@end
