//
//  Player.m
//  Plectra
//
//  Created by OXullo Intersecans on 25/03/12.
//  Copyright (c) 2012 brainrapers.org. All rights reserved.
//
// Part of the following code is sampled from the following resource:
// http://my.safaribooksonline.com/9780321636973

#import "Player.h"

#define PLAYBACK_BUFFERS_NUM    3

NSString * const kBNRPlayerChangedStateNotification = @"PlayerChangedState";

#pragma mark - Private methods
@interface Player (private)
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer;
@end

// we only use time here as a guideline
// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
static void CalculateBytesForTime (AudioFileID inAudioFile, AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets)
{
    
    // we need to calculate how many packets we read at a time, and how big a buffer we need.
    // we base this on the size of the packets in the file and an approximate duration for each buffer.
    //
    // first check to see what the max size of a packet is, if it is bigger than our default
    // allocation size, that needs to become larger
    UInt32 maxPacketSize;
    UInt32 propSize = sizeof(maxPacketSize);
    OSStatus err = AudioFileGetProperty(inAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propSize, &maxPacketSize);
    
    if (err) {
        fprintf(stderr, "Couldn't get file's max packet size\n");
        exit(1);
    }
    
    static const int maxBufferSize = 0x10000; // limit size to 64K
    static const int minBufferSize = 0x4000; // limit size to 16K
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    // we're going to limit our size to our default
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize)
        *outBufferSize = maxBufferSize;
    else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    *outNumPackets = *outBufferSize / maxPacketSize;
}

#pragma mark - AQ Callback

static void AQOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer)
{
    Player *player = (Player *)inUserData;
    [player handleBufferCompleteForQueue:inAQ buffer:inCompleteAQBuffer];
}

#pragma mark -

@implementation Player

@synthesize state = _state;
@synthesize duration = _duration;

- (id)init
{
    self = [super init];
    
    if (self) {
        _playbackFile = nil;
        _queue = nil;
        _state = PLAYER_EMPTY;
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer
{
    if (_isDone) return;
    
    // read audio data from file into supplied buffer
    UInt32 numBytes;
    UInt32 nPackets = _numPacketsToRead;    
    
    OSStatus err = AudioFileReadPackets(_playbackFile,
                                        false,
                                        &numBytes,
                                        _packetDescs,
                                        _packetPosition,
                                        &nPackets,
                                        inBuffer->mAudioData);
    if (err) {
        fprintf(stderr, "AudioFileReadPackets failed\n");
        exit(1);
    }
    
    // enqueue buffer into the Audio Queue
    // if nPackets == 0 it means we are EOF (all data has been read from file)
    if (nPackets > 0)
    {
        inBuffer->mAudioDataByteSize = numBytes;      
        AudioQueueEnqueueBuffer(inAQ,
                                inBuffer,
                                (_packetDescs ? nPackets : 0),
                                _packetDescs);
        _packetPosition += nPackets;
    }
    else
    {
        OSStatus err = AudioQueueStop(inAQ, false);
        if (err) {
            NSLog(@"AudioQueueStop() failed");
            exit(1);
        }
        _isDone = true;
    }
}

- (void)changeState:(PlayerState)newState
{
    _state = newState;
    [[NSNotificationCenter defaultCenter] postNotificationName:kBNRPlayerChangedStateNotification object:self];
}

- (void)check:(OSStatus)returnCode withFailureText:(NSString *)failureText
{
    if (returnCode) {
        @throw [NSException exceptionWithName: @"PlayerException"
                                       reason: failureText
                                     userInfo: nil];
    }
}

- (void)copyEncoderCookieToQueue:(AudioQueueRef)queue
{
    UInt32 propertySize;
    OSStatus result = AudioFileGetPropertyInfo(_playbackFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);

    if (result == noErr && propertySize > 0)
    {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8) * propertySize);   
        [self check:AudioFileGetProperty(_playbackFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie)
         withFailureText:@"get cookie from file failed"];
        
        [self check:AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize)
         withFailureText:@"set cookie on queue failed"];
        
        free(magicCookie);
    }
}

