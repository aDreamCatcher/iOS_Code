//
//  ABContact.m
//  AddressBookDemo
//
//  Created by aDreamCatcher on 16/5/16.
//  Copyright © 2016年 aDreamCatcher. All rights reserved.
//

#import "ABContact.h"

@interface ABContact ()<NSCopying>

@end

@implementation ABContact

- (instancetype)init
{
    self = [super init];
    if (self) {
        _imgData = nil;
        _givenName  = @"";
        _familyName = @"";
        _origanizationName = @"";
        
        _phoneNumLabs = nil;
        _phoneNumbers = nil;
        
        _identifier = @"";
    }
    
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    ABContact *contact = [[ABContact allocWithZone:zone] init];
    
    contact.imgData = [_imgData copy];
    contact.givenName  = [_givenName copy];
    contact.familyName = [_familyName copy];
    contact.origanizationName = [_origanizationName copy];
    contact.phoneNumLabs = [_phoneNumLabs copy];
    contact.phoneNumbers = [_phoneNumbers copy];
    contact.identifier   = [_identifier copy];
    
    return contact;
}


@end
