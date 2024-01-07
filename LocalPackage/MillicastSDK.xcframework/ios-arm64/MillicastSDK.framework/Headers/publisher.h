/**
  * @file publisher.h
  * @author David Baldassin
  * @copyright Copyright 2021 CoSMoSoftware.
  * @date 07/2021
  */

#import <MillicastSDK/client.h>
#import <MillicastSDK/exports.h>

// Forward declarations ///////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@class MCVideoTrack;
@class MCAudioTrack;
@class MCTrack;

// Publisher //////////////////////////////////////////////////////////////////

/**
 * @brief The Listener protocol for the Publisher class.
 * It adds the publishing event on top of the Client listener
 * You must implement this protocol and set a listener with setListener
 * to be able to receive events from the publisher.
 */

@protocol MCPublisherListener <MCListener>

/**
 * @brief onPublishing is called when a peerconnection has been established
 * with Millicast and the media exchange has started.
 */

- (void) onPublishing;

/**
 * @brief Called when an error occuredwhile establishing the peerconnection
 * @param error The reason of the error
 * @param
 */
- (void) onPublishingError:(NSString*) error;

/**
 * @brief Called when the first viewer is viewing the stream
 */
- (void) onActive;

/**
 * @brief Called when the last viewer stops viewing the stream
 */
- (void) onInactive;

/**
 * @brief Called after a frame has been encoded if you need to add data
 * to this frame before the frame is being passed to the RTP packetizer
 * @param data Empty array to be filled with user data. Must be filled with NSNumber with unsignedChar value
 * @param ssrc Synchronization source of the frame
 * @param timestamp Timestamp of the frame
 */
@optional
- (void) onTransformableFrame:(NSMutableArray<NSNumber*>*)data withSsrc:(int) ssrc withTimestamp:(int) timestamp;

@end

/**
 * @brief The RecordingListener protocol for the Publisher class.
 * Contains methods that will be called on specific events regarding recording controls.
 * You must implement this protocol and set a listener with setRecordingListener
 * to be able to receive events from the recording controls API.
 */

@protocol MCRecordingListener

/**
 * @brief Called after a request to start recording finishes successfully
 */
- (void) ownRecordingStarted;

/**
 * @brief Called after a request to stop recording finishes successfully
 */
- (void) ownRecordingStopped;

/**
 * @brief Called after a request to start recording failes
 */
- (void) failedToStartRecording;

/**
 * @brief Called after a request to stop recording failes
 */
- (void) failedToStopRecording;

@end


/**
 * @brief The Credentials interface represents the credentials needed to be able to
 * connect and publish to a Millicast stream.
 * @sa https://dash.millicast.com/docs.html
 */

MILLICAST_API @interface MCPublisherCredentials : NSObject

/** @brief The name of the stream we want to publish */
@property (nonatomic, strong) NSString* streamName;
/** @brief The publishing token as described in the Millicast API */
@property (nonatomic, strong) NSString* token;
/** @brief The publish API URL as described in the Millicast API */
@property (nonatomic, strong) NSString* apiUrl;

@end

/**
 * @brief The Publisher interface. Its purpose is to publish media to a Millicast stream.
 */

MILLICAST_API @interface MCPublisher : NSObject<MCClient>

/**
 * @brief Publish a stream to Millicast.
 * You must be connected first in order to publish a stream.
 * When publishing, the SDK sets the AVAudioSession to the playAndRecord
 * category, with voiceChat mode and allowBluetooth option. If desired, the App
 * can configure the AVAudioSession with its own settings. For an example,
 * please see how the Millicast iOS Sample App configures the AVAudioSession at:
 * https://github.com/millicast/Millicast-ObjC-SDK-iOS-Sample-App-in-Swift
 * @return true if now trying to, or is already publishing, false
 * otherwise.
 * @remark After trying，a successful publish results in the
 * Listener's method onPublishing being called.
 */

- (BOOL) publish;

/**
 * @brief Publish a stream to Millicast.
 * You must be connected first in order to publish a stream.
 * When publishing, the SDK sets the AVAudioSession to the playAndRecord
 * category, with voiceChat mode and allowBluetooth option. If desired, the App
 * can configure the AVAudioSession with its own settings. For an example,
 * please see how the Millicast iOS Sample App configures the AVAudioSession at:
 * https://github.com/millicast/Millicast-ObjC-SDK-iOS-Sample-App-in-Swift
 * @param opts Optional options to pass to publishing. Only Publishing relevant
 * are allowed - others set will be ignored.
 * @return true if now trying to, or is already publishing, false
 * otherwise.
 * @remark After trying，a successful publish results in the
 * Listener's method onPublishing being called.
 */

- (BOOL) publishWithOptions:(nonnull MCClientOptions *) opts;

/**
 * @brief Stop sending media to Millicast.
 * The SDK will automatically disconnect after unpublish.
 * @return false if unable to reach a disconnected state, true otherwise.
 */

- (BOOL)unpublish;

/**
 * @brief Tell if the publisher is publishing
 * @return true if the publisher is publishing, false otherwise.
*/

- (BOOL) isPublishing;

/**
 * @brief Set the publisher credentials.
 * @param credentials The credentials
 * @return true if the credentials are valid and set correctly, false otherwise.
*/

- (BOOL) setCredentials: (MCPublisherCredentials*) credentials;

/**
 * @brief Get the current publisher credentials.
 * @return The current credentials set in the publisher.
*/

- (MCPublisherCredentials*) getCredentials;

/**
 * @brief Add a track that will be used to publish media (audio or video).
 * @param track The track.
*/

- (void) addTrack:(MCTrack*) track;

/**
 * @brief clearTracks will clear all track added to the publisher.
*/

- (void) clearTracks;

/**
 * @brief Enable scalable video coding with a single ssrc
 * @param mode The scalability mode
 * @remarks call this method before publishing
 * @deprecated since 1.6.0 use the MCClientOptions svcMode field instead.
*/
- (void) enableSvcWithMode:(MCScalabilityMode) mode __attribute__((deprecated));

/**
 * @brief Disable scalable video coding and set default publish parameter
 * @deprecated since 1.6.0 use the MCClientOptions svcMode field instead.
*/
- (void) disableSvc __attribute__((deprecated));

/**
 * @brief enable simulcast.
 * @param enable true to enable simulcast. false to disable it.
 * @remarks Call this before publishing
 * @deprecated since 1.6.0 use the MCClientOptions simulcast field instead.
*/
- (void) enableSimulcast:(BOOL) enable __attribute((deprecated));

/**
 * @brief Get the transceiver mid associated to a track
 * @param trackId The id of the track we want to retrieve the mid
 * @return The transceiver mid. nil if there is no mid found
 */
- (NSString*) getMid:(NSString*) trackId;

/**
 * @brief Create a publisher object.
 * @return A publisher object.
*/

+ (MCPublisher*) create;

/**
 * @brief start recording.
 * @remarks Call this after publishing
*/
-(void) record;


/**
 * @brief stop recording.
 * @remarks Call this after publishing
*/
-(void) unrecord;

-(void) setRecordingListener:(nullable id<MCRecordingListener>) rlistener;

@end

NS_ASSUME_NONNULL_END
