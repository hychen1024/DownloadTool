

//
//  YCDNetDownloadTool.m
//  DownLoadTest
//
//  Created by huyuchen on 2018/6/11.
//  Copyright © 2018年 Quarkdata. All rights reserved.
//

#import "YCDNetDownloadTool.h"

@interface YCDNetDownloadTool ()
@property (nonatomic, copy) NSString *fileHistoryPath;
@end
@implementation YCDNetDownloadTool

static id _instance;

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _instance;
}

+ (instancetype)sharedTool {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        
        //监听网络变化
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        
        //开启后台下载
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
        configuration.timeoutIntervalForRequest = 25;
        configuration.allowsCellularAccess = NO;
        _manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
        
        //网络变化通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ycd_didReceiveNetworkStateChanged:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
        
        NSURLSessionDownloadTask *task = nil;
        
        //下载状态变更通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveDownloadCallBack:) name:AFNetworkingTaskDidCompleteNotification object:task];
        
        //获取缓存文件地址
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        self.fileHistoryPath = [path stringByAppendingPathComponent:@"ycd_fileDownloadHistory.plist"];
        
        //是否存在磁盘缓存文件
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            //读磁盘缓存
            self.downloadHistoryDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        }
        else {
            self.downloadHistoryDictionary = [NSMutableDictionary dictionary];
            //创建磁盘缓存文件
            [self.downloadHistoryDictionary writeToFile:path atomically:YES];
        }
    }
    
    return self;
}

#pragma mark - 网络变化通知
- (void)ycd_didReceiveNetworkStateChanged:(NSNotification *)notification {
    id statusObj = [notification.userInfo objectForKey:AFNetworkingReachabilityNotificationStatusItem];
    if (![statusObj respondsToSelector:@selector(integerValue)]) {
        return;
    }
    
    AFNetworkReachabilityStatus status = [((NSNumber *)statusObj) integerValue];
    
    
}

#pragma mark - 下载状态回调处理
/**
 下载模块通知回调 影响到下载状态都会回调(包括强退闪退app)
 */
- (void)didReceiveDownloadCallBack:(NSNotification *)notification {
    NSURLSessionDownloadTask *task = notification.object;
    NSDictionary *dict = notification.userInfo;
    if (![task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        return;
    }
    
    NSString *url = [task.currentRequest.URL absoluteString];
    NSError *error = [dict objectForKey:AFNetworkingTaskDidCompleteErrorKey];
    if (error) {
        if (error.code == -1001) {
            NSLog(@"下载网络出错");
        }
        NSData *resumeData = [error.userInfo objectForKey:@"NSURLSessionDownloadTaskResumeData"];
        [self saveHistoryWithKey:url downloadTaskResumeData:resumeData];
    }
    else {
        if ([self.downloadHistoryDictionary valueForKey:url]) {
            [self.downloadHistoryDictionary removeObjectForKey:url];
            //写入缓存
            [self saveDownloadHistoryDirectory];
        }
    }
}

#pragma mark - 下载历史缓存
- (void)saveDownloadHistoryDirectory {
    [self.downloadHistoryDictionary writeToFile:self.fileHistoryPath atomically:YES];
}

- (void)saveHistoryWithKey:(NSString *)url downloadTaskResumeData:(NSData *)resumeData {
    if ([url isKindOfClass:[NSString class]] && url.length > 0) {
        if (resumeData) {
            [self.downloadHistoryDictionary setObject:resumeData forKey:url];
        }
        else {
            [self.downloadHistoryDictionary setObject:@"" forKey:url];
        }
    }
}

#pragma mark - 公开方法

- (NSURLSessionDownloadTask *)ycd_downloadWithUrl:(NSString *)urlString progress:(YCDDownloadProgressBlock)progress localPath:(NSString *)localPath success:(YCDDownloadSuccessBlock)success failure:(YCDDownloadFailureBlock)failure {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURLSessionDownloadTask *task = nil;
    
    //断点续传
    NSData *resumeData = [self.downloadHistoryDictionary objectForKey:urlString];
    if ([resumeData isKindOfClass:[NSData class]] && resumeData.length > 0) {
        task = [self.manager downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progress) {
                progress(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            }
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            NSLog(@"targetPath:%@\nlocalPath:%@",targetPath.absoluteString,localPath);
            return [NSURL URLWithString:localPath];
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 404) {
                //移除下载文件
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            
            if (error) {
                //下载失败
                if (failure) {
                    failure(error,httpResponse.statusCode);
                }
            }
            else {
                //下载成功
                if (success) {
                    success(filePath,response);
                }
            }
        }];
    }
    //开辟新任务
    else {
        task = [self.manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progress) {
                progress(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            }
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            NSLog(@"targetPath:%@\nlocalPath:%@",targetPath.absoluteString,localPath);
            return [NSURL URLWithString:localPath];
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 404) {
                //移除下载文件
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            
            if (error) {
                //下载失败
                if (failure) {
                    failure(error,httpResponse.statusCode);
                }
            }
            else {
                //下载成功
                if (success) {
                    success(filePath,response);
                }
            }
        }];
    }
    
    //执行任务
    [task resume];
    
    return task;
}

- (void)ycd_stopAllDownloadTasks {
    NSArray *downloadArray = [self.manager downloadTasks];
    if ([downloadArray isKindOfClass:[NSArray class]] && downloadArray.count > 0) {
        for (NSURLSessionDownloadTask *task in downloadArray) {
            if (task.state == NSURLSessionTaskStateRunning) {
                [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    //resumeData不用写入,会自动收到AFNetworkingTaskDidCompleteNotification通知
                }];
            }
        }
    }
}

- (void)ycd_stopDownloadTaskWithUrl:(NSString *)urlString {
    NSArray *downloadArray = [self.manager downloadTasks];
    if ([downloadArray isKindOfClass:[NSArray class]] && downloadArray.count > 0) {
        for (NSURLSessionDownloadTask *task in downloadArray) {
            if ([task.currentRequest.URL.absoluteString isEqualToString:urlString] && task.state == NSURLSessionTaskStateRunning) {
                [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    //resumeData不用写入,会自动收到AFNetworkingTaskDidCompleteNotification通知
                }];
            }
        }
    }
}

#pragma mark - dealloc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
