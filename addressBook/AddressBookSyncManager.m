//
//  AddressBookSyncManager.m
//  AddressBookDemo
//
//  Created by aDreamCatcher on 16/5/16.
//  Copyright © 2016年 aDreamCatcher. All rights reserved.
//

#import "AddressBookSyncManager.h"
#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>
#import <Contacts/CNPhoneNumber.h>
#import <UIKit/UIDevice.h>
#import "ABContact.h"

static AddressBookSyncManager *addressBookManager;

typedef NS_ENUM(NSInteger, NewContactType) {
    NewContactTypeNotExist,       // 通讯录中不存在
    NewContactTypeExistModified,  // 通讯录中存在但信息改变了
    NewContactTypeExistIdentical, // 通讯录中存在且完全相同
};

@interface AddressBookSyncManager () 

@end

@implementation AddressBookSyncManager

+ (instancetype)instance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        addressBookManager = [[AddressBookSyncManager alloc] init];
    });
    
    return addressBookManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _contactMArray = [self getContactsByAddressBook];
    }
    
    return self;
}


#pragma mark - Interface

- (void)addContact:(ABContact *)contact
{
    // 容错
    if (contact == nil || contact.givenName.length<=0) {
        DeLog(@"addContact: nil");
        return ;
    }
    
    @synchronized (self) {
        // 通讯录中是否存在
        NewContactType type = [self contactExistType:contact];
        
        // 添加到内存
        [self addContactToMemory:contact withType:type];
        
        // 添加到手机联系人
        [self addContactToSystem:contact withType:type];
        
        // 同步数据
        [self synAddressBook];
    }
}

- (BOOL)removeContact:(ABContact *)contact;
{ // 根据identifier 删除
    
    @synchronized (self) {
        // 联系人是否存在通讯录中
        NewContactType type = [self contactExistType:contact];
        
        // 内存中删除
        [self removeContactFromMemory:contact withType:type];
        
        // 系统通讯录中删除
        [self removeContactFromSystem:contact withType:type];
        
        return YES;
    }
}

- (ABContact *)QueryContactWithTelNO:(NSString *)telNO
{
    @synchronized (self) {
        
        if (telNO == nil) {
            return nil;
        }
        
        for (id obj in _contactMArray) {
            ABContact *contact = (ABContact *)obj;
            for (NSString *phoneNum in contact.phoneNumbers) {
                if ([phoneNum hasSuffix:telNO]) {
                    return obj;
                }
            }
        }
        
        return nil;
    }
}

- (void)reloadContacts
{
    _contactMArray = [self getContactsByAddressBook];
}

#pragma mark - Utility

- (NewContactType)contactExistType:(ABContact *)contact
{ // 直接在内存中检测
    NewContactType existType = NewContactTypeNotExist;
    
    for (ABContact *obj in _contactMArray) {
        if ([contact.identifier isEqualToString:obj.identifier]) {
            existType = NewContactTypeExistModified;
            
            if ([contact.phoneNumLabs isEqualToArray:obj.phoneNumLabs] &&
                [contact.phoneNumbers isEqualToArray:obj.phoneNumbers] &&
                [contact.givenName isEqualToString:obj.givenName]) {
                existType = NewContactTypeExistIdentical;
            }
            
            break;
        }
    }
    
    return existType;
}

- (void)addContactToMemory:(ABContact *)contact withType:(NewContactType)type
{
    if (type == NewContactTypeExistIdentical) {
        return ;
    }
    
    if (type == NewContactTypeNotExist) {
        [_contactMArray addObject:contact];
        return;
    }
    
    // type == NewContactTypeExistModified
    int index = 0;
    for (; index<_contactMArray.count; index++) {
        ABContact *obj = _contactMArray[index];
        if ([obj.identifier isEqualToString:contact.identifier]) {
            break;
        }
    }
    
    [_contactMArray replaceObjectAtIndex:index withObject:contact];
    
}

- (void)removeContactFromMemory:(ABContact *)contact withType:(NewContactType)type
{
    if (type != NewContactTypeNotExist) {
        
        BOOL isExist= NO;
        int  index = 0;
        for (; index < _contactMArray.count; index++) {
            ABContact *obj = _contactMArray[index];
            if ([obj.identifier isEqualToString:contact.identifier]) {
                isExist = YES;
                break;
            }
        }
        
        if (isExist) {
            [_contactMArray removeObjectAtIndex:index];
        }
    }
}

