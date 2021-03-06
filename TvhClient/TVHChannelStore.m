//
//  TVHChannelStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/3/13.
//  Copyright 2013 Luis Fernandes
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "TVHChannelStore.h"
#import "TVHEpg.h"
#import "TVHSettings.h"
#import "TVHServer.h"

@interface TVHChannelStore ()
@property (nonatomic, weak) TVHJsonClient *jsonClient;
@property (nonatomic, strong) NSArray *channels;
@property (nonatomic, strong) TVHEpgStore *epgStore;
@property (nonatomic, strong) NSDate *profilingDate;
@end

@implementation TVHChannelStore 

- (TVHEpgStore*)epgStore {
    if( ! _epgStore ){
        _epgStore = [[TVHEpgStore alloc] initWithStatsEpgName:@"CurrentlyPlaying" withTvhServer:self.tvhServer];
        [_epgStore setDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:_epgStore selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return _epgStore;
}

- (id)initWithTvhServer:(TVHServer*)tvhServer {
    self = [super init];
    if (!self) return nil;
    self.tvhServer = tvhServer;
    self.jsonClient = [self.tvhServer jsonClient];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchChannelList)
                                                 name:@"channelsNotificationClassReceived"
                                               object:nil];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.channels = nil;
    self.epgStore = nil;
    self.jsonClient = nil;
    self.profilingDate = nil;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        [self signalDidErrorLoadingChannelStore:error];
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *channels = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHChannel *channel = [[TVHChannel alloc] initWithTvhServer:self.tvhServer];
        [obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [channel setValue:obj forKey:key];
        }];
        [channels addObject:channel];

    }];
    
    if ( [[TVHSettings sharedInstance] sortChannel] == TVHS_SORT_CHANNEL_BY_NAME ) {
        self.channels =  [[channels copy] sortedArrayUsingSelector:@selector(compareByName:)];
    } else {
        self.channels =  [[channels copy] sortedArrayUsingSelector:@selector(compareByNumber:)];
    }
#ifdef TESTING
    NSLog(@"[Loaded Channels]: %d", [self.channels count]);
#endif
}

- (void)fetchChannelList {
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"list", @"op", nil];
    self.profilingDate = [NSDate date];
    [self.jsonClient postPath:@"/channels" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.profilingDate];
#ifdef TVH_GOOGLEANALYTICS_KEY
        [[GAI sharedInstance].defaultTracker sendTimingWithCategory:@"Network Profiling"
                                                          withValue:time
                                                           withName:@"ChannelStore"
                                                          withLabel:nil];
#endif
#ifdef TESTING
        NSLog(@"[ChannelList Profiling Network]: %f", time);
#endif
        [self fetchedData:responseObject];
        if ([self.delegate respondsToSelector:@selector(didLoadChannels)]) {
            [self.delegate didLoadChannels];
        }
        [self.epgStore downloadEpgList];
        
       // NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
       // NSLog(@"Request Successful, response '%@'", responseStr);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self signalDidErrorLoadingChannelStore:error];
        NSLog(@"[ChannelList HTTPClient Error]: %@", error.localizedDescription);
    }];
}

#pragma mark EPG delegatee stuff

- (void)didLoadEpg:(TVHEpgStore*)epgStore {
    // for each epg
    NSArray *list = [epgStore epgStoreItems];
    for (TVHEpg *epg in list) {
        TVHChannel *channel = [self channelWithId:epg.channelid];
        [channel addEpg:epg];
    }
    // instead of having this delegate here, channel could send a notification and channel controller
    // could catch it and reload only that line if data was different ?
    [self signalDidLoadChannels];
}

- (void)didErrorLoadingEpgStore:(NSError*)error {
    [self signalDidErrorLoadingChannelStore:error];
}

#pragma mark Controller delegate stuff

- (NSArray*)filteredChannelList {
    NSMutableArray *filteredChannels = [[NSMutableArray alloc] init];
    for (TVHChannel *channel in self.channels) {
        if( [channel hasTag:self.filterTag] ) {
            [filteredChannels addObject:channel];
        }
    }
    return [filteredChannels copy];
}

- (NSArray*)arrayChannels {
    if (self.filterTag == 0) {
        return [self.channels copy];
    } else {
        return [self filteredChannelList];
    }
}

- (TVHChannel*)channelWithName:(NSString*)name {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSArray *filteredArray = [self.channels filteredArrayUsingPredicate:predicate];
    if ([filteredArray count] > 0) {
        return [filteredArray objectAtIndex:0];
    }
    return nil;
}

- (TVHChannel*)channelWithId:(NSInteger)channelId {
    // not using a predicate because if I find one channel then I'll return it right away
    for (TVHChannel *channel in self.channels) {
        if( channel.chid == channelId ) {
            return channel;
        }
    }
    return nil;
}

- (void)setDelegate:(id <TVHChannelStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

- (void)signalDidLoadChannels {
    if ([self.delegate respondsToSelector:@selector(didLoadChannels)]) {
        [self.delegate didLoadChannels];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didLoadChannels"
                                                        object:self];
}

- (void)signalDidErrorLoadingChannelStore:(NSError*)error {
    if ([self.delegate respondsToSelector:@selector(didErrorLoadingChannelStore:)]) {
        [self.delegate didErrorLoadingChannelStore:error];
    }   
}

@end
