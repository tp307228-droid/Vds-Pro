// VdsProUnlock.x — VideoStar Pro Unlock
// Patches all subscription/IAP checks in VideoStar 15.x
// Deploy to: https://github.com/tp307228-droid/Vds-Pro

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────────────────
// Filter: only run inside VideoStar
// ─────────────────────────────────────────────────────────
// Bundle filter set in dylib.plist — no %filter needed here for direct injection

// ─────────────────────────────────────────────────────────
// MARK: - SKPaymentQueue (Block IAP dialogs, spoof purchased)
// ─────────────────────────────────────────────────────────
%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
    // Don't process real purchases — we're already unlocked
    // %orig; // intentionally skipped
}

+ (BOOL)canMakePayments {
    return NO; // Pretend IAP not available → app skips purchase flow
}

%end

// ─────────────────────────────────────────────────────────
// MARK: - NSUserDefaults (Spoof all Pro/VIP flags)
// ─────────────────────────────────────────────────────────
%hook NSUserDefaults

- (BOOL)boolForKey:(NSString *)key {
    // Any key that looks like a subscription/pro/vip/unlock flag → YES
    NSString *lower = key.lowercaseString;
    if ([lower containsString:@"pro"]         ||
        [lower containsString:@"vip"]         ||
        [lower containsString:@"premium"]     ||
        [lower containsString:@"subscri"]     ||
        [lower containsString:@"purchase"]    ||
        [lower containsString:@"unlock"]      ||
        [lower containsString:@"paid"]        ||
        [lower containsString:@"lifetime"]    ||
        [lower containsString:@"iap"]         ||
        [lower containsString:@"activated"]   ||
        [lower containsString:@"fullaccess"]  ||
        [lower containsString:@"full_access"] ||
        [lower containsString:@"hasbought"]   ||
        [lower containsString:@"has_bought"]  ||
        [lower containsString:@"purchased"]   ||
        [lower containsString:@"restored"]) {
        return YES;
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)key {
    NSString *lower = key.lowercaseString;
    if ([lower containsString:@"tier"]  ||
        [lower containsString:@"level"] ||
        [lower containsString:@"plan"]) {
        return 99; // Highest tier
    }
    return %orig;
}

- (id)objectForKey:(NSString *)key {
    NSString *lower = key.lowercaseString;
    if ([lower containsString:@"receipt"] ||
        [lower containsString:@"transaction"]) {
        // Return a fake receipt string so the app thinks it's purchased
        return @"VDS_PRO_FAKE_RECEIPT_OK";
    }
    return %orig;
}

%end

// ─────────────────────────────────────────────────────────
// MARK: - Hook VideoStar-specific subscription classes
//          (discovered via class-dump of VideoStar 15.x)
// ─────────────────────────────────────────────────────────

// Pattern 1: VSSubscriptionManager
%hook VSSubscriptionManager

- (BOOL)isSubscribed       { return YES; }
- (BOOL)isPro              { return YES; }
- (BOOL)isVIP              { return YES; }
- (BOOL)isPremium          { return YES; }
- (BOOL)hasFullAccess      { return YES; }
- (BOOL)isActive           { return YES; }
- (BOOL)isTrial            { return NO;  }
- (BOOL)isExpired          { return NO;  }
- (NSInteger)subscriptionTier { return 3; }  // highest

%end

// Pattern 2: VSPurchaseManager
%hook VSPurchaseManager

- (BOOL)isPurchased:(NSString *)productID { return YES; }
- (BOOL)isUnlocked:(NSString *)featureID  { return YES; }
- (BOOL)hasProFeatures                     { return YES; }
- (BOOL)hasPremiumFeatures                 { return YES; }

%end

// Pattern 3: VideoStarSubscription (possible class name variant)
%hook VideoStarSubscription

- (BOOL)isActive   { return YES; }
- (BOOL)isValid    { return YES; }
- (BOOL)isPremium  { return YES; }
- (id)status       { return @"active"; }
- (NSDate *)expirationDate {
    // Far future date
    return [NSDate dateWithTimeIntervalSince1970:9999999999.0];
}

%end

// Pattern 4: VSStoreManager
%hook VSStoreManager

+ (instancetype)sharedManager { return %orig; }
- (BOOL)isProductPurchased:(NSString *)identifier { return YES; }
- (BOOL)isSubscriptionActive                       { return YES; }
- (BOOL)canAccessPremiumContent                    { return YES; }
- (BOOL)hasProSubscription                         { return YES; }

%end

// Pattern 5: Catch-all for any class named *Manager/*Controller/*Helper with isSubscribed/isPro
// Use class swizzle at runtime
static void swizzleProMethod(Class cls, SEL sel) {
    if (!class_getInstanceMethod(cls, sel)) return;
    class_addMethod(cls, sel, imp_implementationWithBlock(^BOOL(id self) {
        return YES;
    }), "B@:");
    Method m = class_getInstanceMethod(cls, sel);
    method_setImplementation(m, imp_implementationWithBlock(^BOOL(id self) { return YES; }));
}

// ─────────────────────────────────────────────────────────
// MARK: - Dismiss any paywall / subscription prompt VCs
// ─────────────────────────────────────────────────────────
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *className = NSStringFromClass(self.class);
    // Auto-dismiss any paywall UI
    if ([className containsString:@"Paywall"]    ||
        [className containsString:@"Subscribe"]  ||
        [className containsString:@"Purchase"]   ||
        [className containsString:@"Upgrade"]    ||
        [className containsString:@"Subscription"] ||
        [className containsString:@"Premium"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.presentingViewController) {
                [self dismissViewControllerAnimated:NO completion:nil];
            } else if (self.navigationController) {
                [self.navigationController popViewControllerAnimated:NO];
            }
        });
    }
}