- (void)synAddressBook
{
    // 新添加的联系人，获取identifier
    _contactMArray = [self getContactsByAddressBook];
}

- (NSString *)getName:(NSString *)givenName withFamilityName:(NSString *)familityName
{
    if (givenName.length > 0 && familityName.length>0) {
        return [familityName stringByAppendingString:givenName];
    }
    else if (givenName.length > 0)
    {
        return givenName;
    }
    
    return familityName;
}

- (NSString *)removeSpecialCharactersWithNumber:(NSString *)number
{
    return [number stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

#pragma mark methods diff 8.0 and 9.0

- (NSMutableArray *)getContactsByAddressBook
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
    
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        if (status == CNAuthorizationStatusNotDetermined) {
            
            CNContactStore *contactStore = [[CNContactStore alloc] init];
            [contactStore requestAccessForEntityType:CNEntityTypeContacts
                                   completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                       
                                       _authority = granted;
                                       
                                       if (granted) {
                                           [self getContactsByAddressBook];
                                       }
                                   }];
        }
        else if (status == CNAuthorizationStatusAuthorized) {
            
            _authority = YES;
            
            return [self getContacts];
            
        }
        else {
            _authority = NO;
            [[CustomAlertView instance] showTip:@"没有获取通讯录权限" afterDismiss:1.0];
        }

#else
        // 权限
        if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
            __weak typeof(self) weakSelf = self;
            
            ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                
                _authority = granted;
                
                if (granted) {
                    [weakSelf getContactsByAddressBook];
                }
            });
        }
        else if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
        {
            _authority = YES;
            
            ABAddressBookRef adBookRef = ABAddressBookCreateWithOptions(NULL, NULL);
            return [self getContacts:adBookRef];
        }
        else
        {
            _authority = NO;
            [[CustomAlertView instance] showTip:@"没有获取通讯录权限" afterDismiss:1.0];
        }
#endif

    return nil;
}

- (void)addContactToSystem:(ABContact *)contact withType:(NewContactType)type
{
    if (type == NewContactTypeExistIdentical) {
        return ;
    }
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
        
        CNSaveRequest *saveReq = [self getAddCNSaveRequestWithContact:contact];
        
        NSError *error = nil;
        CNContactStore *contactStore = [[CNContactStore alloc] init];
        
        if (![contactStore executeSaveRequest:saveReq error:&error]) {
            NSLog(@"executeSaveReqeust - error: %@", error);
        }
#else
    
        // 添加到系统通讯录
        ABAddressBookRef addressBook = ABAddressBookCreate();
        CFErrorRef errorRef = NULL;
        
        ABRecordRef recordRef = [self getABRecordRefWithContact:contact];
        
        ABRecordSetValue(recordRef, kABPersonFirstNameProperty, (__bridge CFStringRef)@"", NULL);
        ABRecordSetValue(recordRef, kABPersonLastNameProperty, (__bridge CFStringRef)contact.givenName,NULL);
        
        ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        for (int i = 0; i<contact.phoneNumbers.count; i++) {
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFStringRef)contact.phoneNumbers[i], (__bridge CFStringRef)contact.phoneNumLabs[i], NULL);
        }
        ABRecordSetValue(recordRef, kABPersonPhoneProperty, multiPhone, &errorRef);
        CFRelease(multiPhone);
        
        // 新的联系人添加到通讯录
        ABAddressBookAddRecord(addressBook, recordRef, NULL);
        CFRelease(recordRef);
        
        // 保存通讯录数据
        ABAddressBookSave(addressBook, NULL);
        
        // 释放通讯录的引用
        if (addressBook) {
            CFRelease(addressBook);
        }
#endif
    
}

