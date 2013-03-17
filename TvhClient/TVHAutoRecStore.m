//
//  TVHAutoRecStore.m
//  TvhClient
//
//  Created by zipleen on 3/14/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHAutoRecStore.h"
#import "TVHJsonClient.h"

@interface TVHAutoRecStore()
@property (nonatomic, strong) NSArray *dvrAutoRecItems;
@property (nonatomic, weak) id <TVHAutoRecStoreDelegate> delegate;
@end

@implementation TVHAutoRecStore
+ (id)sharedInstance {
    static TVHAutoRecStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHAutoRecStore alloc] init];
    });
    
    return __sharedInstance;
}

- (id)init {
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveDvrdbNotification:)
                                                 name:@"dvrdbNotificationClassReceived"
                                               object:nil];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)receiveDvrdbNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"dvrdbNotificationClassReceived"]) {
        NSDictionary *message = (NSDictionary*)[notification object];
        if ( [[message objectForKey:@"reload"] intValue] == 1 ) {
            [self fetchDvrAutoRec];
        }
    }
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorDvrAutoStore:)]) {
            [self.delegate didErrorDvrAutoStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *dvrAutoRecItems = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHAutoRecItem *dvritem = [[TVHAutoRecItem alloc] init];
        [dvritem updateValuesFromDictionary:obj];
        
        [dvrAutoRecItems addObject:dvritem];
    }];
    
    self.dvrAutoRecItems = [dvrAutoRecItems copy];
    
#ifdef TESTING
    NSLog(@"[Loaded Auto Rec Items, Count]: %d", [self.dvrAutoRecItems count]);
#endif
}

- (void)fetchDvrAutoRec {
    TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"get", @"op", @"autorec", @"table", nil];
    
    self.dvrAutoRecItems = nil;
    [httpClient getPath:@"/tablemgr" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self fetchedData:responseObject];
        [self.delegate didLoadDvrAutoRec];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([self.delegate respondsToSelector:@selector(didErrorDvrAutoStore:)]) {
            [self.delegate didErrorDvrAutoStore:error];
        }
#ifdef TESTING
        NSLog(@"[DVR AutoRec Items HTTPClient Error]: %@", error.localizedDescription);
#endif
    }];
    
}

- (TVHAutoRecItem *)objectAtIndex:(int)row {
    if ( row < [self.dvrAutoRecItems count] ) {
        return [self.dvrAutoRecItems objectAtIndex:row];
    }
    return nil;
}

- (int)count {
    if ( self.dvrAutoRecItems ) {
        return [self.dvrAutoRecItems count];
    }
    return 0;
}

@end
