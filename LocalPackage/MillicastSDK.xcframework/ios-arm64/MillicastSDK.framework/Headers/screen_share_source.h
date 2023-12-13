#import <ReplayKit/ReplayKit.h>
#import <MillicastSDK/exports.h>
#import <MillicastSDK/source.h>
#import <MillicastSDK/track.h>

/**
 * @brief a Millicast App Screen Capture Source. It internally uses ReplayKit to capture the screen 
 * of the application. 
 * */
MILLICAST_API @interface MCAppShareSource: NSObject
@property(nonatomic, readonly) NSString * name;
-(nonnull instancetype) initWithRecorder:(RPScreenRecorder  * _Nonnull) recorder;
-(nonnull instancetype) initWithName: (NSString  * _Nonnull ) name recorder: (RPScreenRecorder * _Nonnull) recorder;
-(void) startCaptureWithCompletionHandler: (void (^)(MCAudioTrack * _Nullable audioTrack, MCVideoTrack * _Nullable videoTrack, NSError * _Nullable))completionHandler;
-(void) stopCaptureWithCompletionHandler: (void (^)(NSError * _Nullable))completionHandler;
@end