- (void)removeContactFromSystem:(ABContact *)contact withType:(NewContactType)type
{
    if (type != NewContactTypeNotExist) {
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
            
            CNSaveRequest *delReq = [self getDeleteCNSaveRequestWithContact:contact];
            
            if (delReq) {
                
                NSError *error = nil;
                CNContactStore *contactStore = [[CNContactStore alloc] init];
                
                if (![contactStore executeSaveRequest:delReq error:&error]) {
                    
                    NSLog(@"sxecuteSaveRequest(delete) - error: %@",error);
                }
            }
        
#else
            CFErrorRef error = NULL;
            ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, &error);
            if (error) {
                return ;
            }
            
            ABRecordRef oldRecordRef = [self getABRecordRefWithContact:contact];
            ABAddressBookRemoveRecord(addressBookRef, oldRecordRef, &error);
            
            CFRelease(oldRecordRef);
            if (error) {
                return ;
            }
            
            ABAddressBookSave(addressBookRef, &error);
            CFRelease(addressBookRef);
        }
    
#endif
    
    }
}

#pragma mark methods >= 9.0

- (NSMutableArray *)getContacts
{ // iOS Version > 9.0
    
    NSMutableArray *contacts = [NSMutableArray array];
    
    // 创建获取联系人的请求
    NSArray <id<CNKeyDescriptor>> *keysToFetch =  [self keysForFetch];
    
    CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
    
    NSError *error = nil;
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    
    [contactStore enumerateContactsWithFetchRequest:fetchRequest
                                              error:&error
                                         usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
                                             
                                             if (!error) {
                                                 ABContact *abContact = [[ABContact alloc] init];
                                                 abContact.imgData = contact.imageData;
                                                 abContact.givenName  = contact.givenName;
                                                 abContact.familyName = contact.familyName;
                                                 abContact.origanizationName = contact.organizationName;
                                                 abContact.identifier = contact.identifier;
                                                 
                                                 NSMutableArray *numMAry = [NSMutableArray array];
                                                 NSMutableArray *labMAry = [NSMutableArray array];
                                                 for (id obj in contact.phoneNumbers) {
                                                     CNLabeledValue *valued = (CNLabeledValue *)obj;
                                                     CNPhoneNumber  *numValue = valued.value;
                                                     
                                                     [numMAry addObject:(numValue.stringValue.length>0)?numValue.stringValue:@""];
                                                     [labMAry addObject:(valued.label.length>0)?valued.label:@""];
                                                 }
                                                 
                                                 abContact.phoneNumbers = numMAry;
                                                 abContact.phoneNumLabs = labMAry;
                                                 
                                                 // 特殊处理givenName
                                                 abContact.givenName = [self getName:contact.givenName withFamilityName:contact.familyName];
                                                 
                                                 [contacts addObject:abContact];
                                             }
                                             else
                                             {
                                                 DeLog(@"error: %@",error);
                                             }
                                             
                                             NSLog(@"contact.iden: %@, stop: %d", contact.identifier, *stop);
                                         }];
    
    NSLog(@"return contacts: %@", contacts);
    return contacts;
}

- (CNSaveRequest *)getAddCNSaveRequestWithContact:(ABContact *)contact {
    
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    
    
    NSError *error = nil;
    
    CNContact *unifiedConatct = [contactStore unifiedContactWithIdentifier:contact.identifier
                                                               keysToFetch:[self keysForFetch]
                                                                     error:&error];
    CNMutableContact *updateContact = nil;
    if (unifiedConatct || error == nil) {
        updateContact = [unifiedConatct mutableCopy];
    }
    else {
        updateContact = [[CNMutableContact alloc] init];
    }
    
    // replace new value
    updateContact.givenName = contact.givenName;
    updateContact.familyName = contact.familyName;
    updateContact.organizationName = contact.origanizationName;
    
    NSMutableArray *phoneNumbers = [NSMutableArray array];
    for (int i = 0; i < contact.phoneNumLabs.count; i++) {
        
        NSString *label = contact.phoneNumLabs[i];
        NSString *num   = contact.phoneNumbers[i];
        
        CNPhoneNumber *phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:num];
        
        CNLabeledValue *labeledValue = [CNLabeledValue labeledValueWithLabel:label value:phoneNumber];
        
        [phoneNumbers addObject:labeledValue];
    }
    
    updateContact.phoneNumbers = phoneNumbers;
    
    // create new saveRequest
    CNSaveRequest *saveReq = [[CNSaveRequest alloc] init];
    
    if (error) {
        [saveReq addContact:updateContact toContainerWithIdentifier:nil];
    }
    else {
        
        [saveReq updateContact:updateContact];
    }
    
    return saveReq;
}

