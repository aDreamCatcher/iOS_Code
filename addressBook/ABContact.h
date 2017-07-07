//
//  ABContact.h
//  AddressBookDemo
//
//  Created by aDreamCatcher on 16/5/16.
//  Copyright © 2016年 aDreamCatcher. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ABContact : NSObject

@property (nonatomic, copy) NSData   *imgData;             // 头像
@property (nonatomic, copy) NSString *givenName;           // FirstName
@property (nonatomic, copy) NSString *familyName;          // LastName
@property (nonatomic, copy) NSString *origanizationName;   // Company Name

@property (nonatomic, copy) NSArray  *phoneNumLabs; // 电话号码对应值
@property (nonatomic, copy) NSArray  *phoneNumbers; // 电话号码

@property (nonatomic, copy) NSString *identifier;          // 唯一标识符

@end
