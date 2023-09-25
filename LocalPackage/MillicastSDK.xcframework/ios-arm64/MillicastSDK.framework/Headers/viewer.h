/**
  * @file viewer.h
  * @author David Baldassin
  * @copyright Copyright 2021 CoSMoSoftware.
  * @date 07/2021
  */

#import <MillicastSDK/client.h>
#import <MillicastSDK/exports.h>

// Forward declarations ///////////////////////////////////////////////////////
@class MCVideoTrack;
@class MCAudioTrack;

// Viewer /////////////////////////////////////////////////////////////////////

/**
 * @brief The layer data is used to select a simulcast/svc layer.
 * by sending a command to the server using the select or project method.
 */
MILLICAST_API @interface MCLayerData : NSObject

/** @brief The encoding id of the simulcast/SVC layer */
@property (nonatomic, strong, nonnull) NSString* encodingId;
/** @brief The spatial layer id*/
@property int spatialLayerId;
/** @brief The temporal layer id*/
@property int temporalLayerId;

@end

/**
 * @brief The projection data is used to project a video/audio track into a specific transceiver.
 * We send a command to the media server using the project method to choose which track to
 * project
 */
MILLICAST_API @interface  MCProjectionData : NSObject

/** @brief The id of the track on the server side */
@property (nonatomic, strong, nonnull) NSString* trackId;
/** @brief Kind of the track. Either "video" or "audio" */
@property (nonatomic, strong, nonnull) NSString* media;
/** @brief The transceiver mid associated to the track */
@property (nonatomic, strong, nonnull) NSString* mid;
/** @brief Optionally choose a simulcast layer. */
@property (nonatomic, strong, nullable) MCLayerData*  layer;

@end

/**
 * @brief The Listener protocol for the Viewer class.
 * It adds the on_subscribed event on top of the Client listener
 * You must inherit this class and set a listener with set_listener
 * to be able to receive events from the Viewer.
 */

@protocol MCSubscriberListener <MCListener>

/**
 * @brief onSubscribed is called when the subcription to the stream is complete.
 */

- (void) onSubscribed;

/**
 * @brief Callled when an error occured while establishing the peerconnection
 * @param reason The reason of the error
 */
- (void) onSubscribedError:(nonnull NSString*) reason;

/**
 * @brief onVideoTrack is called when a remote video track has been added.
 * @param track The remote video track.
 */

- (void) onVideoTrack:(nonnull MCVideoTrack*) track withMid:(nonnull NSString*) mid;

/**
 * @brief onAudioTrack is called when a remote audio track has been added.
 * @param track The remote audio track.
 * @param mid The associated transceiver mid. Can be nil if there is none.
 */

- (void) onAudioTrack:(nonnull MCAudioTrack*) track withMid:(nonnull NSString*) mid;

/**
 * @brief Called when a new source has been publishing within the new stream
 * @param streamId The stream id.
 * @param tracks All the track ids within the stream
 * @param sourceId The source id if the publisher has set one.
 */
- (void) onActive: (nonnull NSString*) streamId tracks: (nonnull NSArray<NSString*> *)tracks sourceId:(nonnull NSString*) sourceId;

/**
 * @brief Called when a source has been unpublished within the stream
 * @param streamId The stream id.
 * @param sourceId The source id set by the publisher if any.
 */
- (void) onInactive: (nonnull NSString*) streamId sourceId:(nonnull NSString*) sourceId;

/**
 * @brief onStopped callback is not currently used, but is reserved for future usage.
 */
- (void) onStopped;

/**
 * @brief Called when a source id is being multiplexed into the audio track based on the voice activity level.
 * @param mid The media id.
 * @param sourceId The source id.
 */
- (void) onVad: (nonnull NSString*) mid sourceId:(nonnull NSString*) sourceId;

/**
 * @brief Called when simulcast/svc layers are available
 * @param mid The mid associated to the track
 * @param activeLayers Active simulcast/SVC layers
 * @param inactiveLayers inactive simulcast/SVC layers
 */
- (void) onLayers: (nonnull NSString*) mid activeLayers:(nonnull NSArray<MCLayerData*>*) activeLayers inactiveLayers:(nonnull NSArray<MCLayerData*>*) inactiveLayers;