- (CNSaveRequest *)getDeleteCNSaveRequestWithContact:(ABContact *)contact {
    
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    
    
    NSError *error = nil;
    
    CNContact *deleteContact = [contactStore unifiedContactWithIdentifier:contact.identifier
                                                              keysToFetch:[self keysForFetch]
                                                                    error:&error];
    
    if (error) {
        return nil;
    }
    
    CNSaveRequest *saveReq = [[CNSaveRequest alloc] init];
    [saveReq deleteContact:[deleteContact mutableCopy]];
    
    return saveReq;
}

- (NSArray <id<CNKeyDescriptor>> *)keysForFetch {
    
    return @[CNContactIdentifierKey,
             CNContactImageDataKey,
             CNContactGivenNameKey,
             CNContactFamilyNameKey,
             CNContactOrganizationNameKey,
             CNContactPhoneNumbersKey];
}

#pragma mark methods < 9.0

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_9_0

- (NSMutableArray *)getContacts:(ABAddressBookRef)addressBook
{
    NSMutableArray *peopleArr = [NSMutableArray array];
    // 获取数据
    NSArray *peopleArray = (__bridge_transfer NSArray *)(ABAddressBookCopyArrayOfAllPeople(addressBook));
    for (id person in peopleArray) {
        ABContact *abContact = [[ABContact alloc] init];
        ABRecordRef recordRef = (__bridge ABRecordRef) person;
        
        abContact.givenName        = (__bridge_transfer NSString *)ABRecordCopyValue(recordRef, kABPersonFirstNameProperty);
        abContact.familyName       = (__bridge_transfer NSString *)ABRecordCopyValue(recordRef, kABPersonLastNameProperty);
        abContact.origanizationName = (__bridge_transfer NSString *)ABRecordCopyValue(recordRef, kABPersonOrganizationProperty);
        
        int32_t identifier         = ABRecordGetRecordID(recordRef);
        abContact.identifier       = [NSString stringWithFormat:@"%d",identifier];
        
        if (ABPersonHasImageData(recordRef)) {
            abContact.imgData = (__bridge_transfer NSData *)ABPersonCopyImageData(recordRef);
        }
        
        abContact.givenName         = [self getName:abContact.givenName withFamilityName:abContact.familyName];
        
        ABMultiValueRef phones  = ABRecordCopyValue((__bridge ABRecordRef)person, kABPersonPhoneProperty);
        NSMutableArray *numMAry = [NSMutableArray array];
        NSMutableArray *labMAry = [NSMutableArray array];
        for (int j = 0; j < ABMultiValueGetCount(phones); j++) {
            NSString    *phoneNum = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phones, j));
            CFStringRef  LabRef   = ABMultiValueCopyLabelAtIndex(phones, j);
            NSString    *phoneLab = (__bridge_transfer NSString *)ABAddressBookCopyLocalizedLabel(LabRef);
            
            phoneNum = [self removeSpecialCharactersWithNumber:phoneNum];
            
            [numMAry addObject:phoneNum];
            [labMAry  addObject:phoneLab?phoneLab:@""];
        }
        
        abContact.phoneNumbers = numMAry;
        abContact.phoneNumLabs = labMAry;
        
        [peopleArr addObject:abContact];
        
        // 释放内存
        CFRelease(phones);
    }
    
    // 释放内存
    CFRelease(addressBook);
    
    return peopleArr;
}

- (ABRecordRef)getABRecordRefWithContact:(ABContact *)contact
{ // 获取系统中的联系人ABRecordRef
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    NSArray *peopleArray = (__bridge_transfer NSArray *)(ABAddressBookCopyArrayOfAllPeople(addressBook));
    
    ABRecordRef recordRef = ABPersonCreate();
    for (id person in peopleArray) {
        ABRecordRef ref   = (__bridge_retained ABRecordRef)person;
        int32_t     identifier  = ABRecordGetRecordID(ref);
        NSString   *iden        = [NSString stringWithFormat:@"%d",identifier];
        if ([contact.identifier isEqualToString:iden]) {
            return ref;
        }
    }
    
    return recordRef;
}

#endif

@end





