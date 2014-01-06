//
//  CoreDataManager.m
//  WidgetPush
//
//  Created by Marin on 9/1/11.
//  Copyright (c) 2011 mneorr.com. All rights reserved.
//

#import "CoreDataManager.h"

@interface CoreDataManager()
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic) UIManagedDocument *document;

@property (strong, nonatomic) NSMutableArray *responseBlocks;
@end

@implementation CoreDataManager

+ (id)instance {
    return [self sharedManager];
}

+ (instancetype)sharedManager {
    static CoreDataManager *singleton;
    static dispatch_once_t singletonToken;
    dispatch_once(&singletonToken, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}


#pragma mark - Private

- (NSString *)appName {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}

- (NSString *)databaseName {
    if (_databaseName != nil) return _databaseName;
    
    _databaseName = [[[self appName] stringByAppendingString:@".sqlite"] copy];
    return _databaseName;
}

- (NSString *)modelName {
    if (_modelName != nil) return _modelName;

    _modelName = [[self appName] copy];
    return _modelName;
}


#pragma mark - Public

- (void)useManagedDocument
{
    self.responseBlocks = [NSMutableArray array];
    
    NSURL *url = [self applicationDocumentsDirectory];
    url = [url URLByAppendingPathComponent:[self appName]];
    
    void (^__block InitializeDocument)(void) = ^ {
        self.document = [[UIManagedDocument alloc] initWithFileURL:url];
        // Set our document up for automatic migrations
        self.document.persistentStoreOptions = @{NSMigratePersistentStoresAutomaticallyOption : @YES,
                                                 NSInferMappingModelAutomaticallyOption : @YES};
    };
    
    void (^__block OnDocumentDidLoad)(BOOL) = ^(BOOL success) {
        if (!success)
        {
            //TODO: Add update database support
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
            
            InitializeDocument();
            
            [self.document saveToURL:url
                    forSaveOperation:UIDocumentSaveForCreating
                   completionHandler:^(BOOL success){
                       if (success)
                           [self documentIsReady];
                   }];
        }
        else
        {
            [self documentIsReady];
        }
    };
    
    InitializeDocument();
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path])
    {
        [self.document openWithCompletionHandler:OnDocumentDidLoad];
    }
    else
    {
        [self.document saveToURL:url
                forSaveOperation:UIDocumentSaveForCreating
               completionHandler:OnDocumentDidLoad];
    }
}

- (void)documentIsReady
{
    if (self.document.documentState == UIDocumentStateNormal)
    {
        self.managedObjectContext = self.document.managedObjectContext;
    }
    
    for (dispatch_block_t block in self.responseBlocks)
        block();
    self.responseBlocks = nil;
}

- (void)addStorageCompletionHandler:(void(^)(void))completion
{
    [self.responseBlocks addObject:completion];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext) return _managedObjectContext;
    
    if (self.persistentStoreCoordinator) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel) return _managedObjectModel;
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:[self modelName] withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (BOOL)saveContext {
    if (self.managedObjectContext == nil) return NO;
    if (![self.managedObjectContext hasChanges])return NO;
    
    NSError *error = nil;
    
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"Unresolved error in saving context! %@, %@", error, [error userInfo]);
        return NO;
    }
    
    return YES;
}


#pragma mark - SQLite file directory

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory 
                                                   inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)applicationSupportDirectory {
    return [[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                   inDomains:NSUserDomainMask] lastObject]
            URLByAppendingPathComponent:[self appName]];
}


#pragma mark - Private

- (NSURL *)sqliteStoreURL {
    NSURL *directory = [self isOSX] ? self.applicationSupportDirectory : self.applicationDocumentsDirectory;
    NSURL *databaseDir = [directory URLByAppendingPathComponent:[self databaseName]];
    
    [self createApplicationSupportDirIfNeeded:directory];
    return databaseDir;
}

- (BOOL)isOSX {
    if (NSClassFromString(@"UIDevice")) return NO;
    return YES;
}

- (void)createApplicationSupportDirIfNeeded:(NSURL *)url {
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.absoluteString]) return;

    [[NSFileManager defaultManager] createDirectoryAtURL:url
                             withIntermediateDirectories:YES attributes:nil error:nil];
}

@end