/**
 * @brief Called when a frame is received and not yet decoded
 *  Provide extracted metadata embedded in a frame if any
 * @param data Array of metadata coming from the publisher
 * @param length Length of the metadata array
 * @param ssrc Synchronization source of the frame
 * @param timestamp Timestamp of the frame
 */
@optional
- (void) onFrameMetadata:(nonnull const unsigned char*)data withLength:(int)length withSsrc:(int) ssrc withTimestamp:(int) timestamp;

@end

/**
 * @brief The Credentials interface represent the credentials need to be able to
 * connect and subscribe to a Millicast stream.
 * @sa https://dash.millicast.com/docs.html
 */

MILLICAST_API @interface MCSubscriberCredentials : NSObject
/** @brief The name of the stream you want to subscribe */
@property (nonatomic, strong, nonnull) NSString* streamName;
/** @brief The subscribing token as described in the Millicast API (optional) */
@property (nonatomic, strong, nonnull) NSString* token;
/** @brief Your millicast account ID */
@property (nonatomic, strong, nonnull) NSString* accountId;
/** @brief The subscribe API URL as described in the Millicast API */
@property (nonatomic, strong, nonnull) NSString* apiUrl;

@end


/**
 * @brief The Subscriber class. Its purpose is to receive media
 * by subscribing to a millicast stream.
 * The stream must already exists and someone must publish media.
 */

MILLICAST_API @interface MCSubscriber : NSObject <MCClient>

/**
 * @brief Subscribe to a Millicast stream.
 * You must be connected first in order to subscribe to a stream.
 * @return true if now trying to, or is already subscribing, false
 * otherwise.
 * @remark After trying，a successful subscribe results in the
 * Listener's method onSubscribed being called.
 */

- (BOOL) subscribe;

/**
 * @brief Stop receiving media from Millicast.
 * The SDK will automatically disconnect after unsubscribe.
 * @return false if unable to reach a disconnected state, true otherwise.
 */

- (BOOL)unsubscribe;

/**
 * @brief Tell whether the viewer is subscribed or not.
 * @return true if the viewer if subscribed, false otherwise.
 */

- (BOOL) isSubscribed;

/**
 * @brief Specify the source you want to receive.
 * With the project method you can select and switch sources from the Millicast server
 * and then forward the selected media to the subscriber, for each audio and video track.
 * @param sourceId The source id you want to receive
 * @param projectionData The configuration of the track you want to receive.
 * @return true if success false otherwise.
 */
- (BOOL) project:(nullable NSString*) sourceId withData:(nonnull NSArray<MCProjectionData*>*) projectionData;

/**
 * @brief Specify the media you want to stop receving
 * @param mids The list of mids to unproject.
 * @return tru if succes. false otherwise
 */
- (BOOL) unproject:(nonnull NSArray<NSString*>*) mids;

/**
 * @brief Select a specific simulcast/SVC layer for a video track.
 * @param layer The data to select which layer and which track. Send an empty optional to reset to automatic layer selection by the server.
 * @return tru if success, false otherwise.
 */
- (BOOL) select:(nullable MCLayerData*)layer;

/**
 * @brief Dynamically add on new track to the subscriber so you can project another source into it.
 * It will locally renegociate the SDP.
 * @param kind The kind of the track. "video" or "audio"
 * @return true if success, false otherwise.
 */
- (BOOL) addRemoteTrack: (nonnull NSString*) kind;

/**
 * @brief Get the transceiver mid associated to a track
 * @param trackId The id of the track we want to retrieve the mid
 * @return The transceiver mid. nil if there is no mid found
 */
- (nullable NSString*) getMid:(nonnull NSString*) trackId;

/**
 * @brief Set the viewer credentials.
 * @param credentials The credentials
 * @return true if the credentials are valid and set correctly, false otherwise.
 */

- (BOOL) setCredentials: (nonnull MCSubscriberCredentials*) credentials;

/**
 * @brief Get the current viewer credentials.
 * @return The current credentials set in the viewer.
 */

- (nonnull MCSubscriberCredentials*) getCredentials;

/**
 * @brief Create a new viewer.
 * @return A new Viewer object.
 	*/

+ (nullable MCSubscriber*) create;

@end
