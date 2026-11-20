#import "TuJuReactHost.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTSurfaceHostingProxyRootView.h>
#import <React/RCTDefaultReactNativeFactoryDelegate.h>
#import <React/RCTReactNativeFactory.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>

@interface TuJuReactDelegate : RCTDefaultReactNativeFactoryDelegate
@end

@implementation TuJuReactDelegate
- (NSURL *)bundleURL {
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
}
@end

@interface TuJuSurfaceEvents : NSObject
@property (nonatomic, copy) void (^action)(NSString *);
@property (nonatomic, copy) void (^height)(double);
@end
@implementation TuJuSurfaceEvents
@end

// Both public view operations and exported JS methods access this registry on the main queue.
static NSMutableDictionary<NSString *, TuJuSurfaceEvents *> *surfaceEvents(void) {
  static NSMutableDictionary *events;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ events = [NSMutableDictionary new]; });
  return events;
}

@interface TuJuControlsBridge : NSObject <RCTBridgeModule>
@end

@implementation TuJuControlsBridge
RCT_EXPORT_MODULE(TuJuControlsBridge)

+ (BOOL)requiresMainQueueSetup { return NO; }
- (dispatch_queue_t)methodQueue { return dispatch_get_main_queue(); }

RCT_EXPORT_METHOD(sendAction:(NSString *)surfaceId action:(NSString *)name) {
  TuJuSurfaceEvents *events = surfaceEvents()[surfaceId];
  if (events && name) events.action(name);
}

RCT_EXPORT_METHOD(reportHeight:(NSString *)surfaceId height:(double)value) {
  TuJuSurfaceEvents *events = surfaceEvents()[surfaceId];
  if (events) events.height(value);
}
@end

@implementation TuJuReactHost
+ (UIView *)mount:(NSDictionary<NSString *,id> *)props
           action:(void (^)(NSString *))action
           height:(void (^)(double))height {
  if (![[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"]) return nil;
  static TuJuReactDelegate *delegate;
  static RCTReactNativeFactory *factory;
  if (!factory) {
    delegate = [TuJuReactDelegate new];
    delegate.dependencyProvider = [RCTAppDependencyProvider new];
    factory = [[RCTReactNativeFactory alloc] initWithDelegate:delegate];
  }
  TuJuSurfaceEvents *events = [TuJuSurfaceEvents new];
  events.action = action;
  events.height = height;
  surfaceEvents()[props[@"surfaceId"]] = events;
  UIView *view = [factory.rootViewFactory viewWithModuleName:@"TuJuControls"
                                           initialProperties:props
                                               launchOptions:nil];
  view.backgroundColor = UIColor.clearColor;
  return view;
}
+ (void)updateView:(UIView *)view props:(NSDictionary<NSString *,id> *)props {
  if ([view isKindOfClass:[RCTSurfaceHostingProxyRootView class]]) {
    ((RCTSurfaceHostingProxyRootView *)view).appProperties = props;
  }
}
+ (void)unmount:(NSString *)surfaceId {
  [surfaceEvents() removeObjectForKey:surfaceId];
}
@end
