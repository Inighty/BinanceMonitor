//
//  HUDHelper.h
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef NOTIFY_RELOAD_HUD
#define NOTIFY_RELOAD_HUD "com.inighty.binancemonitor.notification.hud.reload"
#endif

OBJC_EXTERN const char * const kHUDNotificationReload;
OBJC_EXTERN BOOL IsHUDEnabled(void);
OBJC_EXTERN void SetHUDEnabled(BOOL isEnabled);
OBJC_EXTERN void PostHUDNotification(const char *name);

#if DEBUG
OBJC_EXTERN void SimulateMemoryPressure(void);
#endif

OBJC_EXTERN NSUserDefaults *GetStandardUserDefaults(void);

NS_ASSUME_NONNULL_END