- (void)playFileWithURL:(NSURL *)theURL
{
    NSLog(@"Requested playback of %@", theURL);
    [self reset];
    
    [self check:AudioFileOpenURL((CFURLRef)theURL, kAudioFileReadPermission, 0, &_playbackFile)
        withFailureText:@"AudioFileOpenURL() failed"];
    
    UInt32 propSize = sizeof(_dataFormat);
    
    // get the audio data format from the file
    [self check:AudioFileGetProperty(_playbackFile, kAudioFilePropertyDataFormat, &propSize, &_dataFormat)
        withFailureText:@"AudioFileGetProperty() failed while attempting to retrieve data format"];
    
    // create a output (playback) queue
    [self check:AudioQueueNewOutput(&_dataFormat, // ASBD
                                   AQOutputCallback, // Callback
                                   self, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &_queue) // output: reference to AudioQueue object
        withFailureText:@"AudioQueueNewOutput() failed"];
    
    UInt32 propertySize = sizeof(_duration);
    [self check:AudioFileGetProperty(_playbackFile, kAudioFilePropertyEstimatedDuration, &propertySize, &_duration) withFailureText:@"AudioFileGetProperty() failed"];
    
    NSLog(@"Duration: %f", _duration);
    
    UInt32 bufferByteSize;
    CalculateBytesForTime(_playbackFile, _dataFormat,  0.5, &bufferByteSize, &_numPacketsToRead);

    // check if we are dealing with a VBR file. ASBDs for VBR files always have 
    // mBytesPerPacket and mFramesPerPacket as 0 since they can fluctuate at any time.
    // If we are dealing with a VBR file, we allocate memory to hold the packet descriptions
    BOOL isFormatVBR = (_dataFormat.mBytesPerPacket == 0 || _dataFormat.mFramesPerPacket == 0);
    
    if (isFormatVBR) {
        _packetDescs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * _numPacketsToRead);
    } else {
        _packetDescs = NULL; // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
    }
    
    [self copyEncoderCookieToQueue:_queue];
    
    AudioQueueBufferRef buffers[PLAYBACK_BUFFERS_NUM];
    _isDone = false;
    _packetPosition = 0;
    
    int i;
    for (i = 0; i < PLAYBACK_BUFFERS_NUM; ++i)
    {
        [self check:AudioQueueAllocateBuffer(_queue, bufferByteSize, &buffers[i])
            withFailureText:@"AudioQueueAllocateBuffer failed"];
        
        // manually invoke callback to fill buffers with data
        AQOutputCallback(self, _queue, buffers[i]);
        
        // EOF (the entire file's contents fit in the buffers)
        if (_isDone) {
            break;
        }
    }
    
    [self check:AudioQueueStart(_queue, NULL)
        withFailureText:@"AudioQueueStart failed"];

    [self changeState:PLAYER_PLAYING];
}

- (void)reset
{
    if (_queue) {
        [self check:AudioQueueStop(_queue, true) withFailureText:@"AudioQueueStop() failed"];
    }
    
    if (_playbackFile) {
        [self check:AudioFileClose(_playbackFile)
    withFailureText:@"AudioFileClose() failed"];
        _playbackFile = nil;
    }
    
    if (_queue) {
        [self check:AudioQueueDispose(_queue, true)
    withFailureText:@"AudioQueueDispose() failed"];
        _queue = nil;
    }

    [self changeState:PLAYER_EMPTY];
    _lastProgress = 0.0;
}

- (void)pause
{
    NSAssert(_state == PLAYER_PLAYING, @"Pause requested but not playing");
    
    [self check:AudioQueuePause(_queue) withFailureText:@"AudioQueuePause() failed"];
    [self changeState:PLAYER_PAUSED];
}

- (void)resume
{
    NSAssert(_state == PLAYER_PAUSED, @"Resume requested but not paused");
    [self check:AudioQueueStart(_queue, NULL) withFailureText:@"AudioQueueStart() failed"];
    [self changeState:PLAYER_PLAYING];
}

- (double)currentTime
{
	@synchronized(self)
	{
        if (self.state != PLAYER_PLAYING && self.state != PLAYER_PAUSED)
        {
            return _lastProgress;
        }
        
        AudioTimeStamp queueTime;
        Boolean discontinuity;
        OSStatus err = AudioQueueGetCurrentTime(_queue, NULL, &queueTime, &discontinuity);
        
        if (err) {
            return _lastProgress;
        }
        
        // TODO: WTF
        double seekTime = 0.0;
        double progress = seekTime + queueTime.mSampleTime / _dataFormat.mSampleRate;
        if (progress < 0.0)
        {
            progress = 0.0;
        }
        
        _lastProgress = progress;
        return progress;
	}
	
	return _lastProgress;
}

@end
