//
//  CoreDataManager.h
//  WidgetPush
//
//  Created by Marin on 9/1/11.
//  Copyright (c) 2011 mneorr.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreDataManager : NSObject

@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) UIManagedDocument *document;

@property (copy, nonatomic) NSString *databaseName;
@property (copy, nonatomic) NSString *modelName;

+ (instancetype)sharedManager;

- (BOOL)saveContext;
- (void)useManagedDocument;
- (void)addStorageCompletionHandler:(void(^)(void))completion;

#pragma mark - Helpers

- (NSURL *)applicationDocumentsDirectory;
- (NSURL *)applicationSupportDirectory;

@end
