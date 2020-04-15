//
//  EasyJSDataFunction.m
//  EasyJSWebViewSample
//
//  Created by Alex Lau on 21/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//

#import "EasyJSDataFunction.h"

@implementation EasyJSDataFunction

@synthesize funcID;
@synthesize webView;
@synthesize removeAfterExecute;

- (id)initWithWebView:(EasyJSWebView *)_webView {
	self = [super init];
    if (self) {
		self.webView = _webView;
    }
    return self;
}

- (void)executeWithParam:(NSString *)param completionHandler:(void (^)(id obj, NSError *error))completionHandler {
	NSMutableArray *params = [[NSMutableArray alloc] initWithObjects:param, nil];
    [self executeWithParams:params completionHandler:completionHandler];
}

- (void)executeWithParams:(NSArray*)params completionHandler:(void (^)(id obj, NSError *error))completionHandler {
	NSMutableString* injection = [[NSMutableString alloc] init];
	[injection appendFormat:@"EasyJS.invokeCallback(\"%@\", %@", self.funcID, self.removeAfterExecute ? @"true" : @"false"];
	if (params){
		for (NSInteger i = 0, l = params.count; i < l; i++){
			NSString* arg = [params objectAtIndex:i];
			NSString* encodedArg = (NSString*) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)arg, NULL, (CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
			[injection appendFormat:@", \"%@\"", encodedArg];
		}
	}
	[injection appendString:@");"];
	
	if (self.webView){
        [self.webView evaluateJavaScript:injection completionHandler:^(id obj, NSError * _Nullable error) {
            if (completionHandler) {
                completionHandler(obj, error);
            }
        }];
	} else {
        NSError *error = [NSError errorWithDomain:@"webView = nil" code:-1 userInfo:nil];
        if (completionHandler) {
            completionHandler(nil, error);
        }
	}
}

@end
