//
//  EasyJSWebViewDelegate.m
//  EasyJS
//
//  Created by Lau Alex on 19/1/13.
//  Copyright (c) 2013 Dukeland. All rights reserved.
//

#import "EasyJSWebViewProxyDelegate.h"
#import "EasyJSDataFunction.h"
#import <objc/runtime.h>

/*
 This is the content of easyjs-inject.js
 Putting it inline in order to prevent loading from files
*/
NSString* INJECT_JS = @"window.EasyJS = {\
__callbacks: {},\
\
invokeCallback: function (cbID, removeAfterExecute){\
var args = Array.prototype.slice.call(arguments);\
args.shift();\
args.shift();\
\
for (var i = 0, l = args.length; i < l; i++){\
args[i] = decodeURIComponent(args[i]);\
}\
\
var cb = EasyJS.__callbacks[cbID];\
if (removeAfterExecute){\
EasyJS.__callbacks[cbID] = undefined;\
}\
return cb.apply(null, args);\
},\
\
call: function (obj, functionName, args){\
var formattedArgs = [];\
for (var i = 0, l = args.length; i < l; i++){\
if (typeof args[i] == \"function\"){\
formattedArgs.push(\"f\");\
var cbID = \"__cb\" + (+new Date);\
EasyJS.__callbacks[cbID] = args[i];\
formattedArgs.push(cbID);\
}else{\
formattedArgs.push(\"s\");\
formattedArgs.push(encodeURIComponent(args[i]));\
}\
}\
\
var argStr = (formattedArgs.length > 0 ? \":\" + encodeURIComponent(formattedArgs.join(\":\")) : \"\");\
\
var iframe = document.createElement(\"IFRAME\");\
iframe.setAttribute(\"src\", \"easy-js:\" + obj + \":\" + encodeURIComponent(functionName) + argStr);\
document.documentElement.appendChild(iframe);\
iframe.parentNode.removeChild(iframe);\
iframe = null;\
\
var ret = EasyJS.retValue;\
EasyJS.retValue = undefined;\
\
if (ret){\
return decodeURIComponent(ret);\
}\
},\
\
inject: function (obj, methods){\
window[obj] = {};\
var jsObj = window[obj];\
\
for (var i = 0, l = methods.length; i < l; i++){\
(function (){\
var method = methods[i];\
var jsMethod = method.replace(new RegExp(\":\", \"g\"), \"\");\
jsObj[jsMethod] = function (){\
return EasyJS.call(obj, method, Array.prototype.slice.call(arguments));\
};\
})();\
}\
}\
};";

@implementation EasyJSWebViewProxyDelegate

- (void) addJavascriptInterfaces:(NSObject*) interface WithName:(NSString*) name{
	if (! self.javascriptInterfaces){
		self.javascriptInterfaces = [[NSMutableDictionary alloc] init];
	}
	
	[self.javascriptInterfaces setValue:interface forKey:name];
}


#pragma mark - delegate

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    [self.realDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self.realDelegate webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSString *requestString = [[navigationAction.request URL] absoluteString];
    
    if ([requestString hasPrefix:@"easy-js:"]) {
        /*
         A sample URL structure:
         easy-js:MyJSTest:test
         easy-js:MyJSTest:testWithParam%3A:haha
         */
        NSArray *components = [requestString componentsSeparatedByString:@":"];
        //NSLog(@"req: %@", requestString);
        
        NSString* obj = (NSString*)[components objectAtIndex:1];
        NSString* method = [(NSString*)[components objectAtIndex:2]
                            stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSObject* interface = [self.javascriptInterfaces objectForKey:obj];
        
        // execute the interfacing method
        SEL selector = NSSelectorFromString(method);
        NSMethodSignature* sig = [[interface class] instanceMethodSignatureForSelector:selector];
        NSInvocation* invoker = [NSInvocation invocationWithMethodSignature:sig];
        invoker.selector = selector;
        invoker.target = interface;
        
        NSMutableArray* args = [[NSMutableArray alloc] init];
        
        if ([components count] > 3){
            NSString *argsAsString = [(NSString*)[components objectAtIndex:3]
                                      stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            NSArray* formattedArgs = [argsAsString componentsSeparatedByString:@":"];
            for (NSInteger i = 0, j = 0, l = [formattedArgs count]; i < l; i+=2, j++){
                NSString* type = ((NSString*) [formattedArgs objectAtIndex:i]);
                NSString* argStr = ((NSString*) [formattedArgs objectAtIndex:i + 1]);
                
                if ([@"f" isEqualToString:type]){
                    EasyJSDataFunction* func = [[EasyJSDataFunction alloc] initWithWebView:(EasyJSWebView *)webView];
                    func.funcID = argStr;
                    [args addObject:func];
                    [invoker setArgument:&func atIndex:(j + 2)];
                }else if ([@"s" isEqualToString:type]){
                    NSString* arg = [argStr stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    [args addObject:arg];
                    [invoker setArgument:&arg atIndex:(j + 2)];
                }
            }
        }
        [invoker invoke];
        
        //return the value by using javascript
        if ([sig methodReturnLength] > 0){
            NSString* retValue;
            [invoker getReturnValue:&retValue];
            
            if (retValue == NULL || retValue == nil){
                [webView evaluateJavaScript:@"EasyJS.retValue=null;" completionHandler:nil];
            }else{
                retValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) retValue, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
                [webView evaluateJavaScript:@"EasyJS.retValue=\"%@\";" completionHandler:nil];
            }
        }
        
        decisionHandler(WKNavigationResponsePolicyCancel);
        return;
    }
    
    if (!self.realDelegate){
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }
    
    [self.realDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    [self.realDelegate webView:webView didStartProvisionalNavigation:navigation];
    
    if (! self.javascriptInterfaces){
        self.javascriptInterfaces = [[NSMutableDictionary alloc] init];
    }
    
    NSMutableString* injection = [[NSMutableString alloc] init];
    //inject the javascript interface
    for(id key in self.javascriptInterfaces) {
        NSObject* interface = [self.javascriptInterfaces objectForKey:key];
        [injection appendString:@"EasyJS.inject(\""];
        [injection appendString:key];
        [injection appendString:@"\", ["];
        
        unsigned int mc = 0;
        Class cls = object_getClass(interface);
        Method * mlist = class_copyMethodList(cls, &mc);
        for (int i = 0; i < mc; i++){
            [injection appendString:@"\""];
            [injection appendString:[NSString stringWithUTF8String:sel_getName(method_getName(mlist[i]))]];
            [injection appendString:@"\""];
            
            if (i != mc - 1){
                [injection appendString:@", "];
            }
        }
        free(mlist);
        [injection appendString:@"]);"];
    }
    
    NSString* js = INJECT_JS;
    //inject the basic functions first
    [webView evaluateJavaScript:js completionHandler:nil];
    [webView evaluateJavaScript:injection completionHandler:nil];
}

@end
