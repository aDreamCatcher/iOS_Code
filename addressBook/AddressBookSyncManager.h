//
//  AddressBookSyncManager.h
//  AddressBookDemo
//
//  Created by aDreamCatcher on 16/5/16.
//  Copyright © 2016年 aDreamCatcher. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ABContact.h"

@interface AddressBookSyncManager : NSObject

+ (instancetype)instance;

@property (nonatomic, readonly) BOOL            authority;     // 通讯录访问权限
@property (nonatomic, readonly, copy) NSMutableArray *contactMArray; // 通讯录


- (void)addContact:(ABContact *)contact; // 添加或更改
- (BOOL)removeContact:(ABContact *)contact;

- (ABContact *)QueryContactWithTelNO:(NSString *)telNO;
- (void)reloadContacts;


@end
