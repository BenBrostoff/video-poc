#import "RNVideoPoc.h"
#import "RCTLog.h"
#import "RCTConvert.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@implementation RNVideoPoc

/*
Credit to:
- Apple docs - https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/03_Editing.html#//apple_ref/doc/uid/TP40010188-CH8-SW18
- Merging - https://github.com/MostWantIT/react-native-video-editor
- Merging with video orientation -
- Thumbnails - https://github.com/phuochau/react-native-thumbnail
- Trimming - https://github.com/shahen94/react-native-video-processing
*/

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(getThumbnail:(NSString *)filepath resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        filepath = [filepath stringByReplacingOccurrencesOfString:@"file://"
                                                       withString:@""];
        NSURL *vidURL = [NSURL fileURLWithPath:filepath];
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:vidURL options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        
        NSError *err = NULL;
        
        CMTime time = CMTimeMake(1, 60);
        CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&err];

        // TODO - determine why logging does not work here.
        NSLog(@"err==%@, imageRef==%@", err, imgRef);
        RCTLogInfo(@"err==%@, imageRef==%@", err, imgRef);

        UIImage *thumbnail = [[UIImage alloc] initWithCGImage:imgRef];

        // save to Expo
        NSString* documentsDirectory= [self applicationDocumentsDirectory];
        NSString * fullPath = [documentsDirectory stringByAppendingPathComponent: [NSString stringWithFormat:@"thumbNail-%@.jpg", [[NSProcessInfo processInfo] globallyUniqueString]]];
        NSURL * someURL = [[NSURL alloc] initFileURLWithPath: fullPath];
        NSString* finalPath = someURL.absoluteString;

        
        NSData *data = UIImageJPEGRepresentation(thumbnail, 1.0);
        NSFileManager *fileManager = [NSFileManager  defaultManager];
        [fileManager createFileAtPath:fullPath contents:data attributes:nil];

        // Other than path, most props are for debugging. It is often necessary to invoke decodeURI on JS side for filepath.
        if (resolve)
            resolve(@{ @"path" : finalPath,
                       @"width" : [NSNumber numberWithFloat: thumbnail.size.width],
                       @"height" : [NSNumber numberWithFloat: thumbnail.size.height],
                       @"err": [NSNumber numberWithFloat: thumbnail.scale],
                       @"original": filepath
                       }
                    );
    } @catch(NSException *e) {
        reject(e.reason, nil, nil);
    }
}

RCT_EXPORT_METHOD(trim:(NSString *)filepath
                  options:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    @try {
        filepath = [filepath stringByReplacingOccurrencesOfString:@"file://"
                                                       withString:@""];
        NSURL *vidURL = [NSURL fileURLWithPath:filepath];

        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:vidURL options:nil];
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];

        NSString* documentsDirectory= [self applicationDocumentsDirectory];
        NSString * fullPath = [documentsDirectory stringByAppendingPathComponent: [NSString stringWithFormat:@"trimmedVideo-%@.mp4", [[NSProcessInfo processInfo] globallyUniqueString]]];
        NSURL * urlVideoMain = [[NSURL alloc] initFileURLWithPath: fullPath];

        exporter.outputURL = urlVideoMain;
        exporter.outputFileType =  @"com.apple.quicktime-movie";
        exporter.shouldOptimizeForNetworkUse = YES;

        NSNumber *startTime = [RCTConvert NSNumber:options[@"startTime"]];
        NSNumber *endTime = [RCTConvert NSNumber:options[@"endTime"]];

        int64_t sTime = startTime.doubleValue;
        int64_t eTime = endTime.doubleValue;

        // Numerator / Denom -> Seconds, pass sTime and eTime in seconds
        CMTime convertedStartTime = CMTimeMake(sTime, 1);
        CMTime convertedEndTime = CMTimeMake(eTime, 1);

        exporter.timeRange = CMTimeRangeMake(convertedStartTime, convertedEndTime);
        
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            switch ([exporter status])
            {
                case AVAssetExportSessionStatusFailed:
                    // TODO - make rejection
                    NSLog(@"%@", exporter.error);
                    resolve(@{ @"failed" : fullPath});
                    break;
                case AVAssetExportSessionStatusCancelled:
                    // TODO - make rejection
                    resolve(@{ @"cancel" : fullPath});
                    break;
                    
                case AVAssetExportSessionStatusCompleted:
                    resolve(@{ @"path" : fullPath});
                    break;
                    
                default:
                    break;
            }
        }];
    } @catch(NSException *e) {
        reject(e.reason, nil, nil);
    }
}

