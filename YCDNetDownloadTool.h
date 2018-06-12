//
//  YCDNetDownloadTool.h
//  DownLoadTest
//
//  Created by huyuchen on 2018/6/11.
//  Copyright © 2018年 Quarkdata. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

typedef void(^YCDDownloadSuccessBlock)(NSURL *fileUrlPath, NSURLResponse *response);
typedef void(^YCDDownloadFailureBlock)(NSError *error, NSInteger code);
typedef void(^YCDDownloadProgressBlock)(CGFloat progress);

@interface YCDNetDownloadTool : NSObject
//下载管理
@property (nonatomic, strong) AFURLSessionManager *manager;
//断点续传
@property (nonatomic, strong) NSMutableDictionary *downloadHistoryDictionary;

+ (instancetype)sharedTool;

- (NSURLSessionDownloadTask *)ycd_downloadWithUrl:(NSString *)urlString progress:(YCDDownloadProgressBlock)progress localPath:(NSString *)localPath success:(YCDDownloadSuccessBlock)success failure:(YCDDownloadFailureBlock)failure;

- (void)ycd_stopAllDownloadTasks;

- (void)ycd_stopDownloadTaskWithUrl:(NSString *)urlString;

@end
