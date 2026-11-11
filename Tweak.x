#import <UIKit/UIKit.h>
#import <Security/Security.h>

// ===== ĐỔI DÒNG NÀY thành domain Railway của bạn =====
#define SERVER @"https://ten-app-cua-ban.up.railway.app"
#define KC_ACCOUNT @"license_key"

static BOOL gShowing = NO;

static NSString *DeviceID(void) {
    return UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"unknown";
}

static void KCSave(NSString *v) {
    NSDictionary *q = @{(id)kSecClass: (id)kSecClassGenericPassword, (id)kSecAttrAccount: KC_ACCOUNT};
    SecItemDelete((CFDictionaryRef)q);
    NSMutableDictionary *a = [q mutableCopy];
    a[(id)kSecValueData] = [v dataUsingEncoding:NSUTF8StringEncoding];
    SecItemAdd((CFDictionaryRef)a, NULL);
}

static NSString *KCLoad(void) {
    NSDictionary *q = @{(id)kSecClass: (id)kSecClassGenericPassword, (id)kSecAttrAccount: KC_ACCOUNT,
                        (id)kSecReturnData: @YES};
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)q, &out) != errSecSuccess) return nil;
    NSData *d = (__bridge_transfer NSData *)out;
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}

static UIViewController *TopVC(void) {
    UIWindow *w = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if (![s isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *x in ((UIWindowScene *)s).windows) if (x.isKeyWindow) w = x;
    }
    if (!w) w = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *vc = w.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static NSString *MsgFor(NSString *err) {
    if ([err isEqualToString:@"invalid_key"]) return @"Key không đúng";
    if ([err isEqualToString:@"expired"]) return @"Key đã hết hạn";
    if ([err isEqualToString:@"revoked"]) return @"Key đã bị thu hồi";
    if ([err isEqualToString:@"used_on_other_device"]) return @"Key đã dùng trên máy khác";
    return @"Lỗi không rõ";
}

static void Check(NSString *key, void (^done)(BOOL ok, NSString *msg)) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[SERVER stringByAppendingString:@"/activate"]]];
    r.HTTPMethod = @"POST";
    r.timeoutInterval = 15;
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"key": key, @"device_id": DeviceID()} options:0 error:nil];
    [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *data, NSURLResponse *resp, NSError *e) {
        NSDictionary *j = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![j isKindOfClass:NSDictionary.class]) { done(NO, @"Không kết nối được server"); return; }
            if ([j[@"ok"] boolValue]) done(YES, nil);
            else done(NO, MsgFor(j[@"error"]));
        });
    }] resume];
}

static void Prompt(NSString *msg) {
    UIViewController *vc = TopVC();
    if (!vc) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Prompt(msg); }); return; }
    gShowing = YES;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Nhập key kích hoạt"
                                                               message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t) {
        t.placeholder = @"LIC-XXXXXXXX...";
        t.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        t.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Kích hoạt" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *k = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        Check(k, ^(BOOL ok, NSString *m) {
            if (ok) { KCSave(k); gShowing = NO; }
            else Prompt(m);
        });
    }]];
    [vc presentViewController:a animated:YES completion:nil];
}

static void Start(void) {
    if (gShowing) return;
    NSString *saved = KCLoad();
    if (!saved.length) { Prompt(nil); return; }
    Check(saved, ^(BOOL ok, NSString *m) { if (!ok) Prompt(m); });
}

%ctor {
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *n) { Start(); }];
}
