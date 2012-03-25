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

static void MyAQOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer)
{
    PlayerInfo *aqp = (PlayerInfo*)inUserData;
    if (aqp->isDone) return;
    
    // read audio data from file into supplied buffer
    UInt32 numBytes;
    UInt32 nPackets = aqp->numPacketsToRead;    
    
    OSStatus err = AudioFileReadPackets(aqp->playbackFile,
                                    false,
                                    &numBytes,
                                    aqp->packetDescs,
                                    aqp->packetPosition,
                                    &nPackets,
                                    inCompleteAQBuffer->mAudioData);
    if (err) {
        fprintf(stderr, "AudioFileReadPackets failed\n");
        exit(1);
    }
    
    // enqueue buffer into the Audio Queue
    // if nPackets == 0 it means we are EOF (all data has been read from file)
    if (nPackets > 0)
    {
        inCompleteAQBuffer->mAudioDataByteSize = numBytes;      
        AudioQueueEnqueueBuffer(inAQ,
                                inCompleteAQBuffer,
                                (aqp->packetDescs ? nPackets : 0),
                                aqp->packetDescs);
        aqp->packetPosition += nPackets;
    }
    else
    {
        OSStatus err = AudioQueueStop(inAQ, false);
        if (err) {
            fprintf(stderr, "AudioQueueStop failed\n");
            exit(1);
        }
        aqp->isDone = true;
    }
}

@implementation Player

- (id)init
{
    self = [super init];
    
    if (self) {
        _playerInfo = (PlayerInfo *)malloc(sizeof(PlayerInfo));
        _playerInfo->playbackFile = nil;
        _queue = nil;
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
    free(_playerInfo);
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
    OSStatus result = AudioFileGetPropertyInfo(_playerInfo->playbackFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);

    if (result == noErr && propertySize > 0)
    {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8) * propertySize);   
        [self check:AudioFileGetProperty(_playerInfo->playbackFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie)
         withFailureText:@"get cookie from file failed"];
        
        [self check:AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize)
         withFailureText:@"set cookie on queue failed"];
        
        free(magicCookie);
    }
}

- (void)playFileWithURL:(NSURL *)theURL
{
    NSLog(@"Requested playback of %@", theURL);
    [self stop];
    
    [self check:AudioFileOpenURL((CFURLRef)theURL, kAudioFileReadPermission, 0, &_playerInfo->playbackFile)
        withFailureText:@"AudioFileOpenURL() failed"];
    
    // get the audio data format from the file
    AudioStreamBasicDescription dataFormat;
    UInt32 propSize = sizeof(dataFormat);
    
    [self check:AudioFileGetProperty(_playerInfo->playbackFile, kAudioFilePropertyDataFormat, &propSize, &dataFormat)
        withFailureText:@"AudioFileGetProperty() failed while attempting to retrieve data format"];
    
    // create a output (playback) queue
    [self check:AudioQueueNewOutput(&dataFormat, // ASBD
                                   MyAQOutputCallback, // Callback
                                   _playerInfo, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &_queue) // output: reference to AudioQueue object
        withFailureText:@"AudioQueueNewOutput() failed"];
    
    UInt32 bufferByteSize;
    
    CalculateBytesForTime(_playerInfo->playbackFile, dataFormat,  0.5, &bufferByteSize, &_playerInfo->numPacketsToRead);

    // check if we are dealing with a VBR file. ASBDs for VBR files always have 
    // mBytesPerPacket and mFramesPerPacket as 0 since they can fluctuate at any time.
    // If we are dealing with a VBR file, we allocate memory to hold the packet descriptions
    BOOL isFormatVBR = (dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket == 0);
    
    if (isFormatVBR) {
        _playerInfo->packetDescs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * _playerInfo->numPacketsToRead);
    } else {
        _playerInfo->packetDescs = NULL; // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
    }
    
    [self copyEncoderCookieToQueue:_queue];
    
    AudioQueueBufferRef buffers[PLAYBACK_BUFFERS_NUM];
    _playerInfo->isDone = false;
    _playerInfo->packetPosition = 0;
    
    int i;
    for (i = 0; i < PLAYBACK_BUFFERS_NUM; ++i)
    {
        [self check:AudioQueueAllocateBuffer(_queue, bufferByteSize, &buffers[i])
            withFailureText:@"AudioQueueAllocateBuffer failed"];
        
        // manually invoke callback to fill buffers with data
        MyAQOutputCallback(_playerInfo, _queue, buffers[i]);
        
        // EOF (the entire file's contents fit in the buffers)
        if (_playerInfo->isDone) {
            break;
        }
    }
    
    [self check:AudioQueueStart(_queue, NULL)
        withFailureText:@"AudioQueueStart failed"];

}

- (void)stop
{
    if (_queue) {
        [self check:AudioQueueStop(_queue, true) withFailureText:@"AudioQueueStop() failed"];
    }
    
    if (_playerInfo->playbackFile) {
        [self check:AudioFileClose(_playerInfo->playbackFile)
    withFailureText:@"AudioFileClose() failed"];
         _playerInfo->playbackFile = nil;
    }
    
    if (_queue) {
        [self check:AudioQueueDispose(_queue, true)
    withFailureText:@"AudioQueueDispose() failed"];
        _queue = nil;
    }
}

@end
