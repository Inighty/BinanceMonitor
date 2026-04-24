//
//  RootViewController.h
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <UIKit/UIKit.h>

#if __has_include("BinanceHUD-Swift.h")
#import "BinanceHUD-Swift.h"
#elif __has_include("TrollSpeed-Swift.h")
#import "TrollSpeed-Swift.h"
#else
#error "Swift compatibility header not found"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface RootViewController : UIViewController <TSSettingsControllerDelegate>
@property (nonatomic, strong) UIView *backgroundView;
+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag;
- (void)reloadMainButtonState;
@end

NS_ASSUME_NONNULL_END
