// VdsProUnlock.m — VideoStar Pro Unlock (Pure Objective-C Runtime)
// 100% Standalone — NO CydiaSubstrate dependency — Zero crash on launch
// Works on unjailbroken iOS via eSign / TrollStore / AltStore

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Swizzle Helpers (Zero external dependency)
// ─────────────────────────────────────────────────────────────────────────────

static void swizzleInstanceMethodReturningBOOL(Class cls, SEL sel, BOOL retVal) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        class_addMethod(cls, sel, imp_implementationWithBlock(^BOOL(id self) {
            return retVal;
        }), "B@:");
    } else {
        method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self) {
            return retVal;
        }));
    }
}

static void swizzleClassMethodReturningBOOL(Class cls, SEL sel, BOOL retVal) {
    if (!cls) return;
    Class metaCls = object_getClass(cls);
    Method m = class_getInstanceMethod(metaCls, sel);
    if (!m) {
        class_addMethod(metaCls, sel, imp_implementationWithBlock(^BOOL(id self) {
            return retVal;
        }), "B@:");
    } else {
        method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self) {
            return retVal;
        }));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NSUserDefaults Swizzling
// ─────────────────────────────────────────────────────────────────────────────

static BOOL (*orig_boolForKey)(id, SEL, NSString *);

static BOOL my_boolForKey(id self, SEL _cmd, NSString *key) {
    if (key && [key isKindOfClass:[NSString class]]) {
        // Do not spoof internal tool keys
        if ([key hasPrefix:@"fvd_"]) {
            if (orig_boolForKey) return orig_boolForKey(self, _cmd, key);
            return NO;
        }

        NSString *lower = key.lowercaseString;
        if ([lower containsString:@"pro"]         ||
            [lower containsString:@"vip"]         ||
            [lower containsString:@"premium"]     ||
            [lower containsString:@"subscri"]     ||
            [lower containsString:@"purchase"]    ||
            [lower containsString:@"unlock"]      ||
            [lower containsString:@"paid"]        ||
            [lower containsString:@"lifetime"]    ||
            [lower containsString:@"fullaccess"]  ||
            [lower containsString:@"full_access"] ||
            [lower containsString:@"hasbought"]   ||
            [lower containsString:@"has_bought"]  ||
            [lower containsString:@"purchased"]   ||
            [lower containsString:@"restored"]) {
            return YES;
        }
    }
    if (orig_boolForKey) {
        return orig_boolForKey(self, _cmd, key);
    }
    return NO;
}

