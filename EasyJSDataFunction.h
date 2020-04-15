//
//  EasyJSDataFunction.h
//  EasyJSWebViewSample
//
//  Created by Alex Lau on 21/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EasyJSWebView.h"

@interface EasyJSDataFunction : NSObject

@property (nonatomic, strong) NSString *funcID;
@property (nonatomic, strong) EasyJSWebView *webView;
@property (nonatomic, assign) BOOL removeAfterExecute;

- (id)initWithWebView:(EasyJSWebView *)_webView;

- (void)executeWithParam:(NSString *)param completionHandler:(void (^)(id obj, NSError *error))completionHandler;
- (void)executeWithParams:(NSArray*)params completionHandler:(void (^)(id obj, NSError *error))completionHandler;

@end