%end

// ─────────────────────────────────────────────────────────
// MARK: - Hook UIAlertController (block upgrade/subscribe alerts)
// ─────────────────────────────────────────────────────────
%hook UIAlertController

- (void)viewWillAppear:(BOOL)animated {
    NSString *msg = self.message ?: @"";
    NSString *ttl = self.title   ?: @"";
    NSString *combined = [[ttl stringByAppendingString:msg] lowercaseString];

    // Block upgrade prompts
    if ([combined containsString:@"subscribe"] ||
        [combined containsString:@"upgrade"]   ||
        [combined containsString:@"premium"]   ||
        [combined containsString:@"purchase"]  ||
        [combined containsString:@"vip"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:NO completion:nil];
        });
        return;
    }
    %orig;
}

%end

// ─────────────────────────────────────────────────────────
// MARK: - Show Pro Activated Banner on launch
// ─────────────────────────────────────────────────────────
static void showProActivatedBanner() {
    UIWindow *win = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            win = scene.windows.firstObject;
            break;
        }
    }
    if (!win) return;

    UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(16, win.safeAreaInsets.top + 10,
        win.bounds.size.width - 32, 44)];
    banner.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:0.3 alpha:0.95];
    banner.layer.cornerRadius = 12;
    banner.layer.shadowColor  = UIColor.blackColor.CGColor;
    banner.layer.shadowRadius = 8;
    banner.layer.shadowOpacity = 0.4;
    banner.layer.shadowOffset  = CGSizeZero;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectInset(banner.bounds, 12, 0)];
    lbl.text = @"✅ VideoStar Pro — FallVds Tool kích hoạt!";
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    lbl.textColor = UIColor.whiteColor;
    lbl.adjustsFontSizeToFitWidth = YES;
    [banner addSubview:lbl];
    [win addSubview:banner];

    banner.alpha = 0;
    banner.transform = CGAffineTransformMakeTranslation(0, -20);
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0 options:0 animations:^{
        banner.alpha = 1;
        banner.transform = CGAffineTransformIdentity;
    } completion:^(BOOL done){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.35 animations:^{
                banner.alpha = 0;
                banner.transform = CGAffineTransformMakeTranslation(0, -20);
            } completion:^(BOOL d){ [banner removeFromSuperview]; }];
        });
    }];
}

// ─────────────────────────────────────────────────────────
// MARK: - Runtime swizzle on load
// ─────────────────────────────────────────────────────────
%ctor {
    @autoreleasepool {
        // Runtime-swizzle known subscription method patterns
        // across all loaded classes
        dispatch_async(dispatch_get_main_queue(), ^{
            int count = 0;
            Class *classes = objc_copyClassList((unsigned int *)&count);
            SEL proSelectors[] = {
                @selector(isSubscribed),
                @selector(isPro),
                @selector(isVIP),
                @selector(isPremium),
                @selector(hasFullAccess),
                @selector(isActive),
            };
            int selectorCount = sizeof(proSelectors)/sizeof(proSelectors[0]);

            for (int i = 0; i < count; i++) {
                Class cls = classes[i];
                NSString *name = NSStringFromClass(cls);
                // Only patch VideoStar-specific classes
                if (![name containsString:@"VS"] &&
                    ![name containsString:@"VideoStar"] &&
                    ![name containsString:@"Frontier"] &&
                    ![name containsString:@"Subscription"] &&
                    ![name containsString:@"Purchase"] &&
                    ![name containsString:@"Store"]) continue;

                for (int s = 0; s < selectorCount; s++) {
                    swizzleProMethod(cls, proSelectors[s]);
                }
            }
            free(classes);

            // Show banner
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                showProActivatedBanner();
            });
        });
    }
}
