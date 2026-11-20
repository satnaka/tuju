#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A shared React runtime hosts separately mounted Home and navigation surfaces.
@interface TuJuReactHost : NSObject
+ (nullable UIView *)mount:(NSDictionary<NSString *, id> *)props
                   action:(void (^)(NSString *))action
                   height:(void (^)(double))height;
+ (void)updateView:(UIView *)view props:(NSDictionary<NSString *, id> *)props;
+ (void)unmount:(NSString *)surfaceId;
@end

NS_ASSUME_NONNULL_END