static void patchNSUserDefaults(void) {
    Class cls = [NSUserDefaults class];
    Method m = class_getInstanceMethod(cls, @selector(boolForKey:));
    if (m) {
        orig_boolForKey = (BOOL (*)(id, SEL, NSString *))method_getImplementation(m);
        method_setImplementation(m, (IMP)my_boolForKey);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SKPaymentQueue Swizzling
// ─────────────────────────────────────────────────────────────────────────────

static void patchStoreKit(void) {
    Class queueCls = [SKPaymentQueue class];
    if (queueCls) {
        // canMakePayments -> NO (prevent Apple IAP prompt from popping up)
        swizzleClassMethodReturningBOOL(queueCls, @selector(canMakePayments), NO);

        // addPayment: -> do nothing
        Method addPay = class_getInstanceMethod(queueCls, @selector(addPayment:));
        if (addPay) {
            method_setImplementation(addPay, imp_implementationWithBlock(^(id self, SKPayment *payment) {
                // Silently drop payment request
            }));
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - VideoStar Specific Subscription Classes Swizzling
// ─────────────────────────────────────────────────────────────────────────────

static void patchVideoStarClasses(void) {
    // Array of selectors that indicate Pro / Premium / VIP status
    SEL proSels[] = {
        @selector(isSubscribed),
        @selector(hasSubscription),
        @selector(isPro),
        @selector(isProUser),
        @selector(hasPro),
        @selector(isVIP),
        @selector(hasVIP),
        @selector(isPremium),
        @selector(hasPremium),
        @selector(hasFullAccess),
        @selector(isAllAccessUnlocked),
        @selector(isUnlocked),
        @selector(allPacksPurchased),
        @selector(hasPurchasedAll),
        @selector(isPurchased),
    };
    int proCount = sizeof(proSels) / sizeof(proSels[0]);

    // Known VideoStar classes
    const char *classNames[] = {
        "VSSubscriptionManager",
        "VSStore",
        "VSProduct",
        "VSFeature",
        "VSAccount",
        "VSPurchase",
        "VSProManager",
        "VSSubscription",
        "VSIAPManager",
        "VSStoreManager",
        "VSMembershipManager",
        "VSPackManager",
        "VSEffectManager",
        "VSUserAccount",
    };
    int classCount = sizeof(classNames) / sizeof(classNames[0]);

    for (int c = 0; c < classCount; c++) {
        Class cls = objc_getClass(classNames[c]);
        if (!cls) continue;

        // Instance methods
        for (int s = 0; s < proCount; s++) {
            swizzleInstanceMethodReturningBOOL(cls, proSels[s], YES);
            swizzleClassMethodReturningBOOL(cls, proSels[s], YES);
        }

        // Methods that take an argument: hasPurchasedEffect:, isPurchased:
        SEL argSels[] = {
            @selector(hasPurchasedEffect:),
            @selector(hasPurchasedPack:),
            @selector(isPurchased:),
            @selector(isEffectPurchased:),
            @selector(isPackPurchased:),
            @selector(hasUnlockedItem:),
            @selector(canUseEffect:),
            @selector(canUsePack:),
        };
        int argCount = sizeof(argSels) / sizeof(argSels[0]);
        for (int a = 0; a < argCount; a++) {
            SEL sel = argSels[a];
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self, id arg) {
                    return YES;
                }));
            }
        }
    }

    // Watermark removal
    Class wmCls = objc_getClass("VSWatermarkManager");
    if (wmCls) {
        swizzleInstanceMethodReturningBOOL(wmCls, @selector(shouldShowWatermark), NO);
        swizzleInstanceMethodReturningBOOL(wmCls, @selector(hasWatermark), NO);
        swizzleInstanceMethodReturningBOOL(wmCls, @selector(isWatermarkEnabled), NO);
        swizzleClassMethodReturningBOOL(wmCls, @selector(shouldShowWatermark), NO);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Banner Notification
// ─────────────────────────────────────────────────────────────────────────────

static void showProBanner(void) {
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                win = scene.windows.firstObject;
                if (win) break;
            }
        }
    }
    if (!win) {
        win = [UIApplication sharedApplication].keyWindow;
    }
    if (!win) return;

    CGFloat topInset = 20;
    if (@available(iOS 11.0, *)) {
        topInset = win.safeAreaInsets.top;
    }

    UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(16, topInset + 10, win.bounds.size.width - 32, 44)];
    banner.backgroundColor = [UIColor colorWithRed:0.08 green:0.72 blue:0.42 alpha:0.95];
    banner.layer.cornerRadius = 12;
    banner.layer.shadowColor = UIColor.blackColor.CGColor;
    banner.layer.shadowRadius = 8;
    banner.layer.shadowOpacity = 0.3;
    banner.layer.shadowOffset = CGSizeMake(0, 2);

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectInset(banner.bounds, 12, 0)];
    lbl.text = @"✅ VideoStar Pro — Activated!";
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    lbl.textColor = UIColor.whiteColor;
    lbl.textAlignment = NSTextAlignmentCenter;
    [banner addSubview:lbl];
    [win addSubview:banner];

    banner.alpha = 0;
    banner.transform = CGAffineTransformMakeTranslation(0, -20);
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0 options:0 animations:^{
        banner.alpha = 1;
        banner.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                banner.alpha = 0;
                banner.transform = CGAffineTransformMakeTranslation(0, -20);
            } completion:^(BOOL d) {
                [banner removeFromSuperview];
            }];
        });
    }];
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Constructor Entry Point (Loaded automatically by dyld)
// ─────────────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void VdsProUnlockInit(void) {
    @autoreleasepool {
        patchNSUserDefaults();
        patchStoreKit();

        // Run class patches when app finishes launching
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                patchVideoStarClasses();

                // Show activated banner after 1.5 seconds
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    showProBanner();
                });
            }];
    }
}

#pragma clang diagnostic pop
