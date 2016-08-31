/********* VVVideoPlayer.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "VVPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>

// Refresh interval for timed observations of AVPlayer
#define REFRESH_INTERVAL 0.25f

// Define this constant for the key-value observation context.
static const NSString *PlayerItemStatusContext;
static const NSString *PlayerItemRateContext;

@interface VVVideoPlayer : CDVPlugin <AVAssetResourceLoaderDelegate> {
    NSMutableDictionary *callbackIds;
    AVPlayer *player;
    AVPlayerItem* playerItem;
    AVAssetResourceLoader *resourceLoader;
    VVPlayerViewController *controller;
    
    id timeObserver;
    
    int currentTime;
    int duration;
    float currentCompletion;
    BOOL hasObservers;
    
    enum VVPlaybackEndedStatus : NSUInteger {
        VVPlaybackEndedStatusCompleted = 0,
        VVPlaybackEndedStatusUserExited = 1,
        VVPlaybackEndedStatusLoadFailed = 2,
        VVPlaybackEndedStatusPlaybackError = 3
    };
}

- (void)startPlayer:(CDVInvokedUrlCommand*)command;
- (void)onPlaybackEnded:(CDVInvokedUrlCommand*)command;
- (void)setCurrentTime:(CDVInvokedUrlCommand*)command;
- (void)getCurrentTime:(CDVInvokedUrlCommand*)command;
- (void)getDuration:(CDVInvokedUrlCommand*)command;
- (void)getCompletionPercentage:(CDVInvokedUrlCommand*)command;

@end

@implementation VVVideoPlayer

-(void)pluginInitialize {
    NSLog(@"Initializing video player plugin...");
    hasObservers = NO;
    currentTime = 0;
    currentCompletion = 0.0f;
    duration = 0;
    callbackIds = [NSMutableDictionary dictionary];
}

- (void)startPlayer:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    NSString* videoUrl = [command.arguments objectAtIndex:0];
    int startTime = [[command.arguments objectAtIndex:1] intValue];
    
    if (videoUrl && ![videoUrl isKindOfClass:[NSNull class]] && [videoUrl length] > 0) {
        if (!player && !controller) {
            //          create an AVPlayer
            AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL URLWithString:videoUrl]];
            resourceLoader = [(AVURLAsset *)playerItem.asset resourceLoader];
            [resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
            playerItem = [AVPlayerItem playerItemWithAsset:asset];
            player = [AVPlayer playerWithPlayerItem:playerItem];
            [player seekToTime:CMTimeMakeWithSeconds(startTime, 1)];
            player.allowsExternalPlayback = YES;
            player.closedCaptionDisplayEnabled = YES;
            player.usesExternalPlaybackWhileExternalScreenIsActive = YES;
            //create a player view controller
            controller = [[VVPlayerViewController alloc]init];
            controller.player = player;
            if ([controller respondsToSelector:@selector(setAllowsPictureInPicturePlayback:)]) {
                controller.allowsPictureInPicturePlayback = NO;
            }
            
            self.viewController.view.backgroundColor = [UIColor redColor];
        }
        
        if (!hasObservers) {
            [self addObservers];
            
            // show the view controller
            if (!controller.view.superview) {
                [self.viewController presentViewController:controller
                                                  animated:YES
                                                completion:nil];
            }
        }
        
        [player play];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)onPlaybackEnded:(CDVInvokedUrlCommand *)command {
    [callbackIds setObject:command.callbackId forKey:@"onPlaybackEnded"];
}

- (void)setCurrentTime:(CDVInvokedUrlCommand *)command {
    NSLog(@"command args: %@", command.arguments);
    if (command.arguments.count > 0 && [command.arguments[0] isKindOfClass:[NSNumber class]]) {
        NSNumber *newTime = command.arguments[0];
        [player seekToTime:CMTimeMakeWithSeconds([newTime intValue], 2)];
    }
}

- (void)getCurrentTime:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:currentTime]
                                callbackId:command.callbackId];
}

- (void)getDuration:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:duration]
                                callbackId:command.callbackId];
}

- (void)getCompletionPercentage:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:currentCompletion]
                                callbackId:command.callbackId];
}

-(void)addObservers {
    if (!hasObservers) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePlayer:) name:VVPlayerViewDidDisappearNotification object:nil];
        
        // Listen for playback finishing
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidPlayToEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:player.currentItem];
        
        [player.currentItem addObserver:self
                             forKeyPath:@"status"
                                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                context:&PlayerItemStatusContext];
        
        [player addObserver:self forKeyPath:@"rate"
                    options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                    context: &PlayerItemRateContext];
        
        [self addTimeObserver];
        
        hasObservers = YES;
    }
}

-(void)removeObservers {
    if (hasObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:VVPlayerViewDidDisappearNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name: AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];
        
        [player.currentItem removeObserver:self forKeyPath:@"status"];
        [player removeObserver:self forKeyPath:@"rate"];
        
        [self removeTimeObserver];
        
        hasObservers = NO;
    }
}

-(void)addTimeObserver {
    if (!timeObserver) {
        timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
            if (CMTIME_IS_VALID(time) && !isnan(duration)) {
                currentTime = (int)CMTimeGetSeconds(time);
                if (currentTime != 0 && duration > 0) {
                    currentCompletion = (float)currentTime / (float)duration;
                }
            }
        }];
    }
}

-(void)removeTimeObserver {
    if (timeObserver) {
        [player removeTimeObserver:timeObserver];
        timeObserver = nil;
    }
}

-(void)closePlayer:(NSNotification *)notification {
    if (callbackIds[@"onPlaybackEnded"]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"code": @(VVPlaybackEndedStatusUserExited), @"currentTime": @(currentTime), @"completion": @(currentCompletion), @"duration": @(duration)}]
                                    callbackId:callbackIds[@"onPlaybackEnded"]];
    }
    
    [self reset];
}

-(void)playerItemDidPlayToEnd:(NSNotification *)notification {
    if (callbackIds[@"onPlaybackEnded"]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"code": @(VVPlaybackEndedStatusCompleted), @"currentTime": @(currentTime), @"completion": @(currentCompletion), @"duration": @(duration)}]
                                    callbackId:callbackIds[@"onPlaybackEnded"]];
    }
    
    [self reset];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (context == &PlayerItemRateContext) {
        float rate = [change[NSKeyValueChangeNewKey] floatValue];
        
        if (rate == 0.0) {
            [self removeTimeObserver];
            
            if (callbackIds[@"onPause"]) {
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                                            callbackId:callbackIds[@"onPause"]];
            }
        } else if (rate == 1.0) {
            [self addTimeObserver];
            // Normal playback
        } else if (rate == -1.0) {
            // Reverse playback
        }
        return;
    } else if (context == &PlayerItemStatusContext) {
        AVPlayerItemStatus status = player.currentItem.status;
        if (status == AVPlayerItemStatusUnknown) {
            NSLog(@"status unknown!");
        } else if (status == AVPlayerItemStatusReadyToPlay) {
            NSLog(@"Ready to play!");
            if (duration == 0) {
                duration = (int)CMTimeGetSeconds(player.currentItem.duration);
                NSLog(@"duration: %d", duration);
            }
        } else if (status == AVPlayerItemStatusFailed) {
            NSLog(@"Status failed");
        }
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    return;
}

- (void)reset {
    [player pause];
    [self removeObservers];
    [controller dismissViewControllerAnimated:YES completion:nil];
    player = nil;
    playerItem = nil;
    controller = nil;
    duration = 0;
    currentTime = 0;
    currentCompletion = 0.0;
    hasObservers = NO;
    [callbackIds removeAllObjects];
    resourceLoader = nil;
}

- (void)onReset {
    [self reset];
}

/*AVAssetResourceLoaderDelegate*/
-(BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"player: shouldWaitForLoadingOfRequestedResource");
    
    if ([loadingRequest.request.URL.scheme isEqualToString:@"vodvision"]) {
        [loadingRequest finishLoading];
        return YES;
    }
    
    return NO;
}

@end