RCT_EXPORT_METHOD(merge:(NSArray *)fileNames
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject){
    @try {
        // Assume 16:9 / 9:16 final orientation ratio
        CGFloat EXPECTED_HEIGHT = 1280.0;
        CGFloat EXPECTED_WIDTH = 720.0;
        
        AVMutableComposition *composition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        NSMutableArray *instructions = [NSMutableArray new];
        
        __block BOOL errorOccurred = NO;
        __block CMTime currentTime = kCMTimeZero;
        __block int32_t highestFrameRate = 0;
        __block BOOL isPortrait_ = NO;
        __block BOOL setMergedOrientation = NO;
        __block BOOL mergedOrientationPortrait = NO;
        [fileNames enumerateObjectsUsingBlock:^(id filepath, NSUInteger idx, BOOL *stop) {
            filepath = [filepath stringByReplacingOccurrencesOfString:@"file://"
                                                                   withString:@""];
            NSURL *fileURL = [NSURL fileURLWithPath:filepath];

            NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@YES};
            AVURLAsset *sourceAsset = [AVURLAsset URLAssetWithURL:fileURL options:options];
            AVAssetTrack *videoAsset = [[sourceAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
            AVAssetTrack *audioAsset = [[sourceAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        
            int32_t currentFrameRate = (int)roundf(videoAsset.nominalFrameRate);
            highestFrameRate = (currentFrameRate > highestFrameRate) ? currentFrameRate : highestFrameRate;
            
            NSLog(@"* %@ (%dfps)", [fileURL lastPathComponent], currentFrameRate);
            
            CMTime trimmingTime = CMTimeMake(lround(videoAsset.naturalTimeScale / videoAsset.nominalFrameRate), videoAsset.naturalTimeScale);
            CMTimeRange timeRange = CMTimeRangeMake(trimmingTime, CMTimeSubtract(videoAsset.timeRange.duration, trimmingTime));
            
            NSError *videoError;
            BOOL videoResult = [videoTrack insertTimeRange:timeRange ofTrack:videoAsset atTime:currentTime error:&videoError];
            NSError *audioError;
            BOOL audioResult = [audioTrack insertTimeRange:timeRange ofTrack:audioAsset atTime:currentTime error:&audioError];
            if(!videoResult || !audioResult || videoError || audioError) {
                errorOccurred = YES;
            }
            
            // Set merged video properties based on the first video
            isPortrait_ = [self isVideoPortrait:videoAsset];
            if (!setMergedOrientation) {
                setMergedOrientation = TRUE;
                mergedOrientationPortrait = isPortrait_;
            }
            
            double videoHeight = videoAsset.naturalSize.height;
            double videoWidth = videoAsset.naturalSize.width;
            CGAffineTransform originalTransform = videoAsset.preferredTransform;
            CGAffineTransform useTransform;
            
            // Set instructions to orient and scale properly
            // NOTE: all video dimensions reflect that they are filmed in portrait
            if (isPortrait_ && mergedOrientationPortrait) {
                // force height to be in correct ratio - screen is opposite recording
                double normalizedWidth = videoHeight;
                double normalizedHeight = videoWidth;
                
                double scaleRatioHeight = EXPECTED_WIDTH / normalizedWidth;
                double scaleRatioWidth = EXPECTED_HEIGHT / normalizedHeight;
                CGAffineTransform scale = CGAffineTransformMakeScale(scaleRatioWidth, scaleRatioHeight);
                useTransform = CGAffineTransformConcat(originalTransform, scale);
                
                // hack to fix small sizes
                CGFloat tx = useTransform.tx;
                if (tx > EXPECTED_WIDTH) {
                    CGAffineTransform reTransform = CGAffineTransformMakeTranslation(EXPECTED_WIDTH - tx, 0.0);
                    useTransform = CGAffineTransformConcat(useTransform, reTransform);
                }
            } else if (!isPortrait_ && mergedOrientationPortrait) {
                // downscale width of landscape video to fit portrait
                double scaleToFitRatio = EXPECTED_WIDTH / videoWidth;
                
                CGAffineTransform scale = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio);
                CGAffineTransform first = CGAffineTransformConcat(originalTransform, scale); // scale
                
                // TODO - determine correct method for height middling
                CGAffineTransform reTransform = CGAffineTransformMakeTranslation(0.0, EXPECTED_WIDTH / 1.75);
                useTransform = CGAffineTransformConcat(first, reTransform); // move down
            } else if (!isPortrait_ && !mergedOrientationPortrait) {
                // Scale same orientation videos
                double scaleToFitRatio = EXPECTED_HEIGHT / videoWidth;
                CGAffineTransform scale = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio);
                useTransform = CGAffineTransformConcat(originalTransform, scale);
            } else {
                // isPortrait && !mergedOrientationPortrait
                // downscale height of portrait video to fit landscape
                double scaleToFitRatio = EXPECTED_WIDTH / videoWidth;
                CGAffineTransform scale = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio);
                CGAffineTransform first = CGAffineTransformConcat(originalTransform, scale); // scale

                CGAffineTransform reTransform = CGAffineTransformMakeTranslation(EXPECTED_WIDTH + 100 - first.tx, 0.0);
                useTransform = CGAffineTransformConcat(first, reTransform); // move right
            }

            AVMutableVideoCompositionInstruction *videoCompositionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            videoCompositionInstruction.timeRange = CMTimeRangeMake(currentTime, timeRange.duration);
            AVMutableVideoCompositionLayerInstruction *videoLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
            [videoLayerInstruction setTransform:useTransform atTime:currentTime];
            videoCompositionInstruction.layerInstructions = @[videoLayerInstruction];
            [instructions addObject:videoCompositionInstruction];

            currentTime = CMTimeAdd(currentTime, timeRange.duration);
        }];
        
        if (errorOccurred == YES) {
            reject(@"Error adding video or audio", nil, nil);
        }
    
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];

        NSString* documentsDirectory= [self applicationDocumentsDirectory];
        NSString * myDocumentPath = [documentsDirectory stringByAppendingPathComponent: [NSString stringWithFormat:@"merged_video-%@.mp4", [[NSProcessInfo processInfo] globallyUniqueString]]];
        NSURL * urlVideoMain = [[NSURL alloc] initFileURLWithPath: myDocumentPath];

        exportSession.outputURL = urlVideoMain;
        exportSession.outputFileType =  @"com.apple.quicktime-movie";
        exportSession.shouldOptimizeForNetworkUse = YES;

        AVMutableVideoComposition *mutableVideoComposition = [AVMutableVideoComposition videoComposition];
        mutableVideoComposition.instructions = instructions;
        mutableVideoComposition.frameDuration = CMTimeMake(1, highestFrameRate);

        if (mergedOrientationPortrait) {
            mutableVideoComposition.renderSize =  CGSizeMake(EXPECTED_WIDTH, EXPECTED_HEIGHT);
        } else {
            mutableVideoComposition.renderSize = CGSizeMake(EXPECTED_HEIGHT, EXPECTED_WIDTH);
        }

        exportSession.videoComposition = mutableVideoComposition;

        
        NSLog(@"Composition Duration: %ld seconds", lround(CMTimeGetSeconds(composition.duration)));
        NSLog(@"Composition Framerate: %d fps", highestFrameRate);

        __block NSError *exportErr = nil;
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch (exportSession.status) {
                case AVAssetExportSessionStatusFailed:{
                    exportErr = exportSession.error;
                    reject(exportErr.description, nil, nil);
                    break;
                }
                case AVAssetExportSessionStatusCancelled:{
                    exportErr = exportSession.error;
                    reject(exportErr.description, nil, nil);
                    break;
                }
                case AVAssetExportSessionStatusCompleted: {
                    resolve(@{ @"path" : myDocumentPath});
                    break;
                }
                case AVAssetExportSessionStatusUnknown: {
                    NSLog(@"Export Status: Unknown");
                }
                case AVAssetExportSessionStatusExporting : {
                    NSLog(@"Export Status: Exporting");
                }
                case AVAssetExportSessionStatusWaiting: {
                    NSLog(@"Export Status: Waiting");
                }
            };
        }];
    } @catch(NSException *e) {
        reject(e.reason, nil, nil);
    }
}

- (NSString*) applicationDocumentsDirectory
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

-(BOOL) isVideoPortrait:(AVAssetTrack *)videoTrack{
    BOOL isPortrait = FALSE;
    CGAffineTransform t = videoTrack.preferredTransform;

    // Portrait
    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0)
    {
        isPortrait = YES;
    }

    // PortraitUpsideDown
    if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0)  {
        isPortrait = YES;
    }

    // LandscapeRight
    if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0)
    {
        isPortrait = FALSE;
    }

    // LandscapeLeft
    if (t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0)
    {
        isPortrait = FALSE;
    }

    return isPortrait;
}

@end
