
#import "RNVideoPoc.h"
#import "RCTLog.h"
#import "RCTConvert.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@implementation RNVideoPoc

// Credit to / heavily borrowed from:
// Merging - https://github.com/MostWantIT/react-native-video-editor
// Thumbnails - https://github.com/phuochau/react-native-thumbnail
// Trimming - https://github.com/shahen94/react-native-video-processing

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(merge:(NSArray *)fileNames
                  errorCallback:(RCTResponseSenderBlock)failureCallback
                  callback:(RCTResponseSenderBlock)successCallback) {

    NSLog(@"%@ %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    [self MergeVideo:fileNames callback:successCallback];

    //successCallback(@[@"merge video", fileNames[0]]);
}

-(void)LoopVideo:(NSArray *)fileNames callback:(RCTResponseSenderBlock)successCallback
{
    for (id object in fileNames)
    {
        NSLog(@"video: %@", object);
    }
}

-(void)MergeVideo:(NSArray *)fileNames callback:(RCTResponseSenderBlock)successCallback
{
    CGFloat totalDuration;
    totalDuration = 0;

    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTime insertTime = kCMTimeZero;
    CGAffineTransform originalTransform;

    for (id object in fileNames)
    {
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:object]];
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
 
        [videoTrack insertTimeRange:timeRange
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                             atTime:insertTime
                              error:nil];
        [audioTrack insertTimeRange:timeRange
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                             atTime:insertTime
                              error:nil];

        insertTime = CMTimeAdd(insertTime,asset.duration);
        
        // Get the first track from the asset and its transform.
        NSArray* tracks = [asset tracks];
        AVAssetTrack* track = [tracks objectAtIndex:0];
        originalTransform = [track preferredTransform];
    }

    // Use the transform from the original track to set the video track transform.
    if (originalTransform.a || originalTransform.b || originalTransform.c || originalTransform.d) {
        videoTrack.preferredTransform = originalTransform;
    }

    NSString* documentsDirectory= [self applicationDocumentsDirectory];
    
    // TODO - ensure this is not overwriting other videos
    NSString * myDocumentPath = [documentsDirectory stringByAppendingPathComponent:@"merged_video.mp4"];
    NSURL * urlVideoMain = [[NSURL alloc] initFileURLWithPath: myDocumentPath];

    if([[NSFileManager defaultManager] fileExistsAtPath:myDocumentPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:myDocumentPath error:nil];
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = urlVideoMain;
    exporter.outputFileType = @"com.apple.quicktime-movie";
    exporter.shouldOptimizeForNetworkUse = YES;

    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch ([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
                break;
                
            case AVAssetExportSessionStatusCancelled:
                break;
                
            case AVAssetExportSessionStatusCompleted:
                successCallback(@[@"merge video complete", myDocumentPath]);
                break;
                
            default:
                break;
        }
    }];
}

- (NSString*) applicationDocumentsDirectory
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}


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
        exporter.outputFileType = @"com.apple.quicktime-movie";
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
@end
