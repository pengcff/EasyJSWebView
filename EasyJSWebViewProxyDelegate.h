//
//  EasyJSWebViewDelegate.h
//  EasyJS
//
//  Created by Lau Alex on 19/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface EasyJSWebViewProxyDelegate : NSObject<WKNavigationDelegate>

@property (nonatomic, strong) NSMutableDictionary *javascriptInterfaces;
@property (nonatomic, retain) id<WKNavigationDelegate> realDelegate;

- (void)addJavascriptInterfaces:(NSObject *)interface WithName:(NSString *)name;

@end
