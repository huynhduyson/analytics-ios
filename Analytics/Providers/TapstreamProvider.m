//
//  TapstreamProvider.m
//  Analytics
//
//  Created by Peter Reinhardt on 12/17/13.
//  Copyright (c) 2013 Segment.io. All rights reserved.
//

#import "TapstreamProvider.h"
#import "TSTapstream.h"
#import "AnalyticsUtils.h"
#import "Analytics.h"

@interface TapstreamProvider()
- (TSEvent *)makeEvent:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options;
@end

@implementation TapstreamProvider

#pragma mark - Initialization

+ (void)load {
    [Analytics registerProvider:self withIdentifier:@"Tapstream"];
}

- (id)init {
    if (self = [super init]) {
        self.name = @"Tapstream";
        self.valid = NO;
        self.initialized = NO;
    }
    return self;
}

- (void)start
{
    TSConfig *config = [TSConfig configWithDefaults];
    
    // Load any values that the TSConfig object supports
    for(NSString *key in self.settings) {
        if([config respondsToSelector:NSSelectorFromString(key)]) {
            [config setValue:[self.settings objectForKey:key] forKey:key];
        }
    }
    
    NSString *accountName = [self.settings objectForKey:@"accountName"];
    NSString *developerSecret = [self.settings objectForKey:@"developerSecret"];
    
    [TSTapstream createWithAccountName:accountName developerSecret:developerSecret config:config];
    
    SOLog(@"TapstreamProvider initialized with accountName %@ and developerSecret", accountName, developerSecret);
}


#pragma mark - Settings

- (void)validate
{
    BOOL hasAccountName = [self.settings objectForKey:@"accountName"] != nil;
    BOOL hasDeveloperSecret = [self.settings objectForKey:@"developerSecret"] != nil;
    self.valid = hasAccountName && hasDeveloperSecret;
}


#pragma mark - Analytics API


- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    // Tapstream doesn't have an explicit user identification event
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    TSEvent *e = [self makeEvent:event properties:properties options:options];
    [[TSTapstream instance] fireEvent:e];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSString *screenEventName = [@"screen-" stringByAppendingString:screenTitle];
    TSEvent *e = [self makeEvent:screenEventName properties:properties options:options];
    [[TSTapstream instance] fireEvent:e];
}


- (TSEvent *)makeEvent:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    // Add support for Tapstream's "one-time-only" events by looking for a field in the context dict.
    // One time only will be false by default.
    NSNumber *oneTimeOnly = [options objectForKey:@"oneTimeOnly"];
    BOOL oto = oneTimeOnly != nil && [oneTimeOnly boolValue] == YES;
    
    TSEvent *e = [TSEvent eventWithName:event oneTimeOnly:oto];
    
    for(NSString *key in properties)
    {
        id value = [properties objectForKey:key];
        if([value isKindOfClass:[NSString class]])
        {
            [e addValue:(NSString *)value forKey:(NSString *)key];
        }
        else if([value isKindOfClass:[NSNumber class]])
        {
            NSNumber *number = (NSNumber *)value;
            
            if(strcmp([number objCType], @encode(int)) == 0)
            {
                [e addIntegerValue:[number intValue] forKey:key];
            }
            else if(strcmp([number objCType], @encode(uint)) == 0)
            {
                [e addUnsignedIntegerValue:[number unsignedIntValue] forKey:key];
            }
            else if(strcmp([number objCType], @encode(double)) == 0 ||
                    strcmp([number objCType], @encode(float)) == 0)
            {
                [e addDoubleValue:[number doubleValue] forKey:key];
            }
            else if(strcmp([number objCType], @encode(BOOL)) == 0)
            {
                [e addBooleanValue:[number boolValue] forKey:key];
            }
            else
            {
                SOLog(@"Tapstream Event cannot accept an NSNumber param holding this type, skipping param");
            }
        }
        else
        {
            SOLog(@"Tapstream Event cannot accept a param of type %@, skipping param %@", [value class], key);
        }
    }
    
    return e;
}

@end
